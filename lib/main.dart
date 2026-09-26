import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'models/notification_model.dart';
import 'screens/splash_screen.dart';
import 'screens/register_page.dart';
import 'screens/otp_verification_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/add_loanee_collection_sheet_page.dart';
import 'screens/ro_collection_sheet_view_page.dart';
import 'screens/route_management_page.dart';
import 'screens/create_loanee_page.dart';
import 'screens/loanee_list_page.dart';
import 'screens/create_ro_page.dart';
import 'screens/ro_list_page.dart';
import 'screens/account_page.dart';
import 'screens/recent_loanees_page.dart';
import 'screens/settings_page.dart';
import 'screens/late_fines_page.dart';
import 'screens/admin_users_list_page.dart';
import 'screens/collection_performance_page.dart';
import 'screens/holiday_management_page.dart';
import 'screens/missing_manager_page.dart';
import 'providers/auth_provider.dart';
import 'providers/loanee_provider.dart';
import 'providers/ro_provider.dart';
import 'providers/collection_sheet_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notification_provider.dart';
import 'services/supabase_service.dart';
import 'services/realtime_sync_service.dart';
import 'widgets/app_drawer.dart';
import 'widgets/notifications_sheet.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LoaneeProvider()),
        ChangeNotifierProvider(create: (_) => RoProvider()),
        ChangeNotifierProvider(create: (_) => CollectionSheetProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'Mangang Finance',
        theme: ThemeData(
          primaryColor: const Color(0xFF8B1A1A),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF8B1A1A),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B1A1A)),
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/register': (context) => const RegisterPage(),
          '/otp-verify': (context) => const OTPVerificationPage(),
          '/login': (context) => const LoginPage(),
          '/home': (context) => const MainPage(),
          '/holidays': (context) => const HolidayManagementPage(),
        },
      ),
    );
  }
}

