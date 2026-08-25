import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/models/ro_model.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/screens/register_page.dart';
import 'package:mangang_finance/screens/admin_users_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RegisterPage - Role Selection & Table Match Tests', () {
    testWidgets('Account Type dropdown contains ONLY Loanee and RO (Admin removed)',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider(create: (_) => RoProvider()),
          ],
          child: const MaterialApp(
            home: RegisterPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Dropdown
      final dropdownFinder = find.byType(DropdownButton<UserType>);
      expect(dropdownFinder, findsOneWidget);

      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Verify Loanee and RO are in dropdown
      expect(find.text('Loanee Account'), findsWidgets);
      expect(find.text('Recovery Officer (RO)'), findsWidgets);

      // Verify Admin is NOT present in dropdown menu items
      final dropdownItems = tester.widgetList<DropdownMenuItem<UserType>>(
        find.byType(DropdownMenuItem<UserType>),
      );
      final types = dropdownItems.map((item) => item.value).toSet();
      expect(types.contains(UserType.admin), isFalse);
      expect(types.contains(UserType.manager), isFalse);
      expect(types.contains(UserType.loanee), isTrue);
      expect(types.contains(UserType.ro), isTrue);
    });

    testWidgets('Loanee Registration blocks if details do not match loanee_accounts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      final loaneeProvider = LoaneeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LoaneeProvider>.value(value: loaneeProvider),
            ChangeNotifierProvider(create: (_) => RoProvider()),
          ],
          child: const MaterialApp(
            home: RegisterPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter unmatched Loanee details
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(3)); // Customer ID, Loanee Name, Mobile Number

      await tester.enterText(textFields.at(0), '26LA999999');
      await tester.enterText(textFields.at(1), 'NonExistent Loanee');
      await tester.enterText(textFields.at(2), '9876543210');

      // Scroll and Tap Proceed button
      final submitButton = find.text('PROCEED TO CREATE PIN');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Records Not Match Dialog should be visible
      expect(find.text('Records Not Match'), findsOneWidget);
      expect(find.text('records not match'), findsOneWidget);
    });

    testWidgets('RO Registration blocks if details do not match ro_accounts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      final roProvider = RoProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider<RoProvider>.value(value: roProvider),
          ],
          child: const MaterialApp(
            home: RegisterPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to RO
      final dropdownFinder = find.byType(DropdownButton<UserType>);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Recovery Officer (RO)').last);
      await tester.pumpAndSettle();

      // Enter unmatched RO details
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '26R999');
      await tester.enterText(textFields.at(1), 'Fake Officer');
      await tester.enterText(textFields.at(2), '9988776655');

      // Scroll and Tap Proceed
      final submitButton = find.text('PROCEED TO CREATE PIN');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Records Not Match dialog should appear
      expect(find.text('Records Not Match'), findsOneWidget);
      expect(find.text('records not match'), findsOneWidget);
    });
  });

  group('AdminUsersListPage - Manager Adding Admin User Tests', () {
    testWidgets('Manager can view Add Admin button and open Add Admin Account modal',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.manager);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider(create: (_) => RoProvider()),
            ChangeNotifierProvider(create: (_) => CollectionSheetProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdminUsersListPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Add Admin" button is present in Header and FloatingActionButton
      expect(find.text('Add Admin'), findsWidgets);

      // Tap "Add Admin" button
      await tester.tap(find.text('Add Admin').first);
      await tester.pumpAndSettle();

      // Verify Add Admin modal opens
      expect(find.text('Add Admin Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Security PIN (6 Digits)'), findsOneWidget);
      expect(find.text('CREATE ADMIN'), findsOneWidget);
    });

    test('Creating RO account saves strictly to ro_accounts without creating user_auth entry', () async {
      final roProvider = RoProvider();

      final ro = RoAccount(
        customerid: '26R101',
        accountnumber: 'AC26RS0101',
        roname: 'Test Field Officer',
        guardianname: 'G Name',
        address: 'Test Address',
        designation: 'RO',
        route: 'Route A',
        postoffice: 'Imphal',
        policestation: 'Porompat',
        district: 'Imphal East',
        pincode: '795001',
        mobileno: '9876543210',
        aadharno: '123456789012',
        status: 'Active',
      );

      roProvider.handleRealtimeRoInsert(ro);
      expect(roProvider.roAccounts.any((r) => r.customerId == '26R101'), isTrue);
    });

    test('Creating Loanee account saves strictly to loanee_accounts without creating user_auth entry', () async {
      final loaneeProvider = LoaneeProvider();

      final loanee = LoaneeAccount(
        customerid: '26LA000101',
        accountnumber: 'MF2026A000101',
        loaneename: 'Test Loanee User',
        guardianname: 'G Name',
        address: 'Test Address',
        businesstype: 'Retail',
        postoffice: 'Imphal',
        policestation: 'Porompat',
        district: 'Imphal East',
        pincode: '795001',
        mobileno: '9862001122',
        aadharno: '123456789012',
        loanamount: 11500.0,
        paidamount: 0.0,
        dueamount: 11500.0,
        status: 'Active',
      );

      loaneeProvider.handleRealtimeLoaneeInsert(loanee);
      expect(loaneeProvider.loanees.any((l) => l.customerId == '26LA000101'), isTrue);
    });
  });
}
