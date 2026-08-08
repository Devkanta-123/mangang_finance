// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

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
    final user = authProvider.currentUser;
    final activeRole = authProvider.activeRole;
    final menuItems = _getMenuItemsForRole(activeRole);

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Drawer Header (Clean, without active role dropdown display)
            _buildDrawerHeader(context, user, activeRole),

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

                  const Divider(height: 24, indent: 16, endIndent: 16),
                  _buildSectionHeader('SYSTEM ACTIONS'),

                  _buildDrawerItem(
                    index: 12,
                    icon: Icons.settings_rounded,
                    title: 'Settings & Security',
                    subtitle: 'PIN & App Security',
                  ),
                ],
              ),
            ),

            // Footer (Logout)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: InkWell(
                onTap: () async {
                  Navigator.pop(context); // Close drawer
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red.shade700),
                      const SizedBox(width: 12),
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
                        'v1.2.0',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
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
          title: 'Admin Dashboard',
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
        // Positioned right after RO Accounts List
        DrawerMenuItemData(
          index: 5,
          icon: Icons.post_add_rounded,
          title: 'Loanee Collection Sheet',
          subtitle: 'Record entry by Route & Collection Type',
          isHighlighted: true,
          badge: 'NEW',
          badgeColor: Colors.amber.shade800,
        ),
        DrawerMenuItemData(
          index: 6,
          icon: Icons.table_chart_rounded,
          title: 'Collection View',
          subtitle: 'Table view with Route & Type filters',
          isHighlighted: true,
        ),
        DrawerMenuItemData(
          index: 7,
          icon: Icons.alt_route_rounded,
          title: 'Route Management',
          subtitle: 'Create & manage route masters',
          isHighlighted: true,
          badge: 'MASTER',
          badgeColor: const Color(0xFF8B1A1A),
        ),
        DrawerMenuItemData(
          index: 8,
          icon: Icons.receipt_long_rounded,
          title: 'Transactions & Collections',
          subtitle: 'System payment records',
        ),
        DrawerMenuItemData(
          index: 9,
          icon: Icons.warning_amber_rounded,
          title: 'Late Fines & Dues Audit',
          subtitle: 'Overdue tracking & waivers',
          badgeColor: Colors.orange.shade700,
        ),
        DrawerMenuItemData(
          index: 10,
          icon: Icons.bar_chart_rounded,
          title: 'Executive Reports & Stats',
          subtitle: 'Collection insights & PDF',
        ),
        DrawerMenuItemData(
          index: 11,
          icon: Icons.account_circle_rounded,
          title: 'Admin Account & Profile',
          subtitle: 'User details & identity',
        ),
      ];
    } else if (role == UserType.ro) {
      // RO ROLE
      return [
        DrawerMenuItemData(
          index: 0,
          icon: Icons.space_dashboard_rounded,
          title: 'RO Dashboard',
          subtitle: "Daily collection summary",
          badge: 'RO',
        ),
        DrawerMenuItemData(
          index: 5,
          icon: Icons.post_add_rounded,
          title: 'Add Loanee Collection Entry',
          subtitle: 'Record route collection sheet entry',
          isHighlighted: true,
        ),
        DrawerMenuItemData(
          index: 6,
          icon: Icons.table_chart_rounded,
          title: 'R.O. Collection Sheet Table',
          subtitle: 'View & filter collection entries',
        ),
        DrawerMenuItemData(
          index: 8,
          icon: Icons.payments_rounded,
          title: 'Payment Collection Entry',
          subtitle: 'Record field payment receipt',
        ),
        DrawerMenuItemData(
          index: 11,
          icon: Icons.badge_rounded,
          title: 'RO Officer Profile',
          subtitle: 'Officer credentials & zone',
        ),
      ];
    } else {
      // LOANEE ROLE
      return [
        DrawerMenuItemData(
          index: 0,
          icon: Icons.home_rounded,
          title: 'Loanee Dashboard',
          subtitle: 'Loan card & next EMI date',
          badge: 'LOANEE',
        ),
        DrawerMenuItemData(
          index: 8,
          icon: Icons.receipt_long_rounded,
          title: 'Payment Transactions (View Only)',
          subtitle: 'Read-only payment history & ledger',
          isHighlighted: true,
        ),
        DrawerMenuItemData(
          index: 11,
          icon: Icons.badge_outlined,
          title: 'My Profile',
          subtitle: 'Personal details & Aadhar info',
        ),
      ];
    }
  }

  Widget _buildDrawerHeader(
    BuildContext context,
    User? user,
    UserType activeRole,
  ) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet,
                      color: Colors.amber, size: 24),
                  SizedBox(width: 8),
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
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(
                  _getRoleIcon(activeRole),
                  color: const Color(0xFF8B1A1A),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Finance User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.mobileNo ?? '9862145890',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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

  IconData _getRoleIcon(UserType role) {
    switch (role) {
      case UserType.admin:
        return Icons.admin_panel_settings_rounded;
      case UserType.ro:
        return Icons.badge_rounded;
      case UserType.loanee:
        return Icons.person_rounded;
    }
  }
}
