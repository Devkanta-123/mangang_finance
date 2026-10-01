// lib/providers/collection_sheet_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/route_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/collection_payment_model.dart';
import '../services/customer_id_service.dart';
import '../services/supabase_service.dart';
import 'settings_provider.dart';
import '../models/loanee_model.dart';
import 'loanee_provider.dart';
import '../services/payment_reconciliation_service.dart';
import '../models/missing_payment_model.dart';

class CollectionSheetProvider extends ChangeNotifier {
  // Routes Master List - Pulled directly from Supabase table route_master
  final List<RouteModel> _routes = [];

  // RO Collection Sheet Cards/Entries - Master cards in ro_collection_entries
  final List<RoCollectionEntry> _collectionEntries = [];

  // Dedicated Payment Records - Individual payments in ro_collection_payments
  final List<CollectionPaymentModel> _payments = [];

  // Dedicated Missing Payment Records - Missing payment logs in missing_payment_records (MISSING != PAYMENT)
  final List<MissingPaymentRecord> _missingRecords = [];

  // Set of collection IDs where historical missing Excel records have been uploaded.
  // BY DEFAULT: System auto does NOT run for any entry until historical records are uploaded.
  final Set<String> _authorizedAutoMissingEntryIds = {};

  // Map of collection IDs to the latest historical date audited by the uploaded Excel.
  final Map<String, DateTime> _excelAuditEndDates = {};

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  CollectionSheetProvider({bool autoFetch = true}) {
    _loadAuthorizedMissingEntryIds();
    if (autoFetch) {
      fetchFromSupabase();
    }
  }

  // Getters
  List<RouteModel> get routes => List.unmodifiable(_routes);
  List<RoCollectionEntry> get collectionEntries => List.unmodifiable(_collectionEntries);
  List<CollectionPaymentModel> get payments => List.unmodifiable(_payments);
  List<MissingPaymentRecord> get missingRecords => List.unmodifiable(_missingRecords);

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

  /// Fetch all missing payment records for a collection card ID (sorted chronological ascending)
  List<MissingPaymentRecord> getMissingRecordsForCollection(String collectionId) {
    final cleanId = collectionId.trim().toLowerCase();
    final list = _missingRecords.where((m) => m.collectionId.trim().toLowerCase() == cleanId).map((m) {
      final bool isExcel = m.source.toLowerCase().trim() == 'excel_import' ||
          m.source.toLowerCase().trim() == 'excel' ||
          (m.remarks ?? '').toLowerCase().contains('excel');
      if (isExcel) {
        // Excel uploaded missing records must always remain 1 week (1-week gap) as per user rule
        if (m.missingWeek != 1 || m.missingBalance != m.missingFine) {
          return m.copyWith(
            missingWeek: 1,
            missingBalance: m.missingFine,
          );
        }
        return m;
      }

      if (!m.isResolved && !m.isPaused && m.missingFine > 0) {
        final currentWeek = MissingPaymentRecord.calculateWeeks(missedDate: m.missedDate);
        final currentBalance = double.parse((m.missingFine * currentWeek).toStringAsFixed(2));
        if (m.missingWeek != currentWeek || m.missingBalance != currentBalance) {
          return m.copyWith(
            missingWeek: currentWeek,
            missingBalance: currentBalance,
          );
        }
      }
      return m;
    }).toList();
    list.sort((a, b) => a.missedDate.compareTo(b.missedDate));
    return list;
  }

  /// Total sum of missing pay for a collection card (uncleared/unresolved only)
  double getTotalMissingPayForCollection(String collectionId) {
    final cleanId = collectionId.trim().toLowerCase();
    return _missingRecords
        .where((m) => m.collectionId.trim().toLowerCase() == cleanId && !m.isResolved && m.paidDate == null)
        .fold(0.0, (sum, m) => sum + (m.missingPay > 0 ? m.missingPay : m.dayPayment));
  }

  /// Total sum of missing fine / balance for a collection card
  double getTotalMissingBalanceForCollection(String collectionId, {DateTime? asOfDate}) {
    final cleanId = collectionId.trim().toLowerCase();
    return _missingRecords.where((m) => m.collectionId.trim().toLowerCase() == cleanId).fold(0.0, (sum, m) {
      final bool isExcel = m.source.toLowerCase().trim() == 'excel_import' ||
          m.source.toLowerCase().trim() == 'excel' ||
          (m.remarks ?? '').toLowerCase().contains('excel');
      if (isExcel) {
        return sum + m.missingFine; // 1 week fine for excel upload
      }
      if (!m.isResolved && !m.isPaused && m.missingFine > 0) {
        final currentWeek = MissingPaymentRecord.calculateWeeks(missedDate: m.missedDate, asOfDate: asOfDate);
        return sum + double.parse((m.missingFine * currentWeek).toStringAsFixed(2));
      }
      return sum + m.missingBalance;
    });
  }

  /// Total count of all missing records for a collection card
  int getTotalMissingCountForCollection(String collectionId) {
    final cleanId = collectionId.trim().toLowerCase();
    return _missingRecords.where((m) => m.collectionId.trim().toLowerCase() == cleanId).length;
  }

  /// Count of active uncleared missing records for a collection card
  int getUnclearedMissingCountForCollection(String collectionId) {
    final cleanId = collectionId.trim().toLowerCase();
    return _missingRecords.where((m) => m.collectionId.trim().toLowerCase() == cleanId && !m.isResolved && m.paidDate == null).length;
  }

  /// Total sum of partial day payments recorded in missing logs for a collection card
  double getTotalDayPaymentForCollection(String collectionId) {
    final cleanId = collectionId.trim().toLowerCase();
    return _missingRecords
        .where((m) => m.collectionId.trim().toLowerCase() == cleanId)
        .fold(0.0, (sum, m) => sum + m.dayPayment);
  }
  /// Check whether missing records automation is authorized for an entry.
  /// Rule: By default, system auto does NOT run unless historical missing Excel
  /// has been uploaded and inserted for this entry.
  bool isMissingAutomationAuthorized(String collectionId, [String? accountNo, String? customerId]) {
    final colIdClean = collectionId.trim().toLowerCase();
    final accNoClean = accountNo?.trim().toLowerCase();
    final custIdClean = customerId?.trim().toLowerCase();

    if (_authorizedAutoMissingEntryIds.any((id) => id.trim().toLowerCase() == colIdClean)) return true;
    if (accNoClean != null && accNoClean.isNotEmpty && _authorizedAutoMissingEntryIds.any((id) => id.trim().toLowerCase() == accNoClean)) return true;
    if (custIdClean != null && custIdClean.isNotEmpty && _authorizedAutoMissingEntryIds.any((id) => id.trim().toLowerCase() == custIdClean)) return true;
    if (_excelAuditEndDates.keys.any((k) => k.trim().toLowerCase() == colIdClean)) return true;

    // Check if any missing record with Excel source or remarks exists for this entry
    final hasExcelRecord = _missingRecords.any((m) {
      final matches = m.collectionId.trim().toLowerCase() == colIdClean ||
          (accNoClean != null && accNoClean.isNotEmpty && (m.accountNo ?? '').trim().toLowerCase() == accNoClean) ||
          (custIdClean != null && custIdClean.isNotEmpty && (m.customerId ?? '').trim().toLowerCase() == custIdClean);
      if (!matches) return false;
      final src = m.source.toLowerCase().trim();
      if (src == 'excel_import' || src == 'excel' || src == 'past' || src == 'excel_upload') return true;
      final rem = (m.remarks ?? '').toLowerCase();
      return rem.contains('excel') || rem.contains('imported') || rem.contains('historical') || rem.contains('past');
    });
    if (hasExcelRecord) {
      _authorizedAutoMissingEntryIds.add(collectionId);
      return true;
    }
    return false;
  }

  /// Authorize missing records automation for an entry after Excel upload and set the audit boundary date.
  Future<void> authorizeMissingAutomationForEntry(String collectionId, {DateTime? auditEndDate, bool notify = true}) async {
    _authorizedAutoMissingEntryIds.add(collectionId);
    if (auditEndDate != null) {
      _excelAuditEndDates[collectionId] = DateTime(auditEndDate.year, auditEndDate.month, auditEndDate.day);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('authorized_auto_missing_entry_ids', _authorizedAutoMissingEntryIds.toList());
      if (auditEndDate != null) {
        await prefs.setString('excel_missing_audit_date_$collectionId', auditEndDate.toIso8601String());
      }
    } catch (_) {}

    // Persist to Supabase system_settings so all other Android devices/models share authorization & audit boundary
    if (SupabaseService.instance.isInitialized) {
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          if (auditEndDate != null) {
            await client.from('system_settings').upsert({
              'setting_key': 'excel_missing_audit_date_$collectionId',
              'setting_value': auditEndDate.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'setting_key');
          }
          await client.from('system_settings').upsert({
            'setting_key': 'authorized_auto_missing_entry_ids',
            'setting_value': _authorizedAutoMissingEntryIds.join(','),
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'setting_key');
        }
      } catch (e) {
        debugPrint('Note saving auto missing authorization to remote: $e');
      }
    }

    if (notify) {
      notifyListeners();
    }
  }

  DateTime? getExcelAuditEndDate(String collectionId) {
    final colIdClean = collectionId.trim().toLowerCase();
    for (final entry in _excelAuditEndDates.entries) {
      if (entry.key.trim().toLowerCase() == colIdClean) {
        return entry.value;
      }
    }

    // Fallback: If not cached in memory, inspect _missingRecords for any Excel records for this collection
    final excelRecords = _missingRecords.where((m) {
      if (m.collectionId.trim().toLowerCase() != colIdClean) return false;
      final src = m.source.toLowerCase().trim();
      if (src == 'excel_import' || src == 'excel' || src == 'past' || src == 'excel_upload') return true;
      final rem = (m.remarks ?? '').toLowerCase();
      return rem.contains('excel') || rem.contains('imported') || rem.contains('historical') || rem.contains('past');
    }).toList();

    if (excelRecords.isNotEmpty) {
      final maxDate = excelRecords
          .map((m) => DateTime(m.missedDate.year, m.missedDate.month, m.missedDate.day))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      _excelAuditEndDates[collectionId] = maxDate;
      return maxDate;
    }

    // Second fallback: Any existing missing record for this collection
    final anyRecords = _missingRecords.where((m) => m.collectionId.trim().toLowerCase() == colIdClean).toList();
    if (anyRecords.isNotEmpty) {
      final maxDate = anyRecords
          .map((m) => DateTime(m.missedDate.year, m.missedDate.month, m.missedDate.day))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return maxDate;
    }

    return null;
  }

  final Map<String, List<DateTime>> _lastAutoSkippedDuplicateDates = {};

  /// Get list of duplicate candidate dates skipped during the last auto assessment for this collection entry
  List<DateTime> getLastAutoSkippedDuplicateDates(String collectionId) {
    return _lastAutoSkippedDuplicateDates[collectionId] ?? [];
  }

