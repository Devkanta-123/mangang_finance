// lib/screens/missing_manager_page.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/missing_payment_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/settings_provider.dart';
import '../services/supabase_service.dart';

/// Missing Manager Page
/// Visual Reference: Collection Sheet UI
/// Purpose: ONLY for viewing/checking missing-payment logs. It is NOT a payment screen.
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
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final loaneeProvider = Provider.of<LoaneeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final isRo = authProvider.activeRole == UserType.ro ||
        authProvider.currentUser?.userType == UserType.ro;
    final isAdmin = authProvider.activeRole == UserType.admin ||
        authProvider.currentUser?.userType == UserType.admin;

    // Available Routes
    final availableRoutes = collectionProvider.routeNames;

    // If an RO is assigned to a specific route and no route is selected, default to it
    if (isRo && _selectedRoute == null) {
      final userRoute = authProvider.currentUser?.accountName;
      if (userRoute != null && availableRoutes.contains(userRoute)) {
        _selectedRoute = userRoute;
      } else if (availableRoutes.isNotEmpty) {
        _selectedRoute = availableRoutes.first;
      }
    }

    // Filter collection entries by route
    List<RoCollectionEntry> filteredEntries = collectionProvider.collectionEntries;
    if (_selectedRoute != null && _selectedRoute!.isNotEmpty && _selectedRoute != 'All Routes') {
      filteredEntries = filteredEntries
          .where((e) => e.route.trim().toLowerCase() == _selectedRoute!.trim().toLowerCase())
          .toList();
    }

    // Filter by Collection Type (Daily, Weekly, Today, Mon, Tue...)
    if (_selectedType != 'All') {
      final st = _selectedType.toLowerCase().trim();
      if (st == 'daily') {
        filteredEntries = filteredEntries.where((e) => e.isDaily).toList();
      } else if (st == 'weekly') {
        filteredEntries = filteredEntries.where((e) => !e.isDaily).toList();
      } else if (st == 'today') {
        final todayWeekday = DateTime.now().weekday;
        const weekdayNames = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
        final dayStr = weekdayNames[todayWeekday];
        filteredEntries = filteredEntries.where((e) {
          final ct = e.collectionType.toLowerCase().trim();
          return ct == 'daily' || ct == dayStr || ct == 'all';
        }).toList();
      } else {
        filteredEntries = filteredEntries
            .where((e) => e.collectionType.toLowerCase().trim() == st)
            .toList();
      }
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filteredEntries = filteredEntries.where((e) {
        final matchName = e.loaneeName.toLowerCase().contains(q);
        final matchCust = e.customerId.toLowerCase().contains(q);
        final matchAcc = e.accountNumber.toLowerCase().contains(q);
        final matchMob = e.mobileNo.toLowerCase().contains(q);
        return matchName || matchCust || matchAcc || matchMob;
      }).toList();
    }

    // Calculate aggregated missing metrics for the filtered set
    int totalMissingLoanees = 0;
    double totalMissingAmount = 0.0;
    double totalMissingBalance = 0.0;

    for (final entry in filteredEntries) {
      final missingCount = collectionProvider.getTotalMissingCountForCollection(entry.id);
      if (missingCount > 0) {
        totalMissingLoanees++;
        totalMissingAmount += collectionProvider.getTotalMissingPayForCollection(entry.id);
        totalMissingBalance += collectionProvider.getTotalMissingBalanceForCollection(entry.id);
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
              // 1. TOP HEADER BANNER (Consistent with Collection Sheet)
              _buildTopHeader(collectionProvider, isRo),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. ROUTE SELECTION CARDS
                    _buildRouteSelectionCardsSection(collectionProvider, availableRoutes),

                    const SizedBox(height: 14),

                    // 3. SELECTED ROUTE TITLE & COLLECTION TYPES
                    if (_selectedRoute != null) ...[
                      _buildSelectedRouteHeader(),
                      const SizedBox(height: 10),
                      _buildCollectionTypeFilterCards(),
                      const SizedBox(height: 14),

                      // 4. DATA TABLE SECTION (OR NO ROUTE SELECTED)
                      _buildDataTableSection(
                        filteredEntries,
                        collectionProvider,
                        settingsProvider,
                        loaneeProvider,
                        totalMissingLoanees,
                        totalMissingAmount,
                        totalMissingBalance,
                      ),
                    ] else ...[
                      _buildNoRouteSelectedState(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. TOP BANNER HEADER
  // ==========================================
  Widget _buildTopHeader(CollectionSheetProvider provider, bool isRo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
      child: LayoutBuilder(
        builder: (context, headerConstraints) {
          final isNarrow = headerConstraints.maxWidth < 560;
          final titleWidget = Row(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Missing Manager",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Route-mapped missing payment ledger & audit logs (MISSING ≠ PAYMENT)",
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
          );

          final actionsWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedRoute != null || _searchQuery.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.amber),
                    tooltip: "Reset Filters",
                    onPressed: _resetFilters,
                  ),
                ],
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
                      : const Icon(Icons.sync_rounded, size: 18, color: Colors.white),
                  tooltip: "Sync with Supabase",
                  onPressed: () async {
                    await provider.fetchFromSupabase();
                  },
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleWidget,
                const SizedBox(height: 10),
                actionsWidget,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 8),
              actionsWidget,
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // 2. ROUTE SELECTION CARDS
  // ==========================================
  Widget _buildRouteSelectionCardsSection(
    CollectionSheetProvider provider,
    List<String> availableRoutes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.alt_route_rounded, size: 15, color: Color(0xFF8B1A1A)),
            SizedBox(width: 5),
            Text(
              "ROUTE ZONES",
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableRoutes.map((routeName) {
              final isSelected = _selectedRoute == routeName;
              final entryCount = provider.collectionEntries
                  .where((e) => e.route.trim().toLowerCase() == routeName.trim().toLowerCase())
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF8B1A1A) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? const Color(0xFF8B1A1A).withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: isSelected ? Colors.amber : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          routeName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "$entryCount",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
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
        ),
      ],
    );
  }

  // ==========================================
  // 3. SELECTED ROUTE HEADER & COLLECTION TYPE FILTER
  // ==========================================
  Widget _buildSelectedRouteHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF8B1A1A)),
            const SizedBox(width: 6),
            Text(
              "Route: ${_selectedRoute!}",
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B1A1A),
              ),
            ),
          ],
        ),
        Text(
          "Filter: $_selectedType",
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionTypeFilterCards() {
    final types = ['All', 'Today', 'Daily', 'Weekly', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final isSelected = _selectedType == t;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(t),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedType = t;
                  });
                }
              },
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
              selectedColor: const Color(0xFF8B1A1A),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // 4. NO ROUTE SELECTED STATE
  // ==========================================
  Widget _buildNoRouteSelectedState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.alt_route_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            "Select a Route Zone to Load Missing Payment Logs",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Click on any Route Zone card above to inspect loanee missing payments, fines, and balances.",
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. DATA TABLE SECTION
  // ==========================================
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
        // Controls Row: Search & View Toggle
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search loanee, ID, mobile, account...",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = "";
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
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Toggle Table vs Cards
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.table_rows_rounded,
                      size: 18,
                      color: _isTableView ? const Color(0xFF8B1A1A) : Colors.grey,
                    ),
                    tooltip: "Table View",
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
                      color: !_isTableView ? const Color(0xFF8B1A1A) : Colors.grey,
                    ),
                    tooltip: "Cards View",
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

        // Summary Statistics Bar (Template Style)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    "Showing ${entries.length} Records in ${_selectedRoute!} ($totalMissingLoanees with Missing Logs)",
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          "Total Missing: ₹${totalMissingAmount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          "Total Balance: ₹${totalMissingBalance.toStringAsFixed(2)}",
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
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 42, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  "No Entries Found in ${_selectedRoute!} ($_selectedType)",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Try clearing search filters or changing collection type.",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else if (_isTableView)
          _buildDataTableWidget(entries, provider, settingsProvider, loaneeProvider)
        else
          _buildCardsListWidget(entries, provider, settingsProvider, loaneeProvider),
      ],
    );
  }

  // ==========================================
  // DATA TABLE WIDGET
  // ==========================================
  Widget _buildDataTableWidget(
    List<RoCollectionEntry> entries,
    CollectionSheetProvider provider,
    SettingsProvider settingsProvider,
    LoaneeProvider loaneeProvider,
  ) {
    return Container(
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
            constraints: const BoxConstraints(minWidth: 700),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF8B1A1A)),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 11,
              ),
              dataRowMaxHeight: 52,
              dataRowMinHeight: 44,
              columnSpacing: 14,
              horizontalMargin: 12,
              columns: const [
                DataColumn(label: Text("#")),
                DataColumn(label: Text("Loanee Name")),
                DataColumn(label: Text("Customer ID")),
                DataColumn(label: Text("Account No")),
                DataColumn(label: Text("Type")),
                DataColumn(label: Text("Total Paid")),
                DataColumn(label: Text("Missing Count")),
                DataColumn(label: Text("Missing Amount")),
                DataColumn(label: Text("Missing Balance")),
                DataColumn(label: Text("Action")),
              ],
              rows: entries.asMap().entries.map((mapEntry) {
                final idx = mapEntry.key + 1;
                final entry = mapEntry.value;
                final missingCount = provider.getTotalMissingCountForCollection(entry.id);
                final missingAmount = provider.getTotalMissingPayForCollection(entry.id);
                final missingBalance = provider.getTotalMissingBalanceForCollection(entry.id);
                final totalPaid = provider.getTotalPaidForCollection(entry.id);

                return DataRow(
                  cells: [
                    DataCell(Text("$idx", style: const TextStyle(fontSize: 11))),
                    DataCell(
                      InkWell(
                        onTap: () => _openMissingDetails(entry),
                        child: Text(
                          entry.loaneeName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B1A1A),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(entry.customerId, style: const TextStyle(fontSize: 11))),
                    DataCell(Text(entry.accountNumber, style: const TextStyle(fontSize: 11))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: entry.isDaily ? Colors.blue.shade50 : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.isDaily ? "Daily" : "Weekly",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: entry.isDaily ? Colors.blue.shade800 : Colors.purple.shade800,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        "₹ ${totalPaid.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: missingCount > 0 ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          missingCount > 0 ? "$missingCount" : "0",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: missingCount > 0 ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        missingAmount > 0 ? "₹ ${missingAmount.toStringAsFixed(2)}" : "—",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: missingAmount > 0 ? FontWeight.bold : FontWeight.normal,
                          color: missingAmount > 0 ? Colors.orange.shade900 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        missingBalance > 0 ? "₹ ${missingBalance.toStringAsFixed(2)}" : "—",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: missingBalance > 0 ? FontWeight.bold : FontWeight.normal,
                          color: missingBalance > 0 ? Colors.red.shade900 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () => _openMissingDetails(entry),
                        icon: const Icon(Icons.receipt_long_rounded, size: 12),
                        label: const Text("View Log", style: TextStyle(fontSize: 10)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1A1A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(60, 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
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
    );
  }

  // ==========================================
  // CARDS LIST WIDGET
  // ==========================================
  Widget _buildCardsListWidget(
    List<RoCollectionEntry> entries,
    CollectionSheetProvider provider,
    SettingsProvider settingsProvider,
    LoaneeProvider loaneeProvider,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final entry = entries[i];
        final missingCount = provider.getTotalMissingCountForCollection(entry.id);
        final missingAmount = provider.getTotalMissingPayForCollection(entry.id);
        final missingBalance = provider.getTotalMissingBalanceForCollection(entry.id);
        final totalPaid = provider.getTotalPaidForCollection(entry.id);

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.loaneeName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B1A1A),
                            ),
                          ),
                          Text(
                            "Cust ID: ${entry.customerId} • A/C: ${entry.accountNumber}",
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: entry.isDaily ? Colors.blue.shade50 : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.isDaily ? "Daily" : "Weekly",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: entry.isDaily ? Colors.blue.shade800 : Colors.purple.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatPill("Total Paid", "₹ ${totalPaid.toStringAsFixed(0)}", Colors.green.shade800),
                    _buildStatPill("Missing Count", "$missingCount", missingCount > 0 ? Colors.red.shade800 : Colors.grey.shade700),
                    _buildStatPill("Missing Pay", "₹ ${missingAmount.toStringAsFixed(0)}", Colors.orange.shade900),
                    _buildStatPill("Missing Balance", "₹ ${missingBalance.toStringAsFixed(1)}", Colors.red.shade900),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _openMissingDetails(entry),
                    icon: const Icon(Icons.receipt_long_rounded, size: 14),
                    label: const Text("View Missing Log"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ==========================================
  // 6. OPEN DETAILED MISSING LOG DIALOG
  // ==========================================
  Future<void> _openMissingDetails(RoCollectionEntry entry) async {
    final cp = Provider.of<CollectionSheetProvider>(context, listen: false);
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    final lp = Provider.of<LoaneeProvider>(context, listen: false);

    // Auto sync missing records on demand for this entry
    try {
      final loanee = lp.getLoaneeForUser(
        customerId: entry.customerId,
        mobileNo: entry.mobileNo,
        name: entry.loaneeName,
      );
      final effectiveLoanAmt = (entry.loanAmount != null && entry.loanAmount! > 0)
          ? entry.loanAmount!
          : ((loanee != null && loanee.loanAmount > 0)
              ? loanee.loanAmount
              : (entry.actualPrincipal ?? entry.initialBalance));

      await cp.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: sp,
        loaneeLoanAmount: effectiveLoanAmt,
        loaneeProvider: lp,
        sanctionDate: loanee?.loanSanctionDate,
      );
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MissingDetailsModalSheet(entry: entry),
    );
  }
}

/// ==============================================================================
/// MISSING DETAILS MODAL SHEET
/// Built strictly to match the attached 'Missing Pament Details.xlsx' Excel template:
/// Top: Customer ID, Account No., Mobile No.
/// Summary: Total Pament, Total Missing, Total Missing Amount, Total Missing Balance
/// Table: Date, Day Payment, Missing Pay, Missing find, Missing Week, Missing Balance
/// Strict Rule: It is NOT a payment screen.
/// ==============================================================================
class _MissingDetailsModalSheet extends StatefulWidget {
  final RoCollectionEntry entry;

  const _MissingDetailsModalSheet({required this.entry});

  @override
  State<_MissingDetailsModalSheet> createState() => _MissingDetailsModalSheetState();
}

class _MissingDetailsModalSheetState extends State<_MissingDetailsModalSheet> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);
    final missingRecords = collectionProvider.getMissingRecordsForCollection(widget.entry.id);

    final totalPayment = collectionProvider.getTotalPaidForCollection(widget.entry.id);
    final totalMissing = missingRecords.length;
    final totalMissingAmount = missingRecords.fold(0.0, (sum, m) => sum + m.missingPay);
    final totalMissingBalance = missingRecords.fold(0.0, (sum, m) => sum + m.missingBalance);

    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Sheet Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "MISSING LOG",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange.shade900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.entry.loaneeName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B1A1A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Route: ${widget.entry.route} • Scheme: ${widget.entry.isDaily ? 'Daily' : 'Weekly'}",
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
              ),

              const Divider(height: 1),

              // Scrollable Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // TOP LEVEL INFORMATION (Matches Excel Template Top Rows)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow("Coustomer ID", widget.entry.customerId),
                          const SizedBox(height: 6),
                          _buildInfoRow("Account No.", widget.entry.accountNumber),
                          const SizedBox(height: 6),
                          _buildInfoRow("Mobile No.", widget.entry.mobileNo.isNotEmpty ? widget.entry.mobileNo : "—"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4 SUMMARY CARDS (Matches Row 4 & 5 of Excel Template)
                    // B4: Total Pament, C4: Total Missing, D4: Total Missing Amount, E4: Total Missing Balance
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isSmall = constraints.maxWidth < 450;
                        return GridView.count(
                          crossAxisCount: isSmall ? 2 : 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: isSmall ? 1.8 : 1.5,
                          children: [
                            _buildTemplateStatCard(
                              title: "Total Pament",
                              value: "₹ ${totalPayment.toStringAsFixed(2)}",
                              color: Colors.teal.shade700,
                              bgColor: Colors.teal.shade50,
                              borderColor: Colors.teal.shade200,
                            ),
                            _buildTemplateStatCard(
                              title: "Total Missing",
                              value: "$totalMissing",
                              color: Colors.blueGrey.shade800,
                              bgColor: Colors.blueGrey.shade50,
                              borderColor: Colors.blueGrey.shade200,
                            ),
                            _buildTemplateStatCard(
                              title: "Total Missing Amount",
                              value: "₹ ${totalMissingAmount.toStringAsFixed(2)}",
                              color: Colors.orange.shade800,
                              bgColor: Colors.orange.shade50,
                              borderColor: Colors.orange.shade200,
                            ),
                            _buildTemplateStatCard(
                              title: "Total Missing Balance",
                              value: "₹ ${totalMissingBalance.toStringAsFixed(2)}",
                              color: Colors.red.shade800,
                              bgColor: Colors.red.shade50,
                              borderColor: Colors.red.shade200,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // TABLE SECTION HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Missing Payment Detail Log",
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B1A1A),
                          ),
                        ),
                        if (missingRecords.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _isExporting
                                ? null
                                : () => _exportToExcel(
                                      entry: widget.entry,
                                      records: missingRecords,
                                      totalPayment: totalPayment,
                                      totalMissing: totalMissing,
                                      totalMissingAmount: totalMissingAmount,
                                      totalMissingBalance: totalMissingBalance,
                                    ),
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.download_rounded, size: 13),
                            label: const Text("Export Template Excel", style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B1A1A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // DETAILED TABLE (Matches Excel Template columns: Date, Day Payment, Missing Pay, Missing find, Missing Week, Missing Balance)
                    if (missingRecords.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 36, color: Colors.green.shade600),
                            const SizedBox(height: 8),
                            const Text(
                              "No Missing Payments Recorded",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "This loanee has no pending missed payments in the missing payment logs.",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 580),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF8B1A1A)),
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                                dataRowMaxHeight: 44,
                                dataRowMinHeight: 38,
                                columnSpacing: 14,
                                horizontalMargin: 12,
                                columns: const [
                                  DataColumn(label: Text("Date")),
                                  DataColumn(label: Text("Day Payment")),
                                  DataColumn(label: Text("Missing Pay")),
                                  DataColumn(label: Text("Missing find")),
                                  DataColumn(label: Text("Missing Week")),
                                  DataColumn(label: Text("Missing Balance")),
                                  DataColumn(label: Text("Status")),
                                ],
                                rows: missingRecords.map((m) {
                                  final dateStr =
                                      '${m.missedDate.day.toString().padLeft(2, '0')}-${m.missedDate.month.toString().padLeft(2, '0')}-${m.missedDate.year}';
                                  final dayPaymentStr = m.dayPayment > 0 ? "₹ ${m.dayPayment.toStringAsFixed(2)}" : "—";
                                  final missingPayStr = "₹ ${m.missingPay.toStringAsFixed(2)}";
                                  final missingFineStr = "₹ ${m.missingFine.toStringAsFixed(2)}";
                                  final missingWeekStr = "${m.missingWeek}";
                                  final missingBalanceStr = "₹ ${m.missingBalance.toStringAsFixed(2)}";

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(dateStr, style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(dayPaymentStr, style: const TextStyle(fontSize: 11))),
                                      DataCell(
                                        Text(
                                          missingPayStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(missingFineStr, style: const TextStyle(fontSize: 11))),
                                      DataCell(Text(missingWeekStr, style: const TextStyle(fontSize: 11))),
                                      DataCell(
                                        Text(
                                          missingBalanceStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: m.isResolved
                                                ? Colors.green.shade50
                                                : (m.isPartial ? Colors.amber.shade50 : Colors.red.shade50),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            m.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: m.isResolved
                                                  ? Colors.green.shade800
                                                  : (m.isPartial ? Colors.amber.shade900 : Colors.red.shade800),
                                            ),
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
        ),
        const Text(": ", style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateStatCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EXPORT TO EXCEL MATCHING THE TEMPLATE
  // ==========================================
  Future<void> _exportToExcel({
    required RoCollectionEntry entry,
    required List<MissingPaymentRecord> records,
    required double totalPayment,
    required int totalMissing,
    required double totalMissingAmount,
    required double totalMissingBalance,
  }) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Missing Payment Details'];
      excel.setDefaultSheet('Missing Payment Details');

      // Top Header
      sheet.cell(xl.CellIndex.indexByString("A1")).value = xl.TextCellValue("Coustomer ID");
      sheet.cell(xl.CellIndex.indexByString("B1")).value = xl.TextCellValue(entry.customerId);

      sheet.cell(xl.CellIndex.indexByString("A2")).value = xl.TextCellValue("Account No.");
      sheet.cell(xl.CellIndex.indexByString("B2")).value = xl.TextCellValue(entry.accountNumber);

      sheet.cell(xl.CellIndex.indexByString("A3")).value = xl.TextCellValue("Mobile No.");
      sheet.cell(xl.CellIndex.indexByString("B3")).value = xl.TextCellValue(entry.mobileNo);

      // Summary Header (Row 4)
      sheet.cell(xl.CellIndex.indexByString("B4")).value = xl.TextCellValue("Total Pament");
      sheet.cell(xl.CellIndex.indexByString("C4")).value = xl.TextCellValue("Total Missing");
      sheet.cell(xl.CellIndex.indexByString("D4")).value = xl.TextCellValue("Total Missing Amount");
      sheet.cell(xl.CellIndex.indexByString("E4")).value = xl.TextCellValue("Total Missing Balance");

      // Summary Values (Row 5)
      sheet.cell(xl.CellIndex.indexByString("B5")).value = xl.DoubleCellValue(totalPayment);
      sheet.cell(xl.CellIndex.indexByString("C5")).value = xl.IntCellValue(totalMissing);
      sheet.cell(xl.CellIndex.indexByString("D5")).value = xl.DoubleCellValue(totalMissingAmount);
      sheet.cell(xl.CellIndex.indexByString("E5")).value = xl.DoubleCellValue(totalMissingBalance);

      // Table Header (Row 7)
      sheet.cell(xl.CellIndex.indexByString("A7")).value = xl.TextCellValue("Date");
      sheet.cell(xl.CellIndex.indexByString("B7")).value = xl.TextCellValue("Day Payment");
      sheet.cell(xl.CellIndex.indexByString("C7")).value = xl.TextCellValue("Missing Pay");
      sheet.cell(xl.CellIndex.indexByString("D7")).value = xl.TextCellValue("Missing find");
      sheet.cell(xl.CellIndex.indexByString("E7")).value = xl.TextCellValue("Missing Week");
      sheet.cell(xl.CellIndex.indexByString("F7")).value = xl.TextCellValue("Missing Balance");

      // Data Rows (Row 8 onward)
      int rowIdx = 8;
      for (final m in records) {
        final dateStr =
            '${m.missedDate.day.toString().padLeft(2, '0')}-${m.missedDate.month.toString().padLeft(2, '0')}-${m.missedDate.year}';
        sheet.cell(xl.CellIndex.indexByString("A$rowIdx")).value = xl.TextCellValue(dateStr);
        if (m.dayPayment > 0) {
          sheet.cell(xl.CellIndex.indexByString("B$rowIdx")).value = xl.DoubleCellValue(m.dayPayment);
        } else {
          sheet.cell(xl.CellIndex.indexByString("B$rowIdx")).value = xl.TextCellValue("—");
        }
        sheet.cell(xl.CellIndex.indexByString("C$rowIdx")).value = xl.DoubleCellValue(m.missingPay);
        sheet.cell(xl.CellIndex.indexByString("D$rowIdx")).value = xl.DoubleCellValue(m.missingFine);
        sheet.cell(xl.CellIndex.indexByString("E$rowIdx")).value = xl.IntCellValue(m.missingWeek);
        sheet.cell(xl.CellIndex.indexByString("F$rowIdx")).value = xl.DoubleCellValue(m.missingBalance);
        rowIdx++;
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'Missing_Log_${entry.accountNumber}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Mangang Finance - Missing Log for ${entry.loaneeName} (${entry.accountNumber})',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting missing log: $e')),
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
