import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;
  String? _userPin;
  UserType _activeRole = UserType.admin; // Default role

  User? get currentUser => _currentUser ?? User(
        name: _activeRole == UserType.admin
            ? 'Administrator'
            : (_activeRole == UserType.ro ? 'RO Officer' : 'Loanee Account'),
        mobileNo: '',
        userType: _activeRole,
        customerId: _activeRole == UserType.admin ? 'ADM-01' : null,
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
          : (newRole == UserType.ro ? 'RO Officer' : 'Loanee Account'),
      mobileNo: '',
      userType: newRole,
      customerId: newRole == UserType.admin ? 'ADM-01' : null,
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
      );

      await SupabaseService.instance.saveUserAuthRecord(authRecord);
    }

    notifyListeners();
  }

  /// Login exclusively using real Supabase Table PIN (with local saved PIN backup)
  Future<bool> loginWithPin(String pin) async {
    // 1. Query live Supabase database tables (user_auth, ro_accounts, loanee_accounts)
    try {
      final supaUser = await SupabaseService.instance.fetchUserAuthByPin(pin);
      if (supaUser != null) {
        _currentUser = supaUser.toUser();
        _activeRole = supaUser.userType;
        _isLoggedIn = true;
        _userPin = pin;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_pin', pin);
        await prefs.setString('user_role', supaUser.userType.name);

        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Supabase PIN lookup error: $e');
    }

    // 2. Local saved PIN check (offline backup for created user)
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin');
    if (savedPin == pin && savedPin != null) {
      _isLoggedIn = true;
      _userPin = pin;
      notifyListeners();
      return true;
    }

    return false;
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
            : (role == UserType.ro ? 'RO Officer' : 'Loanee Account'),
        mobileNo: mobileNo,
        userType: role,
        customerId: customerId,
      );
    }

    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;
    notifyListeners();
  }
}