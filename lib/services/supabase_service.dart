// lib/services/supabase_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loanee_model.dart';
import '../models/ro_model.dart';
import '../models/route_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/user_model.dart';
import '../models/collection_payment_model.dart';
import '../models/investment_model.dart';

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

  /// Save loanee account to Supabase 'loanee_accounts' table & sync with 'user_auth'
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
            
        debugPrint('✅ Successfully saved loanee ${loanee.customerid} to Supabase (loanee_accounts).');

        // Also ensure UserAuthRecord exists in user_auth so Loanee can login with PIN / mobile
        try {
          final authRecord = UserAuthRecord(
            id: loanee.customerId.isNotEmpty ? loanee.customerId : loanee.mobileNo,
            mobileNo: loanee.mobileNo,
            customerId: loanee.customerId,
            userType: UserType.loanee,
            pin: loanee.pinCode.isNotEmpty ? loanee.pinCode : '1234',
            name: loanee.loaneeName,
            accountName: loanee.accountNumber,
            status: loanee.status,
          );
          await saveUserAuthRecord(authRecord);
        } catch (authSaveErr) {
          debugPrint('⚠️ Note syncing Loanee to user_auth: $authSaveErr');
        }

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
        await supaClient
            .from('loanee_accounts')
            .delete()
            .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId');
            
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

        // 1. Update status in loanee_accounts (both status and is_active if column present)
        try {
          await supaClient
              .from('loanee_accounts')
              .update({
                'status': newStatus,
                'is_active': isActiveBool,
              })
              .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobileno.eq.$cleanCustId');
        } catch (_) {
          try {
            await supaClient
                .from('loanee_accounts')
                .update({'status': newStatus})
                .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobileno.eq.$cleanCustId');
          } catch (e1) {
            debugPrint('⚠️ Note updating loanee_accounts status: $e1');
          }
        }

        // 2. Sync status in user_auth table for matching record
        try {
          await supaClient
              .from('user_auth')
              .update({
                'status': newStatus,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .or('customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobile_no.eq.$cleanCustId');
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
                .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobileno.eq.$cleanCustId');
          } catch (_) {
            await supaClient
                .from('ro_accounts')
                .update({'status': newStatus})
                .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobileno.eq.$cleanCustId');
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

  /// Save RO account to Supabase 'ro_accounts' table & sync with 'user_auth'
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
            debugPrint('✅ Saved RO with fallback payload.');
          } catch (colErr2) {
            debugPrint('⚠️ Fallback upsert note: $colErr2');
          }
        }

        // Also ensure UserAuthRecord exists in user_auth so RO can login with PIN / mobile
        try {
          final authRecord = UserAuthRecord(
            id: ro.customerId.isNotEmpty ? ro.customerId : ro.mobileNo,
            mobileNo: ro.mobileNo,
            customerId: ro.customerId,
            userType: UserType.ro,
            pin: ro.pinCode.isNotEmpty ? ro.pinCode : '1234',
            name: ro.roName,
            roName: ro.roName,
            status: ro.status,
          );
          await saveUserAuthRecord(authRecord);
        } catch (authSaveErr) {
          debugPrint('⚠️ Note syncing RO to user_auth: $authSaveErr');
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
        await supaClient
            .from('ro_accounts')
            .delete()
            .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId');
            
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

        // 1. Update status in ro_accounts (both status and is_active if column present)
        try {
          await supaClient
              .from('ro_accounts')
              .update({
                'status': newStatus,
                'is_active': isActiveBool,
              })
              .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobileno.eq.$cleanCustId');
        } catch (_) {
          try {
            await supaClient
                .from('ro_accounts')
                .update({'status': newStatus})
                .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobileno.eq.$cleanCustId');
          } catch (e1) {
            debugPrint('⚠️ Note updating ro_accounts status: $e1');
          }
        }

        // 2. Sync status in user_auth table if matching record exists
        try {
          await supaClient
              .from('user_auth')
              .update({
                'status': newStatus,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .or('customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobile_no.eq.$cleanCustId');
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
                .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobileno.eq.$cleanCustId');
          } catch (_) {
            await supaClient
                .from('loanee_accounts')
                .update({'status': newStatus})
                .or('customerid.eq.$cleanCustId,customer_id.eq.$cleanCustId,id.eq.$cleanCustId,mobileno.eq.$cleanCustId');
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
            final authRecord = UserAuthRecord.fromJson(Map<String, dynamic>.from(response));
            final custId = (authRecord.customerId ?? authRecord.id).trim();
            final mobile = authRecord.mobileNo.trim();

            // If user_auth says Inactive, IT IS STRICTLY INACTIVE (Login blocked)
            bool isInactive = authRecord.status.trim().toLowerCase() == 'inactive';

            // Also cross-check if ro_accounts or loanee_accounts marks it Inactive
            if (!isInactive && authRecord.userType == UserType.ro) {
              try {
                var roQuery = supaClient.from('ro_accounts').select('status');
                if (custId.isNotEmpty) {
                  roQuery = roQuery.or('customerid.eq.$custId,customer_id.eq.$custId,id.eq.$custId,mobileno.eq.$mobile');
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
                  loaneeQuery = loaneeQuery.or('customerid.eq.$custId,customer_id.eq.$custId,id.eq.$custId,mobileno.eq.$mobile');
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
        } catch (e) {
          debugPrint('⚠️ user_auth check: $e');
        }

        // 2. Check 'ro_accounts' table fallback
        try {
          final roResponse = await supaClient
              .from('ro_accounts')
              .select('*')
              .or('pincode.eq.$pin,customerid.eq.$pin')
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
                  if (custId.isNotEmpty) 'id.eq.$custId',
                  if (mobile.isNotEmpty) 'mobile_no.eq.$mobile',
                ];
                if (orClauses.isNotEmpty) {
                  final authCheck = await supaClient
                      .from('user_auth')
                      .select('status')
                      .or(orClauses.join(','))
                      .maybeSingle();
                  if (authCheck != null && authCheck['status'] != null) {
                    if (authCheck['status'].toString().trim().toLowerCase() == 'inactive') {
                      isInactive = true;
                    }
                  }
                }
              } catch (_) {}
            }

            return UserAuthRecord(
              id: custId.isNotEmpty ? custId : mobile,
              mobileNo: mobile,
              customerId: custId,
              userType: UserType.ro,
              pin: pin,
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
              .or('pincode.eq.$pin,customerid.eq.$pin')
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
                  if (custId.isNotEmpty) 'id.eq.$custId',
                  if (mobile.isNotEmpty) 'mobile_no.eq.$mobile',
                ];
                if (orClauses.isNotEmpty) {
                  final authCheck = await supaClient
                      .from('user_auth')
                      .select('status')
                      .or(orClauses.join(','))
                      .maybeSingle();
                  if (authCheck != null && authCheck['status'] != null) {
                    if (authCheck['status'].toString().trim().toLowerCase() == 'inactive') {
                      isInactive = true;
                    }
                  }
                }
              } catch (_) {}
            }

            return UserAuthRecord(
              id: custId.isNotEmpty ? custId : mobile,
              mobileNo: mobile,
              customerId: custId,
              userType: UserType.loanee,
              pin: pin,
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

  /// Verify and fetch User Auth Record by Mobile Number (10 digits) and 6-Digit PIN
  Future<UserAuthRecord?> fetchUserAuthByMobileAndPin({
    required String mobileNo,
    required String pin,
  }) async {
    final cleanMobile = mobileNo.trim();
    final cleanPin = pin.trim();

    try {
      final supaClient = client;
      if (supaClient != null) {
        // 1. Check primary 'user_auth' table by matching mobile_no and pin
        try {
          final response = await supaClient
              .from('user_auth')
              .select('*')
              .eq('pin', cleanPin)
              .or('mobile_no.eq.$cleanMobile,id.eq.$cleanMobile')
              .maybeSingle();

          if (response != null && response.isNotEmpty) {
            final authRecord = UserAuthRecord.fromJson(Map<String, dynamic>.from(response));
            final custId = (authRecord.customerId ?? authRecord.id).trim();
            final mobile = authRecord.mobileNo.trim();

            // If user_auth says Inactive, IT IS STRICTLY INACTIVE (Login blocked)
            bool isInactive = authRecord.status.trim().toLowerCase() == 'inactive';

            // Also cross-check if ro_accounts or loanee_accounts marks it Inactive
            if (!isInactive && authRecord.userType == UserType.ro) {
              try {
                var roQuery = supaClient.from('ro_accounts').select('status');
                if (custId.isNotEmpty) {
                  roQuery = roQuery.or('customerid.eq.$custId,customer_id.eq.$custId,id.eq.$custId,mobileno.eq.$mobile');
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
                  loaneeQuery = loaneeQuery.or('customerid.eq.$custId,customer_id.eq.$custId,id.eq.$custId,mobileno.eq.$mobile');
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
        } catch (e) {
          debugPrint('⚠️ user_auth mobile & PIN check error: $e');
        }

        // 2. Check 'ro_accounts' table fallback
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
                  if (custId.isNotEmpty) 'id.eq.$custId',
                  if (mobile.isNotEmpty) 'mobile_no.eq.$mobile',
                ];
                if (orClauses.isNotEmpty) {
                  final authCheck = await supaClient
                      .from('user_auth')
                      .select('status,pin')
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

            return UserAuthRecord(
              id: custId.isNotEmpty ? custId : mobile,
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
          debugPrint('⚠️ ro_accounts mobile check: $e');
        }

        // 3. Check 'loanee_accounts' table fallback
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
                  if (custId.isNotEmpty) 'id.eq.$custId',
                  if (mobile.isNotEmpty) 'mobile_no.eq.$mobile',
                ];
                if (orClauses.isNotEmpty) {
                  final authCheck = await supaClient
                      .from('user_auth')
                      .select('status,pin')
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

            return UserAuthRecord(
              id: custId.isNotEmpty ? custId : mobile,
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
          debugPrint('⚠️ loanee_accounts mobile check: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching user auth by mobile & PIN from Supabase: $e');
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
    return (await fetchAdminUsers()) ?? [];
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

        // 1. Update status in 'user_auth' table
        try {
          final List<String> authOrClauses = [
            'id.eq.$cleanId',
            'customer_id.eq.$cleanId',
            'mobile_no.eq.$cleanId',
          ];
          if (cleanCustId.isNotEmpty && cleanCustId != cleanId) {
            authOrClauses.add('customer_id.eq.$cleanCustId');
            authOrClauses.add('id.eq.$cleanCustId');
          }
          if (cleanMobile.isNotEmpty && cleanMobile != cleanId) {
            authOrClauses.add('mobile_no.eq.$cleanMobile');
            authOrClauses.add('id.eq.$cleanMobile');
          }

          await supaClient.from('user_auth').update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          }).or(authOrClauses.toSet().join(','));
        } catch (eAuth) {
          debugPrint('⚠️ Error updating user_auth status in Supabase: $eAuth');
          try {
            await supaClient.from('user_auth').update({
              'status': newStatus,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', cleanId);
          } catch (_) {}
        }

        // Build match clause for related tables (ro_accounts and loanee_accounts)
        final List<String> matchOrClauses = [
          'customerid.eq.$cleanId',
          'customer_id.eq.$cleanId',
          'id.eq.$cleanId',
          'mobileno.eq.$cleanId',
          'mobile_no.eq.$cleanId',
        ];
        if (cleanCustId.isNotEmpty && cleanCustId != cleanId) {
          matchOrClauses.addAll([
            'customerid.eq.$cleanCustId',
            'customer_id.eq.$cleanCustId',
            'id.eq.$cleanCustId',
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
}