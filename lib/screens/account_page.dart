// lib/screens/account_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/ro_provider.dart';
import '../providers/collection_sheet_provider.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final loaneeProvider = Provider.of<LoaneeProvider>(context);
    final roProvider = Provider.of<RoProvider>(context);
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);

    final user = authProvider.currentUser;
    final role = authProvider.activeRole;

    // Pull real loanee data if role is Loanee
    final loaneeAccount = loaneeProvider.getLoaneeForUser(
      customerId: user?.customerId,
      mobileNo: user?.mobileNo,
      name: user?.name,
    );

    // Pull real RO data if role is RO
    final roAccount = roProvider.getRoForUser(
      customerId: user?.customerId,
      mobileNo: user?.mobileNo,
      name: user?.name,
    );

    final loaneeEntries = collectionProvider.getEntriesForLoanee(
      user?.mobileNo ?? '',
      user?.name ?? '',
      user?.customerId ?? '',
    );

    final String displayName;
    final String customerIdVal;
    final String accountNameVal;
    final String accountNoVal;

    if (role == UserType.loanee) {
      displayName = loaneeAccount?.loaneeName.isNotEmpty == true
          ? loaneeAccount!.loaneeName
          : (user?.name != null && user!.name.isNotEmpty
              ? user.name
              : (loaneeEntries.isNotEmpty ? loaneeEntries.first.loaneeName : 'Loanee Account'));

      customerIdVal = loaneeAccount?.customerId.isNotEmpty == true
          ? loaneeAccount!.customerId
          : ((user?.customerId != null && user!.customerId!.isNotEmpty)
              ? user.customerId!
              : (loaneeEntries.isNotEmpty ? loaneeEntries.first.customerId : 'N/A'));

      accountNameVal = (user?.accountName != null && user!.accountName!.isNotEmpty)
          ? user.accountName!
          : (loaneeAccount?.loaneeName.isNotEmpty == true
              ? loaneeAccount!.loaneeName
              : displayName);

      accountNoVal = loaneeAccount?.accountNumber.isNotEmpty == true
          ? loaneeAccount!.accountNumber
          : (user?.accountName != null && user!.accountName!.isNotEmpty
              ? user.accountName!
              : (loaneeEntries.isNotEmpty
                  ? loaneeEntries.map((e) => e.accountNumber).toSet().join(', ')
                  : 'N/A'));
    } else if (role == UserType.manager) {
      displayName = (user?.name != null && user!.name.isNotEmpty)
          ? user.name
          : 'Branch Manager';
      customerIdVal = (user?.customerId != null && user!.customerId!.isNotEmpty)
          ? user.customerId!
          : 'MGR-01';
      accountNameVal = 'N/A';
      accountNoVal = 'N/A';
    } else if (role == UserType.ro) {
      displayName = (user?.name != null && user!.name.isNotEmpty)
          ? user.name
          : 'RO Officer';
      customerIdVal = (user?.customerId != null && user!.customerId!.isNotEmpty)
          ? user.customerId!
          : 'RO-OFFICER';
      accountNameVal = 'N/A';
      accountNoVal = 'N/A';
    } else {
      displayName = (user?.name != null && user!.name.isNotEmpty)
          ? user.name
          : 'Administrator';
      customerIdVal = (user?.customerId != null && user!.customerId!.isNotEmpty)
          ? user.customerId!
          : 'ADMIN-01';
      accountNameVal = 'N/A';
      accountNoVal = 'N/A';
    }

    final displayMobile = (user?.mobileNo != null && user!.mobileNo.isNotEmpty)
        ? user.mobileNo
        : (loaneeAccount?.mobileNo.isNotEmpty == true
            ? loaneeAccount!.mobileNo
            : 'Not Set');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Card
            _buildProfileHeader(context, displayName, role),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Details Card
                  _buildSectionHeader('PROFILE INFORMATION', Icons.person_outline_rounded),
                  const SizedBox(height: 10),
                  _buildInfoCard([
                    // Loanee / RO / Admin Name
                    _buildDetailRow(
                      icon: Icons.person_rounded,
                      label: role == UserType.loanee ? 'Loanee Name' : (role == UserType.ro ? 'RO Officer Name' : 'Administrator Name'),
                      value: displayName,
                      valueColor: const Color(0xFF8B1A1A),
                    ),
                    const Divider(height: 20),

                    // Customer ID and Account Name for Loanee
                    if (role == UserType.loanee) ...[
                      _buildDetailRow(
                        icon: Icons.badge_rounded,
                        label: 'Customer ID',
                        value: customerIdVal,
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        icon: Icons.account_balance_rounded,
                        label: 'Account Name',
                        value: accountNameVal,
                      ),
                      const Divider(height: 20),
                      if (accountNoVal != 'N/A' && accountNoVal != accountNameVal) ...[
                        _buildDetailRow(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Account No',
                          value: accountNoVal,
                        ),
                        const Divider(height: 20),
                      ],
                    ],

                    _buildDetailRow(
                      icon: Icons.phone_android_rounded,
                      label: 'Mobile Number',
                      value: displayMobile,
                    ),

                    // Additional Loanee Details if available
                    if (role == UserType.loanee && loaneeAccount != null) ...[
                      if (loaneeAccount.guardianName.isNotEmpty) ...[
                        const Divider(height: 20),
                        _buildDetailRow(
                          icon: Icons.family_restroom_rounded,
                          label: 'W/O, S/O, D/O',
                          value: loaneeAccount.guardianName,
                        ),
                      ],
                      if (loaneeAccount.address.isNotEmpty) ...[
                        const Divider(height: 20),
                        _buildDetailRow(
                          icon: Icons.location_on_rounded,
                          label: 'Address',
                          value: loaneeAccount.district.isNotEmpty
                              ? '${loaneeAccount.address}, ${loaneeAccount.district}'
                              : loaneeAccount.address,
                        ),
                      ],
                      if (loaneeAccount.businesstype.isNotEmpty) ...[
                        const Divider(height: 20),
                        _buildDetailRow(
                          icon: Icons.storefront_rounded,
                          label: 'Business Type',
                          value: loaneeAccount.businesstype,
                        ),
                      ],
                      if (loaneeAccount.loanamount > 0) ...[
                        const Divider(height: 20),
                        _buildDetailRow(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Sanctioned Loan Amount',
                          value: '₹ ${loaneeAccount.loanamount.toStringAsFixed(2)}',
                        ),
                      ],
                      const Divider(height: 20),
                      _buildDetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Loan Sanction Date',
                        value: loaneeAccount.formattedSanctionDate,
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        icon: Icons.event_available_rounded,
                        label: 'Loan Maturity Date',
                        value: loaneeAccount.formattedMaturityDate,
                        badge: '5 MONTHS',
                        badgeColor: Colors.teal.shade700,
                      ),
                    ],

                    // For Admin and RO, show role info
                    if (role != UserType.loanee) ...[
                      const Divider(height: 20),
                      _buildDetailRow(
                        icon: Icons.shield_rounded,
                        label: 'Role / Access Level',
                        value: _getRoleLabel(role),
                        badge: _getRoleBadge(role),
                        badgeColor: const Color(0xFF8B1A1A),
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        icon: Icons.badge_rounded,
                        label: 'Account ID',
                        value: customerIdVal,
                      ),
                    ],

                    // If RO, show Assigned Route Map & Designation
                    if (role == UserType.ro) ...[
                      const Divider(height: 20),
                      _buildDetailRow(
                        icon: Icons.alt_route_rounded,
                        label: 'Assigned Route',
                        value: roAccount?.route.isNotEmpty == true ? roAccount!.route : 'All Routes / Flexible',
                        badge: roAccount?.route.isNotEmpty == true ? 'ASSIGNED' : 'FLEXIBLE',
                        badgeColor: Colors.blue.shade700,
                      ),
                      if (roAccount?.designation.isNotEmpty == true) ...[
                        const Divider(height: 20),
                        _buildDetailRow(
                          icon: Icons.work_outline_rounded,
                          label: 'Designation',
                          value: roAccount!.designation,
                        ),
                      ],
                    ],

                    const Divider(height: 20),
                    Builder(
                      builder: (context) {
                        final String effectiveStatus = (role == UserType.loanee
                                ? loaneeAccount?.status
                                : (role == UserType.ro ? roAccount?.status : user?.status)) ??
                            'Active';
                        final bool isAccountActive =
                            effectiveStatus.toLowerCase() != 'inactive';

                        return _buildDetailRow(
                          icon: isAccountActive
                              ? Icons.verified_user_rounded
                              : Icons.person_off_rounded,
                          label: 'Account Status',
                          value: isAccountActive
                              ? (effectiveStatus.isNotEmpty ? effectiveStatus : 'Active & Verified')
                              : 'Inactive (Disabled)',
                          badge: isAccountActive ? 'ACTIVE' : 'INACTIVE',
                          badgeColor: isAccountActive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Security Section
                  _buildSectionHeader('SECURITY & ACCESS', Icons.lock_outline_rounded),
                  const SizedBox(height: 10),
                  _buildActionGroup([
                    _buildActionItem(
                      icon: Icons.pin_rounded,
                      title: 'Change Security PIN',
                      subtitle: 'Update your 6-digit app login PIN',
                      trailingWidget: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'CHANGE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      onTap: () => _showChangePinDialog(context, authProvider),
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
                            'SIGN OUT',
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
                          'MANGANG FINANCE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 3),
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

  Widget _buildProfileHeader(BuildContext context, String name, UserType role) {
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
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.amber.shade400, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(name),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B1A1A),
                    ),
                  ),
                ),
              ),
          if (role != UserType.loanee)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(_getRoleIcon(role), size: 14, color: Colors.white),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        name,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
      if (role != UserType.loanee) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, size: 13, color: Colors.amber.shade300),
              const SizedBox(width: 5),
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
    ],
  ),
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
            color: Colors.black.withOpacity(0.02),
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
            color: const Color(0xFF8B1A1A).withOpacity(0.08),
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
              color: badgeColor?.withOpacity(0.1) ?? Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor?.withOpacity(0.3) ?? Colors.grey.shade300),
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
            color: Colors.black.withOpacity(0.02),
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
          color: const Color(0xFF8B1A1A).withOpacity(0.08),
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

  void _showChangePinDialog(BuildContext context, AuthProvider authProvider) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Color(0xFF8B1A1A)),
            SizedBox(width: 8),
            Text(
              'Change Security PIN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New 6-Digit PIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_rounded),
                ),
                validator: (val) {
                  if (val == null || val.length != 6) {
                    return 'Enter exactly 6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New PIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_rounded),
                ),
                validator: (val) {
                  if (val != pinController.text) {
                    return 'PINs do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                await authProvider.setPin(pinController.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Security PIN updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 42),
            ),
            child: const Text('Save PIN'),
          ),
        ],
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
              onPressed: () async {
                Navigator.pop(context);
                await Provider.of<AuthProvider>(context, listen: false).logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1A1A),
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 42),
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
      case UserType.manager:
        return 'Branch Manager';
      case UserType.ro:
        return 'RO Field Officer';
      case UserType.loanee:
        return 'Loanee Account Holder';
    }
  }

  String _getRoleBadge(UserType role) {
    switch (role) {
      case UserType.admin:
        return 'ADMIN';
      case UserType.manager:
        return 'MANAGER';
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
      case UserType.manager:
        return Icons.supervisor_account_rounded;
      case UserType.ro:
        return Icons.badge_rounded;
      case UserType.loanee:
        return Icons.person_rounded;
    }
  }
}