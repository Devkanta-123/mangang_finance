import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ro_provider.dart';
import '../providers/loanee_provider.dart';
import '../services/customer_id_service.dart';

class AdminUsersListPage extends StatefulWidget {
  const AdminUsersListPage({super.key});

  @override
  State<AdminUsersListPage> createState() => _AdminUsersListPageState();
}

class _AdminUsersListPageState extends State<AdminUsersListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'All Status';

  final List<String> _statusOptions = ['All Status', 'Active Only', 'Inactive Only'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).fetchAdminUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserAuthRecord> _filterUsers(List<UserAuthRecord> allUsers) {
    return allUsers.where((item) {
      // Strictly show Admin usertype only
      if (item.userType != UserType.admin) {
        return false;
      }

      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.customerId ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.mobileNo.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatusFilter == 'All Status' ||
          (_selectedStatusFilter == 'Active Only' && item.isActive) ||
          (_selectedStatusFilter == 'Inactive Only' && !item.isActive);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _handleToggleStatus(
    BuildContext context,
    AuthProvider provider,
    UserAuthRecord userRecord,
  ) async {
    final willBeActive = !userRecord.isActive;
    final newStatus = willBeActive ? 'Active' : 'Inactive';

    await provider.updateAdminUserStatus(
      userRecord.id,
      newStatus,
      customerId: userRecord.customerId,
      mobileNo: userRecord.mobileNo,
      userType: userRecord.userType,
    );

    // Sync in-memory providers if matching accounts are currently loaded
    try {
      final custId = userRecord.customerId ?? userRecord.id;
      final roProvider = Provider.of<RoProvider>(context, listen: false);
      roProvider.updateStatus(custId, newStatus);
    } catch (_) {}

    try {
      final custId = userRecord.customerId ?? userRecord.id;
      final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
      loaneeProvider.updateStatus(custId, newStatus);
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                willBeActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  willBeActive
                      ? 'Account for ${userRecord.name} is now ACTIVE (Login Enabled)'
                      : 'Account for ${userRecord.name} is now INACTIVE (Login Disabled)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: willBeActive ? Colors.green.shade800 : Colors.red.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isAdmin = authProvider.activeRole == UserType.admin;
    final bool isManager = authProvider.activeRole == UserType.manager;
    final bool canManage = isAdmin || isManager;
    final allUsers = authProvider.adminUsers;
    final filteredUsers = _filterUsers(allUsers);

    final adminUsers = allUsers.where((u) => u.userType == UserType.admin).toList();
    final adminCount = adminUsers.length;
    final activeCount = adminUsers.where((u) => u.isActive).length;
    final inactiveCount = adminUsers.where((u) => !u.isActive).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Role Badge + Sync Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Admin User',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: authProvider.isLoadingAdminUsers
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                          tooltip: 'Sync with Supabase user_auth',
                          onPressed: () {
                            authProvider.fetchAdminUsers();
                          },
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            isAdmin ? 'ADMIN CONTROL' : 'MANAGER ACCESS',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Live administrator accounts in user_auth • Managers & Admins can add and manage executive credentials',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 12),
                
                // Add Admin User Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _showAddAdminUserModal(context, authProvider),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text(
                      'Add New Admin User',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Metrics Row
                Row(
                  children: [
                    _buildTopStatCard('Total Admins', '$adminCount', Icons.shield_rounded, Colors.amber.shade700),
                    const SizedBox(width: 8),
                    _buildTopStatCard('Active', '$activeCount', Icons.check_circle_outline_rounded, Colors.green.shade400),
                    const SizedBox(width: 8),
                    _buildTopStatCard('Inactive', '$inactiveCount', Icons.pause_circle_outline_rounded, Colors.orange.shade400),
                  ],
                ),
              ],
            ),
          ),

          // Search & Filter Strip
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by Admin Name, ID, Mobile...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8B1A1A), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Status Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatusFilter,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
                      items: _statusOptions.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatusFilter = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User Accounts List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await authProvider.fetchAdminUsers();
              },
              child: filteredUsers.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: 320,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No Admin User accounts found in user_auth table',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ensure database table user_auth contains rows where user_type = admin',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final item = filteredUsers[index];
                        final bool isItemActive = item.isActive;
                        final bool isItemAdmin = item.userType == UserType.admin;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: InkWell(
                          onTap: () => _showUserDetailsModal(context, item, authProvider, canManage),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Role Avatar
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: isItemAdmin ? const Color(0xFF8B1A1A) : const Color(0xFF5E0F0F),
                                  child: Icon(
                                    isItemAdmin ? Icons.admin_panel_settings_rounded : Icons.supervisor_account_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // User Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Role Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.red.shade200,
                                              ),
                                            ),
                                            child: const Text(
                                              'ADMIN',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF8B1A1A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.badge_outlined, size: 12, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              item.customerId ?? item.id,
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.phone_iphone_rounded, size: 12, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              item.mobileNo.isNotEmpty ? item.mobileNo : 'N/A',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Status Pill & Switch (Interactive Status Toggle)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: canManage
                                          ? () => _handleToggleStatus(context, authProvider, item)
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: isItemActive ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isItemActive ? Colors.green.shade300 : Colors.red.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isItemActive ? Colors.green.shade700 : Colors.red.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isItemActive ? 'ACTIVE' : 'INACTIVE',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: isItemActive ? Colors.green.shade800 : Colors.red.shade800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isAdmin) ...[
                                      const SizedBox(height: 2),
                                      Tooltip(
                                        message: isItemActive
                                            ? 'Toggle to Inactive (Login Disabled)'
                                            : 'Toggle to Active (Login Enabled)',
                                        child: Transform.scale(
                                          scale: 0.72,
                                          child: SizedBox(
                                            width: 38,
                                            height: 22,
                                            child: Switch(
                                              value: isItemActive,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              activeColor: Colors.green.shade700,
                                              activeTrackColor: Colors.green.shade200,
                                              inactiveThumbColor: Colors.red.shade700,
                                              inactiveTrackColor: Colors.red.shade200,
                                              onChanged: (val) {
                                                _handleToggleStatus(context, authProvider, item);
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else if (isManager) ...[
                                      const SizedBox(height: 2),
                                      _StatusToggleSwitch(
                                        value: isItemActive,
                                        tooltip: isItemActive
                                            ? 'Toggle to Inactive (Login Disabled)'
                                            : 'Toggle to Active (Login Enabled)',
                                        onChanged: (val) {
                                          _handleToggleStatus(context, authProvider, item);
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAdminUserModal(context, authProvider),
        backgroundColor: const Color(0xFF8B1A1A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Add Admin',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildTopStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 8.5, color: Colors.grey.shade400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailsModal(
    BuildContext context,
    UserAuthRecord userRecord,
    AuthProvider authProvider,
    bool canManage,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        UserAuthRecord currentRecord = userRecord;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final liveMatch = authProvider.adminUsers.firstWhere(
              (u) =>
                  u.id == currentRecord.id ||
                  (u.customerId != null && u.customerId == currentRecord.customerId) ||
                  (u.mobileNo == currentRecord.mobileNo),
              orElse: () => currentRecord,
            );
            currentRecord = liveMatch;
            final isItemActive = currentRecord.isActive;
            final isItemAdmin = currentRecord.userType == UserType.admin;

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: isItemAdmin ? const Color(0xFF8B1A1A) : const Color(0xFF5E0F0F),
                        child: Icon(
                          isItemAdmin ? Icons.admin_panel_settings_rounded : Icons.supervisor_account_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentRecord.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${currentRecord.userType.name.toUpperCase()} ACCOUNT',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  _buildModalRow('Customer ID', currentRecord.customerId ?? currentRecord.id),
                  _buildModalRow('Mobile Number', currentRecord.mobileNo.isNotEmpty ? currentRecord.mobileNo : 'Not Set'),
                  _buildModalRow('Account Status', isItemActive ? 'Active (Login Enabled)' : 'Inactive (Login Disabled)'),
                  _buildModalRow('Account Role', currentRecord.userType.name.toUpperCase()),
                  _buildModalRow('Created Date', currentRecord.createdAt.toString().split(' ').first),

                  const SizedBox(height: 16),

                  // Status Toggle Bar (FOR ADMIN & MANAGER)
                  if (canManage) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isItemActive ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isItemActive ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isItemActive ? 'Account Status: ACTIVE' : 'Account Status: INACTIVE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isItemActive ? Colors.green.shade900 : Colors.red.shade900,
                                ),
                              ),
                              Text(
                                isItemActive ? 'Toggle to disable account access' : 'Toggle to enable account access',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: isItemActive,
                            activeColor: Colors.green.shade700,
                            activeTrackColor: Colors.green.shade200,
                            inactiveThumbColor: Colors.red.shade700,
                            inactiveTrackColor: Colors.red.shade200,
                            onChanged: (val) async {
                              await _handleToggleStatus(context, authProvider, currentRecord);
                              setModalState(() {
                                currentRecord = currentRecord.copyWith(status: val ? 'Active' : 'Inactive');
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Account status modification is restricted to Administrators and Managers.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Add Admin Account Button inside modal
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddAdminUserModal(context, authProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B1A1A),
                        side: const BorderSide(color: Color(0xFF8B1A1A), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text(
                        'Add New Admin Account',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showAddAdminUserModal(BuildContext context, AuthProvider authProvider) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final pinController = TextEditingController(text: '123456');
    bool isSaving = false;
    bool obscurePin = false;
    bool isAccountActive = true;

    final existingAdminIds = authProvider.adminUsers
        .map((u) => u.customerId ?? '')
        .where((id) => id.isNotEmpty);
    final nextAdminId = CustomerIdService.generateAdminCustomerId(existingIds: existingAdminIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B1A1A).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Color(0xFF8B1A1A),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add Admin Account',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Create administrator in user_auth table',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Text(
                                nextAdminId,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),

                        // Full Name
                        _buildFieldLabel('Full Name'),
                        TextFormField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration(
                            hintText: 'Enter administrator full name',
                            icon: Icons.person_outline,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter administrator full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Mobile Number
                        _buildFieldLabel('Mobile Number'),
                        TextFormField(
                          controller: mobileController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: _inputDecoration(
                            hintText: 'Enter 10-digit mobile number',
                            icon: Icons.phone_android_outlined,
                            prefixText: '+91 ',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter mobile number';
                            }
                            final digits = val.replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 10) {
                              return 'Please enter valid 10-digit number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Security PIN
                        _buildFieldLabel('Security PIN (6 Digits)'),
                        TextFormField(
                          controller: pinController,
                          keyboardType: TextInputType.number,
                          obscureText: obscurePin,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: _inputDecoration(
                            hintText: 'Enter 6-digit Security PIN',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePin ? Icons.visibility_off : Icons.visibility,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  obscurePin = !obscurePin;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter 6-digit Security PIN';
                            }
                            if (val.trim().length != 6) {
                              return 'PIN must be exactly 6 digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Account Status Toggle (Active / Inactive)
                        _buildFieldLabel('Account Status'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isAccountActive ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAccountActive ? Colors.green.shade300 : Colors.red.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isAccountActive ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAccountActive ? 'ACTIVE (Login Enabled)' : 'INACTIVE (Login Disabled)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isAccountActive ? Colors.green.shade900 : Colors.red.shade900,
                                        ),
                                      ),
                                      Text(
                                        isAccountActive
                                            ? 'Admin can sign in immediately'
                                            : 'Login access disabled upon creation',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: isAccountActive,
                                activeColor: Colors.green.shade700,
                                activeTrackColor: Colors.green.shade200,
                                inactiveThumbColor: Colors.red.shade700,
                                inactiveTrackColor: Colors.red.shade200,
                                onChanged: (val) {
                                  setModalState(() {
                                    isAccountActive = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Info note
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This Admin account will be assigned ID $nextAdminId with ${isAccountActive ? "Active" : "Inactive"} status.',
                                  style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSaving ? null : () => Navigator.pop(modalContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (formKey.currentState!.validate()) {
                                          setModalState(() {
                                            isSaving = true;
                                          });

                                          final result = await authProvider.addAdminUser(
                                            name: nameController.text.trim(),
                                            mobileNo: mobileController.text.trim(),
                                            pin: pinController.text.trim(),
                                            customerId: nextAdminId,
                                            status: isAccountActive ? 'Active' : 'Inactive',
                                          );

                                          setModalState(() {
                                            isSaving = false;
                                          });

                                          if (result['success'] == true) {
                                            if (modalContext.mounted) {
                                              Navigator.pop(modalContext);
                                            }
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      const Icon(Icons.check_circle_rounded, color: Colors.white),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          result['message'] ?? 'Admin user added successfully!',
                                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.green.shade800,
                                                  duration: const Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          } else {
                                            if (modalContext.mounted) {
                                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                                SnackBar(
                                                  content: Text(result['message'] ?? 'Failed to add Admin user'),
                                                  backgroundColor: Colors.red.shade800,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B1A1A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'CREATE ADMIN',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: const Color(0xFF8B1A1A), size: 20),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8B1A1A), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
      ),
    );
  }
}

/// A custom interactive animated toggle switch used for executive roles like Manager,
/// offering smooth sliding animation and immediate feedback.
class _StatusToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? tooltip;

  const _StatusToggleSwitch({
    required this.value,
    required this.onChanged,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final toggle = GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? Colors.green.shade700 : Colors.red.shade700,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: toggle,
      );
    }
    return toggle;
  }
}
