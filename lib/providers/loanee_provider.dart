import 'package:flutter/material.dart';
import '../models/loanee_model.dart';
import '../services/customer_id_service.dart';
import '../services/supabase_service.dart';

class LoaneeProvider extends ChangeNotifier {
  // Empty list - no hardcoded dummy data; all data is fetched live from Supabase
  final List<LoaneeAccount> _loanees = [];

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  LoaneeProvider() {
    // Fetch live records directly from Supabase table on initialization
    fetchFromSupabase();
  }

  List<LoaneeAccount> get loanees => List.unmodifiable(_loanees);

  int get totalLoanees => _loanees.length;
  
  double get totalLoanAmount =>
      _loanees.fold(0, (sum, item) => sum + item.loanAmount);
      
  double get totalCollectedAmount =>
      _loanees.fold(0, (sum, item) => sum + item.paidAmount);

  double get totalDueAmount =>
      _loanees.fold(0, (sum, item) => sum + item.dueAmount);

  /// Check connection first, then save directly to Supabase table
  Future<Map<String, dynamic>> addLoaneeWithConnectionCheck(LoaneeAccount loanee) async {
    // 1. Pre-flight Supabase Connection Check
    final isConnected = await SupabaseService.instance.checkConnection();
    if (!isConnected) {
      return {
        'success': false,
        'connectionFailed': true,
        'message': 'Failed to connect to Supabase database! Table insert aborted.',
      };
    }

    // 2. Insert into Supabase table
    final saveSuccess = await SupabaseService.instance.saveLoaneeAccount(loanee);
    if (saveSuccess) {
      _loanees.insert(0, loanee);
      notifyListeners();
      return {
        'success': true,
        'connectionFailed': false,
        'message': 'Successfully connected to Supabase and inserted loanee account!',
      };
    } else {
      return {
        'success': false,
        'connectionFailed': false,
        'message': 'Connected to Supabase, but failed to insert record into table.',
      };
    }
  }

  /// Add multiple Loanees in batch (used during bulk import)
  Future<Map<String, dynamic>> addLoaneesBatchWithConnectionCheck(List<LoaneeAccount> newLoanees) async {
    if (newLoanees.isEmpty) {
      return {'success': true, 'count': 0, 'connectionFailed': false};
    }

    final isConnected = await SupabaseService.instance.checkConnection();
    if (!isConnected) {
      return {
        'success': false,
        'connectionFailed': true,
        'count': 0,
        'message': 'Failed to connect to Supabase database! Table insert aborted.',
      };
    }

    final saveSuccess = await SupabaseService.instance.saveLoaneeAccountsBatch(newLoanees);
    if (saveSuccess) {
      for (final loanee in newLoanees.reversed) {
        final existingIndex = _loanees.indexWhere((l) =>
            (l.customerId.isNotEmpty && l.customerId.trim().toLowerCase() == loanee.customerId.trim().toLowerCase()) ||
            (l.accountNumber.isNotEmpty && l.accountNumber.trim().toLowerCase() == loanee.accountNumber.trim().toLowerCase()));
        if (existingIndex != -1) {
          _loanees[existingIndex] = loanee;
        } else {
          _loanees.insert(0, loanee);
        }
      }
      notifyListeners();
      return {
        'success': true,
        'connectionFailed': false,
        'count': newLoanees.length,
        'message': 'Successfully imported ${newLoanees.length} loanees!',
      };
    } else {
      return {
        'success': false,
        'connectionFailed': false,
        'count': 0,
        'message': 'Connected to Supabase, but failed to batch insert loanee records.',
      };
    }
  }

