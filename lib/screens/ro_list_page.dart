// lib/screens/ro_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ro_model.dart';
import '../providers/ro_provider.dart';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RoAccount> _filterRoAccounts(List<RoAccount> allRos) {
    return allRos.where((item) {
      // 1. Text Search Filter (RO Name, Cust ID, Acc No, Mobile, Aadhar, Designation, District)
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

      return matchesSearch && matchesDistrict;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final roProvider = Provider.of<RoProvider>(context);
    final filteredRos = _filterRoAccounts(roProvider.roAccounts);

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
                          Icon(Icons.badge_rounded, color: Colors.white, size: 24),
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
                      hintText: 'Search by RO Name, Cust ID, Acc No, Designation, Mobile...',
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

                  // District Search Filter Dropdown
                  Row(
                    children: [
                      const Icon(Icons.filter_list_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Filter District:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDistrictFilter,
                              dropdownColor: const Color(0xFF2C2C2C),
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              items: _districtOptions
                                  .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d),
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
                    ],
                  ),
                ],
              ),
            ),

            // Accounts Counter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filteredRos.length} of ${roProvider.totalRoAccounts} RO Accounts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    'Active Officers: ${filteredRos.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // RO Accounts List Area
            Expanded(
              child: filteredRos.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              roProvider.roAccounts.isEmpty
                                  ? 'No RO Accounts in Database'
                                  : 'No Matching RO Accounts',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              roProvider.roAccounts.isEmpty
                                  ? 'Click "New RO Account" above to create & insert records directly into Supabase'
                                  : 'Try adjusting your search filters',
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
                        return _buildRoCard(context, item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoCard(BuildContext context, RoAccount item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => _showRoDetailsDialog(context, item),
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
                    backgroundColor: Colors.black.withOpacity(0.08),
                    child: const Icon(Icons.badge_rounded, color: Colors.black, size: 24),
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
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
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
                                  const SizedBox(height: 3),
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
                                        Icon(Icons.alt_route_rounded,
                                            size: 10, color: Colors.blue.shade800),
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
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Mobile', item.mobileno, Icons.phone),
                  _buildMiniStat('District', item.district, Icons.map_outlined),
                  _buildMiniStat('Status', item.status, Icons.verified_user_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ],
    );
  }

  void _showRoDetailsDialog(BuildContext context, RoAccount item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: Colors.amber.shade900, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.roname,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${item.customerid} | ${item.accountnumber}',
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
            children: [
              _buildModalRow('1. Customer ID', item.customerid),
              _buildModalRow('2. Account Number', item.accountnumber),
              _buildModalRow('3. RO Name', item.roname),
              _buildModalRow('4. W/O, S/O, D/O', item.guardianname),
              _buildModalRow('5. Designation', item.designation),
              _buildModalRow('6. Assigned Route', item.route.isNotEmpty ? item.route : 'Not assigned'),
              _buildModalRow('7. Mobile No', item.mobileno),
              _buildModalRow('8. Aadhar No', item.aadharno),
              _buildModalRow('9. Address', item.address),
              _buildModalRow('10. Post Office (P/O)', item.postoffice),
              _buildModalRow('11. Police Station (P/S)', item.policestation),
              _buildModalRow('12. District', item.district),
              _buildModalRow('13. PIN Code', item.pincode),
              _buildModalRow('14. Status', item.status),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
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
