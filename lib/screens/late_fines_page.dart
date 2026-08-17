// lib/screens/late_fines_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/collection_payment_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/settings_provider.dart';

class LateFinesPage extends StatefulWidget {
  const LateFinesPage({super.key});

  @override
  State<LateFinesPage> createState() => _LateFinesPageState();
}

class _LateFinesPageState extends State<LateFinesPage> {
  String _selectedFilter = 'All'; // 'All', 'Daily', 'Weekly'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);
    final loaneeProvider = Provider.of<LoaneeProvider>(context);

    // Compute status for all collection entries
    final List<LoaneeLateFineStatus> allStatuses = [];
    final entries = collectionProvider.collectionEntries;

    for (final entry in entries) {
      final payments = collectionProvider.getPaymentsForCollection(entry.id);
      final status = settingsProvider.getLateFineStatusForEntry(
        entry: entry,
        payments: payments,
      );
      allStatuses.add(status);
    }

    // Filter statuses
    final filteredStatuses = allStatuses.where((s) {
      if (_selectedFilter == 'Daily' && !s.isDaily) return false;
      if (_selectedFilter == 'Weekly' && s.isDaily) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = s.loaneeName.toLowerCase().contains(q);
        final matchCust = s.customerId.toLowerCase().contains(q);
        final matchAcc = s.accountNumber.toLowerCase().contains(q);
        if (!matchName && !matchCust && !matchAcc) return false;
      }
      return true;
    }).toList();

    // Statistics
    final double totalFineAssessed =
        allStatuses.fold(0.0, (sum, s) => sum + s.calculatedLateFine);
    final double totalFineCollected = collectionProvider.payments
        .fold(0.0, (sum, p) => sum + p.lateFine);
    final int totalOverdueAccounts =
        allStatuses.where((s) => s.calculatedLateFine > 0).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Late Fines & Overdue Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Live calculation from Admin Settings: ',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      Text(
                        'Daily ₹${settingsProvider.dailyLateFine.toStringAsFixed(0)}/day • Weekly ₹${settingsProvider.weeklyLateFine.toStringAsFixed(0)}/wk',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildFineCard(
                          title: 'Total Fine Assessed',
                          amount: '₹ ${totalFineAssessed.toStringAsFixed(2)}',
                          subtitle: '$totalOverdueAccounts Overdue Accounts',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFineCard(
                          title: 'Fine Collected',
                          amount: '₹ ${totalFineCollected.toStringAsFixed(2)}',
                          subtitle: totalFineAssessed > 0
                              ? '${((totalFineCollected / (totalFineAssessed + totalFineCollected)) * 100).toStringAsFixed(1)}% Collected'
                              : 'All Clear',
                          icon: Icons.check_circle_rounded,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Search & Filter Tabs
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by loanee, customer ID...',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            fillColor: Colors.white,
                            filled: true,
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
                      ),
                      const SizedBox(width: 8),
                      // Filter Chips
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Schemes', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Daily', child: Text('Daily Scheme', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Weekly', child: Text('Weekly Scheme', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedFilter = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Live Overdue Accounts & Penalties',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B1A1A),
                        ),
                      ),
                      Text(
                        '${filteredStatuses.length} accounts',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (filteredStatuses.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 40, color: Colors.green.shade600),
                          const SizedBox(height: 8),
                          const Text(
                            'No Overdue Accounts Found',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'All matching accounts are up to date with collection payments.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredStatuses.map((status) {
                      return _buildOverdueStatusItem(
                        context,
                        status,
                        settingsProvider,
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFineCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 8,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(amount,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B1A1A))),
          Text(subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildOverdueStatusItem(
    BuildContext context,
    LoaneeLateFineStatus status,
    SettingsProvider settings,
  ) {
    final hasFine = status.calculatedLateFine > 0;
    final isDaily = status.isDaily;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFine ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: hasFine ? Colors.red.shade50 : Colors.teal.shade50,
                child: Icon(
                  hasFine ? Icons.timer_off_rounded : Icons.check_circle_rounded,
                  color: hasFine ? Colors.red.shade700 : Colors.teal.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          status.loaneeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDaily ? Colors.blue.shade50 : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDaily ? Colors.blue.shade200 : Colors.purple.shade200,
                            ),
                          ),
                          child: Text(
                            status.collectionType,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isDaily ? Colors.blue.shade900 : Colors.purple.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${status.customerId} • ${status.accountNumber}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Fine: ₹ ${status.calculatedLateFine.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: hasFine ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                  Text(
                    '${status.overdueUnits} ${isDaily ? "days" : "weeks"} late',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasFine ? Colors.red.shade600 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  status.hasPaymentsInTable ? Icons.check_circle_outline : Icons.info_outline,
                  size: 12,
                  color: status.hasPaymentsInTable ? Colors.green.shade800 : Colors.orange.shade800,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    status.hasPaymentsInTable
                        ? 'Table ro_collection_payments: ${status.paymentRecordsCount} payments found • Last: ${SettingsProvider.formatDate(status.lastPaymentDate!)}'
                        : 'Table ro_collection_payments: No payment record since start ${SettingsProvider.formatDate(status.loanStartDate)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