  /// Batch update witness details for existing Loanees with connection test
  Future<Map<String, dynamic>> updateWitnessesBatchWithConnectionCheck(
      List<LoaneeAccount> updatedLoanees) async {
    final isConnected = await SupabaseService.instance.checkConnection();
    if (!isConnected) {
      return {
        'success': false,
        'connectionFailed': true,
        'count': 0,
        'message': 'Failed to connect to Supabase database! Table update aborted.',
      };
    }

    final batchSaved =
        await SupabaseService.instance.saveLoaneeAccountsBatch(updatedLoanees);
    if (batchSaved) {
      for (final updated in updatedLoanees) {
        final cleanCust = updated.customerId.trim().toLowerCase();
        final cleanAcc = updated.accountNumber.trim().toLowerCase();
        int foundIndex = -1;
        for (int i = 0; i < _loanees.length; i++) {
          if (_loanees[i].customerId.trim().toLowerCase() == cleanCust ||
              _loanees[i].accountNumber.trim().toLowerCase() == cleanAcc) {
            foundIndex = i;
            break;
          }
        }
        if (foundIndex != -1) {
          _loanees[foundIndex] = updated;
        } else {
          _loanees.add(updated);
        }
      }
      notifyListeners();
      return {
        'success': true,
        'connectionFailed': false,
        'count': updatedLoanees.length,
        'message':
            'Successfully updated witness details for ${updatedLoanees.length} loanees!',
      };
    } else {
      return {
        'success': false,
        'connectionFailed': false,
        'count': 0,
        'message':
            'Connected to Supabase, but failed to batch update witness records.',
      };
    }
  }

  /// Sync/Fetch live accounts directly from Supabase 'loanee_accounts' table
  Future<void> fetchFromSupabase() async {
    _isSyncing = true;
    notifyListeners();

    final remoteLoanees = await SupabaseService.instance.fetchLoaneeAccounts();
    if (remoteLoanees != null) {
      _loanees.clear();
      _loanees.addAll(remoteLoanees);
    }
    _isSyncing = false;
    notifyListeners();
  }

  /// Update account status for a Loanee in-memory & in Supabase table
  Future<bool> updateStatus(String customerId, String newStatus) async {
    final cleanCust = customerId.trim().toLowerCase();
    int foundIndex = -1;
    for (int i = 0; i < _loanees.length; i++) {
      if (_loanees[i].customerId.trim().toLowerCase() == cleanCust) {
        foundIndex = i;
        break;
      }
    }

    if (foundIndex != -1) {
      _loanees[foundIndex] = _loanees[foundIndex].copyWith(status: newStatus);
      notifyListeners();
    }

    // Persist live to Supabase
    final success = await SupabaseService.instance.updateLoaneeStatus(customerId, newStatus);
    return success;
  }

  /// Update entire Loanee record in-memory & in Supabase
  Future<bool> updateLoanee(LoaneeAccount updatedLoanee) async {
    final cleanCust = updatedLoanee.customerId.trim().toLowerCase();
    int foundIndex = -1;
    for (int i = 0; i < _loanees.length; i++) {
      if (_loanees[i].customerId.trim().toLowerCase() == cleanCust ||
          _loanees[i].accountNumber.trim().toLowerCase() == updatedLoanee.accountNumber.trim().toLowerCase()) {
        foundIndex = i;
        break;
      }
    }

    if (foundIndex != -1) {
      _loanees[foundIndex] = updatedLoanee;
    } else {
      _loanees.insert(0, updatedLoanee);
    }
    notifyListeners();

    // Persist live to Supabase
    final success = await SupabaseService.instance.saveLoaneeAccount(updatedLoanee);
    return success;
  }

  /// Delete Loanee account
  Future<bool> deleteLoanee(String customerId) async {
    final cleanCust = customerId.trim().toLowerCase();
    _loanees.removeWhere((l) => l.customerId.trim().toLowerCase() == cleanCust);
    notifyListeners();
    return await SupabaseService.instance.deleteLoaneeAccount(customerId);
  }

  /// Toggle status between Active and Inactive
  Future<bool> toggleStatus(LoaneeAccount loanee) async {
    final nextStatus = loanee.isActive ? 'Inactive' : 'Active';
    return await updateStatus(loanee.customerId, nextStatus);
  }

  String generateNextCustomerId({DateTime? now, Set<String>? reservedIds}) {
    return CustomerIdService.generateLoaneeCustomerId(
      existingLoanees: _loanees,
      now: now,
      reservedIds: reservedIds,
    );
  }

  String generateNextAccountNumber({DateTime? now, Set<String>? reservedAccNos}) {
    return CustomerIdService.generateLoaneeAccountNumber(
      existingLoanees: _loanees,
      now: now,
      reservedAccNos: reservedAccNos,
    );
  }

