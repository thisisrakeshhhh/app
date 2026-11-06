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

              // Segmented Sub-Tabs
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
          child: switch (_subTabIndex) {
            0 => _buildCatalogView(allProducts),
            1 => _buildExpiryRadarView(allProducts),
            2 => _buildAnalyticsView(allProducts, totalValuation),
            _ => _buildCatalogView(allProducts),
          },
        ),
      ],
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
                              Column(
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
                                    'Valuation: ₹${prod.godownValuationRupees.toStringAsFixed(0)} • MRP ₹${prod.mrpRupees.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey),
                                  ),
                                ],
                              ),
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

/// 2. Warehouse Inward View: Factory Shipment Intake Form.
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
    super.dispose();
  }

  void _postInwardReceipt() async {
    if (_selectedProduct == null) return;
    final boxes = int.tryParse(_boxesCtrl.text) ?? 0;
    if (boxes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid box quantity greater than 0')),
      );
      return;
    }

    final key = 'grn_quick_${_selectedProduct!.id}_${DateTime.now().millisecondsSinceEpoch}';
    await widget.api.receiveStockGrnDurable(
      productId: _selectedProduct!.id,
      supplierName: _supplierCtrl.text.trim().isEmpty ? 'Depot Supplier' : _supplierCtrl.text.trim(),
      invoiceNumber: _challanCtrl.text.trim().isEmpty ? 'CH-${DateTime.now().millisecondsSinceEpoch}' : _challanCtrl.text.trim(),
      batchNumber: _batchCtrl.text.trim().isEmpty ? 'B-DEFAULT' : _batchCtrl.text.trim(),
      cartonsReceived: boxes,
      loosePiecesReceived: 0,
      damagedCartons: 0,
      damagedLoosePieces: 0,
      notes: 'Vehicle: ${_vehicleCtrl.text.trim()}',
      idempotencyKey: key,
    );
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Inward Received: $boxes boxes of ${_selectedProduct!.name} posted to Godown!'),
          backgroundColor: AirbnbTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    Text('Record Inward Shipment (Sample Form)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Stock received here updates local test inventory. Default values below are sample form pre-fills.', style: TextStyle(fontSize: 11.5, color: AirbnbTheme.grey)),
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
                const SizedBox(height: 12),

                // SKU Selector
                const Text('Product SKU Received', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AirbnbTheme.grey)),
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
                      value: _selectedProduct,
                      isExpanded: true,
                      items: widget.api.products.map((p) {
                        return DropdownMenuItem<ProductItem>(
                          value: p,
                          child: Text('${p.name} (Cur: ${p.godownStockBoxes} boxes)'),
                        );
                      }).toList(),
                      onChanged: (p) => setState(() => _selectedProduct = p),
                    ),
                  ),
                ),
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
                    onPressed: _postInwardReceipt,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Post Inward to Godown Stock', style: TextStyle(fontWeight: FontWeight.w700)),
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

/// 3. Warehouse Picking & Packing View: Orders picking queue & pack verification.
class WarehousePickingView extends StatelessWidget {
  final ApiService api;
  const WarehousePickingView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final bookingOrders = api.bookingOrders;

    return bookingOrders.isEmpty
        ? Center(
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
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: bookingOrders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final ord = bookingOrders[idx];
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order #${ord.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(4)),
                          child: const Text('PICKING QUEUE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFEA580C))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Retailer: ${ord.shopName} • Assigned Car: ${ord.assignedCarNumber}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                    const Divider(height: 16),
                    ...ord.items.map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${it.quantity} x ${it.unit.label} ${it.product.name}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${it.totalPieces} pcs', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                            ],
                          ),
                        )),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order Value: ₹${ord.totalRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ElevatedButton.icon(
                          onPressed: () {
                            api.advanceOrderStage(ord.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Order #${ord.orderNumber} packed and staged for car loading!')),
                            );
                          },
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Mark Packed & Ready'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AirbnbTheme.success,
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

/// 4. Warehouse Vehicle Loading View: Transfer stock to Car RJ-19-GB-4021.
class WarehouseLoadingView extends StatelessWidget {
  final ApiService api;
  const WarehouseLoadingView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final prods = api.products;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AirbnbTheme.dark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vehicle Loading Dock', style: TextStyle(fontSize: 11, color: Color(0xFFB2BEC3))),
                    const SizedBox(height: 2),
                    Text(api.carNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('${api.totalCarBoxes} Boxes Loaded in Van', style: const TextStyle(fontSize: 12, color: Color(0xFF60A5FA), fontWeight: FontWeight.w700)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Text('Tata Ace', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Transfer Stock to Van', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...prods.map((p) {
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
                        Text('Godown: ${p.godownStockBoxes} bxs • Van: ${p.carStockBoxes} bxs', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: p.godownStockBoxes >= 1
                            ? () {
                                api.transferStockToCar(p.id, 1);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Loaded 1 box of ${p.name} into van!'), duration: const Duration(milliseconds: 600)),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.jodhpurBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('+1 Box', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: p.godownStockBoxes >= 5
                            ? () {
                                api.transferStockToCar(p.id, 5);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Loaded 5 boxes of ${p.name} into van!'), duration: const Duration(milliseconds: 600)),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.dark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('+5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
}
