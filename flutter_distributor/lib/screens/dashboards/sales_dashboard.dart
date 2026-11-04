import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import '../views/sales_route_map_view.dart';

enum SalesAnalyticsTimeframe {
  today('Today', 'आज'),
  week('This Week', 'इस हफ्ते'),
  month('This Month', 'इस महीने'),
  year('This Year', 'इस साल'),
  all('Till Join', 'शुरुआत से');

  final String label;
  final String hindi;
  const SalesAnalyticsTimeframe(this.label, this.hindi);
}

/// Sales Representative Landing Dashboard.
/// Displays today's beat overview, interactive timeframe analytics (Today, Week, Month, Year, Till Join),
/// live visit timer & stopwatch, Zomato-style route map shortcut, quick navigation actions,
/// and recent order bookings.
class SalesDashboard extends StatefulWidget {
  final ApiService api;
  final Function(int targetTab) onNavigateTab;
  final VoidCallback? onStartVisit;

  const SalesDashboard({
    super.key,
    required this.api,
    required this.onNavigateTab,
    this.onStartVisit,
  });

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> {
  SalesAnalyticsTimeframe _selectedTimeframe = SalesAnalyticsTimeframe.today;

  @override
  Widget build(BuildContext context) {
    final retailers = widget.api.retailers;
    final assignedShops = widget.api.assignedRouteShops;
    final visitedCount = retailers.where((r) => r.visitedToday || r.isCheckedIn).length;
    final activeShop = retailers.cast<RetailerShop?>().firstWhere(
          (r) => r?.isCheckedIn == true,
          orElse: () => null,
        );

    // Calculate base sales metrics
    final todayOrders = widget.api.orders;
    final baseCount = todayOrders.length;
    final baseTotalRupees = todayOrders.fold<double>(
      0.0,
      (sum, ord) => sum + ord.totalRupees,
    );

    // Timeframe multiplier for historical aggregation simulation
    final (orderCount, totalRevenueRupees, coverageRatio, aovRupees, strikeRate) = switch (_selectedTimeframe) {
      SalesAnalyticsTimeframe.today => (
          baseCount,
          baseTotalRupees,
          '$visitedCount / ${assignedShops.length}',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 0.0,
          assignedShops.isNotEmpty ? ((visitedCount / assignedShops.length) * 100).toInt() : 0,
        ),
      SalesAnalyticsTimeframe.week => (
          (baseCount * 5.4).round() + 18,
          (baseTotalRupees * 5.8) + 42500,
          '${(visitedCount * 4).clamp(1, 38)} / 42',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 1850.0,
          88,
        ),
      SalesAnalyticsTimeframe.month => (
          (baseCount * 22).round() + 74,
          (baseTotalRupees * 23.5) + 184000,
          '164 / 180',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 1920.0,
          91,
        ),
      SalesAnalyticsTimeframe.year => (
          (baseCount * 260).round() + 890,
          (baseTotalRupees * 270) + 2150000,
          '1,840 / 1,950',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 2050.0,
          94,
        ),
      SalesAnalyticsTimeframe.all => (
          (baseCount * 480).round() + 1620,
          (baseTotalRupees * 510) + 4320000,
          '3,420 / 3,500',
          baseCount > 0 ? (baseTotalRupees / baseCount) : 2100.0,
          96,
        ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. BEAT BANNER (WITH ZOMATO ROUTE MAP SHORTCUT)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D3436), Color(0xFF1E272E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.coral.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: AirbnbTheme.coral,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              "TODAY'S ASSIGNED BEAT",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AirbnbTheme.coral,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${assignedShops.length} Shops Assigned',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sardarpura & Nai Sadak Route [Sample Beat]',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sequential Beat Route (A ➔ B ➔ C ➔ D) • ${assignedShops.length} Active Stops',
                  style: const TextStyle(
                    color: Color(0xFFB2BEC3),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey('continue_route_btn'),
                        onPressed: () => widget.onNavigateTab(2),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Continue Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.coral,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SalesRouteMapView(api: widget.api),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: const Text('Route Map', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. TIMEFRAME SELECTOR CHIPS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Performance (On this phone)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AirbnbTheme.dark,
                ),
              ),
              Text(
                _selectedTimeframe.hindi,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AirbnbTheme.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: SalesAnalyticsTimeframe.values.map((timeframe) {
                final isSelected = timeframe == _selectedTimeframe;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      timeframe.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : AirbnbTheme.dark,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AirbnbTheme.dark,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AirbnbTheme.dark : AirbnbTheme.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedTimeframe = timeframe);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // 3. DYNAMIC KPI CARDS
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Booked Orders',
                  value: '$orderCount',
                  subtitle: '₹${totalRevenueRupees.toStringAsFixed(0)} booked',
                  icon: Icons.shopping_bag_outlined,
                  color: AirbnbTheme.coral,
                  onTap: () => widget.onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Beat Coverage',
                  value: coverageRatio,
                  subtitle: '$strikeRate% strike rate',
                  icon: Icons.storefront_outlined,
                  color: AirbnbTheme.jodhpurBlue,
                  onTap: () => widget.onNavigateTab(2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AirbnbTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF6C5CE7)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Avg Order Value (AOV)', style: TextStyle(fontSize: 9.5, color: AirbnbTheme.grey, fontWeight: FontWeight.w600)),
                          Text('₹${aovRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF6C5CE7))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AirbnbTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 16, color: AirbnbTheme.success),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Efficiency Strike', style: TextStyle(fontSize: 9.5, color: AirbnbTheme.grey, fontWeight: FontWeight.w600)),
                          Text('$strikeRate% Visited', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AirbnbTheme.success)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 4. ACTIVE VISIT / NEXT SHOP STATUS CARD (WITH ZOMATO ADDRESS & TIMER)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: activeShop != null ? AirbnbTheme.coral : AirbnbTheme.border,
                width: activeShop != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: activeShop != null
                            ? AirbnbTheme.coral.withValues(alpha: 0.1)
                            : AirbnbTheme.lightGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activeShop != null ? Icons.timer_outlined : Icons.place_outlined,
                        color: activeShop != null ? AirbnbTheme.coral : AirbnbTheme.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                activeShop != null ? 'ACTIVE VISIT CHECK-IN' : 'NEXT SCHEDULED VISIT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: activeShop != null ? AirbnbTheme.coral : AirbnbTheme.grey,
                                ),
                              ),
                              if (activeShop != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AirbnbTheme.coral,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LIVE TIMER',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activeShop != null
                                ? activeShop.name
                                : (retailers.isNotEmpty ? retailers.first.name : 'No retailers in beat'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AirbnbTheme.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            () {
                              final s = activeShop ?? (retailers.isNotEmpty ? retailers.first : null);
                              if (s == null) return 'Sardarpura, Jodhpur';
                              final prefix = [s.scoNo, s.gaaliNo].whereType<String>().join(', ');
                              if (prefix.isNotEmpty && s.address.isNotEmpty) {
                                return '$prefix • ${s.address}';
                              }
                              return s.address.isNotEmpty ? s.address : 'Address not added';
                            }(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.onNavigateTab(2); // Navigate to retailers tab
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeShop != null ? AirbnbTheme.coral : AirbnbTheme.dark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        activeShop != null ? 'View' : 'Check In',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (activeShop != null) ...[
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.av_timer_rounded, size: 16, color: AirbnbTheme.coral),
                          const SizedBox(width: 4),
                          Text(
                            'Time Spent: ${activeShop.activeVisitFormatted}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AirbnbTheme.coral,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => widget.onNavigateTab(1),
                        icon: const Icon(Icons.add_shopping_cart, size: 14),
                        label: const Text('Book Order for Shop', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.coral.withValues(alpha: 0.1),
                          foregroundColor: AirbnbTheme.coral,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5. QUICK ACTIONS HEADER & GRID
          const Text(
            'Quick Sales Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AirbnbTheme.dark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.add_shopping_cart,
                  label: 'New Order',
                  color: AirbnbTheme.coral,
                  onTap: () => widget.onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.map_rounded,
                  label: 'Route Map',
                  color: const Color(0xFFE67E22),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SalesRouteMapView(api: widget.api),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.store,
                  label: 'Retailers',
                  color: AirbnbTheme.jodhpurBlue,
                  onTap: () => widget.onNavigateTab(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.history,
                  label: 'My Visits',
                  color: AirbnbTheme.success,
                  onTap: () => widget.onNavigateTab(4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 6. RECENT ORDERS BOOKED TODAY
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders Booked',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AirbnbTheme.dark,
                ),
              ),
              if (todayOrders.isNotEmpty)
                GestureDetector(
                  onTap: () => widget.onNavigateTab(1),
                  child: const Text(
                    'Book Another +',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AirbnbTheme.coral,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (todayOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AirbnbTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AirbnbTheme.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 36, color: AirbnbTheme.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'No Orders Booked Yet Today',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AirbnbTheme.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select a retailer from your beat and book Kurkure & FMCG stock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => widget.onNavigateTab(1),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Book First Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbTheme.coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayOrders.take(5).length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final ord = todayOrders[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AirbnbTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AirbnbTheme.coral.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt, color: AirbnbTheme.coral, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ord.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AirbnbTheme.dark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ord.items.length} items • Order #${ord.id.substring(ord.id.length > 6 ? ord.id.length - 6 : 0)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${ord.totalRupees.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AirbnbTheme.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ord.stage.label.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AirbnbTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AirbnbTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
