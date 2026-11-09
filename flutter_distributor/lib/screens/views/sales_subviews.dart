import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/outbox/outbox_models.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import 'add_shop_sheet.dart';

/// 1. Sales Order Booking View: Full order taking experience.
class SalesOrderBookingView extends StatefulWidget {
  final ApiService api;
  final Function(int targetTab)? onNavigateTab;

  const SalesOrderBookingView({
    super.key,
    required this.api,
    this.onNavigateTab,
  });

  @override
  State<SalesOrderBookingView> createState() => _SalesOrderBookingViewState();
}

class _SalesOrderBookingViewState extends State<SalesOrderBookingView> {
  String _selectedCategory = 'All';
  RetailerShop? _activeShop;
  final Map<String, OrderUnit> _selectedUnits = {};
  final Map<String, int> _selectedQuantities = {};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<ProductItem> get _orderAgainProducts {
    if (_activeShop == null) return [];
    final pastOrders = widget.api.orders.where((o) => o.shopId == _activeShop!.id);
    final productIds = pastOrders.expand((o) => o.items).map((i) => i.product.id).toSet();
    return widget.api.products.where((p) => productIds.contains(p.id)).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final cats = <String>{'All'};
    for (final p in widget.api.products) {
      if (p.category.trim().isNotEmpty) cats.add(p.category.trim());
    }
    return cats.toList();
  }

  @override
  void initState() {
    super.initState();
    if (widget.api.retailers.isNotEmpty) {
      _activeShop = widget.api.retailers.first;
    }
  }

  OrderUnit _getUnit(ProductItem p) => _selectedUnits[p.id] ?? OrderUnit.box;
  int _getQty(ProductItem p) => _selectedQuantities[p.id] ?? 1;

  void _showOrderPreviewSafetySheet() {
    if (_activeShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a retailer first.')),
      );
      return;
    }

