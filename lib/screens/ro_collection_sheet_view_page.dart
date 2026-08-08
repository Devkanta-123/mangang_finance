// lib/screens/ro_collection_sheet_view_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_sheet_provider.dart';

class RoCollectionSheetViewPage extends StatefulWidget {
  final VoidCallback? onAddLoaneePressed;

  const RoCollectionSheetViewPage({
    super.key,
    this.onAddLoaneePressed,
  });

  @override
  State<RoCollectionSheetViewPage> createState() =>
      _RoCollectionSheetViewPageState();
}

class _RoCollectionSheetViewPageState
    extends State<RoCollectionSheetViewPage> {
  String _selectedRouteFilter = 'All Routes';
  String _selectedTypeFilter = 'All Types';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _collectionTypeOptions = [
    'All Types',
    'Daily',
    'Mon',
    'Tue',
    'Wed',
    'Thur',
    'Fri',
    'Sat',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedRouteFilter = 'All Routes';
      _selectedTypeFilter = 'All Types';
      _searchController.clear();
      _searchQuery = '';
    });
  }

  // SweetAlert style delete confirmation dialog
  Future<bool> _showSweetAlertDeleteConfirm(
      BuildContext context, RoCollectionEntry entry) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade200, width: 2),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 56,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Collection Entry?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete the collection record for ${entry.loaneeName} (${entry.customerId})?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Collected Amount', '₹ ${entry.collectedAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 4),
                  _buildSummaryRow('Remaining Balance', '₹ ${entry.remainingBalance.toStringAsFixed(2)}'),
                  const SizedBox(height: 4),
                  _buildSummaryRow('Route', entry.route),
                  const SizedBox(height: 4),
                  _buildSummaryRow('Type', entry.collectionType),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Yes, Delete Entry'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // SweetAlert style Success Dialog for Payment Entry Insertion
  void _showSweetSuccessDialog(
      BuildContext context, RoCollectionEntry entry, double paymentAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade300, width: 2),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 56,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Entry Recorded!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Successfully recorded payment collection for ${entry.loaneeName}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                      'Payment Collected', '₹ ${paymentAmount.toStringAsFixed(2)}'),
                  const Divider(height: 12),
                  _buildSummaryRow('Payment Mode', entry.paymentType),
                  const Divider(height: 12),
                  _buildSummaryRow('Remaining Balance',
                      '₹ ${entry.remainingBalance.toStringAsFixed(2)}'),
                  const Divider(height: 12),
                  _buildSummaryRow('Late Fine',
                      '₹ ${entry.lateFine.toStringAsFixed(2)}'),
                  const Divider(height: 12),
                  _buildSummaryRow('Customer ID', entry.customerId),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Popup Modal for View Details
  void _showViewDetailsModal(BuildContext context, RoCollectionEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.amber.shade100,
                    child: Text(
                      entry.loaneeName.isNotEmpty
                          ? entry.loaneeName[0].toUpperCase()
                          : 'L',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.loaneeName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Customer ID: ${entry.customerId} • Acc: ${entry.accountNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRouteBadge(entry.route),
                  _buildCollectionTypeBadge(entry.collectionType),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (entry.status == 'Collected' || entry.paymentAmount > 0)
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (entry.status == 'Collected' || entry.paymentAmount > 0)
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Text(
                      (entry.status == 'Collected' || entry.paymentAmount > 0)
                          ? '✅ Payment Collected (${entry.paymentType})'
                          : '⏳ Pending Payment',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (entry.status == 'Collected' || entry.paymentAmount > 0)
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Total Collected',
                      '₹ ${entry.collectedAmount.toStringAsFixed(2)}',
                      Icons.payments_rounded,
                      isBold: true,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Remaining Balance',
                      '₹ ${entry.remainingBalance.toStringAsFixed(2)}',
                      Icons.account_balance_wallet_rounded,
                      isBold: true,
                      valueColor: Colors.orange.shade800,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Last Payment Amount',
                      '₹ ${entry.paymentAmount.toStringAsFixed(2)}',
                      Icons.price_check_rounded,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Late Fine',
                      '₹ ${entry.lateFine.toStringAsFixed(2)}',
                      Icons.warning_amber_rounded,
                      valueColor: entry.lateFine > 0 ? Colors.red : Colors.grey.shade800,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Payment Type',
                      entry.paymentType,
                      Icons.payment_rounded,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Mobile Number',
                      entry.mobileNo,
                      Icons.phone_android_rounded,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Loanee Address',
                      entry.loaneeAddress,
                      Icons.location_on_rounded,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Collection Type',
                      entry.collectionType,
                      Icons.calendar_month_rounded,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Route Zone',
                      entry.route,
                      Icons.alt_route_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final confirmed =
                            await _showSweetAlertDeleteConfirm(context, entry);
                        if (confirmed && context.mounted) {
                          Provider.of<CollectionSheetProvider>(
                                  context,
                                  listen: false)
                              .deleteCollectionEntry(entry.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Entry for ${entry.loaneeName} deleted.'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete Entry'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Close',
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
    );
  }

  // Popup Modal for Add Payment Entry
  void _showAddPaymentEntryModal(
      BuildContext context, RoCollectionEntry entry) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPaymentEntryModalContent(entry: entry),
    );

    if (result != null && result['success'] == true && context.mounted) {
      final double paidAmt = (result['paymentAmount'] ?? 0.0).toDouble();
      final RoCollectionEntry updatedEntry = result['updatedEntry'] ?? entry;

      // Show SweetAlert Success Dialog
      _showSweetSuccessDialog(context, updatedEntry, paidAmt);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ₹${paidAmt.toStringAsFixed(2)} via ${updatedEntry.paymentType} recorded for ${updatedEntry.loaneeName}!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? (isBold ? Colors.black87 : Colors.grey.shade800),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CollectionSheetProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isRoPanel = authProvider.activeRole == UserType.ro;
    final routeNames = ['All Routes', ...provider.routeNames];

    final filteredEntries = provider.getFilteredEntries(
      selectedRoute: _selectedRouteFilter,
      selectedType: _selectedTypeFilter,
      searchQuery: _searchQuery,
    );

    final totalFilteredAmount = filteredEntries.fold(
      0.0,
      (sum, item) => sum + item.collectedAmount,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber.shade700,
        onPressed: widget.onAddLoaneePressed,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Collection Entry',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchFromSupabase();
        },
        child: Column(
          children: [
            // Clean Dark Header Banner
            Container(
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
                          Icon(Icons.collections_bookmark_rounded,
                              color: Colors.white, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Collection View',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: provider.isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync_rounded, color: Colors.white),
                        tooltip: 'Sync Collection Table',
                        onPressed: () => provider.fetchFromSupabase(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Live Search Field
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Search by Loanee Name, Cust ID, Acc No, Mobile, Address...',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.black87),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18, color: Colors.black54),
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
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Route & Type Filters Row (Responsive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          // Route Filter Dropdown
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: routeNames.contains(_selectedRouteFilter)
                                      ? _selectedRouteFilter
                                      : 'All Routes',
                                  dropdownColor: const Color(0xFF2C2C2C),
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: Colors.white),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                  items: routeNames
                                      .map((r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(r,
                                                overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedRouteFilter = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Type Filter Dropdown
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedTypeFilter,
                                  dropdownColor: const Color(0xFF2C2C2C),
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: Colors.white),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                  items: _collectionTypeOptions
                                      .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedTypeFilter = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
                    'Showing ${filteredEntries.length} of ${provider.totalEntriesCount} Records',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    'Total Collected: ₹ ${totalFilteredAmount.toStringAsFixed(2)}',
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

            // Collection Cards List View
            Expanded(
              child: filteredEntries.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 60, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                provider.collectionEntries.isEmpty
                                    ? 'No Collection Entries in Database'
                                    : 'No Matching Collection Entries',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                provider.collectionEntries.isEmpty
                                    ? 'Tap "Add Collection Entry" to record a loanee collection'
                                    : 'Try resetting filters or search query',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (_selectedRouteFilter != 'All Routes' ||
                                  _selectedTypeFilter != 'All Types' ||
                                  _searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _resetFilters,
                                  icon: const Icon(Icons.restart_alt_rounded,
                                      size: 16),
                                  label: const Text('Reset All Filters'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E1E1E),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];

                        return Dismissible(
                          key: Key(entry.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.centerRight,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Delete Record',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.delete_forever_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await _showSweetAlertDeleteConfirm(
                                context, entry);
                          },
                          onDismissed: (direction) {
                            provider.deleteCollectionEntry(entry.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Entry for ${entry.loaneeName} deleted.'),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          },
                          child: _RoCollectionEntryItemCard(
                            entry: entry,
                            isRoPanel: isRoPanel,
                            onTapView: () =>
                                _showViewDetailsModal(context, entry),
                            onTapAddPayment: () =>
                                _showAddPaymentEntryModal(context, entry),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionTypeBadge(String type) {
    Color bg;
    Color fg;
    switch (type.toLowerCase()) {
      case 'daily':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        break;
      case 'mon':
      case 'tue':
      case 'wed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      default:
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRouteBadge(String route) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alt_route_rounded, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            route,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Item Card Component with Action Buttons under each collection item
class _RoCollectionEntryItemCard extends StatelessWidget {
  final RoCollectionEntry entry;
  final bool isRoPanel;
  final VoidCallback onTapView;
  final VoidCallback onTapAddPayment;

  const _RoCollectionEntryItemCard({
    required this.entry,
    required this.isRoPanel,
    required this.onTapView,
    required this.onTapAddPayment,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAlreadyCollected =
        entry.status == 'Collected' || entry.paymentAmount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.customerId,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Acc: ${entry.accountNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isAlreadyCollected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Payment Collected',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.amber.shade100,
                  child: Text(
                    entry.loaneeName.isNotEmpty
                        ? entry.loaneeName[0].toUpperCase()
                        : 'L',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.loaneeName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_android_rounded,
                              size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            entry.mobileNo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹ ${entry.collectedAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Collected Total',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.loaneeAddress,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildRouteBadge(entry.route),
                const SizedBox(width: 4),
                _buildCollectionTypeBadge(entry.collectionType),
              ],
            ),

            const Divider(height: 20),

            // Action Buttons Row
            Row(
              children: [
                if (isRoPanel && !isAlreadyCollected) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 1,
                      ),
                      onPressed: onTapAddPayment,
                      icon: const Icon(Icons.add_card_rounded, size: 16),
                      label: const Text(
                        'Add Payment Entry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E1E1E),
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onTapView,
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text(
                      'View',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionTypeBadge(String type) {
    Color bg;
    Color fg;
    switch (type.toLowerCase()) {
      case 'daily':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        break;
      case 'mon':
      case 'tue':
      case 'wed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      default:
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRouteBadge(String route) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alt_route_rounded, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            route,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal Content Component for Add Payment Entry Form Modal
class _AddPaymentEntryModalContent extends StatefulWidget {
  final RoCollectionEntry entry;

  const _AddPaymentEntryModalContent({required this.entry});

  @override
  State<_AddPaymentEntryModalContent> createState() =>
      __AddPaymentEntryModalContentState();
}

class __AddPaymentEntryModalContentState
    extends State<_AddPaymentEntryModalContent> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _remainingBalanceController;
  late TextEditingController _paymentAmountController;
  late TextEditingController _lateFineController;
  late TextEditingController _roPasscodeController;

  String _selectedPaymentType = 'Cash';
  bool _isSubmitting = false;
  String? _passcodeError;

  final List<String> _paymentTypes = [
    'Cash',
    'Paytm',
    'Gpay',
    'Phonepay',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _remainingBalanceController = TextEditingController(
      text: widget.entry.remainingBalance > 0
          ? widget.entry.remainingBalance.toStringAsFixed(2)
          : '5000.00',
    );
    _paymentAmountController = TextEditingController(
      text: widget.entry.paymentAmount > 0
          ? widget.entry.paymentAmount.toStringAsFixed(2)
          : '',
    );
    _lateFineController = TextEditingController(
      text: widget.entry.lateFine > 0
          ? widget.entry.lateFine.toStringAsFixed(2)
          : '0.00',
    );
    _roPasscodeController = TextEditingController();

    if (_paymentTypes.contains(widget.entry.paymentType)) {
      _selectedPaymentType = widget.entry.paymentType;
    } else if (widget.entry.paymentType.toLowerCase() == 'cash') {
      _selectedPaymentType = 'Cash';
    } else if (widget.entry.paymentType.toLowerCase() == 'paytm') {
      _selectedPaymentType = 'Paytm';
    } else if (widget.entry.paymentType.toLowerCase() == 'gpay') {
      _selectedPaymentType = 'Gpay';
    } else if (widget.entry.paymentType.toLowerCase() == 'phonepay') {
      _selectedPaymentType = 'Phonepay';
    } else {
      _selectedPaymentType = 'Other';
    }
  }

  @override
  void dispose() {
    _remainingBalanceController.dispose();
    _paymentAmountController.dispose();
    _lateFineController.dispose();
    _roPasscodeController.dispose();
    super.dispose();
  }

  bool _verifyRoPasscode(String passcode, AuthProvider authProvider) {
    final cleanPass = passcode.trim();
    if (cleanPass.isEmpty) return false;

    // Standard default RO Passcode / Admin PINs
    if (cleanPass == '789122' || cleanPass == '123456' || cleanPass == '112233') {
      return true;
    }

    // Check with AuthProvider validator
    if (authProvider.validateDemoPin(cleanPass)) {
      return true;
    }

    // Allow any numeric passcode between 4 and 8 digits
    if (cleanPass.length >= 4 &&
        cleanPass.length <= 8 &&
        RegExp(r'^\d+$').hasMatch(cleanPass)) {
      return true;
    }

    return false;
  }

  Future<void> _submitEntryForm(BuildContext context) async {
    setState(() {
      _passcodeError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final enteredPasscode = _roPasscodeController.text.trim();

    // Verify RO Passcode
    if (!_verifyRoPasscode(enteredPasscode, authProvider)) {
      setState(() {
        _passcodeError = 'Invalid RO Passcode! (Default RO Passcode: 789122)';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final paymentAmount =
        double.tryParse(_paymentAmountController.text.trim()) ?? 0.0;
    final remainingBal =
        double.tryParse(_remainingBalanceController.text.trim()) ?? 0.0;
    final lateFine =
        double.tryParse(_lateFineController.text.trim()) ?? 0.0;

    final newCollectedAmount = widget.entry.collectedAmount + paymentAmount;
    final newRemainingBalance =
        remainingBal >= paymentAmount ? (remainingBal - paymentAmount) : 0.0;

    final updatedEntry = RoCollectionEntry(
      id: widget.entry.id,
      customerId: widget.entry.customerId,
      accountNumber: widget.entry.accountNumber,
      loaneeName: widget.entry.loaneeName,
      loaneeAddress: widget.entry.loaneeAddress,
      collectionType: widget.entry.collectionType,
      collectedAmount: newCollectedAmount,
      remainingBalance: newRemainingBalance,
      paymentAmount: paymentAmount,
      lateFine: lateFine,
      paymentType: _selectedPaymentType,
      route: widget.entry.route,
      mobileNo: widget.entry.mobileNo,
      createdAt: widget.entry.createdAt,
      status: 'Collected',
    );

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final collectionProvider =
        Provider.of<CollectionSheetProvider>(context, listen: false);

    final success =
        await collectionProvider.updateCollectionEntry(updatedEntry);

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      // Pop modal with result map to trigger parent success dialog cleanly
      navigator.pop({
        'success': true,
        'paymentAmount': paymentAmount,
        'updatedEntry': updatedEntry,
      });
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to save collection entry.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_card_rounded,
                      color: Colors.amber.shade900,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Payment Entry',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        Text(
                          '${widget.entry.loaneeName} • ${widget.entry.customerId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Field 1: Remaining Balance & Field 2: Payment Amount
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Remaining Balance (₹)'),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _remainingBalanceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixText: '₹ ',
                            prefixStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors.grey.shade300),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(val.trim()) == null) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Payment Amount (₹) *'),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _paymentAmountController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.green.shade50.withValues(alpha: 0.3),
                            hintText: '0.00',
                            prefixText: '₹ ',
                            prefixStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors.green.shade300),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter amount';
                            }
                            final amt = double.tryParse(val.trim());
                            if (amt == null || amt <= 0) {
                              return 'Valid amount';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Field 3: Late Fine & Field 4: PaymentType Dropdown
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Late Fine (₹)'),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _lateFineController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            hintText: '0.00',
                            prefixText: '₹ ',
                            prefixStyle: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade700),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Payment Type *'),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _selectedPaymentType,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors.grey.shade300),
                            ),
                          ),
                          items: _paymentTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type,
                                  style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedPaymentType = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Field 5: RO Passcode
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('RO Passcode / PIN *'),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _roPasscodeController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      hintText: 'Enter RO Passcode (Default: 789122)',
                      hintStyle: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400),
                      prefixIcon:
                          const Icon(Icons.lock_outline_rounded, size: 18),
                      errorText: _passcodeError,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: _passcodeError != null
                                ? Colors.red
                                : Colors.grey.shade300),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Passcode required';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Modal Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 1,
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitEntryForm(context),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        _isSubmitting
                            ? 'Saving...'
                            : 'Confirm & Submit Payment',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }
}
