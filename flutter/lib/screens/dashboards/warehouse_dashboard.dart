import 'package:flutter/material.dart';
import '../../features/sales/widgets/sales_language_picker.dart';
import '../../l10n/app_language.dart';
import '../../l10n/language_controller.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import '../views/add_edit_inventory_item_sheet.dart';
import '../views/warehouse_subviews.dart';

/// Production-Grade FMCG Warehouse & Logistics Command Cockpit.
/// Designed for Real Bites FMCG distribution network.
/// Core display language is English with instant language toggling support.
/// Displays live depot information, shift date/time, total inventory valuation,
/// category-level stock distribution, and real-time movement registers.
class WarehouseDashboard extends StatefulWidget {
  final ApiService api;
  final Function(int targetTab) onNavigateTab;

  const WarehouseDashboard({
    super.key,
    required this.api,
    required this.onNavigateTab,
  });

  @override
  State<WarehouseDashboard> createState() => _WarehouseDashboardState();
}

class _WarehouseDashboardState extends State<WarehouseDashboard> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.api, LanguageController.instance]),
      builder: (context, _) {
        final currentLang = LanguageController.instance.currentLanguage;
        final products = widget.api.products;
        final totalBoxes = widget.api.totalGodownBoxes;
        final totalPieces = products.fold<int>(0, (sum, p) => sum + (p.godownStockBoxes * p.boxQty));
        final totalValuation = products.fold<double>(0.0, (sum, p) => sum + p.godownValuationRupees);

        final pendingOrders = widget.api.orders.where((o) => o.stage == OrderLifecycleStage.booking).toList();
        final waitingApprovalCount = pendingOrders.where((o) => !o.isOwnerApproved).length;
        final readyToPickCount = pendingOrders.where((o) => o.isOwnerApproved).length;

        final readyOrders = widget.api.readyStockOrders;
        final readyValuation = readyOrders.fold<double>(0.0, (sum, o) => sum + o.totalRupees);

        final trucks = widget.api.deliveryTrucks;
        final activeTruck = widget.api.activeTruck;
        final avgCapacity = trucks.isEmpty
            ? 0.0
            : trucks.fold<double>(0.0, (sum, t) => sum + t.capacityUtilizationPercent) / trucks.length;

        final recentInwards = widget.api.truckInwardLog.take(4).toList();
        final recentDispatches = widget.api.stockDispatchLog.take(4).toList();

        // Category metrics
        final namkeen = products.where((p) => p.category == 'Traditional Namkeen').toList();
        final wafers = products.where((p) => p.category == 'Potato Wafers').toList();
        final fryums = products.where((p) => p.category == 'Extruded Snacks & Fryums').toList();
        final juices = products.where((p) => p.category == 'Juices & Cold Drinks').toList();
        final biscuits = products.where((p) => p.category == 'Biscuits & Bakery').toList();

        // Low stock count
        final lowStockItems = products.where((p) => p.isLowStock || p.isOutOfStock).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. EXECUTIVE FACILITY & SHIFT PROFILE HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Facility Name + Date + Quick Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.waving_hand_rounded, color: Color(0xFFFCD34D), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Welcome, Manoj Kumar!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF34D399),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        const Expanded(
                                          child: Text(
                                            'Warehouse & Inventory Hub • Live Shift',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
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
                            // Universal Language Selector
                            InkWell(
                              onTap: () => SalesLanguagePicker.showSheet(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.language, size: 13, color: Color(0xFFFCD34D)),
                                    const SizedBox(width: 4),
                                    Text(
                                      currentLang.nativeName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              onPressed: () => AddEditInventoryItemSheet.show(context, widget.api),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('+ Add SKU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Stock Counter Label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Godown Stock',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34D399).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${products.length} SKUs in Catalog',
                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Big Numbers Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Boxes on Shelves',
                                    style: TextStyle(color: Color(0xFF93C5FD), fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '(= $totalPieces pcs in godown)',
                                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Stock Valuation', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalValuation.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFF34D399), fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Van Stock & Expiry Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, color: Color(0xFF60A5FA), size: 16),
                              const SizedBox(width: 6),
                              const Text('Loaded in Van', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w700)),
                              Text(': ${widget.api.totalCarBoxes} Boxes', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          InkWell(
                            onTap: () => widget.onNavigateTab(1),
                            child: Row(
                              children: [
                                if (lowStockItems.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${lowStockItems.length} Low',
                                      style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 10, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                const Text('Expiry Radar', style: TextStyle(color: Color(0xFFFCD34D), fontSize: 11.5, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 3),
                                const Icon(Icons.arrow_forward_ios, color: Color(0xFFFCD34D), size: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. TODAY'S WAREHOUSE OPERATIONS PULSE (Real-time Activity Stats)
              const Text(
                "Today's Shift Operations Pulse",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AirbnbTheme.dark),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.checklist_rounded,
                      color: const Color(0xFF2563EB),
                      title: 'Pick & Pack Queue',
                      value: '${pendingOrders.length} Orders',
                      subtext: '$readyToPickCount Approved • $waitingApprovalCount Awaiting',
                      badge: waitingApprovalCount > 0 ? '$waitingApprovalCount Pending' : null,
                      badgeColor: const Color(0xFFD97706),
                      onTap: () => widget.onNavigateTab(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF059669),
                      title: 'Packed & Staged',
                      value: '${readyOrders.length} Orders',
                      subtext: '₹${readyValuation.toStringAsFixed(0)} Ready for Delivery',
                      badge: readyOrders.isNotEmpty ? '${readyOrders.length} Ready' : null,
                      badgeColor: const Color(0xFF059669),
                      onTap: () => widget.onNavigateTab(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF7C3AED),
                      title: 'Active Delivery Vans',
                      value: '${trucks.length} Vehicles',
                      subtext: '${avgCapacity.toStringAsFixed(0)}% Average Van Capacity',
                      badge: activeTruck.vehicleNumber,
                      badgeColor: const Color(0xFF7C3AED),
                      onTap: () => widget.onNavigateTab(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.sync_alt_rounded,
                      color: const Color(0xFFD97706),
                      title: 'Daily Movement Log',
                      value: '${recentInwards.length + recentDispatches.length} Logs',
                      subtext: '${recentInwards.length} Inward • ${recentDispatches.length} Dispatched',
                      badge: 'Live DB',
                      badgeColor: const Color(0xFF059669),
                      onTap: () => widget.onNavigateTab(3),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // 3. REAL BITES PRODUCT PORTFOLIO DISTRIBUTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Real Bites Category Stock Health',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AirbnbTheme.dark),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(1),
                    child: const Text('View Catalog >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryCard(
                      title: 'Namkeen & Sev',
                      icon: Icons.bakery_dining_rounded,
                      color: const Color(0xFFD97706),
                      skuCount: namkeen.length,
                      boxes: namkeen.fold<int>(0, (sum, p) => sum + p.godownStockBoxes),
                      onTap: () => widget.onNavigateTab(1),
                    ),
                    const SizedBox(width: 10),
                    _buildCategoryCard(
                      title: 'Potato Wafers',
                      icon: Icons.lunch_dining_rounded,
                      color: const Color(0xFF4F46E5),
                      skuCount: wafers.length,
                      boxes: wafers.fold<int>(0, (sum, p) => sum + p.godownStockBoxes),
                      onTap: () => widget.onNavigateTab(1),
                    ),
                    const SizedBox(width: 10),
                    _buildCategoryCard(
                      title: 'Fryums & Rings',
                      icon: Icons.fastfood_rounded,
                      color: const Color(0xFFE11D48),
                      skuCount: fryums.length,
                      boxes: fryums.fold<int>(0, (sum, p) => sum + p.godownStockBoxes),
                      onTap: () => widget.onNavigateTab(1),
                    ),
                    const SizedBox(width: 10),
                    _buildCategoryCard(
                      title: 'Juices & Drinks',
                      icon: Icons.local_drink_rounded,
                      color: const Color(0xFF059669),
                      skuCount: juices.length,
                      boxes: juices.fold<int>(0, (sum, p) => sum + p.godownStockBoxes),
                      onTap: () => widget.onNavigateTab(1),
                    ),
                    const SizedBox(width: 10),
                    _buildCategoryCard(
                      title: 'Biscuits & Cookies',
                      icon: Icons.cookie_rounded,
                      color: const Color(0xFFB45309),
                      skuCount: biscuits.length,
                      boxes: biscuits.fold<int>(0, (sum, p) => sum + p.godownStockBoxes),
                      onTap: () => widget.onNavigateTab(1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 4. QUICK SHORTCUTS BAR
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => WarehouseInwardView.showAsSheet(context, widget.api),
                        icon: const Icon(Icons.input_rounded, size: 16),
                        label: const Text('+ Receive Truck Inward (GRN)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => AddEditInventoryItemSheet.show(context, widget.api),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('+ Add Master SKU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbTheme.jodhpurBlue,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 5. LIVE ACTIVITY FEED: RECENT TRUCK INWARD RECEIPTS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Factory Truck Receipts',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(3),
                    child: const Text('All Inwards >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              if (recentInwards.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('No recent factory shipments received today', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                )
              else
                ...recentInwards.map((inw) => _buildInwardLogCard(inw)),

              const SizedBox(height: 20),

              // 6. LIVE ACTIVITY FEED: RECENT VAN DISPATCHES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Van Dispatches (Outward)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(3),
                    child: const Text('All Dispatches >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              if (recentDispatches.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('No van dispatches recorded today', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                )
              else
                ...recentDispatches.map((dsp) => _buildDispatchLogCard(dsp)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtext,
    String? badge,
    Color? badgeColor,
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
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeColor ?? color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 2),
            Text(
              subtext,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color color,
    required int skuCount,
    required int boxes,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              '$boxes Boxes',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
            ),
            Text(
              '$skuCount Active SKUs',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInwardLogCard(TruckInwardEntry inw) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              color: const Color(0xFF059669).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF059669), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      inw.truckNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${inw.arrivedAt.hour.toString().padLeft(2, '0')}:${inw.arrivedAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Supplier: ${inw.supplier} • Driver: ${inw.driverName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  '+${inw.totalCartons} Cartons Received (${inw.items.length} SKUs)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchLogCard(StockDispatchEntry dsp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.outbox_rounded, color: Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dsp.deliveryVehicle,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${dsp.dispatchedAt.hour.toString().padLeft(2, '0')}:${dsp.dispatchedAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Order: #${dsp.orderNumber} • ${dsp.shopName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dsp.totalCartons} Cartons Dispatched for Delivery',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
