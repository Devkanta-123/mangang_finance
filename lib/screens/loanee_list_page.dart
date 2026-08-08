// lib/screens/loanee_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/loanee_model.dart';
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

      return matchesSearch && matchesDistrict;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loaneeProvider = Provider.of<LoaneeProvider>(context);
    final filteredLoanees = _filterLoanees(loaneeProvider.loanees);

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
                    'Showing ${filteredLoanees.length} of ${loaneeProvider.totalLoanees} Accounts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    'Sanctioned: ₹ ${(loaneeProvider.totalLoanAmount / 100000).toStringAsFixed(2)} L',
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

            // Loanee Accounts List Area
            Expanded(
              child: filteredLoanees.isEmpty
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
                      itemCount: filteredLoanees.length,
                      itemBuilder: (context, index) {
                        final item = filteredLoanees[index];
                        return _buildLoaneeCard(context, item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaneeCard(BuildContext context, LoaneeAccount item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => _showLoaneeDetailsDialog(context, item),
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
                    child: const Icon(Icons.person, color: Colors.black, size: 24),
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
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Text(
                                item.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
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

  void _showLoaneeDetailsDialog(BuildContext context, LoaneeAccount item) {
    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          title: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black,
                    child: Icon(Icons.badge_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.loaneename,
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
            height: 380,
            child: TabBarView(
              children: [
                // Tab 1: Loanee Details
                SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildModalRow('1. Customer ID', item.customerid),
                      _buildModalRow('2. Account Number', item.accountnumber),
                      _buildModalRow('3. Loanee Name', item.loaneename),
                      _buildModalRow('4. W/O, S/O, D/O', item.guardianname),
                      _buildModalRow('5. Mobile No', item.mobileno),
                      _buildModalRow('6. Aadhar No', item.aadharno),
                      _buildModalRow('7. Address', item.address),
                      _buildModalRow('8. Post Office (P/O)', item.postoffice),
                      _buildModalRow('9. Police Station (P/S)', item.policestation),
                      _buildModalRow('10. District', item.district),
                      _buildModalRow('11. PIN Code', item.pincode),
                      _buildModalRow('12. Business Type', item.businesstype),
                      _buildModalRow('13. Sanctioned Amount', '₹ ${item.loanamount.toStringAsFixed(0)}'),
                      _buildModalRow('14. Account Status', item.status),
                    ],
                  ),
                ),

                // Tab 2: Witness Details
                SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      if (item.witnessname.isEmpty)
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
                        _buildModalRow('1. Witness Name', item.witnessname),
                        _buildModalRow('2. Witness W/O, S/O, D/O', item.witnessguardianname),
                        _buildModalRow('3. Relationship with Loanee', item.witnessrelationship),
                        _buildModalRow('4. Witness Mobile No', item.witnessmobileno),
                        _buildModalRow('5. Witness Aadhar No', item.witnessaadharno),
                        _buildModalRow('6. Witness Address', item.witnessaddress),
                        _buildModalRow('7. Witness Post Office (P/O)', item.witnesspostoffice),
                        _buildModalRow('8. Witness Police Station (P/S)', item.witnesspolicestation),
                        _buildModalRow('9. Witness District', item.witnessdistrict),
                        _buildModalRow('10. Witness PIN Code', item.witnesspincode),
                        _buildModalRow('11. Witness Business Type', item.witnessbusinesstype),
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
