// lib/services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loanee_model.dart';
import '../models/ro_model.dart';
import '../models/route_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/user_model.dart';
import '../models/collection_payment_model.dart';

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
        try {
          await supaClient
              .from('ro_accounts')
              .upsert(
                payload,
                onConflict: 'customerid',
              )
              .select();
        } catch (colErr) {
          debugPrint('⚠️ Upsert with route column note: $colErr');
          final safePayload = Map<String, dynamic>.from(payload)..remove('route');
          await supaClient
              .from('ro_accounts')
              .upsert(
                safePayload,
                onConflict: 'customerid',
              )
              .select();
        }
            
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

  // ==========================================
  // USER AUTH & SECURITY PIN METHODS
  // ==========================================

  /// Save or Update User Auth Record in Supabase 'user_auth' table
  Future<bool> saveUserAuthRecord(UserAuthRecord record) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient
            .from('user_auth')
            .upsert(record.toSupabaseJson(), onConflict: 'id')
            .select();
        debugPrint('✅ Saved User Auth Record (${record.userType.name}) for ${record.mobileNo} to Supabase.');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error saving user auth record to Supabase: $e');
    }
    return false;
  }

  /// Verify and fetch User Auth Record by 6-Digit PIN from Supabase tables
  Future<UserAuthRecord?> fetchUserAuthByPin(String pin) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        // 1. Check primary 'user_auth' table
        try {
          final response = await supaClient
              .from('user_auth')
              .select('*')
              .eq('pin', pin)
              .maybeSingle();

          if (response != null && response.isNotEmpty) {
            return UserAuthRecord.fromJson(Map<String, dynamic>.from(response));
          }
        } catch (e) {
          debugPrint('⚠️ user_auth check: $e');
        }

        // 2. Check 'ro_accounts' table
        try {
          final roResponse = await supaClient
              .from('ro_accounts')
              .select('*')
              .or('pincode.eq.$pin,customerid.eq.$pin')
              .maybeSingle();

          if (roResponse != null && roResponse.isNotEmpty) {
            final data = Map<String, dynamic>.from(roResponse);
            return UserAuthRecord(
              id: data['customerid']?.toString() ?? '',
              mobileNo: data['mobileno']?.toString() ?? '',
              customerId: data['customerid']?.toString(),
              userType: UserType.ro,
              pin: pin,
              name: data['roname']?.toString() ?? 'RO Officer',
              roName: data['roname']?.toString(),
            );
          }
        } catch (e) {
          debugPrint('⚠️ ro_accounts PIN check: $e');
        }

        // 3. Check 'loanee_accounts' table
        try {
          final loaneeResponse = await supaClient
              .from('loanee_accounts')
              .select('*')
              .or('pincode.eq.$pin,customerid.eq.$pin')
              .maybeSingle();

          if (loaneeResponse != null && loaneeResponse.isNotEmpty) {
            final data = Map<String, dynamic>.from(loaneeResponse);
            return UserAuthRecord(
              id: data['customerid']?.toString() ?? '',
              mobileNo: data['mobileno']?.toString() ?? '',
              customerId: data['customerid']?.toString(),
              userType: UserType.loanee,
              pin: pin,
              name: data['loaneename']?.toString() ?? 'Loanee Account',
              accountName: data['accountnumber']?.toString(),
            );
          }
        } catch (e) {
          debugPrint('⚠️ loanee_accounts PIN check: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching user auth by PIN from Supabase: $e');
    }
    return null;
  }

  /// Reset or Update Security PIN for a specific Role in Supabase
  Future<bool> resetUserPinInSupabase({
    required UserType userType,
    required String mobileNo,
    String? customerId,
    required String newPin,
  }) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        // Query matching user by mobile_no or customer_id
        var query = supaClient.from('user_auth').select('*');
        if (customerId != null && customerId.trim().isNotEmpty) {
          query = query.eq('customer_id', customerId.trim());
        } else {
          query = query.eq('mobile_no', mobileNo.trim());
        }
        
        final response = await query;
        if (response.isNotEmpty) {
          final recordId = response.first['id'];
          await supaClient.from('user_auth').update({
            'pin': newPin,
            'user_type': userType.name,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', recordId);
          debugPrint('✅ Reset PIN in Supabase for $mobileNo (${userType.name})');
          return true;
        } else {
          // Create new record in Supabase if not previously registered
          final newRecord = UserAuthRecord(
            id: customerId?.isNotEmpty == true ? customerId! : mobileNo,
            mobileNo: mobileNo,
            customerId: customerId,
            userType: userType,
            pin: newPin,
            name: userType == UserType.admin
                ? 'Administrator'
                : (userType == UserType.ro ? 'RO Officer' : 'Loanee Account'),
          );
          return await saveUserAuthRecord(newRecord);
        }
      }
    } catch (e) {
      debugPrint('❌ Error resetting PIN in Supabase: $e');
    }
    return false;
  }

  // ==========================================
  // COLLECTION PAYMENTS SEPARATE TABLE METHODS
  // ==========================================

  /// Save individual payment record into Supabase 'ro_collection_payments' table
  Future<bool> saveCollectionPayment(CollectionPaymentModel payment) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final payload = payment.toJson();
        try {
          await supaClient
              .from('ro_collection_payments')
              .upsert(payload, onConflict: 'id')
              .select();
        } catch (colErr) {
          debugPrint('⚠️ Upsert ro_collection_payments fallback note: $colErr');
          final safePayload = Map<String, dynamic>.from(payload)..remove('ro_route');
          await supaClient
              .from('ro_collection_payments')
              .upsert(safePayload, onConflict: 'id')
              .select();
        }
        debugPrint('✅ Saved Collection Payment ${payment.id} for collection ${payment.collectionId} to Supabase.');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error saving payment to Supabase: $e');
    }
    return false;
  }

  /// Fetch payments for a specific collection sheet entry ID
  Future<List<CollectionPaymentModel>?> fetchPaymentsForCollection(String collectionId) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('ro_collection_payments')
            .select('*')
            .eq('collection_id', collectionId)
            .order('created_at', ascending: false);

        if (response.isNotEmpty) {
          return response
              .map((item) => CollectionPaymentModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching payments for collection $collectionId: $e');
    }
    return null;
  }

  /// Fetch all collection payment records from Supabase 'ro_collection_payments' table
  Future<List<CollectionPaymentModel>?> fetchAllCollectionPayments() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('ro_collection_payments')
            .select('*')
            .order('created_at', ascending: false);

        if (response.isNotEmpty) {
          return response
              .map((item) => CollectionPaymentModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching all collection payments: $e');
    }
    return null;
  }

  /// Delete collection payment by ID
  Future<bool> deleteCollectionPayment(String id) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('ro_collection_payments').delete().match({'id': id});
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting collection payment: $e');
    }
    return false;
  }
}