// lib/providers/collection_sheet_provider.dart

import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../services/supabase_service.dart';

class CollectionSheetProvider extends ChangeNotifier {
  // Routes Master List - No dummy data; pulled directly from table
  final List<RouteModel> _routes = [];

  // RO Collection Sheet Entries - No dummy data; pulled directly from table
  final List<RoCollectionEntry> _collectionEntries = [];

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  CollectionSheetProvider() {
    fetchFromSupabase();
  }

  // Getters
  List<RouteModel> get routes => List.unmodifiable(_routes);
  List<RoCollectionEntry> get collectionEntries => List.unmodifiable(_collectionEntries);

  List<String> get routeNames {
    return _routes.where((r) => r.isActive).map((r) => r.name).toList();
  }

  double get totalCollectedAmount {
    return _collectionEntries.fold(0.0, (sum, item) => sum + item.collectedAmount);
  }

  int get totalEntriesCount => _collectionEntries.length;

  int get totalRoutesCount => _routes.length;

  // ROUTE MASTER METHODS
  Future<bool> addRoute(RouteModel route) async {
    // Prevent duplicate route names
    if (_routes.any((r) => r.name.trim().toLowerCase() == route.name.trim().toLowerCase())) {
      return false;
    }
    _routes.insert(0, route);
    notifyListeners();

    // Save directly to Supabase route_master table
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

  // COLLECTION SHEET ENTRY METHODS
  Future<bool> addCollectionEntry(RoCollectionEntry entry) async {
    _collectionEntries.insert(0, entry);
    notifyListeners();

    // Save directly to Supabase ro_collection_entries table
    await SupabaseService.instance.saveCollectionEntry(entry);
    return true;
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

  // FILTERING METHODS
  List<RoCollectionEntry> getFilteredEntries({
    String? selectedRoute,
    String? selectedType,
    String? searchQuery,
  }) {
    return _collectionEntries.where((entry) {
      // 1. Route Filter
      if (selectedRoute != null &&
          selectedRoute != 'All' &&
          selectedRoute != 'All Routes' &&
          selectedRoute.isNotEmpty) {
        if (entry.route.toLowerCase() != selectedRoute.toLowerCase()) {
          return false;
        }
      }

      // 2. Collection Type Filter
      if (selectedType != null &&
          selectedType != 'All' &&
          selectedType != 'All Types' &&
          selectedType.isNotEmpty) {
        if (entry.collectionType.toLowerCase() != selectedType.toLowerCase()) {
          return false;
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

  // SYNC WITH SUPABASE
  Future<void> fetchFromSupabase() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final remoteRoutes = await SupabaseService.instance.fetchRoutes();
      if (remoteRoutes != null) {
        _routes.clear();
        _routes.addAll(remoteRoutes);
      }

      final remoteEntries = await SupabaseService.instance.fetchCollectionEntries();
      if (remoteEntries != null) {
        _collectionEntries.clear();
        _collectionEntries.addAll(remoteEntries);
      }
    } catch (e) {
      debugPrint('Error fetching data from Supabase: $e');
    }

    _isSyncing = false;
    notifyListeners();
  }
}
