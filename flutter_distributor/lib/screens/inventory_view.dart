import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/airbnb_theme.dart';
import 'views/packaging_builder_dialog.dart';

class InventoryView extends StatefulWidget {
  final ApiService api;
  const InventoryView({super.key, required this.api});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Snacks & Kurkure',
    'Namkeen & Sweets',
    'Spices & Mirchi',
    'Ghee & Edible Oils',
    'Biscuits & Bakery',
  ];

  void _showAddProductSheet() {
    final nameCtrl = TextEditingController();
    final hindiCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    final piecePriceCtrl = TextEditingController();
    final stripQtyCtrl = TextEditingController(text: '12');
    final boxQtyCtrl = TextEditingController(text: '48');
    final stockBoxesCtrl = TextEditingController(text: '100');
    final badgeCtrl = TextEditingController(text: 'New Arrival');
    String selectedCat = 'Snacks & Kurkure';
    double selectedGst = 18.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AirbnbTheme.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Add Inventory Item',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AirbnbTheme.dark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Stock added here appears instantly in Sales',
                              style: TextStyle(fontSize: 11.5, color: AirbnbTheme.grey),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AirbnbTheme.coral.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Godown Intake',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AirbnbTheme.coral,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Product Name
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Product Name (e.g. Kurkure Green Chutney)',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Hindi Name
                    TextField(
                      controller: hindiCtrl,
                      decoration: InputDecoration(
                        labelText: 'Hindi / Local Name (e.g. कुरकुरे ग्रीन चटनी)',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category Selector
                    DropdownButtonFormField<String>(
                      initialValue: selectedCat,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _categories.where((c) => c != 'All').map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedCat = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // MRP and Base Wholesale Piece Price
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: mrpCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'MRP (₹)',
                              labelStyle: const TextStyle(fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: piecePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Piece Base (₹)',
                              labelStyle: const TextStyle(fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Strip Qty, Box Qty, Initial Stock Boxes
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stripQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Pcs / Strip',
                              labelStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: boxQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Pcs / Box',
                              labelStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: stockBoxesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Godown Boxes',
                              labelStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // GST Rate Chips & Badge
                    Row(
                      children: [
                        const Text('GST: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ...[5.0, 12.0, 18.0].map((rate) {
                          final isSel = selectedGst == rate;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('${rate.toInt()}%'),
                              selected: isSel,
                              onSelected: (_) => setSheetState(() => selectedGst = rate),
                              selectedColor: const Color(0xFF6C5CE7),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: isSel ? Colors.white : AirbnbTheme.dark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: badgeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Badge',
                              labelStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a product name')),
                            );
                            return;
                          }

                          final mrp = double.tryParse(mrpCtrl.text) ?? 20.0;
                          final piecePrice = ((double.tryParse(piecePriceCtrl.text) ?? (mrp * 0.85)) * 100).round();
                          final stripQty = int.tryParse(stripQtyCtrl.text) ?? 12;
                          final boxQty = int.tryParse(boxQtyCtrl.text) ?? 48;
                          final initialBoxes = int.tryParse(stockBoxesCtrl.text) ?? 100;
                          final hindi = hindiCtrl.text.trim().isNotEmpty
                              ? hindiCtrl.text.trim()
                              : name;

                          final newItem = ProductItem(
                            id: 'PROD_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            hindiName: hindi,
                            category: selectedCat,
                            mrpRupees: mrp,
                            piecePricePaise: piecePrice,
                            stripQty: stripQty,
                            boxQty: boxQty,
                            gstRate: selectedGst,
                            godownStockBoxes: initialBoxes,
                            carStockBoxes: 0,
                            badge: badgeCtrl.text.trim(),
                          );

                          widget.api.addProduct(newItem);
                          Navigator.pop(ctx);
                          setState(() {});

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Added "$name" ($initialBoxes boxes) to Godown Inventory! Available in Sales.'),
                              backgroundColor: AirbnbTheme.success,
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        label: const Text('Add to Godown Inventory'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _showRestockDialog(ProductItem p) {
    final qtyCtrl = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.inventory, color: AirbnbTheme.success),
            const SizedBox(width: 8),
            const Text('Godown Restock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text('Current Godown Stock: ${p.godownStockBoxes} Boxes',
                style: const TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
            const SizedBox(height: 12),
            const Text('Add Boxes received from supplier:'),
            const SizedBox(height: 8),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Boxes to Add',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [10, 25, 50, 100].map((count) {
                return OutlinedButton(
                  onPressed: () => qtyCtrl.text = '$count',
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(40, 28),
                  ),
                  child: Text('+$count', style: const TextStyle(fontSize: 11)),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final addBoxes = int.tryParse(qtyCtrl.text) ?? 0;
              if (addBoxes > 0) {
                widget.api.restockProduct(p.id, addBoxes);
                setState(() {});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Restocked +$addBoxes boxes of ${p.name}! Total: ${p.godownStockBoxes} boxes'),
                    backgroundColor: AirbnbTheme.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbTheme.dark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Restock'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ProductItem p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Archive from Inventory?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Are you sure you want to archive "${p.name}"? It will be hidden from the active sales catalog while preserving all past inventory records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              widget.api.archiveProduct(p.id);
              setState(() {});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Archived ${p.name} from active inventory'),
                  backgroundColor: Colors.grey.shade800,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900, foregroundColor: Colors.white),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = widget.api.products;
    final filtered = allProducts.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.hindiName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    final totalBoxes = widget.api.totalGodownBoxes;
    final totalCarBoxes = widget.api.totalCarBoxes;

    return Column(
      children: [
        // 1. GODOWN WAREHOUSE SUMMARY HEADER
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AirbnbTheme.dark,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
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
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AirbnbTheme.coral.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.warehouse_outlined, color: AirbnbTheme.coral, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'CENTRAL GODOWN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                'Basni Industrial Area, Phase II, Jodhpur',
                                style: TextStyle(color: Colors.white60, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddProductSheet,
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(80, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Godown Metrics Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Godown Stock', style: TextStyle(color: Colors.white60, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          '$totalBoxes Boxes',
                          style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 26, color: Colors.white24),
                    Column(
                      children: [
                        const Text('Car (${"RJ-19"})', style: TextStyle(color: Colors.white60, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          '$totalCarBoxes Boxes',
                          style: const TextStyle(color: Color(0xFF90CAF9), fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 26, color: Colors.white24),
                    Column(
                      children: [
                        const Text('Active SKUs', style: TextStyle(color: Colors.white60, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          '${allProducts.length} Items',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. SEARCH & CATEGORIES
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AirbnbTheme.border),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Search Godown items...',
                      hintStyle: TextStyle(fontSize: 12, color: AirbnbTheme.grey),
                      prefixIcon: Icon(Icons.search, size: 18, color: AirbnbTheme.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Categories Chips
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: AirbnbTheme.dark,
                  backgroundColor: AirbnbTheme.cardBg,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.white : AirbnbTheme.dark,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: isSel ? AirbnbTheme.dark : AirbnbTheme.border),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 4),

        // 3. DYNAMIC INVENTORY ITEMS LIST
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: AirbnbTheme.grey),
                      const SizedBox(height: 10),
                      const Text('No products in this category', style: TextStyle(fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
                      const SizedBox(height: 6),
                      ElevatedButton.icon(
                        onPressed: _showAddProductSheet,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add First Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.coral,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    final isLowStock = p.godownStockBoxes <= 15;
                    final isOutOfStock = p.godownStockBoxes == 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOutOfStock
                              ? Colors.red.withValues(alpha: 0.4)
                              : isLowStock
                                  ? Colors.amber.withValues(alpha: 0.6)
                                  : AirbnbTheme.border,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AirbnbTheme.coral.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    p.category.contains('Snacks')
                                        ? Icons.fastfood
                                        : Icons.inventory_2_outlined,
                                    color: AirbnbTheme.coral,
                                    size: 22,
                                  ),
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
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13.5,
                                              color: AirbnbTheme.dark,
                                            ),
                                          ),
                                        ),
                                        if (p.badge.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              p.badge,
                                              style: const TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                color: AirbnbTheme.jodhpurBlue,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p.hindiName} • ${p.category}',
                                      style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'MRP: ₹${p.mrpRupees.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AirbnbTheme.dark),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Base: ₹${p.priceRupeesForUnit(OrderUnit.piece).toStringAsFixed(1)}/pc',
                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF6C5CE7), fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Peti: ₹${p.priceRupeesForUnit(OrderUnit.box).toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AirbnbTheme.coral),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          // Live Stock & Actions Row
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock
                                          ? Colors.red.withValues(alpha: 0.1)
                                          : isLowStock
                                              ? Colors.amber.withValues(alpha: 0.15)
                                              : AirbnbTheme.success.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isOutOfStock
                                              ? Icons.warning
                                              : isLowStock
                                                  ? Icons.info_outline
                                                  : Icons.check_circle_outline,
                                          size: 13,
                                          color: isOutOfStock
                                              ? Colors.red
                                              : isLowStock
                                                  ? Colors.amber[800]
                                                  : AirbnbTheme.success,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.api.pendingBookingPieces(p.id) > 0
                                              ? 'Godown: ${p.godownStockBoxes} Bxs (${widget.api.pendingBookingBoxes(p.id)}b res)'
                                              : 'Godown: ${p.godownStockBoxes} Boxes',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isOutOfStock
                                                ? Colors.red
                                                : isLowStock
                                                    ? Colors.amber[900]
                                                    : AirbnbTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Car: ${p.carStockBoxes} bxs',
                                    style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Packaging Hierarchy & Multi-Tier Pricing Button
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    icon: const Icon(Icons.layers_outlined, size: 16, color: Color(0xFF1E3A8A)),
                                    tooltip: 'Packaging & Unit Pricing',
                                    onPressed: () => PackagingBuilderDialog.show(
                                      context,
                                      api: widget.api,
                                      product: p,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Quick Restock Button
                                  OutlinedButton.icon(
                                    onPressed: () => _showRestockDialog(p),
                                    icon: const Icon(Icons.add, size: 12),
                                    label: const Text('Restock', style: TextStyle(fontSize: 10.5)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AirbnbTheme.success,
                                      side: const BorderSide(color: AirbnbTheme.success, width: 0.8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(60, 28),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Delete / Remove Button
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                    onPressed: () => _showDeleteDialog(p),
                                  ),
                                ],
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
}
