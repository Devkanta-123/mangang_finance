import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/loanee_provider.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final loaneeProvider = Provider.of<LoaneeProvider>(context);
    final user = authProvider.currentUser;
    final role = authProvider.activeRole;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Executive Profile Header Card
            _buildProfileHeader(context, user, role),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Portfolio / Account Summary Banner
                  _buildRoleSummaryCard(role, loaneeProvider, user),

                  const SizedBox(height: 24),

                  // Section 1: Official Identification & Profile
                  _buildSectionHeader('OFFICIAL IDENTIFICATION & CREDS', Icons.badge_rounded),
                  const SizedBox(height: 10),
                  _buildInfoCard([
                    _buildDetailRow(
                      icon: Icons.person_rounded,
                      label: 'Account Holder Name',
                      value: user?.name ?? 'User',
                      valueColor: const Color(0xFF8B1A1A),
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.phone_android_rounded,
                      label: 'Registered Mobile Number',
                      value: user?.mobileNo ?? '+91 9862145890',
                      badge: 'VERIFIED',
                      badgeColor: Colors.green.shade700,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.shield_rounded,
                      label: 'Assigned Portal Role',
                      value: _getRoleLabel(role),
                      badge: 'LEVEL 1',
                      badgeColor: Colors.amber.shade800,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.numbers_rounded,
                      label: 'Account / Customer ID',
                      value: user?.customerId ?? 'ADM-0192',
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.location_city_rounded,
                      label: 'Primary Operating Branch',
                      value: 'Imphal Head Office (Zone 1)',
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Section 2: Security & App Access Settings
                  _buildSectionHeader('SECURITY & PORTAL ACCESS', Icons.lock_person_rounded),
                  const SizedBox(height: 10),
                  _buildActionGroup([
                    _buildActionItem(
                      icon: Icons.pin_rounded,
                      title: 'App Security PIN',
                      subtitle: '6-digit PIN protection enabled',
                      trailingWidget: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN Security is active. Use Settings to change PIN.'),
                            backgroundColor: Color(0xFF8B1A1A),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionItem(
                      icon: Icons.fingerprint_rounded,
                      title: 'Biometric Access',
                      subtitle: 'Fingerprint & Face ID login',
                      trailingWidget: Switch(
                        value: true,
                        activeColor: const Color(0xFF8B1A1A),
                        onChanged: (val) {},
                      ),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    _buildActionItem(
                      icon: Icons.verified_user_rounded,
                      title: 'Device Authorization',
                      subtitle: 'Current Device: Android Mobile (Logged in)',
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Section 3: Preferences & Support
                  _buildSectionHeader('PREFERENCES & SUPPORT DESK', Icons.headset_mic_rounded),
                  const SizedBox(height: 10),
                  _buildActionGroup([
                    _buildActionItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Account Passbook & Reports',
                      subtitle: 'View payment statements & ledger',
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    _buildActionItem(
                      icon: Icons.notifications_active_rounded,
                      title: 'Push Notifications & Alerts',
                      subtitle: 'Collection updates & payment reminders',
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    _buildActionItem(
                      icon: Icons.contact_support_rounded,
                      title: 'Mangang Help Desk & Support',
                      subtitle: 'Toll Free: 1800-419-8800 • support@mangang.in',
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 30),

                  // Sign Out Button
                  InkWell(
                    onTap: () => _showLogoutDialog(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'SIGN OUT OF PORTAL',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App Footer Branding
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'MANGANG FINANCE ENTERPRISE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Version 1.2.0 • Secured by 256-bit Encryption',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Executive Header Design
  Widget _buildProfileHeader(BuildContext context, User? user, UserType role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B1A1A), Color(0xFF4A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.amber.shade400, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(user?.name ?? 'User'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B1A1A),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(_getRoleIcon(role), size: 16, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user?.name ?? 'User Profile',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars_rounded, size: 14, color: Colors.amber.shade300),
                const SizedBox(width: 6),
                Text(
                  _getRoleLabel(role).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Summary Metrics Banner card tailored to active role
  Widget _buildRoleSummaryCard(UserType role, LoaneeProvider loaneeProvider, User? user) {
    if (role == UserType.admin) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8B1A1A).withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total Portfolio', '₹ ${(loaneeProvider.totalLoanAmount / 100000).toStringAsFixed(1)} L'),
            Container(height: 30, width: 1, color: Colors.grey.shade300),
            _buildStatItem('Loanees', '${loaneeProvider.totalLoanees} Total'),
            Container(height: 30, width: 1, color: Colors.grey.shade300),
            _buildStatItem('Security', 'Encrypted'),
          ],
        ),
      );
    } else if (role == UserType.ro) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Assigned Zone', 'Imphal West'),
            Container(height: 30, width: 1, color: Colors.grey.shade300),
            _buildStatItem('Target Status', '73.5% Done'),
            Container(height: 30, width: 1, color: Colors.grey.shade300),
            _buildStatItem('Officer PIN', '789122'),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Sanctioned Loan', '₹ 1,00,000'),
            Container(height: 30, width: 1, color: Colors.grey.shade300),
            _buildStatItem('Due Balance', '₹ 55,000'),
            Container(height: 30, width: 1, color: Colors.grey.shade300),
            _buildStatItem('Next EMI', '10 Aug'),
          ],
        ),
      );
    }
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8B1A1A)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B1A1A),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    String? badge,
    Color? badgeColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF8B1A1A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor?.withValues(alpha: 0.1) ?? Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor?.withValues(alpha: 0.3) ?? Colors.grey.shade300),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: badgeColor ?? Colors.grey.shade800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailingWidget,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF8B1A1A)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: trailingWidget ??
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Colors.grey.shade400,
          ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFF8B1A1A)),
              SizedBox(width: 8),
              Text(
                'Confirm Sign Out',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out of your Mangang Finance account session?',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.pushReplacementNamed(context, '/register');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  String _getInitials(String name) {
    List<String> parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  String _getRoleLabel(UserType role) {
    switch (role) {
      case UserType.admin:
        return 'Executive Administrator';
      case UserType.ro:
        return 'RO Field Officer';
      case UserType.loanee:
        return 'Loanee Account Holder';
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