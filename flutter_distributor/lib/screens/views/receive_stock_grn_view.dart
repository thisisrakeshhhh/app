import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class ReceiveStockGrnView extends StatefulWidget {
  final ApiService api;

  const ReceiveStockGrnView({
    super.key,
    required this.api,
  });

  @override
  State<ReceiveStockGrnView> createState() => _ReceiveStockGrnViewState();
}

class _ReceiveStockGrnViewState extends State<ReceiveStockGrnView> {
  ProductItem? _selectedProduct;
  final _supplierCtrl = TextEditingController(text: 'Parle Agro Jodhpur Depot');
  final _invoiceCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  int _receivedCartons = 10;
  int _receivedLoosePieces = 0;
  int _damagedCartons = 0;
  int _damagedLoosePieces = 0;

  bool _hasDamagedStock = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.api.products.isNotEmpty) {
      _selectedProduct = widget.api.products.first;
    }
    final now = DateTime.now();
    _invoiceCtrl.text = 'INV-${now.year}-${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-01';
    _batchCtrl.text = 'B-${now.millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _invoiceCtrl.dispose();
    _batchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitGrn() async {
    if (_selectedProduct == null) {
      setState(() => _errorMessage = 'Please select a product.');
      return;
    }
    if (_supplierCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Supplier name is required.');
      return;
    }
    if (_invoiceCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Invoice / Challan number is required.');
      return;
    }
    if (_receivedCartons <= 0 && _receivedLoosePieces <= 0 && _damagedCartons <= 0 && _damagedLoosePieces <= 0) {
      setState(() => _errorMessage = 'Total received quantity cannot be 0.');
      return;
    }

    final currentBoxes = _selectedProduct!.godownStockBoxes;
    final resultingBoxes = currentBoxes + _receivedCartons;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.verified, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Reconfirm GRN Stock Intake', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please verify the received SKU and count before posting to Godown:', style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFAED581)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_selectedProduct!.name} (${_selectedProduct!.id})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text('Current Godown: $currentBoxes Boxes', style: const TextStyle(fontSize: 12)),
                  Text('Inward Cartons: +$_receivedCartons Boxes', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  const SizedBox(height: 2),
                  Text('New Total: $resultingBoxes Boxes', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back / Edit')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            child: const Text('✓ Yes, Post to Godown'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final key = 'grn_${_selectedProduct!.id}_${DateTime.now().millisecondsSinceEpoch}';
      await widget.api.receiveStockGrnDurable(
        productId: _selectedProduct!.id,
        supplierName: _supplierCtrl.text.trim(),
        invoiceNumber: _invoiceCtrl.text.trim(),
        batchNumber: _batchCtrl.text.trim(),
        cartonsReceived: _receivedCartons,
        loosePiecesReceived: _receivedLoosePieces,
        damagedCartons: _hasDamagedStock ? _damagedCartons : 0,
        damagedLoosePieces: _hasDamagedStock ? _damagedLoosePieces : 0,
        notes: _notesCtrl.text.trim(),
        idempotencyKey: key,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock Inward GRN recorded! +$_receivedCartons boxes added to godown.',
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Widget _buildStepper({
    required String label,
    required String hindiLabel,
    required int value,
    required ValueChanged<int> onChanged,
    Color activeColor = const Color(0xFF1E3A8A),
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '($hindiLabel)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove),
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
              ),
              const SizedBox(width: 12),
              Container(
                width: 70,
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: activeColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(backgroundColor: activeColor),
                onPressed: () => onChanged(value + 1),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                children: [5, 10, 50].map((step) {
                  return ActionChip(
                    label: Text('+$step', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => onChanged(value + step),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receive Stock (GRN)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('आवक रसीद एवं गोडाउन स्टॉक प्रविष्टि', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 1. Product Selection
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select SKU / Product (सामान चुनें)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ProductItem>(
                      initialValue: _selectedProduct,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      items: widget.api.products.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.name} (${p.hindiName})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedProduct = val),
                    ),
                    if (_selectedProduct != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Current Godown Stock: ${_selectedProduct!.godownStockBoxes} Boxes | MRP: ₹${_selectedProduct!.mrpRupees}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Supplier & Invoice Details
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _supplierCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Supplier / Depot Name (आपूर्तिकर्ता)',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _invoiceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Invoice / Challan No.',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _batchCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Batch Number',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Received Clean Stock
            _buildStepper(
              label: 'Received Sellable Cartons (Boxes)',
              hindiLabel: 'प्राप्त बक्से',
              value: _receivedCartons,
              onChanged: (val) => setState(() => _receivedCartons = val),
              activeColor: const Color(0xFF1E3A8A),
            ),
            const SizedBox(height: 10),
            _buildStepper(
              label: 'Loose Pieces (if any)',
              hindiLabel: 'खुल्ले पीस',
              value: _receivedLoosePieces,
              onChanged: (val) => setState(() => _receivedLoosePieces = val),
              activeColor: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 14),

            // 4. Damaged Stock Section (खराब / टूटा माल)
            Container(
              decoration: BoxDecoration(
                color: _hasDamagedStock ? const Color(0xFFFFF7ED) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasDamagedStock ? Colors.orange.shade300 : Colors.grey.shade300,
                ),
              ),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      title: const Text(
                        'Report Damaged / Broken Stock',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'खराब अथवा टूटा माल दर्ज करें (अलग क्वारंटाइन में रखा जाएगा)',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _hasDamagedStock,
                      activeThumbColor: Colors.deepOrange,
                      onChanged: (v) => setState(() => _hasDamagedStock = v),
                    ),
                  ),
                  if (_hasDamagedStock) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        children: [
                          _buildStepper(
                            label: 'Damaged Cartons',
                            hindiLabel: 'टूटे / भीगे बक्से',
                            value: _damagedCartons,
                            onChanged: (val) => setState(() => _damagedCartons = val),
                            activeColor: Colors.deepOrange,
                          ),
                          const SizedBox(height: 8),
                          _buildStepper(
                            label: 'Damaged Loose Pieces',
                            hindiLabel: 'टूटे हुए खुल्ले पीस',
                            value: _damagedLoosePieces,
                            onChanged: (val) => setState(() => _damagedLoosePieces = val),
                            activeColor: Colors.deepOrange,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Note: Damaged stock is securely isolated in quarantine snapshots and excluded from sellable stock.',
                            style: TextStyle(fontSize: 10.5, color: Colors.orange.shade900, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Notes / Remarks
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Delivery Remarks / Vehicle Number (वाहन संख्या/विवरण)',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            // 6. Confirm Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isLoading ? null : _submitGrn,
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Confirm Stock Inward (स्टॉक आवक दर्ज करें)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
