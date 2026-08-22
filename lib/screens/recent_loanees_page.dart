import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/loanee_model.dart';
import '../providers/auth_provider.dart';
import '../providers/loanee_provider.dart';
import '../widgets/edit_loanee_dialog.dart';

class RecentLoaneesPage extends StatefulWidget {
  final VoidCallback? onCreateLoaneePressed;

  const RecentLoaneesPage({
    super.key,
    this.onCreateLoaneePressed,
  });

  @override
  State<RecentLoaneesPage> createState() => _RecentLoaneesPageState();
}

class _RecentLoaneesPageState extends State<RecentLoaneesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDateFilter = 'All'; // All, Today, This Week, This Month, Custom
  DateTime? _selectedCustomDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesDateFilter(DateTime createdAt) {
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case 'Today':
        return createdAt.year == now.year &&
            createdAt.month == now.month &&
            createdAt.day == now.day;
      case 'This Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return createdAt.isAfter(weekAgo);
      case 'This Month':
        return createdAt.year == now.year && createdAt.month == now.month;
      case 'Custom':
        if (_selectedCustomDate == null) return true;
        return createdAt.year == _selectedCustomDate!.year &&
            createdAt.month == _selectedCustomDate!.month &&
            createdAt.day == _selectedCustomDate!.day;
      case 'All':
      default:
        return true;
    }
  }

  List<LoaneeAccount> _getFilteredLoanees(List<LoaneeAccount> allLoanees) {
    return allLoanees.where((l) {
      // 1. Search Query Filter
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          l.loaneeName.toLowerCase().contains(query) ||
          l.customerId.toLowerCase().contains(query) ||
          l.accountNumber.toLowerCase().contains(query) ||
          l.mobileNo.contains(query) ||
          l.district.toLowerCase().contains(query) ||
          l.businesstype.toLowerCase().contains(query) ||
          l.witnessName.toLowerCase().contains(query);

      // 2. Date Filter
      final matchesDate = _matchesDateFilter(l.createdAt);

      return matchesSearch && matchesDate;
    }).toList();
  }

  Future<void> _pickCustomDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCustomDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF8B1A1A),
              onPrimary: Colors.white,
              onSurface: Colors.grey.shade900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedCustomDate = picked;
        _selectedDateFilter = 'Custom';
      });
    }
  }

  void _showLoaneeDetailsDialog(BuildContext context, LoaneeAccount account, bool isAdmin) {
    final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final currentAccount = loaneeProvider.loanees.firstWhere(
            (l) => l.customerId.toLowerCase() == account.customerId.toLowerCase(),
            orElse: () => account,
          );
          final bool isCurrentActive = currentAccount.isActive;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF8B1A1A),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentAccount.loaneeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Cust ID: ${currentAccount.customerId}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Bar Toggle Box
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentActive ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
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
                              'Account Status',
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
                                final willBeActive = !isCurrentActive;
                                final newStatus = willBeActive ? 'Active' : 'Inactive';
                                await loaneeProvider.updateStatus(currentAccount.customerId, newStatus);
                                setDialogState(() {});
                                  if (context.mounted) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        willBeActive
                                            ? 'Account for ${currentAccount.loaneeName} is now ACTIVE'
                                            : 'Account for ${currentAccount.loaneeName} is now INACTIVE',
                                      ),
                                      backgroundColor: willBeActive ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  _buildModalSectionTitle('LOANEE PARTICULARS'),
                  _buildModalRow('Customer ID', currentAccount.customerId, Icons.badge_outlined),
                  _buildModalRow('Account Number', currentAccount.accountNumber, Icons.account_balance_wallet_outlined),
                  _buildModalRow('Mobile Number', currentAccount.mobileNo, Icons.phone_android_rounded),
                  _buildModalRow('W/O, S/O, D/O', currentAccount.guardianName.isNotEmpty ? currentAccount.guardianName : 'N/A', Icons.people_outline_rounded),
                  _buildModalRow('Aadhar Number', currentAccount.aadharNo.isNotEmpty ? currentAccount.aadharNo : 'N/A', Icons.credit_card_rounded),
                  _buildModalRow('Business Type', currentAccount.businesstype.isNotEmpty ? currentAccount.businesstype : 'N/A', Icons.storefront_outlined),
                  _buildModalRow('Address', '${currentAccount.address}, ${currentAccount.district}', Icons.location_on_outlined),
                  _buildModalRow('Police Station', currentAccount.policeStation.isNotEmpty ? currentAccount.policeStation : 'N/A', Icons.local_police_outlined),
                  _buildModalRow('Post Office', currentAccount.postOffice.isNotEmpty ? currentAccount.postOffice : 'N/A', Icons.markunread_mailbox_outlined),
                  _buildModalRow('PIN Code', currentAccount.pinCode.isNotEmpty ? currentAccount.pinCode : 'N/A', Icons.pin_drop_outlined),

                  const Divider(height: 20),
                  _buildModalSectionTitle('LOAN & FINANCIAL STATS'),
                  _buildModalRow('Sanctioned Amount', '₹ ${currentAccount.loanAmount.toStringAsFixed(2)}', Icons.currency_rupee_rounded, valueColor: Colors.black87),
                  _buildModalRow('Loan Sanction Date', currentAccount.formattedSanctionDate, Icons.calendar_today_outlined),
                  _buildModalRow('Loan Maturity Date (5m)', currentAccount.formattedMaturityDate, Icons.event_available_outlined, valueColor: Colors.teal.shade800),
                  _buildModalRow('Total Paid Amount', '₹ ${currentAccount.paidAmount.toStringAsFixed(2)}', Icons.payments_outlined, valueColor: Colors.green.shade800),
                  _buildModalRow('Remaining Due Balance', '₹ ${currentAccount.dueAmount.toStringAsFixed(2)}', Icons.money_off_rounded, valueColor: Colors.orange.shade900),

                  const Divider(height: 20),
                  _buildModalSectionTitle('WITNESS & REGISTRATION'),
                  _buildModalRow('Witness Name', currentAccount.witnessName.isNotEmpty ? currentAccount.witnessName : 'N/A', Icons.person_outline_rounded),
                  _buildModalRow('Witness Mobile', currentAccount.witnessMobileNo.isNotEmpty ? currentAccount.witnessMobileNo : 'N/A', Icons.phone_outlined),
                  _buildModalRow('Registration Date', currentAccount.createdAt.toString().split('.')[0], Icons.calendar_today_outlined),
                  _buildModalRow(
                    'Account Status',
                    currentAccount.status,
                    Icons.verified_user_outlined,
                    valueColor: isCurrentActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ],
              ),
            ),
            actions: [
              if (isAdmin)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1A1A),
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
                        EditLoaneeDialog.show(context, currentAccount);
                      }
                    });
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 15),
                  label: const Text('Edit Loanee', style: TextStyle(fontSize: 12)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModalSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8B1A1A),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF1E1E1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isAdmin = authProvider.activeRole == UserType.admin;

    final loaneeProvider = Provider.of<LoaneeProvider>(context);
    final allLoanees = loaneeProvider.loanees;
    final filteredLoanees = _getFilteredLoanees(allLoanees);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
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
                        Icon(Icons.recent_actors_rounded, color: Colors.amber, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Recent Registered Loanees',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Refresh from Supabase',
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: () {
                        loaneeProvider.fetchFromSupabase();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Syncing loanee accounts from Supabase...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Newly registered loanee customer profiles, loan sanction details & witness info',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Analytics Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryMetric(
                          title: 'Total Registered',
                          value: '${allLoanees.length} Accounts',
                          subtitle: 'All Live Profiles',
                          icon: Icons.people_alt_rounded,
                          color: Colors.blue.shade700,
                          backgroundColor: Colors.blue.shade50,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryMetric(
                          title: 'Total Loan Disbursed',
                          value: '₹ ${(loaneeProvider.totalLoanAmount / 1000).toStringAsFixed(1)}k',
                          subtitle: 'Portfolio Sanctioned',
                          icon: Icons.account_balance_wallet_rounded,
                          color: Colors.green.shade700,
                          backgroundColor: Colors.green.shade50,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search and Date Filter Bar
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Box
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by Name, Cust ID, Acc No, Mobile, District...',
                            hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Date Filter Chips
                        Row(
                          children: [
                            const Text(
                              'Filter by Date: ',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildDateFilterChip('All'),
                                    const SizedBox(width: 6),
                                    _buildDateFilterChip('Today'),
                                    const SizedBox(width: 6),
                                    _buildDateFilterChip('This Week'),
                                    const SizedBox(width: 6),
                                    _buildDateFilterChip('This Month'),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _pickCustomDate(context),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _selectedDateFilter == 'Custom'
                                              ? const Color(0xFF8B1A1A)
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: _selectedDateFilter == 'Custom'
                                                ? const Color(0xFF8B1A1A)
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_month_rounded,
                                              size: 13,
                                              color: _selectedDateFilter == 'Custom'
                                                  ? Colors.white
                                                  : Colors.grey.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _selectedDateFilter == 'Custom' && _selectedCustomDate != null
                                                  ? '${_selectedCustomDate!.day}/${_selectedCustomDate!.month}/${_selectedCustomDate!.year}'
                                                  : 'Pick Date',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _selectedDateFilter == 'Custom'
                                                    ? Colors.white
                                                    : Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Result Count & Register Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${filteredLoanees.length} of ${allLoanees.length} Loanees',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (widget.onCreateLoaneePressed != null)
                        TextButton.icon(
                          onPressed: widget.onCreateLoaneePressed,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                          label: const Text('Create New Loanee', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8B1A1A),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Loanees List
                  if (filteredLoanees.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.person_search_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No Registered Loanees Found',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try changing your search query or date filter.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredLoanees.length,
                      itemBuilder: (ctx, index) {
                        final account = filteredLoanees[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    child: Text(
                                      account.loaneeName.isNotEmpty
                                          ? account.loaneeName[0].toUpperCase()
                                          : 'L',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
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
                                                account.loaneeName,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1E1E1E),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '₹ ${account.loanAmount.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF8B1A1A),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${account.customerId} • ${account.accountNumber}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _buildTagChip('📞 ${account.mobileNo}', Colors.blue.shade50, Colors.blue.shade900),
                                  if (account.district.isNotEmpty)
                                    _buildTagChip('📍 ${account.district}', Colors.grey.shade100, Colors.black87),
                                  if (account.businesstype.isNotEmpty)
                                    _buildTagChip('🏢 ${account.businesstype}', Colors.amber.shade50, Colors.amber.shade900),
                                  _buildTagChip('📅 Sanction: ${account.formattedSanctionDate}', Colors.grey.shade100, Colors.grey.shade800),
                                  _buildTagChip('⏳ Maturity: ${account.formattedMaturityDate}', Colors.teal.shade50, Colors.teal.shade900),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: account.isActive ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: account.isActive ? Colors.green.shade300 : Colors.red.shade300,
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
                                                color: account.isActive ? Colors.green.shade700 : Colors.red.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              account.isActive ? 'ACTIVE' : 'INACTIVE',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                color: account.isActive ? Colors.green.shade800 : Colors.red.shade800,
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
                                                    value: account.isActive,
                                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    activeColor: Colors.green.shade700,
                                                    activeTrackColor: Colors.green.shade200,
                                                    inactiveThumbColor: Colors.red.shade700,
                                                    inactiveTrackColor: Colors.red.shade200,
                                                    onChanged: (val) async {
                                                      final willBeActive = !account.isActive;
                                                      final newStatus = willBeActive ? 'Active' : 'Inactive';
                                                      await loaneeProvider.updateStatus(account.customerId, newStatus);
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              willBeActive
                                                                  ? 'Account for ${account.loaneeName} is now ACTIVE'
                                                                  : 'Account for ${account.loaneeName} is now INACTIVE',
                                                            ),
                                                            backgroundColor: willBeActive ? Colors.green.shade800 : Colors.red.shade800,
                                                          ),
                                                        );
                                                      }
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isAdmin) ...[
                                        InkWell(
                                          onTap: () => EditLoaneeDialog.show(context, account),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF8B1A1A).withValues(alpha: 0.3)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit_note_rounded, size: 13, color: Color(0xFF8B1A1A)),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Edit',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF8B1A1A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      InkWell(
                                        onTap: () => _showLoaneeDetailsDialog(context, account, isAdmin),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.visibility_outlined, size: 13, color: Color(0xFF8B1A1A)),
                                              SizedBox(width: 4),
                                              Text(
                                                'View Details',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF8B1A1A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip(String label) {
    final isSelected = _selectedDateFilter == label;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDateFilter = label;
          if (label != 'Custom') _selectedCustomDate = null;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
