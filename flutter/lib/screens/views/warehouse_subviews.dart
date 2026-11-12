import 'package:flutter/material.dart';
import '../../l10n/language_controller.dart';
import '../../l10n/warehouse_delivery_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import 'add_edit_inventory_item_sheet.dart';

export 'warehouse_pick_pack_view.dart';
export 'warehouse_vehicle_handover_view.dart';

/// 1. Warehouse Stock View: Live Godown inventory with full CRUD, Expiry Radar, and Analytics.
class WarehouseStockView extends StatefulWidget {
  final ApiService api;
  const WarehouseStockView({super.key, required this.api});

  @override
  State<WarehouseStockView> createState() => _WarehouseStockViewState();
}

class _WarehouseStockViewState extends State<WarehouseStockView> {
  int _subTabIndex = 0; // 0: Stock Catalog, 1: Expiry Radar, 2: Inventory Analytics
  String _stockLocation = 'godown'; // 'godown' (Central Godown) or 'truck' (Mobile Van Fleet)
  String _selectedCategory = 'All';
  String _stockStatusFilter = 'All'; // 'All', 'In Stock', 'Low Stock', 'Out of Stock'
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Juices & Cold Drinks',
    'Traditional Namkeen',
    'Potato Wafers',
    'Extruded Snacks & Fryums',
    'Biscuits & Bakery',
    'Bakery & Confectionery',
  ];

  void _showAddEditSheet([ProductItem? product]) async {
    final result = await AddEditInventoryItemSheet.show(context, widget.api, product: product);
    if (result != null && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(product != null ? 'Updated SKU ${result.name}' : 'Added ${result.name} to Godown'),
          backgroundColor: AirbnbTheme.jodhpurBlue,
        ),
      );
    }
  }

  void _confirmDeleteSku(ProductItem product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Delete SKU (कैटलॉग से हटाएं)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently remove "${product.name}" (${product.id})?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Current Godown stock: ${product.godownStockBoxes} Boxes.\nThis SKU will be archived and removed from active inventory.',
                style: TextStyle(fontSize: 11, color: Colors.red.shade900),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AirbnbTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.api.removeProduct(product.id);
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed ${product.name} from Inventory'),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete SKU'),
          ),
        ],
      ),
    );
  }

  void _showWriteOffExpiredDialog(ProductItem product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Write-off Expired Stock (निस्तारण/राइट-ऑफ)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Text(
          'Mark all ${product.godownStockBoxes} boxes of "${product.name}" as disposed due to batch expiry (${product.batchNumber})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final boxes = product.godownStockBoxes;
              product.godownStockBoxes = 0;
              widget.api.updateProduct(product);
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Written off $boxes boxes of ${product.name} due to expiry.'),
                  backgroundColor: Colors.orange.shade800,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            child: const Text('Confirm Write-off'),
          ),
        ],
      ),
    );
  }

  void _showQuickAddBoxesDialog(ProductItem product) {
    final qtyCtrl = TextEditingController(text: '10');
    final truckCtrl = TextEditingController(text: 'RJ-19-GA-1102');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_box, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add Stock to Godown (माल जोड़ें)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${product.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text('Current Godown Stock: ${product.godownStockBoxes} Boxes (${product.boxQty} pcs/box)',
                style: const TextStyle(fontSize: 11.5, color: AirbnbTheme.grey)),
            const SizedBox(height: 14),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Boxes to Add (पेटी की संख्या) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: truckCtrl,
              decoration: const InputDecoration(
                labelText: 'Truck / Reference No. (गाड़ी नंबर)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AirbnbTheme.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final addedBoxes = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (addedBoxes <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid box quantity (> 0)')),
                );
                return;
              }
              widget.api.restockProduct(product.id, addedBoxes);
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added +$addedBoxes boxes to ${product.name}! New stock: ${product.godownStockBoxes} bxs'),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: const Text('+ Add to Stock'),
          ),
        ],
      ),
    );
  }

  void _showAdjustStockSheet(ProductItem product) {
    int countedBoxes = product.godownStockBoxes;
    String selectedReason = 'Physical stock audit (भौतिक स्टॉक ऑडिट)';
    final reasons = [
      'Physical stock audit (भौतिक स्टॉक ऑडिट)',
      'Breakage / Damage (टूट-फूट/नुकसान)',
      'Supplier Inward Variance (सप्लायर इनवर्ड अंतर)',
      'Return to Vendor / Disposal (वापसी/निस्तारण)',
      'Correction of Ledger Mismatch (खाता सुधार)'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final difference = countedBoxes - product.godownStockBoxes;
            final isIncrease = difference > 0;
            final isHighVariance = difference.abs() > 10;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: AirbnbTheme.border, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Physical Stock Audit: ${product.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Book Record: ${product.godownStockBoxes} Boxes (${product.boxQty} pcs/box)', style: const TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                  const SizedBox(height: 16),

                  // Counted Quantity Stepper
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.lightGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AirbnbTheme.border),
                    ),
                    child: Column(
                      children: [
                        const Text('Counted Physical Stock (वास्तविक गिना गया स्टॉक):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: countedBoxes > 0 ? () => setSheetState(() => countedBoxes--) : null,
                              icon: const Icon(Icons.remove_circle_outline, size: 28),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('$countedBoxes Boxes', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AirbnbTheme.jodhpurBlue)),
                            ),
                            IconButton(
                              onPressed: () => setSheetState(() => countedBoxes++),
                              icon: const Icon(Icons.add_circle_outline, size: 28, color: AirbnbTheme.jodhpurBlue),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discrepancy (अंतर):', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                            Text(
                              difference == 0
                                  ? '0 (Exact Match)'
                                  : (isIncrease ? '+$difference Boxes (Surplus)' : '$difference Boxes (Shortage)'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: difference == 0
                                    ? Colors.green
                                    : (isIncrease ? Colors.orange.shade800 : Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Text('Mandatory Audit Reason (कारण दर्ज करें):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AirbnbTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedReason,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12, color: AirbnbTheme.dark),
                        items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => selectedReason = val);
                        },
                      ),
                    ),
                  ),

                  if (isHighVariance) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE65100)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Variance > 10 boxes flags an audit investigation and requires Distributor Owner confirmation.',
                              style: TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: difference == 0
                          ? () => Navigator.pop(ctx)
                          : () async {
                              if (selectedReason.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Adjustment reason is required.')),
                                );
                                return;
                              }
                              final messenger = ScaffoldMessenger.of(context);
                              widget.api.restockProduct(product.id, difference);
                              await widget.api.repository.recordStockMovement(
                                productId: product.id,
                                movementType: 'AUDIT_ADJUSTMENT',
                                cartonDelta: difference,
                                loosePieceDelta: 0,
                                reason: selectedReason.trim(),
                                newGodownCartons: product.godownStockBoxes,
                                newGodownLoosePieces: 0,
                                newCarCartons: product.carStockBoxes,
                                newCarLoosePieces: 0,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) setState(() {});
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Recorded physical count of $countedBoxes boxes (${difference >= 0 ? "+$difference" : "$difference"}). Reason: $selectedReason',
                                  ),
                                  backgroundColor: isIncrease ? AirbnbTheme.jodhpurBlue : Colors.red.shade700,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbTheme.jodhpurBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        difference == 0 ? 'Count Matches (No Adjustment)' : 'Confirm Count & Record Audit',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.api, LanguageController.instance]),
      builder: (context, _) {
        final s = WdStrings.current;
        final allProducts = widget.api.products.where((p) => !p.isArchived).toList();
        final totalValuation = allProducts.fold<double>(0.0, (sum, p) => sum + p.godownValuationRupees);
        final nearExpiryCount = allProducts.where((p) => p.isExpiringSoon || p.isExpired).length;

        return Column(
          children: [
            // 1. TOP HEADER & SUB-NAVIGATOR (Catalog, Expiry Radar, Analytics)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AirbnbTheme.border)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.godownStock,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AirbnbTheme.dark),
                            ),
                            Text(
                              '${allProducts.length} ${s.totalSkusLabel} • ₹${(totalValuation / 100000).toStringAsFixed(2)} L',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => WarehouseInwardView.showAsSheet(context, widget.api),
                        icon: const Icon(Icons.input_rounded, size: 15),
                        label: const Text('GRN', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF059669),
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          backgroundColor: const Color(0xFFECFDF5),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditSheet(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('+ Add SKU', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

              // TWO-STOCK LOCATION TOGGLE (Godown vs Truck Stock)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _stockLocation = 'godown'),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _stockLocation == 'godown' ? const Color(0xFF0F172A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _stockLocation == 'godown'
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warehouse_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Central Godown (${widget.api.totalGodownBoxes} bxs)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _stockLocation == 'godown' ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _stockLocation = 'truck'),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _stockLocation == 'truck' ? const Color(0xFF0F172A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _stockLocation == 'truck'
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.local_shipping_rounded, size: 14, color: Color(0xFF60A5FA)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Truck Fleet (${widget.api.totalCarBoxes} bxs)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _stockLocation == 'truck' ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Segmented Sub-Tabs (Active in Godown Mode)
              if (_stockLocation == 'godown')
                Row(
                  children: [
                    _buildSubTab(0, 'Catalog', Icons.inventory_2_outlined),
                    const SizedBox(width: 6),
                    _buildSubTab(1, 'Expiry Radar ($nearExpiryCount)', Icons.timelapse_outlined, isAlert: nearExpiryCount > 0),
                    const SizedBox(width: 6),
                    _buildSubTab(2, 'Analytics', Icons.analytics_outlined),
                  ],
                ),
            ],
          ),
        ),

        // 2. ACTIVE VIEW BODY
        Expanded(
          child: _stockLocation == 'truck'
              ? _buildTruckStockView()
              : switch (_subTabIndex) {
                  0 => _buildCatalogView(allProducts),
                  1 => _buildExpiryRadarView(allProducts),
                  2 => _buildAnalyticsView(allProducts, totalValuation),
                  _ => _buildCatalogView(allProducts),
                },
        ),
      ],
    );
      },
    );
  }

  Widget _buildTruckStockView() {
    final activeTruck = widget.api.activeTruck;
    final trucks = widget.api.deliveryTrucks;
    final allProducts = widget.api.products;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Truck Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...trucks.map((truck) {
                  final isSelected = truck.id == activeTruck.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${truck.vehicleNumber} (${truck.vehicleModel})'),
                      selected: isSelected,
                      selectedColor: AirbnbTheme.jodhpurBlue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AirbnbTheme.dark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            widget.api.selectTruck(truck.id);
                          });
                        }
                      },
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: AirbnbTheme.jodhpurBlue),
                    label: const Text('+ Add Truck', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                    backgroundColor: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                    side: BorderSide(color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.3)),
                    onPressed: () => showAddTruckDialog(
                      context: context,
                      api: widget.api,
                      onAdded: () => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Active Truck Profile & Capacity Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeTruck.vehicleNumber,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${activeTruck.vehicleModel} • Driver: ${activeTruck.driverName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${activeTruck.totalLoadedBoxes} / ${activeTruck.capacityBoxes} bxs',
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (activeTruck.capacityUtilizationPercent / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      activeTruck.capacityUtilizationPercent > 85 ? Colors.orange : const Color(0xFF60A5FA),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Loaded Inventory on Truck (ट्रक स्टॉक)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${allProducts.where((p) => p.carStockBoxes > 0).length} SKUs loaded',
                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Product Cards with Transfer Actions
          ...allProducts.map((p) {
            final loadedBoxes = p.carStockBoxes;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AirbnbTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          'Godown: ${p.godownStockBoxes} bxs • On Truck: $loadedBoxes bxs',
                          style: TextStyle(
                            fontSize: 11,
                            color: loadedBoxes > 0 ? AirbnbTheme.jodhpurBlue : AirbnbTheme.grey,
                            fontWeight: loadedBoxes > 0 ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: loadedBoxes > 0
                              ? () async {
                                  await widget.api.transferStockToCar(p.id, -1, targetTruckId: activeTruck.id);
                                  if (mounted) setState(() {});
                                }
                              : null,
                          icon: const Icon(Icons.remove, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: loadedBoxes > 0 ? Colors.red.shade50 : Colors.transparent,
                            foregroundColor: loadedBoxes > 0 ? Colors.red.shade700 : const Color(0xFFCBD5E1),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$loadedBoxes bxs',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: loadedBoxes > 0 ? AirbnbTheme.jodhpurBlue : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: p.godownStockBoxes >= 1
                              ? () async {
                                  await widget.api.transferStockToCar(p.id, 1, targetTruckId: activeTruck.id);
                                  if (mounted) setState(() {});
                                }
                              : null,
                          icon: const Icon(Icons.add, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: p.godownStockBoxes >= 1 ? AirbnbTheme.jodhpurBlue : Colors.transparent,
                            foregroundColor: p.godownStockBoxes >= 1 ? Colors.white : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
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

  Widget _buildSubTab(int index, String label, IconData icon, {bool isAlert = false}) {
    final isSel = _subTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _subTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? AirbnbTheme.jodhpurBlue : AirbnbTheme.lightGrey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAlert && !isSel ? Colors.amber.shade700 : (isSel ? AirbnbTheme.jodhpurBlue : AirbnbTheme.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSel ? Colors.white : (isAlert ? Colors.amber.shade800 : AirbnbTheme.dark)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? Colors.white : (isAlert ? Colors.amber.shade800 : AirbnbTheme.dark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 0: STOCK CATALOG ---
  Widget _buildCatalogView(List<ProductItem> allProducts) {
    final filtered = allProducts.where((p) {
      final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.hindiName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.batchNumber.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = switch (_stockStatusFilter) {
        'In Stock' => p.godownStockBoxes > p.reorderLevelBoxes,
        'Low Stock' => p.isLowStock,
        'Out of Stock' => p.isOutOfStock,
        _ => true,
      };

      return matchesCat && matchesQuery && matchesStatus;
    }).toList();

    return Column(
      children: [
        // Category horizontal chips
        Container(
          height: 38,
          margin: const EdgeInsets.only(top: 6),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _categories.length,
            itemBuilder: (ctx, idx) {
              final cat = _categories[idx];
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                  selectedColor: AirbnbTheme.jodhpurBlue,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.white : AirbnbTheme.dark,
                  ),
                ),
              );
            },
          ),
        ),

        // Search Bar & Status Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search SKU, name or batch...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: AirbnbTheme.lightGrey,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filter Status Popup
              PopupMenuButton<String>(
                initialValue: _stockStatusFilter,
                onSelected: (val) => setState(() => _stockStatusFilter = val),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: _stockStatusFilter == 'All' ? AirbnbTheme.lightGrey : AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _stockStatusFilter == 'All' ? AirbnbTheme.border : AirbnbTheme.jodhpurBlue),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 16, color: AirbnbTheme.dark),
                      const SizedBox(width: 4),
                      Text(_stockStatusFilter, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => ['All', 'In Stock', 'Low Stock', 'Out of Stock']
                    .map((s) => PopupMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                    .toList(),
              ),
            ],
          ),
        ),

        if (allProducts.length <= 3)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_download_outlined, size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Only ${allProducts.length} SKU(s) in DB',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                      ),
                      const Text(
                        'Import Real Bites FMCG catalog items into your database.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final added = await widget.api.seedRealBitesCatalogToDb();
                    if (mounted) setState(() {});
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(added > 0
                            ? 'Added $added Real Bites FMCG items to database!'
                            : 'All Real Bites items are already in database.'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add Items to DB', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),

        // Product Catalog List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 40, color: AirbnbTheme.grey),
                      const SizedBox(height: 8),
                      const Text('No products match your criteria', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () => _showAddEditSheet(),
                        icon: const Icon(Icons.add),
                        label: const Text('+ Add New SKU Manually'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final prod = filtered[idx];
                    final isLow = prod.isLowStock;
                    final isOut = prod.isOutOfStock;
                    final isExpiring = prod.isExpiringSoon || prod.isExpired;

                    // Category accent color
                    final categoryColor = switch (prod.category) {
                      'Traditional Namkeen' => const Color(0xFFD97706),
                      'Potato Wafers' => const Color(0xFF4F46E5),
                      'Extruded Snacks & Fryums' => const Color(0xFFE11D48),
                      'Juices & Cold Drinks' => const Color(0xFF059669),
                      'Biscuits & Bakery' || 'Bakery & Confectionery' => const Color(0xFFB45309),
                      _ => const Color(0xFF2563EB),
                    };

                    final categoryIcon = switch (prod.category) {
                      'Traditional Namkeen' => Icons.bakery_dining_rounded,
                      'Potato Wafers' => Icons.lunch_dining_rounded,
                      'Extruded Snacks & Fryums' => Icons.fastfood_rounded,
                      'Juices & Cold Drinks' => Icons.local_drink_rounded,
                      _ => Icons.cookie_rounded,
                    };

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOut ? const Color(0xFFFCA5A5) : (isLow ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0)),
                          width: isLow || isOut ? 1.4 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Category Accent Strip
                              Container(
                                width: 5,
                                color: categoryColor,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 1. Header: Image/Placeholder + Name + SKU + MRP + Edit/Delete
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: categoryColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: categoryColor.withValues(alpha: 0.25)),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: prod.imageUrl.isNotEmpty
                                                ? Image.network(
                                                    prod.imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) => Icon(categoryIcon, color: categoryColor, size: 22),
                                                  )
                                                : Icon(categoryIcon, color: categoryColor, size: 22),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        prod.nameForLanguage(LanguageController.instance.currentLanguage),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 14.5,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                    ),
                                                    // Action Icons
                                                    InkWell(
                                                      onTap: () => _showAddEditSheet(prod),
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(4),
                                                        margin: const EdgeInsets.only(left: 4),
                                                        child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () => _confirmDeleteSku(prod),
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(4),
                                                        margin: const EdgeInsets.only(left: 4),
                                                        child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${prod.category} • SKU: ${prod.id} • MRP: ₹${prod.mrpRupees.toStringAsFixed(0)}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                                ),
                                                if (prod.shelfLocation.isNotEmpty) ...[
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.shelves, size: 11, color: Color(0xFF2563EB)),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          'Rack/Shelf: ${prod.shelfLocation}',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // 2. Multi-Unit Pricing Matrix Container
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('PIECE (1 Pc)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                                                  const SizedBox(height: 1),
                                                  Text('₹${(prod.piecePricePaise / 100).toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                                ],
                                              ),
                                            ),
                                            Container(width: 1, height: 22, color: const Color(0xFFCBD5E1)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('STRIP (${prod.stripQty} pcs)', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                                                  const SizedBox(height: 1),
                                                  Text('₹${(prod.priceForUnit(OrderUnit.strip) / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                                ],
                                              ),
                                            ),
                                            Container(width: 1, height: 22, color: const Color(0xFFCBD5E1)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('BOX (${prod.boxQty} pcs)', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                                                  const SizedBox(height: 1),
                                                  Text('₹${(prod.priceForUnit(OrderUnit.box) / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // 3. Physical / Reserved / Available Stock & Valuation
                                      Builder(
                                        builder: (context) {
                                          final s = WdStrings.current;
                                          final reservedPcs = widget.api.pendingBookingPieces(prod.id);
                                          final reservedBxs = widget.api.pendingBookingBoxes(prod.id);
                                          final availPcs = widget.api.availableGodownPieces(prod.id);
                                          final availBxs = widget.api.availableGodownBoxes(prod.id);
                                          final physPcs = prod.godownStockBoxes * prod.boxQty;

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          '${prod.godownStockBoxes} ${s.boxesUnit}',
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w900,
                                                            color: isOut ? const Color(0xFFDC2626) : (isLow ? const Color(0xFFD97706) : const Color(0xFF059669)),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Flexible(
                                                          child: Text(
                                                            '($physPcs pcs)',
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isOut
                                                          ? const Color(0xFFFEE2E2)
                                                          : (isLow ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5)),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: isOut
                                                            ? const Color(0xFFFCA5A5)
                                                            : (isLow ? const Color(0xFFFCD34D) : const Color(0xFFA7F3D0)),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      isOut ? 'OUT OF STOCK' : (isLow ? 'LOW STOCK' : 'IN STOCK'),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w800,
                                                        color: isOut
                                                            ? const Color(0xFF991B1B)
                                                            : (isLow ? const Color(0xFF92400E) : const Color(0xFF065F46)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${s.reservedStockLabel}: $reservedBxs bxs ($reservedPcs pcs)',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        '${s.availableStockLabel}: $availBxs bxs ($availPcs pcs)',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        textAlign: TextAlign.end,
                                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${s.stockValuation}: ₹${prod.godownValuationRupees.toStringAsFixed(0)} • Van: ${prod.carStockBoxes} bxs',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          );
                                        },
                                      ),

                                      // Batch & Expiry Tag
                                      if (prod.expiryDate != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isExpiring ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isExpiring ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.event_outlined, size: 11, color: isExpiring ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Batch: ${prod.batchNumber} • Expiry: ${prod.expiryDate!.day}/${prod.expiryDate!.month}/${prod.expiryDate!.year} (${prod.daysUntilExpiry}d left)',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isExpiring ? const Color(0xFF92400E) : const Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 10),
                                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                      const SizedBox(height: 10),

                                      // 4. Action Buttons Bar
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () => _showQuickAddBoxesDialog(prod),
                                            icon: const Icon(Icons.add_box, size: 14),
                                            label: const Text('+ Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF059669),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () => _showAdjustStockSheet(prod),
                                            icon: const Icon(Icons.tune, size: 14),
                                            label: const Text('Adjust Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                              foregroundColor: const Color(0xFF2563EB),
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 1: EXPIRY RADAR & BATCHES ---
  Widget _buildExpiryRadarView(List<ProductItem> allProducts) {
    // Sort items chronologically by nearest expiry date
    final itemsWithExpiry = allProducts.where((p) => p.expiryDate != null).toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

    final expired = itemsWithExpiry.where((p) => p.isExpired).toList();
    final expiringSoon = itemsWithExpiry.where((p) => p.isExpiringSoon).toList();
    final safe = itemsWithExpiry.where((p) => !p.isExpired && !p.isExpiringSoon).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expiry Overview Hero Cards
          Row(
            children: [
              _buildExpiryKpiCard('Expired', '${expired.length}', Colors.red),
              const SizedBox(width: 8),
              _buildExpiryKpiCard('Expiring <60d', '${expiringSoon.length}', Colors.amber.shade800),
              const SizedBox(width: 8),
              _buildExpiryKpiCard('Fresh / Safe', '${safe.length}', Colors.green),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Batch Expiry Timeline (बैच एक्सपायरी सूची)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sorted by nearest expiry date. Take proactive clearance action before expiration.',
            style: TextStyle(fontSize: 11, color: AirbnbTheme.grey),
          ),
          const SizedBox(height: 12),

          if (itemsWithExpiry.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No batches with expiry dates tracked.'),
              ),
            )
          else
            ...itemsWithExpiry.map((p) {
              final daysLeft = p.daysUntilExpiry ?? 0;
              final isExp = p.isExpired;
              final isCritical = daysLeft >= 0 && daysLeft <= 30;
              final isWarning = daysLeft > 30 && daysLeft <= 60;

              final badgeColor = isExp
                  ? Colors.red
                  : (isCritical ? Colors.deepOrange : (isWarning ? Colors.amber.shade800 : Colors.green));

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExp || isCritical ? badgeColor.withValues(alpha: 0.5) : AirbnbTheme.border,
                    width: isExp || isCritical ? 1.5 : 0.8,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Days Left Big Box
                        Container(
                          width: 58,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                isExp ? 'EXPIRED' : '$daysLeft',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isExp ? 9 : 18,
                                  fontWeight: FontWeight.w900,
                                  color: badgeColor,
                                ),
                              ),
                              if (!isExp)
                                Text(
                                  'days left',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: badgeColor),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              Text('Batch: ${p.batchNumber} • ${p.category}', style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey)),
                              const SizedBox(height: 4),
                              Text(
                                'Expiry Date: ${p.expiryDate!.day}/${p.expiryDate!.month}/${p.expiryDate!.year}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isExp ? Colors.red : AirbnbTheme.dark,
                                ),
                              ),
                              Text(
                                'Stock at Risk: ${p.godownStockBoxes} Boxes (Valuation: ₹${p.godownValuationRupees.toStringAsFixed(0)})',
                                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Action buttons for near-expiry items
                    if (isExp || isCritical) ...[
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isExp)
                            OutlinedButton.icon(
                              onPressed: () => _showWriteOffExpiredDialog(p),
                              icon: const Icon(Icons.delete_sweep, size: 14, color: Colors.red),
                              label: const Text('Write-off Expired', style: TextStyle(fontSize: 11, color: Colors.red)),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Flagged "${p.name}" (Batch ${p.batchNumber}) for High-Velocity Clearance Offer!'),
                                    backgroundColor: Colors.orange.shade800,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.local_offer_outlined, size: 14),
                              label: const Text('Flag for Clearance Sale', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: AirbnbTheme.grey),
                            tooltip: 'Edit Batch Details',
                            onPressed: () => _showAddEditSheet(p),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildExpiryKpiCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: INVENTORY ANALYTICS ---
  Widget _buildAnalyticsView(List<ProductItem> allProducts, double totalValuation) {
    final totalBoxes = allProducts.fold<int>(0, (sum, p) => sum + p.godownStockBoxes);
    final lowStockItems = allProducts.where((p) => p.isLowStock || p.isOutOfStock).toList();

    // Group by category for valuation breakdown
    final Map<String, int> categoryBoxes = {};
    final Map<String, double> categoryValuations = {};

    for (final p in allProducts) {
      categoryBoxes[p.category] = (categoryBoxes[p.category] ?? 0) + p.godownStockBoxes;
      categoryValuations[p.category] = (categoryValuations[p.category] ?? 0.0) + p.godownValuationRupees;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Asset Valuation Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF93C5FD), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'TOTAL GODOWN STOCK VALUATION',
                      style: TextStyle(color: Color(0xFF93C5FD), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${(totalValuation).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$totalBoxes Total Boxes in Central Godown',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      '${allProducts.length} SKUs',
                      style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category Valuation Breakdown
          const Text(
            'Stock Valuation by Category (श्रेणी अनुसार मूल्य)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
          ),
          const SizedBox(height: 10),

          ...categoryValuations.entries.map((entry) {
            final cat = entry.key;
            final val = entry.value;
            final boxes = categoryBoxes[cat] ?? 0;
            final fraction = totalValuation > 0 ? (val / totalValuation) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AirbnbTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '₹${val.toStringAsFixed(0)} (${(fraction * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AirbnbTheme.jodhpurBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('$boxes Boxes', style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey)),
                      const Spacer(),
                      Text('Avg ₹${boxes > 0 ? (val / boxes).toStringAsFixed(0) : "0"}/box', style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: AirbnbTheme.lightGrey,
                      valueColor: const AlwaysStoppedAnimation(AirbnbTheme.jodhpurBlue),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Reorder Alerts & Replenishment
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reorder Threshold Alerts (पुनः ऑर्डर सूचनाएं)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: lowStockItems.isNotEmpty ? Colors.orange.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${lowStockItems.length} Alerts',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: lowStockItems.isNotEmpty ? Colors.orange.shade900 : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (lowStockItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 8),
                  Text('All SKUs have healthy safety stock in Central Godown!', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.green)),
                ],
              ),
            )
          else
            ...lowStockItems.map((p) {
              final needed = (p.reorderLevelBoxes * 2) - p.godownStockBoxes;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          Text(
                            'Stock: ${p.godownStockBoxes} / ${p.reorderLevelBoxes} reorder limit • Suggested Order: +$needed Boxes',
                            style: TextStyle(fontSize: 10.5, color: Colors.orange.shade900),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showAdjustStockSheet(p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbTheme.jodhpurBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Restock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Reusable modal to manually add a new delivery truck with confirmation
void showAddTruckDialog({
  required BuildContext context,
  required ApiService api,
  required VoidCallback onAdded,
}) {
  final vehicleCtrl = TextEditingController();
  final modelCtrl = TextEditingController(text: 'Tata Ace Gold');
  final driverCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final capacityCtrl = TextEditingController(text: '200');

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.local_shipping, color: AirbnbTheme.jodhpurBlue),
          SizedBox(width: 8),
          Text('Add Delivery Truck (नया वाहन)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter truck registration and driver details to add to mobile delivery fleet.',
              style: TextStyle(fontSize: 11.5, color: AirbnbTheme.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: vehicleCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Vehicle Number * (e.g. RJ-19-GD-5510)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: modelCtrl,
              decoration: const InputDecoration(
                labelText: 'Vehicle Model (e.g. Tata Ace, Bolero Maxi, Eicher)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: driverCtrl,
              decoration: const InputDecoration(
                labelText: 'Driver Name * (e.g. Kailash Bishnoi)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Driver Contact (e.g. +91 98290 88776)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: capacityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Box Capacity (e.g. 200 boxes)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final vNum = vehicleCtrl.text.trim().toUpperCase();
            final dName = driverCtrl.text.trim();
            if (vNum.isEmpty || dName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vehicle Number and Driver Name are required!')),
              );
              return;
            }
            Navigator.pop(ctx);
            // Reconfirmation Dialog
            showDialog(
              context: context,
              builder: (cCtx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: const [
                    Icon(Icons.check_circle_outline, color: AirbnbTheme.success),
                    SizedBox(width: 8),
                    Text('Reconfirm Truck Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Please verify you want to add this truck to the active fleet:', style: TextStyle(fontSize: 12.5)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Truck: $vNum (${modelCtrl.text.trim()})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                          const SizedBox(height: 4),
                          Text('Driver: $dName ${phoneCtrl.text.trim().isNotEmpty ? "• ${phoneCtrl.text.trim()}" : ""}', style: const TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                          const SizedBox(height: 3),
                          Text('Max Capacity: ${capacityCtrl.text.trim()} Boxes', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(cCtx), child: const Text('Back / Edit')),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(cCtx);
                      api.addDeliveryTruck(
                        vehicleNumber: vNum,
                        vehicleModel: modelCtrl.text.trim(),
                        driverName: dName,
                        driverPhone: phoneCtrl.text.trim(),
                        capacityBoxes: int.tryParse(capacityCtrl.text.trim()) ?? 200,
                      );
                      onAdded();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ Truck $vNum successfully added to fleet!'),
                          backgroundColor: AirbnbTheme.success,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AirbnbTheme.success, foregroundColor: Colors.white),
                    child: const Text('✓ Yes, Confirm & Add'),
                  ),
                ],
              ),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: AirbnbTheme.jodhpurBlue, foregroundColor: Colors.white),
          child: const Text('Next: Confirm'),
        ),
      ],
    ),
  );
}

/// 2. Warehouse Inward View: Factory Shipment Intake Form with Manual SKU Entry & Typo Reconfirmation.
class WarehouseInwardView extends StatefulWidget {
  final ApiService api;
  const WarehouseInwardView({super.key, required this.api});

  static Future<void> showAsSheet(BuildContext context, ApiService api) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(child: WarehouseInwardView(api: api)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<WarehouseInwardView> createState() => _WarehouseInwardViewState();
}

class _WarehouseInwardViewState extends State<WarehouseInwardView> {
  final _truckCtrl = TextEditingController(text: 'RJ-19-GA-1102');
  final _driverCtrl = TextEditingController(text: 'Kailash Singh');
  final _supplierCtrl = TextEditingController(text: 'Bikaji Foods Central Plant');

  ProductItem? _selectedProduct;
  String _selectedInwardCategory = 'All';
  final _boxQtyCtrl = TextEditingController(text: '10');
  final _stripQtyCtrl = TextEditingController(text: '0');
  final _pieceQtyCtrl = TextEditingController(text: '0');

  final List<TruckInwardItem> _inwardCart = [];
  bool _isSaving = false;

  final List<String> _inwardCategories = [
    'All',
    'Juices & Cold Drinks',
    'Traditional Namkeen',
    'Potato Wafers',
    'Extruded Snacks & Fryums',
    'Biscuits & Bakery',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.api.products.isNotEmpty) {
      _selectedProduct = widget.api.products.first;
    }
  }

  @override
  void dispose() {
    _truckCtrl.dispose();
    _driverCtrl.dispose();
    _supplierCtrl.dispose();
    _boxQtyCtrl.dispose();
    _stripQtyCtrl.dispose();
    _pieceQtyCtrl.dispose();
    super.dispose();
  }

  void _addItemToCart() {
    final s = WdStrings.current;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.selectProductLabel)),
      );
      return;
    }

    final boxes = int.tryParse(_boxQtyCtrl.text.trim()) ?? 0;
    final strips = int.tryParse(_stripQtyCtrl.text.trim()) ?? 0;
    final pieces = int.tryParse(_pieceQtyCtrl.text.trim()) ?? 0;

    if (boxes <= 0 && strips <= 0 && pieces <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least 1 box, strip or piece')),
      );
      return;
    }

    final existingIdx = _inwardCart.indexWhere((it) => it.productId == _selectedProduct!.id);
    if (existingIdx != -1) {
      final existing = _inwardCart[existingIdx];
      _inwardCart[existingIdx] = TruckInwardItem(
        productId: existing.productId,
        productName: existing.productName,
        boxes: existing.boxes + boxes,
        strips: existing.strips + strips,
        pieces: existing.pieces + pieces,
      );
    } else {
      _inwardCart.add(TruckInwardItem(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        boxes: boxes,
        strips: strips,
        pieces: pieces,
      ));
    }

    _boxQtyCtrl.text = '1';
    _stripQtyCtrl.text = '0';
    _pieceQtyCtrl.text = '0';

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Added to intake cart'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _commitInwardToGodownDb() async {
    final truckNum = _truckCtrl.text.trim();
    if (truckNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Truck / Vehicle Number')),
      );
      return;
    }

    if (_inwardCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Intake cart is empty. Add at least 1 SKU.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.api.receiveTruckInward(
        truckNumber: truckNum,
        driverName: _driverCtrl.text.trim(),
        supplier: _supplierCtrl.text.trim(),
        items: List.from(_inwardCart),
      );

      final totalCartons = _inwardCart.fold<int>(0, (sum, i) => sum + i.boxes);
      _inwardCart.clear();

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 3),
            content: Text(
              '✅ Truck $truckNum received ($totalCartons cartons) saved to Godown DB!',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving stock: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = WdStrings.current;
    final currentLang = LanguageController.instance.currentLanguage;
    final allProducts = widget.api.products;
    final filteredProducts = _selectedInwardCategory == 'All'
        ? allProducts
        : allProducts.where((p) => p.category == _selectedInwardCategory).toList();

    if (_selectedProduct == null || !filteredProducts.contains(_selectedProduct)) {
      if (filteredProducts.isNotEmpty) {
        _selectedProduct = filteredProducts.first;
      }
    }

    final totalCartBoxes = _inwardCart.fold<int>(0, (sum, i) => sum + i.boxes);
    final totalCartPieces = _inwardCart.fold<int>(0, (sum, i) => sum + i.pieces);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TRUCK INTAKE HEADER CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_shipping, color: Color(0xFF34D399), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.inwardHeaderTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Real-Time DB', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _truckCtrl,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 1),
                  decoration: InputDecoration(
                    labelText: s.truckNumberLabel,
                    labelStyle: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    prefixIcon: const Icon(Icons.pin, color: Colors.white70, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _driverCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          labelText: s.driverNameLabel,
                          labelStyle: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 11),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _supplierCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          labelText: s.supplierLabel,
                          labelStyle: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 11),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. ADD ITEM TO TRUCK CART SECTION
          Container(
            padding: const EdgeInsets.all(16),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_shopping_cart, color: Color(0xFF2563EB), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.selectProductLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AirbnbTheme.dark),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Inward Category Filter Chips (Juices, Namkeen, Biscuits, Wafers)
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _inwardCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (ctx, idx) {
                      final cat = _inwardCategories[idx];
                      final isSel = _selectedInwardCategory == cat;
                      return ChoiceChip(
                        label: Text(
                          s.categoryName(cat),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                        selected: isSel,
                        selectedColor: const Color(0xFF0F172A),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (_) {
                          setState(() {
                            _selectedInwardCategory = cat;
                          });
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // Product Dropdown
                DropdownButtonFormField<ProductItem>(
                  initialValue: _selectedProduct,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: s.selectProductLabel,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: filteredProducts.map((p) {
                    final localizedName = p.nameForLanguage(currentLang);
                    return DropdownMenuItem<ProductItem>(
                      value: p,
                      child: Text(
                        '$localizedName (${p.godownStockBoxes} ${s.boxesUnit})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (p) => setState(() => _selectedProduct = p),
                ),

                const SizedBox(height: 14),

                // Multi-unit inputs: Boxes, Strips, Pieces
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.boxUnitLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _boxQtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.stripUnitLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _stripQtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.pieceUnitLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _pieceQtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Quick Quantity Presets (+1, +5, +10, +25)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [5, 10, 25, 50].map((step) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        onTap: () {
                          final cur = int.tryParse(_boxQtyCtrl.text.trim()) ?? 0;
                          setState(() => _boxQtyCtrl.text = '${cur + step}');
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text('+$step', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addItemToCart,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(s.addToCartBtn, style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3. TRUCK CART LIST
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Truck Intake Cart (${_inwardCart.length} SKUs)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
              ),
              if (_inwardCart.isNotEmpty)
                Text(
                  'Total: $totalCartBoxes ${s.boxesUnit} $totalCartPieces Pcs',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_inwardCart.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text('Intake cart is empty', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Add cartons from the form above to record delivery into godown stock', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _inwardCart.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final it = _inwardCart[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2, color: Color(0xFF2563EB), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.productName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${it.boxes} ${s.boxesUnit} • ${it.strips} Strips • ${it.pieces} Pcs',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          setState(() {
                            _inwardCart.removeAt(idx);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // 4. BIG COMMIT BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _commitInwardToGodownDb,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle, size: 20),
              label: Text(
                _isSaving ? 'Saving to Godown DB...' : s.saveToGodownBtn,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

