// lib/providers/ro_provider.dart
import 'package:flutter/material.dart';
import '../models/ro_model.dart';
import '../services/supabase_service.dart';

class RoProvider extends ChangeNotifier {
  final List<RoAccount> _roAccounts = [];

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  RoProvider() {
    fetchFromSupabase();
  }

  List<RoAccount> get roAccounts => List.unmodifiable(_roAccounts);

  int get totalRoAccounts => _roAccounts.length;
  int get totalRos => _roAccounts.length;

  Future<Map<String, dynamic>> addRoWithConnectionCheck(RoAccount ro) async {
    final isConnected = await SupabaseService.instance.checkConnection();
    if (!isConnected) {
      return {
        'success': false,
        'connectionFailed': true,
        'message': 'Failed to connect to Supabase database! Table insert aborted.',
      };
    }

    final saveSuccess = await SupabaseService.instance.saveRoAccount(ro);
    if (saveSuccess) {
      _roAccounts.insert(0, ro);
      notifyListeners();
      return {
        'success': true,
        'connectionFailed': false,
        'message': 'Successfully connected to Supabase and inserted RO account!',
      };
    } else {
      return {
        'success': false,
        'connectionFailed': false,
        'message': 'Connected to Supabase, but failed to insert RO record into table.',
      };
    }
  }

  Future<void> fetchFromSupabase() async {
    _isSyncing = true;
    notifyListeners();

    final remoteRos = await SupabaseService.instance.fetchRoAccounts();
    if (remoteRos != null) {
      _roAccounts.clear();
      _roAccounts.addAll(remoteRos);
    }
    _isSyncing = false;
    notifyListeners();
  }

  String generateNextCustomerId() {
    int nextId = 5001 + _roAccounts.length;
    return 'RO-CUST-$nextId';
  }

  String generateNextAccountNumber() {
    int nextAcc = 991001 + _roAccounts.length;
    return 'RO-ACC-$nextAcc';
  }

  RoAccount? getRoForUser({String? customerId, String? mobileNo, String? name}) {
    for (final r in _roAccounts) {
      if (customerId != null && customerId.isNotEmpty && r.customerId.trim().toLowerCase() == customerId.trim().toLowerCase()) {
        return r;
      }
      if (mobileNo != null && mobileNo.isNotEmpty && r.mobileNo.trim() == mobileNo.trim()) {
        return r;
      }
      if (name != null && name.isNotEmpty && r.roName.trim().toLowerCase() == name.trim().toLowerCase()) {
        return r;
      }
    }
    return null;
  }

  List<RoAccount> searchRoAccounts(String query) {
    if (query.isEmpty) return roAccounts;
    final lowerQuery = query.toLowerCase();
    return _roAccounts.where((r) {
      return r.roName.toLowerCase().contains(lowerQuery) ||
          r.customerId.toLowerCase().contains(lowerQuery) ||
          r.accountNumber.toLowerCase().contains(lowerQuery) ||
          r.mobileNo.contains(lowerQuery) ||
          r.aadharNo.contains(lowerQuery) ||
          r.designation.toLowerCase().contains(lowerQuery) ||
          r.route.toLowerCase().contains(lowerQuery) ||
          r.district.toLowerCase().contains(lowerQuery) ||
          r.guardianName.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
