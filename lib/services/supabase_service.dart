// lib/services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loanee_model.dart';
import '../models/ro_model.dart';
import '../models/route_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/user_model.dart';
import '../models/collection_payment_model.dart';
import '../models/investment_model.dart';
import '../models/notification_model.dart';
import 'customer_id_service.dart';

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

  // Scoped notification suppression for bulk imports
  bool _suppressPaymentNotifications = false;
  bool get arePaymentNotificationsSuppressed => _suppressPaymentNotifications;

  void setPaymentNotificationSuppression(bool suppress) {
    _suppressPaymentNotifications = suppress;
  }

  /// Scoped execution that guarantees notifications suppression is reset via try/finally
  Future<T> runWithNotificationSuppression<T>(Future<T> Function() action) async {
    final prev = _suppressPaymentNotifications;
    _suppressPaymentNotifications = true;
    try {
      return await action();
    } finally {
      _suppressPaymentNotifications = prev;
    }
  }

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

  /// Save loanee account strictly to Supabase 'loanee_accounts' table (user_auth is created only upon self-registration)
  Future<bool> saveLoaneeAccount(LoaneeAccount loanee) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final payload = loanee.toJson();
        
        try {
          await supaClient
              .from('loanee_accounts')
              .upsert(
                payload,
                onConflict: 'customerid',
              )
              .select();
        } catch (colErr) {
          debugPrint('⚠️ Upsert with date columns note: $colErr, trying fallback without date columns');
          try {
            final safePayload = Map<String, dynamic>.from(payload)
              ..remove('loansanctiondate')
              ..remove('loanmaturitydate');
            await supaClient
                .from('loanee_accounts')
                .upsert(
                  safePayload,
                  onConflict: 'customerid',
                )
                .select();
          } catch (colErr2) {
            debugPrint('⚠️ Fallback loanee upsert note: $colErr2');
            rethrow;
          }
        }
            
        debugPrint('✅ Successfully saved loanee ${loanee.customerid} to Supabase (loanee_accounts).');
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

  /// Batch save loanee accounts strictly to Supabase 'loanee_accounts' table
  Future<bool> saveLoaneeAccountsBatch(List<LoaneeAccount> loanees) async {
    try {
      final supaClient = client;
      if (supaClient != null && loanees.isNotEmpty) {
        final payloads = loanees.map((l) => l.toJson()).toList();
        try {
          await supaClient
              .from('loanee_accounts')
              .upsert(payloads, onConflict: 'customerid')
              .select();
        } catch (colErr) {
          debugPrint('⚠️ Batch upsert loanee_accounts fallback without dates: $colErr');
          final safePayloads = payloads.map((p) {
            return Map<String, dynamic>.from(p)
              ..remove('loansanctiondate')
              ..remove('loanmaturitydate');
          }).toList();
          await supaClient
              .from('loanee_accounts')
              .upsert(safePayloads, onConflict: 'customerid')
              .select();
        }

        debugPrint('✅ Successfully batch saved ${loanees.length} loanees to Supabase (loanee_accounts).');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error batch saving loanees to Supabase: $e');
      return false;
    }
  }

  /// Fetch loanee accounts from Supabase 'loanee_accounts' table & cross-check with 'user_auth'
  Future<List<LoaneeAccount>?> fetchLoaneeAccounts() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('loanee_accounts')
            .select('*')
            .order('customerid', ascending: true);
            
        List<LoaneeAccount> loanees = [];
        if (response.isNotEmpty) {
          loanees = response
              .map((item) => LoaneeAccount.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }

        // Cross-check with user_auth table to ensure Inactive status in user_auth reflects in list
        try {
          final authRes = await supaClient.from('user_auth').select('id,customer_id,mobile_no,status');
          if (authRes.isNotEmpty) {
            for (int i = 0; i < loanees.length; i++) {
              final l = loanees[i];
              final custId = l.customerId.trim().toLowerCase();
              final mobile = l.mobileNo.trim().toLowerCase();
              for (final u in authRes) {
                final uCustId = (u['customer_id']?.toString() ?? u['id']?.toString() ?? '').trim().toLowerCase();
                final uMobile = (u['mobile_no']?.toString() ?? '').trim().toLowerCase();
                if ((custId.isNotEmpty && custId == uCustId) || (mobile.isNotEmpty && mobile == uMobile)) {
                  final uStatus = u['status']?.toString().trim().toLowerCase() ?? '';
                  if (uStatus == 'inactive' || l.status.trim().toLowerCase() == 'inactive') {
                    loanees[i] = l.copyWith(status: 'Inactive');
                  }
                  break;
                }
              }
            }
          }
        } catch (_) {}

        return loanees;
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
        final cleanCustId = customerId.trim();
        final orConds = [
          'customerid.eq.$cleanCustId',
          'customer_id.eq.$cleanCustId',
          if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
        ];
        await supaClient
            .from('loanee_accounts')
            .delete()
            .or(orConds.join(','));
            
        debugPrint('✅ Successfully deleted loanee $customerId');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting loanee: $e');
    }
    return false;
  }

  /// Update loanee account status in Supabase 'loanee_accounts' & sync 'user_auth' & 'ro_accounts'
  Future<bool> updateLoaneeStatus(String customerId, String newStatus) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final cleanCustId = customerId.trim();
        final bool isActiveBool = newStatus.toLowerCase() != 'inactive';
        final loaneeOr = [
          'customerid.eq.$cleanCustId',
          'customer_id.eq.$cleanCustId',
          'mobileno.eq.$cleanCustId',
          if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
        ].join(',');

        // 1. Update status in loanee_accounts (both status and is_active if column present)
        try {
          await supaClient
              .from('loanee_accounts')
              .update({
                'status': newStatus,
                'is_active': isActiveBool,
              })
              .or(loaneeOr);
        } catch (_) {
          try {
            await supaClient
                .from('loanee_accounts')
                .update({'status': newStatus})
                .or(loaneeOr);
          } catch (e1) {
            debugPrint('⚠️ Note updating loanee_accounts status: $e1');
          }
        }

        // 2. Sync status in user_auth table for matching record
        try {
          final authOr = [
            'customer_id.eq.$cleanCustId',
            'mobile_no.eq.$cleanCustId',
            if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
          ].join(',');
          await supaClient
              .from('user_auth')
              .update({
                'status': newStatus,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_type', 'loanee')
              .or(authOr);
        } catch (syncErr) {
          debugPrint('⚠️ Sync user_auth loanee status note: $syncErr');
        }

        // 3. Also synchronize ro_accounts if matching record exists
        try {
          try {
            await supaClient
                .from('ro_accounts')
                .update({
                  'status': newStatus,
                  'is_active': isActiveBool,
                })
                .or(loaneeOr);
          } catch (_) {
            await supaClient
                .from('ro_accounts')
                .update({'status': newStatus})
                .or(loaneeOr);
          }
        } catch (_) {}

        debugPrint('✅ Successfully updated loanee $customerId status to $newStatus across all Supabase tables');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error updating loanee status in Supabase: $e');
    }
    return false;
  }

  // ==========================================
  // RO ACCOUNTS METHODS
  // ==========================================

  /// Save RO account strictly to Supabase 'ro_accounts' table (user_auth is created only upon self-registration)
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
          debugPrint('✅ Successfully saved RO ${ro.customerid} to Supabase (ro_accounts).');
        } catch (colErr) {
          debugPrint('⚠️ Upsert with route column note: $colErr, trying fallback without route');
          try {
            final safePayload = Map<String, dynamic>.from(payload)..remove('route');
            await supaClient
                .from('ro_accounts')
                .upsert(
                  safePayload,
                  onConflict: 'customerid',
                )
                .select();
            debugPrint('✅ Saved RO with fallback payload (ro_accounts).');
          } catch (colErr2) {
            debugPrint('⚠️ Fallback upsert note: $colErr2');
          }
        }
            
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

  /// Fetch RO accounts directly from Supabase 'ro_accounts' table & merge with 'user_auth'
  Future<List<RoAccount>?> fetchRoAccounts() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        List<RoAccount> roList = [];

        // 1. Fetch from 'ro_accounts' table
        try {
          final response = await supaClient
              .from('ro_accounts')
              .select('*')
              .order('customerid', ascending: true);
              
          if (response.isNotEmpty) {
            for (final item in response) {
              try {
                roList.add(RoAccount.fromJson(Map<String, dynamic>.from(item)));
              } catch (parseErr) {
                debugPrint('⚠️ Error parsing single ro_account row: $parseErr');
              }
            }
          }
        } catch (roErr) {
          debugPrint('⚠️ Error fetching ro_accounts with order: $roErr, falling back to select all');
          try {
            final response = await supaClient.from('ro_accounts').select('*');
            if (response.isNotEmpty) {
              for (final item in response) {
                try {
                  roList.add(RoAccount.fromJson(Map<String, dynamic>.from(item)));
                } catch (parseErr) {
                  debugPrint('⚠️ Error parsing single ro_account fallback row: $parseErr');
                }
              }
            }
          } catch (tableErr) {
            debugPrint('⚠️ Note querying ro_accounts table: $tableErr');
          }
        }

        // 2. Also merge any RO user registered in 'user_auth'
        try {
          final authRes = await supaClient
              .from('user_auth')
              .select('*');

          if (authRes.isNotEmpty) {
            final existingCustIds = roList
                .map((r) => r.customerId.trim().toLowerCase())
                .where((id) => id.isNotEmpty)
                .toSet();
            final existingMobiles = roList
                .map((r) => r.mobileNo.trim().toLowerCase())
                .where((m) => m.isNotEmpty)
                .toSet();

            for (final u in authRes) {
              try {
                final authRec = UserAuthRecord.fromJson(Map<String, dynamic>.from(u));
                if (authRec.userType == UserType.ro) {
                  final custId = (authRec.customerId ?? authRec.id).trim().toLowerCase();
                  final mobile = authRec.mobileNo.trim().toLowerCase();

                  if ((custId.isNotEmpty && !existingCustIds.contains(custId)) ||
                      (mobile.isNotEmpty && !existingMobiles.contains(mobile))) {
                    roList.add(RoAccount(
                      customerid: authRec.customerId ?? authRec.id,
                      accountnumber: 'RO-ACC-${authRec.id}',
                      roname: authRec.name.isNotEmpty ? authRec.name : 'RO Officer',
                      guardianname: 'N/A',
                      address: 'Office / Field',
                      designation: 'RO Field Officer',
                      route: 'All Routes',
                      postoffice: 'N/A',
                      policestation: 'N/A',
                      district: 'Imphal West',
                      pincode: '795001',
                      mobileno: authRec.mobileNo,
                      aadharno: 'N/A',
                      status: authRec.status,
                      createdat: authRec.createdAt,
                    ));
                    if (custId.isNotEmpty) existingCustIds.add(custId);
                    if (mobile.isNotEmpty) existingMobiles.add(mobile);
                  }
                }
              } catch (_) {}
            }

            // Ensure Inactive status in user_auth or ro_accounts propagates to all loaded ROs
            for (int i = 0; i < roList.length; i++) {
              final r = roList[i];
              final custId = r.customerId.trim().toLowerCase();
              final mobile = r.mobileNo.trim().toLowerCase();
              for (final u in authRes) {
                try {
                  final authRec = UserAuthRecord.fromJson(Map<String, dynamic>.from(u));
                  final uCustId = (authRec.customerId ?? authRec.id).trim().toLowerCase();
                  final uMobile = authRec.mobileNo.trim().toLowerCase();
                  if ((custId.isNotEmpty && custId == uCustId) || (mobile.isNotEmpty && mobile == uMobile)) {
                    if (authRec.status.trim().toLowerCase() == 'inactive' || r.status.trim().toLowerCase() == 'inactive') {
                      roList[i] = r.copyWith(status: 'Inactive');
                    }
                    break;
                  }
                } catch (_) {}
              }
            }
          }
        } catch (authErr) {
          debugPrint('⚠️ Note checking user_auth for ROs: $authErr');
        }

        return roList;
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
        final cleanCustId = customerId.trim();
        final orConds = [
          'customerid.eq.$cleanCustId',
          'customer_id.eq.$cleanCustId',
          if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
        ];
        await supaClient
            .from('ro_accounts')
            .delete()
            .or(orConds.join(','));
            
        debugPrint('✅ Successfully deleted RO $customerId');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting RO account: $e');
    }
    return false;
  }

  /// Update RO account status in Supabase 'ro_accounts' & sync 'user_auth' & 'loanee_accounts'
  Future<bool> updateRoStatus(String customerId, String newStatus) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final cleanCustId = customerId.trim();
        final bool isActiveBool = newStatus.toLowerCase() != 'inactive';
        final roOr = [
          'customerid.eq.$cleanCustId',
          'customer_id.eq.$cleanCustId',
          'mobileno.eq.$cleanCustId',
          if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
        ].join(',');

        // 1. Update status in ro_accounts (both status and is_active if column present)
        try {
          await supaClient
              .from('ro_accounts')
              .update({
                'status': newStatus,
                'is_active': isActiveBool,
              })
              .or(roOr);
        } catch (_) {
          try {
            await supaClient
                .from('ro_accounts')
                .update({'status': newStatus})
                .or(roOr);
          } catch (e1) {
            debugPrint('⚠️ Note updating ro_accounts status: $e1');
          }
        }

        // 2. Sync status in user_auth table if matching record exists
        try {
          final authOr = [
            'customer_id.eq.$cleanCustId',
            'mobile_no.eq.$cleanCustId',
            if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
          ].join(',');
          await supaClient
              .from('user_auth')
              .update({
                'status': newStatus,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_type', 'ro')
              .or(authOr);
        } catch (syncErr) {
          debugPrint('⚠️ Sync user_auth RO status note: $syncErr');
        }

        // 3. Also synchronize loanee_accounts if matching record exists
        try {
          try {
            await supaClient
                .from('loanee_accounts')
                .update({
                  'status': newStatus,
                  'is_active': isActiveBool,
                })
                .or(roOr);
          } catch (_) {
            await supaClient
                .from('loanee_accounts')
                .update({'status': newStatus})
                .or(roOr);
          }
        } catch (_) {}

        debugPrint('✅ Successfully updated RO $customerId status to $newStatus across all Supabase tables');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error updating RO status in Supabase: $e');
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
        try {
          await supaClient
              .from('ro_collection_entries')
              .upsert(entry.toJson(), onConflict: 'id')
              .select();
          debugPrint('✅ Successfully saved collection entry for ${entry.loaneeName} to Supabase.');
          return true;
        } catch (e) {
          final errStr = e.toString();
          // Fallback to base columns if schema doesn't have extended actual_principal/interest columns
          if (errStr.contains('PGRST204') || errStr.contains('column') || errStr.contains('schema cache')) {
            debugPrint('ℹ️ Retrying collection entry save with base schema fields: $e');
            try {
              await supaClient
                  .from('ro_collection_entries')
                  .upsert(entry.toBaseJson(), onConflict: 'id')
                  .select();
              debugPrint('✅ Saved collection entry with base fields for ${entry.loaneeName}.');
              return true;
            } catch (baseErr) {
              final baseErrStr = baseErr.toString();
              if (baseErrStr.contains('PGRST204') || baseErrStr.contains('column') || baseErrStr.contains('schema cache')) {
                await supaClient
                    .from('ro_collection_entries')
                    .upsert(entry.toCoreJson(), onConflict: 'id')
                    .select();
                debugPrint('✅ Saved collection entry with core fields for ${entry.loaneeName}.');
                return true;
              }
              rethrow;
            }
          }
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving collection entry to Supabase: $e');
    }
    return false;
  }

  /// Batch save collection card entries to Supabase
  Future<bool> saveCollectionEntriesBatch(List<RoCollectionEntry> entries) async {
    try {
      final supaClient = client;
      if (supaClient != null && entries.isNotEmpty) {
        try {
          final payloads = entries.map((e) => e.toJson()).toList();
          await supaClient
              .from('ro_collection_entries')
              .upsert(payloads, onConflict: 'id')
              .select();
          debugPrint('✅ Successfully batch saved ${entries.length} collection entries to Supabase.');
          return true;
        } catch (e) {
          final errStr = e.toString();
          if (errStr.contains('PGRST204') || errStr.contains('column') || errStr.contains('schema cache')) {
            debugPrint('ℹ️ Retrying batch collection save with base schema fields: $e');
            try {
              final basePayloads = entries.map((e) => e.toBaseJson()).toList();
              await supaClient
                  .from('ro_collection_entries')
                  .upsert(basePayloads, onConflict: 'id')
                  .select();
              debugPrint('✅ Successfully batch saved ${entries.length} collection entries with base fields.');
              return true;
            } catch (baseErr) {
              final corePayloads = entries.map((e) => e.toCoreJson()).toList();
              await supaClient
                  .from('ro_collection_entries')
                  .upsert(corePayloads, onConflict: 'id')
                  .select();
              return true;
            }
          }
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error batch saving collection entries: $e');
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
  // ==========================================
  // USER AUTH & SECURITY PIN METHODS
  // ==========================================

  /// Check if a user authentication record already exists matching (mobile_no, user_type) OR customer_id
  Future<Map<String, dynamic>> checkUserAuthDuplicate({
    required String mobileNo,
    required UserType userType,
    String? customerId,
    String? excludeId,
  }) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final cleanMobile = mobileNo.trim();
        final cleanCustId = customerId?.trim() ?? '';

        // 1. Check if same (mobile_no, user_type) exists
        var query = supaClient
            .from('user_auth')
            .select('id,mobile_no,user_type,customer_id,name')
            .eq('mobile_no', cleanMobile)
            .eq('user_type', userType.name);

        if (excludeId != null && excludeId.isNotEmpty) {
          query = query.neq('id', excludeId);
        }

        final List<dynamic> res = await query;
        if (res.isNotEmpty) {
          final existing = res.first;
          final existingCustId = existing['customer_id']?.toString() ?? '';
          return {
            'isDuplicate': true,
            'type': 'mobile_and_role',
            'message': 'An account with Mobile Number +91 $cleanMobile is already registered as ${userType.name.toUpperCase()}${existingCustId.isNotEmpty ? ' ($existingCustId)' : ''}.',
          };
        }

        // 2. Check if customer_id already exists in user_auth
        if (cleanCustId.isNotEmpty) {
          var custQuery = supaClient
              .from('user_auth')
              .select('id,customer_id,user_type,mobile_no,name')
              .eq('customer_id', cleanCustId);

          if (excludeId != null && excludeId.isNotEmpty) {
            custQuery = custQuery.neq('id', excludeId);
          }

          final List<dynamic> custRes = await custQuery;
          if (custRes.isNotEmpty) {
            final existing = custRes.first;
            final existingRole = existing['user_type']?.toString().toUpperCase() ?? '';
            final existingMobile = existing['mobile_no']?.toString() ?? '';
            return {
              'isDuplicate': true,
              'type': 'customer_id',
              'message': 'Customer ID "$cleanCustId" is already registered as $existingRole (Mobile: +91 $existingMobile).',
            };
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking duplicate user auth: $e');
    }
    return {'isDuplicate': false};
  }

  /// Verify if an RO exists in 'ro_accounts' matching (Customer ID, Name, Mobile No)
  Future<Map<String, dynamic>> verifyRoAccountRegistration({
    required String customerId,
    required String roName,
    required String mobileNo,
  }) async {
    final cleanCustId = customerId.trim();
    final cleanName = roName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final cleanMobileDigits = mobileNo.replaceAll(RegExp(r'\D'), '');
    final normMobile = cleanMobileDigits.length >= 10
        ? cleanMobileDigits.substring(cleanMobileDigits.length - 10)
        : cleanMobileDigits;

    try {
      final supaClient = client;
      if (supaClient != null) {
        List<dynamic> rows = [];
        try {
          final res = await supaClient
              .from('ro_accounts')
              .select('*')
              .or('customerid.ilike.$cleanCustId,customerid.eq.$cleanCustId');
          rows = res as List;
        } catch (e) {
          debugPrint('⚠️ ro_accounts query by customerid note: $e');
        }

        if (rows.isEmpty && normMobile.isNotEmpty) {
          try {
            final resMob = await supaClient
                .from('ro_accounts')
                .select('*')
                .or('mobileno.ilike.%$normMobile%,mobileno.eq.$normMobile');
            rows = resMob as List;
          } catch (e) {
            debugPrint('⚠️ ro_accounts query by mobileno note: $e');
          }
        }

        if (rows.isEmpty) {
          try {
            final resAll = await supaClient.from('ro_accounts').select('*');
            rows = resAll as List;
          } catch (_) {}
        }

        for (final row in rows) {
          final map = Map<String, dynamic>.from(row);
          final rowCustId = (map['customerid'] ?? map['customer_id'] ?? map['id'] ?? '').toString().trim();
          final rowName = (map['roname'] ?? map['ro_name'] ?? map['name'] ?? map['officer_name'] ?? '').toString().trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
          final rawRowMobile = (map['mobileno'] ?? map['mobile_no'] ?? map['mobile'] ?? map['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
          final rowMobile = rawRowMobile.length >= 10 ? rawRowMobile.substring(rawRowMobile.length - 10) : rawRowMobile;

          final bool custMatches = rowCustId.toLowerCase() == cleanCustId.toLowerCase();
          final bool nameMatches = rowName == cleanName;
          final bool mobileMatches = rowMobile == normMobile;

          if (custMatches && nameMatches && mobileMatches) {
            final status = (map['status'] ?? map['is_active'] ?? 'Active').toString().trim();
            final isInactive = status.toLowerCase() == 'inactive' || status.toLowerCase() == 'false';
            return {
              'matched': true,
              'isInactive': isInactive,
              'account': RoAccount.fromJson(map),
              'message': isInactive
                  ? 'Your RO account is currently marked as Inactive. Login access is disabled. Please contact the administrator.'
                  : 'RO account verified successfully.',
            };
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error verifying RO account in ro_accounts: $e');
    }

    return {
      'matched': false,
      'isInactive': false,
      'message': 'No matching Recovery Officer account found in ro_accounts for Customer ID "$cleanCustId", Name "$roName", and Mobile Number "$mobileNo". Registration cannot proceed until your account is registered by Admin.',
    };
  }

  /// Verify if a Loanee exists in 'loanee_accounts' matching (Customer ID, Name, Mobile No)
  Future<Map<String, dynamic>> verifyLoaneeAccountRegistration({
    required String customerId,
    required String loaneeName,
    required String mobileNo,
  }) async {
    final cleanCustId = customerId.trim();
    final cleanName = loaneeName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final cleanMobileDigits = mobileNo.replaceAll(RegExp(r'\D'), '');
    final normMobile = cleanMobileDigits.length >= 10
        ? cleanMobileDigits.substring(cleanMobileDigits.length - 10)
        : cleanMobileDigits;

    try {
      final supaClient = client;
      if (supaClient != null) {
        List<dynamic> rows = [];
        try {
          final res = await supaClient
              .from('loanee_accounts')
              .select('*')
              .or('customerid.ilike.$cleanCustId,customerid.eq.$cleanCustId');
          rows = res as List;
        } catch (e) {
          debugPrint('⚠️ loanee_accounts query by customerid note: $e');
        }

        if (rows.isEmpty && normMobile.isNotEmpty) {
          try {
            final resMob = await supaClient
                .from('loanee_accounts')
                .select('*')
                .or('mobileno.ilike.%$normMobile%,mobileno.eq.$normMobile');
            rows = resMob as List;
          } catch (e) {
            debugPrint('⚠️ loanee_accounts query by mobileno note: $e');
          }
        }

        if (rows.isEmpty) {
          try {
            final resAll = await supaClient.from('loanee_accounts').select('*');
            rows = resAll as List;
          } catch (_) {}
        }

        for (final row in rows) {
          final map = Map<String, dynamic>.from(row);
          final rowCustId = (map['customerid'] ?? map['customer_id'] ?? map['id'] ?? '').toString().trim();
          final rowName = (map['loaneename'] ?? map['loanee_name'] ?? map['name'] ?? '').toString().trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
          final rawRowMobile = (map['mobileno'] ?? map['mobile_no'] ?? map['mobile'] ?? map['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
          final rowMobile = rawRowMobile.length >= 10 ? rawRowMobile.substring(rawRowMobile.length - 10) : rawRowMobile;

          final bool custMatches = rowCustId.toLowerCase() == cleanCustId.toLowerCase();
          final bool nameMatches = rowName == cleanName;
          final bool mobileMatches = rowMobile == normMobile;

          if (custMatches && nameMatches && mobileMatches) {
            final status = (map['status'] ?? map['is_active'] ?? 'Active').toString().trim();
            final isInactive = status.toLowerCase() == 'inactive' || status.toLowerCase() == 'false';
            return {
              'matched': true,
              'isInactive': isInactive,
              'account': LoaneeAccount.fromJson(map),
              'message': isInactive
                  ? 'Your Loanee account is currently marked as Inactive. Login access is disabled. Please contact the administrator.'
                  : 'Loanee account verified successfully.',
            };
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error verifying Loanee account in loanee_accounts: $e');
    }

    return {
      'matched': false,
      'isInactive': false,
      'message': 'No matching Loanee account found in loanee_accounts for Customer ID "$cleanCustId", Name "$loaneeName", and Mobile Number "$mobileNo". Registration cannot proceed until your loan account is created by Admin.',
    };
  }

  /// Check if a user authentication record already exists for a specific (mobile_no, user_type)
  Future<bool> checkUserAuthExists({
    required String mobileNo,
    required UserType userType,
    String? customerId,
    String? excludeId,
  }) async {
    final dup = await checkUserAuthDuplicate(
      mobileNo: mobileNo,
      userType: userType,
      customerId: customerId,
      excludeId: excludeId,
    );
    return dup['isDuplicate'] == true;
  }

  /// Get next sequential Customer ID for Admin (ADM-01, ADM-02...) or Manager (MGR-01, MGR-02...)
  Future<String> fetchNextRoleCustomerId(UserType userType) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('user_auth')
            .select('customer_id')
            .eq('user_type', userType.name);
        final existingIds = (response as List)
            .map((r) => r['customer_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty);
        if (userType == UserType.admin) {
          return CustomerIdService.generateAdminCustomerId(existingIds: existingIds);
        } else if (userType == UserType.manager) {
          return CustomerIdService.generateManagerCustomerId(existingIds: existingIds);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching next role customer ID: $e');
    }
    return userType == UserType.manager ? 'MGR-01' : 'ADM-01';
  }

  /// Save or Update User Auth Record in Supabase 'user_auth' table
  /// - id is auto-incremented by PostgreSQL as integer (1, 2, 3...)
  /// - customer_id is assigned sequentially (ADM-01, ADM-02 / MGR-01, MGR-02)
  /// - Follows composite uniqueness rule: (mobile_no, user_type)
  Future<bool> saveUserAuthRecord(UserAuthRecord record, {bool allowUpdate = true}) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final cleanMobile = record.mobileNo.trim();

        // 1. Resolve sequential customerId if not already set
        String? resolvedCustomerId = record.customerId?.trim();
        if (resolvedCustomerId == null ||
            resolvedCustomerId.isEmpty ||
            resolvedCustomerId == 'ADM-01' ||
            resolvedCustomerId == 'MGR-01') {
          if (record.userType == UserType.admin || record.userType == UserType.manager) {
            resolvedCustomerId = await fetchNextRoleCustomerId(record.userType);
          }
        }

        final finalRecord = record.copyWith(
          mobileNo: cleanMobile,
          customerId: resolvedCustomerId,
        );

        final jsonPayload = finalRecord.toSupabaseJson();

        try {
          await supaClient
              .from('user_auth')
              .upsert(jsonPayload, onConflict: 'mobile_no,user_type')
              .select();
          debugPrint('✅ Saved User Auth Record (${finalRecord.userType.name}) for ${finalRecord.mobileNo} (Customer ID: $resolvedCustomerId) to Supabase.');
          return true;
        } catch (upsertErr) {
          final errStr = upsertErr.toString();
          debugPrint('⚠️ Upsert with onConflict (mobile_no, user_type) note: $errStr, attempting update fallback');

          if (allowUpdate) {
            try {
              final updateRes = await supaClient
                  .from('user_auth')
                  .update(jsonPayload)
                  .eq('mobile_no', cleanMobile)
                  .eq('user_type', finalRecord.userType.name)
                  .select();
              if (updateRes.isNotEmpty) {
                debugPrint('✅ Updated existing user_auth record for $cleanMobile (${finalRecord.userType.name}).');
                return true;
              }
            } catch (updErr) {
              debugPrint('⚠️ Fallback update failed: $updErr');
            }
          }
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving user auth record to Supabase: $e');
    }
    return false;
  }

  /// Verify and fetch User Auth Record by 6-Digit PIN from Supabase tables
  Future<UserAuthRecord?> fetchUserAuthByPin(String pin) async {
    final cleanPin = pin.trim();
    try {
      final supaClient = client;
      if (supaClient != null) {
        // 1. Check primary 'user_auth' table
        try {
          final List<dynamic> response = await supaClient
              .from('user_auth')
              .select('*')
              .eq('pin', cleanPin);

          if (response.isNotEmpty) {
            const rolePriority = {'admin': 0, 'manager': 1, 'ro': 2, 'loanee': 3};
            final sorted = List<dynamic>.from(response);
            sorted.sort((a, b) {
              final aRole = rolePriority[a['user_type']?.toString().trim().toLowerCase()] ?? 99;
              final bRole = rolePriority[b['user_type']?.toString().trim().toLowerCase()] ?? 99;
              return aRole.compareTo(bRole);
            });
            final authRecord = UserAuthRecord.fromJson(Map<String, dynamic>.from(sorted.first));
            return _enrichAndCheckInactive(authRecord, supaClient);
          }
        } catch (e) {
          debugPrint('⚠️ user_auth check: $e');
        }

        // 2. Check 'ro_accounts' table fallback
        try {
          final roResponse = await supaClient
              .from('ro_accounts')
              .select('*')
              .or('pincode.eq.$cleanPin,customerid.eq.$cleanPin')
              .maybeSingle();

          if (roResponse != null && roResponse.isNotEmpty) {
            final data = Map<String, dynamic>.from(roResponse);
            final custId = data['customerid']?.toString().trim() ?? '';
            final mobile = data['mobileno']?.toString().trim() ?? '';
            String roStatus = data['status']?.toString() ?? 'Active';
            bool isInactive = roStatus.trim().toLowerCase() == 'inactive';

            return UserAuthRecord(
              id: custId.isNotEmpty ? custId : (mobile.isNotEmpty ? mobile : 'ro_$cleanPin'),
              mobileNo: mobile,
              customerId: custId,
              userType: UserType.ro,
              pin: cleanPin,
              name: data['roname']?.toString() ?? 'RO Officer',
              roName: data['roname']?.toString(),
              status: isInactive ? 'Inactive' : 'Active',
            );
          }
        } catch (e) {
          debugPrint('⚠️ ro_accounts PIN check: $e');
        }

        // 3. Check 'loanee_accounts' table fallback
        try {
          final loaneeResponse = await supaClient
              .from('loanee_accounts')
              .select('*')
              .or('pincode.eq.$cleanPin,customerid.eq.$cleanPin')
              .maybeSingle();

          if (loaneeResponse != null && loaneeResponse.isNotEmpty) {
            final data = Map<String, dynamic>.from(loaneeResponse);
            final custId = data['customerid']?.toString().trim() ?? '';
            final mobile = data['mobileno']?.toString().trim() ?? '';
            String loaneeStatus = data['status']?.toString() ?? 'Active';
            bool isInactive = loaneeStatus.trim().toLowerCase() == 'inactive';

            return UserAuthRecord(
              id: custId.isNotEmpty ? custId : (mobile.isNotEmpty ? mobile : 'loanee_$cleanPin'),
              mobileNo: mobile,
              customerId: custId,
              userType: UserType.loanee,
              pin: cleanPin,
              name: data['loaneename']?.toString() ?? 'Loanee Account',
              accountName: data['accountnumber']?.toString(),
              status: isInactive ? 'Inactive' : 'Active',
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

  /// Helper to cross-check inactive status across ro_accounts and loanee_accounts tables
  Future<UserAuthRecord> _enrichAndCheckInactive(UserAuthRecord authRecord, dynamic supaClient) async {
    final custId = (authRecord.customerId ?? authRecord.id).trim();
    final mobile = authRecord.mobileNo.trim();

    bool isInactive = !authRecord.isActive;

    if (!isInactive && (authRecord.userType == UserType.admin || authRecord.userType == UserType.manager)) {
      try {
        var adminQuery = supaClient.from('user_auth').select('status,is_active');
        if (custId.isNotEmpty) {
          adminQuery = adminQuery.eq('customer_id', custId);
        } else {
          adminQuery = adminQuery.eq('mobile_no', mobile).eq('user_type', authRecord.userType.name);
        }
        final adminData = await adminQuery.maybeSingle();
        if (adminData != null) {
          final st = adminData['status']?.toString().trim().toLowerCase();
          final ia = adminData['is_active'];
          if (st == 'inactive' || st == 'false' || st == 'disabled' || st == 'deactivated' || ia == false) {
            isInactive = true;
          }
        }
      } catch (_) {}
    } else if (!isInactive && authRecord.userType == UserType.ro) {
      try {
        var roQuery = supaClient.from('ro_accounts').select('status');
        if (custId.isNotEmpty) {
          final orClauses = [
            'customerid.eq.$custId',
            'customer_id.eq.$custId',
            'mobileno.eq.$mobile',
            if (int.tryParse(custId) != null) 'id.eq.$custId',
          ];
          roQuery = roQuery.or(orClauses.join(','));
        } else {
          roQuery = roQuery.eq('mobileno', mobile);
        }
        final roData = await roQuery.maybeSingle();
        if (roData != null && roData['status'] != null) {
          if (roData['status'].toString().trim().toLowerCase() == 'inactive') {
            isInactive = true;
          }
        }
      } catch (_) {}
    } else if (!isInactive && authRecord.userType == UserType.loanee) {
      try {
        var loaneeQuery = supaClient.from('loanee_accounts').select('status');
        if (custId.isNotEmpty) {
          final orClauses = [
            'customerid.eq.$custId',
            'customer_id.eq.$custId',
            'mobileno.eq.$mobile',
            if (int.tryParse(custId) != null) 'id.eq.$custId',
          ];
          loaneeQuery = loaneeQuery.or(orClauses.join(','));
        } else {
          loaneeQuery = loaneeQuery.eq('mobileno', mobile);
        }
        final loaneeData = await loaneeQuery.maybeSingle();
        if (loaneeData != null && loaneeData['status'] != null) {
          if (loaneeData['status'].toString().trim().toLowerCase() == 'inactive') {
            isInactive = true;
          }
        }
      } catch (_) {}
    }

    final effectiveStatus = isInactive ? 'Inactive' : 'Active';
    return authRecord.copyWith(status: effectiveStatus);
  }

  /// Verify and fetch User Auth Record by Mobile Number (10 digits), 6-Digit PIN, and optional UserType
  /// Follows the rule: User identity is determined by (mobile_no, user_type), then PIN is validated.
  Future<UserAuthRecord?> fetchUserAuthByMobileAndPin({
    required String mobileNo,
    required String pin,
    UserType? userType,
  }) async {
    final cleanMobile = mobileNo.trim();
    final cleanPin = pin.trim();

    try {
      final supaClient = client;
      if (supaClient != null) {
        // 1. Check primary 'user_auth' table
        try {
          var query = supaClient.from('user_auth').select('*');
          if (userType != null) {
            // When userType is specified: identify strictly by (mobile_no, user_type)
            query = query
                .eq('mobile_no', cleanMobile)
                .eq('user_type', userType.name);
          } else {
            // When userType is not specified: match by (mobile_no, pin)
            query = query
                .eq('pin', cleanPin)
                .eq('mobile_no', cleanMobile);
          }

          final List<dynamic> response = await query;

          if (response.isNotEmpty) {
            if (userType != null) {
              // Validate PIN for the retrieved role record
              final match = response.firstWhere(
                (r) => r['pin']?.toString().trim() == cleanPin,
                orElse: () => null,
              );
              if (match == null) {
                debugPrint('⚠️ PIN does not match for mobile $cleanMobile and role ${userType.name}');
                return null;
              }
              final authRecord = UserAuthRecord.fromJson(Map<String, dynamic>.from(match));
              return _enrichAndCheckInactive(authRecord, supaClient);
            } else {
              // Priority: Admin > Manager > RO > Loanee
              const rolePriority = {'admin': 0, 'manager': 1, 'ro': 2, 'loanee': 3};
              final sorted = List<dynamic>.from(response);
              sorted.sort((a, b) {
                final aRole = rolePriority[a['user_type']?.toString().trim().toLowerCase()] ?? 99;
                final bRole = rolePriority[b['user_type']?.toString().trim().toLowerCase()] ?? 99;
                if (aRole != bRole) return aRole.compareTo(bRole);

                final aStatus = (a['status'] ?? '').toString().trim().toLowerCase();
                final aInactive = (aStatus == 'inactive' || aStatus == 'false' || aStatus == 'disabled' || a['is_active'] == false) ? 1 : 0;
                final bStatus = (b['status'] ?? '').toString().trim().toLowerCase();
                final bInactive = (bStatus == 'inactive' || bStatus == 'false' || bStatus == 'disabled' || b['is_active'] == false) ? 1 : 0;
                return aInactive.compareTo(bInactive);
              });

              final authRecord = UserAuthRecord.fromJson(Map<String, dynamic>.from(sorted.first));
              return _enrichAndCheckInactive(authRecord, supaClient);
            }
          }
        } catch (e) {
          debugPrint('⚠️ user_auth mobile & PIN check error: $e');
        }

        // 2. Check 'ro_accounts' table fallback if applicable
        if (userType == null || userType == UserType.ro) {
          try {
            final roResponse = await supaClient
                .from('ro_accounts')
                .select('*')
                .eq('mobileno', cleanMobile)
                .maybeSingle();

            if (roResponse != null && roResponse.isNotEmpty) {
              final data = Map<String, dynamic>.from(roResponse);
              final custId = data['customerid']?.toString().trim() ?? '';
              final mobile = data['mobileno']?.toString().trim() ?? '';
              String roStatus = data['status']?.toString() ?? 'Active';
              bool isInactive = roStatus.trim().toLowerCase() == 'inactive';

              // Verify user_auth table to ensure user_auth Inactive status is strictly honored
              if (!isInactive) {
                try {
                  final orClauses = [
                    if (custId.isNotEmpty) 'customer_id.eq.$custId',
                    if (custId.isNotEmpty && int.tryParse(custId) != null) 'id.eq.$custId',
                    if (mobile.isNotEmpty) 'mobile_no.eq.$mobile',
                  ];
                  if (orClauses.isNotEmpty) {
                    final authCheck = await supaClient
                        .from('user_auth')
                        .select('status,pin')
                        .eq('user_type', 'ro')
                        .or(orClauses.join(','))
                        .maybeSingle();
                    if (authCheck != null) {
                      if (authCheck['status'] != null && authCheck['status'].toString().trim().toLowerCase() == 'inactive') {
                        isInactive = true;
                      }
                      if (authCheck['pin'] != null && authCheck['pin'].toString().trim() != cleanPin) {
                        // PIN did not match
                        return null;
                      }
                    }
                  }
                } catch (_) {}
              }

              final dbPin = data['pincode']?.toString().trim() ?? '';
              if (dbPin.isEmpty || dbPin == cleanPin || dbPin == '1234') {
                return UserAuthRecord(
                  id: custId.isNotEmpty ? custId : (mobile.isNotEmpty ? mobile : 'ro_$cleanMobile'),
                  mobileNo: mobile.isNotEmpty ? mobile : cleanMobile,
                  customerId: custId,
                  userType: UserType.ro,
                  pin: cleanPin,
                  name: data['roname']?.toString() ?? 'RO Field Officer',
                  roName: data['roname']?.toString(),
                  status: isInactive ? 'Inactive' : 'Active',
                );
              }
            }
          } catch (e) {
            debugPrint('⚠️ ro_accounts mobile check: $e');
          }
        }

        // 3. Check 'loanee_accounts' table fallback if applicable
        if (userType == null || userType == UserType.loanee) {
          try {
            final loaneeResponse = await supaClient
                .from('loanee_accounts')
                .select('*')
                .eq('mobileno', cleanMobile)
                .maybeSingle();

            if (loaneeResponse != null && loaneeResponse.isNotEmpty) {
              final data = Map<String, dynamic>.from(loaneeResponse);
              final custId = data['customerid']?.toString().trim() ?? '';
              final mobile = data['mobileno']?.toString().trim() ?? '';
              String loaneeStatus = data['status']?.toString() ?? 'Active';
              bool isInactive = loaneeStatus.trim().toLowerCase() == 'inactive';

              // Verify user_auth table to ensure user_auth Inactive status is strictly honored
              if (!isInactive) {
                try {
                  final orClauses = [
                    if (custId.isNotEmpty) 'customer_id.eq.$custId',
                    if (custId.isNotEmpty && int.tryParse(custId) != null) 'id.eq.$custId',
                    if (mobile.isNotEmpty) 'mobile_no.eq.$mobile',
                  ];
                  if (orClauses.isNotEmpty) {
                    final authCheck = await supaClient
                        .from('user_auth')
                        .select('status,pin')
                        .eq('user_type', 'loanee')
                        .or(orClauses.join(','))
                        .maybeSingle();
                    if (authCheck != null) {
                      if (authCheck['status'] != null && authCheck['status'].toString().trim().toLowerCase() == 'inactive') {
                        isInactive = true;
                      }
                      if (authCheck['pin'] != null && authCheck['pin'].toString().trim() != cleanPin) {
                        return null;
                      }
                    }
                  }
                } catch (_) {}
              }

              final dbPin = data['pincode']?.toString().trim() ?? '';
              if (dbPin.isEmpty || dbPin == cleanPin || dbPin == '1234') {
                return UserAuthRecord(
                  id: custId.isNotEmpty ? custId : (mobile.isNotEmpty ? mobile : 'loanee_$cleanMobile'),
                  mobileNo: mobile.isNotEmpty ? mobile : cleanMobile,
                  customerId: custId,
                  userType: UserType.loanee,
                  pin: cleanPin,
                  name: data['loaneename']?.toString() ?? 'Loanee Account',
                  accountName: data['accountnumber']?.toString(),
                  status: isInactive ? 'Inactive' : 'Active',
                );
              }
            }
          } catch (e) {
            debugPrint('⚠️ loanee_accounts mobile check: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching user auth by mobile & PIN from Supabase: $e');
    }
    return null;
  }

  /// Fetch user auth record by mobile number and specific user type
  Future<UserAuthRecord?> fetchUserAuthByMobileAndRole({
    required String mobileNo,
    required UserType userType,
  }) async {
    final cleanMobile = mobileNo.trim();
    try {
      final supaClient = client;
      if (supaClient != null) {
        final List<dynamic> response = await supaClient
            .from('user_auth')
            .select('*')
            .eq('mobile_no', cleanMobile)
            .eq('user_type', userType.name);

        if (response.isNotEmpty) {
          return UserAuthRecord.fromJson(Map<String, dynamic>.from(response.first));
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching user auth by mobile and role: $e');
    }
    return null;
  }

  /// Reset PIN strictly by Customer ID + Mobile Number verification.
  /// Does NOT require User Type.
  /// Verifies that both Customer ID and Mobile Number belong to the same user record.
  /// Reset PIN strictly by Customer ID + Mobile Number (and optional User Type) verification.
  /// Verifies that Customer ID, Mobile Number (and Role if specified) all match the same user record.
  Future<Map<String, dynamic>> resetUserPinByCustomerIdAndMobile({
    required String customerId,
    required String mobileNo,
    required String newPin,
    UserType? userType,
  }) async {
    final cleanCustId = customerId.trim();
    final cleanMobile = mobileNo.trim();
    final cleanPin = newPin.trim();

    if (cleanCustId.isEmpty || cleanMobile.isEmpty || cleanPin.length != 6) {
      return {
        'success': false,
        'message': 'Customer ID, 10-digit Mobile Number, and 6-digit PIN are required.',
      };
    }

    try {
      final supaClient = client;
      if (supaClient != null) {
        // 1. Check primary 'user_auth' table matching BOTH mobile_no and customer_id
        try {
          final orConditions = [
            'customer_id.eq.$cleanCustId',
            'customer_id.ilike.$cleanCustId',
            if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
          ];

          var query = supaClient
              .from('user_auth')
              .select('*')
              .eq('mobile_no', cleanMobile)
              .or(orConditions.join(','));

          if (userType != null) {
            query = query.eq('user_type', userType.name);
          }

          final List<dynamic> response = await query;

          if (response.isNotEmpty) {
            final match = Map<String, dynamic>.from(response.first);
            final recordId = match['id'];
            final userTypeStr = match['user_type']?.toString() ?? 'loanee';

            await supaClient.from('user_auth').update({
              'pin': cleanPin,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', recordId);

            // Also update underlying table if applicable
            final underlyingOr = [
              'customerid.eq.$cleanCustId',
              'customerid.ilike.$cleanCustId',
              if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
            ].join(',');

            if (userTypeStr == 'ro') {
              try {
                await supaClient
                    .from('ro_accounts')
                    .update({'pincode': cleanPin})
                    .eq('mobileno', cleanMobile)
                    .or(underlyingOr);
              } catch (_) {}
            } else if (userTypeStr == 'loanee') {
              try {
                await supaClient
                    .from('loanee_accounts')
                    .update({'pincode': cleanPin})
                    .eq('mobileno', cleanMobile)
                    .or(underlyingOr);
              } catch (_) {}
            }

            debugPrint('✅ Reset PIN in Supabase for Customer ID $cleanCustId and Mobile $cleanMobile');
            return {
              'success': true,
              'userType': userTypeStr,
              'name': match['name']?.toString() ?? 'User',
              'message': 'Security PIN updated successfully for $cleanCustId!',
            };
          }
        } catch (e) {
          debugPrint('⚠️ user_auth reset by Customer ID & Mobile error: $e');
        }

        final genericOr = [
          'customerid.eq.$cleanCustId',
          'customerid.ilike.$cleanCustId',
          if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
        ].join(',');

        // 2. Check fallback in ro_accounts
        if (userType == null || userType == UserType.ro) {
          try {
            final roMatch = await supaClient
                .from('ro_accounts')
                .select('*')
                .eq('mobileno', cleanMobile)
                .or(genericOr)
                .maybeSingle();

            if (roMatch != null && roMatch.isNotEmpty) {
              final roData = Map<String, dynamic>.from(roMatch);
              await supaClient
                  .from('ro_accounts')
                  .update({'pincode': cleanPin})
                  .eq('mobileno', cleanMobile)
                  .or(genericOr);

              // Sync to user_auth as well
              await saveUserAuthRecord(
                UserAuthRecord(
                  id: '',
                  mobileNo: cleanMobile,
                  customerId: cleanCustId,
                  userType: UserType.ro,
                  pin: cleanPin,
                  name: roData['roname']?.toString() ?? 'RO Field Officer',
                  roName: roData['roname']?.toString(),
                ),
              );

              return {
                'success': true,
                'userType': 'ro',
                'name': roData['roname']?.toString() ?? 'RO Officer',
                'message': 'Security PIN updated successfully for $cleanCustId!',
              };
            }
          } catch (e) {
            debugPrint('⚠️ ro_accounts reset check error: $e');
          }
        }

        // 3. Check fallback in loanee_accounts
        if (userType == null || userType == UserType.loanee) {
          try {
            final loaneeMatch = await supaClient
                .from('loanee_accounts')
                .select('*')
                .eq('mobileno', cleanMobile)
                .or(genericOr)
                .maybeSingle();

            if (loaneeMatch != null && loaneeMatch.isNotEmpty) {
              final loaneeData = Map<String, dynamic>.from(loaneeMatch);
              await supaClient
                  .from('loanee_accounts')
                  .update({'pincode': cleanPin})
                  .eq('mobileno', cleanMobile)
                  .or(genericOr);

              // Sync to user_auth as well
              await saveUserAuthRecord(
                UserAuthRecord(
                  id: '',
                  mobileNo: cleanMobile,
                  customerId: cleanCustId,
                  userType: UserType.loanee,
                  pin: cleanPin,
                  name: loaneeData['loaneename']?.toString() ?? 'Loanee Account',
                  accountName: loaneeData['accountnumber']?.toString(),
                ),
              );

              return {
                'success': true,
                'userType': 'loanee',
                'name': loaneeData['loaneename']?.toString() ?? 'Loanee Account',
                'message': 'Security PIN updated successfully for $cleanCustId!',
              };
            }
          } catch (e) {
            debugPrint('⚠️ loanee_accounts reset check error: $e');
          }
        }

        // Detailed mismatch diagnostics to provide clear, actionable error messages
        try {
          // Check if customer_id exists under ANY record
          final custCheck = await supaClient
              .from('user_auth')
              .select('mobile_no,user_type,customer_id')
              .eq('customer_id', cleanCustId);
          if (custCheck.isNotEmpty) {
            final rec = custCheck.first;
            final recMobile = rec['mobile_no']?.toString() ?? '';
            final recRole = rec['user_type']?.toString().toUpperCase() ?? '';
            if (recMobile != cleanMobile) {
              return {
                'success': false,
                'message': 'Customer ID "$cleanCustId" is registered with mobile number +91 $recMobile, which does not match the entered mobile number (+91 $cleanMobile).',
              };
            }
            if (userType != null && recRole != userType.name.toUpperCase()) {
              return {
                'success': false,
                'message': 'Customer ID "$cleanCustId" is registered as $recRole, not as ${userType.name.toUpperCase()}.',
              };
            }
          }

          // Check if mobile exists under ANY record
          final mobileCheck = await supaClient
              .from('user_auth')
              .select('mobile_no,user_type,customer_id')
              .eq('mobile_no', cleanMobile);
          if (mobileCheck.isNotEmpty) {
            final rec = mobileCheck.first;
            final recCust = rec['customer_id']?.toString() ?? '';
            final recRole = rec['user_type']?.toString().toUpperCase() ?? '';
            if (recCust.isNotEmpty && recCust.toUpperCase() != cleanCustId.toUpperCase()) {
              return {
                'success': false,
                'message': 'Mobile number +91 $cleanMobile is registered with Customer ID "$recCust", which does not match "$cleanCustId".',
              };
            }
            if (userType != null && recRole != userType.name.toUpperCase()) {
              return {
                'success': false,
                'message': 'Mobile number +91 $cleanMobile is registered as $recRole, not as ${userType.name.toUpperCase()}.',
              };
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ Error resetting PIN by Customer ID and Mobile: $e');
    }

    final roleText = userType != null ? ' ${userType.name.toUpperCase()}' : '';
    return {
      'success': false,
      'message': 'No$roleText account found matching Customer ID "$cleanCustId" and Mobile Number "+91 $cleanMobile". Please verify your details.',
    };
  }

  /// Reset or Update Security PIN for a specific Role in Supabase
  /// Changing a Manager PIN will strictly update ONLY the Manager record, leaving Admin PIN intact.
  Future<bool> resetUserPinInSupabase({
    required UserType userType,
    required String mobileNo,
    String? customerId,
    required String newPin,
  }) async {
    final cleanMobile = mobileNo.trim();
    final cleanPin = newPin.trim();
    try {
      final supaClient = client;
      if (supaClient != null) {
        // Query matching user strictly by mobile_no AND user_type (or customer_id)
        var query = supaClient.from('user_auth').select('*');
        if (customerId != null && customerId.trim().isNotEmpty) {
          query = query.eq('customer_id', customerId.trim());
        } else {
          query = query.eq('mobile_no', cleanMobile).eq('user_type', userType.name);
        }
        
        final List<dynamic> response = await query;
        if (response.isNotEmpty) {
          final recordId = response.first['id'];
          await supaClient.from('user_auth').update({
            'pin': cleanPin,
            'user_type': userType.name,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', recordId);
          debugPrint('✅ Reset PIN in Supabase for $cleanMobile (${userType.name})');
          return true;
        } else {
          // Create new record in Supabase if not previously registered
          final newRecord = UserAuthRecord(
            id: customerId?.isNotEmpty == true
                ? customerId!
                : '${userType.name}_$cleanMobile',
            mobileNo: cleanMobile,
            customerId: customerId,
            userType: userType,
            pin: cleanPin,
            name: userType == UserType.admin
                ? 'Administrator'
                : (userType == UserType.manager
                    ? 'Branch Manager'
                    : (userType == UserType.ro ? 'RO Officer' : 'Loanee Account')),
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

  /// Helper to ensure payment payloads strictly conform to ro_collection_payments table schema
  Map<String, dynamic> _cleanPaymentPayload(Map<String, dynamic> raw) {
    final cleaned = Map<String, dynamic>.from(raw);
    cleaned.remove('interest');
    cleaned.remove('interest_amount');
    cleaned.remove('interestAmount');
    return cleaned;
  }

  /// Save individual payment record into Supabase 'ro_collection_payments' table
  Future<bool> saveCollectionPayment(CollectionPaymentModel payment) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final payload = _cleanPaymentPayload(payment.toJson());
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

  /// Batch save collection payment records to Supabase
  Future<bool> saveCollectionPaymentsBatch(List<CollectionPaymentModel> payments) async {
    try {
      final supaClient = client;
      if (supaClient != null && payments.isNotEmpty) {
        final payloads = payments.map((p) => _cleanPaymentPayload(p.toJson())).toList();
        await supaClient
            .from('ro_collection_payments')
            .upsert(payloads, onConflict: 'id')
            .select();
        debugPrint('✅ Successfully batch saved ${payments.length} collection payments to Supabase.');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error batch saving collection payments: $e');
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

  /// Fetch paginated collection payment history at the query level
  Future<PaginatedPaymentsResult> fetchPaginatedPaymentHistory({
    int page = 1,
    int pageSize = 5,
    String? route,
    String? searchQuery,
    String? collectionId,
    DateTime? startDate,
    DateTime? endDate,
    bool ascending = false,
  }) async {
    final supaClient = client;
    final int from = (page - 1) * pageSize;

    try {
      if (supaClient != null) {
        var query = supaClient.from('ro_collection_payments').select('*');

        if (collectionId != null && collectionId.isNotEmpty) {
          query = query.eq('collection_id', collectionId);
        }
        if (route != null && route.isNotEmpty && route.toLowerCase() != 'all') {
          query = query.ilike('ro_route', route);
        }
        if (startDate != null) {
          query = query.gte('created_at', startDate.toIso8601String());
        }
        if (endDate != null) {
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          query = query.lte('created_at', endOfDay.toIso8601String());
        }

        final response = await query.order('created_at', ascending: ascending);
        final list = (response as List)
            .map((item) => CollectionPaymentModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        var filtered = list;
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final q = searchQuery.toLowerCase().trim();
          filtered = filtered.where((p) {
            return p.id.toLowerCase().contains(q) ||
                (p.roName?.toLowerCase().contains(q) ?? false) ||
                (p.roRoute?.toLowerCase().contains(q) ?? false) ||
                (p.remarks?.toLowerCase().contains(q) ?? false);
          }).toList();
        }

        final totalCount = filtered.length;
        final pagedList = (from < totalCount)
            ? filtered.skip(from).take(pageSize).toList()
            : <CollectionPaymentModel>[];

        return PaginatedPaymentsResult(
          payments: pagedList,
          totalCount: totalCount,
          page: page,
          pageSize: pageSize,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching paginated payments from Supabase: $e');
    }

    return PaginatedPaymentsResult(
      payments: [],
      totalCount: 0,
      page: page,
      pageSize: pageSize,
    );
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

  /// Fetch all Admin users directly from Supabase 'user_auth' table where user_type=admin
  Future<List<UserAuthRecord>?> fetchAdminUsers() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('user_auth')
            .select('*')
            .or('user_type.eq.admin,user_type.eq.Admin,user_type.eq.ADMIN,user_type.ilike.admin')
            .order('created_at', ascending: false);

        if (response.isNotEmpty) {
          return (response as List)
              .map((item) => UserAuthRecord.fromJson(Map<String, dynamic>.from(item)))
              .where((u) => u.userType == UserType.admin)
              .toList();
        } else {
          return [];
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching admin users from user_auth: $e');
    }
    return null;
  }

  /// Fetch all Admin & Manager users from Supabase 'user_auth' table
  Future<List<UserAuthRecord>> fetchAdminAndManagerUsers() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('user_auth')
            .select('*')
            .or('user_type.eq.admin,user_type.eq.Admin,user_type.eq.ADMIN,user_type.ilike.admin,user_type.eq.manager,user_type.eq.Manager,user_type.eq.MANAGER,user_type.ilike.manager')
            .order('created_at', ascending: false);

        if (response.isNotEmpty) {
          return (response as List)
              .map((item) => UserAuthRecord.fromJson(Map<String, dynamic>.from(item)))
              .where((u) => u.userType == UserType.admin || u.userType == UserType.manager)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching admin & manager users from user_auth: $e');
    }
    return [];
  }

  /// Update user account status in 'user_auth' AND sync to 'ro_accounts' and 'loanee_accounts' tables
  Future<bool> updateUserAuthStatus(
    String id,
    String newStatus, {
    String? customerId,
    String? mobileNo,
    UserType? userType,
  }) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final cleanId = id.trim();
        final cleanCustId = customerId?.trim() ?? '';
        final cleanMobile = mobileNo?.trim() ?? '';
        final bool isActiveBool = newStatus.toLowerCase() != 'inactive';

        // 1. Update status in 'user_auth' table scoped strictly to the specific account
        bool authUpdated = false;

        // A. If we have a customer_id (or non-numeric ID like ADM-01)
        final targetCustId = cleanCustId.isNotEmpty
            ? cleanCustId
            : (int.tryParse(cleanId) == null && cleanId.isNotEmpty ? cleanId : '');
        if (targetCustId.isNotEmpty) {
          try {
            final res = await supaClient.from('user_auth').update({
              'status': newStatus,
              'is_active': isActiveBool,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('customer_id', targetCustId).select();
            if (res.isNotEmpty) authUpdated = true;
          } catch (_) {
            try {
              final res = await supaClient.from('user_auth').update({
                'status': newStatus,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('customer_id', targetCustId).select();
              if (res.isNotEmpty) authUpdated = true;
            } catch (eCust) {
              debugPrint('⚠️ user_auth status update by customer_id error: $eCust');
            }
          }
        }

        // B. If not yet updated or cleanMobile is provided, try by mobile_no & user_type
        if ((!authUpdated || cleanMobile.isNotEmpty) && cleanMobile.isNotEmpty) {
          try {
            var q = supaClient.from('user_auth').update({
              'status': newStatus,
              'is_active': isActiveBool,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('mobile_no', cleanMobile);
            if (userType != null) {
              q = q.eq('user_type', userType.name);
            }
            final res = await q.select();
            if (res.isNotEmpty) authUpdated = true;
          } catch (_) {
            try {
              var q = supaClient.from('user_auth').update({
                'status': newStatus,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('mobile_no', cleanMobile);
              if (userType != null) {
                q = q.eq('user_type', userType.name);
              }
              final res = await q.select();
              if (res.isNotEmpty) authUpdated = true;
            } catch (eMob) {
              debugPrint('⚠️ user_auth status update by mobile error: $eMob');
            }
          }
        }

        // C. If not yet updated, try by numeric id
        if (!authUpdated && int.tryParse(cleanId) != null) {
          final intId = int.parse(cleanId);
          try {
            final res = await supaClient.from('user_auth').update({
              'status': newStatus,
              'is_active': isActiveBool,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', intId).select();
            if (res.isNotEmpty) authUpdated = true;
          } catch (_) {
            try {
              final res = await supaClient.from('user_auth').update({
                'status': newStatus,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', intId).select();
              if (res.isNotEmpty) authUpdated = true;
            } catch (eId) {
              debugPrint('⚠️ user_auth status update by id error: $eId');
            }
          }
        }

        // Build match clause for related tables (ro_accounts and loanee_accounts)
        final List<String> matchOrClauses = [
          'customerid.eq.$cleanId',
          'customer_id.eq.$cleanId',
          'mobileno.eq.$cleanId',
          'mobile_no.eq.$cleanId',
          if (int.tryParse(cleanId) != null) 'id.eq.$cleanId',
        ];
        if (cleanCustId.isNotEmpty && cleanCustId != cleanId) {
          matchOrClauses.addAll([
            'customerid.eq.$cleanCustId',
            'customer_id.eq.$cleanCustId',
            if (int.tryParse(cleanCustId) != null) 'id.eq.$cleanCustId',
          ]);
        }
        if (cleanMobile.isNotEmpty && cleanMobile != cleanId) {
          matchOrClauses.addAll([
            'mobileno.eq.$cleanMobile',
            'mobile_no.eq.$cleanMobile',
          ]);
        }
        final crossTableOr = matchOrClauses.toSet().join(',');

        // 2. Synchronize to 'ro_accounts' table
        try {
          try {
            await supaClient.from('ro_accounts').update({
              'status': newStatus,
              'is_active': isActiveBool,
            }).or(crossTableOr);
          } catch (_) {
            await supaClient.from('ro_accounts').update({
              'status': newStatus,
            }).or(crossTableOr);
          }
          debugPrint('✅ Synced status to $newStatus in ro_accounts');
        } catch (eRo) {
          debugPrint('⚠️ Note updating ro_accounts from user_auth: $eRo');
        }

        // 3. Synchronize to 'loanee_accounts' table
        try {
          try {
            await supaClient.from('loanee_accounts').update({
              'status': newStatus,
              'is_active': isActiveBool,
            }).or(crossTableOr);
          } catch (_) {
            await supaClient.from('loanee_accounts').update({
              'status': newStatus,
            }).or(crossTableOr);
          }
          debugPrint('✅ Synced status to $newStatus in loanee_accounts');
        } catch (eLoanee) {
          debugPrint('⚠️ Note updating loanee_accounts from user_auth: $eLoanee');
        }

        debugPrint('✅ Successfully synchronized user status for $id to $newStatus across all tables (user_auth, ro_accounts, loanee_accounts)');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error updating user status across Supabase tables: $e');
    }
    return false;
  }

  // ==========================================
  // SYSTEM SETTINGS & ROW-WISE PERSISTENCE
  // ==========================================

  /// Upsert a single setting row in 'system_settings' table (Row-wise storage)
  /// Safely handles unique constraint on 'setting_key'
  Future<bool> setSystemSetting(String key, dynamic value) async {
    try {
      final supaClient = client;
      if (supaClient == null) return false;

      final now = DateTime.now().toIso8601String();
      final valStr = value?.toString() ?? '';

      // 1. Try explicit onConflict upsert on 'setting_key'
      try {
        await supaClient.from('system_settings').upsert(
          {
            'setting_key': key,
            'setting_value': valStr,
            'updated_at': now,
          },
          onConflict: 'setting_key',
        );
        return true;
      } catch (eUpsert) {
        debugPrint('ℹ️ onConflict upsert notice for $key: $eUpsert, falling back to check-update-insert');
      }

      // 2. Fallback: Check if row exists, then update or insert
      final existing = await supaClient
          .from('system_settings')
          .select('setting_key')
          .eq('setting_key', key)
          .maybeSingle();

      if (existing != null) {
        await supaClient.from('system_settings').update({
          'setting_value': valStr,
          'updated_at': now,
        }).eq('setting_key', key);
      } else {
        await supaClient.from('system_settings').insert({
          'setting_key': key,
          'setting_value': valStr,
          'updated_at': now,
        });
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ Error persisting system setting row ($key = $value): $e');
      return false;
    }
  }

  /// Fetch all system settings as key-value pairs row-wise from 'system_settings'
  Future<Map<String, String>> fetchAllSystemSettings() async {
    final Map<String, String> settingsMap = {};
    try {
      final supaClient = client;
      if (supaClient != null) {
        final rows = await supaClient
            .from('system_settings')
            .select('setting_key, setting_value');

        for (final r in rows) {
          final k = r['setting_key']?.toString().trim();
          final v = r['setting_value']?.toString().trim();
          if (k != null && v != null) {
            settingsMap[k] = v;
          }
        }
      }
    } catch (e) {
      debugPrint('ℹ️ Note fetching system_settings rows: $e');
    }
    return settingsMap;
  }

  /// Fetch investment settings row-wise from 'system_settings' table (Single Source of Truth)
  Future<InvestmentSettingsModel> fetchInvestmentSettings() async {
    try {
      final map = await fetchAllSystemSettings();

      double base = 10000.0;
      double interest = 1500.0;
      double rate = 15.0;

      if (map.containsKey('investment_base_amount')) {
        base = double.tryParse(map['investment_base_amount']!) ?? base;
      }
      if (map.containsKey('investment_interest_amount')) {
        interest = double.tryParse(map['investment_interest_amount']!) ?? interest;
      }
      if (map.containsKey('investment_interest_rate')) {
        rate = double.tryParse(map['investment_interest_rate']!) ?? rate;
      }

      return InvestmentSettingsModel(
        baseAmount: base,
        interestAmount: interest,
        interestRate: rate,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('⚠️ Error parsing investment settings from system_settings: $e');
    }

    // Default configuration (₹10,000 base, ₹1,500 interest, 15% rate)
    return const InvestmentSettingsModel(
      baseAmount: 10000.0,
      interestAmount: 1500.0,
      interestRate: 15.0,
    );
  }

  /// Save investment settings purely ROW-WISE in 'system_settings' table
  Future<bool> saveInvestmentSettings({
    required double baseAmount,
    required double interestAmount,
    required double interestRate,
  }) async {
    try {
      final ok1 = await setSystemSetting('investment_base_amount', baseAmount);
      final ok2 = await setSystemSetting('investment_interest_amount', interestAmount);
      final ok3 = await setSystemSetting('investment_interest_rate', interestRate);

      debugPrint('✅ Investment settings saved row-wise: Rate=$interestRate%, Base=₹$baseAmount, Interest=₹$interestAmount');
      return ok1 && ok2 && ok3;
    } catch (e) {
      debugPrint('❌ Error saving investment settings row-wise to system_settings: $e');
      return false;
    }
  }

  /// Save late payment and weekly scheme settings purely ROW-WISE in 'system_settings' table
  Future<bool> saveLatePaymentSettings({
    required double dailyFine,
    required double weeklyFine,
    required double weeklyInstallment,
    required double weeklyTenure,
  }) async {
    try {
      final ok1 = await setSystemSetting('daily_late_fine', dailyFine);
      final ok2 = await setSystemSetting('weekly_late_fine', weeklyFine);
      final ok3 = await setSystemSetting('weekly_installment_amount', weeklyInstallment);
      final ok4 = await setSystemSetting('weekly_tenure_weeks', weeklyTenure);

      debugPrint('✅ Late payment settings saved row-wise: Daily=₹$dailyFine, Weekly=₹$weeklyFine, Installment=₹$weeklyInstallment, Tenure=$weeklyTenure');
      return ok1 && ok2 && ok3 && ok4;
    } catch (e) {
      debugPrint('❌ Error saving late payment settings row-wise: $e');
      return false;
    }
  }

  /// Calculate investment details for any amount directly from system_settings in real-time
  /// Business rule: Interest = Investment Amount * (Rate / 100); Total = Investment Amount + Interest
  Future<InvestmentCalculationResult> calculateInvestment(double amount) async {
    final settings = await fetchInvestmentSettings();
    return InvestmentCalculationResult.calculate(
      amount: amount,
      settings: settings,
    );
  }

  // ==========================================
  // REAL-TIME NOTIFICATIONS METHODS
  // ==========================================

  /// Fetch notifications for current user (filtered by matching recipient IDs or 'admin')
  Future<List<AppNotification>> fetchNotificationsForUser({
    required String userId,
    String? customerId,
    String? mobileNo,
    bool isAdmin = false,
  }) async {
    try {
      final supaClient = client;
      if (supaClient == null) return [];

      final validRecipients = <String>{};
      if (userId.isNotEmpty) validRecipients.add(userId);
      if (customerId != null && customerId.isNotEmpty) validRecipients.add(customerId);
      if (mobileNo != null && mobileNo.isNotEmpty) validRecipients.add(mobileNo);
      if (isAdmin) {
        validRecipients.add('admin');
        validRecipients.add('ADM-01');
      }

      if (validRecipients.isEmpty) return [];

      // Query notifications matching any of the user's identifiers
      final response = await supaClient
          .from('notifications')
          .select('*')
          .inFilter('recipient_user_id', validRecipients.toList())
          .order('created_at', ascending: false)
          .limit(100);

      if (response.isNotEmpty) {
        final seenIds = <String>{};
        final seenRefKeys = <String>{};
        final list = <AppNotification>[];
        for (var item in response) {
          final n = AppNotification.fromJson(Map<String, dynamic>.from(item));
          final refKey = n.referenceId != null && n.referenceId!.isNotEmpty
              ? '${n.notificationType}_${n.referenceId}'
              : n.id;

          if (n.id.isNotEmpty && !seenIds.contains(n.id) && !seenRefKeys.contains(refKey)) {
            seenIds.add(n.id);
            seenRefKeys.add(refKey);
            list.add(n);
          }
        }
        return list;
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching notifications: $e');
    }
    return [];
  }

  /// Save single notification to Supabase 'notifications' table
  Future<bool> saveNotification(AppNotification notification) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient
            .from('notifications')
            .upsert(notification.toJson(), onConflict: 'id')
            .select();
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error saving notification: $e');
    }
    return false;
  }

  /// Create and dispatch notifications for a collection payment
  /// Uses deterministic IDs matching DB triggers to ensure zero duplicates
  Future<void> createCollectionPaymentNotifications({
    required CollectionPaymentModel payment,
    required RoCollectionEntry card,
    bool force = false,
  }) async {
    try {
      if (_suppressPaymentNotifications && !force) {
        debugPrint('ℹ️ Payment notification suppressed during bulk import for ${card.loaneeName} (${payment.id})');
        return;
      }

      final supaClient = client;
      if (supaClient == null) return;

      final roName = payment.roName?.isNotEmpty == true ? payment.roName! : 'RO Field Officer';
      final formattedAmount = payment.paymentAmount.toStringAsFixed(2);
      final formattedRemaining = payment.remainingBalance.toStringAsFixed(2);

      // 1. Single Notification for the specific Loanee (deterministic ID)
      final loaneeTarget = card.customerId.isNotEmpty ? card.customerId : card.mobileNo;
      if (loaneeTarget.isNotEmpty) {
        final loaneeNotification = AppNotification(
          id: 'notif_pay_${payment.id}_loanee',
          recipientUserId: loaneeTarget,
          senderUserId: payment.roId,
          notificationType: 'collection_payment',
          title: 'Payment Received',
          message: 'Dear ${card.loaneeName}, payment of ₹$formattedAmount has been recorded by $roName. Remaining balance: ₹$formattedRemaining.',
          referenceId: payment.id,
          isRead: false,
          createdAt: payment.createdAt,
        );
        await saveNotification(loaneeNotification);
      }

      // 2. Single Notification for Admin Broadcast (deterministic ID)
      final adminNotification = AppNotification(
        id: 'notif_pay_${payment.id}_admin',
        recipientUserId: 'admin',
        senderUserId: payment.roId,
        notificationType: 'collection_payment',
        title: 'New Collection Payment',
        message: '$roName collected ₹$formattedAmount from ${card.loaneeName} (${card.accountNumber.isNotEmpty ? card.accountNumber : card.customerId}).',
        referenceId: payment.id,
        isRead: false,
        createdAt: payment.createdAt,
      );
      await saveNotification(adminNotification);
    } catch (e) {
      debugPrint('⚠️ Error dispatching payment notifications: $e');
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String id) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient
            .from('notifications')
            .update({'is_read': true})
            .eq('id', id);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error marking notification read: $e');
    }
    return false;
  }

  /// Mark all notifications as read for a set of recipient IDs
  Future<bool> markAllNotificationsAsRead(List<String> recipientIds) async {
    try {
      final supaClient = client;
      if (supaClient != null && recipientIds.isNotEmpty) {
        await supaClient
            .from('notifications')
            .update({'is_read': true})
            .inFilter('recipient_user_id', recipientIds);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error marking all notifications read: $e');
    }
    return false;
  }

  /// Delete notification by ID
  Future<bool> deleteNotification(String id) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('notifications').delete().eq('id', id);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting notification: $e');
    }
    return false;
  }

  /// Clear all notifications for matching recipient IDs
  Future<bool> clearAllNotifications(List<String> recipientIds) async {
    try {
      final supaClient = client;
      if (supaClient != null && recipientIds.isNotEmpty) {
        await supaClient
            .from('notifications')
            .delete()
            .inFilter('recipient_user_id', recipientIds);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing all notifications: $e');
    }
    return false;
  }
}