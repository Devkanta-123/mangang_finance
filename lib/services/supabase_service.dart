// lib/services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loanee_model.dart';
import '../models/ro_model.dart';
import '../models/route_model.dart';
import '../models/ro_collection_entry_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();

  SupabaseService._internal();

  static const String projectName = 'mangang_finance';
  
  // Base Supabase URL & Anon Public Key
  static const String supabaseUrl = 'https://kjgvkmkaushmujofudak.supabase.co';
  static const String supabaseAnonKey = 
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqZ3ZrbWthdXNobXVqb2Z1ZGFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5MDM2NTUsImV4cCI6MjEwMTQ3OTY1NX0.ZpFmognyhJR1t_O-O1rczI-aUAx-HogkLe7DGlLpt5E';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize Supabase client
  Future<void> initialize({String? customUrl, String? customAnonKey}) async {
    String url = customUrl ?? supabaseUrl;
    String anonKey = customAnonKey ?? supabaseAnonKey;

    try {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
      debugPrint('✅ Supabase initialized successfully for project: $projectName');
    } catch (e) {
      debugPrint('❌ Supabase initialization error: $e');
      _isInitialized = false;
    }
  }

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Explicit Pre-flight Connection Check to Supabase
  Future<bool> checkConnection() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        // Querying the table to verify live network & table accessibility
        await supaClient.from('loanee_accounts').select('customerid').limit(1);
        debugPrint('✅ Supabase pre-flight connection check SUCCESS');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Supabase connection check failed: $e');
    }
    return false;
  }

  /// Save loanee account to Supabase 'loanee_accounts' table
  Future<bool> saveLoaneeAccount(LoaneeAccount loanee) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final payload = loanee.toJson();
        
        await supaClient
            .from('loanee_accounts')
            .upsert(
              payload,
              onConflict: 'customerid',
            )
            .select();
            
        debugPrint('✅ Successfully saved loanee ${loanee.customerid} to Supabase.');
        return true;
      } else {
        debugPrint('⚠️ Supabase client not initialized');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error saving loanee to Supabase: $e');
      return false;
    }
  }

  /// Fetch loanee accounts from Supabase 'loanee_accounts' table
  Future<List<LoaneeAccount>?> fetchLoaneeAccounts() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('loanee_accounts')
            .select('*')
            .order('customerid', ascending: true);
            
        if (response.isNotEmpty) {
          return response
              .map((item) => LoaneeAccount.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching loanees from Supabase: $e');
    }
    return null;
  }

  /// Delete loanee account
  Future<bool> deleteLoaneeAccount(String customerId) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient
            .from('loanee_accounts')
            .delete()
            .match({'customerid': customerId});
            
        debugPrint('✅ Successfully deleted loanee $customerId');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting loanee: $e');
    }
    return false;
  }

  // ==========================================
  // RO ACCOUNTS METHODS
  // ==========================================

  /// Save RO account to Supabase 'ro_accounts' table
  Future<bool> saveRoAccount(RoAccount ro) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final payload = ro.toJson();
        
        await supaClient
            .from('ro_accounts')
            .upsert(
              payload,
              onConflict: 'customerid',
            )
            .select();
            
        debugPrint('✅ Successfully saved RO ${ro.customerid} to Supabase.');
        return true;
      } else {
        debugPrint('⚠️ Supabase client not initialized');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error saving RO to Supabase: $e');
      return false;
    }
  }

  /// Fetch RO accounts from Supabase 'ro_accounts' table
  Future<List<RoAccount>?> fetchRoAccounts() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('ro_accounts')
            .select('*')
            .order('customerid', ascending: true);
            
        if (response.isNotEmpty) {
          return response
              .map((item) => RoAccount.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching RO accounts from Supabase: $e');
    }
    return null;
  }

  /// Delete RO account
  Future<bool> deleteRoAccount(String customerId) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient
            .from('ro_accounts')
            .delete()
            .match({'customerid': customerId});
            
        debugPrint('✅ Successfully deleted RO $customerId');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting RO account: $e');
    }
    return false;
  }

  // ==========================================
  // ROUTE MASTER METHODS
  // ==========================================

  Future<bool> saveRoute(RouteModel route) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient
            .from('route_master')
            .upsert(route.toJson(), onConflict: 'id')
            .select();
        debugPrint('✅ Successfully saved route ${route.name} to Supabase.');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error saving route to Supabase: $e');
    }
    return false;
  }

  Future<List<RouteModel>?> fetchRoutes() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('route_master')
            .select('*')
            .order('name', ascending: true);
        if (response.isNotEmpty) {
          return response
              .map((item) => RouteModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching routes from Supabase: $e');
    }
    return null;
  }

  Future<bool> deleteRoute(String id) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('route_master').delete().match({'id': id});
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting route: $e');
    }
    return false;
  }

  // ==========================================
  // R.O. COLLECTION SHEET METHODS
  // ==========================================

  Future<bool> saveCollectionEntry(RoCollectionEntry entry) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient
            .from('ro_collection_entries')
            .upsert(entry.toJson(), onConflict: 'id')
            .select();
        debugPrint('✅ Successfully saved collection entry for ${entry.loaneeName} to Supabase.');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error saving collection entry to Supabase: $e');
    }
    return false;
  }

  Future<List<RoCollectionEntry>?> fetchCollectionEntries() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('ro_collection_entries')
            .select('*')
            .order('created_at', ascending: false);
        if (response.isNotEmpty) {
          return response
              .map((item) => RoCollectionEntry.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching collection entries from Supabase: $e');
    }
    return null;
  }

  Future<bool> deleteCollectionEntry(String id) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('ro_collection_entries').delete().match({'id': id});
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting collection entry: $e');
    }
    return false;
  }
}