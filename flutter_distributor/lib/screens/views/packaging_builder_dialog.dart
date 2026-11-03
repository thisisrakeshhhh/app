import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class PackagingBuilderDialog extends StatefulWidget {
  final ApiService api;
  final ProductItem product;

  const PackagingBuilderDialog({
    super.key,
    required this.api,
    required this.product,
  });

  static Future<void> show(
    BuildContext context, {
    required ApiService api,
    required ProductItem product,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => PackagingBuilderDialog(api: api, product: product),
    );
  }

  @override
  State<PackagingBuilderDialog> createState() => _PackagingBuilderDialogState();
}

class _PackagingUnitDraft {
  String unitName;
  int multiplierToBase;
  bool isBaseUnit;
  bool allowLooseSale;
  bool canBuy;
  bool canSell;
  int wholesalePricePaise;
  int mrpPaise;

  _PackagingUnitDraft({
    required this.unitName,
    required this.multiplierToBase,
    this.isBaseUnit = false,
    this.allowLooseSale = true,
    this.canBuy = true,
    this.canSell = true,
    required this.wholesalePricePaise,
    required this.mrpPaise,
  });
}

class _PackagingBuilderDialogState extends State<PackagingBuilderDialog> {
  final List<_PackagingUnitDraft> _units = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeUnits();
  }

  void _initializeUnits() {
    final p = widget.product;
    if (p.customUnitMultipliers != null && p.customUnitMultipliers!.isNotEmpty) {
      p.customUnitMultipliers!.forEach((name, mult) {
        final price = p.customUnitPricesPaise?[name] ?? (p.piecePricePaise * mult);
        _units.add(_PackagingUnitDraft(
          unitName: name,
          multiplierToBase: mult,
          isBaseUnit: mult == 1,
          allowLooseSale: true,
          canBuy: true,
          canSell: true,
          wholesalePricePaise: price,
          mrpPaise: (p.mrpRupees * 100 * mult).round(),
        ));
      });
    } else {
      // Default 3-tier
      _units.add(_PackagingUnitDraft(
        unitName: 'piece',
        multiplierToBase: 1,
        isBaseUnit: true,
        allowLooseSale: true,
        wholesalePricePaise: p.piecePricePaise,
        mrpPaise: (p.mrpRupees * 100).round(),
      ));
      if (p.stripQty > 1) {
        _units.add(_PackagingUnitDraft(
          unitName: 'strip',
          multiplierToBase: p.stripQty,
          isBaseUnit: false,
          allowLooseSale: true,
          wholesalePricePaise: p.priceForUnit(OrderUnit.strip),
          mrpPaise: (p.mrpRupees * 100 * p.stripQty).round(),
        ));
      }
      if (p.boxQty > 1) {
        _units.add(_PackagingUnitDraft(
          unitName: 'box',
          multiplierToBase: p.boxQty,
          isBaseUnit: false,
          allowLooseSale: true,
          wholesalePricePaise: p.priceForUnit(OrderUnit.box),
          mrpPaise: (p.mrpRupees * 100 * p.boxQty).round(),
        ));
      }
    }
    _sortUnits();
  }

  void _sortUnits() {
    _units.sort((a, b) => a.multiplierToBase.compareTo(b.multiplierToBase));
  }

  String _buildLivePreview() {
    if (_units.isEmpty) return 'No packaging units configured.';
    final sortedDesc = List<_PackagingUnitDraft>.from(_units)
      ..sort((a, b) => b.multiplierToBase.compareTo(a.multiplierToBase));
    final base = _units.firstWhere(
      (u) => u.isBaseUnit,
      orElse: () => _units.first,
    );

    final parts = <String>[];
    for (var u in sortedDesc) {
      if (u == base) {
        parts.add('1 ${u.unitName.toUpperCase()}');
      } else {
        parts.add('1 ${u.unitName.toUpperCase()} = ${u.multiplierToBase} ${base.unitName.toUpperCase()}s');
      }
    }
    return parts.join('  |  ');
  }

  void _addUnitRow() {
    setState(() {
      _units.add(_PackagingUnitDraft(
        unitName: 'unit_${_units.length + 1}',
        multiplierToBase: (_units.isEmpty ? 1 : _units.last.multiplierToBase * 2),
        isBaseUnit: _units.isEmpty,
        allowLooseSale: true,
        wholesalePricePaise: widget.product.piecePricePaise * 2,
        mrpPaise: (widget.product.mrpRupees * 100 * 2).round(),
      ));
      _sortUnits();
    });
  }

  void _removeUnitRow(int index) {
    if (_units.length <= 1) {
      setState(() => _errorMessage = 'At least 1 base unit is required.');
      return;
    }
    setState(() {
      _units.removeAt(index);
      if (!_units.any((u) => u.isBaseUnit)) {
        _units.first.isBaseUnit = true;
        _units.first.multiplierToBase = 1;
      }
      _errorMessage = null;
    });
  }

  Future<void> _savePackaging() async {
    final hasBase = _units.any((u) => u.isBaseUnit && u.multiplierToBase == 1);
    if (!hasBase) {
      setState(() => _errorMessage = 'One unit must be the Base Unit with multiplier 1.');
      return;
    }

    for (var u in _units) {
      if (u.unitName.trim().isEmpty) {
        setState(() => _errorMessage = 'Unit name cannot be empty.');
        return;
      }
      if (u.multiplierToBase < 1) {
        setState(() => _errorMessage = 'Multiplier must be at least 1.');
        return;
      }
      if (u.wholesalePricePaise < 0) {
        setState(() => _errorMessage = 'Wholesale price cannot be negative.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final packagingUnits = _units.map((u) {
        return ProductPackagingUnit(
          id: 'unit_${widget.product.id}_${u.unitName.toLowerCase().trim()}',
          productId: widget.product.id,
          unitName: u.unitName.toLowerCase().trim(),
          multiplierToBase: u.multiplierToBase,
          isBaseUnit: u.isBaseUnit,
          allowLooseSale: u.allowLooseSale,
          canBuy: u.canBuy,
          canSell: u.canSell,
          wholesalePricePaise: u.wholesalePricePaise,
          mrpPaise: u.mrpPaise,
        );
      }).toList();

      final key = 'pkg_edit_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}';
      await widget.api.updateProductUnitsDurable(
        productId: widget.product.id,
        units: packagingUnits,
        idempotencyKey: key,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Packaging units and wholesale pricing saved!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.layers_rounded, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Packaging & Multi-Tier Pricing Setup',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Live Preview Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _buildLivePreview(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _units.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (ctx, idx) {
                    final item = _units[idx];
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.isBaseUnit ? const Color(0xFFEFF6FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: item.unitName,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit Name (e.g. Crate, Box, Bottle)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    item.unitName = val;
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: item.multiplierToBase.toString(),
                                  keyboardType: TextInputType.number,
                                  enabled: !item.isBaseUnit,
                                  decoration: const InputDecoration(
                                    labelText: 'Multiplier (Base = 1)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    item.multiplierToBase = int.tryParse(val) ?? 1;
                                    setState(() {});
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeUnitRow(idx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: (item.wholesalePricePaise / 100.0).toStringAsFixed(2),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Wholesale Price (₹)',
                                    prefixText: '₹ ',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    final rupees = double.tryParse(val) ?? 0.0;
                                    item.wholesalePricePaise = (rupees * 100).round();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: (item.mrpPaise / 100.0).toStringAsFixed(2),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'MRP (₹)',
                                    prefixText: '₹ ',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    final rupees = double.tryParse(val) ?? 0.0;
                                    item.mrpPaise = (rupees * 100).round();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              ChoiceChip(
                                label: Text(item.isBaseUnit ? 'Base Unit (Pieces/Bottles)' : 'Bulk / Tier Unit'),
                                selected: item.isBaseUnit,
                                onSelected: (sel) {
                                  if (sel) {
                                    for (var u in _units) {
                                      u.isBaseUnit = false;
                                    }
                                    item.isBaseUnit = true;
                                    item.multiplierToBase = 1;
                                    setState(() {});
                                  }
                                },
                              ),
                              const Spacer(),
                              Checkbox(
                                value: item.allowLooseSale,
                                onChanged: (v) {
                                  setState(() => item.allowLooseSale = v ?? true);
                                },
                              ),
                              const Text('Loose sale allowed', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: SwitchListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Can Sell (बिक्री)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  value: item.canSell,
                                  onChanged: (val) {
                                    setState(() => item.canSell = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SwitchListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Can Buy / Inward (खरीद)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  value: item.canBuy,
                                  onChanged: (val) {
                                    setState(() => item.canBuy = val);
                                  },
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
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Another Unit Tier'),
                onPressed: _addUnitRow,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isLoading ? null : _savePackaging,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Packaging Hierarchy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
