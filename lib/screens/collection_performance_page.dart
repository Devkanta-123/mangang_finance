// lib/screens/collection_performance_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/collection_payment_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/ro_model.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/ro_provider.dart';
import '../providers/settings_provider.dart';

enum DateFilterOption {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  customDate,
}

enum SortOption {
  latestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount,
  loaneeName,
  roOfficer,
}

class CollectionPerformancePage extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const CollectionPerformancePage({
    super.key,
    this.onBackToDashboard,
  });

  @override
  State<CollectionPerformancePage> createState() => _CollectionPerformancePageState();
}

class _CollectionPerformancePageState extends State<CollectionPerformancePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  DateFilterOption _selectedDateFilter = DateFilterOption.today;
  DateTime? _customSingleDate;

  String _selectedRo = 'All'; // 'All' or specific RO name/id
  String _selectedAdmin = 'All'; // 'All' or specific Admin name

  SortOption _selectedSort = SortOption.latestFirst;
  int _activeSummaryTab = 0; // 0: RO Breakdown, 1: Route Breakdown

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // DATE FILTERING HELPER
  // ==========================================
  bool _matchesDateFilter(DateTime paymentDate) {
    final now = DateTime.now();

    switch (_selectedDateFilter) {
      case DateFilterOption.today:
        return paymentDate.year == now.year &&
            paymentDate.month == now.month &&
            paymentDate.day == now.day;

      case DateFilterOption.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return paymentDate.year == yesterday.year &&
            paymentDate.month == yesterday.month &&
            paymentDate.day == yesterday.day;

      case DateFilterOption.thisWeek:
        // Current week Monday through Sunday
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final endOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6, 23, 59, 59);
        return !paymentDate.isBefore(startOfWeek) && !paymentDate.isAfter(endOfWeek);

      case DateFilterOption.thisMonth:
        return paymentDate.year == now.year && paymentDate.month == now.month;

      case DateFilterOption.customDate:
        if (_customSingleDate != null) {
          return paymentDate.year == _customSingleDate!.year &&
              paymentDate.month == _customSingleDate!.month &&
              paymentDate.day == _customSingleDate!.day;
        }
        return true;
    }
  }

  String _getDateFilterLabel() {
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case DateFilterOption.today:
        return 'Today (${SettingsProvider.formatDate(now)})';
      case DateFilterOption.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return 'Yesterday (${SettingsProvider.formatDate(yesterday)})';
      case DateFilterOption.thisWeek:
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final endOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6);
        return 'This Week (${SettingsProvider.formatDate(startOfWeek)} - ${SettingsProvider.formatDate(endOfWeek)})';
      case DateFilterOption.thisMonth:
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return 'This Month (${months[now.month - 1]} ${now.year})';
      case DateFilterOption.customDate:
        if (_customSingleDate != null) {
          return 'Custom Date: ${SettingsProvider.formatDate(_customSingleDate!)}';
        }
        return 'Custom Date (Select)';
    }
  }

  // ==========================================
  // SINGLE CUSTOM DATE PICKER
  // ==========================================
  Future<void> _pickCustomSingleDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSingleDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B1A1A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customSingleDate = picked;
        _selectedDateFilter = DateFilterOption.customDate;
      });
    }
  }

  // ==========================================
  // RESET FILTERS
  // ==========================================
  void _resetAllFilters() {
    setState(() {
      _selectedDateFilter = DateFilterOption.today;
      _customSingleDate = null;
      _selectedRo = 'All';
      _selectedAdmin = 'All';
      _selectedSort = SortOption.latestFirst;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  bool get _hasCustomFiltersActive {
    return _selectedDateFilter != DateFilterOption.today ||
        _selectedRo != 'All' ||
        _selectedAdmin != 'All' ||
        _selectedSort != SortOption.latestFirst ||
        _searchQuery.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final activeRole = authProvider.activeRole;

    // Security & Access Control: Manager and Admin ONLY
    final bool hasAccess = activeRole == UserType.admin || activeRole == UserType.manager;

    if (!hasAccess) {
      return _buildAccessRestrictedView(context);
    }

    final collectionProvider = Provider.of<CollectionSheetProvider>(context);
    final roProvider = Provider.of<RoProvider>(context);

    final allPayments = collectionProvider.payments;
    final allCards = collectionProvider.collectionEntries;
    final allRos = roProvider.roAccounts;
    final adminUsers = authProvider.adminUsers;

    // Map card by ID for fast O(1) lookup
    final cardMap = <String, RoCollectionEntry>{};
    for (final c in allCards) {
      cardMap[c.id] = c;
    }

    // 1. FILTERING (RO, Admin, Date, Search Query)
    final filteredPayments = allPayments.where((payment) {
      // Date filter
      if (!_matchesDateFilter(payment.createdAt)) {
        return false;
      }

      final card = cardMap[payment.collectionId];

      // RO filter
      if (_selectedRo != 'All') {
        final pRoName = (payment.roName ?? '').toLowerCase().trim();
        final pRoId = (payment.roId ?? '').toLowerCase().trim();
        final target = _selectedRo.toLowerCase().trim();
        final matchRo = pRoName == target || pRoId == target;
        if (!matchRo) return false;
      }

      // Admin filter
      if (_selectedAdmin != 'All') {
        final target = _selectedAdmin.toLowerCase().trim();
        final pRoName = (payment.roName ?? '').toLowerCase().trim();
        final pRoId = (payment.roId ?? '').toLowerCase().trim();
        final pRemarks = (payment.remarks ?? '').toLowerCase().trim();

        final matchAdmin = payment.isAdminOrOfficeEntry &&
            (pRoName == target ||
                pRoName.contains(target) ||
                pRoId == target ||
                pRemarks.contains(target));
        if (!matchAdmin) return false;
      }

      // Search Query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchLoanee = card?.loaneeName.toLowerCase().contains(q) ?? false;
        final matchCust = card?.customerId.toLowerCase().contains(q) ?? false;
        final matchAcc = card?.accountNumber.toLowerCase().contains(q) ?? false;
        final matchPhone = card?.mobileNo.contains(q) ?? false;
        final matchRo = payment.roName?.toLowerCase().contains(q) ?? false;
        final matchRoute = (payment.roRoute?.toLowerCase().contains(q) ?? false) ||
            (card?.route.toLowerCase().contains(q) ?? false);
        final matchId = payment.id.toLowerCase().contains(q);

        if (!matchLoanee &&
            !matchCust &&
            !matchAcc &&
            !matchPhone &&
            !matchRo &&
            !matchRoute &&
            !matchId) {
          return false;
        }
      }

      return true;
    }).toList();

    // 2. SORTING
    filteredPayments.sort((a, b) {
      final cardA = cardMap[a.collectionId];
      final cardB = cardMap[b.collectionId];

      switch (_selectedSort) {
        case SortOption.latestFirst:
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.oldestFirst:
          return a.createdAt.compareTo(b.createdAt);
        case SortOption.highestAmount:
          return b.paymentAmount.compareTo(a.paymentAmount);
        case SortOption.lowestAmount:
          return a.paymentAmount.compareTo(b.paymentAmount);
        case SortOption.loaneeName:
          final nameA = cardA?.loaneeName ?? '';
          final nameB = cardB?.loaneeName ?? '';
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        case SortOption.roOfficer:
          final roA = a.roName ?? '';
          final roB = b.roName ?? '';
          return roA.toLowerCase().compareTo(roB.toLowerCase());
      }
    });

    // 3. AGGREGATIONS / SUMMARY METRICS
    final double totalCollected = filteredPayments.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final int paymentsCount = filteredPayments.length;
    final Set<String> distinctLoans = filteredPayments.map((p) => p.collectionId).toSet();
    final int loansCount = distinctLoans.length;
    final double avgPayment = paymentsCount > 0 ? (totalCollected / paymentsCount) : 0.0;

    // RO-wise Aggregation
    final roMap = <String, _RoSummaryItem>{};
    for (final p in filteredPayments) {
      final roKey = p.isAdminOrOfficeEntry
          ? (p.roName != null && p.roName!.isNotEmpty ? p.roName! : 'Administrator (Office)')
          : (p.roName != null && p.roName!.isNotEmpty ? p.roName! : 'RO Field Officer');
      final current = roMap[roKey] ?? _RoSummaryItem(name: roKey, count: 0, amount: 0.0);
      roMap[roKey] = _RoSummaryItem(
        name: roKey,
        count: current.count + 1,
        amount: current.amount + p.paymentAmount,
      );
    }
    final roSummaryList = roMap.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));

    // Route-wise Aggregation
    final routeMap = <String, _RouteSummaryItem>{};
    for (final p in filteredPayments) {
      final card = cardMap[p.collectionId];
      final routeKey = (p.roRoute != null && p.roRoute!.isNotEmpty)
          ? p.roRoute!
          : (card != null && card.route.isNotEmpty ? card.route : 'Office / General');
      final current = routeMap[routeKey] ?? _RouteSummaryItem(routeName: routeKey, count: 0, amount: 0.0);
      routeMap[routeKey] = _RouteSummaryItem(
        routeName: routeKey,
        count: current.count + 1,
        amount: current.amount + p.paymentAmount,
      );
    }
    final routeSummaryList = routeMap.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        color: const Color(0xFF8B1A1A),
        onRefresh: () async {
          await collectionProvider.fetchFromSupabase();
          await roProvider.fetchFromSupabase();
          await authProvider.fetchAdminUsers();
        },
        child: CustomScrollView(
          slivers: [
            // 1. App Header Banner with Live Search
            SliverToBoxAdapter(
              child: _buildHeaderBanner(context, collectionProvider),
            ),

            // 2. Compact Total Recovery Card at the TOP
            SliverToBoxAdapter(
              child: _buildCompactTopSummaryCard(
                totalCollected: totalCollected,
                paymentsCount: paymentsCount,
                loansCount: loansCount,
                avgPayment: avgPayment,
              ),
            ),

            // 3. Responsive Date Quick Filters (Wrap for smaller screens)
            SliverToBoxAdapter(
              child: _buildDateFilterBar(context),
            ),

            // 4. Multi-Dimension Filters (Only RO and Admin)
            SliverToBoxAdapter(
              child: _buildRoAndAdminFilters(
                allRos: allRos,
                adminUsers: adminUsers,
              ),
            ),

            // 5. Performance Breakdown (RO Wise & Route Wise)
            SliverToBoxAdapter(
              child: _buildBreakdownSection(
                totalCollected: totalCollected,
                roSummaryList: roSummaryList,
                routeSummaryList: routeSummaryList,
              ),
            ),

            // 6. Results Counter & Sorting Strip
            SliverToBoxAdapter(
              child: _buildSortingAndCounterStrip(filteredPayments.length),
            ),

            // 7. Payments List
            if (filteredPayments.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final payment = filteredPayments[index];
                      final card = cardMap[payment.collectionId];
                      return _buildPaymentCard(context, payment, card);
                    },
                    childCount: filteredPayments.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ACCESS RESTRICTED VIEW
  // ==========================================
  Widget _buildAccessRestrictedView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, size: 64, color: Colors.red.shade700),
              ),
              const SizedBox(height: 20),
              const Text(
                'Access Restricted',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Collection Performance Monitoring is strictly restricted to Branch Managers and Administrators.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1A1A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (widget.onBackToDashboard != null) {
                    widget.onBackToDashboard!();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HEADER BANNER WITH SEARCH
  // ==========================================
  Widget _buildHeaderBanner(BuildContext context, CollectionSheetProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
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
                  Icon(Icons.insights_rounded, color: Colors.amber, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Collection Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: provider.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                tooltip: 'Sync Live Data',
                onPressed: () => provider.fetchFromSupabase(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search loanee, customer ID, account, RO...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
              prefixIcon: const Icon(Icons.search, color: Colors.black87, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Colors.black54),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // COMPACT TOTAL AMOUNT TOP CARD
  // ==========================================
  Widget _buildCompactTopSummaryCard({
    required double totalCollected,
    required int paymentsCount,
    required int loansCount,
    required double avgPayment,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B1A1A), Color(0xFF631010)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B1A1A).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL AMOUNT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$paymentsCount Entries',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '₹ ${totalCollected.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Loans: ',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      Text(
                        '$loansCount Accounts',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Avg: ',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      Text(
                        '₹ ${avgPayment.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // RESPONSIVE DATE QUICK FILTERS BAR (WRAP)
  // ==========================================
  Widget _buildDateFilterBar(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF8B1A1A)),
                  const SizedBox(width: 6),
                  Text(
                    _getDateFilterLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
              if (_hasCustomFiltersActive)
                InkWell(
                  onTap: _resetAllFilters,
                  child: Row(
                    children: [
                      Icon(Icons.restart_alt_rounded, size: 13, color: Colors.red.shade700),
                      const SizedBox(width: 2),
                      Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Responsive Wrap for Date Filter buttons (flows to next row on smaller screens)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildDateChip('Today', DateFilterOption.today),
              _buildDateChip('Yesterday', DateFilterOption.yesterday),
              _buildDateChip('This Week', DateFilterOption.thisWeek),
              _buildDateChip('This Month', DateFilterOption.thisMonth),
              _buildCustomDateChip(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, DateFilterOption option) {
    final isSelected = _selectedDateFilter == option;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey.shade800,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF8B1A1A),
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedDateFilter = option;
            _customSingleDate = null;
          });
        }
      },
    );
  }

  Widget _buildCustomDateChip(BuildContext context) {
    final isSelected = _selectedDateFilter == DateFilterOption.customDate;
    return ActionChip(
      avatar: Icon(
        Icons.event_rounded,
        size: 13,
        color: isSelected ? Colors.white : Colors.grey.shade700,
      ),
      label: Text(
        _customSingleDate != null ? SettingsProvider.formatDate(_customSingleDate!) : 'Custom Date',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey.shade800,
        ),
      ),
      backgroundColor: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
        ),
      ),
      onPressed: () => _pickCustomSingleDate(context),
    );
  }

  // ==========================================
  // FILTERS (ONLY RO AND ADMIN)
  // ==========================================
  Widget _buildRoAndAdminFilters({
    required List<RoAccount> allRos,
    required List<UserAuthRecord> adminUsers,
  }) {
    // Unique list of RO names
    final roNames = <String>{'All'};
    for (final r in allRos) {
      if (r.roName.trim().isNotEmpty) {
        roNames.add(r.roName.trim());
      }
    }

    // Unique list of Admin names (without 'All Admin Entries')
    final adminNames = <String>{'All'};
    for (final a in adminUsers) {
      if (a.name.trim().isNotEmpty) {
        adminNames.add(a.name.trim());
      }
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              // 1. RO Filter Dropdown
              Expanded(
                child: _buildFilterDropdown(
                  label: 'RO OFFICER',
                  value: _selectedRo,
                  items: roNames.toList(),
                  icon: Icons.badge_rounded,
                  onChanged: (val) {
                    setState(() {
                      _selectedRo = val ?? 'All';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),

              // 2. Admin Filter Dropdown
              Expanded(
                child: _buildFilterDropdown(
                  label: 'ADMINISTRATOR',
                  value: _selectedAdmin,
                  items: adminNames.toList(),
                  icon: Icons.admin_panel_settings_rounded,
                  onChanged: (val) {
                    setState(() {
                      _selectedAdmin = val ?? 'All';
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue = items.contains(value) ? value : items.first;
    final isCustomSelected = effectiveValue != 'All';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCustomSelected ? const Color(0xFF8B1A1A).withValues(alpha: 0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCustomSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
          width: isCustomSelected ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 11,
                color: isCustomSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isCustomSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              isDense: true,
              isExpanded: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCustomSelected ? FontWeight.bold : FontWeight.w600,
                color: isCustomSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade900,
              ),
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                size: 20,
                color: isCustomSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade600,
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BREAKDOWN SECTION (RO WISE / ROUTE WISE)
  // ==========================================
  Widget _buildBreakdownSection({
    required double totalCollected,
    required List<_RoSummaryItem> roSummaryList,
    required List<_RouteSummaryItem> routeSummaryList,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Performance Breakdown',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  Row(
                    children: [
                      _buildTabButton('RO Wise', 0),
                      const SizedBox(width: 6),
                      _buildTabButton('Route Wise', 1),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tab Content
            if (_activeSummaryTab == 0)
              _buildRoBreakdownList(roSummaryList, totalCollected)
            else
              _buildRouteBreakdownList(routeSummaryList, totalCollected),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int tabIndex) {
    final isSelected = _activeSummaryTab == tabIndex;
    return InkWell(
      onTap: () {
        setState(() {
          _activeSummaryTab = tabIndex;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildRoBreakdownList(List<_RoSummaryItem> list, double total) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
          child: Text('No RO collections in selected period', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 10),
      itemBuilder: (context, idx) {
        final item = list[idx];
        final pct = total > 0 ? (item.amount / total) : 0.0;

        return Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.shade50,
              child: Text(
                '${idx + 1}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        '${item.count} payments',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '₹ ${item.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRouteBreakdownList(List<_RouteSummaryItem> list, double total) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
          child: Text('No Route collections in selected period', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 10),
      itemBuilder: (context, idx) {
        final item = list[idx];
        final pct = total > 0 ? (item.amount / total) : 0.0;

        return Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.amber.shade50,
              child: Icon(Icons.alt_route_rounded, size: 14, color: Colors.amber.shade900),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.routeName,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        '${item.count} collections',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '₹ ${item.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // SORTING & COUNTER STRIP
  // ==========================================
  Widget _buildSortingAndCounterStrip(int resultsCount) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $resultsCount Payments',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          PopupMenuButton<SortOption>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            initialValue: _selectedSort,
            onSelected: (sort) {
              setState(() {
                _selectedSort = sort;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sort_rounded, size: 14, color: Color(0xFF8B1A1A)),
                  const SizedBox(width: 4),
                  Text(
                    _getSortLabel(_selectedSort),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, size: 15, color: Colors.grey),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.latestFirst,
                child: Text('Latest payment first (Default)', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem(
                value: SortOption.oldestFirst,
                child: Text('Oldest payment first', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem(
                value: SortOption.highestAmount,
                child: Text('Highest Amount (High to Low)', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem(
                value: SortOption.lowestAmount,
                child: Text('Lowest Amount (Low to High)', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem(
                value: SortOption.loaneeName,
                child: Text('Loanee Name (A-Z)', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem(
                value: SortOption.roOfficer,
                child: Text('RO Officer (A-Z)', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSortLabel(SortOption sort) {
    switch (sort) {
      case SortOption.latestFirst:
        return 'Latest First';
      case SortOption.oldestFirst:
        return 'Oldest First';
      case SortOption.highestAmount:
        return 'Highest ₹';
      case SortOption.lowestAmount:
        return 'Lowest ₹';
      case SortOption.loaneeName:
        return 'Loanee Name';
      case SortOption.roOfficer:
        return 'RO Officer';
    }
  }

  // ==========================================
  // PAYMENT CARD COMPONENT
  // ==========================================
  Widget _buildPaymentCard(
    BuildContext context,
    CollectionPaymentModel payment,
    RoCollectionEntry? card,
  ) {
    final loaneeName = card?.loaneeName ?? 'Loanee Account';
    final customerId = card?.customerId ?? 'N/A';
    final accountNo = card?.accountNumber ?? 'N/A';
    final route = (payment.roRoute != null && payment.roRoute!.isNotEmpty)
        ? payment.roRoute!
        : (card?.route ?? 'Office');
    final collector = payment.recordedByDisplayName;
    final formattedTime = _formatTime(payment.createdAt);
    final formattedDate = SettingsProvider.formatDate(payment.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.2,
      child: InkWell(
        onTap: () => _showPaymentReceiptSheet(context, payment, card),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Loanee Name & Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: payment.isAdminOrOfficeEntry
                        ? const Color(0xFF8B1A1A).withValues(alpha: 0.1)
                        : Colors.blue.shade50,
                    child: Icon(
                      payment.isAdminOrOfficeEntry
                          ? Icons.admin_panel_settings_rounded
                          : Icons.person_outline_rounded,
                      color: payment.isAdminOrOfficeEntry ? const Color(0xFF8B1A1A) : Colors.blue.shade800,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loaneeName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$accountNo • $customerId',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+ ₹ ${payment.paymentAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _getPaymentTypeColor(payment.paymentType).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          payment.paymentType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _getPaymentTypeColor(payment.paymentType),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 6),

              // Details Strip: RO/Admin, Route, Date & Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            collector,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.alt_route_rounded, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 3),
                      Text(
                        route,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        '$formattedDate $formattedTime',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPaymentTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return Colors.green.shade800;
      case 'gpay':
        return Colors.blue.shade800;
      case 'paytm':
        return Colors.cyan.shade900;
      case 'phonepay':
        return Colors.purple.shade800;
      default:
        return Colors.orange.shade800;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  // ==========================================
  // PAYMENT RECEIPT MODAL (ONLY LOANEE BASIC DETAILS)
  // ==========================================
  void _showPaymentReceiptSheet(
    BuildContext context,
    CollectionPaymentModel payment,
    RoCollectionEntry? card,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF8B1A1A), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Payment Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      payment.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Collected Amount Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Text('COLLECTED AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 2),
                    Text(
                      '₹ ${payment.paymentAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mode: ${payment.paymentType} • ${SettingsProvider.formatDate(payment.createdAt)} at ${_formatTime(payment.createdAt)}',
                      style: TextStyle(fontSize: 10.5, color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Loanee Basic Details Only
              const Text(
                'Loanee Basic Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              _buildReceiptRow('Loanee Name', card?.loaneeName ?? 'N/A'),
              _buildReceiptRow('Customer ID', card?.customerId ?? 'N/A'),
              _buildReceiptRow('Account Number', card?.accountNumber ?? 'N/A'),
              _buildReceiptRow('Phone Number', card?.mobileNo ?? 'N/A'),
              _buildReceiptRow('Route / Area', (card?.route != null && card!.route.isNotEmpty) ? card.route : (payment.roRoute ?? 'Office')),
              _buildReceiptRow('Collection Scheme', card?.collectionType ?? 'Standard'),
              _buildReceiptRow('Collected By', payment.recordedByDisplayName),
              if (payment.remainingBalance > 0)
                _buildReceiptRow('Remaining Balance', '₹ ${payment.remainingBalance.toStringAsFixed(2)}'),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1A1A),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  // ==========================================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'No Collection Records Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No payment records matched the selected date, RO, or Admin filters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (_hasCustomFiltersActive)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1A1A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: _resetAllFilters,
                icon: const Icon(Icons.restart_alt_rounded, size: 15),
                label: const Text('Reset All Filters', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

// Helper models for aggregations
class _RoSummaryItem {
  final String name;
  final int count;
  final double amount;

  _RoSummaryItem({
    required this.name,
    required this.count,
    required this.amount,
  });
}

class _RouteSummaryItem {
  final String routeName;
  final int count;
  final double amount;

  _RouteSummaryItem({
    required this.routeName,
    required this.count,
    required this.amount,
  });
}