  /// Add batch of missing payment records (from Excel import or system)
  /// Checks duplication: same date cannot be inserted
  void addMissingPaymentRecordsBatch(List<MissingPaymentRecord> records, {bool notify = true}) {
    for (final rec in records) {
      final existingIdx = _missingRecords.indexWhere((m) =>
          m.id == rec.id ||
          (m.collectionId == rec.collectionId &&
              m.missedDate.year == rec.missedDate.year &&
              m.missedDate.month == rec.missedDate.month &&
              m.missedDate.day == rec.missedDate.day));
      if (existingIdx >= 0) {
        // Same date cannot be inserted: skip duplicate!
        continue;
      } else {
        _missingRecords.add(rec);
      }
    }
    if (notify) {
      notifyListeners();
    }
  }

  /// Delete a single missing payment record
  Future<bool> deleteMissingPaymentRecord(String recordId) async {
    try {
      final success = await SupabaseService.instance.deleteMissingPaymentRecordsBatch([recordId]);
      _missingRecords.removeWhere((m) => m.id == recordId);
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('⚠️ Error in deleteMissingPaymentRecord: $e');
      _missingRecords.removeWhere((m) => m.id == recordId);
      notifyListeners();
      return false;
    }
  }

  /// Batch delete missing payment records by IDs
  Future<bool> deleteMissingPaymentRecordsBatch(List<String> recordIds) async {
    if (recordIds.isEmpty) return true;
    try {
      final success = await SupabaseService.instance.deleteMissingPaymentRecordsBatch(recordIds);
      final idSet = recordIds.toSet();
      _missingRecords.removeWhere((m) => idSet.contains(m.id));
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('⚠️ Error in deleteMissingPaymentRecordsBatch: $e');
      final idSet = recordIds.toSet();
      _missingRecords.removeWhere((m) => idSet.contains(m.id));
      notifyListeners();
      return false;
    }
  }

  /// Delete all missing payment records for a specific collection ID
  Future<bool> deleteAllMissingRecordsForCollection(String collectionId) async {
    final cleanId = collectionId.trim().toLowerCase();
    final idsToDelete = _missingRecords
        .where((m) => m.collectionId.trim().toLowerCase() == cleanId)
        .map((m) => m.id)
        .where((id) => id.isNotEmpty)
        .toList();
    try {
      bool success = await SupabaseService.instance.deleteMissingPaymentRecordsForCollection(collectionId);
      if (!success && idsToDelete.isNotEmpty) {
        success = await SupabaseService.instance.deleteMissingPaymentRecordsBatch(idsToDelete);
      } else if (success && idsToDelete.isNotEmpty) {
        await SupabaseService.instance.deleteMissingPaymentRecordsBatch(idsToDelete);
      }
      _missingRecords.removeWhere((m) => m.collectionId.trim().toLowerCase() == cleanId || idsToDelete.contains(m.id));
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('⚠️ Error in deleteAllMissingRecordsForCollection: $e');
      _missingRecords.removeWhere((m) => m.collectionId.trim().toLowerCase() == cleanId || idsToDelete.contains(m.id));
      notifyListeners();
      return false;
    }
  }

