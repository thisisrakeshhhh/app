import 'package:flutter/material.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../services/api_service.dart';
import '../../../theme/airbnb_theme.dart';

/// Sales Role Earn Tab.
/// Honest, phone-local performance overview showing real booked and delivered numbers.
class SalesEarnView extends StatelessWidget {
  final ApiService api;

  const SalesEarnView({super.key, required this.api});

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final todayOrders = api.orders.where((o) => _isToday(o.createdAt)).toList();
    final todayBookingsRupees = todayOrders.fold<double>(0.0, (sum, o) => sum + (o.totalPaise / 100.0));
    final deliveredOrders = api.orders.where((o) => o.stage == OrderLifecycleStage.delivered).toList();
    final totalDeliveredRupees = deliveredOrders.fold<double>(0.0, (sum, o) => sum + (o.totalPaise / 100.0));

    final assignedBeatRetailers = api.retailers.where((r) => api.isAssignedBeatShop(r.id)).toList();
    final totalBeatShops = assignedBeatRetailers.length;
    final visitedShops = assignedBeatRetailers.where((r) => r.visitedToday).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('earn_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
              ),
              const SizedBox(height: 16),

              // Today's Bookings Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AirbnbTheme.coral.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.point_of_sale, color: AirbnbTheme.coral, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.t('earn_today_sales'),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '₹${todayBookingsRupees.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AirbnbTheme.dark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.t('earn_today_orders'),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '${todayOrders.length}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Beat Visits Completed',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '$visitedShops / $totalBeatShops',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Delivered Sales Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AirbnbTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_circle_outline, color: AirbnbTheme.success, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.t('earn_delivered_sales'),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '₹${totalDeliveredRupees.toStringAsFixed(2)} (${deliveredOrders.length} orders)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Target & Commission / Incentive Information
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strings.t('earn_incentives_hint'),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Day Summary / Close Tile
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wb_twilight, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          strings.t('earn_day_close'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'All local sales orders and visit records are stored safely on this phone.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
