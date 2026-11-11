import 'package:flutter/material.dart';
import '../../features/sales/widgets/sales_language_picker.dart';
import '../../l10n/app_language.dart';
import '../../l10n/language_controller.dart';
import '../../l10n/warehouse_delivery_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import '../views/add_edit_inventory_item_sheet.dart';
import '../views/warehouse_subviews.dart';

/// Modern, Polished FMCG Godown & Warehouse Landing Dashboard.
/// Supports 4 languages: English, Hinglish, Hindi (हिन्दी), and Gujarati (ગુજરાતી).
/// Features instant language toggling, multi-category inventory metrics (Juices, Namkeen, Biscuits, Wafers),
/// real-time SQLite DB counters, and one-tap access to Truck Inward, Picking, and Movement Registers.
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
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Juices & Cold Drinks',
    'Traditional Namkeen',
    'Potato Wafers',
    'Extruded Snacks & Fryums',
    'Biscuits & Bakery',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.api, LanguageController.instance]),
      builder: (context, _) {
        final strings = WdStrings.current;
        final currentLang = LanguageController.instance.currentLanguage;
        final products = widget.api.products;
        final totalBoxes = widget.api.totalGodownBoxes;
        final totalValuation = products.fold<double>(0.0, (sum, p) => sum + p.godownValuationRupees);
        final pendingOrders = widget.api.orders.where((o) => o.stage == OrderLifecycleStage.booking).toList();
        final waitingApprovalCount = pendingOrders.where((o) => !o.isOwnerApproved).length;
        final readyToPickCount = pendingOrders.where((o) => o.isOwnerApproved).length;

        final recentInwards = widget.api.truckInwardLog.take(3).toList();
        final recentDispatches = widget.api.stockDispatchLog.take(3).toList();

        // Filter products by category if selected
        final categoryProducts = _selectedCategory == 'All'
            ? products
            : products.where((p) => p.category == _selectedCategory).toList();
        final categoryBoxes = categoryProducts.fold<int>(0, (sum, p) => sum + p.godownStockBoxes);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SLEEK WAREHOUSE HERO BANNER
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
                    // Top Row: Facility Info + Language Switcher + Add SKU
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.warehouse_rounded, color: Color(0xFF60A5FA), size: 22),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
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
                                    SizedBox(height: 1),
                                    Text(
                                      'Basni Industrial Area Phase II (Real-Time DB)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                      ),
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
                            // 1-Tap Quick Language Pill
                            InkWell(
                              onTap: () => SalesLanguagePicker.showSheet(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

                    const SizedBox(height: 18),

                    // Stock Counter Label
                    const Text(
                      'Godown Stock',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),

                    // Big Numbers Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$totalBoxes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${strings.boxesUnit} / पेटी',
                          style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Stock Valuation', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalValuation.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFF34D399), fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Van Stock & Expiry Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              const Icon(Icons.local_shipping_outlined, color: Color(0xFF93C5FD), size: 16),
                              const SizedBox(width: 6),
                              const Text('Loaded in Van', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w700)),
                              Text(': ${widget.api.totalCarBoxes} Boxes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          InkWell(
                            onTap: () => widget.onNavigateTab(1),
                            child: const Row(
                              children: [
                                Text('Expiry Radar', style: TextStyle(color: Color(0xFFFCD34D), fontSize: 11.5, fontWeight: FontWeight.w700)),
                                SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios, color: Color(0xFFFCD34D), size: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. PRODUCT CATEGORY QUICK-FILTER CAROUSEL (Juices, Namkeen, Biscuits, Wafers)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final cat = _categories[idx];
                    final isSelected = _selectedCategory == cat;
                    final displayName = strings.categoryName(cat);

                    return InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Category overview chip when filtered
              if (_selectedCategory != 'All') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${strings.categoryName(_selectedCategory)}: ${categoryProducts.length} Products',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E40AF)),
                      ),
                      Text(
                        '$categoryBoxes ${strings.boxesUnit}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 3. OWNER APPROVAL ALERT BANNER (If any orders waiting)
              if (waitingApprovalCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                              strings.waitingApprovalBanner(waitingApprovalCount),
                              style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              strings.waitingApprovalSub,
                              style: const TextStyle(color: Color(0xFFB45309), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => widget.onNavigateTab(2),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(strings.checkOrdersBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),

              // 4. CORE GODOWN WORK OPERATIONS (2x2 Grid)
              Text(
                strings.operationsHeader,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AirbnbTheme.dark),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildOperationCard(
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF059669),
                      title: strings.stockListTitle,
                      subtitle: strings.stockListSubtitle(totalBoxes),
                      badge: 'CRUD',
                      onTap: () => widget.onNavigateTab(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOperationCard(
                      icon: Icons.checklist_rtl_rounded,
                      color: const Color(0xFF2563EB),
                      title: strings.pickPackTitle,
                      subtitle: strings.pickPackSubtitle(readyToPickCount, waitingApprovalCount),
                      badge: pendingOrders.isNotEmpty ? '${pendingOrders.length}' : null,
                      onTap: () => widget.onNavigateTab(2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildOperationCard(
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFFD97706),
                      title: 'Handover to Driver',
                      subtitle: 'Van loading & driver dispatch',
                      badge: null,
                      onTap: () => widget.onNavigateTab(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOperationCard(
                      icon: Icons.input_rounded,
                      color: const Color(0xFF7C3AED),
                      title: strings.truckInwardTitle,
                      subtitle: strings.truckInwardSubtitle,
                      badge: 'NEW',
                      onTap: () => WarehouseInwardView.showAsSheet(context, widget.api),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 5. RECENT TRUCK INWARD SHIPMENTS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.recentTrucksTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(3),
                    child: Text(strings.viewAllBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
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
                    child: Text('No recent truck shipments recorded', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                )
              else
                ...recentInwards.map((inw) => _buildInwardSummaryTile(inw, strings)),

              const SizedBox(height: 20),

              // 6. RECENT DISPATCHES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.recentDispatchTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateTab(3),
                    child: Text(strings.viewAllBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
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
                    child: Text('No recent dispatches recorded', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                )
              else
                ...recentDispatches.map((dsp) => _buildDispatchSummaryTile(dsp, strings)),
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        height: 135,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
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

  Widget _buildInwardSummaryTile(TruckInwardEntry inw, WdStrings strings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping, color: Color(0xFF059669), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        inw.truckNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        inw.driverName.isNotEmpty ? inw.driverName : inw.supplier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${inw.items.length} SKUs • ${inw.totalCartons} ${strings.boxesUnit}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('SAVED', style: TextStyle(color: Color(0xFF059669), fontSize: 9.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 3),
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

  Widget _buildDispatchSummaryTile(StockDispatchEntry dsp, WdStrings strings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
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
                  '${dsp.itemsSummary} (${dsp.totalCartons} ${strings.boxesUnit})',
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
                child: Text(dsp.deliveryVehicle, style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 9.5, fontWeight: FontWeight.w800)),
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
