import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/models/ro_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/screens/home_page.dart';
import 'package:mangang_finance/widgets/ro_daily_collection_pie_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RO Daily Collection 3D Pie Chart & Ledger Pagination Tests', () {
    testWidgets('RoDailyCollectionPieChart renders strictly today collections and responds to interaction',
        (WidgetTester tester) async {
      final roProvider = RoProvider();
      final collectionProvider = CollectionSheetProvider();

      // Add dummy payments for today
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-101',
          collectionId: 'CARD-1',
          paymentAmount: 1500.0,
          remainingBalance: 3500.0,
          lateFine: 25.0,
          paymentType: 'Cash',
          roName: 'Officer Tom',
          roId: 'RO-001',
          roRoute: 'Route A',
          createdAt: DateTime.now(),
        ),
      );

      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-102',
          collectionId: 'CARD-2',
          paymentAmount: 2500.0,
          remainingBalance: 5000.0,
          lateFine: 0.0,
          paymentType: 'Gpay',
          roName: 'Officer Jerry',
          roId: 'RO-002',
          roRoute: 'Route B',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RoDailyCollectionPieChart(
                roProvider: roProvider,
                collectionProvider: collectionProvider,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Chart Title and Today Live Badge
      expect(find.text('RO Daily Collection Analytics'), findsOneWidget);
      expect(find.textContaining('Today:'), findsOneWidget);

      // Verify RO names and breakdown
      expect(find.text('Officer Tom'), findsWidgets);
      expect(find.text('Officer Jerry'), findsWidgets);
      expect(find.text("Today's RO Performance Overview"), findsOneWidget);
      expect(find.text('₹ 4000.00'), findsOneWidget);

      // Tap on Officer Tom legend chip to select
      await tester.tap(find.text('Officer Tom').first);
      await tester.pumpAndSettle();

      // Verify Spotlight details for selected officer
      expect(find.textContaining('OF TODAY'), findsOneWidget);
      expect(find.text('₹ 1500.00'), findsOneWidget);
    });

    testWidgets('Admin Dashboard contains 3D Pie Chart and paginates ledger 5 records by default',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();
      final loaneeProvider = LoaneeProvider();
      final roProvider = RoProvider();
      final collectionProvider = CollectionSheetProvider();
      final settingsProvider = SettingsProvider();

      // Add 12 dummy payments to test pagination of 5 items per page
      for (int i = 1; i <= 12; i++) {
        await collectionProvider.addCollectionPayment(
          CollectionPaymentModel(
            id: 'TXN-$i',
            collectionId: 'ENTRY-$i',
            paymentAmount: 500.0 * i,
            remainingBalance: 10000.0 - (500.0 * i),
            lateFine: 0.0,
            paymentType: 'Cash',
            roName: 'Officer ${i % 3 + 1}',
            roId: 'RO-00${i % 3 + 1}',
            roRoute: 'Route ${i % 2 == 0 ? "A" : "B"}',
            createdAt: DateTime.now().subtract(Duration(minutes: i)),
          ),
        );
      }

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LoaneeProvider>.value(value: loaneeProvider),
            ChangeNotifierProvider<RoProvider>.value(value: roProvider),
            ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify 3D Pie chart is present on Admin Panel
      expect(find.text('RO Daily Collection Analytics'), findsOneWidget);
      expect(find.text('Route-Wise Collection Analytics'), findsOneWidget);

      // Scroll down to the pagination controls
      await tester.scrollUntilVisible(
        find.byTooltip('Next Page'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Verify default pagination: 5 records per page, showing "Showing 1–5 of 12 entries"
      expect(find.text('Showing 1–5 of 12 entries'), findsOneWidget);
      expect(find.text('Page 1 of 3'), findsOneWidget);

      // Tap Next Page button
      await tester.tap(find.byTooltip('Next Page'));
      await tester.pumpAndSettle();

      // Verify Page 2: "Showing 6–10 of 12 entries"
      expect(find.text('Showing 6–10 of 12 entries'), findsOneWidget);
      expect(find.text('Page 2 of 3'), findsOneWidget);

      // Tap Next Page button to Page 3
      await tester.scrollUntilVisible(
        find.byTooltip('Next Page'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Next Page'));
      await tester.pumpAndSettle();

      // Verify Page 3: "Showing 11–12 of 12 entries"
      expect(find.text('Showing 11–12 of 12 entries'), findsOneWidget);
      expect(find.text('Page 3 of 3'), findsOneWidget);

      // Tap Previous Page button back to Page 2
      await tester.scrollUntilVisible(
        find.byTooltip('Previous Page'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Previous Page'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 6–10 of 12 entries'), findsOneWidget);
      expect(find.text('Page 2 of 3'), findsOneWidget);

      // Tap First Page button back to Page 1
      await tester.scrollUntilVisible(
        find.byTooltip('First Page'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('First Page'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 1–5 of 12 entries'), findsOneWidget);
      expect(find.text('Page 1 of 3'), findsOneWidget);
    });

    testWidgets('RO Dashboard metrics strictly calculate today records collected by logged-in RO only',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();
      // Login as RO Officer "Officer Tom" (RO-001)
      authProvider.switchRole(UserType.ro);
      authProvider.setCurrentUserForTesting(
        User(
          name: 'Officer Tom',
          mobileNo: '9876543210',
          userType: UserType.ro,
          customerId: 'RO-001',
        ),
      );

      final roProvider = RoProvider();
      roProvider.setRoAccountsForTesting([
        RoAccount(
          customerid: 'RO-001',
          accountnumber: 'ACC-RO-1',
          roname: 'Officer Tom',
          guardianname: 'Father Tom',
          address: 'Imphal',
          designation: 'Field Officer',
          route: 'Route A',
          postoffice: 'PO',
          policestation: 'PS',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9876543210',
          aadharno: '123456789012',
          status: 'Active',
        ),
      ]);

      final collectionProvider = CollectionSheetProvider();
      final settingsProvider = SettingsProvider();

      // Today's payment collected by Officer Tom
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-TODAY-TOM',
          collectionId: 'CARD-TOM-1',
          paymentAmount: 2500.0,
          remainingBalance: 5000.0,
          lateFine: 0.0,
          paymentType: 'Cash',
          roName: 'Officer Tom',
          roId: 'RO-001',
          roRoute: 'Route A',
          createdAt: DateTime.now(),
        ),
      );

      // Yesterday's payment collected by Officer Tom (should NOT be counted in Today's metrics)
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-YESTERDAY-TOM',
          collectionId: 'CARD-TOM-2',
          paymentAmount: 8000.0,
          remainingBalance: 2000.0,
          lateFine: 0.0,
          paymentType: 'Cash',
          roName: 'Officer Tom',
          roId: 'RO-001',
          roRoute: 'Route A',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      // Today's payment collected by Officer Jerry (other RO - should NOT be counted in Tom's metrics)
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-TODAY-JERRY',
          collectionId: 'CARD-JERRY-1',
          paymentAmount: 9900.0,
          remainingBalance: 1000.0,
          lateFine: 0.0,
          paymentType: 'Cash',
          roName: 'Officer Jerry',
          roId: 'RO-002',
          roRoute: 'Route B',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LoaneeProvider>(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider<RoProvider>.value(value: roProvider),
            ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify RO Officer Portal Header
      expect(find.text('RO Officer '), findsOneWidget);
      expect(find.text('Officer Tom'), findsOneWidget);

      // Verify "Total Collection Records" and "Total Recovered" strictly show Today's Tom metrics (1 record, ₹ 2500.00)
      expect(find.text('Total Collection Records'), findsOneWidget);
      expect(find.text('1 Records'), findsOneWidget);
      expect(find.text("Today's Sheet Entries"), findsOneWidget);

      expect(find.text('Total Recovered'), findsOneWidget);
      expect(find.text('₹ 2500.00'), findsWidgets);
      expect(find.text("Today's Recovered"), findsOneWidget);

      // Verify "Recent Sheet Entries" section header
      expect(find.text('Recent Sheet Entries'), findsOneWidget);
    });

    testWidgets('Cross-RO entries and collections are never leaked to other ROs',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();
      // Login as RO Officer "Officer Tom" (RO-001) assigned to Route A
      authProvider.switchRole(UserType.ro);
      authProvider.setCurrentUserForTesting(
        User(
          name: 'Officer Tom',
          mobileNo: '9876543210',
          userType: UserType.ro,
          customerId: 'RO-001',
        ),
      );

      final roProvider = RoProvider();
      roProvider.setRoAccountsForTesting([
        RoAccount(
          customerid: 'RO-001',
          accountnumber: 'ACC-RO-1',
          roname: 'Officer Tom',
          guardianname: 'Father Tom',
          address: 'Imphal',
          designation: 'Field Officer',
          route: 'Route A',
          postoffice: 'PO',
          policestation: 'PS',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9876543210',
          aadharno: '123456789012',
          status: 'Active',
        ),
      ]);

      final collectionProvider = CollectionSheetProvider();
      final settingsProvider = SettingsProvider();

      // Card for Route A (Officer Tom's route)
      await collectionProvider.addCollectionEntry(
        RoCollectionEntry(
          id: 'CARD-ROUTE-A',
          customerId: 'CUST-A',
          accountNumber: 'ACC-A',
          loaneeName: 'Loanee Alice',
          loaneeAddress: 'Imphal West',
          mobileNo: '9111111111',
          route: 'Route A',
          collectionType: 'Daily',
        ),
      );

      // Card for Route B (Officer Jerry's route)
      await collectionProvider.addCollectionEntry(
        RoCollectionEntry(
          id: 'CARD-ROUTE-B',
          customerId: 'CUST-B',
          accountNumber: 'ACC-B',
          loaneeName: 'Loanee Bob',
          loaneeAddress: 'Imphal East',
          mobileNo: '9222222222',
          route: 'Route B',
          collectionType: 'Daily',
        ),
      );

      // Payment on Route A collected by Officer Tom
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-TOM-1',
          collectionId: 'CARD-ROUTE-A',
          paymentAmount: 2500.0,
          remainingBalance: 7500.0,
          lateFine: 0.0,
          paymentType: 'Cash',
          roName: 'Officer Tom',
          roId: 'RO-001',
          roRoute: 'Route A',
          createdAt: DateTime.now(),
        ),
      );

      // Payment on Route B collected by Officer Jerry
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-JERRY-1',
          collectionId: 'CARD-ROUTE-B',
          paymentAmount: 5000.0,
          remainingBalance: 15000.0,
          lateFine: 0.0,
          paymentType: 'Cash',
          roName: 'Officer Jerry',
          roId: 'RO-002',
          roRoute: 'Route B',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<LoaneeProvider>(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider<RoProvider>.value(value: roProvider),
            ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Officer Tom has 1 collection today (₹ 2500.00)
      expect(find.text('Total Collection Records'), findsOneWidget);
      expect(find.text('1 Records'), findsOneWidget);

      expect(find.text('Total Recovered'), findsOneWidget);
      expect(find.text('₹ 2500.00'), findsWidgets);

      // Recent Sheet Entries on Tom's dashboard must only list Route A (Loanee Alice), NOT Route B (Loanee Bob)
      expect(find.text('Loanee Alice'), findsOneWidget);
      expect(find.text('Loanee Bob'), findsNothing);

      // Now switch to Officer Jerry (RO-002, Route B)
      authProvider.setCurrentUserForTesting(
        User(
          name: 'Officer Jerry',
          mobileNo: '9876543211',
          userType: UserType.ro,
          customerId: 'RO-002',
        ),
      );

      roProvider.setRoAccountsForTesting([
        RoAccount(
          customerid: 'RO-001',
          accountnumber: 'ACC-RO-1',
          roname: 'Officer Tom',
          guardianname: 'Father Tom',
          address: 'Imphal',
          designation: 'Field Officer',
          route: 'Route A',
          postoffice: 'PO',
          policestation: 'PS',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9876543210',
          aadharno: '123456789012',
          status: 'Active',
        ),
        RoAccount(
          customerid: 'RO-002',
          accountnumber: 'ACC-RO-2',
          roname: 'Officer Jerry',
          guardianname: 'Father Jerry',
          address: 'Imphal East',
          designation: 'Field Officer',
          route: 'Route B',
          postoffice: 'PO',
          policestation: 'PS',
          district: 'Imphal East',
          pincode: '795005',
          mobileno: '9876543211',
          aadharno: '123456789013',
          status: 'Active',
        ),
      ]);

      await tester.pumpAndSettle();

      // Officer Jerry sees 1 collection today (₹ 5000.00)
      expect(find.text('Total Collection Records'), findsOneWidget);
      expect(find.text('1 Records'), findsOneWidget);

      expect(find.text('Total Recovered'), findsOneWidget);
      expect(find.text('₹ 5000.00'), findsWidgets);

      // Recent Sheet Entries on Jerry's dashboard must only list Route B (Loanee Bob), NOT Route A (Loanee Alice)
      expect(find.text('Loanee Bob'), findsOneWidget);
      expect(find.text('Loanee Alice'), findsNothing);
    });
  });
}

