// lib/providers/collection_sheet_provider.dart

import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/collection_payment_model.dart';
import '../services/supabase_service.dart';

class CollectionSheetProvider extends ChangeNotifier {
  // Routes Master List - Pulled directly from Supabase table route_master
  final List<RouteModel> _routes = [];

  // RO Collection Sheet Cards/Entries - Master cards in ro_collection_entries
  final List<RoCollectionEntry> _collectionEntries = [];

  // Dedicated Payment Records - Individual payments in ro_collection_payments
  final List<CollectionPaymentModel> _payments = [];

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  CollectionSheetProvider() {
    fetchFromSupabase();
  }

  // Getters
  List<RouteModel> get routes => List.unmodifiable(_routes);
  List<RoCollectionEntry> get collectionEntries => List.unmodifiable(_collectionEntries);
  List<CollectionPaymentModel> get payments => List.unmodifiable(_payments);

  /// Check if a route is the Master Head Office Route
  static bool isOfficeRoute(String? route) {
    if (route == null) return false;
    final r = route.toLowerCase().trim();
    return r == 'office' || r == 'head office' || r == 'main office';
  }

  List<String> get routeNames {
    final list = _routes.where((r) => r.isActive).map((r) => r.name).toList();
    if (!list.any((r) => isOfficeRoute(r))) {
      list.insert(0, 'Office');
    }
    return list;
  }

  /// Total sum of all payments collected - calculated strictly from payment table (ro_collection_payments)
  double get totalCollectedAmount {
    return _payments.fold(0.0, (sum, p) => sum + p.paymentAmount);
  }

  int get totalEntriesCount => _collectionEntries.length;
  int get totalPaymentsCount => _payments.length;
  int get totalRoutesCount => _routes.length;

