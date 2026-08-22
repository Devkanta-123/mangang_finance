// lib/screens/ro_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/ro_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ro_provider.dart';
import '../widgets/edit_ro_dialog.dart';

class RoListPage extends StatefulWidget {
  final VoidCallback? onCreateRoPressed;

  const RoListPage({super.key, this.onCreateRoPressed});

  @override
  State<RoListPage> createState() => _RoListPageState();
}

class _RoListPageState extends State<RoListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDistrictFilter = 'All Districts';
  String _selectedStatusFilter = 'All Status';

  final List<String> _statusOptions = [
    'All Status',
    'Active Only',
    'Inactive Only',
  ];

  final List<String> _districtOptions = [
    'All Districts',
    'Imphal West',
    'Imphal East',
    'Thoubal',
    'Bishnupur',
    'Kakching',
    'Churachandpur',
    'Ukhrul',
    'Senapati',
    'Tamenglong',
    'Jiribam',
    'Kangpokpi',
    'Tengnoupal',
    'Pherzawl',
    'Noney',
    'Kamjong',
    'Chandel',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<RoProvider>(context, listen: false).fetchFromSupabase();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RoAccount> _filterRoAccounts(List<RoAccount> allRos) {
    return allRos.where((item) {
      // 1. Text Search Filter (RO Name, Cust ID, Acc No, Mobile, Aadhar, Designation, Route, District)
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          item.roname.toLowerCase().contains(query) ||
          item.customerid.toLowerCase().contains(query) ||
          item.accountnumber.toLowerCase().contains(query) ||
          item.mobileno.toLowerCase().contains(query) ||
          item.aadharno.toLowerCase().contains(query) ||
          item.guardianname.toLowerCase().contains(query) ||
          item.designation.toLowerCase().contains(query) ||
          item.route.toLowerCase().contains(query) ||
          item.district.toLowerCase().contains(query);

      // 2. District Filter
      final matchesDistrict = _selectedDistrictFilter == 'All Districts' ||
          item.district.toLowerCase() == _selectedDistrictFilter.toLowerCase();

      // 3. Status Filter
      final matchesStatus = _selectedStatusFilter == 'All Status' ||
          (_selectedStatusFilter == 'Active Only' && item.isActive) ||
          (_selectedStatusFilter == 'Inactive Only' && !item.isActive);

      return matchesSearch && matchesDistrict && matchesStatus;
    }).toList();
  }

  Future<void> _handleToggleStatus(
    BuildContext context,
    RoProvider provider,
    RoAccount ro,
  ) async {
    final willBeActive = !ro.isActive;
    final newStatus = willBeActive ? 'Active' : 'Inactive';

    await provider.updateStatus(ro.customerId, newStatus);
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
                      ? 'RO Account for ${ro.roName} is now ACTIVE (Login Enabled)'
                      : 'RO Account for ${ro.roName} is now INACTIVE (Login Disabled)',
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

    final roProvider = Provider.of<RoProvider>(context);
    final allRos = roProvider.roAccounts;
    final filteredRos = _filterRoAccounts(allRos);
    final activeCount = allRos.where((r) => r.isActive).length;
    final inactiveCount = allRos.where((r) => !r.isActive).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: () async {
          await roProvider.fetchFromSupabase();
        },
        child: Column(
          children: [
            // Search & Filter Header Banner
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                          Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'RO Accounts',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: roProvider.isSyncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.sync_rounded, color: Colors.white),
                            tooltip: 'Sync Live Supabase Table',
                            onPressed: () {
                              roProvider.fetchFromSupabase();
                            },
                          ),
                          if (widget.onCreateRoPressed != null) ...[
                            const SizedBox(width: 4),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: widget.onCreateRoPressed,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(
                                'New RO Account',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Field
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by RO Name, Cust ID, Acc No, Route, Mobile...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.black87),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Colors.black54),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Filter Row (District & Status)
                  Row(
                    children: [
                      // District Filter Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDistrictFilter,
                              dropdownColor: const Color(0xFF2C2C2C),
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                              items: _districtOptions
                                  .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedDistrictFilter = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status Filter Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStatusFilter,
                              dropdownColor: const Color(0xFF2C2C2C),
                              isExpanded: true,
                              icon: const Icon(Icons.tune_rounded, color: Colors.amberAccent, size: 16),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              items: _statusOptions
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedStatusFilter = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Accounts Counter Bar with Active/Inactive counts
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filteredRos.length} of ${allRos.length} RO Accounts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          'Active: $activeCount',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          'Inactive: $inactiveCount',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // RO Accounts List Area
            Expanded(
              child: filteredRos.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: 350,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              allRos.isEmpty
                                  ? 'No RO Accounts in Database'
                                  : 'No Matching RO Accounts',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              allRos.isEmpty
                                  ? 'Click "New RO Account" above to create & insert records directly into Supabase'
                                  : 'Try adjusting your search or status filters',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredRos.length,
                      itemBuilder: (context, index) {
                        final item = filteredRos[index];
                        return _buildRoCard(context, item, roProvider, isAdmin);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoCard(
    BuildContext context,
    RoAccount item,
    RoProvider roProvider,
    bool isAdmin,
  ) {
    final bool isActive = item.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive ? Colors.transparent : Colors.red.shade300,
          width: isActive ? 0 : 1.2,
        ),
      ),
      child: InkWell(
        onTap: () => _showRoDetailsDialog(context, item, roProvider, isAdmin),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isActive
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.red.shade50,
                    child: Icon(
                      isActive ? Icons.badge_rounded : Icons.person_off_rounded,
                      color: isActive ? Colors.black : Colors.red.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.roname,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.black : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            if (isAdmin) ...[
                              InkWell(
                                onTap: () => EditRoDialog.show(context, item),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_note_rounded, size: 14, color: Colors.amber.shade900),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Edit',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            // Interactive Status Toggle Pill & Switch (Admin Only)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive ? Colors.green.shade300 : Colors.red.shade300,
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
                                      color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isActive ? 'ACTIVE' : 'INACTIVE',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 4),
                                    Transform.scale(
                                      scale: 0.65,
                                      child: SizedBox(
                                        width: 36,
                                        height: 20,
                                        child: Switch(
                                          value: isActive,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          activeColor: Colors.green.shade700,
                                          activeTrackColor: Colors.green.shade200,
                                          inactiveThumbColor: Colors.red.shade700,
                                          inactiveTrackColor: Colors.red.shade200,
                                          onChanged: (val) {
                                            _handleToggleStatus(context, roProvider, item);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'W/O, S/O, D/O: ${item.guardianname.isNotEmpty ? item.guardianname : "N/A"}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.customerid,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Acc: ${item.accountnumber}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Route & Designation Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      item.designation.isNotEmpty ? item.designation : 'RO Officer',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                  if (item.route.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.alt_route_rounded, size: 10, color: Colors.blue.shade800),
                          const SizedBox(width: 2),
                          Text(
                            item.route,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Mobile', item.mobileno, Icons.phone),
                  const SizedBox(width: 4),
                  _buildMiniStat('District', item.district, Icons.map_outlined),
                  const SizedBox(width: 4),
                  _buildMiniStat('Post Office', item.postoffice.isNotEmpty ? item.postoffice : 'N/A', Icons.local_post_office_outlined),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRoDetailsDialog(
    BuildContext context,
    RoAccount item,
    RoProvider roProvider,
    bool isAdmin,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<RoProvider>(
        builder: (dialogContext, liveRoProvider, _) {
          final currentRo = liveRoProvider.roAccounts.firstWhere(
            (r) => r.customerId == item.customerId,
            orElse: () => item,
          );
          final bool isCurrentActive = currentRo.isActive;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCurrentActive ? Colors.amber.shade100 : Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrentActive ? Icons.person : Icons.person_off_rounded,
                    color: isCurrentActive ? Colors.amber.shade900 : Colors.red.shade900,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentRo.roname,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${currentRo.customerid} | ${currentRo.accountnumber}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin Account Status Toggle Box in Modal
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentActive ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentActive ? Colors.green.shade300 : Colors.red.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Status (Admin)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isCurrentActive ? Colors.green.shade900 : Colors.red.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCurrentActive
                                  ? 'ACTIVE (Login Allowed)'
                                  : 'INACTIVE (Login Blocked)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isCurrentActive ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                        if (isAdmin)
                          Transform.scale(
                            scale: 0.85,
                            child: Switch(
                              value: isCurrentActive,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              activeThumbColor: Colors.green.shade700,
                              activeTrackColor: Colors.green.shade200,
                              inactiveThumbColor: Colors.red.shade700,
                              inactiveTrackColor: Colors.red.shade200,
                              onChanged: (val) async {
                                await _handleToggleStatus(context, liveRoProvider, currentRo);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  _buildModalRow('1. Customer ID', currentRo.customerid),
                  _buildModalRow('2. Account Number', currentRo.accountnumber),
                  _buildModalRow('3. RO Name', currentRo.roname),
                  _buildModalRow('4. W/O, S/O, D/O', currentRo.guardianname),
                  _buildModalRow('5. Designation', currentRo.designation),
                  _buildModalRow('6. Assigned Route', currentRo.route.isNotEmpty ? currentRo.route : 'Not assigned'),
                  _buildModalRow('7. Mobile No', currentRo.mobileno),
                  _buildModalRow('8. Aadhar No', currentRo.aadharno),
                  _buildModalRow('9. Address', currentRo.address),
                  _buildModalRow('10. Post Office (P/O)', currentRo.postoffice),
                  _buildModalRow('11. Police Station (P/S)', currentRo.policestation),
                  _buildModalRow('12. District', currentRo.district),
                  _buildModalRow('13. PIN Code', currentRo.pincode),
                  _buildModalRow('14. Status', currentRo.status),
                ],
              ),
            ),
            actions: [
              if (isAdmin)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        EditRoDialog.show(context, currentRo);
                      }
                    });
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 15),
                  label: const Text('Edit RO Details', style: TextStyle(fontSize: 12)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