  /// Update an existing missing payment record
  Future<bool> updateMissingPaymentRecord(MissingPaymentRecord record) async {
    try {
      final success = await SupabaseService.instance.updateMissingPaymentRecord(record);
      final idx = _missingRecords.indexWhere((m) => m.id == record.id);
      if (idx >= 0) {
        _missingRecords[idx] = record;
      } else {
        _missingRecords.add(record);
      }
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('⚠️ Error in updateMissingPaymentRecord: $e');
      final idx = _missingRecords.indexWhere((m) => m.id == record.id);
      if (idx >= 0) {
        _missingRecords[idx] = record;
      } else {
        _missingRecords.add(record);
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadAuthorizedMissingEntryIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('authorized_auto_missing_entry_ids');
      if (ids != null) {
        _authorizedAutoMissingEntryIds.addAll(ids);
      }
      for (final id in _authorizedAutoMissingEntryIds) {
        final dStr = prefs.getString('excel_missing_audit_date_$id');
        if (dStr != null) {
          final dt = DateTime.tryParse(dStr);
          if (dt != null) {
            _excelAuditEndDates[id] = DateTime(dt.year, dt.month, dt.day);
          }
        }
      }
    } catch (_) {}
  }

  /// Case 1: When a loanee makes a partial payment (less than the required daily/weekly base installment),
  /// the remaining shortfall has late fine percentage applied (default 3%),
  /// and is inserted/updated into missing records with status 'partial'.
  Future<MissingPaymentRecord?> recordPartialPaymentMissingRecord({
    required RoCollectionEntry entry,
    required double paymentAmount,
    required double baseInstallment,
    required SettingsProvider settingsProvider,
    DateTime? paymentDate,
    String? remarks,
  }) async {
    if (paymentAmount >= baseInstallment) return null;

    final cleanDate = paymentDate ?? DateTime.now();
    final missedDate = DateTime(cleanDate.year, cleanDate.month, cleanDate.day, 12, 0, 0);

    final double unpaidShortfall = double.parse(
      (baseInstallment - paymentAmount).clamp(0.0, double.infinity).toStringAsFixed(2),
    );
    final double fineRatePct = settingsProvider.lateFinePercentage;
    final double missingFine = double.parse(
      (unpaidShortfall * (fineRatePct / 100.0)).toStringAsFixed(2),
    );
    final int missingWeek = MissingPaymentRecord.calculateWeeks(missedDate: missedDate, asOfDate: cleanDate);
    final double missingBalance = double.parse(
      (missingFine * missingWeek).toStringAsFixed(2),
    );

    final dateStr =
        '${cleanDate.year}${cleanDate.month.toString().padLeft(2, '0')}${cleanDate.day.toString().padLeft(2, '0')}';
    final recordId = 'MISS-${entry.id}-$dateStr';

    final rec = MissingPaymentRecord(
      id: recordId,
      accountId: entry.accountNumber,
      collectionId: entry.id,
      loaneeId: entry.customerId,
      customerId: entry.customerId,
      accountNo: entry.accountNumber,
      loaneeName: entry.loaneeName,
      mobileNo: entry.mobileNo,
      route: entry.route,
      collectionType: entry.isDaily ? 'daily' : 'weekly',
      missedDate: missedDate,
      dayPayment: paymentAmount,
      missingPay: unpaidShortfall,
      missingFine: missingFine,
      missingWeek: missingWeek,
      missingBalance: missingBalance,
      status: 'partial paid',
      source: 'collection',
      remarks: remarks ??
          'Partial Payment: ₹${paymentAmount.toStringAsFixed(2)} paid of ₹${baseInstallment.toStringAsFixed(2)}. Remaining: ₹${unpaidShortfall.toStringAsFixed(2)}, ${fineRatePct.toStringAsFixed(1)}% Fine: ₹${missingFine.toStringAsFixed(2)}',
      createdAt: missedDate,
      updatedAt: DateTime.now(),
    );

    final existingIdx = _missingRecords.indexWhere((m) =>
        m.id == rec.id ||
        (m.collectionId == rec.collectionId &&
            m.missedDate.year == rec.missedDate.year &&
            m.missedDate.month == rec.missedDate.month &&
            m.missedDate.day == rec.missedDate.day));

    if (existingIdx >= 0) {
      _missingRecords[existingIdx] = rec;
    } else {
      _missingRecords.add(rec);
    }

    if (SupabaseService.instance.isInitialized) {
      await SupabaseService.instance.saveMissingPaymentRecord(rec);
    }

    notifyListeners();
    return rec;
  }

  /// Case 2: When a payment is allocated to clear an existing missing/paused record,
  /// the missing record is marked resolved/cleared, its paidDate is set to the collection payment date,
  /// and it persists in-memory and Supabase.
  Future<MissingPaymentRecord?> clearPastMissingRecord({
    required MissingPaymentRecord missingRecord,
    required DateTime paidDate,
    required double amountPaidForMissing,
  }) async {
    final cleanPaidDate = DateTime(paidDate.year, paidDate.month, paidDate.day);
    final String formattedPaidDate = SettingsProvider.formatDate(cleanPaidDate);

    // If payment covers the entire missingPay (or balance):
    final bool isFullyCleared = amountPaidForMissing >= missingRecord.missingPay;

    // Recalculate weeks and balance as of the payment date
    final int resolvedWeek = missingRecord.missingFine > 0
        ? MissingPaymentRecord.calculateWeeks(missedDate: missingRecord.missedDate, asOfDate: cleanPaidDate)
        : (missingRecord.missingWeek > 0 ? missingRecord.missingWeek : 1);
    final double finalBalance = missingRecord.missingFine > 0
        ? double.parse((missingRecord.missingFine * resolvedWeek).toStringAsFixed(2))
        : missingRecord.missingBalance;

    // Requirement: No need to make basic pay zero when paid, let it be the old amount.
    final double preservedBasicPay = missingRecord.missingPay > 0
        ? missingRecord.missingPay
        : (amountPaidForMissing > 0 ? amountPaidForMissing : missingRecord.dayPayment);

    final updated = missingRecord.copyWith(
      status: isFullyCleared ? 'resolved' : 'partial paid',
      paidDate: cleanPaidDate,
      missingWeek: resolvedWeek,
      missingBalance: finalBalance,
      dayPayment: missingRecord.dayPayment + amountPaidForMissing,
      missingPay: preservedBasicPay,
      remarks: 'Paid ₹${amountPaidForMissing.toStringAsFixed(2)} on $formattedPaidDate [PAID_DATE:${cleanPaidDate.toIso8601String()}]',
      updatedAt: DateTime.now(),
    );

    final idx = _missingRecords.indexWhere((m) => m.id == missingRecord.id);
    if (idx >= 0) {
      _missingRecords[idx] = updated;
    } else {
      _missingRecords.add(updated);
    }

    if (SupabaseService.instance.isInitialized) {
      await SupabaseService.instance.saveMissingPaymentRecord(updated);
    }

    notifyListeners();
    return updated;
  }

  /// Ensures all payments for a specific collection card ID are loaded from Supabase into memory
  Future<List<CollectionPaymentModel>> fetchAllPaymentsForCollection(String collectionId) async {
    if (SupabaseService.instance.isInitialized) {
      try {
        final remote = await SupabaseService.instance.fetchPaymentsForCollection(collectionId);
        if (remote != null) {
          _payments.removeWhere((p) => p.collectionId == collectionId);
          _payments.addAll(remote);
          if (remote.isEmpty) {
            _dbTotalCollectedCache[collectionId] = 0.0;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching payments for collection $collectionId: $e');
      }
    }
    return getPaymentsForCollection(collectionId);
  }

  /// Calculates the strictly chronological ledger and audit reconciliation result
  /// for a collection entry.
  PaymentReconciliationResult? getReconciliationForCollection(
    String collectionId, {
    LoaneeAccount? loanee,
    RoCollectionEntry? entryOverride,
  }) {
    final entry = entryOverride ?? getCollectionEntryById(collectionId);
    if (entry == null) return null;
    final cardPayments = getPaymentsForCollection(collectionId);
    return PaymentReconciliationService.reconcileLedger(
      entry: entry,
      loanee: loanee,
      payments: cardPayments,
    );
  }

  final Map<String, double> _dbTotalCollectedCache = {};

  /// Calculate total amount paid for a collection card ID from payment table (with DB cache fallback)
  double getTotalPaidForCollection(String collectionId) {
    final cardPayments = getPaymentsForCollection(collectionId);
    final inMemSum = cardPayments.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final dbSum = _dbTotalCollectedCache[collectionId];
    if (dbSum != null && dbSum > inMemSum) {
      return dbSum;
    }
    return inMemSum;
  }

  /// Directly fetch total collected from public.ro_collection_payments for a collection ID
  /// Single source of truth from database
  Future<double> fetchTotalCollectedForCollection(String collectionId) async {
    final total = await SupabaseService.instance.fetchTotalCollectedForCollection(collectionId);
    _dbTotalCollectedCache[collectionId] = total;
    return total;
  }

  /// Add or update payments in memory cache from database
  void mergePayments(List<CollectionPaymentModel> newPayments) {
    if (newPayments.isEmpty) return;
    bool updated = false;
    for (final p in newPayments) {
      final idx = _payments.indexWhere((existing) => existing.id == p.id);
      if (idx >= 0) {
        _payments[idx] = p;
        updated = true;
      } else {
        _payments.add(p);
        updated = true;
      }
    }
    if (updated) {
      notifyListeners();
    }
  }

  /// Calculate total interest and overdue charges for a collection card ID from payment table
  /// (Sum of Total Late Payment Interest and Total Post Maturity Interest)
  double getTotalInterestForCollection(String collectionId) {
    return getTotalLatePaymentFeesForCollection(collectionId) +
        getTotalPostMaturityInterestForCollection(collectionId);
  }

  /// Calculate total daily/weekly late payment fees for a collection card ID from payment table
  /// (Reads from table column lateFine for payments, or interest for historical imported records)
  double getTotalLatePaymentFeesForCollection(String collectionId) {
    final cardPayments = getPaymentsForCollection(collectionId);
    return cardPayments.fold(0.0, (sum, p) => sum + p.effectiveLateFine);
  }

  /// Calculate total post-maturity interest/fine for a collection card ID from payment table
  double getTotalPostMaturityInterestForCollection(String collectionId) {
    final cardPayments = getPaymentsForCollection(collectionId);
    return cardPayments.fold(0.0, (sum, p) => sum + p.postMaturityInterest);
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
    }).fold(0.0, (sum, p) => sum + p.effectiveLateFine);
  }

  /// Get unpaid late fee carried forward for a collection entry
  double getUnpaidLateFeeForCollection(String collectionId) {
    final entry = getCollectionEntryById(collectionId);
    if (entry == null) return 0.0;
    final cardPayments = getPaymentsForCollection(collectionId);
    return SettingsProvider.calculatePreviousUnpaidLateFee(
      entry: entry,
      payments: cardPayments,
    );
  }

  /// Get the latest remaining balance for a collection card ID.
  /// Dynamically computes (initialBal + totalInterest - totalPaid) so that
  /// all past payment records in ro_collection_payments are subtracted from the initial balance.
  /// Note: Unpaid late fees are tracked separately and NOT automatically added to the loan remaining balance.
  double getLatestRemainingBalance(String collectionId, [double fallback = 0.0]) {
    final entry = getCollectionEntryById(collectionId);
    final initialBal = fallback > 0
        ? fallback
        : (entry != null ? entry.initialBalance : 0.0);
    if (initialBal > 0) {
      final totalPaid = getTotalPaidForCollection(collectionId);
      final totalInterest = getTotalInterestForCollection(collectionId);
      return (initialBal + totalInterest - totalPaid).clamp(0.0, double.infinity);
    }
    final cardPayments = getPaymentsForCollection(collectionId);
    if (cardPayments.isNotEmpty) {
      return cardPayments.first.remainingBalance;
    }
    return 0.0;
  }

  /// Get the total outstanding due including carried-forward unpaid late fee:
  /// (Remaining Balance + Unpaid Late Fee)
  double getLatestTotalOutstandingDue(String collectionId, [double fallback = 0.0]) {
    final bal = getLatestRemainingBalance(collectionId, fallback);
    final unpaidFee = getUnpaidLateFeeForCollection(collectionId);
    return bal + unpaidFee;
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

  /// Checks whether a collection entry's loan amount and all accrued interest have been fully cleared (remaining balance <= 0).
  /// A loan is ONLY completed when:
  /// - Total collected from payment records strictly clears initial loan amount + all interest (remaining <= 0.01)
  /// - Total payable amount is 0.00
  /// - Under NO circumstances is a loan completed if there is an outstanding payable balance or unpaid interest,
  ///   even if the maturity date has passed, even if tenure elapsed, and even if paidAmount >= loanAmount.
  bool isEntryCompleted(RoCollectionEntry entry, {LoaneeProvider? loaneeProvider}) {
    // 1. Resolve LoaneeAccount if available
    LoaneeAccount? loanee;
    if (loaneeProvider != null) {
      loanee = loaneeProvider.getLoaneeForUser(
        customerId: entry.customerId,
        mobileNo: entry.mobileNo,
        name: entry.loaneeName,
      );
    }

    // 2. Authoritative loan amount
    final totalLoanAmount = (entry.loanAmount != null && entry.loanAmount! > 0)
        ? entry.loanAmount!
        : ((loanee != null && loanee.loanAmount > 0)
            ? loanee.loanAmount
            : entry.initialBalance);

    // 3. Dynamic payment calculation from ro_collection_payments records
    final totalCollected = getTotalPaidForCollection(entry.id);
    final totalInterest = getTotalInterestForCollection(entry.id);

    // If there is a loan amount defined
    if (totalLoanAmount > 0) {
      final remaining = (totalLoanAmount + totalInterest - totalCollected);
      // If remaining balance is greater than 0.01, loan is NOT completed under any circumstances!
      if (remaining > 0.01) {
        return false;
      }
      // If total collected clears the loan + all interest, then it is completed
      if (totalCollected > 0 && remaining <= 0.01) {
        return true;
      }
    }

    // 4. Check latest payment in ro_collection_payments
    final cardPayments = getPaymentsForCollection(entry.id);
    if (cardPayments.isNotEmpty) {
      final sorted = List<CollectionPaymentModel>.from(cardPayments)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (sorted.first.remainingBalance > 0.01) {
        return false;
      }
      if (sorted.first.remainingBalance <= 0.01 && totalCollected > 0) {
        return true;
      }
    }

    // 5. Check loanee dueAmount
    if (loanee != null) {
      if (loanee.dueAmount > 0.01) {
        return false;
      }
      if (loanee.loanAmount > 0 && loanee.dueAmount <= 0.01 && loanee.paidAmount > 0) {
        return true;
      }
    }

    // 6. Explicit closed/completed status ONLY if no outstanding due remains
    final entryStatus = entry.status.trim().toLowerCase();
    final loaneeStatus = loanee?.status.trim().toLowerCase() ?? '';
    if (entryStatus == 'closed' || entryStatus == 'completed' || loaneeStatus == 'closed' || loaneeStatus == 'completed') {
      if (totalCollected > 0) {
        return true;
      }
    }

    return false;
  }

  /// Returns the count of collection entries whose payments are fully completed
  int getCompletedEntriesCount({String? selectedRoute, LoaneeProvider? loaneeProvider}) {
    final list = (selectedRoute != null && selectedRoute.isNotEmpty && selectedRoute != 'All Routes')
        ? _collectionEntries.where((e) => e.route.trim().toLowerCase() == selectedRoute.trim().toLowerCase())
        : _collectionEntries;
    return list.where((e) => isEntryCompleted(e, loaneeProvider: loaneeProvider)).length;
  }

  /// Returns the count of collection entries whose payments are ongoing (not completed)
  int getOngoingEntriesCount({String? selectedRoute, LoaneeProvider? loaneeProvider}) {
    final list = (selectedRoute != null && selectedRoute.isNotEmpty && selectedRoute != 'All Routes')
        ? _collectionEntries.where((e) => e.route.trim().toLowerCase() == selectedRoute.trim().toLowerCase())
        : _collectionEntries;
    return list.where((e) => !isEntryCompleted(e, loaneeProvider: loaneeProvider)).length;
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

  /// Check if a collection card entry already exists for a Customer ID or Account Number
  bool hasCollectionEntry({required String customerId, required String accountNumber}) {
    final cleanCust = customerId.trim().toLowerCase();
    final cleanAcc = accountNumber.trim().toLowerCase();
    return _collectionEntries.any((e) =>
        (cleanCust.isNotEmpty && e.customerId.trim().toLowerCase() == cleanCust) ||
        (cleanAcc.isNotEmpty && e.accountNumber.trim().toLowerCase() == cleanAcc));
  }

  // COLLECTION SHEET CARD MASTER ENTRY METHODS
  Future<bool> addCollectionEntry(
    RoCollectionEntry entry, {
    bool saveToRemote = true,
  }) async {
    final cleanCust = entry.customerId.trim().toLowerCase();
    final cleanAcc = entry.accountNumber.trim().toLowerCase();

    // Check if card entry already exists for customerId & accountNumber
    final isDuplicate = _collectionEntries.any((e) =>
        (cleanCust.isNotEmpty && e.customerId.trim().toLowerCase() == cleanCust) ||
        (cleanAcc.isNotEmpty && e.accountNumber.trim().toLowerCase() == cleanAcc));

    if (isDuplicate) {
      debugPrint('⚠️ Duplicate collection card rejected: Cust: ${entry.customerId} / Acc: ${entry.accountNumber}');
      return false;
    }

    _collectionEntries.insert(0, entry);
    bool saved = true;
    if (saveToRemote) {
      saved = await SupabaseService.instance.saveCollectionEntry(entry);
    }
    notifyListeners();
    return saved;
  }

  /// Add dedicated payment record strictly to 'ro_collection_payments' table
  Future<bool> addCollectionPayment(
    CollectionPaymentModel payment, {
    bool suppressNotification = false,
    bool saveToRemote = true,
  }) async {
    // Check if this payment is clearing a past missing date
    final bool isMissingClearance =
        payment.remarks != null && payment.remarks!.contains('Cleared missing date:');

    if (isMissingClearance) {
      // Prevent exact duplicate missing payment clearance submission on same date
      final cardPayments = getPaymentsForCollection(payment.collectionId);
      final hasAlreadyClearedOnDate = cardPayments.any((p) =>
          p.remarks != null &&
          p.remarks!.contains('Cleared missing date:') &&
          p.createdAt.year == payment.createdAt.year &&
          p.createdAt.month == payment.createdAt.month &&
          p.createdAt.day == payment.createdAt.day &&
          p.id != payment.id);
      if (hasAlreadyClearedOnDate) {
        debugPrint(
            '⚠️ Duplicate missing payment clearance rejected on ${payment.createdAt.toString().split(' ')[0]}');
        return false;
      }
    } else if (hasPaymentForDate(payment.collectionId, payment.createdAt)) {
      debugPrint(
          '⚠️ Duplicate payment rejected: Collection ${payment.collectionId} already recorded on ${payment.createdAt.toString().split(' ')[0]}');
      return false;
    }

    _payments.insert(0, payment);

    if (saveToRemote) {
      notifyListeners();

      // Save payment to Supabase table ro_collection_payments
      final success = await SupabaseService.instance.saveCollectionPayment(payment);
      if (success && !suppressNotification && !SupabaseService.instance.arePaymentNotificationsSuppressed) {
        final parentCard = getCollectionEntryById(payment.collectionId);
        if (parentCard != null) {
          // Trigger notification creation fallback
          SupabaseService.instance.createCollectionPaymentNotifications(
            payment: payment,
            card: parentCard,
          );
        }
      }
    }
    return true;
  }

  /// Notify listeners after batch operations
  void notifyChanges() {
    notifyListeners();
  }

  /// Reverts a cleared/resolved missing payment record back to normal active missing state
  /// (unlocked, not frozen, paidDate null, status 'missing' or 'paused', recalculated balance).
  Future<MissingPaymentRecord?> revertClearedMissingRecord(
    MissingPaymentRecord missingRecord, {
    SettingsProvider? settingsProvider,
  }) async {
    final entry = getCollectionEntryById(missingRecord.collectionId);

    final cleanMissed = DateTime(missingRecord.missedDate.year, missingRecord.missedDate.month, missingRecord.missedDate.day, 12, 0, 0);
    final now = DateTime.now();

    final bool isPaused = (settingsProvider != null &&
            settingsProvider.isLateFinePaused(missingRecord.collectionId, cleanMissed, customerId: missingRecord.customerId)) ||
        (missingRecord.remarks?.toLowerCase().contains('pause') == true && missingRecord.missingFine == 0.0);

    final int weeks = isPaused
        ? 0
        : MissingPaymentRecord.calculateWeeks(missedDate: cleanMissed, asOfDate: now);

    final double basicPay = missingRecord.missingPay > 0
        ? missingRecord.missingPay
        : (missingRecord.dayPayment > 0 ? missingRecord.dayPayment : (entry?.isDaily == true ? 200.0 : 1500.0));

    final double finePct = settingsProvider?.lateFinePercentage ?? 3.0;
    final double fine = isPaused
        ? 0.0
        : (missingRecord.missingFine > 0
            ? missingRecord.missingFine
            : double.parse((basicPay * (finePct / 100.0)).toStringAsFixed(2)));

    final double balance = isPaused
        ? 0.0
        : double.parse((fine * (weeks > 0 ? weeks : 1)).toStringAsFixed(2));

    final reverted = missingRecord.copyWith(
      status: isPaused ? 'paused' : 'missing',
      clearPaidDate: true,
      missingWeek: weeks,
      missingBalance: balance,
      missingPay: basicPay,
      missingFine: fine,
      dayPayment: 0.0,
      remarks: isPaused
          ? 'Late Fine Paused on ${SettingsProvider.formatDate(cleanMissed)}'
          : '${missingRecord.isDaily ? "Daily" : "Weekly"} Missing Payment: ₹${basicPay.toStringAsFixed(2)}, Fine: ₹${fine.toStringAsFixed(2)} (Auto assessed for ${SettingsProvider.formatDate(cleanMissed)})',
      updatedAt: DateTime.now(),
    );

    final idx = _missingRecords.indexWhere((m) => m.id == missingRecord.id);
    if (idx >= 0) {
      _missingRecords[idx] = reverted;
    } else {
      _missingRecords.add(reverted);
    }

    if (SupabaseService.instance.isInitialized) {
      await SupabaseService.instance.saveMissingPaymentRecord(reverted);
    }

    notifyListeners();
    return reverted;
  }

  /// Finds and reverts any cleared missing record associated with a collection payment.
  Future<MissingPaymentRecord?> revertMissingRecordForPayment(
    CollectionPaymentModel payment, {
    SettingsProvider? settingsProvider,
  }) async {
    MissingPaymentRecord? target;

    // 1. Try finding missing record by MISSING_ID in remarks
    if (payment.remarks != null && payment.remarks!.contains('[MISSING_ID:')) {
      final match = RegExp(r'\[MISSING_ID:([^\]]+)\]').firstMatch(payment.remarks!);
      if (match != null) {
        final id = match.group(1)!.trim();
        target = _missingRecords.where((m) => m.id == id).firstOrNull;
      }
    }

    // 2. Try finding missing record by cleared date in remarks
    if (target == null && payment.remarks != null && payment.remarks!.contains('Cleared missing date:')) {
      final match = RegExp(r'Cleared missing date:\s*([^,\)\[]+)').firstMatch(payment.remarks!);
      if (match != null) {
        final dateStr = match.group(1)!.trim();
        final parsedDate = MissingPaymentRecord.parseCalendarDate(dateStr);
        target = _missingRecords.where((m) =>
            m.collectionId == payment.collectionId &&
            m.missedDate.year == parsedDate.year &&
            m.missedDate.month == parsedDate.month &&
            m.missedDate.day == parsedDate.day).firstOrNull;
      }
    }

    // 3. Try finding missing record matching collectionId and payment.createdAt
    target ??= _missingRecords.where((m) =>
        m.collectionId == payment.collectionId &&
        m.missedDate.year == payment.createdAt.year &&
        m.missedDate.month == payment.createdAt.month &&
        m.missedDate.day == payment.createdAt.day &&
        (m.isResolved || m.paidDate != null)).firstOrNull;

    // If still null, try refreshing from remote and re-checking
    if (target == null) {
      await refreshMissingRecordsForCollection(payment.collectionId);
      if (payment.remarks != null && payment.remarks!.contains('[MISSING_ID:')) {
        final match = RegExp(r'\[MISSING_ID:([^\]]+)\]').firstMatch(payment.remarks!);
        if (match != null) {
          final id = match.group(1)!.trim();
          target = _missingRecords.where((m) => m.id == id).firstOrNull;
        }
      }
      if (target == null && payment.remarks != null && payment.remarks!.contains('Cleared missing date:')) {
        final match = RegExp(r'Cleared missing date:\s*([^,\)\[]+)').firstMatch(payment.remarks!);
        if (match != null) {
          final dateStr = match.group(1)!.trim();
          final parsedDate = MissingPaymentRecord.parseCalendarDate(dateStr);
          target = _missingRecords.where((m) =>
              m.collectionId == payment.collectionId &&
              m.missedDate.year == parsedDate.year &&
              m.missedDate.month == parsedDate.month &&
              m.missedDate.day == parsedDate.day).firstOrNull;
        }
      }
      target ??= _missingRecords.where((m) =>
          m.collectionId == payment.collectionId &&
          m.missedDate.year == payment.createdAt.year &&
          m.missedDate.month == payment.createdAt.month &&
          m.missedDate.day == payment.createdAt.day &&
          (m.isResolved || m.paidDate != null)).firstOrNull;
    }

    if (target != null) {
      return await revertClearedMissingRecord(target, settingsProvider: settingsProvider);
    }
    return null;
  }

  /// Delete collection payment by ID
  Future<bool> deleteCollectionPayment(
    String paymentId, {
    SettingsProvider? settingsProvider,
  }) async {
    final payment = _payments.where((p) => p.id == paymentId).firstOrNull;
    if (payment != null) {
      await revertMissingRecordForPayment(payment, settingsProvider: settingsProvider);
    }
    _payments.removeWhere((p) => p.id == paymentId);
    notifyListeners();
    if (SupabaseService.instance.isInitialized) {
      return await SupabaseService.instance.deleteCollectionPayment(paymentId);
    }
    return true;
  }

  /// Delete all collection payments for a collection ID (in memory and remote database in one operation)
  Future<bool> deleteAllPaymentsForCollection(
    String collectionId, {
    SettingsProvider? settingsProvider,
  }) async {
    final resolvedMissing = _missingRecords.where((m) =>
        m.collectionId == collectionId && (m.isResolved || m.paidDate != null)).toList();
    for (final rec in resolvedMissing) {
      await revertClearedMissingRecord(rec, settingsProvider: settingsProvider);
    }
    _payments.removeWhere((p) => p.collectionId == collectionId);
    _dbTotalCollectedCache[collectionId] = 0.0;
    notifyListeners();
    if (SupabaseService.instance.isInitialized) {
      return await SupabaseService.instance.deleteAllPaymentsForCollection(collectionId);
    }
    return true;
  }

  /// Delete multiple collection payments by IDs in a single batch operation
  Future<bool> deleteCollectionPaymentsBatch(
    List<String> paymentIds, {
    SettingsProvider? settingsProvider,
  }) async {
    if (paymentIds.isEmpty) return true;
    final idsSet = paymentIds.toSet();
    final toDelete = _payments.where((p) => idsSet.contains(p.id)).toList();
    for (final p in toDelete) {
      await revertMissingRecordForPayment(p, settingsProvider: settingsProvider);
    }
    _payments.removeWhere((p) => idsSet.contains(p.id));
    notifyListeners();
    if (SupabaseService.instance.isInitialized) {
      return await SupabaseService.instance.deleteCollectionPaymentsBatch(paymentIds);
    }
    return true;
  }

  /// Update an existing collection payment record in memory and Supabase
  Future<bool> updateCollectionPayment(CollectionPaymentModel updatedPayment) async {
    final idx = _payments.indexWhere((p) => p.id == updatedPayment.id);
    if (idx != -1) {
      _payments[idx] = updatedPayment;
    } else {
      _payments.insert(0, updatedPayment);
    }
    notifyListeners();

    if (SupabaseService.instance.isInitialized) {
      return await SupabaseService.instance.saveCollectionPayment(updatedPayment);
    }
    return true;
  }

  /// Deletes all automatically assessed PAY-LATE entries in ro_collection_payments falling within a date range
  Future<int> removeAutoLateFeesInDateRange({
    required String collectionId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final cleanFrom = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final cleanTo = DateTime(toDate.year, toDate.month, toDate.day);

    final cardPayments = getPaymentsForCollection(collectionId);
    final toRemove = cardPayments.where((p) {
      final isAuto = p.id.startsWith('PAY-LATE-') ||
          (p.remarks != null && p.remarks!.contains('Auto assessed'));
      if (!isAuto) return false;
      final clean = DateTime(p.createdAt.year, p.createdAt.month, p.createdAt.day);
      return !clean.isBefore(cleanFrom) && !clean.isAfter(cleanTo);
    }).toList();

    if (toRemove.isEmpty) return 0;

    final ids = toRemove.map((p) => p.id).toList();
    final ok = await deleteCollectionPaymentsBatch(ids);
    return ok ? ids.length : 0;
  }

  /// Synchronize and automatically insert monthly 7% Post-Maturity Fine records into 'ro_collection_payments'
  /// triggered strictly on the day-of-month of the original maturity date for all applicable monthly cycles.
  Future<List<CollectionPaymentModel>> syncAutoPostMaturityFinesForEntry({
    required RoCollectionEntry entry,
    required SettingsProvider settingsProvider,
    double? loaneeLoanAmount,
    LoaneeProvider? loaneeProvider,
    DateTime? asOfDate,
    DateTime? sanctionDate,
    bool saveToRemote = true,
  }) async {
    final now = asOfDate ?? DateTime.now();
    final cleanToday = DateTime(now.year, now.month, now.day);

    // 1. Resolve loanee and maturity date (Maturity Date is the strict source of truth)
    LoaneeAccount? loanee;
    if (loaneeProvider != null) {
      loanee = loaneeProvider.getLoaneeForUser(
        customerId: entry.customerId,
        mobileNo: entry.mobileNo,
        name: entry.loaneeName,
      );
    }

    final DateTime effectiveMaturity = loanee?.effectiveMaturityDate ??
        (loanee?.loanMaturityDate ?? LoaneeAccount.calculateMaturityDate(sanctionDate ?? loanee?.loanSanctionDate ?? entry.createdAt));
    final cleanMaturity = DateTime(effectiveMaturity.year, effectiveMaturity.month, effectiveMaturity.day);

    // If today is strictly before maturity date, loan is not past maturity
    if (cleanToday.isBefore(cleanMaturity)) {
      return [];
    }

    // 2. Authoritative initial loan balance
    final double? effectiveLoanAmount = loaneeLoanAmount ??
        ((loanee != null && loanee.loanAmount > 0)
            ? loanee.loanAmount
            : entry.loanAmount);
    final double initialLoan = (effectiveLoanAmount != null && effectiveLoanAmount > 0)
        ? effectiveLoanAmount
        : (entry.actualPrincipal ?? entry.initialBalance);

    if (initialLoan <= 0) {
      return [];
    }

    // 3. Existing payment records from ro_collection_payments
    final cardPayments = getPaymentsForCollection(entry.id);

    // If there are no real payment records in ro_collection_payments for this entry
    // (e.g. before Excel is uploaded or loan has empty transaction history),
    // strictly do NOT auto-insert post-maturity fines into empty data!
    if (!SettingsProvider.hasRealPayments(cardPayments)) {
      // Clean up any orphan auto-assessed post-maturity records that were generated while data was empty
      final orphanAutoPostMat = cardPayments.where((p) =>
          p.id.startsWith('PAY-POSTMAT-') ||
          (p.roId == 'SYS-AUTO' && p.postMaturityInterest > 0)
      ).toList();

      if (orphanAutoPostMat.isNotEmpty) {
        final orphanIds = orphanAutoPostMat.map((p) => p.id).toList();
        _payments.removeWhere((item) => orphanIds.contains(item.id));
        if (saveToRemote && SupabaseService.instance.isInitialized) {
          await SupabaseService.instance.deleteCollectionPaymentsBatch(orphanIds);
        }
        notifyListeners();
      }
      return [];
    }

    // 4. Candidate monthly cycle dates triggered strictly by maturity date's day-of-month
    // Example: Maturity Date = 18/01/2026 -> 18/01/2026, 18/02/2026, ... 18/09/2026 (up to today)
    final List<DateTime> candidateCycles = [];
    for (int k = 0; k < 1200; k++) {
      final cycleDate = SettingsProvider.addMonths(cleanMaturity, k);
      final cleanCycleDate = DateTime(cycleDate.year, cycleDate.month, cycleDate.day);
      if (cleanCycleDate.isAfter(cleanToday)) {
        break; // Stop at future dates
      }
      candidateCycles.add(cleanCycleDate);
    }

    if (candidateCycles.isEmpty) {
      return [];
    }

    // Combined chronological payment timeline tracking existing + newly created cycle events
    final List<CollectionPaymentModel> newlyCreatedRecords = [];
    final List<CollectionPaymentModel> workingTimeline = List<CollectionPaymentModel>.from(cardPayments);

    for (final cycleDate in candidateCycles) {
      final dateStr = '${cycleDate.year}${cycleDate.month.toString().padLeft(2, '0')}${cycleDate.day.toString().padLeft(2, '0')}';
      final expectedRecordId = 'PAY-POSTMAT-${entry.id}-$dateStr';

      // Duplicate Prevention Check:
      // Check if a post-maturity event for this account and monthly cycle already exists
      final bool alreadyAssessed = workingTimeline.any((p) {
        final s = p.status.toLowerCase().trim();
        if (s == 'failed' || s == 'cancelled') return false;

        if (p.id == expectedRecordId) return true;

        final sameYearMonth = p.createdAt.year == cycleDate.year && p.createdAt.month == cycleDate.month;
        if (sameYearMonth) {
          if (p.postMaturityInterest > 0) return true;
          if (p.remarks != null && p.remarks!.contains('Post Maturity')) return true;
        }
        return false;
      });

      if (alreadyAssessed) {
        continue;
      }

      // Eligible remaining balance immediately before this Post-Maturity event (strictly up to the day before)
      final cycleStart = DateTime(cycleDate.year, cycleDate.month, cycleDate.day, 0, 0, 0);
      final priorPayments = workingTimeline.where((p) {
        final s = p.status.toLowerCase().trim();
        if (s == 'failed' || s == 'cancelled') return false;
        return p.createdAt.isBefore(cycleStart);
      }).toList();

      final double totalPaidBefore = priorPayments.fold(0.0, (sum, p) => sum + p.paymentAmount);
      final double totalInterestBefore = priorPayments.fold(
        0.0,
        (sum, p) => sum + (p.effectiveLateFine + p.postMaturityInterest),
      );

      final double eligibleBalance = (initialLoan + totalInterestBefore - totalPaidBefore).clamp(0.0, double.infinity);

      // If loan was already cleared before this monthly cycle, stop assessing future cycles
      if (eligibleBalance <= 0.01) {
        break;
      }

      // Fixed 7% calculation on eligible remaining balance
      final double fineAmount = double.parse((eligibleBalance * 0.07).toStringAsFixed(2));
      if (fineAmount <= 0) {
        continue;
      }

      final double newRemaining = double.parse((eligibleBalance + fineAmount).toStringAsFixed(2));

      final record = CollectionPaymentModel(
        id: expectedRecordId,
        collectionId: entry.id,
        paymentAmount: 0.0,
        lateFine: 0.0,
        interest: 0.0,
        postMaturityInterest: fineAmount,
        remainingBalance: newRemaining,
        paymentType: 'Post Maturity Fine',
        roPasscode: '',
        roName: 'System (Auto)',
        roId: 'SYS-AUTO',
        roRoute: entry.route,
        createdAt: DateTime(cycleDate.year, cycleDate.month, cycleDate.day, 12, 0, 0),
        status: 'Success',
        remarks: 'Post Maturity Fine: ₹${fineAmount.toStringAsFixed(2)} (Auto assessed for 7% monthly overdue fine on balance ₹${eligibleBalance.toStringAsFixed(2)})',
      );

      newlyCreatedRecords.add(record);
      workingTimeline.add(record);
    }

    if (newlyCreatedRecords.isNotEmpty) {
      for (final rec in newlyCreatedRecords) {
        if (!_payments.any((p) => p.id == rec.id)) {
          _payments.insert(0, rec);
        }
      }

      if (saveToRemote && SupabaseService.instance.isInitialized) {
        await SupabaseService.instance.saveCollectionPaymentsBatch(newlyCreatedRecords);
      }

      notifyListeners();
    }

    return newlyCreatedRecords;
  }

  /// Synchronize and automatically insert missing payment log records into 'missing_payment_records'
  /// for completed missed collection days/weeks strictly before today (today is excluded).
  /// Architecture Rule: MISSING != PAYMENT. Missing records are NOT stored in ro_collection_payments.
  Future<List<MissingPaymentRecord>> syncAutoLateFeesForEntry({
    required RoCollectionEntry entry,
    required SettingsProvider settingsProvider,
    double? loaneeLoanAmount,
    LoaneeProvider? loaneeProvider,
    DateTime? asOfDate,
    DateTime? sanctionDate,
    bool saveToRemote = true,
    bool forceAuthorize = false,
  }) async {
    // Ensure this entry's missing records are up to date from remote before evaluation
    // to prevent cross-device/model race conditions and duplicate inserts
    if (saveToRemote && SupabaseService.instance.isInitialized) {
      try {
        final remote = await SupabaseService.instance.fetchMissingPaymentRecords(
          collectionId: entry.id,
        );
        for (final r in remote) {
          final idx = _missingRecords.indexWhere((m) => m.id == r.id);
          if (idx >= 0) {
            _missingRecords[idx] = r;
          } else {
            _missingRecords.add(r);
          }
        }
      } catch (e) {
        debugPrint('Note refreshing remote missing records prior to auto check: $e');
      }
    }

    // 0. RULE: By default, do NOT run system auto for any entry!
    // Automation strictly runs once historical missing records Excel data has been
    // uploaded and inserted successfully (or when forceAuthorize is explicitly true,
    // or when the loan has real payments recorded).
    final cardPayments = getPaymentsForCollection(entry.id);
    final auditEndDate = getExcelAuditEndDate(entry.id);
    final isAuthorized = forceAuthorize ||
        isMissingAutomationAuthorized(entry.id, entry.accountNumber, entry.customerId) ||
        auditEndDate != null ||
        SettingsProvider.hasRealPayments(cardPayments);

    if (!isAuthorized) {
      return [];
    }

    // If there are no real payment records in ro_collection_payments for this entry
    // and no historical Excel uploaded, strictly do NOT auto-insert missing records or post-maturity records,
    // and clean up any orphan records!
    if (!SettingsProvider.hasRealPayments(cardPayments) && auditEndDate == null) {
      final orphanAuto = cardPayments.where((p) =>
          p.id.startsWith('PAY-LATE-') ||
          p.id.startsWith('PAY-POSTMAT-') ||
          p.roId == 'SYS-AUTO' ||
          (p.remarks != null && p.remarks!.contains('Auto assessed'))
      ).toList();

      if (orphanAuto.isNotEmpty) {
        final orphanIds = orphanAuto.map((p) => p.id).toList();
        _payments.removeWhere((item) => orphanIds.contains(item.id));
        if (saveToRemote && SupabaseService.instance.isInitialized) {
          await SupabaseService.instance.deleteCollectionPaymentsBatch(orphanIds);
        }
        notifyListeners();
      }
      return [];
    }

    // 1. First sync monthly Post-Maturity fines so chronological balance and overdue charges are up to date
    await syncAutoPostMaturityFinesForEntry(
      entry: entry,
      settingsProvider: settingsProvider,
      loaneeLoanAmount: loaneeLoanAmount,
      loaneeProvider: loaneeProvider,
      asOfDate: asOfDate,
      sanctionDate: sanctionDate,
      saveToRemote: saveToRemote,
    );

    final bool isDaily = entry.isDaily;

    final now = asOfDate ?? DateTime.now();
    final cleanToday = DateTime(now.year, now.month, now.day);

    // 2. Identify real non-auto transaction in ro_collection_payments
    final allSuccessful = cardPayments.where((p) {
      final s = p.status.toLowerCase().trim();
      final hasFeeOrPayment = p.paymentAmount > 0 ||
          p.lateFine > 0 ||
          p.interest > 0 ||
          p.postMaturityInterest > 0;
      return s != 'failed' && s != 'cancelled' && hasFeeOrPayment;
    }).toList();

    // We exclude auto-assessed records so that candidate evaluation starts from the last real/historical transaction
    final nonAutoTx = allSuccessful.where((p) {
      final isAuto = p.id.startsWith('PAY-LATE-') ||
          p.id.startsWith('PAY-POSTMAT-') ||
          p.roId == 'SYS-AUTO' ||
          (p.remarks != null && p.remarks!.contains('Auto assessed'));
      return !isAuto;
    }).toList();

    if (nonAutoTx.isEmpty && auditEndDate == null) {
      return [];
    }

    // Resolve loanee if provider is supplied
    LoaneeAccount? loanee;
    if (loaneeProvider != null) {
      loanee = loaneeProvider.getLoaneeForUser(
        customerId: entry.customerId,
        mobileNo: entry.mobileNo,
        name: entry.loaneeName,
      );
    }
    final double? effectiveLoanAmount = loaneeLoanAmount ??
        ((loanee != null && loanee.loanAmount > 0)
            ? loanee.loanAmount
            : entry.loanAmount);

    // 3. Calculate late fine rate strictly as 3% of base installment (daily or weekly)
    final double baseInstallment = entry.getCalculatedPayableAmount(
      loaneeLoanAmount: effectiveLoanAmount,
      configuredInterestRate: settingsProvider.investmentInterestRate,
      configuredBasePrincipal: settingsProvider.investmentBaseAmount,
      configuredBaseDailyAmount: settingsProvider.baseDailyAmount,
      configuredWeeklyInstallment: settingsProvider.weeklyInstallmentAmount,
    );
    final double fineRate = double.parse((baseInstallment * (settingsProvider.lateFinePercentage / 100.0)).toStringAsFixed(2));
    if (fineRate <= 0) {
      return [];
    }

    // 4. Clean up any legacy PAY-LATE fake payment records from ro_collection_payments
    // (Migrating to missing_payment_records architecture: MISSING != PAYMENT)
    final legacyPayLate = cardPayments.where((p) {
      final isAutoLate = (p.id.startsWith('PAY-LATE-') ||
          (p.roId == 'SYS-AUTO' && p.paymentAmount == 0.0 && p.lateFine > 0)) &&
          !p.id.startsWith('PAY-POSTMAT-') &&
          p.paymentType != 'Post Maturity Fine';
      return isAutoLate;
    }).toList();

    if (legacyPayLate.isNotEmpty) {
      final legacyIds = legacyPayLate.map((p) => p.id).toSet();
      _payments.removeWhere((item) => legacyIds.contains(item.id));
      cardPayments.removeWhere((item) => legacyIds.contains(item.id));
      if (saveToRemote && SupabaseService.instance.isInitialized) {
        await SupabaseService.instance.deleteCollectionPaymentsBatch(legacyIds.toList());
      }
      notifyListeners();
    }

    // 5. Validate outstanding balance > 0 (loan not cleared)
    final totalCollected = cardPayments.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final double initialLoan = (entry.loanAmount != null && entry.loanAmount! > 0)
        ? entry.loanAmount!
        : ((effectiveLoanAmount != null && effectiveLoanAmount > 0)
            ? effectiveLoanAmount
            : (entry.actualPrincipal ?? 0.0));
    final double totalInterest = getTotalInterestForCollection(entry.id);
    final double currentRemainingBalance = (initialLoan > 0)
        ? (initialLoan + totalInterest - totalCollected).clamp(0.0, double.infinity)
        : (cardPayments.isNotEmpty && cardPayments.first.remainingBalance > 0
            ? cardPayments.first.remainingBalance
            : 0.0);

    final bool isCleared = (initialLoan > 0 && currentRemainingBalance <= 0.01) ||
        (cardPayments.isNotEmpty && cardPayments.first.remainingBalance <= 0.01 && totalCollected > 0);
    if (isCleared) {
      return [];
    }

    final List<DateTime> candidateDates = [];
    final List<DateTime> skippedHolidays = [];
    final List<DateTime> skippedPausedDates = [];

    // For both Daily and Weekly loans, late fine calculations must strictly start
    // forward from the latest real transaction, historical Excel audit date, or existing missing records.
    DateTime cleanBaseDate;
    final entryIdClean = entry.id.trim().toLowerCase();
    final entryAccClean = entry.accountNumber.trim().toLowerCase();
    final entryCustClean = entry.customerId.trim().toLowerCase();

    final existingMissingForEntry = _missingRecords.where((m) {
      if (m.collectionId.trim().toLowerCase() == entryIdClean) return true;
      if (entryAccClean.isNotEmpty && (m.accountNo ?? '').trim().toLowerCase() == entryAccClean) return true;
      if (entryCustClean.isNotEmpty && (m.customerId ?? '').trim().toLowerCase() == entryCustClean) return true;
      return false;
    }).toList();

    DateTime? latestExistingMissingDate;
    if (existingMissingForEntry.isNotEmpty) {
      latestExistingMissingDate = existingMissingForEntry
          .map((m) => DateTime(m.missedDate.year, m.missedDate.month, m.missedDate.day))
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }

    final effectiveSanction = sanctionDate ?? loanee?.loanSanctionDate;

    if (nonAutoTx.isNotEmpty) {
      final sorted = List<CollectionPaymentModel>.from(nonAutoTx)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final baseDate = sorted.first.createdAt;
      cleanBaseDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    } else if (auditEndDate != null) {
      cleanBaseDate = DateTime(auditEndDate.year, auditEndDate.month, auditEndDate.day);
    } else if (latestExistingMissingDate != null) {
      cleanBaseDate = latestExistingMissingDate;
    } else if (effectiveSanction != null) {
      cleanBaseDate = DateTime(effectiveSanction.year, effectiveSanction.month, effectiveSanction.day);
    } else {
      return [];
    }

    if (auditEndDate != null && auditEndDate.isAfter(cleanBaseDate)) {
      cleanBaseDate = DateTime(auditEndDate.year, auditEndDate.month, auditEndDate.day);
    }

    // Crucial: If missing records already exist up to date X, all candidate dates
    // must strictly start AFTER date X to prevent duplicate assessment across devices/models!
    if (latestExistingMissingDate != null && latestExistingMissingDate.isAfter(cleanBaseDate)) {
      cleanBaseDate = latestExistingMissingDate;
    }

    if (effectiveSanction != null) {
      final cleanSanction = DateTime(effectiveSanction.year, effectiveSanction.month, effectiveSanction.day);
      if (cleanSanction.isAfter(cleanBaseDate)) {
        cleanBaseDate = cleanSanction;
      }
    }

    // Clean up any existing auto-assessed PAY-LATE records generated on or before cleanBaseDate
    // or on/after cleanToday (e.g. erroneous past entries generated before Excel upload)
    final invalidPastAutoRecords = cardPayments.where((p) {
      final isAutoLate = (p.id.startsWith('PAY-LATE-') ||
          (p.roId == 'SYS-AUTO' && p.lateFine > 0) ||
          (p.remarks != null && p.remarks!.contains('Auto assessed') && p.lateFine > 0)) &&
          !p.id.startsWith('PAY-POSTMAT-') &&
          p.paymentType != 'Post Maturity Fine';
      if (!isAutoLate) return false;
      final pDate = DateTime(p.createdAt.year, p.createdAt.month, p.createdAt.day);
      return !pDate.isAfter(cleanBaseDate) || !pDate.isBefore(cleanToday);
    }).toList();

    if (invalidPastAutoRecords.isNotEmpty) {
      final invalidIds = invalidPastAutoRecords.map((p) => p.id).toSet();
      _payments.removeWhere((item) => invalidIds.contains(item.id));
      cardPayments.removeWhere((item) => invalidIds.contains(item.id));
      if (saveToRemote && SupabaseService.instance.isInitialized) {
        await SupabaseService.instance.deleteCollectionPaymentsBatch(invalidIds.toList());
      }
      notifyListeners();
    }

    if (isDaily) {
      if (cleanToday.isAfter(cleanBaseDate)) {
        final firstCheckDate = DateTime(cleanBaseDate.year, cleanBaseDate.month, cleanBaseDate.day + 1);
        DateTime current = firstCheckDate;
        while (current.isBefore(cleanToday)) {
          final isSunday = current.weekday == DateTime.sunday;
          final isHoliday = settingsProvider.isHoliday(current);
          final isPaused = settingsProvider.isLateFinePaused(entry.id, current, customerId: entry.customerId);

          if (isHoliday) {
            skippedHolidays.add(DateTime(current.year, current.month, current.day));
          }
          if (isPaused) {
            skippedPausedDates.add(DateTime(current.year, current.month, current.day));
          }
          if (!isSunday && !isHoliday && !isPaused) {
            candidateDates.add(DateTime(current.year, current.month, current.day));
          }
          current = DateTime(current.year, current.month, current.day + 1);
        }
      }
    } else {
      // Weekly scheme:
      // Overdue weeks are strictly evaluated forward from cleanBaseDate (after Excel file upload / latest real transaction)
      if (cleanToday.isAfter(cleanBaseDate)) {
        final int daysSinceBase = cleanToday.difference(cleanBaseDate).inDays;
        final int weeksElapsedSinceBase = daysSinceBase ~/ 7;
        final int maxTenureWeeks = settingsProvider.weeklyTenureWeeks.ceil();

        final double weeklyInstallmentToUse = baseInstallment > 0
            ? baseInstallment
            : settingsProvider.weeklyInstallmentAmount;
        final int weeksPaid = (weeklyInstallmentToUse > 0)
            ? (totalCollected / weeklyInstallmentToUse).floor()
            : 0;

        final int remainingTenureWeeks = (maxTenureWeeks - weeksPaid).clamp(0, maxTenureWeeks);
        final int weeksToAssess = weeksElapsedSinceBase.clamp(0, remainingTenureWeeks);

        for (int w = 1; w <= weeksToAssess; w++) {
          final candidate = DateTime(cleanBaseDate.year, cleanBaseDate.month, cleanBaseDate.day + (w * 7));
          if (candidate.isBefore(cleanToday)) {
            final isHoliday = settingsProvider.isHoliday(candidate);
            final isPaused = settingsProvider.isLateFinePaused(entry.id, candidate, customerId: entry.customerId);
            if (isHoliday) {
              skippedHolidays.add(candidate);
            } else if (isPaused) {
              skippedPausedDates.add(candidate);
            } else {
              candidateDates.add(candidate);
            }
          }
        }
      }

      // Purge any orphan weekly auto-records that do not match the valid candidate dates
      // (e.g. records created beyond remaining tenure or on paused weeks)
      final candidateDateKeys = candidateDates.map((d) => '${d.year}-${d.month}-${d.day}').toSet();
      final orphanWeeklyAuto = cardPayments.where((p) {
        final isAutoLate = (p.id.startsWith('PAY-LATE-') ||
            (p.roId == 'SYS-AUTO' && p.lateFine > 0) ||
            (p.remarks != null && p.remarks!.contains('Auto assessed') && p.lateFine > 0)) &&
            !p.id.startsWith('PAY-POSTMAT-') &&
            p.paymentType != 'Post Maturity Fine';
        if (!isAutoLate) return false;
        final dKey = '${p.createdAt.year}-${p.createdAt.month}-${p.createdAt.day}';
        return !candidateDateKeys.contains(dKey);
      }).toList();

      if (orphanWeeklyAuto.isNotEmpty) {
        final orphanIds = orphanWeeklyAuto.map((p) => p.id).toSet();
        _payments.removeWhere((item) => orphanIds.contains(item.id));
        cardPayments.removeWhere((item) => orphanIds.contains(item.id));
        if (saveToRemote && SupabaseService.instance.isInitialized) {
          await SupabaseService.instance.deleteCollectionPaymentsBatch(orphanIds.toList());
        }
        notifyListeners();
      }
    }

    if (candidateDates.isEmpty) {
      return [];
    }

    final List<DateTime> alreadyAssessedDates = [];
    final List<DateTime> newLateDates = [];
    final List<MissingPaymentRecord> newlyCreatedRecords = [];

    for (final candidate in candidateDates) {
      final paymentsOnDate = cardPayments.where((p) {
        final s = p.status.toLowerCase().trim();
        return p.createdAt.year == candidate.year &&
            p.createdAt.month == candidate.month &&
            p.createdAt.day == candidate.day &&
            s != 'failed' &&
            s != 'cancelled';
      }).toList();

      final double dayPayment = paymentsOnDate.fold(0.0, (sum, p) => sum + p.paymentAmount);
      // Check if borrower made full payment on this date
      if (dayPayment >= baseInstallment) {
        continue;
      }

      final dateStr = '${candidate.year}${candidate.month.toString().padLeft(2, '0')}${candidate.day.toString().padLeft(2, '0')}';
      final recordId = 'MISS-${entry.id}-$dateStr';

      // Check if missing payment record already exists for this exact date or deterministic ID
      final alreadyAssessed = _missingRecords.any((m) {
        if (m.id == recordId) return true;
        final matches = m.collectionId.trim().toLowerCase() == entryIdClean ||
            (entryAccClean.isNotEmpty && (m.accountNo ?? '').trim().toLowerCase() == entryAccClean) ||
            (entryCustClean.isNotEmpty && (m.customerId ?? '').trim().toLowerCase() == entryCustClean);
        if (!matches) return false;
        return m.missedDate.year == candidate.year &&
            m.missedDate.month == candidate.month &&
            m.missedDate.day == candidate.day;
      });
      if (alreadyAssessed) {
        alreadyAssessedDates.add(candidate);
        continue;
      }

      // Candidate date is a completed missed day/week needing missing-record entry
      newLateDates.add(candidate);

      final double missingPay = double.parse((baseInstallment - dayPayment).clamp(0.0, double.infinity).toStringAsFixed(2));
      final double missingFine = double.parse((missingPay * (settingsProvider.lateFinePercentage / 100.0)).toStringAsFixed(2));
      final int missingWeek = MissingPaymentRecord.calculateWeeks(missedDate: candidate, asOfDate: cleanToday);
      final double missingBalance = double.parse((missingFine * missingWeek).toStringAsFixed(2));

      final record = MissingPaymentRecord(
        id: recordId,
        accountId: entry.accountNumber,
        collectionId: entry.id,
        loaneeId: loanee?.customerid ?? entry.customerId,
        customerId: entry.customerId,
        accountNo: entry.accountNumber,
        loaneeName: entry.loaneeName,
        mobileNo: entry.mobileNo,
        route: entry.route,
        collectionType: isDaily ? 'daily' : 'weekly',
        missedDate: DateTime(candidate.year, candidate.month, candidate.day, 12, 0, 0),
        dayPayment: dayPayment,
        missingPay: missingPay,
        missingFine: missingFine,
        missingWeek: missingWeek,
        missingBalance: missingBalance,
        status: dayPayment > 0 ? 'partially_resolved' : 'missing',
        source: 'system',
        remarks: '${isDaily ? "Daily" : "Weekly"} Missing Payment: ₹${missingPay.toStringAsFixed(2)}, Fine: ₹${missingFine.toStringAsFixed(2)} (Auto assessed for ${SettingsProvider.formatDate(candidate)})',
        createdAt: DateTime(candidate.year, candidate.month, candidate.day, 12, 0, 0),
        updatedAt: DateTime.now(),
      );

      newlyCreatedRecords.add(record);
    }

    // Process skipped paused dates: create records with status 'paused' and 0 fine so they can be tracked & cleared
    for (final pDate in skippedPausedDates) {
      final paymentsOnDate = cardPayments.where((p) {
        final s = p.status.toLowerCase().trim();
        return p.createdAt.year == pDate.year &&
            p.createdAt.month == pDate.month &&
            p.createdAt.day == pDate.day &&
            s != 'failed' &&
            s != 'cancelled';
      }).toList();

      final double dayPayment = paymentsOnDate.fold(0.0, (sum, p) => sum + p.paymentAmount);
      if (dayPayment >= baseInstallment) continue;

      final dateStr = '${pDate.year}${pDate.month.toString().padLeft(2, '0')}${pDate.day.toString().padLeft(2, '0')}';
      final recordId = 'MISS-${entry.id}-$dateStr';

      final alreadyAssessed = _missingRecords.any((m) {
        if (m.id == recordId) return true;
        final matches = m.collectionId.trim().toLowerCase() == entryIdClean ||
            (entryAccClean.isNotEmpty && (m.accountNo ?? '').trim().toLowerCase() == entryAccClean) ||
            (entryCustClean.isNotEmpty && (m.customerId ?? '').trim().toLowerCase() == entryCustClean);
        if (!matches) return false;
        return m.missedDate.year == pDate.year &&
            m.missedDate.month == pDate.month &&
            m.missedDate.day == pDate.day;
      });
      if (alreadyAssessed) continue;

      final record = MissingPaymentRecord(
        id: recordId,
        accountId: entry.accountNumber,
        collectionId: entry.id,
        loaneeId: loanee?.customerid ?? entry.customerId,
        customerId: entry.customerId,
        accountNo: entry.accountNumber,
        loaneeName: entry.loaneeName,
        mobileNo: entry.mobileNo,
        route: entry.route,
        collectionType: isDaily ? 'daily' : 'weekly',
        missedDate: DateTime(pDate.year, pDate.month, pDate.day, 12, 0, 0),
        dayPayment: dayPayment,
        missingPay: (baseInstallment - dayPayment).clamp(0.0, double.infinity),
        missingFine: 0.0,
        missingWeek: 1,
        missingBalance: (baseInstallment - dayPayment).clamp(0.0, double.infinity),
        status: 'paused',
        source: 'system',
        remarks: 'Payment Paused by Admin for ${SettingsProvider.formatDate(pDate)}',
        createdAt: DateTime(pDate.year, pDate.month, pDate.day, 12, 0, 0),
        updatedAt: DateTime.now(),
      );

      newlyCreatedRecords.add(record);
    }

    // 6. Debug logging matching Requirement 19
    final StringBuffer logBuf = StringBuffer();
    logBuf.writeln('=== [AUTOMATIC MISSING PAYMENT RECORD SYNCHRONIZATION (${isDaily ? "DAILY" : "WEEKLY"})] ===');
    logBuf.writeln('Loan / Collection ID: ${entry.id} | Account: ${entry.accountNumber}');
    logBuf.writeln('Loanee Name: ${entry.loaneeName}');
    logBuf.writeln('Base Installment: ₹${baseInstallment.toStringAsFixed(2)} | Late Fine Rate: ${settingsProvider.lateFinePercentage.toStringAsFixed(1)}% | ${isDaily ? "Daily" : "Weekly"} Late Fee: ₹${fineRate.toStringAsFixed(2)}');
    logBuf.writeln('Outstanding Balance: ₹${currentRemainingBalance.toStringAsFixed(2)}');
    logBuf.writeln('Current Date: ${SettingsProvider.formatDate(cleanToday)}');
    logBuf.writeln('Latest Transaction / Start: ${SettingsProvider.formatDate(cleanBaseDate)}');
    logBuf.writeln('Candidate Dates:');
    for (final d in candidateDates) {
      logBuf.writeln('  ${SettingsProvider.formatDate(d)}');
    }
    logBuf.writeln('Excluded:');
    logBuf.writeln('  ${SettingsProvider.formatDate(cleanToday)} (today)');
    if (skippedHolidays.isNotEmpty) {
      logBuf.writeln('Official Holidays (Skipped):');
      for (final h in skippedHolidays) {
        final holidayInfo = settingsProvider.getHolidayForDate(h);
        logBuf.writeln('  ${SettingsProvider.formatDate(h)} (${holidayInfo?.description ?? "Official Holiday"})');
      }
    }
    if (skippedPausedDates.isNotEmpty) {
      logBuf.writeln('Paused Dates (Skipped):');
      for (final p in skippedPausedDates) {
        logBuf.writeln('  ${SettingsProvider.formatDate(p)} (Admin Paused)');
      }
    }
    if (alreadyAssessedDates.isNotEmpty) {
      logBuf.writeln('Already Assessed (Skipped):');
      for (final d in alreadyAssessedDates) {
        logBuf.writeln('  ${SettingsProvider.formatDate(d)}');
      }
    }
    if (newLateDates.isNotEmpty) {
      logBuf.writeln('New Missing Records:');
      for (final d in newLateDates) {
        logBuf.writeln('  ${SettingsProvider.formatDate(d)} → Fine ₹${fineRate.toStringAsFixed(2)}');
      }
    } else {
      logBuf.writeln('New Missing Records: None (all candidate dates already exist or were satisfied)');
    }
    logBuf.writeln('====================================================');
    debugPrint(logBuf.toString());

    _lastAutoSkippedDuplicateDates[entry.id] = List.from(alreadyAssessedDates);

    final List<MissingPaymentRecord> recordsToPersist = List.from(newlyCreatedRecords);

    // Refresh week and balance for any active, unresolved missing records for this entry
    for (int i = 0; i < _missingRecords.length; i++) {
      final rec = _missingRecords[i];
      if (rec.collectionId == entry.id && !rec.isResolved && !rec.isPaused && rec.missingFine > 0) {
        final bool isExcel = rec.source.toLowerCase().trim() == 'excel_import' ||
            rec.source.toLowerCase().trim() == 'excel' ||
            (rec.remarks ?? '').toLowerCase().contains('excel');
        if (isExcel) {
          // Excel uploaded missing records must always remain 1 week (1-week gap) as per user rule
          if (rec.missingWeek != 1 || rec.missingBalance != rec.missingFine) {
            final updated = rec.copyWith(
              missingWeek: 1,
              missingBalance: rec.missingFine,
              updatedAt: DateTime.now(),
            );
            _missingRecords[i] = updated;
            if (!recordsToPersist.any((r) => r.id == updated.id)) {
              recordsToPersist.add(updated);
            }
          }
          continue;
        }

        final currentWeek = MissingPaymentRecord.calculateWeeks(missedDate: rec.missedDate, asOfDate: cleanToday);
        final currentBal = double.parse((rec.missingFine * currentWeek).toStringAsFixed(2));
        if (rec.missingWeek != currentWeek || rec.missingBalance != currentBal) {
          final updated = rec.copyWith(
            missingWeek: currentWeek,
            missingBalance: currentBal,
            updatedAt: DateTime.now(),
          );
          _missingRecords[i] = updated;
          if (!recordsToPersist.any((r) => r.id == updated.id)) {
            recordsToPersist.add(updated);
          }
        }
      }
    }

    // 7. Insert new missing records in-memory and save to Supabase missing_payment_records table
    final List<MissingPaymentRecord> actuallyInsertedRecords = [];
    if (recordsToPersist.isNotEmpty) {
      final List<MissingPaymentRecord> finalPersistList = [];
      for (final rec in recordsToPersist) {
        final existingIdx = _missingRecords.indexWhere((m) =>
            m.id == rec.id ||
            ((m.collectionId.trim().toLowerCase() == rec.collectionId.trim().toLowerCase() ||
                (rec.accountNo != null && m.accountNo != null && m.accountNo!.trim().toLowerCase() == rec.accountNo!.trim().toLowerCase()) ||
                (rec.customerId != null && m.customerId != null && m.customerId!.trim().toLowerCase() == rec.customerId!.trim().toLowerCase())) &&
                m.missedDate.year == rec.missedDate.year &&
                m.missedDate.month == rec.missedDate.month &&
                m.missedDate.day == rec.missedDate.day));
        if (existingIdx >= 0) {
          if (newlyCreatedRecords.any((n) => n.id == rec.id)) {
            // Same date can't insert: skip duplicate!
            continue;
          }
          _missingRecords[existingIdx] = rec;
          finalPersistList.add(rec);
        } else {
          _missingRecords.add(rec);
          finalPersistList.add(rec);
          if (newlyCreatedRecords.any((n) => n.id == rec.id)) {
            actuallyInsertedRecords.add(rec);
          }
        }
      }

      if (saveToRemote && SupabaseService.instance.isInitialized && finalPersistList.isNotEmpty) {
        await SupabaseService.instance.saveMissingPaymentRecordsBatch(finalPersistList);
      }

      notifyListeners();
    }

    return actuallyInsertedRecords;
  }

  /// Synchronize automatic late fees across all active entries
  Future<int> syncAutoLateFeesForAllEntries({
    required SettingsProvider settingsProvider,
    LoaneeProvider? loaneeProvider,
    DateTime? asOfDate,
    bool saveToRemote = true,
  }) async {
    int totalCount = 0;
    for (final entry in _collectionEntries) {
      final list = await syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        loaneeProvider: loaneeProvider,
        asOfDate: asOfDate,
        saveToRemote: saveToRemote,
      );
      totalCount += list.length;
    }
    return totalCount;
  }

  Future<PaginatedPaymentsResult> getPaginatedPaymentHistory({
    int page = 1,
    int pageSize = 5,
    String? route,
    String? searchQuery,
    String? collectionId,
    DateTime? startDate,
    DateTime? endDate,
    bool ascending = false,
  }) async {
    // 1. Try fetching via database-level query from Supabase
    if (SupabaseService.instance.isInitialized) {
      try {
        final remoteResult = await SupabaseService.instance.fetchPaginatedPaymentHistory(
          page: page,
          pageSize: pageSize,
          route: route,
          searchQuery: searchQuery,
          collectionId: collectionId,
          startDate: startDate,
          endDate: endDate,
          ascending: ascending,
        );
        return remoteResult;
      } catch (e) {
        debugPrint('⚠️ Remote paginated history query failed, falling back to local: $e');
      }
    }

    // 2. In-memory fallback from provider payment store across all dates
    var filtered = List<CollectionPaymentModel>.from(_payments);

    if (collectionId != null && collectionId.isNotEmpty) {
      filtered = filtered.where((p) => p.collectionId == collectionId).toList();
    }

    if (route != null && route.isNotEmpty && route.toLowerCase() != 'all') {
      filtered = filtered.where((p) {
        if (p.roRoute != null && p.roRoute!.isNotEmpty) {
          return p.roRoute!.toLowerCase().trim() == route.toLowerCase().trim();
        }
        final card = getCollectionEntryById(p.collectionId);
        return card?.route.toLowerCase().trim() == route.toLowerCase().trim();
      }).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      filtered = filtered.where((p) {
        final card = getCollectionEntryById(p.collectionId);
        return p.id.toLowerCase().contains(q) ||
            (p.roName?.toLowerCase().contains(q) ?? false) ||
            (p.roRoute?.toLowerCase().contains(q) ?? false) ||
            (card?.loaneeName.toLowerCase().contains(q) ?? false) ||
            (card?.accountNumber.toLowerCase().contains(q) ?? false) ||
            (card?.customerId.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (startDate != null) {
      filtered = filtered.where((p) => !p.createdAt.isBefore(startDate)).toList();
    }
    if (endDate != null) {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      filtered = filtered.where((p) => !p.createdAt.isAfter(endOfDay)).toList();
    }

    // Stable Sort: Payment date ascending or descending, then ID
    // Uses effectiveSortDate so missing date payments cleared on latest date sort to the top!
    filtered.sort((a, b) {
      final dateCmp = ascending
          ? a.effectiveSortDate.compareTo(b.effectiveSortDate)
          : b.effectiveSortDate.compareTo(a.effectiveSortDate);
      if (dateCmp != 0) return dateCmp;
      return ascending ? a.id.compareTo(b.id) : b.id.compareTo(a.id);
    });

    final totalCount = filtered.length;
    final int from = (page - 1) * pageSize;
    final paged = (from < totalCount)
        ? filtered.skip(from).take(pageSize).toList()
        : <CollectionPaymentModel>[];

    return PaginatedPaymentsResult(
      payments: paged,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  // ==========================================
  // REALTIME POSTGRES CHANGES HANDLERS
  // ==========================================

  void handleRealtimePaymentInsert(CollectionPaymentModel payment) {
    final existingIndex = _payments.indexWhere((p) => p.id == payment.id);
    if (existingIndex == -1) {
      _payments.insert(0, payment);
      notifyListeners();
    }
  }

  void handleRealtimePaymentUpdate(CollectionPaymentModel payment) {
    final existingIndex = _payments.indexWhere((p) => p.id == payment.id);
    if (existingIndex != -1) {
      _payments[existingIndex] = payment;
      notifyListeners();
    } else {
      _payments.insert(0, payment);
      notifyListeners();
    }
  }

  void handleRealtimePaymentDelete(String id) {
    _payments.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void handleRealtimeEntryInsert(RoCollectionEntry entry) {
    final existingIndex = _collectionEntries.indexWhere((e) => e.id == entry.id);
    if (existingIndex == -1) {
      _collectionEntries.insert(0, entry);
      notifyListeners();
    }
  }

  void handleRealtimeEntryUpdate(RoCollectionEntry entry) {
    final existingIndex = _collectionEntries.indexWhere((e) => e.id == entry.id);
    if (existingIndex != -1) {
      _collectionEntries[existingIndex] = entry;
      notifyListeners();
    } else {
      _collectionEntries.insert(0, entry);
      notifyListeners();
    }
  }

  void handleRealtimeEntryDelete(String id) {
    _collectionEntries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void handleRealtimeMissingRecordUpsert(MissingPaymentRecord record) {
    final existingIndex = _missingRecords.indexWhere((m) => m.id == record.id);
    if (existingIndex != -1) {
      _missingRecords[existingIndex] = record;
    } else {
      _missingRecords.add(record);
    }
    notifyListeners();
  }

  void handleRealtimeMissingRecordDelete(String id) {
    _missingRecords.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  /// Ensure latest missing records for a specific collection entry are synced from remote
  Future<void> refreshMissingRecordsForCollection(String collectionId) async {
    if (!SupabaseService.instance.isInitialized) return;
    try {
      final remote = await SupabaseService.instance.fetchMissingPaymentRecords(collectionId: collectionId);
      for (final r in remote) {
        final idx = _missingRecords.indexWhere((m) => m.id == r.id);
        if (idx >= 0) {
          _missingRecords[idx] = r;
        } else {
          _missingRecords.add(r);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing missing records for collection $collectionId: $e');
    }
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

  String generateNextCustomerId({DateTime? now, Set<String>? reservedIds}) {
    final existingIds = _collectionEntries.map((e) => e.customerId).toSet();
    return CustomerIdService.generateLoaneeCustomerId(
      existingIds: existingIds,
      now: now,
      reservedIds: reservedIds,
    );
  }

  String generateNextAccountNumber({DateTime? now, Set<String>? reservedAccNos}) {
    final existingAccs = _collectionEntries.map((e) => e.accountNumber).toSet();
    return CustomerIdService.generateLoaneeAccountNumber(
      existingAccNos: existingAccs,
      now: now,
      reservedAccNos: reservedAccNos,
    );
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
      _dbTotalCollectedCache.clear();
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
            // Keep Payment History clean: exclude legacy fake payment records
            final isLegacyAutoLate = p.id.startsWith('PAY-LATE-') ||
                (p.roId == 'SYS-AUTO' && p.paymentAmount == 0.0 && p.lateFine > 0 && p.paymentType != 'Post Maturity Fine');
            if (!isLegacyAutoLate) {
              seenPaymentIds.add(key);
              _payments.add(p);
            }
          }
        }
      }

      // Fetch cross-device authorization and Excel audit dates from system_settings
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          final settingsRows = await client
              .from('system_settings')
              .select('*')
              .or('setting_key.ilike.excel_missing_audit_date_%,setting_key.eq.authorized_auto_missing_entry_ids');
          final list = settingsRows as List<dynamic>;
          for (final row in list) {
            final key = row['setting_key']?.toString() ?? '';
            final val = row['setting_value']?.toString() ?? '';
            if (key == 'authorized_auto_missing_entry_ids' && val.isNotEmpty) {
              final ids = val.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
              _authorizedAutoMissingEntryIds.addAll(ids);
            } else if (key.startsWith('excel_missing_audit_date_') && val.isNotEmpty) {
              final colId = key.replaceFirst('excel_missing_audit_date_', '');
              final dt = DateTime.tryParse(val);
              if (dt != null) {
                _excelAuditEndDates[colId] = DateTime(dt.year, dt.month, dt.day);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Note fetching auto missing settings from remote: $e');
      }

      final remoteMissing = await SupabaseService.instance.fetchMissingPaymentRecords();
      final seenMissingIds = <String>{};
      final List<MissingPaymentRecord> newMissingList = [];
      final now = DateTime.now();
      for (var m in remoteMissing) {
        if (m.id.isNotEmpty && !seenMissingIds.contains(m.id)) {
          seenMissingIds.add(m.id);
          final bool isExcel = m.source.toLowerCase().trim() == 'excel_import' ||
              m.source.toLowerCase().trim() == 'excel' ||
              m.source.toLowerCase().trim() == 'excel_upload' ||
              m.source.toLowerCase().trim() == 'past' ||
              (m.remarks ?? '').toLowerCase().contains('excel');
          if (isExcel) {
            _authorizedAutoMissingEntryIds.add(m.collectionId);
            final mCleanDate = DateTime(m.missedDate.year, m.missedDate.month, m.missedDate.day);
            final existingAudit = _excelAuditEndDates[m.collectionId];
            if (existingAudit == null || mCleanDate.isAfter(existingAudit)) {
              _excelAuditEndDates[m.collectionId] = mCleanDate;
            }
            if (m.missingWeek != 1 || m.missingBalance != m.missingFine) {
              m = m.copyWith(
                missingWeek: 1,
                missingBalance: m.missingFine,
              );
            }
          } else if (!m.isResolved && !m.isPaused && m.missingFine > 0) {
            final currentWeek = MissingPaymentRecord.calculateWeeks(missedDate: m.missedDate, asOfDate: now);
            final currentBalance = double.parse((m.missingFine * currentWeek).toStringAsFixed(2));
            if (m.missingWeek != currentWeek || m.missingBalance != currentBalance) {
              m = m.copyWith(
                missingWeek: currentWeek,
                missingBalance: currentBalance,
              );
            }
          }
          newMissingList.add(m);
        }
      }
      _missingRecords.clear();
      _missingRecords.addAll(newMissingList);
    } catch (e) {
      debugPrint('Error fetching data from Supabase: $e');
    }

    _isSyncing = false;
    notifyListeners();
  }

  @visibleForTesting
  void setMissingRecordsForTest(List<MissingPaymentRecord> records) {
    _missingRecords.clear();
    _missingRecords.addAll(records);
    notifyListeners();
  }
}
