import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ro_provider.dart';
import '../providers/loanee_provider.dart';

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
                      ? 'Account for ${userRecord.name} is now ACTIVE (Synced across all tables)'
                      : 'Account for ${userRecord.name} is now INACTIVE (Login Disabled & Synced)',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Admin User',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: authProvider.isLoadingAdminUsers
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
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
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAdmin ? 'ADMIN CONTROL' : 'MANAGER VIEW',
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
                  isAdmin
                      ? 'Live database accounts from user_auth table (user_type = admin)'
                      : 'Monitor executive administrators from user_auth (Read-Only)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
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
                          onTap: () => _showUserDetailsModal(context, item, authProvider, isAdmin),
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
                                          Text(
                                            item.customerId ?? item.id,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: 10),
                                          Icon(Icons.phone_iphone_rounded, size: 12, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.mobileNo.isNotEmpty ? item.mobileNo : 'N/A',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Status Pill & Switch (Switch ONLY for Admin)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isItemActive ? Colors.green.shade50 : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isItemActive ? Colors.green.shade300 : Colors.red.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isItemActive ? Colors.green.shade700 : Colors.red.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isItemActive ? 'ACTIVE' : 'INACTIVE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isItemActive ? Colors.green.shade800 : Colors.red.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                     if (isAdmin) ...[
                                       const SizedBox(height: 2),
                                       Transform.scale(
                                         scale: 0.65,
                                         child: SizedBox(
                                           width: 36,
                                           height: 20,
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
    );
  }

  Widget _buildTopStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
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
    bool isAdmin,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isItemActive = userRecord.isActive;
            final isItemAdmin = userRecord.userType == UserType.admin;

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
                              userRecord.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${userRecord.userType.name.toUpperCase()} ACCOUNT',
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

                  _buildModalRow('Customer ID', userRecord.customerId ?? userRecord.id),
                  _buildModalRow('Mobile Number', userRecord.mobileNo.isNotEmpty ? userRecord.mobileNo : 'Not Set'),
                  _buildModalRow('Account Status', isItemActive ? 'Active (Login Enabled)' : 'Inactive (Login Disabled)'),
                  _buildModalRow('Account Role', userRecord.userType.name.toUpperCase()),
                  _buildModalRow('Created Date', userRecord.createdAt.toString().split(' ').first),

                  const SizedBox(height: 16),

                  // Status Toggle Bar (ONLY FOR ADMIN)
                  if (isAdmin) ...[
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
                              await _handleToggleStatus(context, authProvider, userRecord);
                              setModalState(() {});
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
                              'Manager role has monitoring access only. User account status modification is restricted to Administrators.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B1A1A),
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
}
