import 'package:flutter/material.dart';
import '../../l10n/language_controller.dart';
import '../../l10n/warehouse_delivery_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/warehouse_design.dart';

/// Screen 4: Vehicle Loading & Handover.
/// Cleanly separates:
/// 1. Packed Order Handover to Delivery Person (with explicit confirmation)
/// 2. Godown-to-Vehicle Stock Transfer & Capacity
/// 3. Inward Log (GRN) & Dispatch Register
class WarehouseLoadingView extends StatefulWidget {
  final ApiService api;
  const WarehouseLoadingView({super.key, required this.api});

  @override
  State<WarehouseLoadingView> createState() => _WarehouseLoadingViewState();
}

class _WarehouseLoadingViewState extends State<WarehouseLoadingView> {
  final Map<String, bool> _transferLoading = {};

  Future<void> _executeTransfer(
    ProductItem product,
    DeliveryTruck truck,
    int boxDelta,
  ) async {
    setState(() => _transferLoading[product.id] = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await widget.api.transferStockToCar(
        product.id,
        boxDelta,
        targetTruckId: truck.id,
      );
      if (mounted) {
        setState(() => _transferLoading[product.id] = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? (boxDelta >= 0
                      ? 'Transferred $boxDelta boxes of ${product.name} to ${truck.vehicleNumber}'
                      : 'Unloaded ${boxDelta.abs()} boxes of ${product.name} back to Godown')
                  : 'Insufficient stock for transfer.',
            ),
            backgroundColor: ok ? WarehouseDesign.green : WarehouseDesign.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _transferLoading[product.id] = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Transfer failed: $e'),
            backgroundColor: WarehouseDesign.red,
          ),
        );
      }
    }
  }

  void _showCustomTransferDialog(ProductItem product, DeliveryTruck truck) {
    final qtyCtrl = TextEditingController(text: '5');
    OrderUnit selectedUnit = OrderUnit.box;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
          final unitMult = product.piecesForUnit(selectedUnit);
          final equivPcs = qty * unitMult;
          final boxesRequired = product.boxQty > 0 ? (equivPcs / product.boxQty).ceil() : qty;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Transfer ${product.name}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Godown: ${product.godownStockBoxes} Boxes • In Van (${truck.vehicleNumber}): ${truck.getStockForProduct(product.id)} Boxes',
                  style: const TextStyle(fontSize: 12, color: WarehouseDesign.textMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<OrderUnit>(
                  initialValue: selectedUnit,
                  decoration: const InputDecoration(
                    labelText: 'Transfer Unit',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [OrderUnit.box, OrderUnit.strip, OrderUnit.piece]
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text('${u.name.toUpperCase()} (1 = ${product.piecesForUnit(u)} pcs)'),
                          ))
                      .toList(),
                  onChanged: (u) {
                    if (u != null) setDialogState(() => selectedUnit = u);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Transfer Quantity',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Equivalent: $equivPcs pcs ($boxesRequired boxes)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: WarehouseDesign.blue),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (qty <= 0 || boxesRequired > product.godownStockBoxes) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invalid quantity! Max godown stock: ${product.godownStockBoxes} boxes.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await _executeTransfer(product, truck, boxesRequired);
                },
                style: ElevatedButton.styleFrom(backgroundColor: WarehouseDesign.blue, foregroundColor: Colors.white),
                child: const Text('Confirm Transfer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showHandoverConfirmationDialog(DistributorOrder ord, DeliveryTruck truck) {
    final driverCtrl = TextEditingController(text: truck.driverName);
    final handedByCtrl = TextEditingController(text: 'Manoj Kumar');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.handshake_rounded, color: WarehouseDesign.green),
            SizedBox(width: 8),
            Expanded(
              child: Text('Confirm Driver Handover', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${ord.orderNumber} • ${ord.shopName}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
            const SizedBox(height: 4),
            Text(
              '${ord.items.length} Items • ${ord.packedCartonCount} Cartons • ₹${ord.totalRupees.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: WarehouseDesign.textMuted, fontWeight: FontWeight.w600),
            ),
            Text(
              'Vehicle: ${truck.vehicleNumber} (${truck.vehicleModel})',
              style: const TextStyle(fontSize: 12, color: WarehouseDesign.blue, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: handedByCtrl,
              decoration: const InputDecoration(
                labelText: 'Handed Over By (Warehouse)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: driverCtrl,
              decoration: const InputDecoration(
                labelText: 'Received By (Delivery Person)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              final handedBy = handedByCtrl.text.trim().isEmpty ? 'Manoj Kumar' : handedByCtrl.text.trim();
              final driver = driverCtrl.text.trim().isEmpty ? truck.driverName : driverCtrl.text.trim();
              final ok = widget.api.confirmOrderHandoverToDriver(
                ord.id,
                handedOverBy: handedBy,
                receivedByDriver: driver,
                vehicleNumber: truck.vehicleNumber,
              );
              Navigator.pop(ctx);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Handed over #${ord.orderNumber} to $driver (${truck.vehicleNumber})!'
                          : 'Cannot hand over unapproved or unpacked order.',
                    ),
                    backgroundColor: ok ? WarehouseDesign.green : WarehouseDesign.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Confirm Handover'),
            style: ElevatedButton.styleFrom(backgroundColor: WarehouseDesign.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.api, LanguageController.instance]),
      builder: (context, _) {
        final s = WdStrings.current;
        return DefaultTabController(
          length: 4,
          child: Container(
            color: WarehouseDesign.bg,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.loadingAndRegistersHeader,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: WarehouseDesign.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: WarehouseDesign.blue,
                        unselectedLabelColor: WarehouseDesign.textMuted,
                        indicatorColor: WarehouseDesign.blue,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        tabs: [
                          Tab(text: 'Order Handover (${widget.api.readyStockOrders.length})'),
                          const Tab(text: 'Vehicle Stock Transfer'),
                          Tab(text: s.inwardLogTab(widget.api.truckInwardLog.length)),
                          Tab(text: s.dispatchLogTab(widget.api.stockDispatchLog.length)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOrderHandoverTab(context, s),
                      _buildVehicleTransferTab(context, s),
                      _buildInwardLogView(context, s),
                      _buildDispatchLogView(context, s),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleSelectorStrip(List<DeliveryTruck> trucks, DeliveryTruck activeTruck) {
    final availableCap = (activeTruck.capacityBoxes - activeTruck.totalLoadedBoxes).clamp(0, activeTruck.capacityBoxes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: trucks.map((truck) {
              final isSelected = truck.id == activeTruck.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${truck.vehicleNumber} (${truck.vehicleModel})'),
                  selected: isSelected,
                  selectedColor: WarehouseDesign.blue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : WarehouseDesign.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => widget.api.selectTruck(truck.id));
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [WarehouseDesign.navy, WarehouseDesign.navySlate],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${activeTruck.vehicleNumber} • ${activeTruck.vehicleModel}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '${activeTruck.capacityUtilizationPercent.toStringAsFixed(0)}% Full',
                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Driver: ${activeTruck.driverName} • Loaded: ${activeTruck.totalLoadedBoxes}/${activeTruck.capacityBoxes} bxs • Free Capacity: $availableCap bxs',
                style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (activeTruck.capacityUtilizationPercent / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tab 1: Packed Order Handover to Delivery Person
  Widget _buildOrderHandoverTab(BuildContext context, WdStrings s) {
    final trucks = widget.api.deliveryTrucks;
    final activeTruck = widget.api.activeTruck;
    final readyOrders = widget.api.readyStockOrders;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVehicleSelectorStrip(trucks, activeTruck),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Packed Orders Ready for Handover',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: WarehouseDesign.textPrimary),
              ),
              WarehouseStatusPill(
                label: '${readyOrders.length} Ready',
                fg: WarehouseDesign.green,
                bg: WarehouseDesign.greenSoft,
                borderColor: WarehouseDesign.greenBorder,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (readyOrders.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: WarehouseDesign.cardDecoration(),
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 40, color: WarehouseDesign.textMuted),
                  SizedBox(height: 8),
                  Text('No packed orders awaiting driver handover.', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            )
          else
            ...readyOrders.map((ord) {
              final assignedTruck = trucks.firstWhere(
                (t) => t.vehicleNumber == ord.assignedCarNumber,
                orElse: () => activeTruck,
              );
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: WarehouseDesign.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order #${ord.orderNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ),
                        WarehouseStatusPill(
                          label: s.packedReadyLabel,
                          fg: WarehouseDesign.green,
                          bg: WarehouseDesign.greenSoft,
                          borderColor: WarehouseDesign.greenBorder,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(ord.shopName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      '${ord.items.length} Items • ${ord.packedCartonCount} Cartons • ₹${ord.totalRupees.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WarehouseDesign.textSecondary),
                    ),
                    Text(
                      'Vehicle: ${assignedTruck.vehicleNumber} • Driver: ${assignedTruck.driverName}',
                      style: const TextStyle(fontSize: 11.5, color: WarehouseDesign.blue, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: WarehouseDesign.buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: () => _showHandoverConfirmationDialog(ord, assignedTruck),
                        icon: const Icon(Icons.handshake_outlined, size: 18),
                        label: Text(s.handoverConfirmBtn, style: const TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WarehouseDesign.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Tab 2: Godown-to-Vehicle Stock Transfer
  Widget _buildVehicleTransferTab(BuildContext context, WdStrings s) {
    final prods = widget.api.products.where((p) => !p.isArchived).toList();
    final trucks = widget.api.deliveryTrucks;
    final activeTruck = widget.api.activeTruck;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVehicleSelectorStrip(trucks, activeTruck),
          const SizedBox(height: 16),
          const Text(
            'Transfer Stock from Godown to Vehicle',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: WarehouseDesign.textPrimary),
          ),
          const SizedBox(height: 10),
          ...prods.map((p) {
            final inTruckBoxes = activeTruck.getStockForProduct(p.id);
            final isBusy = _transferLoading[p.id] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: WarehouseDesign.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.nameForLanguage(LanguageController.instance.currentLanguage),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                      Text(
                        p.id,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WarehouseDesign.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Godown: ${p.godownStockBoxes} Boxes',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WarehouseDesign.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Vehicle: $inTruckBoxes Boxes',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: WarehouseDesign.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isBusy)
                    const Center(child: LinearProgressIndicator())
                  else
                    Row(
                      children: [
                        if (inTruckBoxes > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: OutlinedButton(
                              onPressed: () => _executeTransfer(p, activeTruck, -1),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: WarehouseDesign.red,
                                side: const BorderSide(color: WarehouseDesign.redBorder),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('-1 Box', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: p.godownStockBoxes >= 1 ? () => _executeTransfer(p, activeTruck, 1) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WarehouseDesign.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('+1 Box', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: p.godownStockBoxes >= 5 ? () => _executeTransfer(p, activeTruck, 5) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WarehouseDesign.blueSoft,
                            foregroundColor: WarehouseDesign.blue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('+5', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => _showCustomTransferDialog(p, activeTruck),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Custom / Unit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInwardLogView(BuildContext context, WdStrings s) {
    final inwardLog = widget.api.truckInwardLog;
    if (inwardLog.isEmpty) {
      return Center(child: Text(s.noInwardLogsYet, style: const TextStyle(color: WarehouseDesign.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: inwardLog.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        final inw = inwardLog[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: WarehouseDesign.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${inw.truckNumber} • ${inw.supplier}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  WarehouseStatusPill(
                    label: '${inw.totalCartons} Boxes',
                    fg: WarehouseDesign.green,
                    bg: WarehouseDesign.greenSoft,
                    borderColor: WarehouseDesign.greenBorder,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Driver: ${inw.driverName} • ${inw.totalPieces} pcs', style: const TextStyle(fontSize: 12, color: WarehouseDesign.textMuted)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDispatchLogView(BuildContext context, WdStrings s) {
    final dispatchLog = widget.api.stockDispatchLog;
    if (dispatchLog.isEmpty) {
      return Center(child: Text(s.noDispatchLogsYet, style: const TextStyle(color: WarehouseDesign.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: dispatchLog.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        final dsp = dispatchLog[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: WarehouseDesign.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('#${dsp.orderNumber} • ${dsp.shopName}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                  WarehouseStatusPill(
                    label: '${dsp.totalCartons} Cartons',
                    fg: WarehouseDesign.blue,
                    bg: WarehouseDesign.blueSoft,
                    borderColor: WarehouseDesign.blueBorder,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Vehicle: ${dsp.deliveryVehicle}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WarehouseDesign.blue)),
              Text(dsp.itemsSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: WarehouseDesign.textMuted)),
            ],
          ),
        );
      },
    );
  }
}
