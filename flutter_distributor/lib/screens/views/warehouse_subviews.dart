import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import 'add_edit_inventory_item_sheet.dart';
import 'receive_stock_grn_view.dart';

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
    'Carbonated Drinks (CSD)',
    'Energy & Hydration',
    'Potato Chips (Lay\'s)',
    'Extruded Snacks (Kurkure & Doritos)',
    'Juices & Nutrition (Tropicana & Quaker)',
    'Biscuits & Confectionery',
    'Namkeen & Traditional Snacks',
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
                          : () {
                              widget.api.restockProduct(product.id, difference);
                              Navigator.pop(ctx);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
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
    final allProducts = widget.api.products;
    final totalValuation = allProducts.fold<double>(0.0, (sum, p) => sum + p.godownValuationRupees);
    final nearExpiryCount = allProducts.where((p) => p.isExpiringSoon || p.isExpired).length;

    return Column(
      children: [
        // 1. TOP HEADER & SUB-NAVIGATOR (Catalog, Expiry Radar, Analytics)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AirbnbTheme.border)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Godown Inventory (गोदाम स्टॉक)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                      ),
                      Text(
                        '${allProducts.length} SKUs • Total Value: ₹${(totalValuation / 100000).toStringAsFixed(2)} Lakhs',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditSheet(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ Add SKU', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOut ? Colors.red.shade300 : (isLow ? Colors.orange.shade300 : AirbnbTheme.border),
                          width: isLow || isOut ? 1.2 : 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Badge Container
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? Colors.red.shade50
                                      : (isLow
                                          ? Colors.orange.shade50
                                          : AirbnbTheme.jodhpurBlue.withValues(alpha: 0.08)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.inventory_2,
                                  color: isOut
                                      ? Colors.red.shade700
                                      : (isLow ? Colors.orange.shade800 : AirbnbTheme.jodhpurBlue),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Name & Category Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            prod.name,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                          ),
                                        ),
                                        // Edit & Delete CRUD Buttons
                                        InkWell(
                                          onTap: () => _showAddEditSheet(prod),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.edit_outlined, size: 16, color: AirbnbTheme.jodhpurBlue),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _confirmDeleteSku(prod),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${prod.hindiName} • ${prod.category}',
                                      style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                                    ),
                                    const SizedBox(height: 6),

                                    // Chips Row (Batch, Expiry, Units)
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        // Batch
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AirbnbTheme.lightGrey,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Batch: ${prod.batchNumber}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                                          ),
                                        ),

                                        // Expiry Chip
                                        if (prod.expiryDate != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isExpiring ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isExpiring ? Colors.amber.shade600 : AirbnbTheme.border,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.timelapse, size: 10, color: isExpiring ? Colors.amber.shade900 : AirbnbTheme.grey),
                                                const SizedBox(width: 3),
                                                Text(
                                                  prod.isExpired
                                                      ? 'Expired!'
                                                      : (prod.isExpiringSoon
                                                          ? 'Exp: ${prod.daysUntilExpiry}d left'
                                                          : 'Exp: ${prod.expiryDate!.day}/${prod.expiryDate!.month}/${prod.expiryDate!.year}'),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isExpiring ? Colors.amber.shade900 : AirbnbTheme.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Status Chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isOut
                                                ? Colors.red.shade100
                                                : (isLow ? Colors.orange.shade100 : Colors.green.shade50),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isOut ? 'Out of Stock' : (isLow ? 'Low Stock' : 'In Stock'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isOut
                                                  ? Colors.red.shade800
                                                  : (isLow ? Colors.orange.shade900 : Colors.green.shade800),
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

                          const Divider(height: 16),

                          // Bottom Row: Stock Quantity, Valuation & Adjust Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${prod.godownStockBoxes} Boxes (${prod.boxQty} pcs/box)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: isOut ? Colors.red : (isLow ? Colors.orange.shade800 : AirbnbTheme.dark),
                                      ),
                                    ),
                                    Text(
                                      'Wholesale: ₹${(prod.piecePricePaise / 100).toStringAsFixed(1)}/pc • ₹${(prod.priceForUnit(OrderUnit.strip) / 100).toStringAsFixed(0)}/strip • ₹${(prod.priceForUnit(OrderUnit.box) / 100).toStringAsFixed(0)}/box',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue),
                                    ),
                                    Text(
                                      'Valuation: ₹${prod.godownValuationRupees.toStringAsFixed(0)} • MRP ₹${prod.mrpRupees.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                onPressed: () => _showAdjustStockSheet(prod),
                                icon: const Icon(Icons.tune, size: 14),
                                label: const Text('Adjust Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                                  foregroundColor: AirbnbTheme.jodhpurBlue,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  @override
  State<WarehouseInwardView> createState() => _WarehouseInwardViewState();
}

class _WarehouseInwardViewState extends State<WarehouseInwardView> {
  final _supplierCtrl = TextEditingController(text: 'PepsiCo FMCG Plant Panipat');
  final _challanCtrl = TextEditingController(text: 'CH-2026-8819');
  final _vehicleCtrl = TextEditingController(text: 'RJ-19-GA-1102');
  final _boxesCtrl = TextEditingController(text: '50');
  final _batchCtrl = TextEditingController(text: 'B-2610-A');
  
  // Manual SKU Input vs Catalog Dropdown Toggle
  bool _manualSkuMode = true;
  final _skuInputCtrl = TextEditingController(text: 'KURK-01');
  ProductItem? _selectedProduct;

  @override
  void initState() {
    super.initState();
    if (widget.api.products.isNotEmpty) {
      _selectedProduct = widget.api.products.first;
    }
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _challanCtrl.dispose();
    _vehicleCtrl.dispose();
    _boxesCtrl.dispose();
    _batchCtrl.dispose();
    _skuInputCtrl.dispose();
    super.dispose();
  }

  ProductItem? _findExactProduct(String query) {
    final clean = query.trim().toUpperCase();
    if (clean.isEmpty) return null;
    for (final p in widget.api.products) {
      if (p.id.toUpperCase() == clean || p.name.toUpperCase() == clean) {
        return p;
      }
    }
    return null;
  }

  List<ProductItem> _findClosestMatches(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];
    return widget.api.products.where((p) {
      return p.id.toLowerCase().contains(clean) ||
          p.name.toLowerCase().contains(clean) ||
          clean.contains(p.id.toLowerCase()) ||
          clean.contains(p.name.toLowerCase());
    }).take(3).toList();
  }

  void _onPostInwardTapped() {
    final boxes = int.tryParse(_boxesCtrl.text) ?? 0;
    if (boxes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid box quantity greater than 0')),
      );
      return;
    }

    if (_manualSkuMode) {
      final typedSku = _skuInputCtrl.text.trim();
      if (typedSku.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a Product SKU or Code')),
        );
        return;
      }

      final matched = _findExactProduct(typedSku);
      if (matched != null) {
        // Matched catalog product -> Show Reconfirmation Dialog
        _showVerifiedInwardConfirmationDialog(matched, boxes);
      } else {
        // Unrecognized SKU -> Potential Typo Warning & Reconfirmation Dialog
        final suggestions = _findClosestMatches(typedSku);
        _showUnrecognizedSkuWarningDialog(typedSku, boxes, suggestions);
      }
    } else {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a product from catalog')),
        );
        return;
      }
      _showVerifiedInwardConfirmationDialog(_selectedProduct!, boxes);
    }
  }

  void _showVerifiedInwardConfirmationDialog(ProductItem product, int boxes) {
    final currentStock = product.godownStockBoxes;
    final resultingStock = currentStock + boxes;
    final supplier = _supplierCtrl.text.trim().isEmpty ? 'Depot Supplier' : _supplierCtrl.text.trim();
    final vehicle = _vehicleCtrl.text.trim().isEmpty ? 'RJ-19-GA-1102' : _vehicleCtrl.text.trim();
    final challan = _challanCtrl.text.trim().isEmpty ? 'CH-${DateTime.now().millisecondsSinceEpoch}' : _challanCtrl.text.trim();
    final batch = _batchCtrl.text.trim().isEmpty ? 'B-DEFAULT' : _batchCtrl.text.trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.verified, color: AirbnbTheme.success, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text('Reconfirm Inward SKU & Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please double-check the SKU and stock count before posting to Godown shelves:',
                style: TextStyle(fontSize: 12, color: AirbnbTheme.dark),
              ),
              const SizedBox(height: 12),

              // Product Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF166534), borderRadius: BorderRadius.circular(4)),
                          child: Text(product.id, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF14532D)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(product.category, style: const TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Godown: $currentStock bxs', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        Text('Adding: +$boxes bxs', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AirbnbTheme.success)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stock After Inward: $resultingStock Boxes',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Logistics details
              Text('Supplier: $supplier', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
              Text('Challan #: $challan • Batch: $batch', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
              Text('Incoming Vehicle: $vehicle', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back / Edit Details'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeInwardCommit(product, boxes, supplier, challan, batch, vehicle);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('✓ Yes, Confirm & Post Stock'),
          ),
        ],
      ),
    );
  }

  void _showUnrecognizedSkuWarningDialog(String typedSku, int boxes, List<ProductItem> suggestions) {
    final newNameCtrl = TextEditingController(text: typedSku);
    String newCategory = 'Extruded Snacks (Kurkure & Doritos)';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Unrecognized SKU / Potential Typo', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'You typed SKU: ',
                    style: const TextStyle(fontSize: 12, color: AirbnbTheme.dark),
                    children: [
                      TextSpan(
                        text: '"$typedSku"',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange),
                      ),
                      const TextSpan(text: '. This code does not match any product in your current godown catalog.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Did you mean suggestions
                if (suggestions.isNotEmpty) ...[
                  const Text('Did you mean one of these existing catalog items?', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                  const SizedBox(height: 6),
                  ...suggestions.map((p) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${p.name} (${p.id})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  Text('Current Stock: ${p.godownStockBoxes} bxs', style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showVerifiedInwardConfirmationDialog(p, boxes);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AirbnbTheme.jodhpurBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Use This', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 16),
                ],

                // Or confirm adding as new SKU
                const Text('Or register this as a brand-new SKU:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                const SizedBox(height: 6),
                TextField(
                  controller: newNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: newCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Extruded Snacks (Kurkure & Doritos)', child: Text('Extruded Snacks (Kurkure)')),
                    DropdownMenuItem(value: 'Potato Chips (Lay\'s)', child: Text('Potato Chips (Lay\'s)')),
                    DropdownMenuItem(value: 'Carbonated Drinks (CSD)', child: Text('Carbonated Drinks (Pepsi)')),
                    DropdownMenuItem(value: 'Energy & Hydration', child: Text('Energy & Hydration (Sting)')),
                    DropdownMenuItem(value: 'Juices & Nutrition (Tropicana & Quaker)', child: Text('Juices & Nutrition')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => newCategory = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel / Re-type SKU'),
            ),
            ElevatedButton(
              onPressed: () async {
                final prodName = newNameCtrl.text.trim();
                if (prodName.isEmpty) return;
                Navigator.pop(ctx);

                // Create new SKU in catalog
                final newProd = ProductItem(
                  id: typedSku.toUpperCase(),
                  name: prodName,
                  hindiName: prodName,
                  category: newCategory,
                  piecePricePaise: 1800,
                  stripQty: 12,
                  boxQty: 24,
                  mrpPaise: 2000,
                  godownStockBoxes: 0,
                  carStockBoxes: 0,
                );
                widget.api.addProduct(newProd);

                final supplier = _supplierCtrl.text.trim().isEmpty ? 'Depot Supplier' : _supplierCtrl.text.trim();
                final vehicle = _vehicleCtrl.text.trim().isEmpty ? 'RJ-19-GA-1102' : _vehicleCtrl.text.trim();
                final challan = _challanCtrl.text.trim().isEmpty ? 'CH-${DateTime.now().millisecondsSinceEpoch}' : _challanCtrl.text.trim();
                final batch = _batchCtrl.text.trim().isEmpty ? 'B-DEFAULT' : _batchCtrl.text.trim();

                await _executeInwardCommit(newProd, boxes, supplier, challan, batch, vehicle);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbTheme.coral,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add as New SKU & Inward'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeInwardCommit(
    ProductItem product,
    int boxes,
    String supplier,
    String challan,
    String batch,
    String vehicle,
  ) async {
    final key = 'grn_quick_${product.id}_${DateTime.now().millisecondsSinceEpoch}';
    await widget.api.receiveStockGrnDurable(
      productId: product.id,
      supplierName: supplier,
      invoiceNumber: challan,
      batchNumber: batch,
      cartonsReceived: boxes,
      loosePiecesReceived: 0,
      damagedCartons: 0,
      damagedLoosePieces: 0,
      notes: 'Vehicle: $vehicle',
      idempotencyKey: key,
    );

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Inward Verified & Posted: +$boxes boxes of ${product.name} (${product.id}) added to Godown!'),
          backgroundColor: AirbnbTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchedProduct = _manualSkuMode ? _findExactProduct(_skuInputCtrl.text) : _selectedProduct;
    final trucks = widget.api.deliveryTrucks;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detailed GRN Banner Button
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => ReceiveStockGrnView(api: widget.api),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.receipt_long, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Open Full GRN Entry Sheet (आवक रसीद)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Record damaged goods, batch numbers & challans', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AirbnbTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.input_rounded, color: AirbnbTheme.jodhpurBlue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Record Inward Shipment (आवक स्टॉक)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Manually enter received SKU and truck number. Stock is verified with confirmation before saving.', style: TextStyle(fontSize: 11.5, color: AirbnbTheme.grey)),
                const Divider(height: 20),

                // Supplier
                const Text('Supplier / Manufacturing Depot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey)),
                const SizedBox(height: 4),
                TextField(
                  controller: _supplierCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AirbnbTheme.border)),
                  ),
                ),
                const SizedBox(height: 12),

                // Invoice / Challan & Vehicle
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Challan / Invoice #', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _challanCtrl,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AirbnbTheme.border)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Truck / Vehicle #', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _vehicleCtrl,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AirbnbTheme.border)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Quick Fleet Trucks selector chips
                Row(
                  children: [
                    const Text('Quick Truck: ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AirbnbTheme.grey)),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...trucks.map((t) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: InkWell(
                                    onTap: () => setState(() => _vehicleCtrl.text = t.vehicleNumber),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Text(t.vehicleNumber, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                    ),
                                  ),
                                )),
                            InkWell(
                              onTap: () => showAddTruckDialog(
                                context: context,
                                api: widget.api,
                                onAdded: () => setState(() {}),
                              ),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.3)),
                                ),
                                child: const Text('+ Add Truck', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // SKU MODE TOGGLE (Manual Entry vs Select from Catalog)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _manualSkuMode = true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              color: _manualSkuMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _manualSkuMode
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note, size: 14, color: _manualSkuMode ? AirbnbTheme.jodhpurBlue : AirbnbTheme.grey),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Manual SKU Entry',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _manualSkuMode ? FontWeight.w800 : FontWeight.w600,
                                      color: _manualSkuMode ? AirbnbTheme.jodhpurBlue : const Color(0xFF64748B),
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
                          onTap: () => setState(() => _manualSkuMode = false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              color: !_manualSkuMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: !_manualSkuMode
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.list_alt, size: 14, color: !_manualSkuMode ? AirbnbTheme.jodhpurBlue : AirbnbTheme.grey),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Catalog Select',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: !_manualSkuMode ? FontWeight.w800 : FontWeight.w600,
                                      color: !_manualSkuMode ? AirbnbTheme.jodhpurBlue : const Color(0xFF64748B),
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
                const SizedBox(height: 10),

                // MANUAL SKU INPUT OR DROPDOWN
                if (_manualSkuMode) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Enter Product SKU / Item Code *',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (matchedProduct != null)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              '✓ ${matchedProduct.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AirbnbTheme.success),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _skuInputCtrl,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'e.g. KURK-01, KURK-02, PEPSI-500',
                      prefixIcon: const Icon(Icons.qr_code, size: 18, color: AirbnbTheme.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AirbnbTheme.border)),
                    ),
                  ),
                  if (matchedProduct == null && _skuInputCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text('⚠️ New SKU detected: will prompt confirmation before registering into catalog.', style: TextStyle(fontSize: 10.5, color: Colors.orange, fontWeight: FontWeight.w600)),
                  ],
                ] else ...[
                  const Text('Select Product SKU from Catalog', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AirbnbTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ProductItem>(
                        value: widget.api.products.contains(_selectedProduct)
                            ? _selectedProduct
                            : (widget.api.products.isNotEmpty ? widget.api.products.first : null),
                        isExpanded: true,
                        items: widget.api.products.map((p) {
                          return DropdownMenuItem<ProductItem>(
                            value: p,
                            child: Text('${p.name} (${p.id}) • Cur: ${p.godownStockBoxes} bxs'),
                          );
                        }).toList(),
                        onChanged: (p) => setState(() => _selectedProduct = p),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Box quantity & batch number
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inward Quantity (Petis/Boxes)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _boxesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AirbnbTheme.border)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Batch Number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _batchCtrl,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AirbnbTheme.border)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _onPostInwardTapped,
                    icon: const Icon(Icons.verified, size: 18),
                    label: const Text('Verify & Post Inward to Godown', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.jodhpurBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
}

/// 3. Warehouse Sales Orders Pick List View:
/// Live queue of incoming orders placed by Sales Persons (stage: booking).
/// Allows physical item checklist picking, truck assignment, and one-click truck loading.
class WarehousePickingView extends StatefulWidget {
  final ApiService api;
  const WarehousePickingView({super.key, required this.api});

  @override
  State<WarehousePickingView> createState() => _WarehousePickingViewState();
}

class _WarehousePickingViewState extends State<WarehousePickingView> {
  // Track picked item IDs per order: orderId -> Set of item product IDs
  final Map<String, Set<String>> _pickedItems = {};

  @override
  Widget build(BuildContext context) {
    final bookingOrders = widget.api.bookingOrders;
    final readyOrders = widget.api.readyStockOrders;
    final trucks = widget.api.deliveryTrucks;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                          const Text(
                            'Sales Orders Pick List (बिक्री ऑर्डर सूची)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${bookingOrders.length} New Orders received from Sales reps',
                            style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDBA74)),
                      ),
                      child: Text(
                        '${bookingOrders.length} To Pick',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TabBar(
                  labelColor: AirbnbTheme.jodhpurBlue,
                  unselectedLabelColor: AirbnbTheme.grey,
                  indicatorColor: AirbnbTheme.jodhpurBlue,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  tabs: [
                    Tab(text: 'Incoming to Pick (${bookingOrders.length})'),
                    Tab(text: 'Ready & Staged (${readyOrders.length})'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildIncomingOrdersList(bookingOrders, trucks),
                _buildReadyOrdersList(readyOrders),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingOrdersList(List<DistributorOrder> orders, List<DeliveryTruck> trucks) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.inventory, size: 48, color: AirbnbTheme.grey),
            SizedBox(height: 12),
            Text('No Pending Orders in Picking Queue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('All placed orders have been picked and packed for delivery.', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final ord = orders[idx];
        final pickedSet = _pickedItems[ord.id] ?? {};
        final allItemsPicked = ord.items.isNotEmpty && ord.items.every((it) => pickedSet.contains(it.product.id));

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AirbnbTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, size: 16, color: AirbnbTheme.jodhpurBlue),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order #${ord.orderNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: allItemsPicked ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: allItemsPicked ? const Color(0xFF86EFAC) : const Color(0xFFFED7AA)),
                    ),
                    child: Text(
                      allItemsPicked ? 'ALL PICKED' : 'PICKING QUEUE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: allItemsPicked ? AirbnbTheme.success : const Color(0xFFEA580C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Retailer: ${ord.shopName} • Assigned Car: ${ord.assignedCarNumber}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AirbnbTheme.dark),
              ),
              if (ord.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(ord.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                ),
              const SizedBox(height: 8),

              // Target Truck Selector
              Row(
                children: [
                  const Text('Assign Truck: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AirbnbTheme.lightGrey,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AirbnbTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: trucks.any((t) => t.vehicleNumber == ord.assignedCarNumber)
                              ? ord.assignedCarNumber
                              : trucks.first.vehicleNumber,
                          isDense: true,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                          items: trucks
                              .map((t) => DropdownMenuItem(
                                    value: t.vehicleNumber,
                                    child: Text('${t.vehicleNumber} (${t.vehicleModel})', overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (newCar) {
                            if (newCar != null) {
                              setState(() {
                                ord.assignedCarNumber = newCar;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 18),
              const Text('Items to Pick from Godown Shelves:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
              const SizedBox(height: 6),

              // Item rows with Checkboxes
              ...ord.items.map((it) {
                final isChecked = pickedSet.contains(it.product.id);
                final prod = widget.api.products.firstWhere((p) => p.id == it.product.id, orElse: () => it.product);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isChecked) {
                        pickedSet.remove(it.product.id);
                      } else {
                        pickedSet.add(it.product.id);
                      }
                      _pickedItems[ord.id] = pickedSet;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 18,
                          color: isChecked ? AirbnbTheme.success : AirbnbTheme.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${it.quantity} x ${it.unit.label} ${it.product.name}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                  color: isChecked ? AirbnbTheme.grey : AirbnbTheme.dark,
                                ),
                              ),
                              Text(
                                'Godown Available: ${prod.godownStockBoxes} bxs',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: prod.godownStockBoxes > 0 ? AirbnbTheme.success : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${it.totalPieces} pcs',
                          style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const Divider(height: 18),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Order Value: ',
                              style: TextStyle(fontSize: 11.5, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '₹${ord.totalRupees.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AirbnbTheme.dark),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AirbnbTheme.border),
                          ),
                          child: Text(
                            'Mode: ${ord.paymentMode}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                final allIds = ord.items.map((it) => it.product.id).toSet();
                                _pickedItems[ord.id] = allIds;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AirbnbTheme.jodhpurBlue,
                              side: BorderSide(color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Pick All', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              widget.api.advanceOrderStage(ord.id);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Order #${ord.orderNumber} packed and staged for car loading!'),
                                  backgroundColor: AirbnbTheme.success,
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 14),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Mark Packed & Ready', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AirbnbTheme.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        );
      },
    );
  }

  Widget _buildReadyOrdersList(List<DistributorOrder> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.checklist_rtl, size: 48, color: AirbnbTheme.grey),
            SizedBox(height: 12),
            Text('No Orders Staged for Delivery Yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Orders picked from the queue appear here ready for truck loading.', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final ord = orders[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AirbnbTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${ord.orderNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6)),
                    child: const Text('READY FOR LOADING', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AirbnbTheme.success)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${ord.shopName} • Assigned Truck: ${ord.assignedCarNumber}', style: const TextStyle(fontSize: 11.5, color: AirbnbTheme.grey)),
              const Divider(height: 16),
              ...ord.items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${it.quantity} x ${it.unit.label} ${it.product.name}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('₹${(it.totalPaise / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                      ],
                    ),
                  )),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total: ₹${ord.totalRupees.toStringAsFixed(0)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.api.advanceOrderStage(ord.id);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order #${ord.orderNumber} loaded and out for delivery!'),
                          backgroundColor: AirbnbTheme.jodhpurBlue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_shipping, size: 14),
                    label: const Text('Dispatch on Route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.jodhpurBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 4. Warehouse Multi-Truck Loading Dock View:
/// Multi-truck fleet management, loading stock from Godown to Trucks (- Godown, + Truck),
/// unloading stock back to Godown (+ Godown, - Truck), and dispatching delivery orders.
class WarehouseLoadingView extends StatefulWidget {
  final ApiService api;
  const WarehouseLoadingView({super.key, required this.api});

  @override
  State<WarehouseLoadingView> createState() => _WarehouseLoadingViewState();
}

class _WarehouseLoadingViewState extends State<WarehouseLoadingView> {
  void _showCustomLoadDialog(ProductItem product, DeliveryTruck truck) {
    final qtyCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Load ${product.name} to ${truck.vehicleNumber}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available in Godown: ${product.godownStockBoxes} Boxes', style: const TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
            Text('Currently on Truck: ${truck.getStockForProduct(product.id)} Boxes', style: const TextStyle(fontSize: 12, color: AirbnbTheme.jodhpurBlue, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity to Load (Boxes)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0 || qty > product.godownStockBoxes) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid quantity! Must be between 1 and ${product.godownStockBoxes} boxes.')),
                );
                return;
              }
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await widget.api.transferStockToCar(product.id, qty, targetTruckId: truck.id);
              if (mounted) setState(() {});
              messenger.showSnackBar(
                SnackBar(content: Text('Loaded $qty boxes of ${product.name} into ${truck.vehicleNumber}!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AirbnbTheme.jodhpurBlue, foregroundColor: Colors.white),
            child: const Text('Confirm Load'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prods = widget.api.products;
    final trucks = widget.api.deliveryTrucks;
    final activeTruck = widget.api.activeTruck;
    final assignedOrders = widget.api.readyStockOrders.where((o) => o.assignedCarNumber == activeTruck.vehicleNumber).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Truck Fleet Tabs
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

          // 2. Active Truck Profile & Capacity Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AirbnbTheme.dark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vehicle Loading Dock', style: TextStyle(fontSize: 11, color: Color(0xFFB2BEC3))),
                        const SizedBox(height: 2),
                        Text(widget.api.carNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.api.totalCarBoxes} Boxes Loaded in Van',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF60A5FA), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Text(activeTruck.vehicleModel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Driver: ${activeTruck.driverName}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    Text('${activeTruck.capacityUtilizationPercent.toStringAsFixed(0)}% Capacity', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (activeTruck.capacityUtilizationPercent / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transfer Stock to Van', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              Text(
                'Godown Stock reduces instantly',
                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Stock Transfer List
          ...prods.map((p) {
            final inTruckBoxes = activeTruck.getStockForProduct(p.id);
            final hasGodownStock = p.godownStockBoxes > 0;
            final canLoad5 = p.godownStockBoxes >= 5;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AirbnbTheme.border),
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
                  // Top Row: Category icon, SKU title, Brand/Category tag
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Icon(Icons.fastfood_rounded, color: Color(0xFFB45309), size: 20),
                          ),
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
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                        color: AirbnbTheme.dark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      p.id,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${p.category} • ₹${((p.piecePricePaise * p.boxQty) / 100).toStringAsFixed(0)}/bx (${p.boxQty} pcs)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Middle Row: Godown vs In-Van Stock Badges
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.warehouse_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Godown: ${p.godownStockBoxes} bxs',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: p.godownStockBoxes > 0 ? const Color(0xFF334155) : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 16, color: const Color(0xFFCBD5E1)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.local_shipping_rounded, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'In Van: $inTruckBoxes bxs',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1),

                  // Bottom Action Bar: Stepper & Quick Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: [-1] and [+1 Box] actions
                        Row(
                          children: [
                            if (inTruckBoxes > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await widget.api.transferStockToCar(p.id, -1, targetTruckId: activeTruck.id);
                                    if (mounted) setState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('-1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ElevatedButton.icon(
                              onPressed: hasGodownStock
                                  ? () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      await widget.api.transferStockToCar(p.id, 1, targetTruckId: activeTruck.id);
                                      if (mounted) setState(() {});
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Loaded 1 box of ${p.name} into van!'),
                                          duration: const Duration(milliseconds: 600),
                                        ),
                                      );
                                    }
                                  : null,
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('+1 Box', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AirbnbTheme.jodhpurBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),

                        // Right: Quick Load +5 & Custom
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: canLoad5
                                  ? () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      await widget.api.transferStockToCar(p.id, 5, targetTruckId: activeTruck.id);
                                      if (mounted) setState(() {});
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Loaded 5 boxes of ${p.name} into van!'),
                                          duration: const Duration(milliseconds: 600),
                                        ),
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('+5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              onPressed: hasGodownStock
                                  ? () => _showCustomLoadDialog(p, activeTruck)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AirbnbTheme.jodhpurBlue,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('Custom', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          if (assignedOrders.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Orders Loaded for ${activeTruck.vehicleNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6)),
                  child: Text('${assignedOrders.length} Ready', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AirbnbTheme.success)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...assignedOrders.map((ord) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AirbnbTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #${ord.orderNumber} • ${ord.shopName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        Text('₹${ord.totalRupees.toStringAsFixed(0)} • ${ord.items.length} items', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.api.advanceOrderStage(ord.id);
                      if (mounted) setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Dispatched Order #${ord.orderNumber} for delivery!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Dispatch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
