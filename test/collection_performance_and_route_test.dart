// test/collection_performance_and_route_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/main.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/models/route_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/providers/notification_provider.dart';
import 'package:mangang_finance/screens/collection_performance_page.dart';
import 'package:mangang_finance/screens/route_management_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Collection Performance & Route Management Tests', () {
    testWidgets('1. Access Control: Admin and Manager see Collection Performance in Drawer; RO and Loanee DO NOT', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.admin);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider(create: (_) => RoProvider()),
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

      // Open drawer as Admin
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Collection Performance'), findsOneWidget);

      // Close drawer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Switch to Manager
      authProvider.switchRole(UserType.manager);
      await tester.pumpAndSettle();

      // Open drawer as Manager
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Collection Performance'), findsOneWidget);

      // Close drawer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Switch to RO
      authProvider.switchRole(UserType.ro);
      await tester.pumpAndSettle();

      // Open drawer as RO
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Collection Performance'), findsNothing);

      // Close drawer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Switch to Loanee
      authProvider.switchRole(UserType.loanee);
      await tester.pumpAndSettle();

      // Open drawer as Loanee
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Collection Performance'), findsNothing);
    });

    testWidgets('2. Collection Performance Screen loads Today by default, shows TOTAL AMOUNT top card, RO & Admin filters, and modal with Loanee details only', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.manager);

      final collectionProvider = CollectionSheetProvider();
      final roProvider = RoProvider();

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final lastWeek = now.subtract(const Duration(days: 10));

      // Setup Routes & Collection Entries
      await collectionProvider.addRoute(RouteModel(id: 'R1', name: 'Mangang', code: 'MNG-01'));
      await collectionProvider.addRoute(RouteModel(id: 'R2', name: 'Luwang', code: 'LWG-01'));

      final card1 = RoCollectionEntry(
        id: 'COL-1',
        customerId: 'CUST-101',
        accountNumber: 'ACC-101',
        loaneeName: 'John Doe',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Mangang',
        mobileNo: '9876543210',
      );
      final card2 = RoCollectionEntry(
        id: 'COL-2',
        customerId: 'CUST-102',
        accountNumber: 'ACC-102',
        loaneeName: 'Jane Smith',
        loaneeAddress: 'Thoubal',
        collectionType: 'Weekly',
        route: 'Luwang',
        mobileNo: '9876543211',
      );
      await collectionProvider.addCollectionEntry(card1);
      await collectionProvider.addCollectionEntry(card2);

      // Payment 1: Today, collected by RO 'Bikram Singh'
      final payToday1 = CollectionPaymentModel(
        id: 'PAY-1',
        collectionId: 'COL-1',
        paymentAmount: 500.0,
        roName: 'Bikram Singh',
        roId: 'RO-01',
        roRoute: 'Mangang',
        createdAt: now,
      );

      // Payment 2: Today, collected by Admin 'Office Admin'
      final payToday2 = CollectionPaymentModel(
        id: 'PAY-2',
        collectionId: 'COL-2',
        paymentAmount: 1200.0,
        roName: 'Office Admin',
        roId: 'ADM-01',
        roRoute: 'Office',
        createdAt: now,
      );

      // Payment 3: Yesterday
      final payYesterday = CollectionPaymentModel(
        id: 'PAY-3',
        collectionId: 'COL-1',
        paymentAmount: 300.0,
        roName: 'Bikram Singh',
        roId: 'RO-01',
        roRoute: 'Mangang',
        createdAt: yesterday,
      );

      // Payment 4: Last Week
      final payLastWeek = CollectionPaymentModel(
        id: 'PAY-4',
        collectionId: 'COL-2',
        paymentAmount: 800.0,
        roName: 'Office Admin',
        roId: 'ADM-01',
        roRoute: 'Office',
        createdAt: lastWeek,
      );

      await collectionProvider.addCollectionPayment(payToday1);
      await collectionProvider.addCollectionPayment(payToday2);
      await collectionProvider.addCollectionPayment(payYesterday);
      await collectionProvider.addCollectionPayment(payLastWeek);

      // Launch CollectionPerformancePage for Manager
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider<RoProvider>.value(value: roProvider),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CollectionPerformancePage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Top Card with 'TOTAL AMOUNT' label
      expect(find.text('TOTAL AMOUNT'), findsOneWidget);
      expect(find.text('₹ 1700.00'), findsOneWidget);
      expect(find.text('Showing 2 Payments'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);

      // 2. Verify filter dropdowns: Only RO and Admin (no Master Route or Payment Mode dropdowns)
      expect(find.text('RO OFFICER'), findsOneWidget);
      expect(find.text('ADMINISTRATOR'), findsOneWidget);
      expect(find.text('MASTER ROUTE'), findsNothing);
      expect(find.text('PAYMENT MODE'), findsNothing);

      // 3. Tap 'Yesterday' filter chip
      await tester.tap(find.text('Yesterday'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Yesterday payment: PAY-3 (₹300.00)
      expect(find.text('₹ 300.00'), findsWidgets);
      expect(find.text('Showing 1 Payments'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);

      // 4. Tap back to 'Today'
      await tester.tap(find.text('Today'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Showing 2 Payments'), findsOneWidget);

      // 5. Tap on a payment card to open modal sheet
      await tester.tap(find.text('John Doe'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal shows Loanee Basic Details without Officer ID / Tag
      expect(find.text('Payment Details'), findsOneWidget);
      expect(find.text('Loanee Basic Details'), findsOneWidget);
      expect(find.text('Loanee Name'), findsOneWidget);
      expect(find.text('Customer ID'), findsOneWidget);
      expect(find.text('Officer ID / Tag'), findsNothing);
      expect(find.text('Officer ID'), findsNothing);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('3. Route Management displays today collection only, preserving historical payments', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.admin);

      final collectionProvider = CollectionSheetProvider();

      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 5));

      final testRoute = RouteModel(id: 'R-TEST', name: 'Khuman Route', code: 'KHM-01');
      await collectionProvider.addRoute(testRoute);

      final card = RoCollectionEntry(
        id: 'COL-KHM',
        customerId: 'CUST-KHM',
        accountNumber: 'ACC-KHM',
        loaneeName: 'Tomba Singh',
        loaneeAddress: 'Imphal East',
        collectionType: 'Daily',
        route: 'Khuman Route',
        mobileNo: '9888877777',
      );
      await collectionProvider.addCollectionEntry(card);

      // Historical Payment: 5 days ago: ₹1500
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-HIST',
          collectionId: 'COL-KHM',
          paymentAmount: 1500.0,
          createdAt: pastDate,
        ),
      );

      // Today Payment: ₹450
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-TODAY',
          collectionId: 'COL-KHM',
          paymentAmount: 450.0,
          createdAt: now,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider(create: (_) => RoProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RouteManagementPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In Route Management, it must display Today's Collection (₹450.00), NOT historical total (₹1950.00)
      expect(find.text('Today\'s Collection'), findsWidgets);
      expect(find.text('₹ 450.00'), findsOneWidget);
      expect(find.text('₹ 1950.00'), findsNothing);

      // Total payments in provider still contains all payments (intact history)
      expect(collectionProvider.payments.length, equals(2));
      expect(collectionProvider.getTotalPaidForCollection('COL-KHM'), equals(1950.0));
      expect(collectionProvider.getTodayPaidForCollection('COL-KHM'), equals(450.0));
    });
  });
}