    final cartItems = widget.api.cart.values.toList();
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your order cart is empty. Add products to proceed.')),
      );
      return;
    }

    final checkoutIdempotencyKey = generateUuidV4();
    bool isSubmitting = false;

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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review Booking Order',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                        ),
                        Text(
                          'Retailer: ${_activeShop!.name} • Local Outbox',
                          style: const TextStyle(fontSize: 12, color: AirbnbTheme.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.coral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${cartItems.length} SKUs',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AirbnbTheme.coral),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Text(
                  '[NOTE] Offline in-memory booking preview. Physical godown and van stock remain unchanged until warehouse pick & pack.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFF57F17), fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cartItems.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (ctx, idx) {
                    final item = cartItems[idx];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                '${item.quantity} ${item.unit.label} (${item.totalPieces} pcs)',
                                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${item.totalRupees.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal (Taxable):', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                  Text('₹${widget.api.cartTaxableRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total GST (CGST + SGST):', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                  Text('₹${widget.api.cartTotalGstRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total Payable:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                  Text(
                    '₹${widget.api.cartTotalRupees.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AirbnbTheme.coral),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : () async {
                        setSheetState(() => isSubmitting = true);
                        try {
                          final order = await widget.api.confirmOrderDurable(
                            shopId: _activeShop!.id,
                            paymentMode: 'Credit',
                            checkoutIdempotencyKey: checkoutIdempotencyKey,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('[LOCAL OUTBOX] Order ${order.orderNumber} booked on Credit for ${_activeShop!.name}'),
                                backgroundColor: AirbnbTheme.coral,
                                action: SnackBarAction(
                                  label: 'Share (शेयर)',
                                  textColor: Colors.white,
                                  // ignore: deprecated_member_use
                                  onPressed: () => Share.share(widget.api.generateWhatsAppOrderShareText(order)),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setSheetState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Order failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AirbnbTheme.coral),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Book on Khata (Credit)', style: TextStyle(fontWeight: FontWeight.w700, color: AirbnbTheme.coral)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        setSheetState(() => isSubmitting = true);
                        try {
                          final order = await widget.api.confirmOrderDurable(
                            shopId: _activeShop!.id,
                            paymentMode: 'COD',
                            checkoutIdempotencyKey: checkoutIdempotencyKey,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('[LOCAL OUTBOX] Order ${order.orderNumber} booked for COD for ${_activeShop!.name}'),
                                backgroundColor: AirbnbTheme.success,
                                action: SnackBarAction(
                                  label: 'Share (शेयर)',
                                  textColor: Colors.white,
                                  // ignore: deprecated_member_use
                                  onPressed: () => Share.share(widget.api.generateWhatsAppOrderShareText(order)),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setSheetState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Order failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Book COD', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
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
    final filteredProducts = widget.api.products.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.hindiName.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();

    return Column(
      children: [
        // 1. RETAILER SELECTOR BAR
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: AirbnbTheme.cardBg,
          child: Row(
            children: [
              const Icon(Icons.storefront, size: 20, color: AirbnbTheme.dark),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RetailerShop>(
                    value: _activeShop,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: widget.api.retailers.map((shop) {
                      return DropdownMenuItem<RetailerShop>(
                        value: shop,
                        child: Text(
                          '${shop.name} (${shop.area})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      );
                    }).toList(),
                    onChanged: (s) {
                      if (s != null) setState(() => _activeShop = s);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // 1.5 FIXED SEARCH BAR (English, Hindi, SKU)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AirbnbTheme.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: TextField(
              key: const ValueKey('sales_order_search_field'),
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search product, हिन्दी नाम, or SKU...',
                hintStyle: TextStyle(fontSize: 12, color: AirbnbTheme.grey),
                prefixIcon: Icon(Icons.search, size: 18, color: AirbnbTheme.grey),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),

        // 1.8 ORDER AGAIN SHELF
        if (_orderAgainProducts.isNotEmpty) ...[
          Container(
            key: const ValueKey('order_again_shelf'),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Again ⚡',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _orderAgainProducts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final p = _orderAgainProducts[i];
                      return ActionChip(
                        avatar: const Icon(Icons.refresh, size: 14, color: AirbnbTheme.coral),
                        label: Text('${p.name} (+1 Peti)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        backgroundColor: AirbnbTheme.cardBg,
                        side: const BorderSide(color: AirbnbTheme.border),
                        onPressed: () {
                          widget.api.addToCart(p, OrderUnit.box, 1);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added 1 Box of ${p.name} to cart!'),
                              duration: const Duration(milliseconds: 700),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        // 2. CATEGORY HORIZONTAL CHIPS
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
                  selectedColor: AirbnbTheme.coral,
                  backgroundColor: AirbnbTheme.cardBg,
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

        // 3. PRODUCT LISTING FOR ORDER BOOKING
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
            itemCount: filteredProducts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final p = filteredProducts[idx];
              final currentUnit = _getUnit(p);
              final currentQty = _getQty(p);

              // Calculate rate per unit using data-driven wholesale pricing
              final unitRate = p.priceRupeesForUnit(currentUnit);
              final lineTotal = unitRate * currentQty;

              return Container(
                padding: const EdgeInsets.all(12),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AirbnbTheme.dark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${p.hindiName} • MRP ₹${p.mrpRupees.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: p.isOutOfStock
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : (p.isLowStock
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : const Color(0xFFF0FDF4)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: p.isOutOfStock
                                      ? Colors.red.shade300
                                      : (p.isLowStock
                                          ? Colors.orange.shade300
                                          : const Color(0xFF86EFAC)),
                                ),
                              ),
                              child: Text(
                                p.isOutOfStock
                                    ? '✕ Out of Stock (0 Bxs)'
                                    : 'Godown: ${p.godownStockBoxes} Bxs (${widget.api.availableGodownBoxes(p.id)} avail)',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.isOutOfStock
                                      ? Colors.red.shade800
                                      : (p.isLowStock
                                          ? Colors.orange.shade800
                                          : const Color(0xFF166534)),
                                ),
                              ),
                            ),
                            if (p.carStockBoxes > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Van: ${p.carStockBoxes} Bxs',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AirbnbTheme.grey),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Unit selector pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('Unit: ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
                          const SizedBox(width: 4),
                          _buildUnitChip(p, OrderUnit.box, 'Box (${p.boxQty}p)'),
                          const SizedBox(width: 5),
                          if (p.stripQty > 1) ...[
                            _buildUnitChip(p, OrderUnit.strip, 'Strip (${p.stripQty}p)'),
                            const SizedBox(width: 5),
                          ],
                          _buildUnitChip(p, OrderUnit.piece, 'Pcs'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quantity +/- and Quick-qty chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: currentQty > 1
                                  ? () => setState(() => _selectedQuantities[p.id] = currentQty - 1)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                key: ValueKey('qty_display_${p.id}'),
                                '$currentQty',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _selectedQuantities[p.id] = currentQty + 1),
                              icon: const Icon(Icons.add_circle_outline, size: 22, color: AirbnbTheme.coral),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            for (final addCount in [1, 5, 10])
                              InkWell(
                                key: ValueKey('quick_qty_${addCount}_${p.id}'),
                                onTap: () => setState(() => _selectedQuantities[p.id] = currentQty + addCount),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AirbnbTheme.lightGrey,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AirbnbTheme.border),
                                  ),
                                  child: Text('+$addCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '₹${unitRate.toStringAsFixed(2)} / ${currentUnit.shortCode} • Total: ₹${lineTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showMixedUnitOrderSheet(p),
                              icon: const Icon(Icons.layers_outlined, size: 12, color: AirbnbTheme.coral),
                              label: const Text('Combo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AirbnbTheme.coral)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: AirbnbTheme.coral),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton.icon(
                              onPressed: () {
                                widget.api.addToCart(p, currentUnit, currentQty);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added $currentQty ${currentUnit.shortCode} of ${p.name} to cart!'),
                                    duration: const Duration(milliseconds: 900),
                                    backgroundColor: AirbnbTheme.dark,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_shopping_cart, size: 13),
                              label: const Text('Add', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AirbnbTheme.coral,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
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

        // 4. FLOATING BOTTOM CART BAR
        if (widget.api.cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AirbnbTheme.dark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.api.cart.length} SKUs in Cart',
                          style: const TextStyle(color: Color(0xFFB2BEC3), fontSize: 11),
                        ),
                        Text(
                          '₹${widget.api.cartTotalRupees.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _showOrderPreviewSafetySheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Review Order →', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUnitChip(ProductItem p, OrderUnit unit, String label) {
    final isSel = _getUnit(p) == unit;
    return GestureDetector(
      onTap: () => setState(() => _selectedUnits[p.id] = unit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSel ? AirbnbTheme.dark : AirbnbTheme.lightGrey,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
            color: isSel ? Colors.white : AirbnbTheme.dark,
          ),
        ),
      ),
    );
  }

  void _showMixedUnitOrderSheet(ProductItem product) {
    int boxCount = 1;
    int stripCount = 1;
    int pieceCount = 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final boxPrice = product.priceRupeesForUnit(OrderUnit.box);
          final stripPrice = product.priceRupeesForUnit(OrderUnit.strip);
          final piecePrice = product.priceRupeesForUnit(OrderUnit.piece);

          final totalPieces = (boxCount * product.boxQty) + (stripCount * product.stripQty) + pieceCount;
          final totalCostRupees = (boxCount * boxPrice) + (stripCount * stripPrice) + (pieceCount * piecePrice);

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AirbnbTheme.border, borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Multi-Unit Mixed Order: ${product.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                          Text('${product.hindiName} • MRP ₹${product.mrpRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('Godown: ${product.godownStockBoxes} Boxes', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Boxes Stepper Row
                _buildMixedStepperRow(
                  title: 'Boxes (${product.boxQty} pcs / box)',
                  priceSubtitle: '₹${boxPrice.toStringAsFixed(2)} / Box',
                  count: boxCount,
                  onMinus: boxCount > 0 ? () => setSheetState(() => boxCount--) : null,
                  onPlus: () => setSheetState(() => boxCount++),
                ),
                const Divider(height: 16),

                // 2. Strips Stepper Row
                _buildMixedStepperRow(
                  title: 'Strips / Ladi (${product.stripQty} pcs / strip)',
                  priceSubtitle: '₹${stripPrice.toStringAsFixed(2)} / Strip',
                  count: stripCount,
                  onMinus: stripCount > 0 ? () => setSheetState(() => stripCount--) : null,
                  onPlus: () => setSheetState(() => stripCount++),
                ),
                const Divider(height: 16),

                // 3. Loose Pieces Stepper Row
                _buildMixedStepperRow(
                  title: 'Loose Pieces (1 pc)',
                  priceSubtitle: '₹${piecePrice.toStringAsFixed(2)} / Piece',
                  count: pieceCount,
                  onMinus: pieceCount > 0 ? () => setSheetState(() => pieceCount--) : null,
                  onPlus: () => setSheetState(() => pieceCount++),
                ),
                const SizedBox(height: 16),

                // Live Summary Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AirbnbTheme.lightGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AirbnbTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Calculated Quantity:', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                          Text(
                            '$boxCount Box + $stripCount Strip + $pieceCount Pcs ($totalPieces pieces)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total (GST Incl.):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                          Text('₹${totalCostRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AirbnbTheme.coral)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: totalPieces == 0
                        ? null
                        : () {
                            widget.api.addMixedUnitsToCart(
                              product,
                              boxes: boxCount,
                              strips: stripCount,
                              pieces: pieceCount,
                            );
                            Navigator.pop(ctx);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added mixed combo: $boxCount Box, $stripCount Strip, $pieceCount Pcs ($totalPieces pcs) to cart!'),
                                backgroundColor: AirbnbTheme.dark,
                              ),
                            );
                          },
                    child: const Text('Add Multi-Unit Combo to Cart (कार्ट में जोड़ें)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMixedStepperRow({
    required String title,
    required String priceSubtitle,
    required int count,
    required VoidCallback? onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
            Text(priceSubtitle, style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 22),
              onPressed: onMinus,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 22, color: AirbnbTheme.coral),
              onPressed: onPlus,
            ),
          ],
        ),
      ],
    );
  }
}

/// 2. Sales Retailers View: Beat Retailers Directory, Zomato Map Toggle & Visit Check-in.
class SalesRetailersView extends StatefulWidget {
  final ApiService api;
  final Function(int targetTab)? onNavigateTab;

  const SalesRetailersView({
    super.key,
    required this.api,
    this.onNavigateTab,
  });

  @override
  State<SalesRetailersView> createState() => _SalesRetailersViewState();
}

class _SalesRetailersViewState extends State<SalesRetailersView> {
  String _selectedRouteFilter = 'ALL'; // 'ALL', 'route_sardarpura_02', 'route_nai_sadak_01'
  String _sortBy = 'NEAREST'; // 'NEAREST', 'SEQUENCE', 'PENDING'
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  Timer? _stopwatchTimer;

  // Salesperson's active reference GPS coordinate in Jodhpur commercial district
  static const double _repLat = 26.2850;
  static const double _repLng = 73.0180;

  @override
  void initState() {
    super.initState();
    // 1-second ticker to update active visit stopwatch in real-time
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.api.activeVisitShopId != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  double _getShopDistance(RetailerShop shop) {
    if (shop.latitude == null || shop.longitude == null) return 999999.0;
    return ApiService.calculateDistanceMeters(
      _repLat,
      _repLng,
      shop.latitude!,
      shop.longitude!,
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 999999) return 'Distance unknown';
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  List<RetailerShop> _getFilteredAndSortedShops() {
    var list = List<RetailerShop>.from(widget.api.retailers);

    // 1. Filter by Beat Route
    if (_selectedRouteFilter != 'ALL') {
      list = list.where((s) => s.routeId == _selectedRouteFilter).toList();
    }

    // 2. Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.area.toLowerCase().contains(q) ||
            s.ownerName.toLowerCase().contains(q) ||
            s.phone.contains(q);
      }).toList();
    }

    // 3. Sort
    if (_sortBy == 'NEAREST') {
      list.sort((a, b) => _getShopDistance(a).compareTo(_getShopDistance(b)));
    } else if (_sortBy == 'PENDING') {
      list.sort((a, b) {
        int scoreA = a.isCheckedIn ? 0 : (!a.visitedToday && !a.isSkipped ? 1 : 2);
        int scoreB = b.isCheckedIn ? 0 : (!b.visitedToday && !b.isSkipped ? 1 : 2);
        if (scoreA != scoreB) return scoreA.compareTo(scoreB);
        return _getShopDistance(a).compareTo(_getShopDistance(b));
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final allShops = widget.api.retailers;
    final displayShops = _getFilteredAndSortedShops();
    final activeShop = widget.api.activeVisitShop;

    // Closest unvisited & un-skipped shop for Zomato-style Next Stop recommendation
    final pendingShops = displayShops.where((s) => !s.visitedToday && !s.isSkipped && !s.isCheckedIn).toList();
    final nextRecommendedShop = pendingShops.isNotEmpty ? pendingShops.first : null;

    return Column(
      children: [
        // Active Visit Floating Banner (If salesperson is currently checked into a shop)
        if (activeShop != null) _buildActiveVisitBanner(activeShop),

        // 1. Beat Selection Filter Tabs
        _buildBeatFilterChips(),

        // 2. Search & Sort Bar
        _buildSearchAndSortBar(displayShops.length, allShops.length),

        // 3. Next Recommended Stop Banner (Zomato style sequence)
        if (nextRecommendedShop != null && activeShop == null)
          _buildNextStopRecommendationCard(nextRecommendedShop),
        // 4. Shops List
        Expanded(
          child: displayShops.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: displayShops.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final shop = displayShops[idx];
                    return _buildShopCard(shop, idx + 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActiveVisitBanner(RetailerShop shop) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B894), Color(0xFF00897B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B894).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'ACTIVE VISIT IN PROGRESS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  shop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '⏱️ Time Spent: ${shop.activeVisitFormatted}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              widget.api.selectShop(shop);
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(1); // Book Order tab
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00897B),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Book Order', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () => _handleCheckOut(shop),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Check-Out', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildBeatFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _buildFilterChip('ALL', 'All Shops (${widget.api.retailers.length})'),
          const SizedBox(width: 8),
          _buildFilterChip(
            'route_sardarpura_02',
            'Sardarpura Beat (${widget.api.retailers.where((s) => s.routeId == 'route_sardarpura_02').length})',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'route_nai_sadak_01',
            'Nai Sadak Beat (${widget.api.retailers.where((s) => s.routeId == 'route_nai_sadak_01').length})',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String routeKey, String label) {
    final isSelected = _selectedRouteFilter == routeKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedRouteFilter = routeKey),
      selectedColor: AirbnbTheme.dark,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? AirbnbTheme.dark : AirbnbTheme.border),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : AirbnbTheme.dark,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSearchAndSortBar(int filteredCount, int totalCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search shop or owner...',
                hintStyle: const TextStyle(fontSize: 12.5, color: AirbnbTheme.grey),
                prefixIcon: const Icon(Icons.search, size: 18, color: AirbnbTheme.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AirbnbTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AirbnbTheme.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sort Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.sort, size: 18, color: AirbnbTheme.dark),
                items: const [
                  DropdownMenuItem(value: 'NEAREST', child: Text('📍 Nearest', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  DropdownMenuItem(value: 'PENDING', child: Text('⏱️ Pending', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  DropdownMenuItem(value: 'SEQUENCE', child: Text('🚶 Route Stop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Add Shop Button
          ElevatedButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final newShop = await AddShopSheet.show(context, api: widget.api);
              if (newShop != null && mounted) {
                setState(() {});
                messenger.showSnackBar(
                  SnackBar(content: Text('Added ${newShop.name} successfully!')),
                );
              }
            },
            icon: const Icon(Icons.add_business_outlined, size: 16),
            label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbTheme.coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStopRecommendationCard(RetailerShop shop) {
    final dist = _getShopDistance(shop);
    final distStr = _formatDistance(dist);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.navigation_outlined, color: Color(0xFF16A34A), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT RECOMMENDED STOP • $distStr away',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16A34A),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  shop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AirbnbTheme.dark,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _handleCheckIn(shop),
            icon: const Icon(Icons.login, size: 14),
            label: const Text('Check In', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF16A34A),
              side: const BorderSide(color: Color(0xFF16A34A)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(RetailerShop shop, int stopNum) {
    final isCheckedIn = shop.isCheckedIn;
    final dist = _getShopDistance(shop);
    final distStr = _formatDistance(dist);

    Color cardBorderColor = AirbnbTheme.border;
    if (isCheckedIn) {
      cardBorderColor = const Color(0xFF00B894);
    } else if (shop.isSkipped) {
      cardBorderColor = Colors.orange.shade300;
    } else if (shop.visitedToday) {
      cardBorderColor = Colors.blueGrey.shade200;
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isCheckedIn ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cardBorderColor,
          width: isCheckedIn ? 1.8 : 1.0,
        ),
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
          // Top Row: Stop Index, Shop Name, Class, and Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Stop Number Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AirbnbTheme.dark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$stopNum',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              _getCategoryIcon(shop.shopType),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AirbnbTheme.dark,
                      ),
                    ),
                    Text(
                      '${shop.ownerName} • ${shop.phone}',
                      style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                    ),
                  ],
                ),
              ),
              // Class Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getClassBadgeColor(shop.classType).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _getClassBadgeColor(shop.classType).withValues(alpha: 0.3)),
                ),
                child: Text(
                  shop.classType,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _getClassBadgeColor(shop.classType),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AirbnbTheme.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'delete') {
                    _showDeleteShopDialog(context, shop);
                  } else if (val == 'skip') {
                    _showSkipShopDialog(context, shop);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'skip',
                    child: Row(
                      children: [
                        Icon(Icons.skip_next_outlined, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Skip Shop with Reason', style: TextStyle(fontSize: 13, color: Colors.orange)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete / Remove Shop', style: TextStyle(fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Location details & Distance Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AirbnbTheme.lightGrey,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place_outlined, size: 12, color: AirbnbTheme.dark),
                    const SizedBox(width: 3),
                    Text(
                      distStr,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  shop.area,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                ),
              ),
              if (shop.routeId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    shop.routeId == 'route_sardarpura_02' ? 'Sardarpura' : 'Nai Sadak',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Time Spent & Visit Status Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCheckedIn
                  ? const Color(0xFF00B894).withValues(alpha: 0.12)
                  : (shop.isSkipped
                      ? Colors.orange.shade50
                      : (shop.visitedToday ? Colors.blueGrey.shade50 : AirbnbTheme.lightGrey)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isCheckedIn
                      ? Icons.timer
                      : (shop.isSkipped
                          ? Icons.warning_amber_rounded
                          : (shop.visitedToday ? Icons.check_circle_outline : Icons.schedule)),
                  size: 14,
                  color: isCheckedIn
                      ? const Color(0xFF00897B)
                      : (shop.isSkipped
                          ? Colors.orange.shade800
                          : (shop.visitedToday ? Colors.teal.shade800 : AirbnbTheme.grey)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isCheckedIn
                        ? '🟢 CHECKED IN • Time Spent: ${shop.activeVisitFormatted}'
                        : (shop.isSkipped
                            ? '⚠️ SKIPPED • Reason: ${shop.skipReason ?? "No Orders"}'
                            : (shop.visitedToday
                                ? '✓ VISITED TODAY • Time Spent: ${shop.totalTimeSpentFormatted}'
                                : '⏱️ Not Visited (0m spent today)')),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isCheckedIn
                          ? const Color(0xFF00897B)
                          : (shop.isSkipped
                              ? Colors.orange.shade900
                              : (shop.visitedToday ? Colors.teal.shade900 : AirbnbTheme.grey)),
                    ),
                  ),
                ),
                if (shop.todayOrderTotalPaise > 0) ...[
                  Text(
                    '₹${(shop.todayOrderTotalPaise / 100).toStringAsFixed(0)} Booked',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AirbnbTheme.coral),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action Buttons: Check-In/Check-Out, Book Order, Skip Shop
          Row(
            children: [
              // Check-In / Check-Out
              Expanded(
                child: isCheckedIn
                    ? ElevatedButton.icon(
                        onPressed: () => _handleCheckOut(shop),
                        icon: const Icon(Icons.logout, size: 15),
                        label: const Text('Check-Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _handleCheckIn(shop),
                        icon: const Icon(Icons.login, size: 15),
                        label: Text(shop.visitedToday ? 'Re-Visit' : 'Check-In'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbTheme.dark,
                          side: const BorderSide(color: AirbnbTheme.dark),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              // Book Order
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!shop.isCheckedIn) {
                      widget.api.startShopVisit(shop.id);
                    }
                    widget.api.selectShop(shop);
                    if (widget.onNavigateTab != null) {
                      widget.onNavigateTab!(1); // Go to Order Booking tab
                    }
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 15),
                  label: const Text('Book Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbTheme.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Skip Shop Button
              IconButton(
                onPressed: () => _showSkipShopDialog(context, shop),
                icon: const Icon(Icons.skip_next_outlined, size: 20),
                tooltip: 'Skip Shop',
                color: Colors.orange.shade800,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.orange.shade200),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleCheckIn(RetailerShop shop) {
    widget.api.startShopVisit(shop.id);
    if (shop.isSkipped) {
      shop.clearSkip();
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🟢 Checked into ${shop.name}! Stopwatch started.'),
        backgroundColor: const Color(0xFF00897B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleCheckOut(RetailerShop shop) {
    final elapsedSecs = widget.api.endShopVisit(shop.id);
    setState(() {});

    final durationFormatted = RetailerShop.formatDuration(elapsedSecs);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF00897B), size: 24),
            SizedBox(width: 8),
            Text('Visit Completed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully checked out from ${shop.name}.', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AirbnbTheme.lightGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Time Spent This Visit:', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                      Text(durationFormatted, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Today Time:', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                      Text(shop.totalTimeSpentFormatted, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Orders Booked:', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                      Text('₹${(shop.todayOrderTotalPaise / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AirbnbTheme.coral)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbTheme.dark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.store_outlined, size: 48, color: AirbnbTheme.grey),
          SizedBox(height: 10),
          Text(
            'No shops found matching filter.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AirbnbTheme.grey),
          ),
        ],
      ),
    );
  }

  Widget _getCategoryIcon(String shopType) {
    IconData icon;
    Color color;
    switch (shopType.toUpperCase()) {
      case 'WHOLESALE':
        icon = Icons.inventory_2_outlined;
        color = const Color(0xFF6C5CE7);
        break;
      case 'FARSAN_NAMKEEN':
      case 'FARSAN':
        icon = Icons.bakery_dining_outlined;
        color = const Color(0xFFD35400);
        break;
      case 'SUPERMARKET':
        icon = Icons.storefront_outlined;
        color = const Color(0xFF27AE60);
        break;
      default:
        icon = Icons.shopping_basket_outlined;
        color = AirbnbTheme.coral;
    }
    return Icon(icon, size: 18, color: color);
  }

  void _showSkipShopDialog(BuildContext context, RetailerShop shop) {
    String selectedReason = 'Shop Closed';
    final searchReasonCtrl = TextEditingController();

    final presetReasons = [
      'Next Week',
      'No Orders',
      'Shop Closed',
      'Vehicle Breakdown',
      'Others',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RouteX | Sales Order',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.jodhpurBlue),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reason For Skipping : ${shop.name}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchReasonCtrl,
                    onChanged: (val) {
                      setDialogState(() {
                        if (val.isNotEmpty) selectedReason = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search Reason',
                      hintStyle: const TextStyle(fontSize: 12, color: AirbnbTheme.grey),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...presetReasons.map((reason) {
                    final isChecked = selectedReason == reason;
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: isChecked,
                      title: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
                          color: isChecked ? AirbnbTheme.jodhpurBlue : AirbnbTheme.dark,
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedReason = reason;
                          searchReasonCtrl.text = reason;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CLOSE', style: TextStyle(color: AirbnbTheme.grey, fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.api.skipShopVisit(shop.id, selectedReason);
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Skipped "${shop.name}" ($selectedReason)'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbTheme.jodhpurBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Skip Shop', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getClassBadgeColor(String classType) {
    switch (classType.toUpperCase()) {
      case 'CLASS_A':
        return Colors.green.shade700;
      case 'CLASS_B':
        return AirbnbTheme.jodhpurBlue;
      case 'CLASS_C':
        return Colors.orange.shade800;
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  void _showDeleteShopDialog(BuildContext context, RetailerShop shop) {
    final isAssigned = widget.api.isAssignedBeatShop(shop.id);
    if (isAssigned) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.shield_outlined, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Protected Shop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Text(
            '${shop.name} is an assigned beat shop assigned by the distributor owner. '
            'Sales representatives cannot delete assigned distributor shops.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Shop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text('Are you sure you want to delete "${shop.name}" from your shop roster?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await widget.api.deleteRetailer(shop.id);
              if (mounted) {
                setState(() {});
                messenger.showSnackBar(
                  SnackBar(content: Text('Deleted "${shop.name}"')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// 3. Sales Products View: FMCG Price Book & Catalogue.
class SalesProductsView extends StatefulWidget {
  final ApiService api;
  const SalesProductsView({super.key, required this.api});

  @override
  State<SalesProductsView> createState() => _SalesProductsViewState();
}

class _SalesProductsViewState extends State<SalesProductsView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final prods = widget.api.products.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) || p.hindiName.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: AppStrings.searchProductsHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: AirbnbTheme.lightGrey,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: prods.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final p = prods[idx];
              final piecePrice = p.piecePricePaise / 100.0;
              final stripPrice = piecePrice * p.stripQty;
              final boxPrice = piecePrice * p.boxQty;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AirbnbTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AirbnbTheme.dark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: p.isOutOfStock
                                ? Colors.red.withValues(alpha: 0.1)
                                : (p.isLowStock
                                    ? Colors.orange.withValues(alpha: 0.1)
                                    : const Color(0xFFF0FDF4)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: p.isOutOfStock
                                  ? Colors.red.shade300
                                  : (p.isLowStock
                                      ? Colors.orange.shade300
                                      : const Color(0xFF86EFAC)),
                            ),
                          ),
                          child: Text(
                            p.isOutOfStock
                                ? 'Out of Stock'
                                : 'Godown: ${p.godownStockBoxes} Bxs${p.carStockBoxes > 0 ? " • Van: ${p.carStockBoxes} Bxs" : ""}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: p.isOutOfStock
                                  ? Colors.red.shade800
                                  : (p.isLowStock
                                      ? Colors.orange.shade800
                                      : const Color(0xFF166534)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${p.hindiName} • ${p.category} • MRP ₹${p.mrpRupees.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AirbnbTheme.cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Wholesale Piece', style: TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                              Text('₹${piecePrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          Column(
                            children: [
                              Text('Strip (${p.stripQty}p)', style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                              Text('₹${stripPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          Column(
                            children: [
                              Text('Box (${p.boxQty}p)', style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                              Text('₹${boxPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AirbnbTheme.coral)),
                            ],
                          ),
                        ],
                      ),
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

/// 4. Sales Visits View: Beat Visits & Stopwatch Tracker.
class SalesVisitsView extends StatelessWidget {
  final ApiService api;
  const SalesVisitsView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final retailers = api.retailers;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
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
                    const Text('Total Beat Time Logged', style: TextStyle(color: Color(0xFFB2BEC3), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      api.totalBeatTimeSpentFormatted,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('GPS Geofence OK', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Retailer Visit History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...retailers.map((shop) {
            final isCheckedIn = shop.isCheckedIn;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isCheckedIn ? AirbnbTheme.coral : AirbnbTheme.border),
              ),
              child: Row(
                children: [
                  Icon(
                    isCheckedIn ? Icons.timer : (shop.visitedToday ? Icons.check_circle : Icons.schedule),
                    color: isCheckedIn ? AirbnbTheme.coral : (shop.visitedToday ? AirbnbTheme.success : AirbnbTheme.grey),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${shop.area} • ${shop.visitCountToday} visit(s) today', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                      ],
                    ),
                  ),
                  Text(
                    isCheckedIn ? shop.activeVisitFormatted : shop.totalTimeSpentFormatted,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isCheckedIn ? AirbnbTheme.coral : AirbnbTheme.dark,
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
}