  LoaneeAccount? getLoaneeForUser({String? customerId, String? mobileNo, String? name}) {
    for (final l in _loanees) {
      if (customerId != null && customerId.isNotEmpty && l.customerId.trim().toLowerCase() == customerId.trim().toLowerCase()) {
        return l;
      }
      if (mobileNo != null && mobileNo.isNotEmpty && l.mobileNo.trim() == mobileNo.trim()) {
        return l;
      }
      if (name != null && name.isNotEmpty && l.loaneeName.trim().toLowerCase() == name.trim().toLowerCase()) {
        return l;
      }
    }
    return null;
  }

  List<LoaneeAccount> searchLoanees(String query) {
    if (query.isEmpty) return loanees;
    final lowerQuery = query.toLowerCase();
    return _loanees.where((l) {
      return l.loaneeName.toLowerCase().contains(lowerQuery) ||
          l.customerId.toLowerCase().contains(lowerQuery) ||
          l.accountNumber.toLowerCase().contains(lowerQuery) ||
          l.mobileNo.contains(lowerQuery) ||
          l.district.toLowerCase().contains(lowerQuery) ||
          l.witnessName.toLowerCase().contains(lowerQuery) ||
          l.witnessMobileNo.contains(lowerQuery) ||
          l.witnessRelationship.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  void recordPaymentForLoanee({
    required String customerId,
    required String accountNumber,
    required double paymentAmount,
    required double newRemainingBalance,
  }) {
    final cleanCust = customerId.trim().toLowerCase();
    final cleanAcc = accountNumber.trim().toLowerCase();

    for (int i = 0; i < _loanees.length; i++) {
      final l = _loanees[i];
      final matchCust = cleanCust.isNotEmpty && l.customerId.trim().toLowerCase() == cleanCust;
      final matchAcc = cleanAcc.isNotEmpty && l.accountNumber.trim().toLowerCase() == cleanAcc;

      if (matchCust || matchAcc) {
        _loanees[i] = l.copyWith(
          paidamount: l.paidamount + paymentAmount,
          dueamount: newRemainingBalance,
          status: newRemainingBalance <= 0 ? 'Closed' : l.status,
        );
        notifyListeners();
        break;
      }
    }
  }

  void handlePaymentDeleted({
    required String customerId,
    required String accountNumber,
    required double deletedPaymentAmount,
    required double newRemainingBalance,
  }) {
    final cleanCust = customerId.trim().toLowerCase();
    final cleanAcc = accountNumber.trim().toLowerCase();

    for (int i = 0; i < _loanees.length; i++) {
      final l = _loanees[i];
      final matchCust = cleanCust.isNotEmpty && l.customerId.trim().toLowerCase() == cleanCust;
      final matchAcc = cleanAcc.isNotEmpty && l.accountNumber.trim().toLowerCase() == cleanAcc;

      if (matchCust || matchAcc) {
        final double updatedPaid = (l.paidamount - deletedPaymentAmount).clamp(0.0, double.infinity);
        _loanees[i] = l.copyWith(
          paidamount: updatedPaid,
          dueamount: newRemainingBalance,
          status: newRemainingBalance <= 0 ? 'Closed' : 'Active',
        );
        notifyListeners();
        break;
      }
    }
  }

  // ==========================================
  // REALTIME POSTGRES CHANGES HANDLERS
  // ==========================================

  void handleRealtimeLoaneeInsert(LoaneeAccount loanee) {
    final cleanCust = loanee.customerId.trim().toLowerCase();
    final index = _loanees.indexWhere((l) => l.customerId.trim().toLowerCase() == cleanCust);
    if (index == -1) {
      _loanees.insert(0, loanee);
      notifyListeners();
    }
  }

  void handleRealtimeLoaneeUpdate(LoaneeAccount loanee) {
    final cleanCust = loanee.customerId.trim().toLowerCase();
    final index = _loanees.indexWhere((l) => l.customerId.trim().toLowerCase() == cleanCust);
    if (index != -1) {
      _loanees[index] = loanee;
      notifyListeners();
    } else {
      _loanees.insert(0, loanee);
      notifyListeners();
    }
  }

  void handleRealtimeLoaneeDelete(String customerId) {
    final cleanCust = customerId.trim().toLowerCase();
    _loanees.removeWhere((l) => l.customerId.trim().toLowerCase() == cleanCust);
    notifyListeners();
  }
}
