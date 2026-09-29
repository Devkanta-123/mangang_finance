// lib/screens/missing_manager_page.dart

import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/missing_payment_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/settings_provider.dart';

/// Missing Manager Page
///
/// Purpose:
/// - ONLY for viewing/checking missing-payment logs.
/// - NOT a payment screen.
/// - Visual reference: Collection Sheet UI.
class MissingManagerPage extends StatefulWidget {
  const MissingManagerPage({super.key});

  @override
  State<MissingManagerPage> createState() => _MissingManagerPageState();
}

class _MissingManagerPageState extends State<MissingManagerPage> {
  String? _selectedRoute;
  String _selectedType = 'All';
  String _searchQuery = '';
  bool _isTableView = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedRoute = null;
      _selectedType = 'All';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final collectionProvider =
        Provider.of<CollectionSheetProvider>(context);

    final settingsProvider = Provider.of<SettingsProvider>(context);

    final loaneeProvider = Provider.of<LoaneeProvider>(context);

    final authProvider = Provider.of<AuthProvider>(context);

    final bool isRo =
        authProvider.activeRole == UserType.ro ||
        authProvider.currentUser?.userType == UserType.ro;

    final List<String> availableRoutes = collectionProvider.routeNames;

    // ------------------------------------------------------------
    // Automatically select RO route.
    // ------------------------------------------------------------
    if (isRo && _selectedRoute == null) {
      final userRoute = authProvider.currentUser?.accountName;

      if (userRoute != null && availableRoutes.contains(userRoute)) {
        _selectedRoute = userRoute;
      } else if (availableRoutes.isNotEmpty) {
        _selectedRoute = availableRoutes.first;
      }
    }

    // ------------------------------------------------------------
    // FILTER ENTRIES
    // ------------------------------------------------------------
    List<RoCollectionEntry> filteredEntries =
        List<RoCollectionEntry>.from(
      collectionProvider.collectionEntries,
    );

    // Route filter.
    if (_selectedRoute != null &&
        _selectedRoute!.isNotEmpty &&
        _selectedRoute != 'All Routes') {
      final selectedRouteLower =
          _selectedRoute!.trim().toLowerCase();

      filteredEntries = filteredEntries.where((entry) {
        return entry.route.trim().toLowerCase() == selectedRouteLower;
      }).toList();
    }

    // Collection type filter.
    if (_selectedType != 'All') {
      final selectedType =
          _selectedType.toLowerCase().trim();

      if (selectedType == 'daily') {
        filteredEntries =
            filteredEntries.where((entry) => entry.isDaily).toList();
      } else if (selectedType == 'weekly') {
        filteredEntries =
            filteredEntries.where((entry) => !entry.isDaily).toList();
      } else if (selectedType == 'today') {
        final int todayWeekday = DateTime.now().weekday;

        const weekdayNames = [
          '',
          'mon',
          'tue',
          'wed',
          'thu',
          'fri',
          'sat',
          'sun',
        ];

        final String dayString =
            weekdayNames[todayWeekday];

        filteredEntries = filteredEntries.where((entry) {
          final collectionType =
              entry.collectionType.toLowerCase().trim();

          return collectionType == 'daily' ||
              collectionType == dayString ||
              collectionType == 'all';
        }).toList();
      } else {
        filteredEntries = filteredEntries.where((entry) {
          return entry.collectionType.toLowerCase().trim() ==
              selectedType;
        }).toList();
      }
    }

    // Search filter.
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();

