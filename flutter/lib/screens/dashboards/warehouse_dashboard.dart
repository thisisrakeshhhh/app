import 'package:flutter/material.dart';
import '../../features/sales/widgets/sales_language_picker.dart';
import '../../l10n/app_language.dart';
import '../../l10n/language_controller.dart';
import '../../l10n/warehouse_delivery_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import '../../theme/warehouse_design.dart';
import '../views/add_edit_inventory_item_sheet.dart';
import '../views/warehouse_subviews.dart';

/// Modern, high-contrast Warehouse & Inventory Home Dashboard.
/// Designed so a warehouse worker understands what to do next within 5 seconds.
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
  void _showNotificationsSheet(
    BuildContext context, {
    required int approvedToPickCount,
    required int packedReadyCount,
    required List<ProductItem> lowStockItems,
    required List<ProductItem> expiringItems,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: WarehouseDesign.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Warehouse Alerts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: WarehouseDesign.textPrimary),
                ),
                const SizedBox(height: 12),
                if (approvedToPickCount == 0 &&
                    packedReadyCount == 0 &&
                    lowStockItems.isEmpty &&
                    expiringItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'All caught up! No urgent alerts right now.',
                        style: TextStyle(fontSize: 13, color: WarehouseDesign.textMuted),
                      ),
                    ),
                  ),
                if (approvedToPickCount > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: WarehouseDesign.blueSoft,
                      child: Icon(Icons.playlist_add_check_rounded, color: WarehouseDesign.blue),
                    ),
                    title: Text('$approvedToPickCount Approved Orders to Pick',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('Tap to open Pick & Pack queue', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onNavigateTab(2);
                    },
                  ),
                if (packedReadyCount > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: WarehouseDesign.greenSoft,
                      child: Icon(Icons.local_shipping_rounded, color: WarehouseDesign.green),
                    ),
                    title: Text('$packedReadyCount Packed Orders Ready for Driver',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('Tap to open Vehicle Handover', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onNavigateTab(3);
                    },
                  ),
                if (lowStockItems.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: WarehouseDesign.amberSoft,
                      child: Icon(Icons.warning_amber_rounded, color: WarehouseDesign.amber),
                    ),
                    title: Text('${lowStockItems.length} SKUs Low / Out of Stock',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: Text(
                      lowStockItems.take(3).map((e) => e.name).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onNavigateTab(1);
                    },
                  ),
                if (expiringItems.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: WarehouseDesign.redSoft,
                      child: Icon(Icons.timelapse_rounded, color: WarehouseDesign.red),
                    ),
                    title: Text('${expiringItems.length} Batches Expiring Soon / Expired',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('Check Expiry Radar in Godown Stock', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onNavigateTab(1);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.api, LanguageController.instance]),
      builder: (context, _) {
        final s = WdStrings.current;
        final currentLang = LanguageController.instance.currentLanguage;
        final products = widget.api.products.where((p) => !p.isArchived).toList();

        // Physical, Reserved, and Available stock calculated via real product conversions
        final totalPhysicalBoxes = products.fold<int>(0, (sum, p) => sum + p.godownStockBoxes);
        final totalPhysicalPieces = products.fold<int>(0, (sum, p) => sum + (p.godownStockBoxes * p.boxQty));
        final totalReservedPieces = products.fold<int>(0, (sum, p) => sum + widget.api.pendingBookingPieces(p.id));
        final totalReservedBoxes = products.fold<int>(0, (sum, p) => sum + widget.api.pendingBookingBoxes(p.id));
        final totalAvailablePieces = products.fold<int>(0, (sum, p) => sum + widget.api.availableGodownPieces(p.id));
        final totalAvailableBoxes = products.fold<int>(0, (sum, p) => sum + widget.api.availableGodownBoxes(p.id));
        final totalValuation = products.fold<double>(0.0, (sum, p) => sum + p.godownValuationRupees);

        // Live Operation Stage Counts
        final allOrders = widget.api.orders;
        final waitingApprovalCount =
            allOrders.where((o) => o.effectiveWarehouseStage == WarehouseTaskStage.waitingApproval).length;
        final approvedToPickCount = allOrders
            .where((o) =>
                o.effectiveWarehouseStage == WarehouseTaskStage.approvedToPick ||
                o.effectiveWarehouseStage == WarehouseTaskStage.assignedToWorker)
            .length;
        final pickingInProgressCount =
            allOrders.where((o) => o.effectiveWarehouseStage == WarehouseTaskStage.pickingInProgress).length;
        final waitingPackingCount = allOrders
            .where((o) =>
                o.effectiveWarehouseStage == WarehouseTaskStage.waitingPacking ||
                o.effectiveWarehouseStage == WarehouseTaskStage.packingInProgress)
            .length;
        final packedReadyCount =
            allOrders.where((o) => o.effectiveWarehouseStage == WarehouseTaskStage.packedReady).length;
        final handedOverCount =
            allOrders.where((o) => o.effectiveWarehouseStage == WarehouseTaskStage.handedOver).length;

        final trucks = widget.api.deliveryTrucks;
        final vehiclesLoadingCount = trucks.where((t) => t.totalLoadedBoxes > 0).length;

        final lowStockItems = products.where((p) => p.isLowStock || p.isOutOfStock).toList();
        final expiringItems = products.where((p) => p.isExpiringSoon || p.isExpired).toList();
        final alertBadgeCount =
            (approvedToPickCount > 0 ? 1 : 0) + (lowStockItems.isNotEmpty ? 1 : 0) + (expiringItems.isNotEmpty ? 1 : 0);

        final recentInwards = widget.api.truckInwardLog.take(3).toList();
        final recentDispatches = widget.api.stockDispatchLog.take(3).toList();

        return Container(
          color: WarehouseDesign.bg,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. CLEAN HEADER: Welcome, Employee, Warehouse, Shift, Language, Notifications
                _buildCleanHeader(
                  context,
                  s: s,
                  currentLang: currentLang,
                  alertBadgeCount: alertBadgeCount,
                  onOpenAlerts: () => _showNotificationsSheet(
                    context,
                    approvedToPickCount: approvedToPickCount,
                    packedReadyCount: packedReadyCount,
                    lowStockItems: lowStockItems,
                    expiringItems: expiringItems,
                  ),
                ),

                const SizedBox(height: 14),

                // 2. NEXT PRIORITY ACTION (5-second clarity for warehouse worker)
                _buildNextActionBanner(
                  s: s,
                  approvedToPickCount: approvedToPickCount,
                  waitingPackingCount: waitingPackingCount,
                  packedReadyCount: packedReadyCount,
                ),

                const SizedBox(height: 14),

                // 3. GODOWN OVERVIEW (Dark Navy Summary Card)
                _buildGodownOverviewCard(
                  s: s,
                  totalSkus: products.length,
                  physicalBoxes: totalPhysicalBoxes,
                  physicalPieces: totalPhysicalPieces,
                  reservedBoxes: totalReservedBoxes,
                  reservedPieces: totalReservedPieces,
                  availableBoxes: totalAvailableBoxes,
                  availablePieces: totalAvailablePieces,
                  totalValuation: totalValuation,
                  carBoxes: widget.api.totalCarBoxes,
                  expiringCount: expiringItems.length,
                ),

                const SizedBox(height: 20),

                // 4. TODAY'S OPERATIONS (Clickable workflow stage tiles)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        s.todaysOperationsTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: WarehouseDesign.textPrimary,
                        ),
                      ),
                    ),
                    if (waitingApprovalCount > 0)
                      WarehouseStatusPill(
                        label: '$waitingApprovalCount ${s.waitingApprovalLabel}',
                        fg: WarehouseDesign.amber,
                        bg: WarehouseDesign.amberSoft,
                        borderColor: WarehouseDesign.amberBorder,
                        icon: Icons.hourglass_top_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.52,
                  children: [
                    _buildOperationTile(
                      icon: Icons.playlist_add_check_rounded,
                      color: WarehouseDesign.blue,
                      count: '$approvedToPickCount',
                      label: s.approvedToPickLabel,
                      onTap: () => widget.onNavigateTab(2),
                    ),
                    _buildOperationTile(
                      icon: Icons.shopping_basket_rounded,
                      color: const Color(0xFF7C3AED),
                      count: '$pickingInProgressCount',
                      label: s.pickingInProgressLabel,
                      onTap: () => widget.onNavigateTab(2),
                    ),
                    _buildOperationTile(
                      icon: Icons.inventory_2_rounded,
                      color: WarehouseDesign.amber,
                      count: '$waitingPackingCount',
                      label: s.waitingPackingLabel,
                      onTap: () => widget.onNavigateTab(2),
                    ),
                    _buildOperationTile(
                      icon: Icons.check_circle_rounded,
                      color: WarehouseDesign.green,
                      count: '$packedReadyCount',
                      label: s.packedReadyLabel,
                      onTap: () => widget.onNavigateTab(3),
                    ),
                    _buildOperationTile(
                      icon: Icons.local_shipping_rounded,
                      color: WarehouseDesign.blue,
                      count: '$vehiclesLoadingCount / ${trucks.length}',
                      label: s.vehiclesLoadingLabel,
                      onTap: () => widget.onNavigateTab(3),
                    ),
                    _buildOperationTile(
                      icon: Icons.handshake_rounded,
                      color: WarehouseDesign.green,
                      count: '$handedOverCount',
                      label: s.handedOverLabel,
                      onTap: () => widget.onNavigateTab(3),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 5. PRIMARY WAREHOUSE SHORTCUTS
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: WarehouseDesign.buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: () => WarehouseInwardView.showAsSheet(context, widget.api),
                          icon: const Icon(Icons.input_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              s.receiveStockGrnBtn,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WarehouseDesign.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: WarehouseDesign.buttonHeight,
                        child: OutlinedButton.icon(
                          onPressed: () => AddEditInventoryItemSheet.show(context, widget.api),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '+ Add SKU',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: WarehouseDesign.blue,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: WarehouseDesign.blueBorder, width: 1.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // 6. RECENT STOCK MOVEMENTS (INWARD & DISPATCHES)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Factory Receipts (GRN)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: WarehouseDesign.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigateTab(3),
                      child: const Text('All Logs >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WarehouseDesign.blue)),
                    ),
                  ],
                ),
                if (recentInwards.isEmpty)
                  _buildEmptyRegister('No truck inward shipments recorded today')
                else
                  ...recentInwards.map((inw) => _buildInwardLogCard(inw)),

                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Driver Handovers',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: WarehouseDesign.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigateTab(3),
                      child: const Text('All Logs >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WarehouseDesign.blue)),
                    ),
                  ],
                ),
                if (recentDispatches.isEmpty)
                  _buildEmptyRegister('No dispatches recorded today')
                else
                  ...recentDispatches.map((dsp) => _buildDispatchLogCard(dsp)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCleanHeader(
    BuildContext context, {
    required WdStrings s,
    required AppLanguage currentLang,
    required int alertBadgeCount,
    required VoidCallback onOpenAlerts,
  }) {
    final branchName = widget.api.warehouseHubs.isNotEmpty
        ? widget.api.warehouseHubs.first.name
        : 'Main Warehouse';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: WarehouseDesign.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: WarehouseDesign.navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome, Manoj Kumar!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: WarehouseDesign.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$branchName • ${s.warehouseSubtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: WarehouseDesign.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => SalesLanguagePicker.showSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: WarehouseDesign.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: WarehouseDesign.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded, size: 14, color: WarehouseDesign.blue),
                  const SizedBox(width: 4),
                  Text(
                    currentLang.nativeName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WarehouseDesign.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onOpenAlerts,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: WarehouseDesign.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: WarehouseDesign.border),
                  ),
                  child: const Icon(Icons.notifications_outlined, size: 18, color: WarehouseDesign.textPrimary),
                ),
                if (alertBadgeCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: WarehouseDesign.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextActionBanner({
    required WdStrings s,
    required int approvedToPickCount,
    required int waitingPackingCount,
    required int packedReadyCount,
  }) {
    final String title;
    final String subtitle;
    final String ctaLabel;
    final Color accentColor;
    final Color bgColor;
    final Color borderColor;
    final VoidCallback onTap;

    if (approvedToPickCount > 0) {
      title = '$approvedToPickCount Approved Orders Waiting to Pick';
      subtitle = 'Owner approved. Tap to pick items from godown shelves.';
      ctaLabel = s.startPickingBtn;
      accentColor = WarehouseDesign.blue;
      bgColor = WarehouseDesign.blueSoft;
      borderColor = WarehouseDesign.blueBorder;
      onTap = () => widget.onNavigateTab(2);
    } else if (waitingPackingCount > 0) {
      title = '$waitingPackingCount Picked Orders Ready for Packing';
      subtitle = 'Verify picked items and pack cartons for delivery.';
      ctaLabel = s.verifyAndPackBtn;
      accentColor = WarehouseDesign.amber;
      bgColor = WarehouseDesign.amberSoft;
      borderColor = WarehouseDesign.amberBorder;
      onTap = () => widget.onNavigateTab(2);
    } else if (packedReadyCount > 0) {
      title = '$packedReadyCount Packed Orders Ready for Handover';
      subtitle = 'Assign delivery vehicle and hand over cartons to driver.';
      ctaLabel = s.handoverConfirmBtn;
      accentColor = WarehouseDesign.green;
      bgColor = WarehouseDesign.greenSoft;
      borderColor = WarehouseDesign.greenBorder;
      onTap = () => widget.onNavigateTab(3);
    } else {
      title = 'Queue Clear — Receive Incoming Stock';
      subtitle = 'All approved orders handled. Record factory GRN or inspect stock.';
      ctaLabel = s.receiveStockGrnBtn;
      accentColor = WarehouseDesign.green;
      bgColor = WarehouseDesign.greenSoft;
      borderColor = WarehouseDesign.greenBorder;
      onTap = () => WarehouseInwardView.showAsSheet(context, widget.api);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.3),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bolt_rounded, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: accentColor),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: WarehouseDesign.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(ctaLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildGodownOverviewCard({
    required WdStrings s,
    required int totalSkus,
    required int physicalBoxes,
    required int physicalPieces,
    required int reservedBoxes,
    required int reservedPieces,
    required int availableBoxes,
    required int availablePieces,
    required double totalValuation,
    required int carBoxes,
    required int expiringCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WarehouseDesign.navy, WarehouseDesign.navySlate],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: WarehouseDesign.navy.withValues(alpha: 0.2),
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
              Expanded(
                child: Text(
                  s.godownOverviewTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalSkus ${s.totalSkusLabel}',
                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Physical Stock & Valuation Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.godownStock,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$physicalBoxes',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.boxesUnit,
                          style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text(
                      '($physicalPieces pcs)',
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.stockValuation,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${totalValuation.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Physical / Reserved / Available 3-Column Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildOverviewStat(
                    label: s.physicalStockLabel,
                    value: '$physicalBoxes bxs',
                    sub: '$physicalPieces pcs',
                    valueColor: Colors.white,
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white12),
                Expanded(
                  child: _buildOverviewStat(
                    label: s.reservedStockLabel,
                    value: '$reservedBoxes bxs',
                    sub: '$reservedPieces pcs',
                    valueColor: const Color(0xFFFCD34D),
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white12),
                Expanded(
                  child: _buildOverviewStat(
                    label: s.availableStockLabel,
                    value: '$availableBoxes bxs',
                    sub: '$availablePieces pcs',
                    valueColor: const Color(0xFF34D399),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Footer: Loaded in Van & Expiry Radar
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: Color(0xFF60A5FA), size: 15),
              const SizedBox(width: 5),
              Text(
                s.loadedInVan,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              Text(
                ': $carBoxes ${s.boxesUnit}',
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              InkWell(
                onTap: () => widget.onNavigateTab(1),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timelapse_outlined,
                        color: expiringCount > 0 ? const Color(0xFFFBBF24) : Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s.expiryRadar,
                        style: TextStyle(
                          color: expiringCount > 0 ? const Color(0xFFFBBF24) : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (expiringCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($expiringCount)',
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat({
    required String label,
    required String value,
    required String sub,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w900),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildOperationTile({
    required IconData icon,
    required Color color,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: WarehouseDesign.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: WarehouseDesign.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 16, color: WarehouseDesign.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRegister(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: WarehouseDesign.cardDecoration(),
      child: Center(
        child: Text(text, style: const TextStyle(color: WarehouseDesign.textMuted, fontSize: 12)),
      ),
    );
  }

  Widget _buildInwardLogCard(TruckInwardEntry inw) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: WarehouseDesign.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WarehouseDesign.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_outlined, color: WarehouseDesign.green, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${inw.truckNumber} • ${inw.supplier}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: WarehouseDesign.textPrimary),
                ),
                Text(
                  '${inw.totalCartons} Boxes • ${_formatTime(inw.arrivedAt)}',
                  style: const TextStyle(fontSize: 11, color: WarehouseDesign.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const WarehouseStatusPill(
            label: 'INWARD',
            fg: WarehouseDesign.green,
            bg: WarehouseDesign.greenSoft,
            borderColor: WarehouseDesign.greenBorder,
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchLogCard(StockDispatchEntry dsp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: WarehouseDesign.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WarehouseDesign.blueSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.outbox_rounded, color: WarehouseDesign.blue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dsp.orderNumber} • ${dsp.shopName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: WarehouseDesign.textPrimary),
                ),
                Text(
                  'Van: ${dsp.deliveryVehicle} • ${dsp.totalCartons} Boxes • ${_formatTime(dsp.dispatchedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: WarehouseDesign.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const WarehouseStatusPill(
            label: 'DISPATCH',
            fg: WarehouseDesign.blue,
            bg: WarehouseDesign.blueSoft,
            borderColor: WarehouseDesign.blueBorder,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

/// Reusable bottom-navigation shell for Warehouse / Inventory role.
class WarehouseRoleShell extends StatefulWidget {
  final ApiService api;
  const WarehouseRoleShell({super.key, required this.api});

  @override
  State<WarehouseRoleShell> createState() => _WarehouseRoleShellState();
}

class _WarehouseRoleShellState extends State<WarehouseRoleShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarehouseDesign.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          WarehouseDashboard(
            api: widget.api,
            onNavigateTab: (tab) => setState(() => _currentIndex = tab),
          ),
          WarehouseStockView(api: widget.api),
          WarehousePickingView(api: widget.api),
          WarehouseLoadingView(api: widget.api),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AirbnbTheme.jodhpurBlue,
        unselectedItemColor: WarehouseDesign.textMuted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Godown Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_add_check_rounded), label: 'Pick & Pack'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_rounded), label: 'Handover to Driver'),
        ],
      ),
    );
  }
}
