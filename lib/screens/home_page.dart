// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/ro_provider.dart';
import '../providers/collection_sheet_provider.dart';

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
            else if (activeRole == UserType.ro)
              _buildRODashboard(context, loaneeProvider, user, onNavigateToMenu)
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
    final double extraCollection = collectionProvider.collectionEntries.fold(
      0.0,
      (sum, item) => sum + item.collectedAmount,
    );
    final double grandTotalCollected = loaneeProvider.totalCollectedAmount + extraCollection;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Executive Portfolio Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 12),

          // Meaningful Executive Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Total RO Officers',
                  value: '${roProvider.totalRoAccounts} Officers',
                  subtitle: 'Active Field Officers',
                  icon: Icons.badge_rounded,
                  color: Colors.blue.shade700,
                  backgroundColor: Colors.blue.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Loanees',
                  value: '${loaneeProvider.totalLoanees} Loanees',
                  subtitle: 'Active Loan Accounts',
                  icon: Icons.people_alt_rounded,
                  color: Colors.purple.shade700,
                  backgroundColor: Colors.purple.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Loanee Collected Amount',
                  value: '₹ ${grandTotalCollected.toStringAsFixed(2)}',
                  subtitle: 'Total Recovery Collection',
                  icon: Icons.payments_rounded,
                  color: Colors.green.shade700,
                  backgroundColor: Colors.green.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Loan Sanctioned',
                  value: '₹ ${(loaneeProvider.totalLoanAmount / 100000).toStringAsFixed(2)} Lakh',
                  subtitle: 'Total Sanctioned Portfolio',
                  icon: Icons.account_balance_rounded,
                  color: Colors.amber.shade900,
                  backgroundColor: Colors.amber.shade50,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Route-Wise Collection Vertical Bar Chart (Database-Backed)
          _buildRouteWiseCollectionChart(context, collectionProvider),

          const SizedBox(height: 20),

          // Recent Loanee Accounts Overview
          _buildRecentLoaneesList(loaneeProvider, onNavigateToMenu),
        ],
      ),
    );
  }

  // ==========================================
  // 2. RO DASHBOARD VIEW (PROFILE & PAYMENT ENTRY ONLY)
  // ==========================================
  Widget _buildRODashboard(
    BuildContext context,
    LoaneeProvider loaneeProvider,
    User? user,
    Function(int)? onNavigateToMenu,
  ) {
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
            child: Row(
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
                        user?.name ?? 'Rajesh Sharma (RO)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Assigned Zone: Imphal West & Kwakeithel Area',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            "Today's Collection Target",
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
                  title: 'Daily Target',
                  value: '₹ 85,000',
                  subtitle: 'Target for today',
                  icon: Icons.track_changes_rounded,
                  color: Colors.blue.shade700,
                  backgroundColor: Colors.blue.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Collected Today',
                  value: '₹ 62,500',
                  subtitle: '73.5% achieved',
                  icon: Icons.payments_rounded,
                  color: Colors.green.shade700,
                  backgroundColor: Colors.green.shade50,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // RO Actions: PAYMENT ENTRY & PROFILE ONLY
          const Text(
            'RO Officer Actions',
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
                  title: 'Payment Entry',
                  subtitle: 'Record field collection',
                  icon: Icons.add_card_rounded,
                  color: Colors.green.shade700,
                  onTap: () {
                    if (onNavigateToMenu != null) onNavigateToMenu(3);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  title: 'RO Profile',
                  subtitle: 'View credentials & zone',
                  icon: Icons.account_circle_rounded,
                  color: const Color(0xFF8B1A1A),
                  onTap: () {
                    if (onNavigateToMenu != null) onNavigateToMenu(6);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildROScheduleCard(loaneeProvider),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Loan Overview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF8B1A1A), const Color(0xFF6B1414)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B1A1A).withOpacity(0.3),
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
                    Column(
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
                          user?.name ?? 'Nongthombam Ibomcha',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sanctioned Amount',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text(
                          '₹ 1,00,000',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Outstanding Balance',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text(
                          '₹ 55,000',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Upcoming Next EMI Notice Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_note_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next EMI Due Date: 10 Aug 2026',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Monthly Installment Amount: ₹ 4,500',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8B1A1A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Loanee View-Only Options
          const Text(
            'Loanee Passbook & Profile (View Only)',
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
                  title: 'Payment Transactions',
                  subtitle: 'View passbook statement',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.blue.shade700,
                  onTap: () {
                    if (onNavigateToMenu != null) onNavigateToMenu(3);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  title: 'My Profile',
                  subtitle: 'View personal details',
                  icon: Icons.account_circle_rounded,
                  color: const Color(0xFF8B1A1A),
                  onTap: () {
                    if (onNavigateToMenu != null) onNavigateToMenu(6);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildLoaneeRepaymentHistory(),
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

    // Standard default master routes to guarantee baseline chart display
    final List<String> baseRoutes = [
      'Mangang',
      'Luwang',
      'Khuman',
      'Angom',
      'Moirang'
    ];
    for (var r in baseRoutes) {
      routeTotals[r] = 0.0;
    }

    // Include dynamic master routes from Supabase route_master table
    for (var rObj in collectionProvider.routes) {
      routeTotals[rObj.name] = routeTotals[rObj.name] ?? 0.0;
    }

    // Aggregate collected amounts per route from Supabase ro_collection_entries table
    for (var entry in collectionProvider.collectionEntries) {
      routeTotals[entry.route] =
          (routeTotals[entry.route] ?? 0.0) + entry.collectedAmount;
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded,
                        size: 12, color: Colors.blue.shade800),
                    const SizedBox(width: 4),
                    Text(
                      'DATABASE DATA',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            'Collection statistics grouped by route zone (Vertical Column Chart)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          const Divider(height: 20),

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

  Widget _buildRecentLoaneesList(
    LoaneeProvider loaneeProvider,
    Function(int)? onNavigateToMenu,
  ) {
    final list = loaneeProvider.loanees.take(3).toList();
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
                'Recent Registered Loanees',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B1A1A),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (onNavigateToMenu != null) onNavigateToMenu(2);
                },
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 12),
          ...list.map((item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF8B1A1A).withOpacity(0.1),
                  child: const Icon(Icons.person,
                      color: Color(0xFF8B1A1A), size: 18),
                ),
                title: Text(item.loaneeName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${item.customerId} • ${item.district}',
                    style: const TextStyle(fontSize: 11)),
                trailing: Text(
                  '₹ ${item.loanAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B1A1A),
                      fontSize: 13),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildROScheduleCard(LoaneeProvider loaneeProvider) {
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
          const Text(
            "Today's Collection Schedule",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B1A1A),
            ),
          ),
          const SizedBox(height: 10),
          _buildScheduleItem(
            name: 'Thokchom Sanatombi Devi',
            location: 'Kwakeithel Heinoukhongnembi',
            amount: '₹ 2,500',
            status: 'Pending Visit',
            statusColor: Colors.orange.shade800,
          ),
          const Divider(height: 16),
          _buildScheduleItem(
            name: 'Nongthombam Ibomcha',
            location: 'Imphal West Sector 4',
            amount: '₹ 4,500',
            status: 'Collected',
            statusColor: Colors.green.shade700,
          ),
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
  }) {
    return Row(
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
    );
  }

  Widget _buildLoaneeRepaymentHistory() {
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
          const Text(
            'Verified Payment Passbook History (View Only)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B1A1A),
            ),
          ),
          const SizedBox(height: 12),
          _buildPaymentRow('10 Jul 2026', '₹ 4,500', 'Paid via UPI', true),
          const Divider(height: 16),
          _buildPaymentRow('10 Jun 2026', '₹ 4,500', 'Paid via Cash (RO)', true),
          const Divider(height: 16),
          _buildPaymentRow('10 May 2026', '₹ 4,500', 'Paid via UPI', true),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(
      String date, String amount, String method, bool isSuccess) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                Text(method,
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
        Text(
          amount,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B1A1A),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _getRoleTitle(UserType role) {
    switch (role) {
      case UserType.admin:
        return 'Executive Admin Portal';
      case UserType.ro:
        return 'RO Officer Portal';
      case UserType.loanee:
        return 'Loanee Account Portal';
    }
  }

  String _getRoleBadgeText(UserType role) {
    switch (role) {
      case UserType.admin:
        return 'ADMIN LEVEL';
      case UserType.ro:
        return 'RO LEVEL';
      case UserType.loanee:
        return 'LOANEE LEVEL';
    }
  }

  IconData _getRoleIcon(UserType role) {
    switch (role) {
      case UserType.admin:
        return Icons.admin_panel_settings_rounded;
      case UserType.ro:
        return Icons.badge_rounded;
      case UserType.loanee:
        return Icons.person_rounded;
    }
  }
}