  /// Fetch all individual payment records for a collection card ID from payment table (sorted most recent first)
  List<CollectionPaymentModel> getPaymentsForCollection(String collectionId) {
    final list = _payments.where((p) => p.collectionId == collectionId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Calculate total amount paid for a collection card ID from payment table
  double getTotalPaidForCollection(String collectionId) {
    final cardPayments = getPaymentsForCollection(collectionId);
    return cardPayments.fold(0.0, (sum, p) => sum + p.paymentAmount);
  }

  /// Calculate today's amount paid for a collection card ID strictly from payment table
  double getTodayPaidForCollection(String collectionId, [DateTime? targetDate]) {
    final date = targetDate ?? DateTime.now();
    final cardPayments = getPaymentsForCollection(collectionId);
    return cardPayments.where((p) {
      return p.createdAt.year == date.year &&
          p.createdAt.month == date.month &&
          p.createdAt.day == date.day;
    }).fold(0.0, (sum, p) => sum + p.paymentAmount);
  }

  /// Calculate today's late fine for a collection card ID strictly from payment table
  double getTodayLateFineForCollection(String collectionId, [DateTime? targetDate]) {
    final date = targetDate ?? DateTime.now();
    final cardPayments = getPaymentsForCollection(collectionId);
    return cardPayments.where((p) {
      return p.createdAt.year == date.year &&
          p.createdAt.month == date.month &&
          p.createdAt.day == date.day;
    }).fold(0.0, (sum, p) => sum + p.lateFine);
  }

  /// Get the latest remaining balance for a collection card ID (default fallback if no payments)
  double getLatestRemainingBalance(String collectionId, [double fallback = 0.0]) {
    final cardPayments = getPaymentsForCollection(collectionId);
    if (cardPayments.isNotEmpty) {
      return cardPayments.first.remainingBalance;
    }
    return fallback > 0 ? fallback : 0.0;
  }

  /// Strictly check payment table (ro_collection_payments) for payment on a specific date (default today)
  bool hasPaymentForDate(String collectionId, [DateTime? targetDate]) {
    final date = targetDate ?? DateTime.now();
    final cardPayments = getPaymentsForCollection(collectionId);
    return cardPayments.any((p) {
      return p.createdAt.year == date.year &&
          p.createdAt.month == date.month &&
          p.createdAt.day == date.day;
    });
  }

  /// Find a single collection entry by its ID
  RoCollectionEntry? getCollectionEntryById(String collectionId) {
    try {
      return _collectionEntries.firstWhere((e) => e.id == collectionId);
    } catch (_) {
      return null;
    }
  }

  /// Find collection card entries belonging to a specific loanee account / user
  List<RoCollectionEntry> getEntriesForLoanee(String phone, String name, String custId) {
    final cleanPhone = phone.trim();
    final cleanName = name.toLowerCase().trim();
    final cleanCustId = custId.trim();

    return _collectionEntries.where((entry) {
      final matchPhone = cleanPhone.isNotEmpty && entry.mobileNo.trim() == cleanPhone;
      final matchCust = cleanCustId.isNotEmpty && entry.customerId.trim() == cleanCustId;
      final matchName = cleanName.isNotEmpty &&
          cleanName != 'loanee account' &&
          cleanName != 'user' &&
          entry.loaneeName.toLowerCase().trim() == cleanName;
      return matchPhone || matchCust || matchName;
    }).toList();
  }

  /// Get payments for a set of collection card entries, optionally filtered by route (sorted most recent first)
  List<CollectionPaymentModel> getPaymentsForEntries(List<RoCollectionEntry> entries, {String? selectedRoute}) {
    if (entries.isEmpty) return [];

    final cardMap = <String, RoCollectionEntry>{};
    for (var e in entries) {
      cardMap[e.id] = e;
    }

    final list = _payments.where((p) {
      final card = cardMap[p.collectionId];
      if (card == null) return false;

      if (selectedRoute != null &&
          selectedRoute.isNotEmpty &&
          selectedRoute != 'All' &&
          selectedRoute != 'All Routes') {
        if (card.route.toLowerCase().trim() != selectedRoute.toLowerCase().trim()) {
          return false;
        }
      }
      return true;
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Find parent collection card entry for a payment model
  RoCollectionEntry? getCardForPayment(CollectionPaymentModel payment) {
    final index = _collectionEntries.indexWhere((e) => e.id == payment.collectionId);
    if (index != -1) {
      return _collectionEntries[index];
    }
    return null;
  }

  // ROUTE MASTER METHODS
  Future<bool> addRoute(RouteModel route) async {
    if (_routes.any((r) => r.name.trim().toLowerCase() == route.name.trim().toLowerCase())) {
      return false;
    }
    _routes.insert(0, route);
    notifyListeners();

    await SupabaseService.instance.saveRoute(route);
    return true;
  }

  Future<void> updateRoute(String id, RouteModel updatedRoute) async {
    final index = _routes.indexWhere((r) => r.id == id);
    if (index != -1) {
      _routes[index] = updatedRoute;
      notifyListeners();
      await SupabaseService.instance.saveRoute(updatedRoute);
    }
  }

  Future<void> deleteRoute(String id) async {
    _routes.removeWhere((r) => r.id == id);
    notifyListeners();
    await SupabaseService.instance.deleteRoute(id);
  }

  // COLLECTION SHEET CARD MASTER ENTRY METHODS
  /// Add master collection card entry to 'ro_collection_entries' table ONLY (no default payment inserted)
  Future<bool> addCollectionEntry(RoCollectionEntry entry) async {
    // Check if card entry already exists for customerId & accountNumber
    final existingIndex = _collectionEntries.indexWhere((e) =>
        e.customerId == entry.customerId || e.accountNumber == entry.accountNumber);

    if (existingIndex == -1) {
      _collectionEntries.insert(0, entry);
      await SupabaseService.instance.saveCollectionEntry(entry);
    }

    notifyListeners();
    return true;
  }

  /// Add dedicated payment record strictly to 'ro_collection_payments' table
  Future<bool> addCollectionPayment(CollectionPaymentModel payment) async {
    // Strictly prevent duplicate payment entry for the same collection card on the same date
    if (hasPaymentForDate(payment.collectionId, payment.createdAt)) {
      debugPrint(
          '⚠️ Duplicate payment rejected: Collection ${payment.collectionId} already recorded on ${payment.createdAt.toString().split(' ')[0]}');
      return false;
    }

    _payments.insert(0, payment);
    notifyListeners();

    // Save payment to Supabase table ro_collection_payments
    return await SupabaseService.instance.saveCollectionPayment(payment);
  }

  Future<bool> updateCollectionEntry(RoCollectionEntry updatedEntry) async {
    final index = _collectionEntries.indexWhere((e) => e.id == updatedEntry.id);
    if (index != -1) {
      _collectionEntries[index] = updatedEntry;
      notifyListeners();
      await SupabaseService.instance.saveCollectionEntry(updatedEntry);
      return true;
    }
    return false;
  }

  Future<void> deleteCollectionEntry(String id) async {
    _collectionEntries.removeWhere((e) => e.id == id);
    _payments.removeWhere((p) => p.collectionId == id);
    notifyListeners();
    await SupabaseService.instance.deleteCollectionEntry(id);
  }

  String generateNextId() {
    return 'COL-${1000 + _collectionEntries.length + 1}';
  }

  String generateNextCustomerId() {
    return 'CUST-${1000 + _collectionEntries.length + 1}';
  }

  String generateNextAccountNumber() {
    return 'ACC-${88239100 + _collectionEntries.length + 1}';
  }

  static bool _matchesWeekday(String colType, int weekday) {
    switch (weekday) {
      case 1:
        return colType.startsWith('mon');
      case 2:
        return colType.startsWith('tue');
      case 3:
        return colType.startsWith('wed');
      case 4:
        return colType.startsWith('thu');
      case 5:
        return colType.startsWith('fri');
      case 6:
        return colType.startsWith('sat');
      case 7:
        return colType.startsWith('sun');
      default:
        return false;
    }
  }

  static int? _weekdayForDayName(String dayName) {
    final d = dayName.toLowerCase().trim();
    if (d.startsWith('mon')) return 1;
    if (d.startsWith('tue')) return 2;
    if (d.startsWith('wed')) return 3;
    if (d.startsWith('thu')) return 4;
    if (d.startsWith('fri')) return 5;
    if (d.startsWith('sat')) return 6;
    if (d.startsWith('sun')) return 7;
    return null;
  }

  // FILTERING METHODS
  List<RoCollectionEntry> getFilteredEntries({
    String? selectedRoute,
    String? selectedType,
    String? searchQuery,
  }) {
    final now = DateTime.now();

    return _collectionEntries.where((entry) {
      // 1. Route Filter
      if (selectedRoute != null &&
          selectedRoute != 'All' &&
          selectedRoute != 'All Routes' &&
          selectedRoute.isNotEmpty) {
        if (entry.route.toLowerCase().trim() != selectedRoute.toLowerCase().trim()) {
          return false;
        }
      }

      // 2. Collection Type / Day Filter
      if (selectedType != null &&
          selectedType != 'All' &&
          selectedType != 'All Types' &&
          selectedType.isNotEmpty) {
        final colType = entry.collectionType.toLowerCase().trim();
        final selType = selectedType.toLowerCase().trim();

        if (selType == 'today') {
          final isMatch = entry.isDaily ||
              colType == 'daily' ||
              colType == 'day' ||
              _matchesWeekday(colType, now.weekday);
          if (!isMatch) return false;
        } else {
          final targetWeekday = _weekdayForDayName(selType);
          if (targetWeekday != null) {
            final isMatch = _matchesWeekday(colType, targetWeekday);
            if (!isMatch) return false;
          } else if (colType != selType) {
            return false;
          }
        }
      }

      // 3. Search Query Filter
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchesName = entry.loaneeName.toLowerCase().contains(query);
        final matchesCustId = entry.customerId.toLowerCase().contains(query);
        final matchesAcc = entry.accountNumber.toLowerCase().contains(query);
        final matchesMobile = entry.mobileNo.contains(query);
        final matchesAddress = entry.loaneeAddress.toLowerCase().contains(query);
        if (!matchesName && !matchesCustId && !matchesAcc && !matchesMobile && !matchesAddress) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // SYNC WITH SUPABASE TABLES
  Future<void> fetchFromSupabase() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final remoteRoutes = await SupabaseService.instance.fetchRoutes();
      if (remoteRoutes != null) {
        _routes.clear();
        _routes.addAll(remoteRoutes);
      }
      if (!_routes.any((r) => isOfficeRoute(r.name))) {
        _routes.insert(
          0,
          RouteModel(
            id: 'ROUTE-OFFICE-MASTER',
            name: 'Office',
            code: 'OFFICE',
            description: 'Master Office Route - Admin Direct Collections',
            isActive: true,
          ),
        );
      }

      final remoteEntries = await SupabaseService.instance.fetchCollectionEntries();
      if (remoteEntries != null) {
        final seenEntryIds = <String>{};
        _collectionEntries.clear();
        for (var e in remoteEntries) {
          if (e.id.isNotEmpty && !seenEntryIds.contains(e.id)) {
            seenEntryIds.add(e.id);
            _collectionEntries.add(e);
          } else if (e.id.isEmpty) {
            _collectionEntries.add(e);
          }
        }
      }

      final remotePayments = await SupabaseService.instance.fetchAllCollectionPayments();
      if (remotePayments != null) {
        final seenPaymentIds = <String>{};
        _payments.clear();
        for (var p in remotePayments) {
          final key = p.id.isNotEmpty ? p.id : '${p.collectionId}_${p.createdAt.toIso8601String()}';
          if (!seenPaymentIds.contains(key)) {
            seenPaymentIds.add(key);
            _payments.add(p);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching data from Supabase: $e');
    }

    _isSyncing = false;
    notifyListeners();
  }
}
