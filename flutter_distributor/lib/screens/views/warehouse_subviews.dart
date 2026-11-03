import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import 'receive_stock_grn_view.dart';

/// 1. Warehouse Stock View: Live Godown inventory with search, adjust stock, add SKU.
class WarehouseStockView extends StatefulWidget {
  final ApiService api;
  const WarehouseStockView({super.key, required this.api});

  @override
  State<WarehouseStockView> createState() => _WarehouseStockViewState();
}

class _WarehouseStockViewState extends State<WarehouseStockView> {
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

  void _showAdjustStockSheet(ProductItem product) {
    int addQty = 10;
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
                  Text('Adjust Stock: ${product.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Current Godown: ${product.godownStockBoxes} Boxes (${product.boxQty} pcs/box)', style: const TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: addQty > 1 ? () => setSheetState(() => addQty--) : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 28),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('+$addQty Boxes', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AirbnbTheme.jodhpurBlue)),
                      ),
                      IconButton(
                        onPressed: () => setSheetState(() => addQty++),
                        icon: const Icon(Icons.add_circle_outline, size: 28, color: AirbnbTheme.jodhpurBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.api.restockProduct(product.id, addQty);
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added $addQty boxes to ${product.name} in Godown!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbTheme.jodhpurBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Confirm Stock Update', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final filtered = widget.api.products.where((p) {
      final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.hindiName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    return Column(
      children: [
        // Category horizontal chips
        Container(
          height: 42,
          margin: const EdgeInsets.symmetric(vertical: 6),
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

        // Product search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search SKU or Hindi name in Godown...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: AirbnbTheme.lightGrey,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),

        // Products List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final prod = filtered[idx];
              final isLow = prod.godownStockBoxes < 40;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isLow ? const Color(0xFFFDBA74) : AirbnbTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isLow ? const Color(0xFFFFF7ED) : AirbnbTheme.jodhpurBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.inventory_2, color: isLow ? const Color(0xFFEA580C) : AirbnbTheme.jodhpurBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prod.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('${prod.hindiName} • ${prod.category} (${prod.boxQty} pcs/box)', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${prod.godownStockBoxes} Boxes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isLow ? const Color(0xFFEA580C) : AirbnbTheme.dark)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _showAdjustStockSheet(prod),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Adjust +', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
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
