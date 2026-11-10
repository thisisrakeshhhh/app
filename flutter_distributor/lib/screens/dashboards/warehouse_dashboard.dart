import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import '../views/add_edit_inventory_item_sheet.dart';

/// Simplified Godown & Warehouse Landing Dashboard.
/// Designed for field godown workers ("10th fail friendly") with clear Hinglish & English labels,
/// real-time SQLite DB counters, and one-tap access to Truck Inward, Stock, Orders, and Dispatch Log.
class WarehouseDashboard extends StatelessWidget {
  final ApiService api;
  final Function(int targetTab) onNavigateTab;

  const WarehouseDashboard({
    super.key,
    required this.api,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final products = api.products;
        final totalBoxes = api.totalGodownBoxes;
        final totalValuation = products.fold<double>(0.0, (sum, p) => sum + p.godownValuationRupees);
        final pendingOrders = api.orders.where((o) => o.stage == OrderLifecycleStage.booking).toList();
        final waitingApprovalCount = pendingOrders.where((o) => !o.isOwnerApproved).length;
        final readyToPickCount = pendingOrders.where((o) => o.isOwnerApproved).length;

        final recentInwards = api.truckInwardLog.take(3).toList();
        final recentDispatches = api.stockDispatchLog.take(3).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. GODOWN HEADER BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.warehouse_rounded, color: Color(0xFF60A5FA), size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CENTRAL FMCG GODOWN',
                                  style: TextStyle(
                                    color: Color(0xFF93C5FD),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  'Basni Industrial Area Phase II (Real-Time DB)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => AddEditInventoryItemSheet.show(context, api),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('+ Add SKU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Godown Stock',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$totalBoxes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Boxes / पेटी',
                          style: TextStyle(color: Color(0xFF93C5FD), fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Stock Valuation', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                            Text(
                              '₹${totalValuation.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFF34D399), fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Loaded in Van', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w700)),
                              Text(': ${api.totalCarBoxes} Boxes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          InkWell(
                            onTap: () => onNavigateTab(1),
                            child: const Text('Expiry Radar', style: TextStyle(color: Color(0xFFFCD34D), fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // OWNER APPROVAL ALERT BANNER (If any orders waiting)
              if (waitingApprovalCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$waitingApprovalCount ऑर्डर मालिक की मंजूरी के इंतज़ार में हैं',
                              style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            const Text(
                              'Waiting for Owner Approval before packing',
                              style: TextStyle(color: Color(0xFFB45309), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => onNavigateTab(3),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('चेक करें', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),

              // 2. BIG 4 WORK OPERATIONS (10th-fail friendly cards)
              const Text(
                'गोदाम के मुख्य काम (Godown Work)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AirbnbTheme.dark),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildOperationCard(
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF2563EB),
                      title: '🚚 ट्रक से माल आया',
                      subtitle: 'गाड़ी नंबर & कार्ट जोड़ें\n(Truck Inward)',
                      badge: 'नया माल',
                      onTap: () => onNavigateTab(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOperationCard(
                      icon: Icons.checklist_rtl_rounded,
                      color: const Color(0xFFD97706),
                      title: '📦 दुकान के ऑर्डर',
                      subtitle: '$readyToPickCount तैयार • $waitingApprovalCount पेंडिंग\n(Pick & Pack)',
                      badge: pendingOrders.isNotEmpty ? '${pendingOrders.length}' : null,
                      onTap: () => onNavigateTab(3),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildOperationCard(
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF059669),
                      title: '📋 गोदाम स्टॉक लिस्ट',
                      subtitle: '$totalBoxes पेटी उपलब्ध\n(Stock List)',
                      badge: null,
                      onTap: () => onNavigateTab(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOperationCard(
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF7C3AED),
                      title: '📜 आवक-जावक रजिस्टर',
                      subtitle: 'कब आया & कहाँ गया\n(Inward/Dispatch Log)',
                      badge: null,
                      onTap: () => onNavigateTab(4),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 3. RECENT TRUCK INWARD (कब माल आया, किससे आया)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🚚 हाल ही में आए ट्रक (Recent Trucks)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                  ),
                  TextButton(
                    onPressed: () => onNavigateTab(4),
                    child: const Text('सब देखें >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (recentInwards.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('अभी कोई नया ट्रक दर्ज नहीं हुआ है', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                )
              else
                ...recentInwards.map((inw) => _buildInwardSummaryTile(inw)),

              const SizedBox(height: 20),

              // 4. RECENT DISPATCH (कहाँ कहाँ माल गया)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📤 हाल ही में गया माल (Recent Dispatch)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                  ),
                  TextButton(
                    onPressed: () => onNavigateTab(4),
                    child: const Text('सब देखें >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (recentDispatches.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('अभी कोई माल रवाना नहीं हुआ है', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                )
              else
                ...recentDispatches.map((dsp) => _buildDispatchSummaryTile(dsp)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperationCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.25),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInwardSummaryTile(TruckInwardEntry inw) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_shipping, color: Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      inw.truckNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${inw.driverName})',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${inw.items.length} आइटम्स • ${inw.totalCartons} पेटी',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('जमा हुआ', style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 2),
              Text(
                '${inw.arrivedAt.hour.toString().padLeft(2, '0')}:${inw.arrivedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchSummaryTile(StockDispatchEntry dsp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.outbox_rounded, color: Color(0xFF7C3AED), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dsp.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dsp.itemsSummary} (${dsp.totalCartons} पेटी)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(dsp.deliveryVehicle, style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 2),
              Text(
                '${dsp.dispatchedAt.hour.toString().padLeft(2, '0')}:${dsp.dispatchedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
