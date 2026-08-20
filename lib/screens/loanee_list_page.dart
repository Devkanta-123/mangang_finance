import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/loanee_model.dart';
import '../providers/auth_provider.dart';
import '../providers/loanee_provider.dart';

class LoaneeListPage extends StatefulWidget {
  final VoidCallback? onCreateLoaneePressed;

  const LoaneeListPage({super.key, this.onCreateLoaneePressed});

  @override
  State<LoaneeListPage> createState() => _LoaneeListPageState();
}

class _LoaneeListPageState extends State<LoaneeListPage> {
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LoaneeAccount> _filterLoanees(List<LoaneeAccount> allLoanees) {
    return allLoanees.where((item) {
      // 1. Text Search Filter (Loanee & Witness fields)
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          item.loaneename.toLowerCase().contains(query) ||
          item.customerid.toLowerCase().contains(query) ||
          item.accountnumber.toLowerCase().contains(query) ||
          item.mobileno.toLowerCase().contains(query) ||
          item.aadharno.toLowerCase().contains(query) ||
          item.guardianname.toLowerCase().contains(query) ||
          item.businesstype.toLowerCase().contains(query) ||
          item.district.toLowerCase().contains(query) ||
          item.witnessname.toLowerCase().contains(query) ||
          item.witnessguardianname.toLowerCase().contains(query) ||
          item.witnessmobileno.toLowerCase().contains(query) ||
          item.witnessaadharno.toLowerCase().contains(query) ||
          item.witnessrelationship.toLowerCase().contains(query) ||
          item.witnessdistrict.toLowerCase().contains(query);

      // 2. District Filter
      final matchesDistrict = _selectedDistrictFilter == 'All Districts' ||
          item.district.toLowerCase() == _selectedDistrictFilter.toLowerCase() ||
          item.witnessdistrict.toLowerCase() == _selectedDistrictFilter.toLowerCase();

      // 3. Status Filter
      final matchesStatus = _selectedStatusFilter == 'All Status' ||
          (_selectedStatusFilter == 'Active Only' && item.isActive) ||
          (_selectedStatusFilter == 'Inactive Only' && !item.isActive);

      return matchesSearch && matchesDistrict && matchesStatus;
    }).toList();
  }

