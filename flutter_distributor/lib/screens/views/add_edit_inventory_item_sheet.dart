import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';

/// Interactive Modal Sheet for Creating and Editing Inventory Items / SKUs manually.
class AddEditInventoryItemSheet extends StatefulWidget {
  final ApiService api;
  final ProductItem? initialProduct; // Null when creating new; non-null when editing

  const AddEditInventoryItemSheet({
    super.key,
    required this.api,
    this.initialProduct,
  });

  static Future<ProductItem?> show(BuildContext context, ApiService api, {ProductItem? product}) {
    return showModalBottomSheet<ProductItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditInventoryItemSheet(api: api, initialProduct: product),
    );
  }

  @override
  State<AddEditInventoryItemSheet> createState() => _AddEditInventoryItemSheetState();
}

class _AddEditInventoryItemSheetState extends State<AddEditInventoryItemSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _hindiNameController;
  late TextEditingController _mrpController;
  late TextEditingController _wholesalePriceController; // piece
  late TextEditingController _stripPriceController; // strip
  late TextEditingController _boxPriceController; // box
  late TextEditingController _boxQtyController;
  late TextEditingController _stripQtyController;
  late TextEditingController _stockBoxesController;
  late TextEditingController _batchNumberController;
  late TextEditingController _reorderLevelController;

  late String _selectedCategory;
  late double _selectedGstRate;
  DateTime? _selectedExpiryDate;

  final List<String> _categories = [
    'Traditional Namkeen',
    'Potato Wafers',
    'Extruded Snacks & Fryums',
    'Bakery & Confectionery',
  ];

  final List<double> _gstRates = [5.0, 12.0, 18.0, 28.0];

  bool get _isEditing => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;

    final generatedId = p?.id ?? 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final initialPiecePrice = p != null ? (p.piecePricePaise / 100.0) : 17.00;
    final initialBoxQty = p?.boxQty ?? 24;
    final initialStripQty = p?.stripQty ?? 6;
    final initialStripPrice = p != null ? (p.priceForUnit(OrderUnit.strip) / 100.0) : (initialPiecePrice * initialStripQty);
    final initialBoxPrice = p != null ? (p.priceForUnit(OrderUnit.box) / 100.0) : (initialPiecePrice * initialBoxQty);

    _idController = TextEditingController(text: p?.id ?? generatedId);
    _nameController = TextEditingController(text: p?.name ?? '');
    _hindiNameController = TextEditingController(text: p?.hindiName ?? '');
    _mrpController = TextEditingController(text: p != null ? p.mrpRupees.toStringAsFixed(1) : '20.0');
    _wholesalePriceController = TextEditingController(text: initialPiecePrice.toStringAsFixed(2));
    _stripPriceController = TextEditingController(text: initialStripPrice.toStringAsFixed(2));
    _boxPriceController = TextEditingController(text: initialBoxPrice.toStringAsFixed(2));
    _boxQtyController = TextEditingController(text: initialBoxQty.toString());
    _stripQtyController = TextEditingController(text: initialStripQty.toString());
    _stockBoxesController = TextEditingController(text: (p?.godownStockBoxes ?? 50).toString());
    _batchNumberController = TextEditingController(
      text: p?.batchNumber ?? 'LOT-${DateTime.now().year}-B${DateTime.now().month}',
    );
    _reorderLevelController = TextEditingController(text: (p?.reorderLevelBoxes ?? 30).toString());

    _selectedCategory = p?.category ?? _categories.first;
    if (!_categories.contains(_selectedCategory)) {
      _categories.insert(0, _selectedCategory);
    }

    _selectedGstRate = p?.gstRate ?? 18.0;
    if (!_gstRates.contains(_selectedGstRate)) {
      _gstRates.add(_selectedGstRate);
      _gstRates.sort();
    }

    _selectedExpiryDate = p?.expiryDate ?? DateTime.now().add(const Duration(days: 180));
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _hindiNameController.dispose();
    _mrpController.dispose();
    _wholesalePriceController.dispose();
    _stripPriceController.dispose();
    _boxPriceController.dispose();
    _boxQtyController.dispose();
    _stripQtyController.dispose();
    _stockBoxesController.dispose();
    _batchNumberController.dispose();
    _reorderLevelController.dispose();
    super.dispose();
  }

  void _autoCalculatePricesFromPiece() {
    final piecePrice = double.tryParse(_wholesalePriceController.text.trim()) ?? 0.0;
    final stripQty = int.tryParse(_stripQtyController.text.trim()) ?? 6;
    final boxQty = int.tryParse(_boxQtyController.text.trim()) ?? 24;

    setState(() {
      _stripPriceController.text = (piecePrice * stripQty).toStringAsFixed(2);
      _boxPriceController.text = (piecePrice * boxQty).toStringAsFixed(2);
    });
  }

  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;

    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    final hindiName = _hindiNameController.text.trim().isNotEmpty
        ? _hindiNameController.text.trim()
        : name;

    final mrpRupees = double.tryParse(_mrpController.text.trim()) ?? 20.0;
    final mrpPaise = (mrpRupees * 100).round();

    final boxQty = int.tryParse(_boxQtyController.text.trim()) ?? 24;
    final stripQty = int.tryParse(_stripQtyController.text.trim()) ?? 6;

    final piecePriceRupees = double.tryParse(_wholesalePriceController.text.trim()) ?? 17.0;
    final piecePricePaise = (piecePriceRupees * 100).round();

    final stripPriceRupees = double.tryParse(_stripPriceController.text.trim()) ?? (piecePriceRupees * stripQty);
    final stripPricePaise = (stripPriceRupees * 100).round();

    final boxPriceRupees = double.tryParse(_boxPriceController.text.trim()) ?? (piecePriceRupees * boxQty);
    final boxPricePaise = (boxPriceRupees * 100).round();

    final godownBoxes = int.tryParse(_stockBoxesController.text.trim()) ?? 0;
    final reorderLevel = int.tryParse(_reorderLevelController.text.trim()) ?? 30;
    final batchNo = _batchNumberController.text.trim().isNotEmpty
        ? _batchNumberController.text.trim()
        : 'LOT-${DateTime.now().year}-GEN';

    final customUnitPricesPaise = <String, int>{
      'piece': piecePricePaise,
      'strip': stripPricePaise,
      'box': boxPricePaise,
    };

    final customUnitMultipliers = <String, int>{
      'piece': 1,
      'strip': stripQty,
      'box': boxQty,
    };

    final product = ProductItem(
      id: id,
      name: name,
      hindiName: hindiName,
      category: _selectedCategory,
      mrpPaise: mrpPaise,
      piecePricePaise: piecePricePaise,
      stripQty: stripQty,
      boxQty: boxQty,
      gstRate: _selectedGstRate,
      godownStockBoxes: godownBoxes,
      carStockBoxes: widget.initialProduct?.carStockBoxes ?? 0,
      badge: widget.initialProduct?.badge ?? 'Manual SKU',
      imageUrl: widget.initialProduct?.imageUrl ?? '',
      batchNumber: batchNo,
      expiryDate: _selectedExpiryDate,
      reorderLevelBoxes: reorderLevel,
      customUnitPricesPaise: customUnitPricesPaise,
      customUnitMultipliers: customUnitMultipliers,
    );

    if (_isEditing) {
      widget.api.updateProduct(product);
    } else {
      widget.api.addProduct(product);
    }

    Navigator.pop(context, product);
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final initial = _selectedExpiryDate ?? now.add(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 4)),
      helpText: 'Select Batch Expiry Date (समाप्ति तिथि)',
    );
    if (picked != null) {
      setState(() => _selectedExpiryDate = picked);
    }
  }

  void _applyExpiryPresetMonths(int months) {
    setState(() {
      _selectedExpiryDate = DateTime.now().add(Duration(days: months * 30));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AirbnbTheme.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                        color: AirbnbTheme.jodhpurBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Inventory SKU' : 'Add Inventory SKU',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AirbnbTheme.dark,
                          ),
                        ),
                        Text(
                          _isEditing ? 'Update stock, prices & batch' : 'Manual stock intake to Godown',
                          style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AirbnbTheme.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Form Fields
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SKU Identifier (Disabled in edit mode to preserve history)
                    TextFormField(
                      controller: _idController,
                      enabled: !_isEditing,
                      decoration: InputDecoration(
                        labelText: 'SKU / Product Code *',
                        hintText: 'e.g. PEPSI-CAN-330',
                        prefixIcon: const Icon(Icons.qr_code_2, size: 20),
                        filled: true,
                        fillColor: _isEditing ? AirbnbTheme.lightGrey : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter unique SKU Code' : null,
                    ),
                    const SizedBox(height: 12),

                    // Product English Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name (English) *',
                        hintText: 'e.g. Lay\'s Wafers Salted 50g',
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter product name' : null,
                    ),
                    const SizedBox(height: 12),

                    // Product Hindi Name
                    TextFormField(
                      controller: _hindiNameController,
                      decoration: InputDecoration(
                        labelText: 'Hindi / Local Name (हिंदी नाम)',
                        hintText: 'e.g. लेज़ नमकीन वेफर्स',
                        prefixIcon: const Icon(Icons.translate, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Dropdown
                    const Text('Category (श्रेणी) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AirbnbTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          items: _categories
                              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 12.5))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stock & Packaging Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockBoxesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Godown Stock (Boxes) *',
                              prefixIcon: const Icon(Icons.all_inbox, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (val) => (val == null || int.tryParse(val) == null) ? 'Enter valid number' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _reorderLevelController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Reorder Alert (Boxes)',
                              prefixIcon: const Icon(Icons.notifications_active_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Packaging Units (Pieces per Box & Strip)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _boxQtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Pcs per Box *',
                              prefixIcon: const Icon(Icons.grid_view, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (val) => (val == null || (int.tryParse(val) ?? 0) <= 0) ? '> 0 required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stripQtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Pcs per Strip (लड़ी)',
                              prefixIcon: const Icon(Icons.linear_scale, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Retail MRP
                    TextFormField(
                      controller: _mrpController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Retail MRP per Piece (₹) *',
                        prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) => (val == null || (double.tryParse(val) ?? 0) <= 0) ? 'Valid MRP required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Multi-Unit Wholesale Pricing Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AirbnbTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.sell_outlined, size: 16, color: AirbnbTheme.jodhpurBlue),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Unit Wholesale Pricing (पीस, लड़ी, पेटी)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _autoCalculatePricesFromPiece,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calculate_outlined, size: 12, color: AirbnbTheme.jodhpurBlue),
                                      SizedBox(width: 3),
                                      Text(
                                        'Auto-Fill Units',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 1. Piece Price
                          TextFormField(
                            controller: _wholesalePriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Wholesale Price per Piece (प्रति पीस) *',
                              prefixIcon: const Icon(Icons.crop_square, size: 16),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (val) => (val == null || (double.tryParse(val) ?? 0) <= 0) ? 'Enter piece price' : null,
                          ),
                          const SizedBox(height: 8),

                          // 2. Strip & Box Prices Row
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _stripPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Strip Price (प्रति लड़ी)',
                                    prefixIcon: const Icon(Icons.linear_scale, size: 16),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _boxPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Box Price (प्रति पेटी)',
                                    prefixIcon: const Icon(Icons.all_inbox, size: 16),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // GST Rate Selector
                    Row(
                      children: [
                        const Text('GST Rate: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        ..._gstRates.map((rate) {
                          final isSel = _selectedGstRate == rate;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('${rate.toInt()}%'),
                              selected: isSel,
                              selectedColor: AirbnbTheme.jodhpurBlue,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : AirbnbTheme.dark,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _selectedGstRate = rate);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Batch Tracking & Expiry
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AirbnbTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified_outlined, size: 16, color: AirbnbTheme.jodhpurBlue),
                              SizedBox(width: 6),
                              Text(
                                'Batch & Expiry Controls (बैच व एक्सपायरी)',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _batchNumberController,
                            decoration: InputDecoration(
                              labelText: 'Batch Number (बैच नंबर) *',
                              hintText: 'e.g. LOT-2026-N1',
                              prefixIcon: const Icon(Icons.tag, size: 18),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter batch number' : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickExpiryDate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AirbnbTheme.border),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_month_outlined, size: 18, color: AirbnbTheme.coral),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedExpiryDate != null
                                                ? '${_selectedExpiryDate!.day.toString().padLeft(2, '0')}/${_selectedExpiryDate!.month.toString().padLeft(2, '0')}/${_selectedExpiryDate!.year}'
                                                : 'Set Expiry Date',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Quick Presets
                              Wrap(
                                spacing: 4,
                                children: [
                                  ActionChip(
                                    label: const Text('+3M', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                                    onPressed: () => _applyExpiryPresetMonths(3),
                                  ),
                                  ActionChip(
                                    label: const Text('+6M', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                                    onPressed: () => _applyExpiryPresetMonths(6),
                                  ),
                                  ActionChip(
                                    label: const Text('+1Y', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                                    onPressed: () => _applyExpiryPresetMonths(12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveItem,
                        icon: Icon(_isEditing ? Icons.check_circle_outline : Icons.save_alt_rounded),
                        label: Text(
                          _isEditing ? 'Save Changes' : 'Add Item to Godown Inventory',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.jodhpurBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }
}
