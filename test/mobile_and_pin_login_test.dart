import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/screens/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Mobile & PIN Login Provider Tests', () {
    test('loginWithMobileAndPin validates and authenticates offline cached Admin user', () async {
      final prefs = await SharedPreferences.getInstance();
      final adminUser = User(
        name: 'Super Admin',
        mobileNo: '9876543210',
        userType: UserType.admin,
        customerId: 'ADM-001',
        status: 'Active',
      );
      await prefs.setString('user_pin', '654321');
      await prefs.setString('user_data', jsonEncode(adminUser.toJson()));

      final authProvider = AuthProvider();
      final result = await authProvider.loginWithMobileAndPin(
        mobileNo: '9876543210',
        pin: '654321',
      );

      expect(result.success, isTrue);
      expect(result.user?.name, equals('Super Admin'));
      expect(result.user?.userType, equals(UserType.admin));
      expect(authProvider.isLoggedIn, isTrue);
    });

    test('loginWithMobileAndPin validates and authenticates offline cached Manager user', () async {
      final prefs = await SharedPreferences.getInstance();
      final managerUser = User(
        name: 'Branch Manager',
        mobileNo: '9876543211',
        userType: UserType.manager,
        customerId: 'MGR-001',
        status: 'Active',
      );
      await prefs.setString('user_pin', '112233');
      await prefs.setString('user_data', jsonEncode(managerUser.toJson()));

      final authProvider = AuthProvider();
      final result = await authProvider.loginWithMobileAndPin(
        mobileNo: '9876543211',
        pin: '112233',
      );

      expect(result.success, isTrue);
      expect(result.user?.name, equals('Branch Manager'));
      expect(result.user?.userType, equals(UserType.manager));
      expect(authProvider.isLoggedIn, isTrue);
    });

    test('loginWithMobileAndPin validates and authenticates offline cached RO Officer', () async {
      final prefs = await SharedPreferences.getInstance();
      final roUser = User(
        name: 'RO Tomba',
        mobileNo: '9876543212',
        userType: UserType.ro,
        customerId: 'RO-001',
        roName: 'Tomba Singh',
        status: 'Active',
      );
      await prefs.setString('user_pin', '998877');
      await prefs.setString('user_data', jsonEncode(roUser.toJson()));

      final authProvider = AuthProvider();
      final result = await authProvider.loginWithMobileAndPin(
        mobileNo: '9876543212',
        pin: '998877',
      );

      expect(result.success, isTrue);
      expect(result.user?.name, equals('RO Tomba'));
      expect(result.user?.userType, equals(UserType.ro));
      expect(authProvider.isLoggedIn, isTrue);
    });

    test('loginWithMobileAndPin blocks Inactive user account', () async {
      final prefs = await SharedPreferences.getInstance();
      final inactiveUser = User(
        name: 'Inactive RO',
        mobileNo: '9876543213',
        userType: UserType.ro,
        customerId: 'RO-002',
        status: 'Inactive',
      );
      await prefs.setString('user_pin', '123456');
      await prefs.setString('user_data', jsonEncode(inactiveUser.toJson()));

      final authProvider = AuthProvider();
      final result = await authProvider.loginWithMobileAndPin(
        mobileNo: '9876543213',
        pin: '123456',
      );

      expect(result.success, isFalse);
      expect(result.isInactive, isTrue);
      expect(authProvider.isLoggedIn, isFalse);
    });

    test('loginWithMobileAndPin fails on mismatched Mobile or PIN', () async {
      final prefs = await SharedPreferences.getInstance();
      final adminUser = User(
        name: 'Super Admin',
        mobileNo: '9876543210',
        userType: UserType.admin,
        customerId: 'ADM-001',
        status: 'Active',
      );
      await prefs.setString('user_pin', '654321');
      await prefs.setString('user_data', jsonEncode(adminUser.toJson()));

      final authProvider = AuthProvider();

      // Wrong PIN
      final wrongPin = await authProvider.loginWithMobileAndPin(
        mobileNo: '9876543210',
        pin: '000000',
      );
      expect(wrongPin.success, isFalse);

      // Wrong Mobile
      final wrongMobile = await authProvider.loginWithMobileAndPin(
        mobileNo: '9111111111',
        pin: '654321',
      );
      expect(wrongMobile.success, isFalse);
    });
  });

  group('LoginPage UI Widget Tests for Mobile & PIN Inputs', () {
    testWidgets('LoginPage renders 10-digit Mobile Number and 6-digit PIN input fields', (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authProvider,
          child: const MaterialApp(
            home: LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for Mobile Number and Security PIN fields
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Enter 10-digit mobile number'), findsOneWidget);
      expect(find.text('+91 '), findsOneWidget);
      expect(find.text('Enter 6-Digit Security PIN'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'SIGN IN TO '), findsOneWidget);
    });

    testWidgets('LoginPage validates 10-digit mobile number requirement', (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authProvider,
          child: const MaterialApp(
            home: Scaffold(body: LoginPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter short mobile (e.g. 5 digits) and 6-digit PIN
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '98765');
      await tester.enterText(textFields.at(1), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'SIGN'));
      await tester.pumpAndSettle();
      expect(find.text('Mobile number must be exactly 10 digits'), findsOneWidget);
    });

    testWidgets('LoginPage validates empty mobile number requirement', (tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authProvider,
          child: const MaterialApp(
            home: Scaffold(body: LoginPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign In with empty fields -> SnackBar for mobile number
      await tester.tap(find.widgetWithText(ElevatedButton, 'SIGN IN'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your 10-digit Mobile Number'), findsOneWidget);
    });

    testWidgets('LoginPage successfully logs in with valid 10-digit mobile and 6-digit PIN', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final adminUser = User(
        name: 'Administrator',
        mobileNo: '9876543210',
        userType: UserType.admin,
        customerId: 'ADM-01',
        status: 'Active',
      );
      await prefs.setString('user_pin', '123456');
      await prefs.setString('user_data', jsonEncode(adminUser.toJson()));

      final authProvider = AuthProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authProvider,
          child: MaterialApp(
            routes: {
              '/home': (context) => const Scaffold(body: Text('Home Dashboard')),
            },
            home: const Scaffold(body: LoginPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '9876543210');
      await tester.enterText(textFields.at(1), '123456');

      await tester.tap(find.widgetWithText(ElevatedButton, 'SIGN IN'));
      await tester.pumpAndSettle();

      expect(find.text('Home Dashboard'), findsOneWidget);
      expect(authProvider.isLoggedIn, isTrue);
    });
  });
}