  Future<void> _handleToggleStatus(
    BuildContext context,
    LoaneeProvider provider,
    LoaneeAccount loanee,
  ) async {
    final willBeActive = !loanee.isActive;
    final newStatus = willBeActive ? 'Active' : 'Inactive';

    await provider.updateStatus(loanee.customerId, newStatus);
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
                      ? 'Account for ${loanee.loaneeName} is now ACTIVE (Login Enabled)'
                      : 'Account for ${loanee.loaneeName} is now INACTIVE (Login Disabled)',
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

    final loaneeProvider = Provider.of<LoaneeProvider>(context);
    final allLoanees = loaneeProvider.loanees;
    final filteredLoanees = _filterLoanees(allLoanees);
    final activeCount = allLoanees.where((l) => l.isActive).length;
    final inactiveCount = allLoanees.where((l) => !l.isActive).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: () async {
          await loaneeProvider.fetchFromSupabase();
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
                          Icon(Icons.people_alt_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Loanee Accounts',
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
                            icon: loaneeProvider.isSyncing
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
                              loaneeProvider.fetchFromSupabase();
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
                            onPressed: widget.onCreateLoaneePressed,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'New Account',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Options Input Field
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by Loanee or Witness Name, Cust ID, Acc No, Mobile...',
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
                    'Showing ${filteredLoanees.length} of ${loaneeProvider.totalLoanees} Accounts',
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

            // Loanee Accounts List Area
            Expanded(
              child: filteredLoanees.isEmpty
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
                              loaneeProvider.loanees.isEmpty
                                  ? 'No Loanee Accounts in Database'
                                  : 'No Matching Loanee Accounts',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              loaneeProvider.loanees.isEmpty
                                  ? 'Click "New Account" above to create & insert records directly into Supabase'
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
                      itemCount: filteredLoanees.length,
                      itemBuilder: (context, index) {
                        final item = filteredLoanees[index];
                        return _buildLoaneeCard(context, item, loaneeProvider, isAdmin);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaneeCard(
    BuildContext context,
    LoaneeAccount item,
    LoaneeProvider loaneeProvider,
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
        onTap: () => _showLoaneeDetailsDialog(context, item, loaneeProvider, isAdmin),
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
                      isActive ? Icons.person : Icons.person_off_rounded,
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
                                item.loaneename,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.black : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            // Interactive Status Toggle Pill & Switch
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
                                            _handleToggleStatus(context, loaneeProvider, item);
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

              // Witness Badge Header on Loanee Card
              if (item.witnessname.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.handshake_outlined, size: 14, color: Colors.indigo.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 11, color: Colors.indigo.shade900),
                            children: [
                              const TextSpan(
                                text: 'Witness: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: item.witnessname,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (item.witnessrelationship.isNotEmpty)
                                TextSpan(
                                  text: ' (${item.witnessrelationship})',
                                  style: TextStyle(color: Colors.indigo.shade700),
                                ),
                              if (item.witnessmobileno.isNotEmpty)
                                TextSpan(
                                  text: ' • Mobile: ${item.witnessmobileno}',
                                  style: TextStyle(color: Colors.indigo.shade800),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 20),
              Row(
                children: [
                  Expanded(child: _buildMiniStat('Mobile', item.mobileno, Icons.phone)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildMiniStat('District', item.district, Icons.map_outlined)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildMiniStat('Sanctioned', '₹ ${item.loanamount.toStringAsFixed(0)}', Icons.currency_rupee)),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }

  void _showLoaneeDetailsDialog(
    BuildContext context,
    LoaneeAccount item,
    LoaneeProvider loaneeProvider,
    bool isAdmin,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // Re-lookup live account from provider
          final currentLoanee = loaneeProvider.loanees.firstWhere(
            (l) => l.customerId.toLowerCase() == item.customerId.toLowerCase(),
            orElse: () => item,
          );
          final bool isCurrentActive = currentLoanee.isActive;

          return DefaultTabController(
            length: 2,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              title: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isCurrentActive ? Colors.black : Colors.red.shade700,
                        child: Icon(
                          isCurrentActive ? Icons.badge_rounded : Icons.person_off_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentLoanee.loaneename,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${currentLoanee.customerid} | ${currentLoanee.accountnumber}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.black,
                    indicatorWeight: 2.5,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.person_rounded, size: 18),
                        text: 'Loanee Details',
                      ),
                      Tab(
                        icon: Icon(Icons.handshake_outlined, size: 18),
                        text: 'Witness Details',
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 460,
                child: TabBarView(
                  children: [
                    // Tab 1: Loanee Details
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // Admin Account Status Toggle Card
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
                                      'Account Status (Login Access)',
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
                                      activeColor: Colors.green.shade700,
                                      activeTrackColor: Colors.green.shade200,
                                      inactiveThumbColor: Colors.red.shade700,
                                      inactiveTrackColor: Colors.red.shade200,
                                      onChanged: (val) async {
                                        await _handleToggleStatus(context, loaneeProvider, currentLoanee);
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          _buildModalRow('1. Customer ID', currentLoanee.customerid),
                          _buildModalRow('2. Account Number', currentLoanee.accountnumber),
                          _buildModalRow('3. Loanee Name', currentLoanee.loaneename),
                          _buildModalRow('4. W/O, S/O, D/O', currentLoanee.guardianname),
                          _buildModalRow('5. Mobile No', currentLoanee.mobileno),
                          _buildModalRow('6. Aadhar No', currentLoanee.aadharno),
                          _buildModalRow('7. Address', currentLoanee.address),
                          _buildModalRow('8. Post Office (P/O)', currentLoanee.postoffice),
                          _buildModalRow('9. Police Station (P/S)', currentLoanee.policestation),
                          _buildModalRow('10. District', currentLoanee.district),
                          _buildModalRow('11. PIN Code', currentLoanee.pincode),
                          _buildModalRow('12. Business Type', currentLoanee.businesstype),
                          _buildModalRow('13. Sanctioned Amount', '₹ ${currentLoanee.loanamount.toStringAsFixed(0)}'),
                          _buildModalRow('14. Account Status', currentLoanee.status),
                        ],
                      ),
                    ),

                    // Tab 2: Witness Details
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          if (currentLoanee.witnessname.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No witness details recorded',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            _buildModalRow('1. Witness Name', currentLoanee.witnessname),
                            _buildModalRow('2. Witness W/O, S/O, D/O', currentLoanee.witnessguardianname),
                            _buildModalRow('3. Relationship with Loanee', currentLoanee.witnessrelationship),
                            _buildModalRow('4. Witness Mobile No', currentLoanee.witnessmobileno),
                            _buildModalRow('5. Witness Aadhar No', currentLoanee.witnessaadharno),
                            _buildModalRow('6. Witness Address', currentLoanee.witnessaddress),
                            _buildModalRow('7. Witness Post Office (P/O)', currentLoanee.witnesspostoffice),
                            _buildModalRow('8. Witness Police Station (P/S)', currentLoanee.witnesspolicestation),
                            _buildModalRow('9. Witness District', currentLoanee.witnessdistrict),
                            _buildModalRow('10. Witness PIN Code', currentLoanee.witnesspincode),
                            _buildModalRow('11. Witness Business Type', currentLoanee.witnessbusinesstype),
                          ],
                        ],
                      ),
                    ),
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
