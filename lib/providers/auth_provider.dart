import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;
  String? _otp;
  String? _userPin;
  UserType _activeRole = UserType.admin; // Default role

  User? get currentUser => _currentUser ?? User(
        name: _activeRole == UserType.admin
            ? 'Administrator'
            : (_activeRole == UserType.ro ? 'Rajesh Sharma (RO)' : 'Nongthombam Ibomcha'),
        mobileNo: _activeRole == UserType.ro ? '9774123890' : '9862145890',
        userType: _activeRole,
        customerId: _activeRole == UserType.loanee ? 'CUST-1001' : 'ADM-01',
        roName: _activeRole == UserType.ro ? 'Rajesh Sharma' : null,
      );

  UserType get activeRole => _currentUser?.userType ?? _activeRole;

  bool get isLoggedIn => _isLoggedIn;
  String? get otp => _otp;

  void switchRole(UserType newRole) {
    _activeRole = newRole;
    _currentUser = User(
      name: newRole == UserType.admin
          ? 'Administrator'
          : (newRole == UserType.ro ? 'Rajesh Sharma (RO)' : 'Nongthombam Ibomcha'),
      mobileNo: newRole == UserType.ro ? '9774123890' : '9862145890',
      userType: newRole,
      customerId: newRole == UserType.loanee ? 'CUST-1001' : 'ADM-01',
      roName: newRole == UserType.ro ? 'Rajesh Sharma' : null,
    );
    notifyListeners();
  }

  Future<void> registerUser(User user) async {
    _currentUser = user;
    _activeRole = user.userType;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', user.toJson().toString());
    notifyListeners();
  }

  void setOTP(String otp) {
    _otp = otp;
    notifyListeners();
  }

  bool verifyOTP(String enteredOTP) {
    return enteredOTP == _otp;
  }

  Future<void> setPin(String pin) async {
    _userPin = pin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', pin);
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<bool> loginWithPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin');

    if (pin == '123456') {
      _activeRole = UserType.admin;
      _currentUser = User(
        name: 'Administrator',
        mobileNo: '9862145890',
        userType: UserType.admin,
        customerId: 'ADM-01',
      );
      _isLoggedIn = true;
      _userPin = pin;
      notifyListeners();
      return true;
    } else if (pin == '789122') {
      _activeRole = UserType.ro;
      _currentUser = User(
        name: 'Rajesh Sharma (RO)',
        mobileNo: '9774123890',
        userType: UserType.ro,
        roName: 'Rajesh Sharma',
      );
      _isLoggedIn = true;
      _userPin = pin;
      notifyListeners();
      return true;
    } else if (pin == '112233') {
      _activeRole = UserType.loanee;
      _currentUser = User(
        name: 'Nongthombam Ibomcha',
        mobileNo: '9862145890',
        userType: UserType.loanee,
        customerId: 'CUST-1001',
        accountName: 'ACC-88239101',
      );
      _isLoggedIn = true;
      _userPin = pin;
      notifyListeners();
      return true;
    } else if (savedPin == pin && savedPin != null) {
      _isLoggedIn = true;
      _userPin = pin;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;
    notifyListeners();
  }

  bool validateDemoPin(String pin) {
    return pin == '123456' || pin == '789122' || pin == '112233';
  }
}