      filteredEntries = filteredEntries.where((entry) {
        final matchName =
            entry.loaneeName.toLowerCase().contains(query);

        final matchCustomerId =
            entry.customerId.toLowerCase().contains(query);

        final matchAccount =
            entry.accountNumber.toLowerCase().contains(query);

        final matchMobile =
            entry.mobileNo.toLowerCase().contains(query);

        return matchName ||
            matchCustomerId ||
            matchAccount ||
            matchMobile;
      }).toList();
    }

    // ------------------------------------------------------------
    // SUMMARY
    // ------------------------------------------------------------
    int totalMissingLoanees = 0;
    double totalMissingAmount = 0.0;
    double totalMissingBalance = 0.0;

    for (final entry in filteredEntries) {
      final missingCount =
          collectionProvider.getTotalMissingCountForCollection(
        entry.id,
      );

      if (missingCount > 0) {
        totalMissingLoanees++;

        totalMissingAmount +=
            collectionProvider.getTotalMissingPayForCollection(
          entry.id,
        );

        totalMissingBalance +=
            collectionProvider.getTotalMissingBalanceForCollection(
          entry.id,
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: () async {
          await collectionProvider.fetchFromSupabase();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(
                collectionProvider,
                isRo,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRouteSelectionCardsSection(
                      collectionProvider,
                      availableRoutes,
                    ),

                    const SizedBox(height: 14),

                    if (_selectedRoute != null) ...[
                      _buildSelectedRouteHeader(),

                      const SizedBox(height: 10),

                      _buildCollectionTypeFilterCards(),

                      const SizedBox(height: 14),

                      _buildDataTableSection(
                        filteredEntries,
                        collectionProvider,
                        settingsProvider,
                        loaneeProvider,
                        totalMissingLoanees,
                        totalMissingAmount,
                        totalMissingBalance,
                      ),
                    ] else
                      _buildNoRouteSelectedState(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP HEADER
  // ============================================================

  Widget _buildTopHeader(
    CollectionSheetProvider provider,
    bool isRo,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1E1E1E),
            Color(0xFF2C2C2C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade800,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_late_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Missing Manager',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Route-mapped missing payment ledger & audit logs (MISSING ≠ PAYMENT)',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedRoute != null ||
                  _searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: Colors.amber,
                  ),
                  tooltip: 'Reset Filters',
                  onPressed: _resetFilters,
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
                    : const Icon(
                        Icons.sync_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                tooltip: 'Sync with Supabase',
                onPressed: () async {
                  await provider.fetchFromSupabase();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROUTE CARDS
  // ============================================================

  Widget _buildRouteSelectionCardsSection(
    CollectionSheetProvider provider,
    List<String> availableRoutes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.alt_route_rounded,
              size: 15,
              color: Color(0xFF8B1A1A),
            ),
            SizedBox(width: 5),
            Text(
              'ROUTE ZONES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Color(0xFF8B1A1A),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: availableRoutes.map((routeName) {
              final isSelected =
                  _selectedRoute == routeName;

              final entryCount = provider.collectionEntries
                  .where(
                    (entry) =>
                        entry.route.trim().toLowerCase() ==
                        routeName.trim().toLowerCase(),
                  )
                  .length;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedRoute = routeName;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B1A1A)
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B1A1A)
                            : Colors.grey.shade300,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: isSelected
                              ? Colors.amber
                              : Colors.grey.shade600,
                        ),

                        const SizedBox(width: 6),

                        Text(
                          routeName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade800,
                          ),
                        ),

                        const SizedBox(width: 6),

                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                    .withValues(alpha: 0.2)
                                : Colors.grey.shade200,
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$entryCount',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // SELECTED ROUTE HEADER
  // ============================================================

  Widget _buildSelectedRouteHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_city_rounded,
              size: 16,
              color: Color(0xFF8B1A1A),
            ),

            const SizedBox(width: 6),

            Text(
              'Route: ${_selectedRoute!}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B1A1A),
              ),
            ),
          ],
        ),

        Text(
          'Filter: $_selectedType',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COLLECTION TYPE FILTER
  // ============================================================

  Widget _buildCollectionTypeFilterCards() {
    final types = [
      'All',
      'Today',
      'Daily',
      'Weekly',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: types.map((type) {
        final isSelected =
            _selectedType == type;

        return ChoiceChip(
          label: Text(type),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedType = type;
              });
            }
          },
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: isSelected
                ? FontWeight.bold
                : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : Colors.grey.shade800,
          ),
          selectedColor:
              const Color(0xFF8B1A1A),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF8B1A1A)
                  : Colors.grey.shade300,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // NO ROUTE
  // ============================================================

  Widget _buildNoRouteSelectedState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.alt_route_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 12),

          Text(
            'Select a Route Zone to Load Missing Payment Logs',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          Text(
            'Click on any Route Zone card above to inspect loanee missing payments, fines, and balances.',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATA TABLE SECTION
  // ============================================================

  Widget _buildDataTableSection(
    List<RoCollectionEntry> entries,
    CollectionSheetProvider provider,
    SettingsProvider settingsProvider,
    LoaneeProvider loaneeProvider,
    int totalMissingLoanees,
    double totalMissingAmount,
    double totalMissingBalance,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search + view buttons.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText:
                      'Search loanee, ID, mobile, account...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                  ),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 16,
                              ),
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
                  contentPadding:
                      const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.table_rows_rounded,
                      size: 18,
                      color: _isTableView
                          ? const Color(0xFF8B1A1A)
                          : Colors.grey,
                    ),
                    tooltip: 'Table View',
                    onPressed: () {
                      setState(() {
                        _isTableView = true;
                      });
                    },
                  ),

                  IconButton(
                    icon: Icon(
                      Icons.view_agenda_rounded,
                      size: 18,
                      color: !_isTableView
                          ? const Color(0xFF8B1A1A)
                          : Colors.grey,
                    ),
                    tooltip: 'Cards View',
                    onPressed: () {
                      setState(() {
                        _isTableView = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Summary.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(10),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                'Showing ${entries.length} Records in ${_selectedRoute!} '
                '($totalMissingLoanees with Missing Logs)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius:
                          BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.orange.shade200,
                      ),
                    ),
                    child: Text(
                      'Total Missing: ₹${totalMissingAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius:
                          BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.red.shade200,
                      ),
                    ),
                    child: Text(
                      'Total Balance: ₹${totalMissingBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (entries.isEmpty)
          _buildEmptyEntriesState()
        else if (_isTableView)
          _buildDataTableWidget(
            entries,
            provider,
            settingsProvider,
            loaneeProvider,
          )
        else
          _buildCardsListWidget(
            entries,
            provider,
            settingsProvider,
            loaneeProvider,
          ),
      ],
    );
  }

  Widget _buildEmptyEntriesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 42,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 10),

          Text(
            'No Entries Found in $_selectedRoute ($_selectedType)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 4),

          Text(
            'Try clearing search filters or changing collection type.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN TABLE
  //
  // IMPORTANT:
  // Every column has a fixed width.
  // The table itself has a fixed minimum width.
  // No FlexColumnWidth is used.
  // ============================================================

  Widget _buildDataTableWidget(
    List<RoCollectionEntry> entries,
    CollectionSheetProvider provider,
    SettingsProvider settingsProvider,
    LoaneeProvider loaneeProvider,
  ) {
    const double tableWidth = 1020;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ExcludeSemantics(
            child: SizedBox(
              width: tableWidth,
              child: Table(
              defaultVerticalAlignment:
                  TableCellVerticalAlignment.middle,

              // FIX:
              // Do NOT use FlexColumnWidth here.
              // Every column gets a deterministic width.
              columnWidths: const {
                0: FixedColumnWidth(45),
                1: FixedColumnWidth(160),
                2: FixedColumnWidth(105),
                3: FixedColumnWidth(115),
                4: FixedColumnWidth(80),
                5: FixedColumnWidth(105),
                6: FixedColumnWidth(100),
                7: FixedColumnWidth(105),
                8: FixedColumnWidth(105),
                9: FixedColumnWidth(100),
              },

              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B1A1A),
                  ),
                  children: [
                    _dataHeaderCell('#'),
                    _dataHeaderCell('Loanee Name'),
                    _dataHeaderCell('Customer ID'),
                    _dataHeaderCell('Account No'),
                    _dataHeaderCell('Type'),
                    _dataHeaderCell('Total Paid'),
                    _dataHeaderCell('Missing Count'),
                    _dataHeaderCell('Missing Amount'),
                    _dataHeaderCell('Missing Balance'),
                    _dataHeaderCell('Action'),
                  ],
                ),

                ...entries.asMap().entries.map(
                  (mapEntry) {
                    final int index =
                        mapEntry.key + 1;

                    final entry =
                        mapEntry.value;

                    final int missingCount =
                        provider
                            .getTotalMissingCountForCollection(
                      entry.id,
                    );

                    final double missingAmount =
                        provider
                            .getTotalMissingPayForCollection(
                      entry.id,
                    );

                    final double missingBalance =
                        provider
                            .getTotalMissingBalanceForCollection(
                      entry.id,
                    );

                    final double totalPaid =
                        provider
                            .getTotalPaidForCollection(
                      entry.id,
                    );

                    return TableRow(
                      decoration: BoxDecoration(
                        color: index.isEven
                            ? Colors.white
                            : Colors.grey.shade50,
                      ),
                      children: [
                        _dataBodyCell(
                          Text(
                            '$index',
                            style: const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        ),

                        _dataBodyCell(
                          InkWell(
                            onTap: () =>
                                _openMissingDetails(
                              entry,
                            ),
                            child: Text(
                              entry.loaneeName,
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Color(0xFF8B1A1A),
                              ),
                            ),
                          ),
                        ),

                        _dataBodyCell(
                          Text(
                            entry.customerId,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        ),

                        _dataBodyCell(
                          Text(
                            entry.accountNumber,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        ),

                        _dataBodyCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: entry.isDaily
                                      ? Colors.blue.shade50
                                      : Colors
                                          .purple.shade50,
                                  borderRadius:
                                      BorderRadius
                                          .circular(4),
                                ),
                                child: Text(
                                  entry.isDaily
                                      ? 'Daily'
                                      : 'Weekly',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.bold,
                                    color: entry.isDaily
                                        ? Colors.blue
                                            .shade800
                                        : Colors.purple
                                            .shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        _dataBodyCell(
                          Text(
                            '₹ ${totalPaid.toStringAsFixed(2)}',
                            style:
                                const TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                        _dataBodyCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: missingCount >
                                          0
                                      ? Colors.red.shade50
                                      : Colors.green
                                          .shade50,
                                  borderRadius:
                                      BorderRadius
                                          .circular(4),
                                ),
                                child: Text(
                                  '$missingCount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        missingCount >
                                                0
                                            ? Colors.red
                                                .shade800
                                            : Colors.green
                                                .shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        _dataBodyCell(
                          Text(
                            missingAmount > 0
                                ? '₹ ${missingAmount.toStringAsFixed(2)}'
                                : '—',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  missingAmount >
                                          0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color:
                                  missingAmount >
                                          0
                                      ? Colors.orange
                                          .shade900
                                      : Colors.grey
                                          .shade600,
                            ),
                          ),
                        ),

                        _dataBodyCell(
                          Text(
                            missingBalance > 0
                                ? '₹ ${missingBalance.toStringAsFixed(2)}'
                                : '—',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  missingBalance >
                                          0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color:
                                  missingBalance >
                                          0
                                      ? Colors.red
                                          .shade900
                                      : Colors.grey
                                          .shade600,
                            ),
                          ),
                        ),

                        _dataBodyCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 30,
                                child:
                                    ElevatedButton.icon(
                                  onPressed: () =>
                                      _openMissingDetails(
                                    entry,
                                  ),
                                  icon: const Icon(
                                    Icons
                                        .receipt_long_rounded,
                                    size: 12,
                                  ),
                                  label: const Text(
                                    'View Log',
                                    style:
                                        TextStyle(
                                      fontSize: 10,
                                    ),
                                  ),
                                  style:
                                      ElevatedButton
                                          .styleFrom(
                                    backgroundColor:
                                        const Color(
                                      0xFF8B1A1A,
                                    ),
                                    foregroundColor:
                                        Colors.white,
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize:
                                        const Size(
                                      60,
                                      28,
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        6,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _dataHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _dataBodyCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      child: child,
    );
  }

  // ============================================================
  // CARDS VIEW
  //
  // IMPORTANT:
  // No ListView inside the parent SingleChildScrollView.
  // We use a Column instead.
  // ============================================================

  Widget _buildCardsListWidget(
    List<RoCollectionEntry> entries,
    CollectionSheetProvider provider,
    SettingsProvider settingsProvider,
    LoaneeProvider loaneeProvider,
  ) {
    return Column(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          _buildSingleEntryCard(
            entries[i],
            provider,
          ),

          if (i != entries.length - 1)
            const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildSingleEntryCard(
    RoCollectionEntry entry,
    CollectionSheetProvider provider,
  ) {
    final missingCount =
        provider.getTotalMissingCountForCollection(
      entry.id,
    );

    final missingAmount =
        provider.getTotalMissingPayForCollection(
      entry.id,
    );

    final missingBalance =
        provider.getTotalMissingBalanceForCollection(
      entry.id,
    );

    final totalPaid =
        provider.getTotalPaidForCollection(
      entry.id,
    );

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.loaneeName,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              Color(0xFF8B1A1A),
                        ),
                      ),

                      Text(
                        'Cust ID: ${entry.customerId} • A/C: ${entry.accountNumber}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: entry.isDaily
                        ? Colors.blue.shade50
                        : Colors.purple.shade50,
                    borderRadius:
                        BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.isDaily
                        ? 'Daily'
                        : 'Weekly',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                      color: entry.isDaily
                          ? Colors.blue.shade800
                          : Colors.purple.shade800,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 16),

            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildStatPill(
                  'Total Paid',
                  '₹ ${totalPaid.toStringAsFixed(0)}',
                  Colors.green.shade800,
                ),
                _buildStatPill(
                  'Missing Count',
                  '$missingCount',
                  missingCount > 0
                      ? Colors.red.shade800
                      : Colors.grey.shade700,
                ),
                _buildStatPill(
                  'Missing Pay',
                  '₹ ${missingAmount.toStringAsFixed(0)}',
                  Colors.orange.shade900,
                ),
                _buildStatPill(
                  'Missing Balance',
                  '₹ ${missingBalance.toStringAsFixed(1)}',
                  Colors.red.shade900,
                ),
              ],
            ),

            const SizedBox(height: 10),

            Align(
              alignment:
                  Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _openMissingDetails(entry),
                icon: const Icon(
                  Icons.receipt_long_rounded,
                  size: 14,
                ),
                label: const Text(
                  'View Missing Log',
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF8B1A1A),
                  foregroundColor:
                      Colors.white,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: Colors.grey.shade600,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OPEN MISSING DETAILS
  // ============================================================

  Future<void> _openMissingDetails(
    RoCollectionEntry entry,
  ) async {
    await _MissingDetailsDialog.show(
      context,
      entry,
    );
  }
}

// ============================================================================
// MISSING DETAILS DIALOG (Payment History Modal style with pagination)
// ============================================================================

class _MissingDetailsDialog extends StatefulWidget {
  final RoCollectionEntry entry;
  final CollectionSheetProvider collectionProvider;
  final LoaneeProvider? loaneeProvider;

  const _MissingDetailsDialog({
    required this.entry,
    required this.collectionProvider,
    this.loaneeProvider,
  });

  static Future<void> show(
    BuildContext context,
    RoCollectionEntry entry,
  ) async {
    final collectionProvider =
        Provider.of<CollectionSheetProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    LoaneeProvider? loaneeProvider;
    try {
      loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
    } catch (_) {}

    try {
      final loanee = loaneeProvider?.getLoaneeForUser(
        customerId: entry.customerId,
        mobileNo: entry.mobileNo,
        name: entry.loaneeName,
      );

      final effectiveLoanAmount =
          (entry.loanAmount != null && entry.loanAmount! > 0)
              ? entry.loanAmount!
              : ((loanee != null && loanee.loanAmount > 0)
                  ? loanee.loanAmount
                  : (entry.actualPrincipal ?? entry.initialBalance));

      await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        loaneeLoanAmount: effectiveLoanAmount,
        loaneeProvider: loaneeProvider,
        sanctionDate: loanee?.loanSanctionDate,
      );
    } catch (_) {}

    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      builder: (ctx) => _MissingDetailsDialog(
        entry: entry,
        collectionProvider: collectionProvider,
        loaneeProvider: loaneeProvider,
      ),
    );
  }

  @override
  State<_MissingDetailsDialog> createState() => _MissingDetailsDialogState();
}

class _MissingDetailsDialogState extends State<_MissingDetailsDialog> {
  int _page = 1;
  final int _pageSize = 5;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    widget.collectionProvider.addListener(_onProviderChange);
  }

  @override
  void dispose() {
    widget.collectionProvider.removeListener(_onProviderChange);
    super.dispose();
  }

  void _onProviderChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final cp = widget.collectionProvider;
    final missingRecords = cp.getMissingRecordsForCollection(entry.id);
    final totalPayment = cp.getTotalPaidForCollection(entry.id);
    final totalCount = missingRecords.length;

    final totalMissingAmount = missingRecords
        .where((record) => !record.isResolved)
        .fold<double>(
      0.0,
      (sum, record) => sum + record.missingPay,
    );

    final totalMissingBalance = missingRecords.fold<double>(
      0.0,
      (sum, record) => sum + record.missingBalance,
    );

    final loanee = widget.loaneeProvider?.getLoaneeForUser(
      customerId: entry.customerId,
      mobileNo: entry.mobileNo,
      name: entry.loaneeName,
    );

    final totalLateFees = cp.getTotalLatePaymentFeesForCollection(entry.id);
    final totalPostMat = cp.getTotalPostMaturityInterestForCollection(entry.id);
    final totalInt = cp.getTotalInterestForCollection(entry.id);
    final totalOverdueInterest = totalLateFees + totalPostMat;
    final effectiveInt = totalOverdueInterest > 0 ? totalOverdueInterest : totalInt;
    final loanAmt = (entry.loanAmount != null && entry.loanAmount! > 0)
        ? entry.loanAmount!
        : ((loanee != null && loanee.loanAmount > 0)
            ? loanee.loanAmount
            : (entry.actualPrincipal ?? entry.initialBalance));
    final remaining = (loanAmt + effectiveInt - totalPayment).clamp(0.0, double.infinity);

    // Pagination calculations
    final int totalPages = totalCount == 0 ? 1 : ((totalCount + _pageSize - 1) ~/ _pageSize);
    if (_page > totalPages && totalPages > 0) {
      _page = totalPages;
    }
    final int startIndex = (_page - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize).clamp(0, totalCount);
    final pagedRecords = (startIndex < totalCount)
        ? missingRecords.sublist(startIndex, endIndex)
        : <MissingPaymentRecord>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.history_edu_rounded,
                          color: Color(0xFF8B1A1A),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${entry.loaneeName} - Missing Payment Log",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E1E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Account: ${entry.accountNumber} • ID: ${entry.customerId} • Route: ${entry.route} (${entry.isDaily ? 'Daily' : 'Weekly'})",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: (_isExporting || missingRecords.isEmpty)
                            ? null
                            : () => _exportToExcel(
                                  entry: entry,
                                  records: missingRecords,
                                  totalPayment: totalPayment,
                                  totalMissing: totalCount,
                                  totalMissingAmount: totalMissingAmount,
                                  totalMissingBalance: totalMissingBalance,
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E7E34),
                          side: const BorderSide(color: Color(0xFF1E7E34)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isExporting
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1E7E34),
                                ),
                              )
                            : const Icon(Icons.table_view_rounded, size: 15, color: Color(0xFF1E7E34)),
                        label: Text(
                          _isExporting ? "Exporting..." : "Excel Export",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E7E34),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Loan Metrics Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildMetricItem(
                      label: "Loan Amount",
                      value: "₹ ${loanAmt.toStringAsFixed(0)}",
                    ),
                    _buildMetricItem(
                      label: "Sanction Date",
                      value: loanee?.formattedSanctionDate ?? "N/A",
                    ),
                    _buildMetricItem(
                      label: "Mobile No.",
                      value: entry.mobileNo.isNotEmpty ? entry.mobileNo : "—",
                    ),
                    _buildMetricItem(
                      label: "Total Missing",
                      value: "$totalCount",
                      valueColor: const Color(0xFF8B1A1A),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Payment History & Breakdown Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B1A1A).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8B1A1A).withValues(alpha: 0.15)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildMetricItem(
                      label: "Total Paid",
                      value: "₹${totalPayment.toStringAsFixed(2)}",
                      valueColor: Colors.green.shade800,
                    ),
                    _buildMetricItem(
                      label: "Total Missing Pay",
                      value: "₹${totalMissingAmount.toStringAsFixed(2)}",
                      valueColor: Colors.orange.shade900,
                    ),
                    _buildMetricItem(
                      label: "Total Missing Balance",
                      value: "₹${totalMissingBalance.toStringAsFixed(2)}",
                      valueColor: Colors.red.shade900,
                    ),
                    _buildMetricItem(
                      label: "Remaining Loan",
                      value: "₹${remaining.toStringAsFixed(2)}",
                      valueColor: remaining > 0 ? Colors.red.shade900 : Colors.green.shade800,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Payments Table
              if (missingRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded,
                          size: 38, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        "No missing payment records recorded for this loan yet.",
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 780),
                        child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(const Color(0xFF8B1A1A)),
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        dataRowMaxHeight: 52,
                        dataRowMinHeight: 40,
                        columnSpacing: 14,
                        horizontalMargin: 12,
                        columns: const [
                          DataColumn(label: Text("Date")),
                          DataColumn(label: Text("Paid Date")),
                          DataColumn(label: Text("Day Payment")),
                          DataColumn(label: Text("Missing Pay")),
                          DataColumn(label: Text("Missing Fine")),
                          DataColumn(label: Text("Missing Week")),
                          DataColumn(label: Text("Missing Balance")),
                          DataColumn(label: Text("Status")),
                        ],
                        rows: pagedRecords.asMap().entries.map((mapEntry) {
                          final int idx = mapEntry.key;
                          final m = mapEntry.value;
                          final dateString =
                              '${m.missedDate.day.toString().padLeft(2, '0')}-'
                              '${m.missedDate.month.toString().padLeft(2, '0')}-'
                              '${m.missedDate.year}';
                          final dayPayString = m.dayPayment > 0
                              ? '₹ ${m.dayPayment.toStringAsFixed(2)}'
                              : '—';
                          final isResolved = m.isResolved;
                          final isPartial = m.isPartial;

                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>((states) {
                              return idx.isEven ? Colors.white : Colors.grey.shade50;
                            }),
                            cells: [
                              DataCell(Text(
                                dateString,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                              DataCell(
                                m.paidDate != null
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.green.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_rounded, size: 10, color: Colors.green.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${m.paidDate!.day.toString().padLeft(2, '0')}-${m.paidDate!.month.toString().padLeft(2, '0')}-${m.paidDate!.year}',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Text(
                                        '—',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade400,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              DataCell(Text(
                                dayPayString,
                                style: const TextStyle(fontSize: 11),
                              )),
                              DataCell(Text(
                                '₹ ${m.missingPay.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              )),
                              DataCell(Text(
                                '₹ ${m.missingFine.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11),
                              )),
                              DataCell(Text(
                                '${m.missingWeek}',
                                style: const TextStyle(fontSize: 11),
                              )),
                              DataCell(Text(
                                '₹ ${m.missingBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              )),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isResolved
                                        ? Colors.green.shade50
                                        : (isPartial
                                            ? Colors.amber.shade50
                                            : Colors.red.shade50),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isResolved
                                          ? Colors.green.shade300
                                          : (isPartial
                                              ? Colors.amber.shade300
                                              : Colors.red.shade300),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isResolved
                                            ? Icons.check_circle_rounded
                                            : (isPartial
                                                ? Icons.hourglass_bottom_rounded
                                                : (m.isPaused ? Icons.pause_circle_rounded : Icons.pending_actions_rounded)),
                                        size: 11,
                                        color: isResolved
                                            ? Colors.green.shade700
                                            : (isPartial
                                                ? Colors.amber.shade900
                                                : (m.isPaused ? Colors.blue.shade700 : Colors.red.shade700)),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isResolved
                                            ? "PAID"
                                            : (isPartial
                                                ? "PARTIAL PAID"
                                                : (m.isPaused ? "PAUSED" : "MISSING")),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isResolved
                                              ? Colors.green.shade800
                                              : (isPartial
                                                  ? Colors.amber.shade900
                                                  : (m.isPaused ? Colors.blue.shade900 : Colors.red.shade800)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Pagination Controls: [Previous] Page X of Y (N records) [Next]
              if (totalPages > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _page > 1
                            ? const Color(0xFF8B1A1A)
                            : Colors.grey.shade300,
                        foregroundColor: _page > 1
                            ? Colors.white
                            : Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: _page > 1
                          ? () => setState(() => _page--)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded, size: 16),
                      label: const Text(
                        "Previous",
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      "Page $_page of $totalPages ($totalCount records)",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _page < totalPages
                            ? const Color(0xFF8B1A1A)
                            : Colors.grey.shade300,
                        foregroundColor: _page < totalPages
                            ? Colors.white
                            : Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: _page < totalPages
                          ? () => setState(() => _page++)
                          : null,
                      label: const Text(
                        "Next",
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      icon: const Icon(Icons.chevron_right_rounded, size: 16),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXPORT TO EXCEL
  // ============================================================

  Future<void> _exportToExcel({
    required RoCollectionEntry entry,
    required List<MissingPaymentRecord>
        records,
    required double totalPayment,
    required int totalMissing,
    required double totalMissingAmount,
    required double totalMissingBalance,
  }) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final excel =
          xl.Excel.createExcel();

      final sheet =
          excel['Missing Payment Details'];

      excel.setDefaultSheet(
        'Missing Payment Details',
      );

      // ----------------------------------------------------------
      // HEADER INFORMATION
      // ----------------------------------------------------------

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'A1',
            ),
          )
          .value = xl.TextCellValue(
        'Customer ID',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'B1',
            ),
          )
          .value = xl.TextCellValue(
        entry.customerId,
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'A2',
            ),
          )
          .value = xl.TextCellValue(
        'Account No.',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'B2',
            ),
          )
          .value = xl.TextCellValue(
        entry.accountNumber,
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'A3',
            ),
          )
          .value = xl.TextCellValue(
        'Mobile No.',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'B3',
            ),
          )
          .value = xl.TextCellValue(
        entry.mobileNo,
      );

      // ----------------------------------------------------------
      // SUMMARY
      // ----------------------------------------------------------

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'B4',
            ),
          )
          .value = xl.TextCellValue(
        'Total Payment',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'C4',
            ),
          )
          .value = xl.TextCellValue(
        'Total Missing',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'D4',
            ),
          )
          .value = xl.TextCellValue(
        'Total Missing Amount',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'E4',
            ),
          )
          .value = xl.TextCellValue(
        'Total Missing Balance',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'B5',
            ),
          )
          .value = xl.DoubleCellValue(
        totalPayment,
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'C5',
            ),
          )
          .value = xl.IntCellValue(
        totalMissing,
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'D5',
            ),
          )
          .value = xl.DoubleCellValue(
        totalMissingAmount,
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'E5',
            ),
          )
          .value = xl.DoubleCellValue(
        totalMissingBalance,
      );

      // ----------------------------------------------------------
      // DETAIL TABLE HEADER
      // ----------------------------------------------------------

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'A7',
            ),
          )
          .value = xl.TextCellValue(
        'Date',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'B7',
            ),
          )
          .value = xl.TextCellValue(
        'Paid Date',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'C7',
            ),
          )
          .value = xl.TextCellValue(
        'Day Payment',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'D7',
            ),
          )
          .value = xl.TextCellValue(
        'Missing Pay',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'E7',
            ),
          )
          .value = xl.TextCellValue(
        'Missing Fine',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'F7',
            ),
          )
          .value = xl.TextCellValue(
        'Missing Week',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'G7',
            ),
          )
          .value = xl.TextCellValue(
        'Missing Balance',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'H7',
            ),
          )
          .value = xl.TextCellValue(
        'Status',
      );

      // ----------------------------------------------------------
      // DETAIL ROWS
      // ----------------------------------------------------------

      int rowIndex = 8;

      for (final record in records) {
        final dateString =
            '${record.missedDate.day.toString().padLeft(2, '0')}-'
            '${record.missedDate.month.toString().padLeft(2, '0')}-'
            '${record.missedDate.year}';
        final paidDateStr = record.paidDate != null
            ? '${record.paidDate!.day.toString().padLeft(2, '0')}-${record.paidDate!.month.toString().padLeft(2, '0')}-${record.paidDate!.year}'
            : '—';
        final statusLabel = record.isResolved
            ? 'PAID'
            : (record.isPartial ? 'PARTIAL PAID' : (record.isPaused ? 'PAUSED' : 'MISSING'));

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'A$rowIndex',
              ),
            )
            .value = xl.TextCellValue(
          dateString,
        );

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'B$rowIndex',
              ),
            )
            .value = xl.TextCellValue(
          paidDateStr,
        );

        if (record.dayPayment > 0) {
          sheet
              .cell(
                xl.CellIndex.indexByString(
                  'C$rowIndex',
                ),
              )
              .value =
              xl.DoubleCellValue(
            record.dayPayment,
          );
        } else {
          sheet
              .cell(
                xl.CellIndex.indexByString(
                  'C$rowIndex',
                ),
              )
              .value = xl.TextCellValue(
            '—',
          );
        }

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'D$rowIndex',
              ),
            )
            .value = xl.DoubleCellValue(
          record.missingPay,
        );

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'E$rowIndex',
              ),
            )
            .value = xl.DoubleCellValue(
          record.missingFine,
        );

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'F$rowIndex',
              ),
            )
            .value = xl.IntCellValue(
          record.missingWeek,
        );

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'G$rowIndex',
              ),
            )
            .value = xl.DoubleCellValue(
          record.missingBalance,
        );

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'H$rowIndex',
              ),
            )
            .value = xl.TextCellValue(
          statusLabel,
        );

        rowIndex++;
      }

      // ----------------------------------------------------------
      // SAVE + SHARE
      // ----------------------------------------------------------

      final fileBytes = excel.save();

      if (fileBytes != null) {
        final tempDirectory =
            await getTemporaryDirectory();

        final fileName =
            'Missing_Log_${entry.accountNumber}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        final file = File(
          '${tempDirectory.path}/$fileName',
        );

        await file.writeAsBytes(
          fileBytes,
        );

        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              'Mangang Finance - Missing Log for '
              '${entry.loaneeName} '
              '(${entry.accountNumber})',
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Error exporting missing log: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}