// Main page with Toggle Navigation Drawer
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<AppNotification>? _notifSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRealtimeAndNotifications();
    });
  }

  void _initRealtimeAndNotifications() {
    if (!mounted) return;
    final collectionProvider = Provider.of<CollectionSheetProvider>(context, listen: false);
    final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    RealtimeSyncService.instance.registerProviders(
      collectionProvider: collectionProvider,
      loaneeProvider: loaneeProvider,
      notificationProvider: notifProvider,
      settingsProvider: settingsProvider,
    );

    notifProvider.initForUser(authProvider.currentUser);
    RealtimeSyncService.instance.startRealtimeSubscription();

    _notifSubscription?.cancel();
    _notifSubscription = notifProvider.notificationStream.listen((notif) {
      if (mounted) {
        _showInAppNotificationBanner(notif);
      }
    });

    // Check for today's or upcoming official holiday on login / app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkHolidayOnLogin(settingsProvider);
    });
  }

  void _checkHolidayOnLogin(SettingsProvider settingsProvider) {
    if (!mounted) return;
    final now = DateTime.now();
    final cleanNow = DateTime(now.year, now.month, now.day);
    final holidayToday = settingsProvider.getHolidayForDate(now);

    if (holidayToday != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.celebration_rounded, color: Colors.amber, size: 26),
              SizedBox(width: 10),
              Text('Official Holiday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today is an Official Holiday:\n"${holidayToday.description}"',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF8B1A1A)),
              ),
              const SizedBox(height: 10),
              Text(
                'Date: ${SettingsProvider.formatDate(holidayToday.date)}\n\n• Collection payments are suspended today.\n• No late fine penalties or auto-assessed fee records will be applied for today.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
    } else {
      // Check if an upcoming holiday is within next 3 days
      for (int i = 1; i <= 3; i++) {
        final futureDate = cleanNow.add(Duration(days: i));
        final upcoming = settingsProvider.getHolidayForDate(futureDate);
        if (upcoming != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              backgroundColor: Colors.indigo.shade900,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              duration: const Duration(seconds: 5),
              content: Row(
                children: [
                  const Icon(Icons.event_note_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📢 Upcoming Holiday: ${upcoming.description}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5),
                        ),
                        Text(
                          '${SettingsProvider.formatDate(upcoming.date)} (${upcoming.relativeLabel}). Collections will be closed.',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          break;
        }
      }
    }
  }

  void _showInAppNotificationBanner(AppNotification notif) {
    SoundService.instance.playNotificationSound(isPayment: notif.isPayment);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: notif.isPayment ? Colors.green.shade700 : const Color(0xFF8B1A1A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                notif.isPayment ? Icons.payments_rounded : Icons.notifications_active_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.message,
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.amber.shade300,
          onPressed: () => NotificationsSheet.show(context),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Navigation Pages List - Sequential matching menu ordering
    final bool isAdmin = authProvider.activeRole == UserType.admin;

    final List<Widget> pages = [
      // Index 0: Main Role Dashboard (Role-specific layout with overview widgets)
      HomePage(
        onNavigateToMenu: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),

      // Index 1: Create Loanee Account
      CreateLoaneePage(
        onAccountCreated: () {
          setState(() {
            _selectedIndex = 2; // Navigate to Loanee List after creation
          });
        },
      ),
      // Index 2: Loanee Accounts List
      LoaneeListPage(
        onCreateLoaneePressed: isAdmin
            ? () {
                setState(() {
                  _selectedIndex = 1; // Navigate to Create Loanee Page
                });
              }
            : null,
      ),
      // Index 3: Create RO Account
      CreateRoPage(
        onAccountCreated: () {
          setState(() {
            _selectedIndex = 4; // Navigate to RO List after creation
          });
        },
      ),
      // Index 4: RO Accounts List
      RoListPage(
        onCreateRoPressed: isAdmin
            ? () {
                setState(() {
                  _selectedIndex = 3; // Navigate to Create RO Page
                });
              }
            : null,
      ),

      // Under RO Accounts List (Indices 5, 6, 7)
      // Index 5: Add Loanee on R.O. Collection Sheet
      AddLoaneeCollectionSheetPage(
        onViewCollectionSheet: () {
          setState(() {
            _selectedIndex = 6; // Navigate to Collection Sheet Table view
          });
        },
      ),
      // Index 6: R.O. Collection Sheet View (Table View)
      RoCollectionSheetViewPage(
        onAddLoaneePressed: isAdmin
            ? () {
                setState(() {
                  _selectedIndex = 5; // Navigate to Add Loanee Form
                });
              }
            : null,
      ),
      // Index 7: Route Management Master
      const RouteManagementPage(),

      // Index 8: Simple Profile Page
      const AccountPage(),

      // Index 9: Recent Registered Loanees Page
      RecentLoaneesPage(
        onCreateLoaneePressed: isAdmin
            ? () {
                setState(() {
                  _selectedIndex = 1; // Navigate to Create Loanee Page
                });
              }
            : null,
      ),
      // Index 10: System Settings (Late Payment Settings, etc.)
      const SettingsPage(),
      // Index 11: Late Fines & Overdue Tracking
      const LateFinesPage(),
      // Index 12: Admin & Staff Accounts List
      const AdminUsersListPage(),
      // Index 13: Collection Performance (Manager & Admin only)
      CollectionPerformancePage(
        onBackToDashboard: () {
          setState(() {
            _selectedIndex = 0;
          });
        },
      ),
      // Index 14: Official Holiday Management (Admin only)
      const HolidayManagementPage(),
      // Index 15: Missing Manager (Admin, Manager, and RO)
      const MissingManagerPage(),
    ];

    // Access control protection: Only Admin and Manager can access index 13, Admin for 14
    int effectiveIndex = _selectedIndex;
    if (effectiveIndex == 13 &&
        authProvider.activeRole != UserType.admin &&
        authProvider.activeRole != UserType.manager) {
      effectiveIndex = 0;
    }
    if (effectiveIndex == 14 && authProvider.activeRole != UserType.admin) {
      effectiveIndex = 0;
    }
    if (effectiveIndex == 15 && authProvider.activeRole == UserType.loanee) {
      effectiveIndex = 0;
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _getMenuTitle(effectiveIndex, authProvider.activeRole),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 28),
          tooltip: 'Toggle Menu Drawer',
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          // Notification Bell Icon with Live Unread Badge
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) {
              final unread = notifProvider.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 23),
                    tooltip: 'Notifications',
                    onPressed: () => NotificationsSheet.show(context),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 2),

          // Active Role Level Badge in AppBar (Hidden for Loanee or when on Profile)
          if (authProvider.activeRole != UserType.loanee && effectiveIndex != 8)
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: authProvider.activeRole == UserType.manager
                    ? const Color(0xFF8B1A1A)
                    : Colors.amber.shade700,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    authProvider.activeRole.toString().split('.').last.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      // Toggle Navigation Drawer
      drawer: AppDrawer(
        selectedIndex: effectiveIndex,
        onMenuSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          Navigator.pop(context); // Close drawer after selection
        },
      ),
      body: pages[effectiveIndex < pages.length ? effectiveIndex : 0],
    );
  }

  String _getMenuTitle(int index, UserType role) {
    switch (index) {
      case 0:
        return 'Mangang Finance';
      case 1:
        return 'Create Loanee Account';
      case 2:
        return 'Loanee Accounts List';
      case 3:
        return 'Create RO Account';
      case 4:
        return 'RO Accounts List';
      case 5:
        return 'Add Loanee on R.O. Collection Sheet';
      case 6:
        return 'Collection Sheet';
      case 7:
        return 'Route Management';
      case 8:
        switch (role) {
          case UserType.admin:
            return 'Admin Profile';
          case UserType.manager:
            return 'Manager Profile';
          case UserType.ro:
            return 'RO Officer Profile';
          case UserType.loanee:
            return 'Loanee Profile';
        }
      case 9:
        return 'Recent Registered Loanees';
      case 10:
        return 'Settings';
      case 11:
        return 'Late Fines & Overdue Tracking';
      case 12:
        return 'Admin User';
      case 13:
        return 'Collection Performance';
      case 14:
        return 'Official Holiday Management';
      case 15:
        return 'Missing Manager';
      default:
        return 'Mangang Finance';
    }
  }
}