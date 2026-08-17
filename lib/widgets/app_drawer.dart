// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'app_logo.dart';

class DrawerMenuItemData {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final bool isHighlighted;

  DrawerMenuItemData({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    this.isHighlighted = false,
  });
}

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onMenuSelected;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final activeRole = authProvider.activeRole;
    final menuItems = _getMenuItemsForRole(activeRole);

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Drawer Header
            _buildDrawerHeader(context),

            // Role-Specific Navigation Menus
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildSectionHeader('${_getRoleBadge(activeRole)} NAVIGATION MENU'),

                  ...menuItems.map((item) => _buildDrawerItem(
                        index: item.index,
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        badge: item.badge,
                        badgeColor: item.badgeColor,
                        isHighlighted: item.isHighlighted,
                      )),
                ],
              ),
            ),

            // Footer (Logout, Version, Developer Credit & Copyright)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context); // Close drawer
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'v1.0.0',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Developed by Devkanta Singh',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '© 2026 Mangang Finance • Terms & Conditions',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DrawerMenuItemData> _getMenuItemsForRole(UserType role) {
    if (role == UserType.admin) {
      return [
        DrawerMenuItemData(
          index: 0,
          icon: Icons.dashboard_rounded,
          title: 'My Dashboard',
          subtitle: 'Financial overview & portfolio',
          badge: 'ADMIN',
        ),
        DrawerMenuItemData(
          index: 1,
          icon: Icons.person_add_alt_1_rounded,
          title: 'Create Loanee Account',
          subtitle: 'Register loanee profile & witness',
        ),
        DrawerMenuItemData(
          index: 2,
          icon: Icons.people_alt_rounded,
          title: 'Loanee Accounts List',
          subtitle: 'View & manage all loanees',
        ),
        DrawerMenuItemData(
          index: 3,
          icon: Icons.badge_rounded,
          title: 'Create RO Account',
          subtitle: 'Register Relationship Officer',
        ),
        DrawerMenuItemData(
          index: 4,
          icon: Icons.manage_accounts_rounded,
          title: 'RO Accounts List',
          subtitle: 'Fetch & filter RO officer details',
        ),
        DrawerMenuItemData(
          index: 5,
          icon: Icons.post_add_rounded,
          title: 'Add Loanee on R.O. Collection Sheet',
          subtitle: 'Record entry by Route & Collection Type',
        ),
        DrawerMenuItemData(
          index: 6,
          icon: Icons.table_chart_rounded,
          title: 'Collection Sheet',
          subtitle: 'Table view with Route & Type filters',
        ),
        DrawerMenuItemData(
          index: 7,
          icon: Icons.alt_route_rounded,
          title: 'Route Management',
          subtitle: 'Create & manage route masters',
        ),
        DrawerMenuItemData(
          index: 9,
          icon: Icons.recent_actors_rounded,
          title: 'Recent Registered Loanees',
          subtitle: 'New customer registrations & loans',
          badge: 'NEW',
          badgeColor: Colors.green.shade700,
        ),
        DrawerMenuItemData(
          index: 11,
          icon: Icons.timer_off_rounded,
          title: 'Late Fines & Penalties',
          subtitle: 'Live overdue tracking & penalty calculations',
        ),
        DrawerMenuItemData(
          index: 10,
          icon: Icons.settings_rounded,
          title: 'Settings',
          subtitle: 'Late payment penalty & defaults',
          badge: 'ADMIN',
          badgeColor: const Color(0xFF8B1A1A),
        ),
        DrawerMenuItemData(
          index: 8,
          icon: Icons.account_circle_rounded,
          title: 'Admin Profile',
          subtitle: 'Account details & security PIN',
        ),
      ];
    } else if (role == UserType.ro) {
      // RO ROLE
      return [
        DrawerMenuItemData(
          index: 0,
          icon: Icons.space_dashboard_rounded,
          title: 'My Dashboard',
          subtitle: "Daily collection summary",
          badge: 'RO',
        ),
        DrawerMenuItemData(
          index: 6,
          icon: Icons.table_chart_rounded,
          title: 'Collection Sheet',
          subtitle: 'View routes & record payments',
        ),
        DrawerMenuItemData(
          index: 8,
          icon: Icons.badge_rounded,
          title: 'RO Officer Profile',
          subtitle: 'Officer credentials & details',
        ),
      ];
    } else {
      // LOANEE ROLE
      return [
        DrawerMenuItemData(
          index: 0,
          icon: Icons.home_rounded,
          title: 'My Dashboard',
          subtitle: 'Loan card & repayment overview',
        ),
        DrawerMenuItemData(
          index: 11,
          icon: Icons.gavel_rounded,
          title: 'Late Fine & Overdue Notice',
          subtitle: 'Overdue assessment & acknowledgment',
        ),
        DrawerMenuItemData(
          index: 8,
          icon: Icons.badge_outlined,
          title: 'Loanee Profile',
          subtitle: 'Account details & customer info',
        ),
      ];
    }
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 16,
        16,
        16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              AppLogo(
                width: 44,
                height: 44,
                fallbackIcon: Icons.account_balance_wallet,
                fallbackIconColor: Colors.amber,
              ),
              SizedBox(width: 10),
              Text(
                'MANGANG FINANCE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    bool isHighlighted = false,
  }) {
    final isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.green.shade50
            : (isHighlighted
                ? Colors.amber.shade50
                : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Colors.green.shade400, width: 1.5)
            : (isHighlighted
                ? Border.all(color: Colors.amber.shade300)
                : null),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.green.shade700
                : (isHighlighted
                    ? Colors.amber.shade700
                    : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected || isHighlighted ? Colors.white : Colors.grey.shade700,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.green.shade800
                : Colors.grey.shade900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isSelected
                ? Colors.green.shade700
                : Colors.grey.shade600,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green.shade700 : (badgeColor ?? const Color(0xFF8B1A1A)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : (isSelected
                ? Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.green.shade700)
                : null),
        onTap: () => onMenuSelected(index),
      ),
    );
  }

  String _getRoleBadge(UserType role) {
    switch (role) {
      case UserType.admin:
        return 'ADMIN';
      case UserType.ro:
        return 'RO';
      case UserType.loanee:
        return 'LOANEE';
    }
  }
}
