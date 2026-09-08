import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mangang_finance/main.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/providers/notification_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createLoaneeApp({
    required AuthProvider authProvider,
    required LoaneeProvider loaneeProvider,
    required CollectionSheetProvider collectionProvider,
    required SettingsProvider settingsProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<LoaneeProvider>.value(value: loaneeProvider),
        ChangeNotifierProvider(create: (_) => RoProvider()),
        ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MaterialApp(
        home: MainPage(),
      ),
    );
  }

  group('Loanee Overdue Notice Display Tests', () {
    testWidgets('1. Overdue loanee sees ONLY Total Loanee Amount and Overdue duration, NO 3% or fine calculations',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.loanee);

      final testUser = User(
        name: 'Thoiba Singh',
        mobileNo: '9876543210',
        userType: UserType.loanee,
        customerId: 'CUST-OVERDUE-01',
      );
      authProvider.setCurrentUserForTesting(testUser);

      final loaneeProvider = LoaneeProvider();
      final maturedLoanee = LoaneeAccount(
        customerid: 'CUST-OVERDUE-01',
        accountnumber: 'ACC-OVERDUE-99',
        loaneename: 'Thoiba Singh',
        guardianname: 'Elder Singh',
        address: 'Imphal',
        businesstype: 'Retail',
        postoffice: 'Imphal PO',
        policestation: 'Imphal PS',
        district: 'Imphal',
        pincode: '795001',
        mobileno: '9876543210',
        aadharno: '123456789012',
        loanamount: 50000.0,
        dueamount: 50000.0,
        paidamount: 0.0,
        loansanctiondate: DateTime.now().subtract(const Duration(days: 200)),
        loanmaturitydate: DateTime.now().subtract(const Duration(days: 50)), // Past maturity (matured)
        status: 'Active',
      );
      loaneeProvider.handleRealtimeLoaneeInsert(maturedLoanee);

      final collectionProvider = CollectionSheetProvider();
      final testEntry = RoCollectionEntry(
        id: 'entry-overdue-1',
        route: 'Route A',
        customerId: 'CUST-OVERDUE-01',
        accountNumber: 'ACC-OVERDUE-99',
        loaneeName: 'Thoiba Singh',
        loaneeAddress: 'Imphal',
        mobileNo: '9876543210',
        collectionType: 'Daily',
        loanAmount: 50000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
      );
      collectionProvider.handleRealtimeEntryInsert(testEntry);

      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(createLoaneeApp(
        authProvider: authProvider,
        loaneeProvider: loaneeProvider,
        collectionProvider: collectionProvider,
        settingsProvider: settingsProvider,
      ));

      await tester.pumpAndSettle();

      // Verify Overdue Notice banner is present
      expect(find.text('OVERDUE NOTICE'), findsWidgets);

      // Verify Total Loanee Amount is shown
      expect(find.text('Total Loanee Amount'), findsWidgets);
      expect(find.text('₹ 50000.00'), findsWidgets);

      // Verify Overdue duration label is shown
      expect(find.text('Overdue'), findsWidgets);

      // Verify "3%" is strictly NOT shown to the loanee
      expect(find.textContaining('3%'), findsNothing);
      expect(find.textContaining('3.0%'), findsNothing);

      // Verify detailed calculation explanations or admin config fine rates are NOT shown
      expect(find.textContaining('Calculation Method'), findsNothing);
      expect(find.textContaining('Admin Config'), findsNothing);
      expect(find.textContaining('ro_collection_payments'), findsNothing);
      expect(find.textContaining('Compounded'), findsNothing);
      expect(find.textContaining('Late Payment Fee ('), findsNothing);
      expect(find.textContaining('Post-Maturity Alert'), findsNothing);
      expect(find.textContaining('Acknowledge Notice'), findsNothing);
    });

    testWidgets('2. Non-overdue loanee sees Account in good standing and NO overdue notice',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.loanee);

      final testUser = User(
        name: 'Sanajaoba Meitei',
        mobileNo: '9123456780',
        userType: UserType.loanee,
        customerId: 'CUST-GOOD-02',
      );
      authProvider.setCurrentUserForTesting(testUser);

      final loaneeProvider = LoaneeProvider();
      final freshLoanee = LoaneeAccount(
        customerid: 'CUST-GOOD-02',
        accountnumber: 'ACC-GOOD-02',
        loaneename: 'Sanajaoba Meitei',
        guardianname: 'Guardian Meitei',
        address: 'Thoubal',
        businesstype: 'Agriculture',
        postoffice: 'Thoubal PO',
        policestation: 'Thoubal PS',
        district: 'Thoubal',
        pincode: '795138',
        mobileno: '9123456780',
        aadharno: '987654321012',
        loanamount: 30000.0,
        dueamount: 30000.0,
        paidamount: 0.0,
        loansanctiondate: DateTime.now(), // Today
        loanmaturitydate: DateTime.now().add(const Duration(days: 150)),
        status: 'Active',
      );
      loaneeProvider.handleRealtimeLoaneeInsert(freshLoanee);

      final collectionProvider = CollectionSheetProvider();
      final testEntry = RoCollectionEntry(
        id: 'entry-good-2',
        route: 'Route B',
        customerId: 'CUST-GOOD-02',
        accountNumber: 'ACC-GOOD-02',
        loaneeName: 'Sanajaoba Meitei',
        loaneeAddress: 'Thoubal',
        mobileNo: '9123456780',
        collectionType: 'Daily',
        loanAmount: 30000.0,
        createdAt: DateTime.now(), // Today
      );
      collectionProvider.handleRealtimeEntryInsert(testEntry);

      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(createLoaneeApp(
        authProvider: authProvider,
        loaneeProvider: loaneeProvider,
        collectionProvider: collectionProvider,
        settingsProvider: settingsProvider,
      ));

      await tester.pumpAndSettle();

      // Verify Account in good standing banner is shown
      expect(find.text('ACCOUNT STATUS'), findsOneWidget);
      expect(find.text('Account in good standing! No overdue accrued.'), findsOneWidget);

      // Verify OVERDUE NOTICE is NOT displayed
      expect(find.text('OVERDUE NOTICE'), findsNothing);
      expect(find.textContaining('3%'), findsNothing);
    });

    testWidgets('3. Overdue Notice modal shows only Total Loanee Amount and Overdue duration',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.loanee);

      final testUser = User(
        name: 'Ibopishak Singh',
        mobileNo: '9862000001',
        userType: UserType.loanee,
        customerId: 'CUST-MODAL-03',
      );
      authProvider.setCurrentUserForTesting(testUser);

      final loaneeProvider = LoaneeProvider();
      final maturedLoanee = LoaneeAccount(
        customerid: 'CUST-MODAL-03',
        accountnumber: 'ACC-MODAL-03',
        loaneename: 'Ibopishak Singh',
        guardianname: 'Elder Singh',
        address: 'Bishnupur',
        businesstype: 'Trade',
        postoffice: 'Bishnupur PO',
        policestation: 'Bishnupur PS',
        district: 'Bishnupur',
        pincode: '795126',
        mobileno: '9862000001',
        aadharno: '123456789012',
        loanamount: 40000.0,
        dueamount: 40000.0,
        paidamount: 0.0,
        loansanctiondate: DateTime.now().subtract(const Duration(days: 180)),
        loanmaturitydate: DateTime.now().subtract(const Duration(days: 30)),
        status: 'Active',
      );
      loaneeProvider.handleRealtimeLoaneeInsert(maturedLoanee);

      final collectionProvider = CollectionSheetProvider();
      final testEntry = RoCollectionEntry(
        id: 'entry-modal-3',
        route: 'Route C',
        customerId: 'CUST-MODAL-03',
        accountNumber: 'ACC-MODAL-03',
        loaneeName: 'Ibopishak Singh',
        loaneeAddress: 'Bishnupur',
        mobileNo: '9862000001',
        collectionType: 'Daily',
        loanAmount: 40000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 180)),
      );
      collectionProvider.handleRealtimeEntryInsert(testEntry);

      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(createLoaneeApp(
        authProvider: authProvider,
        loaneeProvider: loaneeProvider,
        collectionProvider: collectionProvider,
        settingsProvider: settingsProvider,
      ));

      await tester.pumpAndSettle();

      // In modal (or card):
      expect(find.text('Overdue Notice'), findsWidgets);
      expect(find.text('Total Loanee Amount'), findsWidgets);
      expect(find.text('₹ 40000.00'), findsWidgets);
      expect(find.text('Overdue'), findsWidgets);

      // Dismiss button if modal bottom sheet is open
      final dismissBtn = find.text('Dismiss');
      if (dismissBtn.evaluate().isNotEmpty) {
        await tester.tap(dismissBtn);
        await tester.pumpAndSettle();
      }
    });
  });
}
