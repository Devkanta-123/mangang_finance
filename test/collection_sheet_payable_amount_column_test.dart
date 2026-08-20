import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/screens/ro_collection_sheet_view_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoanPrincipalBreakdown & Business Rule Tests', () {
    test('Example 1: ₹11,500 loan amount -> ₹10,000 principal -> ₹100/day, ₹650/week', () {
      final breakdown = LoanPrincipalBreakdown.calculate(
        loanAmount: 11500.0,
        interestRate: 15.0,
        basePrincipal: 10000.0,
        baseDailyAmount: 100.0,
        baseWeeklyAmount: 650.0,
      );

      expect(breakdown.loanAmount, equals(11500.0));
      expect(breakdown.actualPrincipal, closeTo(10000.0, 0.01));
      expect(breakdown.interestAmount, closeTo(1500.0, 0.01));
      expect(breakdown.interestRate, equals(15.0));
      expect(breakdown.dailyPayable, closeTo(100.0, 0.01));
      expect(breakdown.weeklyPayable, closeTo(650.0, 0.01));
    });

    test('Example 2: ₹23,000 loan amount -> ₹20,000 principal -> ₹200/day, ₹1,300/week', () {
      final breakdown = LoanPrincipalBreakdown.calculate(
        loanAmount: 23000.0,
        interestRate: 15.0,
        basePrincipal: 10000.0,
        baseDailyAmount: 100.0,
        baseWeeklyAmount: 650.0,
      );

      expect(breakdown.loanAmount, equals(23000.0));
      expect(breakdown.actualPrincipal, closeTo(20000.0, 0.01));
      expect(breakdown.interestAmount, closeTo(3000.0, 0.01));
      expect(breakdown.interestRate, equals(15.0));
      expect(breakdown.dailyPayable, closeTo(200.0, 0.01));
      expect(breakdown.weeklyPayable, closeTo(1300.0, 0.01));
    });

    test('Example 3: ₹57,500 loan amount -> ₹50,000 principal -> ₹500/day, ₹3,250/week', () {
      final breakdown = LoanPrincipalBreakdown.calculate(
        loanAmount: 57500.0,
        interestRate: 15.0,
        basePrincipal: 10000.0,
        baseDailyAmount: 100.0,
        baseWeeklyAmount: 650.0,
      );

      expect(breakdown.loanAmount, equals(57500.0));
      expect(breakdown.actualPrincipal, closeTo(50000.0, 0.01));
      expect(breakdown.interestAmount, closeTo(7500.0, 0.01));
      expect(breakdown.interestRate, equals(15.0));
      expect(breakdown.dailyPayable, closeTo(500.0, 0.01));
      expect(breakdown.weeklyPayable, closeTo(3250.0, 0.01));
    });

    test('Example 4: ₹66,125 loan amount -> ₹57,500 principal -> ₹575/day, ₹3,737.50/week', () {
      final breakdown = LoanPrincipalBreakdown.calculate(
        loanAmount: 66125.0,
        interestRate: 15.0,
        basePrincipal: 10000.0,
        baseDailyAmount: 100.0,
        baseWeeklyAmount: 650.0,
      );

      expect(breakdown.loanAmount, equals(66125.0));
      expect(breakdown.actualPrincipal, closeTo(57500.0, 0.01));
      expect(breakdown.interestAmount, closeTo(8625.0, 0.01));
      expect(breakdown.interestRate, equals(15.0));
      expect(breakdown.dailyPayable, closeTo(575.0, 0.01));
      expect(breakdown.weeklyPayable, closeTo(3737.50, 0.01));
    });
  });

  group('RoCollectionEntry Dynamic Payable & Loan Amount Calculations', () {
    test('Calculates ₹500 / Day for ₹57,500 Daily loan (₹50k actual principal)', () {
      final dailyEntry57k = RoCollectionEntry(
        id: 'COL-1',
        customerId: 'CUST-001',
        accountNumber: 'ACC-001',
        loaneeName: 'Tomba Singh',
        loaneeAddress: 'Imphal West',
        collectionType: 'Daily',
        route: 'Mangang',
        mobileNo: '9876543210',
        loanAmount: 57500.0,
      );

      expect(dailyEntry57k.isDaily, isTrue);
      expect(dailyEntry57k.frequencyLabel, equals('Day'));
      expect(dailyEntry57k.getCalculatedLoanAmount(), equals(57500.0));
      expect(dailyEntry57k.getCalculatedActualPrincipal(), closeTo(50000.0, 0.01));
      expect(dailyEntry57k.getCalculatedInterestAmount(), closeTo(7500.0, 0.01));
      expect(dailyEntry57k.getCalculatedPayableAmount(), closeTo(500.0, 0.01));
      expect(dailyEntry57k.getFormattedPayableAmount(), equals('₹500 / Day'));
    });

    test('Calculates ₹200 / Day for ₹23,000 Daily loan (₹20k actual principal)', () {
      final dailyEntry23k = RoCollectionEntry(
        id: 'COL-2',
        customerId: 'CUST-002',
        accountNumber: 'ACC-002',
        loaneeName: 'Chaoba Devi',
        loaneeAddress: 'Imphal East',
        collectionType: 'Daily',
        route: 'Luwang',
        mobileNo: '9876543211',
        loanAmount: 23000.0,
      );

      expect(dailyEntry23k.isDaily, isTrue);
      expect(dailyEntry23k.frequencyLabel, equals('Day'));
      expect(dailyEntry23k.getCalculatedLoanAmount(), equals(23000.0));
      expect(dailyEntry23k.getCalculatedActualPrincipal(), closeTo(20000.0, 0.01));
      expect(dailyEntry23k.getCalculatedInterestAmount(), closeTo(3000.0, 0.01));
      expect(dailyEntry23k.getCalculatedPayableAmount(), closeTo(200.0, 0.01));
      expect(dailyEntry23k.getFormattedPayableAmount(), equals('₹200 / Day'));
    });

    test('Calculates configured Weekly amount (₹650 / Week for ₹11.5k total / ₹10k principal)', () {
      final weeklyEntry = RoCollectionEntry(
        id: 'COL-3',
        customerId: 'CUST-003',
        accountNumber: 'ACC-003',
        loaneeName: 'Biren Singh',
        loaneeAddress: 'Thoubal',
        collectionType: 'Mon', // Weekly day plan
        route: 'Khuman',
        mobileNo: '9876543212',
        loanAmount: 11500.0,
      );

      expect(weeklyEntry.isDaily, isFalse);
      expect(weeklyEntry.frequencyLabel, equals('Week'));
      expect(weeklyEntry.getCalculatedActualPrincipal(), closeTo(10000.0, 0.01));
      expect(weeklyEntry.getCalculatedInterestAmount(), closeTo(1500.0, 0.01));
      expect(weeklyEntry.getCalculatedPayableAmount(), closeTo(650.0, 0.01));
      expect(weeklyEntry.getFormattedPayableAmount(), equals('₹650 / Week'));
    });

    test('Maps dynamically from LoaneeAccount when entry loanAmount is not explicitly set', () {
      final entry = RoCollectionEntry(
        id: 'COL-4',
        customerId: 'CUST-004',
        accountNumber: 'ACC-004',
        loaneeName: 'Sanatomba',
        loaneeAddress: 'Bishnupur',
        collectionType: 'Daily',
        route: 'Angom',
        mobileNo: '9876543213',
      );

      final loanee = LoaneeAccount(
        customerid: 'CUST-004',
        accountnumber: 'ACC-004',
        loaneename: 'Sanatomba',
        guardianname: 'Guardian',
        address: 'Bishnupur',
        businesstype: 'Retail',
        postoffice: 'Bishnupur',
        policestation: 'Bishnupur',
        district: 'Bishnupur',
        pincode: '795126',
        mobileno: '9876543213',
        aadharno: '123456789012',
        loanamount: 57500.0,
      );

      expect(
        entry.getCalculatedPayableAmount(loaneeLoanAmount: loanee.loanAmount),
        closeTo(500.0, 0.01),
      );
      expect(
        entry.getFormattedPayableAmount(loaneeLoanAmount: loanee.loanAmount),
        equals('₹500 / Day'),
      );
    });

    test('JSON serialization & deserialization with all separate financial properties', () {
      final entry = RoCollectionEntry(
        id: 'COL-100',
        customerId: 'CUST-100',
        accountNumber: 'ACC-100',
        loaneeName: 'Memi Devi',
        loaneeAddress: 'Kakching',
        collectionType: 'Daily',
        route: 'Moirang',
        mobileNo: '9876543299',
        loanAmount: 57500.0,
        actualPrincipal: 50000.0,
        interestAmount: 7500.0,
        interestRate: 15.0,
        payableAmount: 500.0,
        frequency: 'Day',
      );

      final json = entry.toJson();
      expect(json['loan_amount'], equals(57500.0));
      expect(json['actual_principal'], equals(50000.0));
      expect(json['interest_amount'], equals(7500.0));
      expect(json['interest_rate'], equals(15.0));
      expect(json['payable_amount'], equals(500.0));
      expect(json['frequency'], equals('Day'));

      final reconstructed = RoCollectionEntry.fromJson(json);
      expect(reconstructed.id, equals('COL-100'));
      expect(reconstructed.loanAmount, equals(57500.0));
      expect(reconstructed.actualPrincipal, equals(50000.0));
      expect(reconstructed.interestAmount, equals(7500.0));
      expect(reconstructed.interestRate, equals(15.0));
      expect(reconstructed.payableAmount, equals(500.0));
      expect(reconstructed.frequency, equals('Day'));
      expect(reconstructed.getFormattedPayableAmount(), equals('₹500 / Day'));
    });
  });

  group('Collection Sheet Page UI Columns & Mapping', () {
    testWidgets('Collection Sheet Table has ACNO and Payable Amount columns and displays amounts', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authProvider = AuthProvider();
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();
      final roProvider = RoProvider();
      final settingsProvider = SettingsProvider();

      // Set admin user
      final adminUser = User(
        customerId: 'ADM-01',
        name: 'Administrator',
        userType: UserType.admin,
        mobileNo: '9999999999',
      );
      authProvider.setCurrentUserForTesting(adminUser);

      // Add sample daily and weekly entries
      final entryDaily = RoCollectionEntry(
        id: 'COL-D1',
        customerId: 'CUST-D1',
        accountNumber: 'ACC-D1',
        loaneeName: 'Daily Loanee ₹11.5k (₹10k princ)',
        loaneeAddress: 'Imphal West',
        collectionType: 'Daily',
        route: 'Office',
        mobileNo: '9876543201',
        loanAmount: 11500.0,
      );

      final entryDaily57k = RoCollectionEntry(
        id: 'COL-D2',
        customerId: 'CUST-D2',
        accountNumber: 'ACC-D2',
        loaneeName: 'Daily Loanee ₹57.5k (₹50k princ)',
        loaneeAddress: 'Imphal East',
        collectionType: 'Daily',
        route: 'Office',
        mobileNo: '9876543202',
        loanAmount: 57500.0,
      );

      final entryWeekly = RoCollectionEntry(
        id: 'COL-W1',
        customerId: 'CUST-W1',
        accountNumber: 'ACC-W1',
        loaneeName: 'Weekly Loanee ₹11.5k (₹10k princ)',
        loaneeAddress: 'Thoubal',
        collectionType: 'Mon',
        route: 'Office',
        mobileNo: '9876543203',
        loanAmount: 11500.0,
      );

      await collectionProvider.addCollectionEntry(entryDaily);
      await collectionProvider.addCollectionEntry(entryDaily57k);
      await collectionProvider.addCollectionEntry(entryWeekly);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: collectionProvider),
            ChangeNotifierProvider.value(value: loaneeProvider),
            ChangeNotifierProvider.value(value: roProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RoCollectionSheetViewPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on 'Office' route card to select route
      final officeRouteFinder = find.text('Office');
      expect(officeRouteFinder, findsWidgets);
      await tester.tap(officeRouteFinder.first);
      await tester.pumpAndSettle();

      // Verify Column headers: ACNO and Payable Amount
      expect(find.text('ACNO'), findsOneWidget);
      expect(find.text('Payable Amount'), findsOneWidget);

      // Verify displayed formatted payable amounts
      expect(find.text('₹100 / Day'), findsOneWidget);
      expect(find.text('₹500 / Day'), findsOneWidget);
      expect(find.text('₹650 / Week'), findsOneWidget);
    });
  });
}
