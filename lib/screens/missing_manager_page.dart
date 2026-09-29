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
import '../widgets/missing_records_excel_upload_dialog.dart';

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
  String _dateSortOrder = 'none'; // 'none', 'desc', 'asc'
  final Set<String> _runningAutoEntryIds = {};

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
      _dateSortOrder = 'none';
    });
  }

  bool _hasPastMissingRecords(
    CollectionSheetProvider provider,
    RoCollectionEntry entry,
  ) {
    if (provider.isMissingAutomationAuthorized(
      entry.id,
      entry.accountNumber,
      entry.customerId,
    )) {
      return true;
    }
    final records = provider.getMissingRecordsForCollection(entry.id);
    return records.any((m) {
      final src = m.source.toLowerCase().trim();
      if (src == 'excel_import' ||
          src == 'excel' ||
          src == 'past' ||
          src == 'excel_upload') {
        return true;
      }
      final rem = (m.remarks ?? '').toLowerCase();
      return rem.contains('excel') ||
          rem.contains('imported') ||
          rem.contains('historical') ||
          rem.contains('past');
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

    // Date sorting for entries list
    if (_dateSortOrder == 'desc') {
      filteredEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_dateSortOrder == 'asc') {
      filteredEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
                icon: const Icon(
                  Icons.upload_file_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                tooltip: 'Upload Missing Old Records (Excel)',
                onPressed: () async {
                  final imported =
                      await MissingRecordsExcelUploadDialog.pickAndShow(context);
                  if (imported == true && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() {});
                    });
                  }
                },
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

                  Container(
                    height: 20,
                    width: 1,
                    color: Colors.grey.shade300,
                  ),

                  IconButton(
                    icon: Icon(
                      _dateSortOrder == 'asc'
                          ? Icons.arrow_upward_rounded
                          : (_dateSortOrder == 'desc'
                              ? Icons.arrow_downward_rounded
                              : Icons.sort_rounded),
                      size: 18,
                      color: _dateSortOrder != 'none'
                          ? const Color(0xFF8B1A1A)
                          : Colors.grey,
                    ),
                    tooltip: _dateSortOrder == 'asc'
                        ? 'Date: Ascending (Oldest First)'
                        : (_dateSortOrder == 'desc'
                            ? 'Date: Descending (Newest First)'
                            : 'Sort by Date'),
                    onPressed: () {
                      setState(() {
                        if (_dateSortOrder == 'none') {
                          _dateSortOrder = 'desc';
                        } else if (_dateSortOrder == 'desc') {
                          _dateSortOrder = 'asc';
                        } else {
                          _dateSortOrder = 'none';
                        }
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
    const double tableWidth = 1135;

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
                9: FixedColumnWidth(215),
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

                    final bool isRunningAuto =
                        _runningAutoEntryIds.contains(entry.id);

                    final bool hasPastData =
                        _hasPastMissingRecords(provider, entry);

                    final bool canStartAuto = hasPastData && !isRunningAuto;

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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
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
                                if (provider.isMissingAutomationAuthorized(entry.id)) ...[
                                  const SizedBox(width: 4),
                                  const Tooltip(
                                    message: 'Excel Uploaded - Automation Active',
                                    child: Icon(
                                      Icons.bolt_rounded,
                                      size: 13,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ],
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

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 28,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openMissingDetails(entry),
                                    icon: const Icon(
                                      Icons.receipt_long_rounded,
                                      size: 12,
                                    ),
                                    label: const Text(
                                      'View Log',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B1A1A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      minimumSize: const Size(0, 28),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  height: 28,
                                  child: Tooltip(
                                    message: !hasPastData
                                        ? 'System Auto disabled: Past missing records (Excel) must exist first'
                                        : (isRunningAuto
                                            ? 'Syncing...'
                                            : 'Start Auto'),
                                    child: ElevatedButton.icon(
                                      onPressed: canStartAuto
                                          ? () => _handleStartSystemAuto(entry)
                                          : null,
                                      icon: isRunningAuto
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              Icons.bolt_rounded,
                                              size: 13,
                                              color: canStartAuto
                                                  ? Colors.white
                                                  : Colors.grey.shade600,
                                            ),
                                      label: Text(
                                        isRunningAuto
                                            ? 'Syncing...'
                                            : 'Start Auto',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: canStartAuto
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: canStartAuto
                                            ? const Color(0xFF1E7E34)
                                            : Colors.grey.shade300,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            Colors.grey.shade300,
                                        disabledForegroundColor:
                                            Colors.grey.shade600,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        minimumSize: const Size(0, 28),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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

    final bool hasPastData = _hasPastMissingRecords(provider, entry);
    final bool isRunningAuto = _runningAutoEntryIds.contains(entry.id);
    final bool canStartAuto = hasPastData && !isRunningAuto;

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
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    height: 32,
                    child: Tooltip(
                      message: !hasPastData
                          ? 'System Auto disabled: Past missing records (Excel) must exist first'
                          : (isRunningAuto ? 'Syncing...' : 'Start Auto'),
                      child: ElevatedButton.icon(
                        onPressed: canStartAuto
                            ? () => _handleStartSystemAuto(entry)
                            : null,
                        icon: isRunningAuto
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.bolt_rounded,
                                size: 14,
                                color: canStartAuto
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                        label: Text(
                          isRunningAuto ? 'Syncing...' : 'Start Auto',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: canStartAuto
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canStartAuto
                              ? const Color(0xFF1E7E34)
                              : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () => _openMissingDetails(entry),
                      icon: const Icon(
                        Icons.receipt_long_rounded,
                        size: 14,
                      ),
                      label: const Text(
                        'View Missing Log',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B1A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
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

  Future<void> _handleStartSystemAuto(RoCollectionEntry entry) async {
    if (_runningAutoEntryIds.contains(entry.id)) return;

    final collectionProvider =
        Provider.of<CollectionSheetProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    LoaneeProvider? loaneeProvider;
    try {
      loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
    } catch (_) {}

    final isAuthorized = collectionProvider.isMissingAutomationAuthorized(
      entry.id,
      entry.accountNumber,
      entry.customerId,
    );

    if (!isAuthorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please upload historical missing records Excel from the top header first for ${entry.loaneeName}.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _runningAutoEntryIds.add(entry.id);
    });

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

      final newRecords = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        loaneeLoanAmount: effectiveLoanAmount,
        loaneeProvider: loaneeProvider,
        sanctionDate: loanee?.loanSanctionDate,
        saveToRemote: true,
        forceAuthorize: true,
      );

      final skippedDups = collectionProvider.getLastAutoSkippedDuplicateDates(entry.id);
      if (mounted) {
        String dupMsg = '';
        if (skippedDups.isNotEmpty) {
          final dupFormatted = skippedDups.map((d) => SettingsProvider.formatDate(d)).join(', ');
          dupMsg = ' Skipped duplicate date(s): $dupFormatted.';
        }

        if (newRecords.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'System auto complete: ${newRecords.length} new missing date record(s) inserted for ${entry.loaneeName}.$dupMsg',
              ),
              backgroundColor: Colors.green.shade800,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'System auto complete: Missing records for ${entry.loaneeName} are up to date.$dupMsg',
              ),
              backgroundColor: Colors.blue.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error running system auto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _runningAutoEntryIds.remove(entry.id);
        });
      }
    }
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
    LoaneeProvider? loaneeProvider;
    try {
      loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
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
  bool _isRunningAuto = false;
  bool _sortAscending = true; // true = asc (oldest first), false = desc (newest first)
  String _sourceFilter = 'All'; // 'All', 'excel', 'system', 'collection'

  bool _isExcelUpload(MissingPaymentRecord record) {
    final src = record.source.toLowerCase().trim();
    if (src == 'excel_import' || src == 'excel' || src == 'excel_upload') return true;
    final rem = (record.remarks ?? '').toLowerCase();
    return rem.contains('excel');
  }

  bool _isSystemAuto(MissingPaymentRecord record) {
    final src = record.source.toLowerCase().trim();
    if (src == 'system' || src == 'system_auto' || src == 'auto') return true;
    final rem = (record.remarks ?? '').toLowerCase();
    return rem.contains('auto assessed') ||
        rem.contains('system') ||
        rem.contains('paused by admin');
  }

  Widget _buildSourceBadge(MissingPaymentRecord record) {
    final bool isExcel = _isExcelUpload(record);
    final bool isAuto = _isSystemAuto(record);

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String label;

    if (isExcel) {
      bgColor = Colors.teal.shade50;
      borderColor = Colors.teal.shade300;
      textColor = Colors.teal.shade800;
      icon = Icons.upload_file_rounded;
      label = 'Excel Upload';
    } else if (isAuto) {
      bgColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade300;
      textColor = Colors.blue.shade800;
      icon = Icons.bolt_rounded;
      label = 'System Auto';
    } else {
      bgColor = Colors.purple.shade50;
      borderColor = Colors.purple.shade300;
      textColor = Colors.purple.shade800;
      icon = Icons.receipt_long_rounded;
      label = 'Collection';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? const Color(0xFF8B1A1A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : activeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeColor : activeColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 11,
                color: isSelected ? Colors.white : activeColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _runSystemAutoInDialog() async {
    if (_isRunningAuto) return;

    final entry = widget.entry;
    final collectionProvider = widget.collectionProvider;
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final loaneeProvider = widget.loaneeProvider;

    final isAuthorized = collectionProvider.isMissingAutomationAuthorized(
      entry.id,
      entry.accountNumber,
      entry.customerId,
    );

    if (!isAuthorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please upload historical missing records Excel from the top header first for ${entry.loaneeName}.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _isRunningAuto = true;
    });

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

      final newRecords = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        loaneeLoanAmount: effectiveLoanAmount,
        loaneeProvider: loaneeProvider,
        sanctionDate: loanee?.loanSanctionDate,
        saveToRemote: true,
        forceAuthorize: true,
      );

      final skippedDups = widget.collectionProvider.getLastAutoSkippedDuplicateDates(entry.id);
      if (mounted) {
        String dupMsg = '';
        if (skippedDups.isNotEmpty) {
          final dupFormatted = skippedDups.map((d) => SettingsProvider.formatDate(d)).join(', ');
          dupMsg = ' Skipped duplicate date(s): $dupFormatted.';
        }

        if (newRecords.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'System auto complete: ${newRecords.length} new missing date record(s) inserted.$dupMsg',
              ),
              backgroundColor: Colors.green.shade800,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'System auto check complete: Missing records are up to date.$dupMsg',
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error running system auto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunningAuto = false;
        });
      }
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
        .where((record) => !record.isResolved && record.paidDate == null)
        .fold<double>(
      0.0,
      (sum, record) => sum + (record.missingPay > 0 ? record.missingPay : record.dayPayment),
    );

    final totalMissingBalance = missingRecords
        .where((record) => !record.isResolved && record.paidDate == null)
        .fold<double>(
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

    // Origin breakdown counts
    final int excelCount = missingRecords.where(_isExcelUpload).length;
    final int systemCount = missingRecords.where(_isSystemAuto).length;
    final int collectionCount =
        missingRecords.where((r) => !_isExcelUpload(r) && !_isSystemAuto(r)).length;

    // Filter records by source if active
    List<MissingPaymentRecord> displayRecords =
        List<MissingPaymentRecord>.from(missingRecords);
    if (_sourceFilter == 'excel') {
      displayRecords = displayRecords.where(_isExcelUpload).toList();
    } else if (_sourceFilter == 'system') {
      displayRecords = displayRecords.where(_isSystemAuto).toList();
    } else if (_sourceFilter == 'collection') {
      displayRecords = displayRecords
          .where((r) => !_isExcelUpload(r) && !_isSystemAuto(r))
          .toList();
    }

    // Sort by missedDate (Ascending or Descending)
    displayRecords.sort((a, b) {
      final cmp = a.missedDate.compareTo(b.missedDate);
      return _sortAscending ? cmp : -cmp;
    });

    final int filteredCount = displayRecords.length;
    final int totalPages =
        filteredCount == 0 ? 1 : ((filteredCount + _pageSize - 1) ~/ _pageSize);
    if (_page > totalPages && totalPages > 0) {
      _page = totalPages;
    }
    final int startIndex = (_page - 1) * _pageSize;
    final int endIndex = (startIndex + _pageSize).clamp(0, filteredCount);
    final pagedRecords = (startIndex < filteredCount)
        ? displayRecords.sublist(startIndex, endIndex)
        : <MissingPaymentRecord>[];

    final bool hasPastData = excelCount > 0 ||
        cp.isMissingAutomationAuthorized(
          entry.id,
          entry.accountNumber,
          entry.customerId,
        ) ||
        missingRecords.any(_isExcelUpload);
    final bool canStartAutoInDialog = hasPastData && !_isRunningAuto;

    // Determine overall status label & colors
    final String overallStatusLabel;
    final Color overallStatusBg;
    final Color overallStatusBorder;
    final Color overallStatusText;
    final IconData overallStatusIcon;

    if (totalCount == 0) {
      final isAuth = cp.isMissingAutomationAuthorized(
        entry.id,
        entry.accountNumber,
        entry.customerId,
      );
      if (isAuth) {
        overallStatusLabel = "Authorized (Excel Linked)";
        overallStatusBg = Colors.green.shade50;
        overallStatusBorder = Colors.green.shade300;
        overallStatusText = Colors.green.shade800;
        overallStatusIcon = Icons.check_circle_outline_rounded;
      } else {
        overallStatusLabel = "Pending Excel Upload";
        overallStatusBg = Colors.grey.shade100;
        overallStatusBorder = Colors.grey.shade300;
        overallStatusText = Colors.grey.shade700;
        overallStatusIcon = Icons.pending_outlined;
      }
    } else if (excelCount > 0 && systemCount > 0) {
      overallStatusLabel =
          "Excel Upload ($excelCount) • System Auto ($systemCount)";
      overallStatusBg = Colors.amber.shade50;
      overallStatusBorder = Colors.amber.shade300;
      overallStatusText = Colors.amber.shade900;
      overallStatusIcon = Icons.auto_awesome_rounded;
    } else if (excelCount > 0) {
      overallStatusLabel = "Excel Upload ($excelCount records)";
      overallStatusBg = Colors.teal.shade50;
      overallStatusBorder = Colors.teal.shade300;
      overallStatusText = Colors.teal.shade800;
      overallStatusIcon = Icons.upload_file_rounded;
    } else if (systemCount > 0) {
      overallStatusLabel = "System Auto ($systemCount records)";
      overallStatusBg = Colors.blue.shade50;
      overallStatusBorder = Colors.blue.shade300;
      overallStatusText = Colors.blue.shade800;
      overallStatusIcon = Icons.bolt_rounded;
    } else {
      overallStatusLabel = "Collection Sheet ($collectionCount records)";
      overallStatusBg = Colors.purple.shade50;
      overallStatusBorder = Colors.purple.shade300;
      overallStatusText = Colors.purple.shade800;
      overallStatusIcon = Icons.receipt_long_rounded;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
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
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width < 560
                          ? (MediaQuery.of(context).size.width - 72).clamp(200.0, 480.0)
                          : 480,
                    ),
                    child: Row(
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
                        Flexible(
                          child: Column(
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
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: overallStatusBg,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: overallStatusBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      overallStatusIcon,
                                      size: 11,
                                      color: overallStatusText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      overallStatusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: overallStatusText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: (_isExporting || missingRecords.isEmpty)
                            ? null
                            : () => _exportToExcel(
                                  entry: entry,
                                  records: displayRecords,
                                  totalPayment: totalPayment,
                                  totalMissing: totalCount,
                                  totalMissingAmount: totalMissingAmount,
                                  totalMissingBalance: totalMissingBalance,
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E7E34),
                          side: const BorderSide(color: Color(0xFF1E7E34)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                            : const Icon(
                                Icons.table_view_rounded,
                                size: 15,
                                color: Color(0xFF1E7E34),
                              ),
                        label: Text(
                          _isExporting ? "Exporting..." : "Excel Export",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E7E34),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: !hasPastData
                            ? 'System Auto disabled: Past missing records (Excel) must exist first'
                            : (_isRunningAuto ? 'Running...' : 'Start System Auto'),
                        child: ElevatedButton.icon(
                          onPressed: canStartAutoInDialog ? _runSystemAutoInDialog : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canStartAutoInDialog
                                ? const Color(0xFF1E7E34)
                                : Colors.grey.shade300,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _isRunningAuto
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.bolt_rounded,
                                  size: 14,
                                  color: canStartAutoInDialog
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                          label: Text(
                            _isRunningAuto ? "Running..." : "Start System Auto",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: canStartAutoInDialog
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Close',
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
                    _buildMetricItem(
                      label: "Record Origin",
                      value: excelCount > 0 && systemCount > 0
                          ? "Excel + Auto"
                          : (excelCount > 0
                              ? "Excel Upload"
                              : (systemCount > 0
                                  ? "System Auto"
                                  : (totalCount == 0 ? "Pending" : "Collection"))),
                      valueColor: excelCount > 0
                          ? Colors.teal.shade800
                          : (systemCount > 0
                              ? Colors.blue.shade800
                              : Colors.grey.shade700),
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
                      label: "Total Missing Fine",
                      value: "₹${totalMissingBalance.toStringAsFixed(2)}",
                      valueColor: Colors.red.shade900,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filter & Date Sorting Toolbar (Visible when there are records)
              if (missingRecords.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      // Source status filter chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildFilterChip(
                            label: 'All ($totalCount)',
                            isSelected: _sourceFilter == 'All',
                            onTap: () => setState(() {
                              _sourceFilter = 'All';
                              _page = 1;
                            }),
                          ),
                          if (excelCount > 0)
                            _buildFilterChip(
                              label: 'Excel ($excelCount)',
                              icon: Icons.upload_file_rounded,
                              isSelected: _sourceFilter == 'excel',
                              color: Colors.teal,
                              onTap: () => setState(() {
                                _sourceFilter =
                                    _sourceFilter == 'excel' ? 'All' : 'excel';
                                _page = 1;
                              }),
                            ),
                          if (systemCount > 0)
                            _buildFilterChip(
                              label: 'System Auto ($systemCount)',
                              icon: Icons.bolt_rounded,
                              isSelected: _sourceFilter == 'system',
                              color: Colors.blue,
                              onTap: () => setState(() {
                                _sourceFilter =
                                    _sourceFilter == 'system' ? 'All' : 'system';
                                _page = 1;
                              }),
                            ),
                          if (collectionCount > 0)
                            _buildFilterChip(
                              label: 'Collection ($collectionCount)',
                              icon: Icons.receipt_long_rounded,
                              isSelected: _sourceFilter == 'collection',
                              color: Colors.purple,
                              onTap: () => setState(() {
                                _sourceFilter =
                                    _sourceFilter == 'collection'
                                        ? 'All'
                                        : 'collection';
                                _page = 1;
                              }),
                            ),
                        ],
                      ),

                      // Date sorting button
                      InkWell(
                        onTap: () {
                          setState(() {
                            _sortAscending = !_sortAscending;
                            _page = 1;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF8B1A1A).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortAscending
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 14,
                                color: const Color(0xFF8B1A1A),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _sortAscending
                                    ? 'Date: Asc (Oldest First)'
                                    : 'Date: Desc (Newest First)',
                                style: const TextStyle(
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
                ),

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
                      child: ExcludeSemantics(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 920),
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
                        sortColumnIndex: 0,
                        sortAscending: _sortAscending,
                        columns: [
                          DataColumn(
                            label: const Text("Date"),
                            tooltip: _sortAscending
                                ? 'Click to Sort Date Descending'
                                : 'Click to Sort Date Ascending',
                            onSort: (columnIndex, ascending) {
                              setState(() {
                                _sortAscending = ascending;
                                _page = 1;
                              });
                            },
                          ),
                          const DataColumn(label: Text("Paid Date")),
                          const DataColumn(label: Text("Basic Pay")),
                          const DataColumn(label: Text("Missing Fine")),
                          const DataColumn(label: Text("Missing Week")),
                          const DataColumn(label: Text("Missing Balance")),
                          const DataColumn(label: Text("Status")),
                          const DataColumn(label: Text("Source")),
                        ],
                        rows: pagedRecords.asMap().entries.map((mapEntry) {
                          final int idx = mapEntry.key;
                          final m = mapEntry.value;
                          final dateString =
                              '${m.missedDate.day.toString().padLeft(2, '0')}-'
                              '${m.missedDate.month.toString().padLeft(2, '0')}-'
                              '${m.missedDate.year}';
                          final isResolved = m.isResolved;
                          final isPartial = m.isPartial;
                          final bool isPaid = isResolved || m.paidDate != null;
                          final double displayBasicPay = m.missingPay > 0
                              ? m.missingPay
                              : (m.dayPayment > 0 ? m.dayPayment : 0.0);

                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>((states) {
                              if (isPaid) {
                                return const Color(0xFFF1F5F9); // Frozen / locked row style
                              }
                              return idx.isEven ? Colors.white : Colors.grey.shade50;
                            }),
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPaid) ...[
                                      Container(
                                        padding: const EdgeInsets.all(2.5),
                                        margin: const EdgeInsets.only(right: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.grey.shade400),
                                        ),
                                        child: Tooltip(
                                          message: m.paidDate != null
                                              ? 'Paid & Frozen on ${m.paidDate!.day.toString().padLeft(2, '0')}-${m.paidDate!.month.toString().padLeft(2, '0')}-${m.paidDate!.year} - Row is locked'
                                              : 'Paid & Frozen - Row is locked',
                                          child: Icon(
                                            Icons.lock_rounded,
                                            size: 11,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Text(
                                      dateString,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isPaid ? Colors.grey.shade800 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹ ${displayBasicPay.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isPaid ? Colors.grey.shade800 : Colors.orange.shade900,
                                      ),
                                    ),
                                    if (isPaid) ...[
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message: 'Settled Basic Pay Amount (Preserved & Frozen)',
                                        child: Icon(
                                          Icons.lock_clock_rounded,
                                          size: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              DataCell(Text(
                                '₹ ${m.missingFine.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isPaid ? Colors.grey.shade700 : Colors.black87,
                                ),
                              )),
                              DataCell(Text(
                                '${m.missingWeek}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isPaid ? Colors.grey.shade700 : Colors.black87,
                                ),
                              )),
                              DataCell(Text(
                                '₹ ${m.missingBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? Colors.grey.shade600 : Colors.red.shade900,
                                ),
                              )),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPaid
                                        ? Colors.green.shade50
                                        : (isPartial
                                            ? Colors.amber.shade50
                                            : Colors.red.shade50),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isPaid
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
                                        isPaid
                                            ? Icons.lock_rounded
                                            : (isPartial
                                                ? Icons.hourglass_bottom_rounded
                                                : (m.isPaused ? Icons.pause_circle_rounded : Icons.pending_actions_rounded)),
                                        size: 11,
                                        color: isPaid
                                            ? Colors.green.shade700
                                            : (isPartial
                                                ? Colors.amber.shade900
                                                : (m.isPaused ? Colors.blue.shade700 : Colors.red.shade700)),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPaid
                                            ? "PAID (LOCKED)"
                                            : (isPartial
                                                ? "PARTIAL PAID"
                                                : (m.isPaused ? "PAUSED" : "MISSING")),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isPaid
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
                              DataCell(_buildSourceBadge(m)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

              const SizedBox(height: 14),

              // Pagination Controls: [Previous] Page X of Y (N records) [Next]
              if (totalPages > 0)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
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
                      "Page $_page of $totalPages (${filteredCount != totalCount ? '$filteredCount of $totalCount' : '$totalCount'} records)",
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
        'Basic Pay',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'D7',
            ),
          )
          .value = xl.TextCellValue(
        'Missing Fine',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'E7',
            ),
          )
          .value = xl.TextCellValue(
        'Missing Week',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'F7',
            ),
          )
          .value = xl.TextCellValue(
        'Missing Balance',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'G7',
            ),
          )
          .value = xl.TextCellValue(
        'Status',
      );

      sheet
          .cell(
            xl.CellIndex.indexByString(
              'H7',
            ),
          )
          .value = xl.TextCellValue(
        'Source',
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
        final bool isPaid = record.isResolved || record.paidDate != null;
        final statusLabel = isPaid
            ? 'PAID (LOCKED)'
            : (record.isPartial ? 'PARTIAL PAID' : (record.isPaused ? 'PAUSED' : 'MISSING'));
        final double exportBasicPay = record.missingPay > 0
            ? record.missingPay
            : (record.dayPayment > 0 ? record.dayPayment : 0.0);

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

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'C$rowIndex',
              ),
            )
            .value = xl.DoubleCellValue(
          exportBasicPay,
        );

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'D$rowIndex',
              ),
            )
            .value = xl.DoubleCellValue(
          record.missingFine,
        );

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'E$rowIndex',
              ),
            )
            .value = xl.IntCellValue(
          record.missingWeek,
        );

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'F$rowIndex',
              ),
            )
            .value = xl.DoubleCellValue(
          record.missingBalance,
        );

        final sourceLabel = _isExcelUpload(record)
            ? 'Excel Upload'
            : (_isSystemAuto(record) ? 'System Auto' : 'Collection');

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'G$rowIndex',
              ),
            )
            .value = xl.TextCellValue(
          statusLabel,
        );

        sheet
            .cell(
              xl.CellIndex.indexByString(
                'H$rowIndex',
              ),
            )
            .value = xl.TextCellValue(
          sourceLabel,
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