import 'package:flutter/material.dart';
import '../models/loanee_model.dart';
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

  String generateNextCustomerId() {
    int nextId = 1001 + _loanees.length;
    return 'CUST-$nextId';
  }

  String generateNextAccountNumber() {
    int nextAcc = 88239101 + _loanees.length;
    return 'ACC-$nextAcc';
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
        _loanees[i] = LoaneeAccount(
          customerid: l.customerid,
          accountnumber: l.accountnumber,
          loaneename: l.loaneename,
          guardianname: l.guardianname,
          address: l.address,
          businesstype: l.businesstype,
          postoffice: l.postoffice,
          policestation: l.policestation,
          district: l.district,
          pincode: l.pincode,
          mobileno: l.mobileno,
          aadharno: l.aadharno,
          createdat: l.createdat,
          status: newRemainingBalance <= 0 ? 'Closed' : l.status,
          loanamount: l.loanamount,
          paidamount: l.paidamount + paymentAmount,
          dueamount: newRemainingBalance,
          witnessname: l.witnessname,
          witnessguardianname: l.witnessguardianname,
          witnessaddress: l.witnessaddress,
          witnessbusinesstype: l.witnessbusinesstype,
          witnesspostoffice: l.witnesspostoffice,
          witnesspolicestation: l.witnesspolicestation,
          witnessdistrict: l.witnessdistrict,
          witnesspincode: l.witnesspincode,
          witnessmobileno: l.witnessmobileno,
          witnessaadharno: l.witnessaadharno,
          witnessrelationship: l.witnessrelationship,
        );
        notifyListeners();
        break;
      }
    }
  }
}

