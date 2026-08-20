// lib/widgets/ro_daily_collection_pie_chart.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../providers/ro_provider.dart';
import '../providers/collection_sheet_provider.dart';

class RoDailyCollectionData {
  final String roId;
  final String roName;
  final String route;
  final double collectedAmount;
  final double lateFineAmount;
  final int transactionCount;
  final Color color;
  final double percentage;

  const RoDailyCollectionData({
    required this.roId,
    required this.roName,
    required this.route,
    required this.collectedAmount,
    required this.lateFineAmount,
    required this.transactionCount,
    required this.color,
    required this.percentage,
  });
}

class RoDailyCollectionPieChart extends StatefulWidget {
  final RoProvider roProvider;
  final CollectionSheetProvider collectionProvider;

  const RoDailyCollectionPieChart({
    super.key,
    required this.roProvider,
    required this.collectionProvider,
  });

  @override
  State<RoDailyCollectionPieChart> createState() =>
      _RoDailyCollectionPieChartState();
}

class _RoDailyCollectionPieChartState extends State<RoDailyCollectionPieChart>
    with SingleTickerProviderStateMixin {
  int _hoveredIndex = -1;
  late AnimationController _animController;
  late Animation<double> _animValue;

  static const List<Color> _palette = [
    Color(0xFF2E7D32), // Forest Green
    Color(0xFF1565C0), // Royal Blue
    Color(0xFFE65100), // Deep Orange
    Color(0xFF6A1B9A), // Purple
    Color(0xFF00838F), // Teal Cyan
    Color(0xFFC2185B), // Berry Pink
    Color(0xFFF57F17), // Amber Gold
    Color(0xFF4527A0), // Deep Indigo
    Color(0xFF00695C), // Dark Teal
    Color(0xFF37474F), // Slate Grey
  ];

  static const List<String> _monthNames = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animValue = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<RoDailyCollectionData> _computeTodayRoData() {
    final allPayments = widget.collectionProvider.payments;
    final now = DateTime.now();

    // Strictly for today's date only
    final todayPayments = allPayments.where((p) {
      return p.createdAt.year == now.year &&
          p.createdAt.month == now.month &&
          p.createdAt.day == now.day;
    }).toList();

    // Map by unique identifier (roId or roName or office)
    final Map<String, _RoAccumulator> accumulators = {};

    // 1. Pre-populate registered ROs from roProvider
    for (final ro in widget.roProvider.roAccounts) {
      final key = ro.customerid.isNotEmpty ? ro.customerid : ro.roname;
      accumulators[key] = _RoAccumulator(
        roId: ro.customerid,
        roName: ro.roname,
        route: ro.route,
      );
    }

    // 2. Aggregate today's collection payments
    for (final payment in todayPayments) {
      String key;
      String name;
      String route;
      String roId;

      if (payment.isAdminOrOfficeEntry) {
        key = 'ADMIN_OFFICE';
        name = payment.roName?.isNotEmpty == true ? payment.roName! : 'Admin (Office)';
        route = 'Office Route';
        roId = payment.roId ?? 'ADM-01';
      } else {
        key = payment.roId?.isNotEmpty == true
            ? payment.roId!
            : (payment.roName?.isNotEmpty == true ? payment.roName! : 'UNKNOWN_RO');
        name = payment.roName?.isNotEmpty == true ? payment.roName! : 'RO Officer';
        route = payment.roRoute ?? 'Unassigned';
        roId = payment.roId ?? '';
      }

      if (!accumulators.containsKey(key)) {
        accumulators[key] = _RoAccumulator(
          roId: roId,
          roName: name,
          route: route,
        );
      }

      final acc = accumulators[key]!;
      acc.collectedAmount += payment.paymentAmount;
      acc.lateFineAmount += payment.lateFine;
      acc.transactionCount += 1;
      if (payment.roRoute?.isNotEmpty == true && acc.route.isEmpty) {
        acc.route = payment.roRoute!;
      }
      if (payment.roName?.isNotEmpty == true && acc.roName.isEmpty) {
        acc.roName = payment.roName!;
      }
    }

    // Filter to only ROs with collections today
    final List<_RoAccumulator> activeAccumulators = accumulators.values
        .where((a) => a.collectedAmount > 0)
        .toList();

    // Sort descending by collected amount
    activeAccumulators.sort((a, b) => b.collectedAmount.compareTo(a.collectedAmount));

    final double grandTotal =
        activeAccumulators.fold(0.0, (sum, a) => sum + a.collectedAmount);

    return activeAccumulators.asMap().entries.map((entry) {
      final index = entry.key;
      final acc = entry.value;
      final percentage = grandTotal > 0 ? (acc.collectedAmount / grandTotal) * 100 : 0.0;
      final color = _palette[index % _palette.length];

      return RoDailyCollectionData(
        roId: acc.roId,
        roName: acc.roName,
        route: acc.route.isNotEmpty ? acc.route : 'General Route',
        collectedAmount: acc.collectedAmount,
        lateFineAmount: acc.lateFineAmount,
        transactionCount: acc.transactionCount,
        color: color,
        percentage: percentage,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String dateString = '${now.day} ${_monthNames[now.month]} ${now.year}';

    final roDataList = _computeTodayRoData();
    final double totalCollection =
        roDataList.fold(0.0, (sum, d) => sum + d.collectedAmount);
    final int totalTransactions =
        roDataList.fold(0, (sum, d) => sum + d.transactionCount);
    final double totalLateFines =
        roDataList.fold(0.0, (sum, d) => sum + d.lateFineAmount);

    final RoDailyCollectionData? hoveredData =
        (_hoveredIndex >= 0 && _hoveredIndex < roDataList.length)
            ? roDataList[_hoveredIndex]
            : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Live Date Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_rounded, color: Color(0xFF1B5E20), size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'RO Daily Collection Analytics',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B5E20),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Today: $dateString',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            "Today's live collection breakdown across Relationship Officers (RO)",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          const Divider(height: 20),

          if (roDataList.isEmpty) ...[
            // Empty State for Today
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 32,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No Collections Recorded for Today ($dateString)',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'When ROs record payments today, the 3D visual breakdown will appear here in real-time.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // 3D Pie Chart Visual Canvas (Anti-Flicker Hit Tested)
            LayoutBuilder(
              builder: (context, constraints) {
                final double chartWidth = constraints.maxWidth;
                const double chartHeight = 220;

                return Center(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onHover: (event) {
                      final idx = _hitTest3DPie(
                        event.localPosition,
                        Size(chartWidth, chartHeight),
                        roDataList,
                        totalCollection,
                      );
                      if (idx != _hoveredIndex) {
                        setState(() {
                          _hoveredIndex = idx;
                        });
                      }
                    },
                    onExit: (_) {
                      if (_hoveredIndex != -1) {
                        setState(() {
                          _hoveredIndex = -1;
                        });
                      }
                    },
                    child: GestureDetector(
                      onTapDown: (details) {
                        final idx = _hitTest3DPie(
                          details.localPosition,
                          Size(chartWidth, chartHeight),
                          roDataList,
                          totalCollection,
                        );
                        setState(() {
                          _hoveredIndex = (_hoveredIndex == idx) ? -1 : idx;
                        });
                      },
                      child: AnimatedBuilder(
                        animation: _animValue,
                        builder: (context, _) {
                          return CustomPaint(
                            size: Size(chartWidth, chartHeight),
                            painter: _PieChart3DPainter(
                              data: roDataList,
                              hoveredIndex: _hoveredIndex,
                              animationValue: _animValue.value,
                              totalCollection: totalCollection,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Stable Height Information Spotlight Card (Prevents layout jumping)
            SizedBox(
              height: 110,
              child: _buildSpotlightInformationCard(
                hoveredData: hoveredData,
                totalCollection: totalCollection,
                totalTransactions: totalTransactions,
                totalLateFines: totalLateFines,
                activeRoCount: roDataList.length,
                topRo: roDataList.isNotEmpty ? roDataList.first : null,
              ),
            ),

            const SizedBox(height: 14),

            // Interactive RO Legend Grid
            Text(
              "Today's Active Collectors (${roDataList.length} Officers)",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roDataList.asMap().entries.map((entry) {
                final idx = entry.key;
                final data = entry.value;
                final isSelected = _hoveredIndex == idx;

                return MouseRegion(
                  onEnter: (_) {
                    if (_hoveredIndex != idx) {
                      setState(() => _hoveredIndex = idx);
                    }
                  },
                  onExit: (_) {
                    if (_hoveredIndex == idx) {
                      setState(() => _hoveredIndex = -1);
                    }
                  },
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _hoveredIndex = (_hoveredIndex == idx) ? -1 : idx;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? data.color.withValues(alpha: 0.12)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? data.color : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: data.color.withValues(alpha: 0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: data.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: data.color.withValues(alpha: 0.4),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    data.roName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? data.color : Colors.grey.shade900,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${data.percentage.toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? data.color : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '₹ ${data.collectedAmount.toStringAsFixed(0)} • ${data.route}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpotlightInformationCard({
    required RoDailyCollectionData? hoveredData,
    required double totalCollection,
    required int totalTransactions,
    required double totalLateFines,
    required int activeRoCount,
    required RoDailyCollectionData? topRo,
  }) {
    if (hoveredData != null) {
      // Hovered RO Specific Information Card
      final avgPerTx = hoveredData.transactionCount > 0
          ? hoveredData.collectedAmount / hoveredData.transactionCount
          : 0.0;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: hoveredData.color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hoveredData.color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: hoveredData.color,
                      child: Text(
                        hoveredData.roName.isNotEmpty ? hoveredData.roName[0].toUpperCase() : 'R',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hoveredData.roName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        Text(
                          'ID: ${hoveredData.roId.isNotEmpty ? hoveredData.roId : "RO"} • Route: ${hoveredData.route}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hoveredData.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${hoveredData.percentage.toStringAsFixed(1)}% OF TODAY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    label: 'Today Collection',
                    value: '₹ ${hoveredData.collectedAmount.toStringAsFixed(2)}',
                    valueColor: hoveredData.color,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    label: 'Receipts Count',
                    value: '${hoveredData.transactionCount} entries',
                    valueColor: const Color(0xFF1E1E1E),
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    label: 'Avg / Collection',
                    value: '₹ ${avgPerTx.toStringAsFixed(0)}',
                    valueColor: Colors.teal.shade800,
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Default Summary Card when no slice is actively hovered
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Today's RO Performance Overview",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 12, color: Colors.grey),
                  SizedBox(width: 3),
                  Text(
                    'Hover slice to view RO',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  label: "Total Today's Collection",
                  value: '₹ ${totalCollection.toStringAsFixed(2)}',
                  valueColor: Colors.green.shade800,
                  icon: Icons.monetization_on_rounded,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  label: 'Active Officers',
                  value: '$activeRoCount ROs',
                  valueColor: Colors.blue.shade800,
                  icon: Icons.groups_rounded,
                ),
              ),
              if (topRo != null)
                Expanded(
                  child: _buildInfoItem(
                    label: 'Top Collector',
                    value: '${topRo.roName} (${topRo.percentage.toStringAsFixed(0)}%)',
                    valueColor: Colors.amber.shade900,
                    icon: Icons.workspace_premium_rounded,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Mathematically exact radial hit-test with modulo sector test (Zero flickering)
  int _hitTest3DPie(
    Offset localPos,
    Size size,
    List<RoDailyCollectionData> dataList,
    double total,
  ) {
    if (total <= 0 || dataList.isEmpty) return -1;

    final center = Offset(size.width / 2, size.height * 0.44);
    final rx = min(size.width * 0.38, 115.0);
    const depth = 22.0;

    // Relative to center normalized to circular coordinates
    final dx = localPos.dx - center.dx;
    final dy = (localPos.dy - (center.dy + depth / 3)) / 0.58;
    final dist = sqrt(dx * dx + dy * dy);

    // Strict boundary checks
    if (dist < 8.0 || dist > rx * 1.22) return -1;

    // Angle in radians [-pi, pi]
    final angle = atan2(dy, dx);

    const double startBaseAngle = -pi * 0.65;
    double currentAngle = startBaseAngle;

    for (int i = 0; i < dataList.length; i++) {
      final sweep = (dataList[i].collectedAmount / total) * 2 * pi;

      // Exact mathematical sector inclusion test
      double diff = (angle - currentAngle) % (2 * pi);
      if (diff < 0) diff += 2 * pi;

      if (diff >= 0 && diff <= sweep + 0.001) {
        return i;
      }
      currentAngle += sweep;
    }

    return -1;
  }
}

class _RoAccumulator {
  String roId;
  String roName;
  String route;
  double collectedAmount = 0.0;
  double lateFineAmount = 0.0;
  int transactionCount = 0;

  _RoAccumulator({
    required this.roId,
    required this.roName,
    required this.route,
  });
}

/// Custom 3D Pie Chart Painter with true isometric projection, extrusion side walls & glossy top facets
class _PieChart3DPainter extends CustomPainter {
  final List<RoDailyCollectionData> data;
  final int hoveredIndex;
  final double animationValue;
  final double totalCollection;

  _PieChart3DPainter({
    required this.data,
    required this.hoveredIndex,
    required this.animationValue,
    required this.totalCollection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalCollection <= 0 || data.isEmpty) return;

    final center = Offset(size.width / 2, size.height * 0.44);
    final rx = min(size.width * 0.38, 115.0);
    final ry = rx * 0.58;
    const depth = 22.0;

    // 1. Draw Base Drop Shadow
    final shadowRect = Rect.fromCenter(
      center: center + const Offset(0, depth + 8),
      width: rx * 2.1,
      height: ry * 2.1,
    );
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(shadowRect, shadowPaint);

    // Compute angular slices
    const double startBaseAngle = -pi * 0.65;
    final List<_SliceGeometry> slices = [];
    double currentAngle = startBaseAngle;

    for (int i = 0; i < data.length; i++) {
      final sweep = (data[i].collectedAmount / totalCollection) * 2 * pi * animationValue;
      final mid = currentAngle + sweep / 2;
      slices.add(_SliceGeometry(
        index: i,
        startAngle: currentAngle,
        sweepAngle: sweep,
        midAngle: mid,
        color: data[i].color,
      ));
      currentAngle += sweep;
    }

    // 2. Draw 3D Side Walls (Extrusion / Cylindrical Rim)
    for (final slice in slices) {
      final isHovered = slice.index == hoveredIndex;
      final double lift = isHovered ? -5.0 : 0.0;
      final Offset sliceCenter = center + Offset(0, lift);

      _draw3DSideWall(
        canvas: canvas,
        sliceCenter: sliceCenter,
        rx: rx,
        ry: ry,
        depth: depth,
        startAngle: slice.startAngle,
        sweepAngle: slice.sweepAngle,
        baseColor: slice.color,
      );
    }

    // 3. Draw Top Faces with glossy gradient and edge highlights
    for (final slice in slices) {
      final isHovered = slice.index == hoveredIndex;
      final double lift = isHovered ? -5.0 : 0.0;
      final Offset sliceCenter = center + Offset(0, lift);

      _drawTopSlice(
        canvas: canvas,
        sliceCenter: sliceCenter,
        rx: rx,
        ry: ry,
        startAngle: slice.startAngle,
        sweepAngle: slice.sweepAngle,
        color: slice.color,
        isHovered: isHovered,
      );
    }
  }

  void _draw3DSideWall({
    required Canvas canvas,
    required Offset sliceCenter,
    required double rx,
    required double ry,
    required double depth,
    required double startAngle,
    required double sweepAngle,
    required Color baseColor,
  }) {
    if (sweepAngle <= 0.001) return;

    // Discretize the arc to render smooth 3D curved side walls
    const int segments = 24;
    final double step = sweepAngle / segments;

    final hsl = HSLColor.fromColor(baseColor);
    final darkColor = hsl
        .withLightness((hsl.lightness * 0.65).clamp(0.0, 1.0))
        .toColor();

    for (int i = 0; i < segments; i++) {
      final a1 = startAngle + i * step;
      final a2 = startAngle + (i + 1) * step;

      // Only draw if facing towards the camera (sin(angle) >= -0.15)
      final mid = (a1 + a2) / 2;
      final sinMid = sin(mid);
      if (sinMid < -0.15) continue;

      final p1Top = Offset(sliceCenter.dx + rx * cos(a1), sliceCenter.dy + ry * sin(a1));
      final p2Top = Offset(sliceCenter.dx + rx * cos(a2), sliceCenter.dy + ry * sin(a2));
      final p1Bot = p1Top + Offset(0, depth);
      final p2Bot = p2Top + Offset(0, depth);

      final sidePath = Path()
        ..moveTo(p1Top.dx, p1Top.dy)
        ..lineTo(p2Top.dx, p2Top.dy)
        ..lineTo(p2Bot.dx, p2Bot.dy)
        ..lineTo(p1Bot.dx, p1Bot.dy)
        ..close();

      // Realistic directional lighting based on angle relative to light source
      final lightMod = (0.7 + 0.3 * sinMid).clamp(0.4, 1.0);
      final wallColor = HSLColor.fromColor(darkColor)
          .withLightness((hsl.lightness * 0.6 * lightMod).clamp(0.0, 1.0))
          .toColor();

      final paint = Paint()
        ..color = wallColor
        ..style = PaintingStyle.fill;

      canvas.drawPath(sidePath, paint);
    }
  }

  void _drawTopSlice({
    required Canvas canvas,
    required Offset sliceCenter,
    required double rx,
    required double ry,
    required double startAngle,
    required double sweepAngle,
    required Color color,
    required bool isHovered,
  }) {
    if (sweepAngle <= 0.001) return;

    final path = Path()
      ..moveTo(sliceCenter.dx, sliceCenter.dy)
      ..lineTo(
        sliceCenter.dx + rx * cos(startAngle),
        sliceCenter.dy + ry * sin(startAngle),
      )
      ..arcTo(
        Rect.fromCenter(center: sliceCenter, width: rx * 2, height: ry * 2),
        startAngle,
        sweepAngle,
        false,
      )
      ..close();

    final hsl = HSLColor.fromColor(color);
    final topHighlight = hsl
        .withLightness((hsl.lightness * (isHovered ? 1.35 : 1.15)).clamp(0.0, 1.0))
        .toColor();

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [topHighlight, color],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCenter(center: sliceCenter, width: rx * 2, height: ry * 2))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Rim border for crisp sector demarcation
    final borderPaint = Paint()
      ..color = isHovered ? Colors.white : Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHovered ? 2.2 : 1.2;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PieChart3DPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.data != data ||
        oldDelegate.totalCollection != totalCollection;
  }
}

class _SliceGeometry {
  final int index;
  final double startAngle;
  final double sweepAngle;
  final double midAngle;
  final Color color;

  _SliceGeometry({
    required this.index,
    required this.startAngle,
    required this.sweepAngle,
    required this.midAngle,
    required this.color,
  });
}
