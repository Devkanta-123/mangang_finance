import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
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

  Future<void> registerUser(User user) async {
    _currentUser = user;
    _activeRole = user.userType;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    _userPin = pin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', pin);
    _isLoggedIn = true;

    // Save & sync User Auth Record directly to Supabase table
    if (_currentUser != null) {
      final authRecord = UserAuthRecord(
        id: (_currentUser!.customerId != null && _currentUser!.customerId!.isNotEmpty)
            ? _currentUser!.customerId!
            : _currentUser!.mobileNo,
        mobileNo: _currentUser!.mobileNo,
        customerId: _currentUser!.customerId,
        userType: _currentUser!.userType,
        pin: pin,
        name: _currentUser!.name,
        roName: _currentUser!.roName,
        accountName: _currentUser!.accountName,
        status: _currentUser!.status,
      );

      await SupabaseService.instance.saveUserAuthRecord(authRecord);
    }

    notifyListeners();
  }

  /// Login using Mobile Number (10 digits) and 6-Digit Security PIN
  Future<LoginResult> loginWithMobileAndPin({
    required String mobileNo,
    required String pin,
  }) async {
    final cleanMobile = mobileNo.trim();
    final cleanPin = pin.trim();

    // 1. Query live Supabase database tables (user_auth, ro_accounts, loanee_accounts) by Mobile and PIN
    try {
      final supaUser = await SupabaseService.instance.fetchUserAuthByMobileAndPin(
        mobileNo: cleanMobile,
        pin: cleanPin,
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

    // 2. Local saved credentials check (offline backup for created user)
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin');
    final savedData = prefs.getString('user_data');
    if (savedPin == cleanPin && savedPin != null && savedData != null) {
      try {
        final cachedUser = User.fromJson(jsonDecode(savedData));
        if (cachedUser.mobileNo.trim() == cleanMobile || cleanMobile.isEmpty) {
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

    return const LoginResult(
      success: false,
      isInactive: false,
      message: 'Invalid Mobile Number or Security PIN. Please check your credentials.',
    );
  }

  /// Login exclusively using real Supabase Table PIN (with local saved PIN backup)
  Future<LoginResult> loginWithPin(String pin) async {
    // 1. Query live Supabase database tables (user_auth, ro_accounts, loanee_accounts)
    try {
      final supaUser = await SupabaseService.instance.fetchUserAuthByPin(pin);
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
        _userPin = pin;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_pin', pin);
        await prefs.setString('user_role', supaUser.userType.name);
        await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));

        notifyListeners();
        return LoginResult(success: true, message: 'Login successful', user: _currentUser);
      }
    } catch (e) {
      debugPrint('⚠️ Supabase PIN lookup error: $e');
    }

    // 2. Local saved PIN check (offline backup for created user)
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin');
    if (savedPin == pin && savedPin != null) {
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
      _userPin = pin;
      notifyListeners();
      return LoginResult(success: true, message: 'Login successful (Offline)', user: _currentUser);
    }

    return const LoginResult(
      success: false,
      isInactive: false,
      message: 'Invalid Security PIN. No matching user account found in database.',
    );
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

    if (_currentUser != null &&
        (_currentUser!.customerId == id ||
            _currentUser!.mobileNo == id ||
            (customerId != null && _currentUser!.customerId == customerId) ||
            (mobileNo != null && _currentUser!.mobileNo == mobileNo))) {
      _currentUser = _currentUser!.copyWith(status: newStatus);
      notifyListeners();
    }

    final success = await SupabaseService.instance.updateUserAuthStatus(
      targetRecord?.id ?? id,
      newStatus,
      customerId: customerId ?? targetRecord?.customerId,
      mobileNo: mobileNo ?? targetRecord?.mobileNo,
      userType: userType ?? targetRecord?.userType,
    );
    return success;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;
    notifyListeners();
  }
}