// lib/screens/locked_devices_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/locked_device_session_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

/// Screen for Managers (and Admins) to inspect and unblock accounts
/// locked due to active device sessions on old/broken/lost devices.
class LockedDeviceListPage extends StatefulWidget {
  const LockedDeviceListPage({super.key});

  @override
  State<LockedDeviceListPage> createState() => _LockedDeviceListPageState();
}

class _LockedDeviceListPageState extends State<LockedDeviceListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'All'; // 'All', 'loanee', 'ro', 'manager', 'admin'
  bool _isLoading = false;
  List<LockedDeviceSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final list = await authProvider.fetchLockedDeviceSessions();
    if (mounted) {
      setState(() {
        _sessions = list;
        _isLoading = false;
      });
    }
  }

  List<LockedDeviceSession> _filterSessions() {
    return _sessions.where((s) {
      // Role filter
      if (_selectedRoleFilter != 'All' &&
          s.userType.name.toLowerCase() != _selectedRoleFilter.toLowerCase()) {
        return false;
      }

      // Search filter
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final name = (s.userName ?? '').toLowerCase();
      final mobile = s.mobileNo.toLowerCase();
      final custId = (s.customerId ?? '').toLowerCase();
      final devId = s.deviceId.toLowerCase();

      return name.contains(query) ||
          mobile.contains(query) ||
          custId.contains(query) ||
          devId.contains(query);
    }).toList();
  }

  Future<void> _confirmAndUnblock(LockedDeviceSession session) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isManager = authProvider.activeRole == UserType.manager;
    final bool isAdmin = authProvider.activeRole == UserType.admin;

    if (!isManager && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only Managers and Admins can unblock device sessions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phonelink_erase_rounded, color: Colors.amber.shade900, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Unblock Device Session',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to release the device lock for:\n',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mobile: +91 ${session.mobileNo} • Role: ${session.roleLabel}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  if (session.customerId != null && session.customerId!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${session.customerId}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will clear the device session lock from the old or broken device. The user will be able to log in immediately from their replacement device.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await authProvider.unblockDeviceSession(session);
      if (mounted) {
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Session unblocked for ${session.displayName} (+91 ${session.mobileNo}). User can now log in.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade800,
            ),
          );
          _loadSessions();
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to unblock device session. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isManager = authProvider.activeRole == UserType.manager;
    final bool isAdmin = authProvider.activeRole == UserType.admin;
    final bool canManage = isManager || isAdmin;

    if (!canManage) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, size: 60, color: Colors.red.shade700),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Device session unlock is restricted to Manager and Administrator accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = _filterSessions();

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
                colors: [Color(0xFF8B1A1A), Color(0xFF5E1212)],
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
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.phonelink_lock_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'LOCKED DEVICE SESSIONS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                      tooltip: 'Refresh Locked Accounts',
                      onPressed: _loadSessions,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Accounts currently locked because of active sessions on old/broken devices. Managers can unblock them to allow login from new devices.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Filters & Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search name, mobile, ID, device...',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
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
                  ),
                ),

                const SizedBox(height: 10),

                // Role Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'All'),
                      const SizedBox(width: 6),
                      _buildFilterChip('Loanees', 'loanee'),
                      const SizedBox(width: 6),
                      _buildFilterChip('RO Officers', 'ro'),
                      const SizedBox(width: 6),
                      _buildFilterChip('Managers', 'manager'),
                      const SizedBox(width: 6),
                      _buildFilterChip('Admins', 'admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Summary Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} Locked Account${filtered.length == 1 ? "" : "s"} Found',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  'Tap Unblock to free session',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Sessions List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadSessions,
                    child: filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, idx) => _buildSessionCard(filtered[idx]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedRoleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedRoleFilter = value);
        }
      },
      selectedColor: const Color(0xFF8B1A1A),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.grey.shade800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildSessionCard(LockedDeviceSession session) {
    final roleColor = _getRoleBadgeColor(session.userType);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.red.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Role Badge + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: roleColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    session.roleLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: roleColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 12, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'LOCKED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // User Display Name & Mobile
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF8B1A1A).withOpacity(0.1),
                  child: Icon(Icons.person_rounded, color: const Color(0xFF8B1A1A), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.displayName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_android_rounded, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '+91 ${session.mobileNo}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          if (session.customerId != null && session.customerId!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ID: ${session.customerId}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Device details & registered time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.perm_device_information_rounded, size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Device ID: ',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Expanded(
                        child: Text(
                          session.deviceId,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: Color(0xFF1E1E1E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Locked Since: ',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Text(
                        session.formattedDate,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action Button: Unblock
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmAndUnblock(session),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                ),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text(
                  'Unblock / Reset Login for New Device',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleBadgeColor(UserType type) {
    switch (type) {
      case UserType.admin:
        return const Color(0xFF8B1A1A);
      case UserType.manager:
        return Colors.purple.shade700;
      case UserType.ro:
        return Colors.blue.shade700;
      case UserType.loanee:
        return Colors.teal.shade700;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phonelink_setup_rounded,
                  size: 54,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Locked Device Sessions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'All user accounts are currently unlocked. When a user\'s device is broken or replaced before logout, you can unblock their account here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
