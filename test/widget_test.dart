// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/main.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';

import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/providers/notification_provider.dart';

void main() {
  testWidgets('MainPage renders correctly with drawer and role title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
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

    // Verify main page title
    expect(find.text('Mangang Finance'), findsWidgets);

    // Verify menu button exists
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
  });

  testWidgets('Loanee role drawer does not have Late Fine & Overdue Notice menu',
      (WidgetTester tester) async {
    final authProvider = AuthProvider();
    authProvider.switchRole(UserType.loanee);

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

    // Open Drawer
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Verify Loanee Drawer Items
    expect(find.text('My Dashboard'), findsWidgets);
    expect(find.text('Loanee Profile'), findsOneWidget);

    // Verify Late Fine menu is NOT in Loanee Drawer
    expect(find.text('Late Fine & Overdue Notice'), findsNothing);
    expect(find.text('Late Fines & Penalties'), findsNothing);
  });

  testWidgets('Manager role drawer has monitoring menus and no entry menus',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const MaterialApp(
          home: MainPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open Drawer
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Verify Manager Drawer Items
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Manager Dashboard')), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Admin User')), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Loanee Accounts List')), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('RO Accounts List')), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Collection Sheet')), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Master Routes')), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Recent Registered Loanees')), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Late Fines & Penalties')), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Manager Profile')), findsOneWidget);

    // Verify Entry menus are strictly excluded for Manager
    expect(find.text('Create Loanee Account'), findsNothing);
    expect(find.text('Create RO Account'), findsNothing);
    expect(find.text('Add Loanee on R.O. Collection Sheet'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('Admin Dashboard removes Total Sanctioned card; Manager Dashboard has Total Sanctioned and Recovered/Due',
      (WidgetTester tester) async {
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

    // On Admin Dashboard: No TOTAL SANCTIONED or ADMIN LIVE, nor Total Recovered/Due
    expect(find.text('ADMIN LIVE'), findsNothing);
    expect(find.text('Total Recovered'), findsNothing);
    expect(find.text('Total Due Remaining'), findsNothing);

    // Quick metric cards exist on Admin Dashboard
    expect(find.text('Total Loanees'), findsOneWidget);
    expect(find.text('Active ROs'), findsOneWidget);

    // Switch to Manager Dashboard
    authProvider.switchRole(UserType.manager);
    await tester.pumpAndSettle();

    // On Manager Dashboard: Total Sanctioned and Manager Monitoring exist
    expect(find.text('TOTAL SANCTIONED'), findsOneWidget);
    expect(find.text('MANAGER MONITORING'), findsOneWidget);
    // Hidden by default
    expect(find.text('Total Recovered'), findsNothing);
    expect(find.text('Total Due Remaining'), findsNothing);

    // Tap to reveal
    await tester.tap(find.text('MANAGER MONITORING'));
    await tester.pumpAndSettle();
    expect(find.text('Total Recovered'), findsOneWidget);
    expect(find.text('Total Due Remaining'), findsOneWidget);
  });
}


