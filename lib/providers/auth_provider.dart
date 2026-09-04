import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/ro_model.dart';
import '../models/loanee_model.dart';
import '../services/supabase_service.dart';

class LoginResult {
  final bool success;
  final bool isInactive;
  final String message;
  final User? user;

  const LoginResult({
    required this.success,
    this.isInactive = false,
    this.message = '',
    this.user,
  });
}

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;
  String? _userPin;
  UserType _activeRole = UserType.admin; // Default role

  // Live admin accounts pulled directly from Supabase 'user_auth' table (no dummy data)
  List<UserAuthRecord> _adminUsers = [];
  bool _isLoadingAdminUsers = false;

  AuthProvider() {
    fetchAdminUsers();
  }

  List<UserAuthRecord> get adminUsers => List.unmodifiable(_adminUsers);
  bool get isLoadingAdminUsers => _isLoadingAdminUsers;

  void setAdminUsersForTesting(List<UserAuthRecord> users) {
    _adminUsers = users;
    notifyListeners();
  }

  void setCurrentUserForTesting(User user) {
    _currentUser = user;
    _activeRole = user.userType;
    notifyListeners();
  }

  User? get currentUser => _currentUser ?? User(
        name: _activeRole == UserType.admin
            ? 'Administrator'
            : (_activeRole == UserType.manager
                ? 'Branch Manager'
                : (_activeRole == UserType.ro ? 'RO Officer' : 'Loanee Account')),
        mobileNo: '',
        userType: _activeRole,
        customerId: _activeRole == UserType.admin
            ? 'ADM-01'
            : (_activeRole == UserType.manager ? 'MGR-01' : null),
        roName: null,
      );

  UserType get activeRole => _currentUser?.userType ?? _activeRole;
  bool get isLoggedIn => _isLoggedIn;
  String? get userPin => _userPin;

  void switchRole(UserType newRole) {
    _activeRole = newRole;
    _currentUser = User(
      name: newRole == UserType.admin
          ? 'Administrator'
          : (newRole == UserType.manager
              ? 'Branch Manager'
              : (newRole == UserType.ro ? 'RO Officer' : 'Loanee Account')),
      mobileNo: '',
      userType: newRole,
      customerId: newRole == UserType.admin
          ? 'ADM-01'
          : (newRole == UserType.manager ? 'MGR-01' : null),
      roName: null,
    );
    notifyListeners();
  }

  /// Check if an account already exists for (mobile_no, user_type) and/or customerId
  Future<bool> checkDuplicateUser({
    required String mobileNo,
    required UserType userType,
    String? customerId,
  }) async {
    return await SupabaseService.instance.checkUserAuthExists(
      mobileNo: mobileNo,
      userType: userType,
      customerId: customerId,
    );
  }

  /// Detailed duplicate user verification
  Future<Map<String, dynamic>> checkDuplicateUserDetailed({
    required String mobileNo,
    required UserType userType,
    String? customerId,
  }) async {
    return await SupabaseService.instance.checkUserAuthDuplicate(
      mobileNo: mobileNo,
      userType: userType,
      customerId: customerId,
    );
  }

  /// Verify that an RO account exists in ro_accounts before allowing registration
  Future<Map<String, dynamic>> verifyRoAccountForRegistration({
    required String customerId,
    required String roName,
    required String mobileNo,
    List<RoAccount>? localRos,
  }) async {
    final result = await SupabaseService.instance.verifyRoAccountRegistration(
      customerId: customerId,
      roName: roName,
      mobileNo: mobileNo,
    );

    if (result['matched'] == true) {
      return result;
    }

    // Local fallback check
    if (localRos != null && localRos.isNotEmpty) {
      final cleanCustId = customerId.trim().toLowerCase();
      final cleanName = roName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      final cleanMobile = mobileNo.replaceAll(RegExp(r'\D'), '');
      final normMobile = cleanMobile.length >= 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;

      for (final r in localRos) {
        final rCust = r.customerId.trim().toLowerCase();
        final rName = r.roName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        final rawRMobile = r.mobileNo.replaceAll(RegExp(r'\D'), '');
        final rMobile = rawRMobile.length >= 10 ? rawRMobile.substring(rawRMobile.length - 10) : rawRMobile;

        if (rCust == cleanCustId && rName == cleanName && rMobile == normMobile) {
          final isInactive = !r.isActive;
          return {
            'matched': true,
            'isInactive': isInactive,
            'account': r,
            'message': isInactive
                ? 'Your RO account is currently marked as Inactive. Login access is disabled. Please contact the administrator.'
                : 'RO account verified successfully.',
          };
        }
      }
    }

    return result;
  }

  /// Verify that a Loanee account exists in loanee_accounts before allowing registration
  Future<Map<String, dynamic>> verifyLoaneeAccountForRegistration({
    required String customerId,
    required String loaneeName,
    required String mobileNo,
    List<LoaneeAccount>? localLoanees,
  }) async {
    final result = await SupabaseService.instance.verifyLoaneeAccountRegistration(
      customerId: customerId,
      loaneeName: loaneeName,
      mobileNo: mobileNo,
    );

    if (result['matched'] == true) {
      return result;
    }

    // Local fallback check
    if (localLoanees != null && localLoanees.isNotEmpty) {
      final cleanCustId = customerId.trim().toLowerCase();
      final cleanName = loaneeName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      final cleanMobile = mobileNo.replaceAll(RegExp(r'\D'), '');
      final normMobile = cleanMobile.length >= 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;

      for (final l in localLoanees) {
        final lCust = l.customerId.trim().toLowerCase();
        final lName = l.loaneeName.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        final rawLMobile = l.mobileNo.replaceAll(RegExp(r'\D'), '');
        final lMobile = rawLMobile.length >= 10 ? rawLMobile.substring(rawLMobile.length - 10) : rawLMobile;

        if (lCust == cleanCustId && lName == cleanName && lMobile == normMobile) {
          final isInactive = !l.isActive;
          return {
            'matched': true,
            'isInactive': isInactive,
            'account': l,
            'message': isInactive
                ? 'Your Loanee account is currently marked as Inactive. Login access is disabled. Please contact the administrator.'
                : 'Loanee account verified successfully.',
          };
        }
      }
    }

    return result;
  }

  /// Add a new Admin user directly to Supabase user_auth table (called by Manager or Admin)
  Future<Map<String, dynamic>> addAdminUser({
    required String name,
    required String mobileNo,
    required String pin,
    String? customerId,
    String status = 'Active',
  }) async {
    final cleanMobile = mobileNo.trim();
    final cleanName = name.trim();
    final cleanPin = pin.trim();

    // Check duplicate
    final dupResult = await SupabaseService.instance.checkUserAuthDuplicate(
      mobileNo: cleanMobile,
      userType: UserType.admin,
      customerId: customerId,
    );

    if (dupResult['isDuplicate'] == true) {
      return {
        'success': false,
        'message': dupResult['message'] ?? 'An account with this Mobile Number or Customer ID already exists.',
      };
    }

    String finalCustId = customerId?.trim() ?? '';
    if (finalCustId.isEmpty) {
      finalCustId = await SupabaseService.instance.fetchNextRoleCustomerId(UserType.admin);
    }

    final newAdmin = UserAuthRecord(
      id: '',
      mobileNo: cleanMobile,
      customerId: finalCustId,
      userType: UserType.admin,
      pin: cleanPin,
      name: cleanName,
      status: status,
    );

    final saved = await SupabaseService.instance.saveUserAuthRecord(newAdmin);
    if (saved) {
      await fetchAdminUsers();
      return {
        'success': true,
        'message': 'Admin account ($finalCustId) for $cleanName added successfully.',
        'user': newAdmin,
      };
    } else {
      return {
        'success': false,
        'message': 'Failed to save admin account to Supabase user_auth table.',
      };
    }
  }

  /// Register a user in the application with duplicate prevention for (mobile_no, user_type) & customerId
  Future<Map<String, dynamic>> registerUser(User user) async {
    final cleanMobile = user.mobileNo.trim();
    final dupResult = await SupabaseService.instance.checkUserAuthDuplicate(
      mobileNo: cleanMobile,
      userType: user.userType,
      customerId: user.customerId,
    );

    if (dupResult['isDuplicate'] == true) {
      return {
        'success': false,
        'isDuplicate': true,
        'message': dupResult['message'] ?? 'An account matching these details is already registered.',
      };
    }

    _currentUser = user;
    _activeRole = user.userType;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
    notifyListeners();
    return {
      'success': true,
      'isDuplicate': false,
      'message': 'Account registered successfully',
    };
  }

  /// Create and persist 6-Digit PIN in Supabase user_auth table
  Future<bool> setPin(String pin, {UserType? userType, String? mobileNo}) async {
    final cleanPin = pin.trim();
    _userPin = cleanPin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', cleanPin);
    _isLoggedIn = true;

    final effectiveUserType = userType ?? _currentUser?.userType ?? _activeRole;
    final effectiveMobile = mobileNo?.trim() ?? _currentUser?.mobileNo.trim() ?? '';

    // Save & sync User Auth Record directly to Supabase table
    final authRecord = UserAuthRecord(
      id: '', // Leave empty so PostgreSQL auto-generates integer id (1, 2, 3...)
      mobileNo: effectiveMobile,
      customerId: _currentUser?.customerId,
      userType: effectiveUserType,
      pin: cleanPin,
      name: _currentUser?.name ??
          (effectiveUserType == UserType.admin
              ? 'Administrator'
              : (effectiveUserType == UserType.manager
                  ? 'Branch Manager'
                  : (effectiveUserType == UserType.ro ? 'RO Officer' : 'Loanee Account'))),
      roName: _currentUser?.roName,
      accountName: _currentUser?.accountName,
      status: _currentUser?.status ?? 'Active',
    );

    final success = await SupabaseService.instance.saveUserAuthRecord(authRecord);
    notifyListeners();
    return success;
  }

  /// Login using Mobile Number (10 digits), 6-Digit Security PIN, and optional UserType
  Future<LoginResult> loginWithMobileAndPin({
    required String mobileNo,
    required String pin,
    UserType? userType,
  }) async {
    final cleanMobile = mobileNo.trim();
    final cleanPin = pin.trim();

    // 1. Query live Supabase database tables (user_auth, ro_accounts, loanee_accounts) by Mobile, PIN, and UserType
    try {
      final supaUser = await SupabaseService.instance.fetchUserAuthByMobileAndPin(
        mobileNo: cleanMobile,
        pin: cleanPin,
        userType: userType,
      );
      if (supaUser != null) {
        // Check if account status is inactive - block login
        if (!supaUser.isActive) {
          debugPrint('🚫 Login rejected: Account for ${supaUser.name} (${supaUser.userType.name}) is INACTIVE');

          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('user_pin');
          await prefs.remove('user_data');
          await prefs.remove('user_role');

          return const LoginResult(
            success: false,
            isInactive: true,
            message: 'Your account is INACTIVE. Login access has been deactivated by the Administrator. Please contact admin to reactivate.',
          );
        }

        _currentUser = supaUser.toUser();
        _activeRole = supaUser.userType;
        _isLoggedIn = true;
        _userPin = cleanPin;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_pin', cleanPin);
        await prefs.setString('user_role', supaUser.userType.name);
        await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));

        notifyListeners();
        return LoginResult(success: true, message: 'Login successful', user: _currentUser);
      }
    } catch (e) {
      debugPrint('⚠️ Supabase Mobile & PIN login error: $e');
    }

    // 2. In-memory Admin Users check (offline / mock / unit testing sync)
    final matchingAdminMobile = _adminUsers.firstWhere(
      (u) =>
          (cleanMobile.isEmpty || u.mobileNo.trim() == cleanMobile) &&
          (u.pin.trim() == cleanPin) &&
          (userType == null || u.userType == userType),
      orElse: () => UserAuthRecord(
        id: '',
        mobileNo: '',
        userType: UserType.admin,
        pin: '',
        name: '',
        status: 'Active',
      ),
    );

    if (matchingAdminMobile.id.isNotEmpty && !matchingAdminMobile.isActive) {
      debugPrint('🚫 Login rejected: Admin account for ${matchingAdminMobile.name} is marked INACTIVE');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_pin');
      await prefs.remove('user_data');
      await prefs.remove('user_role');

      return const LoginResult(
        success: false,
        isInactive: true,
        message: 'Your account is INACTIVE. Login access has been deactivated by the Administrator. Please contact admin to reactivate.',
      );
    }

    // 3. Local saved credentials check (offline backup for created user)
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin');
    final savedData = prefs.getString('user_data');
    if (savedPin == cleanPin && savedPin != null && savedData != null) {
      try {
        final cachedUser = User.fromJson(jsonDecode(savedData));
        if ((cachedUser.mobileNo.trim() == cleanMobile || cleanMobile.isEmpty) &&
            (userType == null || cachedUser.userType == userType)) {
          if (!cachedUser.isActive) {
            return const LoginResult(
              success: false,
              isInactive: true,
              message: 'Your account is INACTIVE. Login access has been deactivated by the Administrator.',
            );
          }
          _currentUser = cachedUser;
          _activeRole = cachedUser.userType;
          _isLoggedIn = true;
          _userPin = cleanPin;
          notifyListeners();
          return LoginResult(success: true, message: 'Login successful (Offline)', user: _currentUser);
        }
      } catch (_) {}
    }

    final roleMsg = userType != null ? ' for ${userType.name.toUpperCase()} role' : '';
    return LoginResult(
      success: false,
      isInactive: false,
      message: 'Invalid Mobile Number or Security PIN$roleMsg. Please check your credentials.',
    );
  }

  /// Login exclusively using real Supabase Table PIN (with local saved PIN backup)
  Future<LoginResult> loginWithPin(String pin) async {
    final cleanPin = pin.trim();

    // 1. Query live Supabase database tables (user_auth, ro_accounts, loanee_accounts)
    try {
      final supaUser = await SupabaseService.instance.fetchUserAuthByPin(cleanPin);
      if (supaUser != null) {
        // Check if account status is inactive - block login
        if (!supaUser.isActive) {
          debugPrint('🚫 Login rejected: Account for ${supaUser.name} (${supaUser.userType.name}) is INACTIVE');
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('user_pin');
          await prefs.remove('user_data');
          await prefs.remove('user_role');

          return const LoginResult(
            success: false,
            isInactive: true,
            message: 'Your account is INACTIVE. Login access has been deactivated by the Administrator. Please contact admin to reactivate.',
          );
        }

        _currentUser = supaUser.toUser();
        _activeRole = supaUser.userType;
        _isLoggedIn = true;
        _userPin = cleanPin;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_pin', cleanPin);
        await prefs.setString('user_role', supaUser.userType.name);
        await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));

        notifyListeners();
        return LoginResult(success: true, message: 'Login successful', user: _currentUser);
      }
    } catch (e) {
      debugPrint('⚠️ Supabase PIN lookup error: $e');
    }

    // 2. In-memory Admin Users check (offline / mock / unit testing sync)
    final matchingAdminPin = _adminUsers.firstWhere(
      (u) => u.pin.trim() == cleanPin,
      orElse: () => UserAuthRecord(
        id: '',
        mobileNo: '',
        userType: UserType.admin,
        pin: '',
        name: '',
        status: 'Active',
      ),
    );

    if (matchingAdminPin.id.isNotEmpty && !matchingAdminPin.isActive) {
      debugPrint('🚫 Login rejected: Admin account for ${matchingAdminPin.name} is marked INACTIVE in adminUsers');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_pin');
      await prefs.remove('user_data');
      await prefs.remove('user_role');

      return const LoginResult(
        success: false,
        isInactive: true,
        message: 'Your account is INACTIVE. Login access has been deactivated by the Administrator. Please contact admin to reactivate.',
      );
    }

    // 3. Local saved PIN check (offline backup for created user)
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin');
    if (savedPin == cleanPin && savedPin != null) {
      final savedData = prefs.getString('user_data');
      if (savedData != null) {
        try {
          final cachedUser = User.fromJson(jsonDecode(savedData));
          if (!cachedUser.isActive) {
            return const LoginResult(
              success: false,
              isInactive: true,
              message: 'Your account is INACTIVE. Login access has been deactivated by the Administrator.',
            );
          }
          _currentUser = cachedUser;
          _activeRole = cachedUser.userType;
        } catch (_) {}
      }

      _isLoggedIn = true;
      _userPin = cleanPin;
      notifyListeners();
      return LoginResult(success: true, message: 'Login successful (Offline)', user: _currentUser);
    }

    return const LoginResult(
      success: false,
      isInactive: false,
      message: 'Invalid Security PIN. No matching user account found in database.',
    );
  }

  /// Reset Security PIN using Customer ID + Mobile Number (and optional User Type)
  Future<Map<String, dynamic>> resetPinWithCustomerIdAndMobile({
    required String customerId,
    required String mobileNo,
    required String newPin,
    UserType? userType,
  }) async {
    final result = await SupabaseService.instance.resetUserPinByCustomerIdAndMobile(
      customerId: customerId,
      mobileNo: mobileNo,
      newPin: newPin,
      userType: userType,
    );

    if (result['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_pin', newPin);
      _userPin = newPin;

      if (_currentUser != null &&
          (_currentUser!.customerId == customerId || _currentUser!.mobileNo == mobileNo)) {
        _currentUser = _currentUser!.copyWith(mobileNo: mobileNo);
      }
      notifyListeners();
    }

    return result;
  }

  /// Reset Security PIN for any Role (Admin, RO, Loanee) with live Supabase update
  Future<bool> resetPinForRole({
    required UserType role,
    required String mobileNo,
    String? customerId,
    required String newPin,
  }) async {
    // 1. Sync with Supabase table
    await SupabaseService.instance.resetUserPinInSupabase(
      userType: role,
      mobileNo: mobileNo,
      customerId: customerId,
      newPin: newPin,
    );

    // 2. Update local state & SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', newPin);
    _userPin = newPin;

    if (_currentUser == null || _currentUser!.userType == role) {
      _activeRole = role;
      _currentUser = User(
        name: role == UserType.admin
            ? 'Administrator'
            : (role == UserType.manager
                ? 'Branch Manager'
                : (role == UserType.ro ? 'RO Officer' : 'Loanee Account')),
        mobileNo: mobileNo,
        userType: role,
        customerId: customerId,
        status: _currentUser?.status ?? 'Active',
      );
    }

    notifyListeners();
    return true;
  }

  Future<void> fetchAdminUsers() async {
    _isLoadingAdminUsers = true;
    notifyListeners();
    try {
      final remoteList = await SupabaseService.instance.fetchAdminUsers();
      if (remoteList != null) {
        _adminUsers.clear();
        _adminUsers.addAll(remoteList.where((r) => r.userType == UserType.admin));
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching admin users in provider: $e');
    } finally {
      _isLoadingAdminUsers = false;
      notifyListeners();
    }
  }

  Future<bool> updateAdminUserStatus(
    String id,
    String newStatus, {
    String? customerId,
    String? mobileNo,
    UserType? userType,
  }) async {
    final index = _adminUsers.indexWhere((u) =>
        u.id == id ||
        (u.customerId != null && u.customerId == id) ||
        u.mobileNo == id ||
        (customerId != null && u.customerId == customerId) ||
        (mobileNo != null && u.mobileNo == mobileNo));

    UserAuthRecord? targetRecord;
    if (index != -1) {
      final old = _adminUsers[index];
      targetRecord = old.copyWith(status: newStatus);
      _adminUsers[index] = targetRecord;
      notifyListeners();
    }

    final bool isDeactivating = newStatus.trim().toLowerCase() == 'inactive';

    if (_currentUser != null &&
        (_currentUser!.customerId == id ||
            _currentUser!.mobileNo == id ||
            (customerId != null && _currentUser!.customerId == customerId) ||
            (mobileNo != null && _currentUser!.mobileNo == mobileNo))) {
      _currentUser = _currentUser!.copyWith(status: newStatus);
      if (isDeactivating) {
        _isLoggedIn = false;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('user_pin');
          await prefs.remove('user_data');
          await prefs.remove('user_role');
        } catch (_) {}
      }
      notifyListeners();
    }

    final success = await SupabaseService.instance.updateUserAuthStatus(
      targetRecord?.id ?? id,
      newStatus,
      customerId: customerId ?? targetRecord?.customerId,
      mobileNo: mobileNo ?? targetRecord?.mobileNo,
      userType: userType ?? targetRecord?.userType,
    );

    // Sync latest from Supabase
    try {
      await fetchAdminUsers();
    } catch (_) {}

    return success;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;
    notifyListeners();
  }
}