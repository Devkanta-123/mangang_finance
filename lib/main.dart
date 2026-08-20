import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
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
import 'providers/auth_provider.dart';
import 'providers/loanee_provider.dart';
import 'providers/ro_provider.dart';
import 'providers/collection_sheet_provider.dart';
import 'providers/settings_provider.dart';
import 'services/supabase_service.dart';
import 'widgets/app_drawer.dart';

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
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _getMenuTitle(_selectedIndex, authProvider.activeRole),
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
          // Active Role Level Badge in AppBar (Hidden for Loanee or when on Profile)
          if (authProvider.activeRole != UserType.loanee && _selectedIndex != 8)
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
                    color: Colors.black.withOpacity(0.15),
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
        selectedIndex: _selectedIndex,
        onMenuSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          Navigator.pop(context); // Close drawer after selection
        },
      ),
      body: pages[_selectedIndex < pages.length ? _selectedIndex : 0],
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
      default:
        return 'Mangang Finance';
    }
  }
}