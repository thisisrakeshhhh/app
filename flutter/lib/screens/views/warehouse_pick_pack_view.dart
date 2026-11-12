import 'package:flutter/material.dart';
import '../../l10n/language_controller.dart';
import '../../l10n/warehouse_delivery_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/warehouse_design.dart';

/// Screen 3: Sales Orders Pick & Pack Queue.
/// Enforces Owner Approval Gate: Inventory staff cannot approve orders or
/// pick/pack unapproved orders. Supports mixed-unit lines via CartItem.cartKey,
/// detailed picking with missing/damaged reporting, and separate packing verification.
class WarehousePickingView extends StatefulWidget {
  final ApiService api;
  const WarehousePickingView({super.key, required this.api});

  @override
  State<WarehousePickingView> createState() => _WarehousePickingViewState();
}

class _WarehousePickingViewState extends State<WarehousePickingView> {
  // Status filter: 'to_pick', 'picking', 'to_pack', 'ready', 'waiting_approval'
  String _activeFilter = 'to_pick';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.api, LanguageController.instance]),
      builder: (context, _) {
        final s = WdStrings.current;
        final allOrders = widget.api.orders;
        final trucks = widget.api.deliveryTrucks;

        final toPickOrders = allOrders
            .where((o) =>
                o.effectiveWarehouseStage == WarehouseTaskStage.approvedToPick ||
                o.effectiveWarehouseStage == WarehouseTaskStage.assignedToWorker)
            .toList();
        final pickingOrders = allOrders
            .where((o) => o.effectiveWarehouseStage == WarehouseTaskStage.pickingInProgress)
            .toList();
        final toPackOrders = allOrders
            .where((o) =>
                o.effectiveWarehouseStage == WarehouseTaskStage.waitingPacking ||
                o.effectiveWarehouseStage == WarehouseTaskStage.packingInProgress)
            .toList();
        final readyOrders = allOrders
            .where((o) => o.effectiveWarehouseStage == WarehouseTaskStage.packedReady)
            .toList();
        final waitingApprovalOrders = allOrders
            .where((o) => o.effectiveWarehouseStage == WarehouseTaskStage.waitingApproval)
            .toList();

        final List<DistributorOrder> visibleOrders = switch (_activeFilter) {
          'to_pick' => toPickOrders,
          'picking' => pickingOrders,
          'to_pack' => toPackOrders,
          'ready' => readyOrders,
          'waiting_approval' => waitingApprovalOrders,
          _ => toPickOrders,
        };

        return Container(
          color: WarehouseDesign.bg,
          child: Column(
            children: [
              // Top Header & Status Filter Chips
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: WarehouseDesign.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            s.pickPackTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: WarehouseDesign.textPrimary,
                            ),
                          ),
                        ),
                        WarehouseStatusPill(
                          label: '${toPickOrders.length + pickingOrders.length + toPackOrders.length} Active',
                          fg: WarehouseDesign.blue,
                          bg: WarehouseDesign.blueSoft,
                          borderColor: WarehouseDesign.blueBorder,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            keyId: 'to_pick',
                            label: '${s.approvedToPickLabel} (${toPickOrders.length})',
                            color: WarehouseDesign.blue,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            keyId: 'picking',
                            label: '${s.pickingInProgressLabel} (${pickingOrders.length})',
                            color: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            keyId: 'to_pack',
                            label: '${s.waitingPackingLabel} (${toPackOrders.length})',
                            color: WarehouseDesign.amber,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            keyId: 'ready',
                            label: '${s.packedReadyLabel} (${readyOrders.length})',
                            color: WarehouseDesign.green,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            keyId: 'waiting_approval',
                            label: '${s.waitingApprovalLabel} (${waitingApprovalOrders.length})',
                            color: WarehouseDesign.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Informational Notice when viewing Waiting for Owner Approval
              if (_activeFilter == 'waiting_approval')
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WarehouseDesign.amberSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: WarehouseDesign.amberBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 18, color: WarehouseDesign.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.ownerApprovalSubtitle(false),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Order List
              Expanded(
                child: visibleOrders.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 46, color: WarehouseDesign.textMuted),
                              const SizedBox(height: 10),
                              Text(
                                s.noApprovedOrdersEmpty,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: WarehouseDesign.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: visibleOrders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                          return _buildOrderCard(visibleOrders[idx], trucks, s);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String keyId,
    required String label,
    required Color color,
  }) {
    final isSelected = _activeFilter == keyId;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _activeFilter = keyId),
      selectedColor: color,
      backgroundColor: WarehouseDesign.bg,
      side: BorderSide(color: isSelected ? color : WarehouseDesign.border),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: isSelected ? Colors.white : WarehouseDesign.textPrimary,
      ),
    );
  }

  Widget _buildOrderCard(DistributorOrder ord, List<DeliveryTruck> trucks, WdStrings s) {
    final taskStage = ord.effectiveWarehouseStage;
    final isLocked = taskStage == WarehouseTaskStage.waitingApproval;

    final (statusLabel, statusFg, statusBg, statusBorder) = switch (taskStage) {
      WarehouseTaskStage.waitingApproval => (
          s.waitingApprovalLabel,
          WarehouseDesign.amber,
          WarehouseDesign.amberSoft,
          WarehouseDesign.amberBorder,
        ),
      WarehouseTaskStage.approvedToPick || WarehouseTaskStage.assignedToWorker => (
          s.approvedToPickLabel,
          WarehouseDesign.blue,
          WarehouseDesign.blueSoft,
          WarehouseDesign.blueBorder,
        ),
      WarehouseTaskStage.pickingInProgress => (
          s.pickingInProgressLabel,
          const Color(0xFF7C3AED),
          const Color(0xFFF5F3FF),
          const Color(0xFFDDD6FE),
        ),
      WarehouseTaskStage.waitingPacking || WarehouseTaskStage.packingInProgress => (
          s.waitingPackingLabel,
          WarehouseDesign.amber,
          WarehouseDesign.amberSoft,
          WarehouseDesign.amberBorder,
        ),
      WarehouseTaskStage.packedReady => (
          s.packedReadyLabel,
          WarehouseDesign.green,
          WarehouseDesign.greenSoft,
          WarehouseDesign.greenBorder,
        ),
      WarehouseTaskStage.handedOver => (
          s.handedOverLabel,
          WarehouseDesign.green,
          WarehouseDesign.greenSoft,
          WarehouseDesign.greenBorder,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: WarehouseDesign.cardDecoration(
        borderColor: isLocked ? WarehouseDesign.amberBorder : WarehouseDesign.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Order # + Status Pill
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${ord.orderNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: WarehouseDesign.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              WarehouseStatusPill(
                label: statusLabel,
                fg: statusFg,
                bg: statusBg,
                borderColor: statusBorder,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Retailer & Address
          Text(
            ord.shopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: WarehouseDesign.textPrimary),
          ),
          if (ord.address.isNotEmpty)
            Text(
              ord.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: WarehouseDesign.textMuted),
            ),

          const SizedBox(height: 10),

          // Compact Summary Strip: Items, Value, Assigned Worker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: WarehouseDesign.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WarehouseDesign.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${ord.items.length} Items • ₹${ord.totalRupees.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: WarehouseDesign.textPrimary),
                  ),
                ),
                Text(
                  ord.assignedWorkerName.isNotEmpty ? 'Worker: ${ord.assignedWorkerName}' : 'Unassigned',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WarehouseDesign.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Line Items Preview (Original unit + equivalent base pieces)
          ...ord.items.map((it) {
            final equivPcs = it.totalPieces;
            final prod = widget.api.products.firstWhere((p) => p.id == it.product.id, orElse: () => it.product);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: WarehouseDesign.blueSoft,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${it.quantity} ${it.unit.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: WarehouseDesign.blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prod.nameForLanguage(LanguageController.instance.currentLanguage),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: WarehouseDesign.textPrimary),
                    ),
                  ),
                  Text(
                    '= $equivPcs pcs',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: WarehouseDesign.textMuted),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Action Row (Strictly enforced by Owner Approval Gate!)
          if (isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: WarehouseDesign.amberSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: WarehouseDesign.amberBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, size: 16, color: WarehouseDesign.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.ownerApprovalStatus(false),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            )
          else if (taskStage == WarehouseTaskStage.approvedToPick ||
              taskStage == WarehouseTaskStage.assignedToWorker ||
              taskStage == WarehouseTaskStage.pickingInProgress)
            SizedBox(
              width: double.infinity,
              height: WarehouseDesign.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.api.startPickingOrder(ord.id);
                  _openDetailedPickingSheet(context, ord, s);
                },
                icon: const Icon(Icons.shopping_basket_rounded, size: 18),
                label: Text(
                  taskStage == WarehouseTaskStage.pickingInProgress ? 'CONTINUE PICKING' : s.startPickingBtn,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WarehouseDesign.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          else if (taskStage == WarehouseTaskStage.waitingPacking ||
              taskStage == WarehouseTaskStage.packingInProgress)
            SizedBox(
              width: double.infinity,
              height: WarehouseDesign.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: () => _openPackingVerificationSheet(context, ord, s),
                icon: const Icon(Icons.inventory_2_rounded, size: 18),
                label: Text(
                  s.verifyAndPackBtn,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WarehouseDesign.amber,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          else if (taskStage == WarehouseTaskStage.packedReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: WarehouseDesign.greenSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: WarehouseDesign.greenBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: WarehouseDesign.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Packed (${ord.packedCartonCount} Cartons) • Ready in Handover tab',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Dedicated Detailed Picking Sheet:
  /// Keys every line by CartItem.cartKey (`productId::unit`), displays saved packaging conversion,
  /// equivalent base quantity, shelf location, available stock, picked qty stepper,
  /// and explicit missing/damaged quantity recording.
  void _openDetailedPickingSheet(BuildContext context, DistributorOrder ord, WdStrings s) {
    final Map<String, int> pickedQty = {
      for (final it in ord.items) it.cartKey: ord.pickedLineQuantities[it.cartKey] ?? it.quantity,
    };
    final Map<String, int> damagedQty = {
      for (final it in ord.items) it.cartKey: ord.damagedLineQuantities[it.cartKey] ?? 0,
    };
    final Map<String, String> notes = Map<String, String>.from(ord.lineIssueNotes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(color: WarehouseDesign.border, borderRadius: BorderRadius.circular(10)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pick Order #${ord.orderNumber}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: WarehouseDesign.textPrimary),
                              ),
                              Text(
                                '${ord.shopName} • ${ord.items.length} Lines',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: WarehouseDesign.textMuted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: ord.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, idx) {
                        final it = ord.items[idx];
                        final prod = widget.api.products.firstWhere((p) => p.id == it.product.id, orElse: () => it.product);
                        final unitMult = prod.piecesForUnit(it.unit);
                        final equivPcs = it.quantity * unitMult;
                        final curPicked = pickedQty[it.cartKey] ?? it.quantity;
                        final curDamaged = damagedQty[it.cartKey] ?? 0;
                        final availBoxes = widget.api.availableGodownBoxes(prod.id);
                        final availPcs = widget.api.availableGodownPieces(prod.id);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: WarehouseDesign.cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: WarehouseDesign.blueSoft,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: prod.imageUrl.isNotEmpty
                                        ? Image.network(
                                            prod.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, color: WarehouseDesign.blue),
                                          )
                                        : const Icon(Icons.inventory_2_outlined, color: WarehouseDesign.blue),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.nameForLanguage(LanguageController.instance.currentLanguage),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: WarehouseDesign.textPrimary),
                                        ),
                                        Text(
                                          prod.shelfLocation.isNotEmpty
                                              ? 'Shelf: ${prod.shelfLocation} • Available: $availBoxes bxs ($availPcs pcs)'
                                              : 'Available: $availBoxes bxs ($availPcs pcs)',
                                          style: const TextStyle(fontSize: 11, color: WarehouseDesign.textMuted, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: WarehouseDesign.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: WarehouseDesign.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('REQUESTED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: WarehouseDesign.textMuted)),
                                        Text(
                                          '${it.quantity} ${it.unit.name.toUpperCase()}',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: WarehouseDesign.blue),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const Text('CONVERSION', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: WarehouseDesign.textMuted)),
                                        Text(
                                          '1 ${it.unit.name} = $unitMult pcs',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: WarehouseDesign.textPrimary),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('EQUIVALENT', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: WarehouseDesign.textMuted)),
                                        Text(
                                          '$equivPcs pcs',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: WarehouseDesign.textPrimary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Picked Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WarehouseDesign.green)),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: curPicked > 0
                                                  ? () => setSheetState(() => pickedQty[it.cartKey] = curPicked - 1)
                                                  : null,
                                              icon: const Icon(Icons.remove_circle_outline),
                                            ),
                                            Text('$curPicked', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                            IconButton(
                                              onPressed: curPicked < it.quantity
                                                  ? () => setSheetState(() => pickedQty[it.cartKey] = curPicked + 1)
                                                  : null,
                                              icon: const Icon(Icons.add_circle_outline, color: WarehouseDesign.green),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Damaged / Missing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WarehouseDesign.red)),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: curDamaged > 0
                                                  ? () => setSheetState(() => damagedQty[it.cartKey] = curDamaged - 1)
                                                  : null,
                                              icon: const Icon(Icons.remove_circle_outline),
                                            ),
                                            Text('$curDamaged', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: WarehouseDesign.red)),
                                            IconButton(
                                              onPressed: () => setSheetState(() => damagedQty[it.cartKey] = curDamaged + 1),
                                              icon: const Icon(Icons.add_circle_outline, color: WarehouseDesign.red),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (curDamaged > 0 || curPicked < it.quantity)
                                TextField(
                                  onChanged: (v) => notes[it.cartKey] = v,
                                  decoration: const InputDecoration(
                                    hintText: 'Reason for missing / damaged item...',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: WarehouseDesign.border)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: WarehouseDesign.buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await widget.api.completePickingOrder(
                            ord.id,
                            pickedQtyByCartKey: pickedQty,
                            damagedQtyByCartKey: damagedQty,
                            issueNotes: notes,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() => _activeFilter = 'to_pack');
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Picking completed for #${ord.orderNumber}! Moved to Packing.'
                                      : 'Order must be approved by Owner first.',
                                ),
                                backgroundColor: ok ? WarehouseDesign.green : WarehouseDesign.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Complete Picking -> Move to Packing', style: TextStyle(fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WarehouseDesign.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Separate Packing Verification Sheet:
  /// Requires line verification, package/carton count, and explicit confirmation
  /// before moving the order to Packed / Ready for Dispatch.
  void _openPackingVerificationSheet(BuildContext context, DistributorOrder ord, WdStrings s) {
    final Set<String> verifiedLines = {
      for (final it in ord.items) it.cartKey,
    };
    int cartonCount = ord.packedCartonCount > 0 ? ord.packedCartonCount : 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final allVerified = ord.items.isNotEmpty && ord.items.every((it) => verifiedLines.contains(it.cartKey));

            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.82,
                child: Column(
                  children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(color: WarehouseDesign.border, borderRadius: BorderRadius.circular(10)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verify & Pack #${ord.orderNumber}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: WarehouseDesign.textPrimary),
                              ),
                              Text(
                                'Retailer: ${ord.shopName}',
                                style: const TextStyle(fontSize: 12, color: WarehouseDesign.textMuted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ...ord.items.map((it) {
                          final isChecked = verifiedLines.contains(it.cartKey);
                          final picked = ord.pickedLineQuantities[it.cartKey] ?? it.quantity;
                          final damaged = ord.damagedLineQuantities[it.cartKey] ?? 0;

                          return CheckboxListTile(
                            value: isChecked,
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  verifiedLines.add(it.cartKey);
                                } else {
                                  verifiedLines.remove(it.cartKey);
                                }
                              });
                            },
                            activeColor: WarehouseDesign.green,
                            title: Text(
                              '${it.product.name} (${it.unit.name.toUpperCase()})',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            subtitle: Text(
                              'Requested: ${it.quantity} • Picked: $picked${damaged > 0 ? " • Damaged: $damaged" : ""}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: WarehouseDesign.cardDecoration(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Packed Cartons', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                    Text('Enter final carton/package count', style: TextStyle(fontSize: 11, color: WarehouseDesign.textMuted)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: cartonCount > 1 ? () => setSheetState(() => cartonCount--) : null,
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text('$cartonCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  IconButton(
                                    onPressed: () => setSheetState(() => cartonCount++),
                                    icon: const Icon(Icons.add_circle_outline, color: WarehouseDesign.blue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: WarehouseDesign.border)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: WarehouseDesign.buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: allVerified
                            ? () {
                                final ok = widget.api.completePackingOrder(
                                  ord.id,
                                  cartonCount: cartonCount,
                                  packingWorkerName: 'Manoj Kumar',
                                );
                                Navigator.pop(ctx);
                                if (mounted) {
                                  setState(() => _activeFilter = 'ready');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Order #${ord.orderNumber} packed ($cartonCount cartons) & Ready for Dispatch!'
                                            : 'Cannot pack unapproved order.',
                                      ),
                                      backgroundColor: ok ? WarehouseDesign.green : WarehouseDesign.red,
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Confirm Packing & Mark Ready for Dispatch', style: TextStyle(fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WarehouseDesign.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      },
    );
  }
}
