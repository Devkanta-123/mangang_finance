import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/main.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/models/ro_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/providers/notification_provider.dart';
import 'package:mangang_finance/screens/ro_list_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({required RoProvider roProvider, required AuthProvider authProvider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<RoProvider>.value(value: roProvider),
        ChangeNotifierProvider(create: (_) => LoaneeProvider()),
        ChangeNotifierProvider(create: (_) => CollectionSheetProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MaterialApp(
        home: RoListPage(),
      ),
    );
  }

  test('RoProvider initializes with zero dummy data (pure live DB pulling)', () {
    final roProvider = RoProvider();
    // Verify no dummy data is pre-populated in provider memory
    expect(roProvider.roAccounts, isEmpty);
    expect(roProvider.totalRos, equals(0));
  });

  test('RoAccount.fromJson robustly handles database columns with int, snake_case, and null values', () {
    // Simulating database row returned from PostgreSQL / Supabase with integer numbers and snake_case
    final Map<String, dynamic> dbRow = {
      'customer_id': 'RO-CUST-8001',
      'account_number': 9918001, // int from DB
      'ro_name': 'Nongthombam Anand',
      'guardian_name': 'Tomba Singh',
      'address': 'Kwakeithel, Imphal',
      'designation': 'Senior Field Recovery Officer',
      'route_name': 'Imphal West Route 1',
      'post_office': 'Imphal Head Post Office',
      'police_station': 'Lamphel PS',
      'district': 'Imphal West',
      'pin_code': 795001, // int from DB
      'mobile_no': 9876543210, // int from DB
      'aadhar_no': 123456789012, // int from DB
      'created_at': '2026-01-15T10:30:00.000Z',
      'status': 'Active',
    };

    final ro = RoAccount.fromJson(dbRow);

    expect(ro.customerId, equals('RO-CUST-8001'));
    expect(ro.accountNumber, equals('9918001'));
    expect(ro.roName, equals('Nongthombam Anand'));
    expect(ro.guardianName, equals('Tomba Singh'));
    expect(ro.route, equals('Imphal West Route 1'));
    expect(ro.pinCode, equals('795001'));
    expect(ro.mobileNo, equals('9876543210'));
    expect(ro.aadharNo, equals('123456789012'));
    expect(ro.status, equals('Active'));
    expect(ro.isActive, isTrue);
  });

  testWidgets('RoListPage renders empty database state without errors', (tester) async {
    final handle = tester.ensureSemantics();
    final authProvider = AuthProvider();
    final roProvider = RoProvider();

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(roProvider: roProvider, authProvider: authProvider));
    await tester.pumpAndSettle();

    expect(find.text('RO Accounts'), findsOneWidget);
    expect(find.text('No RO Accounts in Database'), findsOneWidget);
    expect(find.text('Click "New RO Account" above to create & insert records directly into Supabase'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('RoListPage renders live RO accounts pulled from database without errors', (tester) async {
    final handle = tester.ensureSemantics();
    final authProvider = AuthProvider();
    final roProvider = RoProvider();

    // Populate live accounts pulled from database
    roProvider.setRoAccountsForTesting([
      RoAccount(
        customerid: 'RO-CUST-8001',
        accountnumber: 'RO-ACC-8823101',
        roname: 'Nongthombam Anand',
        guardianname: 'Tomba Singh',
        address: 'Sagolband',
        designation: 'Senior RO Officer',
        route: 'Imphal West Route',
        postoffice: 'Imphal PO',
        policestation: 'Imphal PS',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9876543210',
        aadharno: '123456789012',
        status: 'Active',
      ),
    ]);

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(roProvider: roProvider, authProvider: authProvider));
    await tester.pumpAndSettle();

    expect(find.text('RO Accounts'), findsOneWidget);
    expect(find.text('Nongthombam Anand'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Imphal West Route'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('Admin toggles RO status directly from card Switch and details dialog', (tester) async {
    final handle = tester.ensureSemantics();
    final authProvider = AuthProvider();
    authProvider.switchRole(UserType.admin);
    final roProvider = RoProvider();

    roProvider.setRoAccountsForTesting([
      RoAccount(
        customerid: 'RO-CUST-8001',
        accountnumber: 'RO-ACC-8823101',
        roname: 'Nongthombam Anand',
        guardianname: 'Tomba Singh',
        address: 'Sagolband',
        designation: 'Senior RO Officer',
        route: 'Imphal West Route',
        postoffice: 'Imphal PO',
        policestation: 'Imphal PS',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9876543210',
        aadharno: '123456789012',
        status: 'Active',
      ),
    ]);

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<RoProvider>.value(value: roProvider),
          ChangeNotifierProvider(create: (_) => LoaneeProvider()),
          ChangeNotifierProvider(create: (_) => CollectionSheetProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const MaterialApp(
          home: MainPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Drawer as Admin
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Click RO Accounts List menu item in Drawer
    await tester.tap(find.text('RO Accounts List'));
    await tester.pumpAndSettle();

    // Verify RO List page is loaded for Admin
    expect(find.text('RO Accounts'), findsOneWidget);
    expect(find.text('Nongthombam Anand'), findsOneWidget);

    // Toggle status directly via Switch on the card
    expect(find.byType(Switch), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Verify status updated to Inactive on card
    expect(find.text('INACTIVE'), findsOneWidget);

    // Tap on the RO card to open the details modal dialog
    await tester.tap(find.text('Nongthombam Anand'));
    await tester.pumpAndSettle();

    // Verify modal dialog opened with Admin toggle showing INACTIVE
    expect(find.text('Account Status (Admin)'), findsOneWidget);
    expect(find.text('1. Customer ID'), findsOneWidget);

    // Toggle switch inside dialog modal back to Active
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    // Close modal
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Verify status updated back to ACTIVE on card
    expect(find.text('ACTIVE'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('Non-admin users (e.g. RO/Manager) cannot see status toggle switch on card', (tester) async {
    final handle = tester.ensureSemantics();
    final authProvider = AuthProvider();
    authProvider.switchRole(UserType.ro); // Non-admin
    final roProvider = RoProvider();

    roProvider.setRoAccountsForTesting([
      RoAccount(
        customerid: 'RO-CUST-8001',
        accountnumber: 'RO-ACC-8823101',
        roname: 'Nongthombam Anand',
        guardianname: 'Tomba Singh',
        address: 'Sagolband',
        designation: 'Senior RO Officer',
        route: 'Imphal West Route',
        postoffice: 'Imphal PO',
        policestation: 'Imphal PS',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9876543210',
        aadharno: '123456789012',
        status: 'Active',
      ),
    ]);

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(roProvider: roProvider, authProvider: authProvider));
    await tester.pumpAndSettle();

    expect(find.text('RO Accounts'), findsOneWidget);
    expect(find.text('Nongthombam Anand'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // Switch should NOT be rendered for non-admin
    expect(find.byType(Switch), findsNothing);

    handle.dispose();
  });

  testWidgets('RoListPage search filtering dynamically filters by query', (tester) async {
    final handle = tester.ensureSemantics();
    final authProvider = AuthProvider();
    final roProvider = RoProvider();

    roProvider.setRoAccountsForTesting([
      RoAccount(
        customerid: 'RO-CUST-1',
        accountnumber: 'RO-ACC-1',
        roname: 'Anand Nongthombam',
        guardianname: 'Tomba',
        address: 'Sagolband',
        designation: 'Officer',
        route: 'West Route',
        postoffice: 'PO 1',
        policestation: 'PS 1',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9876543210',
        aadharno: '123456789012',
        status: 'Active',
      ),
      RoAccount(
        customerid: 'RO-CUST-2',
        accountnumber: 'RO-ACC-2',
        roname: 'Biren Meitei',
        guardianname: 'Chaoba',
        address: 'Thoubal',
        designation: 'Field Supervisor',
        route: 'Thoubal Route',
        postoffice: 'Thoubal PO',
        policestation: 'Thoubal PS',
        district: 'Thoubal',
        pincode: '795138',
        mobileno: '9123456789',
        aadharno: '987654321098',
        status: 'Active',
      ),
    ]);

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(roProvider: roProvider, authProvider: authProvider));
    await tester.pumpAndSettle();

    expect(find.text('Anand Nongthombam'), findsOneWidget);
    expect(find.text('Biren Meitei'), findsOneWidget);

    // Search for "Thoubal"
    await tester.enterText(find.byType(TextField), 'Thoubal');
    await tester.pumpAndSettle();

    expect(find.text('Anand Nongthombam'), findsNothing);
    expect(find.text('Biren Meitei'), findsOneWidget);

    handle.dispose();
  });
}
