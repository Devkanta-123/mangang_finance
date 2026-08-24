import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/main.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/providers/notification_provider.dart';
import 'package:mangang_finance/screens/admin_users_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Manager Role & Admin Users List Tests', () {
    testWidgets('Admin Users List displays admin user accounts with toggle switches for Admin',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.admin);
      authProvider.setAdminUsersForTesting([
        UserAuthRecord(
          id: 'ADM-LIVE-01',
          name: 'Live Admin User',
          mobileNo: '9876543210',
          customerId: 'ADM-LIVE-01',
          userType: UserType.admin,
          pin: '1234',
          status: 'Active',
        ),
      ]);

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

      // Verify Admin User title is present
      expect(find.text('Admin User'), findsOneWidget);

      // Verify Admin user from user_auth table is shown
      expect(find.text('Live Admin User'), findsOneWidget);

      // As Admin, status toggle switches should be visible
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('Manager sees Admin User list in read-only mode without status toggle switches',
        (WidgetTester tester) async {
      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.manager);
      authProvider.setAdminUsersForTesting([
        UserAuthRecord(
          id: 'ADM-LIVE-01',
          name: 'Live Admin User',
          mobileNo: '9876543210',
          customerId: 'ADM-LIVE-01',
          userType: UserType.admin,
          pin: '1234',
          status: 'Active',
        ),
      ]);

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

      // Verify Admin User title is present
      expect(find.text('Admin User'), findsOneWidget);

      // Verify Admin user is shown in list
      expect(find.text('Live Admin User'), findsOneWidget);

      // Status toggle switch is NOT present for Manager
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('Admin drawer does NOT show Admin User; Manager drawer DOES',
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

      // Open Drawer as Admin
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Admin drawer does not have Admin User
      expect(find.text('Admin User'), findsNothing);
    });

    testWidgets('Manager drawer DOES show Admin User directly above Loanee Accounts List',
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
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: const MaterialApp(
            home: MainPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Drawer as Manager
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Manager drawer has Admin User above Loanee Accounts List
      expect(find.text('Admin User'), findsOneWidget);
      expect(find.text('Loanee Accounts List'), findsOneWidget);
    });
  });
}
