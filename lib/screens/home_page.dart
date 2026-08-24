import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/ro_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/collection_payment_model.dart';
import '../models/loanee_model.dart';
import '../providers/auth_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/ro_provider.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/ro_daily_collection_pie_chart.dart';
import 'late_fines_page.dart';

class HomePage extends StatelessWidget {
  final Function(int)? onNavigateToMenu;

  const HomePage({super.key, this.onNavigateToMenu});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final loaneeProvider = Provider.of<LoaneeProvider>(context);
    final roProvider = Provider.of<RoProvider>(context);
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);

    final activeRole = authProvider.activeRole;
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Role Banner Header
            _buildRoleBanner(context, activeRole),

            // Role-Specific Dashboard Content
            if (activeRole == UserType.admin)
              _buildAdminDashboard(context, loaneeProvider, roProvider, collectionProvider, onNavigateToMenu)
            else if (activeRole == UserType.manager)
              _buildManagerDashboard(context, loaneeProvider, roProvider, collectionProvider, onNavigateToMenu)
            else if (activeRole == UserType.ro)
              _buildRODashboard(context, roProvider, collectionProvider, user, onNavigateToMenu)
            else
              _buildLoaneeDashboard(context, user, onNavigateToMenu),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBanner(
    BuildContext context,
    UserType activeRole,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        _getRoleTitle(activeRole),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // ==========================================
  // 1. ADMIN DASHBOARD VIEW (FULL ACCESS)
  // ==========================================
  Widget _buildAdminDashboard(
    BuildContext context,
    LoaneeProvider loaneeProvider,
    RoProvider roProvider,
    CollectionSheetProvider collectionProvider,
    Function(int)? onNavigateToMenu,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Metric Cards
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateToMenu?.call(2), // Loanee List
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMetricCard(
                    title: 'Total Loanees',
                    value: '${loaneeProvider.totalLoanees}',
                    subtitle: 'Registered Accounts',
                    icon: Icons.people_alt_rounded,
                    color: Colors.blue.shade700,
                    backgroundColor: Colors.blue.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateToMenu?.call(4), // RO List
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMetricCard(
                    title: 'Active ROs',
                    value: '${roProvider.totalRos}',
                    subtitle: 'Field Officers',
                    icon: Icons.badge_rounded,
                    color: Colors.orange.shade700,
                    backgroundColor: Colors.orange.shade50,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateToMenu?.call(6), // Collection Sheet
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMetricCard(
                    title: 'Collection Cards',
                    value: '${collectionProvider.totalEntriesCount}',
                    subtitle: 'Sheet Entries',
                    icon: Icons.table_chart_rounded,
                    color: Colors.purple.shade700,
                    backgroundColor: Colors.purple.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateToMenu?.call(7), // Master Route Setup
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMetricCard(
                    title: 'Total Routes',
                    value: '${collectionProvider.totalRoutesCount}',
                    subtitle: 'Master Route Setup',
                    icon: Icons.alt_route_rounded,
                    color: Colors.teal.shade700,
                    backgroundColor: Colors.teal.shade50,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. 3D Interactive RO Daily Collection Pie Chart
          RoDailyCollectionPieChart(
            roProvider: roProvider,
            collectionProvider: collectionProvider,
          ),
          const SizedBox(height: 20),

          // 2. Route Wise Collection Visual Bar Chart
          _buildRouteWiseCollectionChart(context, collectionProvider),
          const SizedBox(height: 20),

          // 3. All Collection & Payment Done Ledger across All Routes (Paginated)
          _AdminAllCollectionsLedgerSection(collectionProvider: collectionProvider),
        ],
      ),
    );
  }

  // ==========================================
  // 1.5. MANAGER MONITORING DASHBOARD (READ-ONLY)
  // ==========================================
  Widget _buildManagerDashboard(
    BuildContext context,
    LoaneeProvider loaneeProvider,
    RoProvider roProvider,
    CollectionSheetProvider collectionProvider,
    Function(int)? onNavigateToMenu,
  ) {
    final double extraCollection = collectionProvider.totalCollectedAmount;
    final double grandTotalCollected = loaneeProvider.totalCollectedAmount + extraCollection;
    final double totalSanctioned = loaneeProvider.totalLoanAmount;
    final double remainingBalance = (totalSanctioned - grandTotalCollected).clamp(0.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recovered vs Remaining Balance Summary with Show/Hide Toggle (Manager Theme - Brand Red)
          _ManagerBalanceSummaryCard(
            grandTotalCollected: grandTotalCollected,
            remainingBalance: remainingBalance,
          ),
          const SizedBox(height: 16),

          // Monitoring Metrics Grid (Tap to view relevant pages)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateToMenu?.call(2), // Loanee List
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMetricCard(
                    title: 'Total Loanees',
                    value: '${loaneeProvider.totalLoanees}',
                    subtitle: 'Registered Accounts',
                    icon: Icons.people_alt_rounded,
                    color: Colors.blue.shade700,
                    backgroundColor: Colors.blue.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateToMenu?.call(4), // RO List
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMetricCard(
                    title: 'Active ROs',
                    value: '${roProvider.totalRos}',
                    subtitle: 'Field Officers',
                    icon: Icons.badge_rounded,
                    color: Colors.orange.shade700,
                    backgroundColor: Colors.orange.shade50,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateToMenu?.call(6), // Collection Sheet
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMetricCard(
                    title: 'Collection Cards',
                    value: '${collectionProvider.totalEntriesCount}',
                    subtitle: 'Sheet Entries',
                    icon: Icons.table_chart_rounded,
                    color: Colors.purple.shade700,
                    backgroundColor: Colors.purple.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateToMenu?.call(7), // Master Route
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMetricCard(
                    title: 'Master Routes',
                    value: '${collectionProvider.totalRoutesCount}',
                    subtitle: 'Zone Setups',
                    icon: Icons.alt_route_rounded,
                    color: Colors.teal.shade700,
                    backgroundColor: Colors.teal.shade50,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. 3D Interactive RO Daily Collection Pie Chart
          RoDailyCollectionPieChart(
            roProvider: roProvider,
            collectionProvider: collectionProvider,
          ),
          const SizedBox(height: 20),

          // 2. Route Wise Collection Visual Bar Chart
          _buildRouteWiseCollectionChart(context, collectionProvider),
          const SizedBox(height: 20),

          // 3. All Collection & Payment Done Ledger across All Routes (Paginated)
          _AdminAllCollectionsLedgerSection(collectionProvider: collectionProvider),
        ],
      ),
    );
  }

  // ==========================================
  // 2. RO DASHBOARD VIEW
  // ==========================================
  Widget _buildRODashboard(
    BuildContext context,
    RoProvider roProvider,
    CollectionSheetProvider collectionProvider,
    User? user,
    Function(int)? onNavigateToMenu,
  ) {
    final displayName = (user?.name != null && user!.name.isNotEmpty)
        ? user.name
        : 'RO Officer';

    final roAccount = roProvider.getRoForUser(
      customerId: user?.customerId,
      mobileNo: user?.mobileNo,
      name: user?.name,
    );

    final assignedRoute = (roAccount != null && roAccount.route.isNotEmpty)
        ? roAccount.route
        : 'All Routes / General';

    final now = DateTime.now();

    final cleanUserName = (user?.name ?? '').toLowerCase().trim();
    final cleanUserCustId = (user?.customerId ?? '').toLowerCase().trim();
    final cleanUserMobile = (user?.mobileNo ?? '').trim();
    final cleanRoName = (roAccount?.roName ?? '').toLowerCase().trim();
    final cleanRoCustId = (roAccount?.customerId ?? '').toLowerCase().trim();
    final cleanRoMobile = (roAccount?.mobileNo ?? '').trim();
    final cleanRoute = assignedRoute.toLowerCase().trim();

    bool isPaymentForThisRo(CollectionPaymentModel p) {
      final pRoName = (p.roName ?? '').toLowerCase().trim();
      final pRoId = (p.roId ?? '').toLowerCase().trim();
      final pRoRoute = (p.roRoute ?? '').toLowerCase().trim();

      // 1. Direct ID match
      final matchId = (cleanUserCustId.isNotEmpty && pRoId == cleanUserCustId) ||
          (cleanRoCustId.isNotEmpty && pRoId == cleanRoCustId) ||
          (cleanUserMobile.isNotEmpty && pRoId == cleanUserMobile) ||
          (cleanRoMobile.isNotEmpty && pRoId == cleanRoMobile);
      if (matchId) return true;

      // 2. Direct Name match
      final matchName = (cleanUserName.isNotEmpty && pRoName == cleanUserName) ||
          (cleanRoName.isNotEmpty && pRoName == cleanRoName);
      if (matchName) return true;

      // 3. Explicit check: If this payment is tagged with another RO officer's ID or name, reject it!
      if (pRoId.isNotEmpty) return false;
      if (pRoName.isNotEmpty &&
          pRoName != 'ro officer' &&
          pRoName != 'field officer' &&
          pRoName != 'officer') {
        return false;
      }

      // 4. Route match if assigned specific route
      if (cleanRoute.isNotEmpty &&
          cleanRoute != 'all routes / general' &&
          cleanRoute != 'all routes' &&
          cleanRoute != 'all') {
        if (pRoRoute == cleanRoute) return true;
        final card = collectionProvider.getCardForPayment(p);
        if (card != null && card.route.toLowerCase().trim() == cleanRoute) return true;
      }
      return false;
    }

    // Today's collections strictly for the logged-in RO
    final todayRoPayments = collectionProvider.payments.where((p) {
      final isToday = p.createdAt.year == now.year &&
          p.createdAt.month == now.month &&
          p.createdAt.day == now.day;
      return isToday && isPaymentForThisRo(p);
    }).toList();

    final double todayRecoveredAmount =
        todayRoPayments.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final int todayCollectionRecordsCount = todayRoPayments.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RO Field Officer Profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFF8B1A1A),
                      child: Icon(Icons.badge_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Field Relationship Officer • Mangang Finance',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                // Route Map / Assigned Route Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.alt_route_rounded, size: 18, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ASSIGNED ROUTE MAP',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              assignedRoute,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
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
          const SizedBox(height: 16),

          const Text(
            "Collection Overview",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B1A1A),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Collection Records',
                  value: '$todayCollectionRecordsCount Records',
                  subtitle: "Today's Sheet Entries",
                  icon: Icons.post_add_rounded,
                  color: Colors.blue.shade700,
                  backgroundColor: Colors.blue.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Recovered',
                  value: '₹ ${todayRecoveredAmount.toStringAsFixed(2)}',
                  subtitle: "Today's Recovered",
                  icon: Icons.payments_rounded,
                  color: Colors.green.shade700,
                  backgroundColor: Colors.green.shade50,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // RO Actions
          const Text(
            'RO Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B1A1A),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  title: 'Collection Sheet',
                  subtitle: 'View routes & record payments',
                  icon: Icons.table_chart_rounded,
                  color: Colors.green.shade700,
                  onTap: () {
                    if (onNavigateToMenu != null) onNavigateToMenu(6);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  title: 'RO Profile',
                  subtitle: 'Officer credentials & details',
                  icon: Icons.account_circle_rounded,
                  color: const Color(0xFF8B1A1A),
                  onTap: () {
                    if (onNavigateToMenu != null) onNavigateToMenu(8);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildROScheduleCard(collectionProvider, roProvider, assignedRoute, user, roAccount),
        ],
      ),
    );
  }

  // ==========================================
  // 3. LOANEE DASHBOARD VIEW (READ ONLY)
  // ==========================================
  Widget _buildLoaneeDashboard(
    BuildContext context,
    User? user,
    Function(int)? onNavigateToMenu,
  ) {
    final loaneeProvider = Provider.of<LoaneeProvider>(context);
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);

    // Pull real mapped account from live 'loanee_accounts' Supabase table
    final loaneeAccount = loaneeProvider.getLoaneeForUser(
      customerId: user?.customerId,
      mobileNo: user?.mobileNo,
      name: user?.name,
    );

    // Real loan amount from loanee_accounts table column 'loanamount' (if exists, else 0.0)
    final double realLoanAmount = loaneeAccount?.loanAmount ?? 0.0;

    final loaneeEntries = collectionProvider.getEntriesForLoanee(
      user?.mobileNo ?? '',
      user?.name ?? '',
      user?.customerId ?? '',
    );
    final loaneePayments = collectionProvider.getPaymentsForEntries(loaneeEntries);

    final double totalPaid = loaneePayments.fold(0.0, (sum, p) => sum + p.paymentAmount);

    // Dynamic Remaining Balance calculation:
    // If collection sheet recorded payments exist with remainingBalance, use latest
    // Else if real loan amount is known, use (realLoanAmount - totalPaid)
    // Else 0.0
    final double latestRemainingBal = loaneePayments.isNotEmpty
        ? loaneePayments.first.remainingBalance
        : (realLoanAmount > 0
            ? (realLoanAmount - totalPaid)
            : 0.0);

    // Resolve Customer ID and Account Number
    final customerIdDisplay = (user?.customerId != null && user!.customerId!.isNotEmpty)
        ? user.customerId!
        : (loaneeAccount?.customerId.isNotEmpty == true
            ? loaneeAccount!.customerId
            : (loaneeEntries.isNotEmpty ? loaneeEntries.first.customerId : 'N/A'));

    final accountNoDisplay = loaneeAccount?.accountNumber.isNotEmpty == true
        ? loaneeAccount!.accountNumber
        : (loaneeEntries.isNotEmpty
            ? loaneeEntries.map((e) => e.accountNumber).toSet().join(', ')
            : (user?.mobileNo ?? 'N/A'));

    final loaneeDisplayName = loaneeAccount?.loaneeName.isNotEmpty == true
        ? loaneeAccount!.loaneeName
        : (user?.name ?? (loaneeEntries.isNotEmpty ? loaneeEntries.first.loaneeName : 'Loanee Account'));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Personal Loan Account Card with CustomerID & Account No
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (onNavigateToMenu != null) onNavigateToMenu(8);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B1A1A), Color(0xFF6B1414)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B1A1A).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
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
                                'MY LOAN ACCOUNT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade300,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loaneeDisplayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge_outlined, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'VIEW PROFILE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),

                // Customer ID & Account Number Details
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Customer ID',
                              style: TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              customerIdDisplay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Number',
                              style: TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              accountNoDisplay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),

                // Financial Balance Metrics: Loan Amount, Paid Amount, Remaining Due
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Loan Amount',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          '₹ ${realLoanAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.white24,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Paid',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          '₹ ${totalPaid.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.white24,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Remaining Due',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          '₹ ${latestRemainingBal.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.amber.shade300,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Auto-Calculated Payable & Late Fee Summary Row
                Builder(
                  builder: (context) {
                    final settings = Provider.of<SettingsProvider>(context, listen: false);
                    final primaryEntry = loaneeEntries.isNotEmpty ? loaneeEntries.first : null;

                    if (primaryEntry == null) return const SizedBox.shrink();

                    final breakdown = settings.getLatePayableBreakdownForEntry(
                      entry: primaryEntry,
                      payments: loaneePayments,
                      loaneeLoanAmount: realLoanAmount,
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 13, color: Colors.white70),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Base: ₹${breakdown.currentInstallment.toStringAsFixed(0)}/${primaryEntry.frequencyLabel}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(
                                    breakdown.isOverdue ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                    size: 13,
                                    color: breakdown.isOverdue ? Colors.amberAccent : Colors.lightGreenAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    breakdown.isOverdue
                                        ? 'Payable Today: ₹${breakdown.totalPayableAmount.toStringAsFixed(2)} (${breakdown.lateUnits}${primaryEntry.isDaily ? "d" : "w"} late)'
                                        : 'Payable Today: ₹${breakdown.totalPayableAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: breakdown.isOverdue ? Colors.amberAccent : Colors.lightGreenAccent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (breakdown.calculatedLateFine > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Late Payment Fee (${breakdown.lateUnits} ${breakdown.isDaily ? "days" : "weeks"} @ ₹${breakdown.lateFineRate.toStringAsFixed(0)}/${breakdown.isDaily ? "day" : "wk"}):',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                                Text(
                                  '₹ ${breakdown.calculatedLateFine.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),

                // Loan Sanction & Maturity Date Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sanction Date', style: TextStyle(color: Colors.white60, fontSize: 9.5)),
                              const SizedBox(height: 1),
                              Text(
                                loaneeAccount?.formattedSanctionDate ?? 'N/A',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(height: 24, width: 1, color: Colors.white24),
                          const Spacer(),
                          const Icon(Icons.event_available_rounded, size: 14, color: Colors.amberAccent),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Maturity Date', style: TextStyle(color: Colors.white60, fontSize: 9.5)),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade700,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text('5 Months', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                loaneeAccount?.formattedMaturityDate ?? 'N/A',
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (loaneeAccount?.isPastMaturity == true) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amberAccent),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amberAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Post-Maturity Alert: Loan has exceeded the maturity date. Under servicing policy, overdue interest is auto-applied on the unpaid remaining balance.',
                                  style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600, height: 1.25),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      const SizedBox(height: 16),

      // 2. Late Fine & Overdue Assessment Acknowledgment Card & Notification
      _LoaneeLateFineAcknowledgmentSection(
        user: user,
        loaneeAccount: loaneeAccount,
        loaneeEntries: loaneeEntries,
        loaneePayments: loaneePayments,
        onNavigateToMenu: onNavigateToMenu,
      ),

      const SizedBox(height: 20),

      // 3. Payment History Ledger with Date Filtering
      _LoaneeRepaymentHistorySection(user: user),
    ],
  ),
);
  }

  // ==========================================
  // ROUTE-WISE COLLECTION BAR CHART WIDGET
  // ==========================================
  Widget _buildRouteWiseCollectionChart(
    BuildContext context,
    CollectionSheetProvider collectionProvider,
  ) {
    final Map<String, double> routeTotals = {};

    // Dynamic master routes from Supabase route_master table
    for (var rObj in collectionProvider.routes) {
      if (rObj.name.trim().isNotEmpty) {
        routeTotals[rObj.name.trim()] = 0.0;
      }
    }

    // Dynamic routes from collection entries
    for (var entry in collectionProvider.collectionEntries) {
      if (entry.route.trim().isNotEmpty) {
        final rName = entry.route.trim();
        routeTotals[rName] = (routeTotals[rName] ?? 0.0) +
            collectionProvider.getTotalPaidForCollection(entry.id);
      }
    }

    final double maxVal = routeTotals.values
        .fold(0.0, (prev, curr) => curr > prev ? curr : prev);
    final double totalAllRoutes =
        routeTotals.values.fold(0.0, (sum, curr) => sum + curr);

    final List<Color> barColors = [
      Colors.teal.shade600,
      Colors.blue.shade600,
      Colors.amber.shade700,
      Colors.purple.shade600,
      Colors.deepOrange.shade600,
      Colors.indigo.shade600,
      Colors.green.shade600,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      color: Color(0xFF1E1E1E), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Route-Wise Collection Analytics',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),

            ],
          ),

          const SizedBox(height: 4),
          Text(
            'Collection amounts grouped by route zone',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          const Divider(height: 20),

          if (routeTotals.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.alt_route_rounded, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No Routes Created Yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add routes in Route Management to see route-wise analytics.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Vertical Column Bar Chart Layout
            SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: routeTotals.entries.toList().asMap().entries.map((mapEntry) {
                  final idx = mapEntry.key;
                  final routeName = mapEntry.value.key;
                  final amount = mapEntry.value.value;
                  final color = barColors[idx % barColors.length];
                  final ratio = maxVal > 0 ? (amount / maxVal) : 0.0;
                  final barHeight = 115.0 * ratio.clamp(0.06, 1.0);
                  final percentShare = totalAllRoutes > 0 ? (amount / totalAllRoutes * 100) : 0.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Amount & % Label on Top of Vertical Bar
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              amount >= 1000
                                  ? '₹ ${(amount / 1000).toStringAsFixed(1)}k'
                                  : '₹ ${amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            '${percentShare.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Vertical Bar Track
                          Container(
                            height: 115,
                            width: double.infinity,
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              height: barHeight,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color.withOpacity(0.65), color],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // X-Axis Route Label
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  routeName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Total Route Summary Footer Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Route Collection:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹ ${totalAllRoutes.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B1A1A),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
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

  Widget _buildROScheduleCard(
    CollectionSheetProvider collectionProvider,
    RoProvider roProvider,
    String assignedRoute,
    User? user,
    RoAccount? roAccount,
  ) {
    final cleanUserName = (user?.name ?? '').toLowerCase().trim();
    final cleanUserCustId = (user?.customerId ?? '').toLowerCase().trim();
    final cleanUserMobile = (user?.mobileNo ?? '').trim();
    final cleanRoName = (roAccount?.roName ?? '').toLowerCase().trim();
    final cleanRoCustId = (roAccount?.customerId ?? '').toLowerCase().trim();
    final cleanRoMobile = (roAccount?.mobileNo ?? '').trim();
    final cleanRoute = assignedRoute.toLowerCase().trim();

    bool isPaymentForThisRo(CollectionPaymentModel p) {
      final pRoName = (p.roName ?? '').toLowerCase().trim();
      final pRoId = (p.roId ?? '').toLowerCase().trim();
      final pRoRoute = (p.roRoute ?? '').toLowerCase().trim();

      // 1. Direct ID match
      if (cleanUserCustId.isNotEmpty && pRoId == cleanUserCustId) return true;
      if (cleanRoCustId.isNotEmpty && pRoId == cleanRoCustId) return true;
      if (cleanUserMobile.isNotEmpty && pRoId == cleanUserMobile) return true;
      if (cleanRoMobile.isNotEmpty && pRoId == cleanRoMobile) return true;

      // 2. Direct Name match
      if (cleanUserName.isNotEmpty &&
          cleanUserName != 'ro officer' &&
          cleanUserName != 'field officer' &&
          pRoName == cleanUserName) {
        return true;
      }
      if (cleanRoName.isNotEmpty &&
          cleanRoName != 'ro officer' &&
          cleanRoName != 'field officer' &&
          pRoName == cleanRoName) {
        return true;
      }

      // 3. Explicit check: If this payment is tagged with another RO officer's ID or name, reject it!
      if (pRoId.isNotEmpty) return false;
      if (pRoName.isNotEmpty &&
          pRoName != 'ro officer' &&
          pRoName != 'field officer' &&
          pRoName != 'officer') {
        return false;
      }

      // 4. Route match if assigned specific route
      if (cleanRoute.isNotEmpty &&
          cleanRoute != 'all routes / general' &&
          cleanRoute != 'all routes' &&
          cleanRoute != 'all') {
        if (pRoRoute == cleanRoute) return true;
        final card = collectionProvider.getCardForPayment(p);
        if (card != null && card.route.toLowerCase().trim() == cleanRoute) return true;
      }

      return false;
    }

    // All historical collection payment entries recorded strictly by this logged-in RO (deduplicated)
    final rawRoPayments = collectionProvider.payments
        .where(isPaymentForThisRo)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final seenPaymentKeys = <String>{};
    final roPayments = <CollectionPaymentModel>[];
    for (final p in rawRoPayments) {
      final key = p.id.isNotEmpty
          ? p.id
          : '${p.collectionId}_${p.createdAt.millisecondsSinceEpoch}';
      if (!seenPaymentKeys.contains(key)) {
        seenPaymentKeys.add(key);
        roPayments.add(p);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Sheet Entries",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B1A1A),
                ),
              ),
              Text(
                '${roPayments.length} Entries',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (roPayments.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No collection sheet entries recorded by your account yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: roPayments.length > 8 ? 8 : roPayments.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final payment = roPayments[index];
                final card = collectionProvider.getCardForPayment(payment);
                final loaneeName = card?.loaneeName ??
                    (payment.remarks?.isNotEmpty == true ? payment.remarks! : 'Loanee Collection');
                final routeName = (payment.roRoute != null && payment.roRoute!.isNotEmpty)
                    ? payment.roRoute!
                    : (card?.route ?? (assignedRoute.isNotEmpty ? assignedRoute : 'General'));
                final accNo = card?.accountNumber ?? (card?.customerId ?? 'N/A');
                final dateStr =
                    '${payment.createdAt.day.toString().padLeft(2, '0')}/${payment.createdAt.month.toString().padLeft(2, '0')}/${payment.createdAt.year}';

                final bool isCrossRoute = assignedRoute.isNotEmpty &&
                    assignedRoute != 'All Routes / General' &&
                    routeName.isNotEmpty &&
                    routeName.toLowerCase().trim() !=
                        assignedRoute.toLowerCase().trim();

                return _buildScheduleItem(
                  name: loaneeName,
                  location: 'Route: $routeName • Acc #$accNo • $dateStr',
                  amount: '₹ ${payment.paymentAmount.toStringAsFixed(2)}',
                  status: '${payment.paymentType} • ${payment.status}',
                  statusColor: payment.status.toLowerCase() == 'success'
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                  isCrossRoute: isCrossRoute,
                  assignedRoute: assignedRoute,
                  entryRoute: routeName,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleItem({
    required String name,
    required String location,
    required String amount,
    required String status,
    required Color statusColor,
    bool isCrossRoute = false,
    String assignedRoute = '',
    String entryRoute = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on_rounded, color: statusColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(location,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF8B1A1A))),
                Text(status,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              ],
            ),
          ],
        ),
        if (isCrossRoute) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.deepPurple.shade200),
            ),
            child: Text(
              '⚡ Cross-Route Entry (Your Route: $assignedRoute)',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade900,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getRoleTitle(UserType role) {
    switch (role) {
      case UserType.admin:
        return 'Executive Admin ';
      case UserType.manager:
        return 'Manager Monitoring';
      case UserType.ro:
        return 'RO Officer';
      case UserType.loanee:
        return 'Loanee Account';
    }
  }
}

/// =========================================================
/// DEDICATED LOANEE LATE FINE & OVERDUE ACKNOWLEDGMENT SECTION
/// =========================================================
class _LoaneeLateFineAcknowledgmentSection extends StatefulWidget {
  final User? user;
  final LoaneeAccount? loaneeAccount;
  final List<RoCollectionEntry> loaneeEntries;
  final List<CollectionPaymentModel> loaneePayments;
  final Function(int)? onNavigateToMenu;

  const _LoaneeLateFineAcknowledgmentSection({
    required this.user,
    required this.loaneeAccount,
    required this.loaneeEntries,
    required this.loaneePayments,
    this.onNavigateToMenu,
  });

  @override
  State<_LoaneeLateFineAcknowledgmentSection> createState() =>
      _LoaneeLateFineAcknowledgmentSectionState();
}

class _LoaneeLateFineAcknowledgmentSectionState
    extends State<_LoaneeLateFineAcknowledgmentSection> {
  bool _isAcknowledged = false;
  String? _acknowledgmentIsoTime;
  bool _hasCheckedAck = false;
  bool _modalAutoShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndPromptAcknowledgment();
  }

  @override
  void didUpdateWidget(covariant _LoaneeLateFineAcknowledgmentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.customerId != widget.user?.customerId ||
        oldWidget.loaneePayments.length != widget.loaneePayments.length) {
      _checkAndPromptAcknowledgment();
    }
  }

  Future<void> _checkAndPromptAcknowledgment() async {
    final customerId = _resolveCustomerId();
    if (customerId.isEmpty) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final acknowledged = await settings.isFineAcknowledgedToday(customerId);
    final timeStr = await settings.getAcknowledgmentTimestamp(customerId);

    if (mounted) {
      setState(() {
        _isAcknowledged = acknowledged;
        _acknowledgmentIsoTime = timeStr;
        _hasCheckedAck = true;
      });

      // If fine is accrued or past maturity date, and not yet acknowledged today, auto-prompt the Loanee
      final status = _calculateStatus(settings);
      final bool hasOverdueOrPostMaturity = status.calculatedLateFine > 0 || status.isPastMaturity;
      if (hasOverdueOrPostMaturity && !acknowledged && !_modalAutoShown) {
        _modalAutoShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showLoaneeFineAcknowledgmentModal(context, status, settings);
          }
        });
      }
    }
  }

  String _resolveCustomerId() {
    if (widget.user?.customerId != null && widget.user!.customerId!.isNotEmpty) {
      return widget.user!.customerId!;
    }
    if (widget.loaneeAccount != null && widget.loaneeAccount!.customerId.isNotEmpty) {
      return widget.loaneeAccount!.customerId;
    }
    if (widget.loaneeEntries.isNotEmpty) {
      return widget.loaneeEntries.first.customerId;
    }
    return widget.user?.mobileNo ?? '';
  }

  LoaneeLateFineStatus _calculateStatus(SettingsProvider settings) {
    final customerId = _resolveCustomerId();
    final name = widget.loaneeAccount?.loaneeName ??
        (widget.user?.name ?? (widget.loaneeEntries.isNotEmpty ? widget.loaneeEntries.first.loaneeName : 'Loanee Account'));
    final accNo = widget.loaneeAccount?.accountNumber ??
        (widget.loaneeEntries.isNotEmpty ? widget.loaneeEntries.map((e) => e.accountNumber).toSet().join(', ') : 'N/A');
    final fallbackStart = widget.loaneeAccount?.loansanctiondate ?? widget.loaneeAccount?.createdAt ?? DateTime.now();
    final fallbackMaturity = widget.loaneeAccount?.loanmaturitydate;
    final fallbackLoanAmt = widget.loaneeAccount?.loanAmount ?? 0.0;
    final fallbackDueAmt = widget.loaneeAccount?.dueAmount ?? 0.0;

    return settings.getAggregateLateFineStatus(
      entries: widget.loaneeEntries,
      payments: widget.loaneePayments,
      customerId: customerId,
      loaneeName: name,
      accountNumber: accNo,
      fallbackStartDate: fallbackStart,
      fallbackMaturityDate: fallbackMaturity,
      fallbackLoanAmount: fallbackLoanAmt,
      fallbackDueAmount: fallbackDueAmt,
    );
  }

  Future<void> _handleAcknowledge(LoaneeLateFineStatus status, SettingsProvider settings) async {
    final customerId = _resolveCustomerId();
    if (customerId.isEmpty) return;

    await settings.acknowledgeFineForToday(customerId);
    final now = DateTime.now();

    if (mounted) {
      setState(() {
        _isAcknowledged = true;
        _acknowledgmentIsoTime = now.toIso8601String();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.green.shade800,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Late Fine Assessment Acknowledged',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Notice for ${status.collectionType} scheme recorded on ${SettingsProvider.formatDate(now)}.',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  String _formatAckTimestamp(String? iso) {
    if (iso == null) return 'Today';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Today';
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${SettingsProvider.formatDate(dt)} at $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final status = _calculateStatus(settings);
    final hasFine = status.calculatedLateFine > 0;
    final isDaily = status.isDaily;

    final primaryThemeColor = hasFine ? const Color(0xFF8B1A1A) : Colors.teal.shade800;
    final cardBgColor = Colors.white;
    final cardBorderColor = hasFine
        ? (_isAcknowledged ? Colors.grey.shade300 : const Color(0xFF8B1A1A).withValues(alpha: 0.35))
        : Colors.teal.shade200;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor, width: hasFine && !_isAcknowledged ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: hasFine
                ? const Color(0xFF8B1A1A).withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasFine
                    ? [const Color(0xFF8B1A1A), const Color(0xFF6B1414)]
                    : [Colors.teal.shade800, Colors.teal.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasFine ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                      color: hasFine ? Colors.amber.shade300 : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LATE FINE & OVERDUE STATUS',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDaily ? Icons.calendar_today_rounded : Icons.date_range_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDaily
                            ? 'DAILY (₹${settings.dailyLateFine.toStringAsFixed(0)}/day)'
                            : 'WEEKLY (₹${settings.weeklyLateFine.toStringAsFixed(0)}/wk)',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Database ro_collection_payments Table Status Pill
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: status.hasPaymentsInTable
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: status.hasPaymentsInTable
                          ? Colors.green.shade200
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status.hasPaymentsInTable
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 14,
                        color: status.hasPaymentsInTable
                            ? Colors.green.shade800
                            : Colors.orange.shade900,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          status.hasPaymentsInTable
                              ? 'Last Records: ${status.paymentRecordsCount} payment entries found (Last: ${SettingsProvider.formatDate(status.lastPaymentDate!)})'
                              : 'Last Records: No payment entries found in database table (Start: ${SettingsProvider.formatDate(status.loanStartDate)})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: status.hasPaymentsInTable
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Grid of Assessment Metrics
                Row(
                  children: [
                    // Scheme Type Box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Loan Scheme',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              status.collectionType,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isDaily ? 'Daily Schedule' : '₹${settings.weeklyInstallmentAmount.toStringAsFixed(0)}/wk scheme',
                              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Overdue Duration Box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: status.overdueUnits > 0 ? Colors.red.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: status.overdueUnits > 0 ? Colors.red.shade200 : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDaily ? 'Overdue Days' : 'Overdue Weeks',
                              style: TextStyle(
                                fontSize: 10,
                                color: status.overdueUnits > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${status.overdueUnits} ${isDaily ? 'Days' : 'Weeks'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: status.overdueUnits > 0 ? Colors.red.shade800 : Colors.black87,
                              ),
                            ),
                            Text(
                              status.overdueUnits > 0 ? 'Penalty Accruing' : 'Up to Date',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: status.overdueUnits > 0 ? Colors.red.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Late Fine Rate Box (Admin Settings)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fine Rate',
                              style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '₹${status.lateFineRate.toStringAsFixed(0)}/${isDaily ? 'day' : 'wk'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            Text(
                              'Admin Config',
                              style: TextStyle(fontSize: 9.5, color: Colors.amber.shade800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 4. Mathematical Calculation Explanation Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.calculate_outlined, size: 16, color: primaryThemeColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calculation Method',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.calculationExplanation,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (status.postMaturityBreakdown != null && status.postMaturityBreakdown!.isPastMaturity) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade400, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'POST-MATURITY OVERDUE INTEREST NOTICE',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Maturity date (${SettingsProvider.formatDate(status.postMaturityBreakdown!.maturityDate)}) exceeded (${status.postMaturityBreakdown!.overdueMonths} month(s) overdue). Under terms, overdue interest applies strictly on completed month basis.',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Unpaid Remaining Balance:', style: TextStyle(fontSize: 10.5, color: Colors.black87)),
                                  Text('₹ ${status.postMaturityBreakdown!.remainingBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Standard Rate (5m Tenure):', style: TextStyle(fontSize: 10.5, color: Colors.black54)),
                                  Text('${status.postMaturityBreakdown!.normalInterestRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Overdue Interest Status:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                                  Text('Active (${status.postMaturityBreakdown!.overdueMonths > 0 ? "${status.postMaturityBreakdown!.overdueMonths}m " : ""}Compounded)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Accrued Overdue Interest:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A))),
                                  Text('₹ ${status.postMaturityBreakdown!.postMaturityInterestAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A))),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Payable (Due + Interest):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                                  Text('₹ ${status.postMaturityBreakdown!.postMaturityPayableAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // 5. Total Financial Summary Row (Late Fine vs Total Overdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: hasFine ? const Color(0xFF8B1A1A).withValues(alpha: 0.06) : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasFine ? const Color(0xFF8B1A1A).withValues(alpha: 0.25) : Colors.teal.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Late Fine Penalty',
                            style: TextStyle(
                              fontSize: 11,
                              color: hasFine ? Colors.red.shade900 : Colors.teal.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹ ${status.calculatedLateFine.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: hasFine ? const Color(0xFF8B1A1A) : Colors.teal.shade900,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 28, width: 1, color: Colors.grey.shade300),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isDaily ? 'Total Overdue Fine' : 'Total Overdue (EMI + Fine)',
                            style: TextStyle(
                              fontSize: 11,
                              color: hasFine ? Colors.red.shade900 : Colors.teal.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹ ${status.totalOverdueAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: hasFine ? const Color(0xFF8B1A1A) : Colors.teal.shade900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 6. Acknowledgment Action & Status Strip
                if (hasFine) ...[
                  if (_isAcknowledged)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Colors.green.shade800, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Acknowledged by Loanee',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                                Text(
                                  _formatAckTimestamp(_acknowledgmentIsoTime),
                                  style: TextStyle(fontSize: 10, color: Colors.green.shade800),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green.shade900,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              _showLoaneeFineAcknowledgmentModal(context, status, settings);
                            },
                            child: const Text('View Notice', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_active_outlined, size: 14, color: Colors.amber.shade900),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Notice unacknowledged. Please acknowledge your overdue fine assessment.',
                                  style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B1A1A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  await _handleAcknowledge(status, settings);
                                },
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: const Text(
                                  'Acknowledge Notice',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF8B1A1A),
                                  side: const BorderSide(color: Color(0xFF8B1A1A)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  _showLoaneeFineAcknowledgmentModal(context, status, settings);
                                },
                                child: const Text(
                                  'Breakdown',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ] else ...[
                  // Up to date banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.teal.shade800, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Account in good standing! No overdue late fines accrued.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive Modal Dialog / Bottom Sheet for Loanee Acknowledgment
  void _showLoaneeFineAcknowledgmentModal(
    BuildContext context,
    LoaneeLateFineStatus status,
    SettingsProvider settings,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Modal Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.gavel_rounded,
                                color: Color(0xFF8B1A1A),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Overdue Notice & Acknowledgment',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B1A1A),
                                  ),
                                ),
                                Text(
                                  'Official assessment under Admin Late Fine Rules',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Loanee Account Particulars Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildModalInfoRow('Loanee Name', status.loaneeName),
                          const SizedBox(height: 6),
                          _buildModalInfoRow('Customer ID', status.customerId),
                          const SizedBox(height: 6),
                          _buildModalInfoRow('Account Number', status.accountNumber),
                          const SizedBox(height: 6),
                          _buildModalInfoRow(
                            'Collection Scheme',
                            '${status.collectionType} (${status.isDaily ? "Daily" : "Weekly ₹${settings.weeklyInstallmentAmount.toStringAsFixed(0)}/wk"})',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ro_collection_payments Table Status Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: status.hasPaymentsInTable ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: status.hasPaymentsInTable ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status.hasPaymentsInTable ? Icons.storage_rounded : Icons.search_off_rounded,
                            size: 16,
                            color: status.hasPaymentsInTable ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status.hasPaymentsInTable
                                  ? 'Supabase Table "ro_collection_payments": Data found (${status.paymentRecordsCount} records, Total Paid: ₹${status.totalPaidAmount.toStringAsFixed(2)})'
                                  : 'Supabase Table "ro_collection_payments": No payment entries recorded for this account since ${SettingsProvider.formatDate(status.loanStartDate)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: status.hasPaymentsInTable ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Detailed Calculation Breakdown Table
                    const Text(
                      'Assessment Calculation Breakdown',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          _buildBreakdownItem(
                            'Base Installment (${status.isDaily ? 'Daily' : 'Weekly'})',
                            '₹ ${(status.latePayableBreakdown?.baseInstallment ?? (status.isDaily ? 100.0 : 650.0)).toStringAsFixed(2)} / ${status.isDaily ? 'day' : 'wk'}',
                          ),
                          const Divider(height: 1),
                          _buildBreakdownItem(
                            'Late Elapsed Duration',
                            '${status.overdueUnits} ${status.isDaily ? (status.overdueUnits == 1 ? "Late Day" : "Late Days") : (status.overdueUnits == 1 ? "Late Week" : "Late Weeks")}',
                          ),
                          if (status.overdueUnits > 0) ...[
                            const Divider(height: 1),
                            _buildBreakdownItem(
                              'Missed Overdue Installments (${status.overdueUnits} × ₹${(status.latePayableBreakdown?.baseInstallment ?? (status.isDaily ? 100.0 : 650.0)).toStringAsFixed(0)})',
                              '₹ ${(status.latePayableBreakdown?.overdueMissedAmount ?? (status.overdueUnits * (status.isDaily ? 100.0 : 650.0))).toStringAsFixed(2)}',
                              valueColor: Colors.red.shade800,
                            ),
                          ],
                          const Divider(height: 1),
                          _buildBreakdownItem(
                            'Today\'s Scheduled Installment',
                            '₹ ${(status.latePayableBreakdown?.currentInstallment ?? (status.isDaily ? 100.0 : 650.0)).toStringAsFixed(2)}',
                            valueColor: Colors.teal.shade800,
                          ),
                          if (status.postMaturityBreakdown != null && status.postMaturityBreakdown!.isPastMaturity) ...[
                            const Divider(height: 1),
                            _buildBreakdownItem(
                              'Overdue Interest Status',
                              'Active Overdue Compounding',
                              valueColor: Colors.red.shade900,
                              isBold: true,
                            ),
                            const Divider(height: 1),
                            _buildBreakdownItem(
                              'Unpaid Remaining Balance',
                              '₹ ${status.postMaturityBreakdown!.remainingBalance.toStringAsFixed(2)}',
                              valueColor: const Color(0xFF8B1A1A),
                              isBold: true,
                            ),
                            const Divider(height: 1),
                            _buildBreakdownItem(
                              'Accrued Overdue Interest',
                              '₹ ${status.postMaturityBreakdown!.postMaturityInterestAmount.toStringAsFixed(2)}',
                              valueColor: Colors.red.shade900,
                              isBold: true,
                            ),
                          ],
                          const Divider(height: 1),
                          _buildBreakdownItem(
                            'Late Payment Fine Rate',
                            '₹ ${status.lateFineRate.toStringAsFixed(2)} / ${status.isDaily ? 'day' : 'wk'}',
                          ),
                          const Divider(height: 1),
                          _buildBreakdownItem(
                            'System Late Payment Fine Penalty',
                            '₹ ${status.calculatedLateFine.toStringAsFixed(2)}',
                            valueColor: Colors.red.shade800,
                            isBold: true,
                          ),
                          const Divider(height: 1),
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Auto-Calculated Payable',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8B1A1A)),
                                    ),
                                    Text(
                                      '₹ ${(status.latePayableBreakdown?.totalPayableAmount ?? (status.totalOverdueAmount)).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF8B1A1A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  status.latePayableBreakdown?.explanation ?? status.calculationExplanation,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Legal / Servicing Acknowledgment Disclaimer
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 15, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status.isPastMaturity
                                  ? 'Acknowledgment Notice: Your loan exceeded the 5-month maturity period. Under Mangang Finance servicing terms, overdue interest is automatically applied to your unpaid remaining balance.'
                                  : 'By clicking acknowledge below, you verify you have viewed and accepted your account overdue notice, late fine penalty, and payment calculations under Mangang Finance terms.',
                              style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B1A1A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _handleAcknowledge(status, settings);
                            },
                            icon: const Icon(Icons.check_circle_rounded, size: 18),
                            label: const Text(
                              'I Acknowledge Notice',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(
    String title,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Date-Filtered Repayment History Section for Loanees
class _LoaneeRepaymentHistorySection extends StatefulWidget {
  final User? user;

  const _LoaneeRepaymentHistorySection({required this.user});

  @override
  State<_LoaneeRepaymentHistorySection> createState() =>
      _LoaneeRepaymentHistorySectionState();
}

class _LoaneeRepaymentHistorySectionState
    extends State<_LoaneeRepaymentHistorySection> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);
    final loaneeEntries = collectionProvider.getEntriesForLoanee(
      widget.user?.mobileNo ?? '',
      widget.user?.name ?? '',
      widget.user?.customerId ?? '',
    );
    final allPayments = collectionProvider.getPaymentsForEntries(loaneeEntries);

    final filteredPayments = allPayments.where((p) {
      if (_selectedDate != null) {
        return p.createdAt.year == _selectedDate!.year &&
            p.createdAt.month == _selectedDate!.month &&
            p.createdAt.day == _selectedDate!.day;
      }
      return true;
    }).toList();

    final double totalFilteredPaid =
        filteredPayments.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final double totalFilteredFine =
        filteredPayments.fold(0.0, (sum, p) => sum + p.lateFine);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title and Small Calendar Date Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, color: Color(0xFF8B1A1A), size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Payment History',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B1A1A),
                    ),
                  ),
                ],
              ),

              // Small Calendar Picker Button
              _buildSmallCalendarButton(context),
            ],
          ),
          const SizedBox(height: 12),

          // Active Date Filter Banner
          if (_selectedDate != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_available_rounded,
                          size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Text(
                        'Date: ${_formatDate(_selectedDate!)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close,
                              size: 11, color: Colors.amber.shade900),
                          const SizedBox(width: 2),
                          Text(
                            'Show All',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Summary Mini Banner
          if (filteredPayments.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredPayments.length} Payments • Paid: ₹ ${totalFilteredPaid.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  if (totalFilteredFine > 0)
                    Text(
                      'Fine: ₹ ${totalFilteredFine.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (filteredPayments.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy_rounded,
                        size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      _selectedDate == null
                          ? 'No payment records found for your account.'
                          : 'No payments found on ${_formatDate(_selectedDate!)}.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedDate != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedDate = null;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Show All Payments',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredPayments.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final p = filteredPayments[index];
                final officerName = (p.roName != null && p.roName!.isNotEmpty)
                    ? p.roName!
                    : 'Officer';
                RoCollectionEntry? entry;
                for (final e in loaneeEntries) {
                  if (e.id == p.collectionId) {
                    entry = e;
                    break;
                  }
                }
                entry ??= collectionProvider.getCollectionEntryById(p.collectionId);
                final routeName = (entry != null && entry.route.isNotEmpty)
                    ? entry.route
                    : '';

                return _buildPaymentRow(
                  date: p.createdAt.toString().split('.')[0],
                  amount: '₹ ${p.paymentAmount.toStringAsFixed(2)}',
                  method: p.isAdminOrOfficeEntry
                      ? 'Recorded by Admin ($officerName) • Mode: ${p.paymentType}'
                      : 'Collected By: $officerName • Mode: ${p.paymentType}',
                  routeName: routeName,
                  lateFine: p.lateFine,
                  isAdminEntry: p.isAdminOrOfficeEntry,
                  isSuccess: true,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // Small Calendar Date Picker Button
  Widget _buildSmallCalendarButton(BuildContext context) {
    final hasDate = _selectedDate != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF8B1A1A),
                    onPrimary: Colors.white,
                    onSurface: Colors.black87,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null) {
            setState(() {
              _selectedDate = picked;
            });
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: hasDate ? const Color(0xFF8B1A1A) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasDate ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 14,
                color: hasDate ? Colors.white : const Color(0xFF8B1A1A),
              ),
              const SizedBox(width: 4),
              Text(
                hasDate ? _formatDate(_selectedDate!) : 'Pick Date',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: hasDate ? Colors.white : Colors.grey.shade800,
                ),
              ),
              if (hasDate) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = null;
                    });
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildPaymentRow({
    required String date,
    required String amount,
    required String method,
    required String routeName,
    required double lateFine,
    bool isAdminEntry = false,
    required bool isSuccess,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(date,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    if (routeName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alt_route_rounded,
                                size: 10, color: Colors.blue.shade800),
                            const SizedBox(width: 3),
                            Text(
                              routeName,
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
                    if (isAdminEntry) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF8B1A1A).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded,
                                size: 10, color: Color(0xFF8B1A1A)),
                            SizedBox(width: 3),
                            Text(
                              'ADMIN / OFFICE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(method,
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                if (lateFine > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Late Fine: ₹ ${lateFine.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B1A1A),
                fontSize: 13,
              ),
            ),
            if (lateFine > 0)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  '+ Fine ₹${lateFine.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// =========================================================
// ADMIN ALL COLLECTIONS & PAYMENT DONE LEDGER (ALL ROUTES)
// =========================================================
class _AdminAllCollectionsLedgerSection extends StatefulWidget {
  final CollectionSheetProvider collectionProvider;

  const _AdminAllCollectionsLedgerSection({
    required this.collectionProvider,
  });

  @override
  State<_AdminAllCollectionsLedgerSection> createState() =>
      _AdminAllCollectionsLedgerSectionState();
}

class _AdminAllCollectionsLedgerSectionState
    extends State<_AdminAllCollectionsLedgerSection> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDateFilter = 'All'; // All, Today, Yesterday, This Week, This Month, Custom
  DateTime? _selectedCustomDate;
  int _currentPage = 1;
  int _rowsPerPage = 5; // Default 5 records per page

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesDateFilter(DateTime dt) {
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case 'Today':
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        return dt.year == yesterday.year &&
            dt.month == yesterday.month &&
            dt.day == yesterday.day;
      case 'This Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return dt.isAfter(weekAgo);
      case 'This Month':
        return dt.year == now.year && dt.month == now.month;
      case 'Custom':
        if (_selectedCustomDate == null) return true;
        return dt.year == _selectedCustomDate!.year &&
            dt.month == _selectedCustomDate!.month &&
            dt.day == _selectedCustomDate!.day;
      case 'All':
      default:
        return true;
    }
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20),
              onPrimary: Colors.white,
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
        _currentPage = 1;
      });
    }
  }

  void _showPaymentReceiptDialog(
    BuildContext context,
    CollectionPaymentModel payment,
    RoCollectionEntry? card,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Receipt Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModalSectionHeader('LOANEE & ROUTE PARTICULARS'),
              _buildReceiptRow('Loanee Name', card?.loaneeName ?? 'N/A', Icons.person_rounded),
              _buildReceiptRow('Customer ID', card?.customerId ?? 'N/A', Icons.badge_outlined),
              _buildReceiptRow('Account Number', card?.accountNumber ?? 'N/A', Icons.account_balance_wallet_outlined),
              _buildReceiptRow('Card Route', card?.route ?? 'N/A', Icons.alt_route_rounded),
              _buildReceiptRow('Collection Type', card?.collectionType ?? 'N/A', Icons.schedule_rounded),
              if (card != null && card.mobileNo.isNotEmpty)
                _buildReceiptRow('Mobile Number', card.mobileNo, Icons.phone_android_rounded),

              const Divider(height: 20),
              _buildModalSectionHeader('PAYMENT TRANSACTION PARTICULARS'),
              _buildReceiptRow('Transaction ID', payment.id, Icons.tag_rounded),
              _buildReceiptRow('Payment Amount', '₹ ${payment.paymentAmount.toStringAsFixed(2)}', Icons.currency_rupee_rounded, valueColor: Colors.green.shade800),
              _buildReceiptRow('Remaining Due Balance', '₹ ${payment.remainingBalance.toStringAsFixed(2)}', Icons.money_off_rounded, valueColor: Colors.orange.shade900),
              if (payment.lateFine > 0)
                _buildReceiptRow('Late Fine Paid', '₹ ${payment.lateFine.toStringAsFixed(2)}', Icons.timer_off_outlined, valueColor: Colors.red.shade700),
              _buildReceiptRow('Payment Mode', payment.paymentType, Icons.payment_rounded),
              _buildReceiptRow('Transaction Date', payment.createdAt.toString().split('.')[0], Icons.calendar_today_outlined),
              _buildReceiptRow('Payment Status', payment.status, Icons.verified_user_outlined, valueColor: Colors.green.shade700),

              const Divider(height: 20),
              _buildModalSectionHeader('OFFICER / ADMIN ATTRIBUTION'),
              _buildReceiptRow(
                payment.isAdminOrOfficeEntry ? 'Recorded By' : 'Collected By RO',
                payment.recordedByDisplayName,
                payment.isAdminOrOfficeEntry ? Icons.shield_rounded : Icons.badge_rounded,
                valueColor: payment.isAdminOrOfficeEntry ? const Color(0xFF8B1A1A) : null,
              ),
              if (payment.roId != null && payment.roId!.isNotEmpty)
                _buildReceiptRow(payment.isAdminOrOfficeEntry ? 'Admin ID' : 'RO ID', payment.roId!, Icons.fingerprint_rounded),
              if (payment.roRoute != null && payment.roRoute!.isNotEmpty)
                _buildReceiptRow('Route Zone', payment.roRoute!, Icons.alt_route_rounded),
              if (payment.remarks != null && payment.remarks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: payment.isAdminOrOfficeEntry
                        ? const Color(0xFF8B1A1A).withValues(alpha: 0.08)
                        : Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: payment.isAdminOrOfficeEntry
                          ? const Color(0xFF8B1A1A).withValues(alpha: 0.25)
                          : Colors.deepPurple.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        payment.isAdminOrOfficeEntry ? Icons.shield_rounded : Icons.alt_route_rounded,
                        size: 14,
                        color: payment.isAdminOrOfficeEntry ? const Color(0xFF8B1A1A) : Colors.deepPurple.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          payment.remarks!,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: payment.isAdminOrOfficeEntry ? const Color(0xFF8B1A1A) : Colors.deepPurple.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (payment.roRoute != null &&
                  payment.roRoute!.isNotEmpty &&
                  card != null &&
                  card.route.isNotEmpty &&
                  payment.roRoute!.toLowerCase().trim() != card.route.toLowerCase().trim()) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.alt_route_rounded, size: 14, color: Colors.deepPurple.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '⚡ Cross-Route: RO from "${payment.roRoute}" collected for "${card.route}"',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B5E20),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
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
    final allPayments = widget.collectionProvider.payments;

    final filteredPayments = allPayments.where((p) {
      final card = widget.collectionProvider.getCardForPayment(p);
      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          (card?.loaneeName.toLowerCase().contains(query) ?? false) ||
          (card?.customerId.toLowerCase().contains(query) ?? false) ||
          (card?.accountNumber.toLowerCase().contains(query) ?? false) ||
          (card?.route.toLowerCase().contains(query) ?? false) ||
          (p.roName?.toLowerCase().contains(query) ?? false) ||
          (p.roRoute?.toLowerCase().contains(query) ?? false) ||
          (p.paymentType.toLowerCase().contains(query));

      final matchesDate = _matchesDateFilter(p.createdAt);

      return matchesSearch && matchesDate;
    }).toList();

    final double totalFilteredAmount =
        filteredPayments.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final double totalFilteredLateFine =
        filteredPayments.fold(0.0, (sum, p) => sum + p.lateFine);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Color(0xFF1B5E20), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'All Collection & Payment Ledger',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
             
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Complete live collection & repayment ledger with officer attribution across all routes',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),

          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Loanee Name, Cust ID, Acc No, Route, RO...',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _currentPage = 1;
              });
            },
          ),
          const SizedBox(height: 10),

          // Date Filter Chips
          Row(
            children: [
              const Text(
                'Date: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDateChip('All'),
                      const SizedBox(width: 5),
                      _buildDateChip('Today'),
                      const SizedBox(width: 5),
                      _buildDateChip('Yesterday'),
                      const SizedBox(width: 5),
                      _buildDateChip('This Week'),
                      const SizedBox(width: 5),
                      _buildDateChip('This Month'),
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => _pickCustomDate(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _selectedDateFilter == 'Custom'
                                ? const Color(0xFF1B5E20)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedDateFilter == 'Custom'
                                  ? const Color(0xFF1B5E20)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 12,
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
                                  fontSize: 10.5,
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
          const SizedBox(height: 12),

          // Total Summary Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtered Collection (${filteredPayments.length} Entries)',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '₹ ${totalFilteredAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                if (totalFilteredLateFine > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Late Fine Total',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '₹ ${totalFilteredLateFine.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Transactions Table / Card List
          if (filteredPayments.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No Collections Found',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No collection payments match the selected date or search filter.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Builder(
              builder: (context) {
                final int totalCount = filteredPayments.length;
                final int totalPages = totalCount > 0 ? (totalCount / _rowsPerPage).ceil() : 1;
                if (_currentPage > totalPages) {
                  _currentPage = totalPages;
                }
                if (_currentPage < 1) {
                  _currentPage = 1;
                }

                final int startIndex = (_currentPage - 1) * _rowsPerPage;
                final int endIndex = min(startIndex + _rowsPerPage, totalCount);
                final List<CollectionPaymentModel> pagedPayments = totalCount > 0
                    ? filteredPayments.sublist(startIndex, endIndex)
                    : [];

                return Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pagedPayments.length,
                      itemBuilder: (ctx, index) {
                        final payment = pagedPayments[index];
                        final card = widget.collectionProvider.getCardForPayment(payment);
                        final cardRoute = card?.route ?? '';
                        final roRoute = payment.roRoute ?? '';
                        final isCrossRoute = roRoute.isNotEmpty &&
                            cardRoute.isNotEmpty &&
                            roRoute.toLowerCase().trim() != cardRoute.toLowerCase().trim();

                        final roDisplay = (payment.roName != null && payment.roName!.isNotEmpty)
                            ? payment.roName!
                            : 'Field Officer';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: Loanee & Route Header
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.green.shade50,
                                    child: Icon(Icons.arrow_downward_rounded,
                                        color: Colors.green.shade800, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card?.loaneeName ?? 'Card #${payment.collectionId}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E1E1E),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Cust: ${card?.customerId ?? 'N/A'} • Acc: ${card?.accountNumber ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹ ${payment.paymentAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                      if (payment.lateFine > 0)
                                        Text(
                                          'Fine: ₹${payment.lateFine.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Row 2: Badges (Route, Mode, Remaining Due)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.amber.shade200),
                                    ),
                                    child: Text(
                                      'Route: $cardRoute',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Text(
                                      payment.paymentType,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Due: ₹ ${payment.remainingBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 14),

                              // Row 3: Officer Attribution & Cross-Route Notice
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: payment.isAdminOrOfficeEntry
                                          ? const Color(0xFF8B1A1A).withValues(alpha: 0.1)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: payment.isAdminOrOfficeEntry
                                            ? const Color(0xFF8B1A1A).withValues(alpha: 0.3)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          payment.isAdminOrOfficeEntry ? Icons.shield_rounded : Icons.person_outline_rounded,
                                          size: 12,
                                          color: payment.isAdminOrOfficeEntry ? const Color(0xFF8B1A1A) : Colors.grey.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          payment.isAdminOrOfficeEntry ? 'Admin: $roDisplay (Office)' : 'RO: $roDisplay',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: payment.isAdminOrOfficeEntry ? const Color(0xFF8B1A1A) : Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () =>
                                        _showPaymentReceiptDialog(context, payment, card),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.visibility_outlined,
                                              size: 11, color: Color(0xFF1B5E20)),
                                          SizedBox(width: 3),
                                          Text(
                                            'Receipt',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1B5E20),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (isCrossRoute) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.deepPurple.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.alt_route_rounded,
                                          size: 12, color: Colors.deepPurple.shade700),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          '⚡ Cross-Route: RO from "$roRoute" collected for "$cardRoute"',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 4),
                              Text(
                                'Time: ${payment.createdAt.toString().split('.')[0]}',
                                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildPaginationControls(
                      totalCount: totalCount,
                      totalPages: totalPages,
                      startIndex: startIndex,
                      endIndex: endIndex,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationControls({
    required int totalCount,
    required int totalPages,
    required int startIndex,
    required int endIndex,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Entries indicator
              Text(
                'Showing ${startIndex + 1}–$endIndex of $totalCount entries',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),

              // Rows Per Page Selector
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Per Page: ',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _rowsPerPage,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5')),
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 20, child: Text('20')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                      ],
                      onChanged: (val) {
                        if (val != null && val != _rowsPerPage) {
                          setState(() {
                            _rowsPerPage = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First Page Button
              IconButton(
                icon: const Icon(Icons.first_page_rounded),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: _currentPage > 1 ? const Color(0xFF1B5E20) : Colors.grey.shade400,
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage = 1)
                    : null,
                tooltip: 'First Page',
              ),
              const SizedBox(width: 4),

              // Previous Page Button
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: _currentPage > 1 ? const Color(0xFF1B5E20) : Colors.grey.shade400,
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage -= 1)
                    : null,
                tooltip: 'Previous Page',
              ),
              const SizedBox(width: 8),

              // Page badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $_currentPage of $totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Next Page Button
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: _currentPage < totalPages ? const Color(0xFF1B5E20) : Colors.grey.shade400,
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage += 1)
                    : null,
                tooltip: 'Next Page',
              ),
              const SizedBox(width: 4),

              // Last Page Button
              IconButton(
                icon: const Icon(Icons.last_page_rounded),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: _currentPage < totalPages ? const Color(0xFF1B5E20) : Colors.grey.shade400,
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage = totalPages)
                    : null,
                tooltip: 'Last Page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label) {
    final isSelected = _selectedDateFilter == label;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDateFilter = label;
          if (label != 'Custom') _selectedCustomDate = null;
          _currentPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}

// =========================================================
// MANAGER DASHBOARD SUMMARY CARD (WITH TOGGLEABLE BALANCES)
// =========================================================
class _ManagerBalanceSummaryCard extends StatefulWidget {
  final double grandTotalCollected;
  final double remainingBalance;

  const _ManagerBalanceSummaryCard({
    required this.grandTotalCollected,
    required this.remainingBalance,
  });

  @override
  State<_ManagerBalanceSummaryCard> createState() => _ManagerBalanceSummaryCardState();
}

class _ManagerBalanceSummaryCardState extends State<_ManagerBalanceSummaryCard> {
  bool _showBalances = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B1A1A).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _showBalances = !_showBalances;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.dashboard_rounded, size: 16, color: Colors.white70),
                        SizedBox(width: 6),
                        Text(
                          'TOTAL SANCTIONED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MANAGER MONITORING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Recovered',
                            style: TextStyle(fontSize: 11.5, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _showBalances
                                ? '₹ ${widget.grandTotalCollected.toStringAsFixed(2)}'
                                : '₹ ${widget.grandTotalCollected.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Due Remaining',
                            style: TextStyle(fontSize: 11.5, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _showBalances
                                ? '₹ ${widget.remainingBalance.toStringAsFixed(2)}'
                                : '₹ ${widget.remainingBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                              letterSpacing: 0.5,
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
        ),
      ),
    );
  }
}