import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/outbox/outbox_models.dart';
import '../../l10n/app_strings.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import 'sales_route_map_view.dart';

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
  int _viewMode = 0; // 0 = List View, 1 = Route Map View

  @override
  Widget build(BuildContext context) {
    if (_viewMode == 1) {
      return Column(
        children: [
          _buildViewModeToggle(),
          Expanded(
            child: SalesRouteMapView(
              api: widget.api,
              onNavigateTab: widget.onNavigateTab,
            ),
          ),
        ],
      );
    }

    final retailers = widget.api.retailers;

    return Column(
      children: [
        _buildViewModeToggle(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: retailers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final shop = retailers[idx];
              final isCheckedIn = shop.isCheckedIn;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCheckedIn ? AirbnbTheme.coral : AirbnbTheme.border,
                    width: isCheckedIn ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            shop.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                          ),
                        ),
                        // Class Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCheckedIn
                                ? AirbnbTheme.coral.withValues(alpha: 0.12)
                                : (shop.visitedToday
                                    ? AirbnbTheme.success.withValues(alpha: 0.1)
                                    : AirbnbTheme.lightGrey),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCheckedIn
                                ? 'CHECKED IN • ${shop.activeVisitFormatted}'
                                : (shop.visitedToday ? 'VISITED TODAY' : 'NOT VISITED'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isCheckedIn
                                  ? AirbnbTheme.coral
                                  : (shop.visitedToday ? AirbnbTheme.success : AirbnbTheme.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Real address chips (SCO No, Gaali No if present in address text)
                    Row(
                      children: [
                        if (shop.unitNo != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.lightGrey,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AirbnbTheme.border),
                            ),
                            child: Text(shop.unitNo!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (shop.gaaliNo != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.lightGrey,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AirbnbTheme.border),
                            ),
                            child: Text(shop.gaaliNo!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            shop.ownerName,
                            style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shop.address.trim().isNotEmpty
                          ? (shop.area.isNotEmpty ? '${shop.address}, ${shop.area}' : shop.address)
                          : 'Address not added',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AirbnbTheme.grey,
                        height: 1.3,
                        fontStyle: shop.address.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Outstanding Udhaar: ₹${shop.outstandingRupees.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.coral),
                        ),
                        Text(
                          'Today: ₹${(shop.todayOrderTotalPaise / 100.0).toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        // In Route / Extra visit toggle with permission check
                        Builder(
                          builder: (ctx) {
                            final isAssigned = widget.api.isAssignedBeatShop(shop.id);
                            final isExtra = widget.api.isExtraVisitToday(shop.id);
                            if (isAssigned) {
                              return IconButton(
                                icon: const Icon(Icons.lock_outline, size: 18, color: AirbnbTheme.grey),
                                tooltip: 'Assigned Beat Shop (Cannot remove)',
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Assigned beat shops cannot be removed by sales reps.')),
                                  );
                                },
                              );
                            }
                            return IconButton(
                              icon: Icon(
                                isExtra ? Icons.check_circle : Icons.add_circle_outline,
                                size: 20,
                                color: isExtra ? AirbnbTheme.coral : AirbnbTheme.grey,
                              ),
                              tooltip: isExtra ? 'Extra Visit Added (Tap to remove)' : 'Add as Extra Visit Today',
                              onPressed: () {
                                widget.api.toggleShopInRoute(shop.id);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isExtra
                                        ? AppStrings.tr('extra_visit_removed', {'name': shop.name})
                                        : AppStrings.tr('extra_visit_added', {'name': shop.name})),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        Expanded(
                          child: isCheckedIn
                              ? ElevatedButton.icon(
                                  onPressed: () {
                                    widget.api.endShopVisit(shop.id);
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Completed visit to ${shop.name}!')),
                                    );
                                  },
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Complete Visit'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AirbnbTheme.dark,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                )
                              : OutlinedButton.icon(
                                  onPressed: () {
                                    widget.api.startShopVisit(shop.id);
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Checked in at ${shop.name}!')),
                                    );
                                  },
                                  icon: const Icon(Icons.location_on_outlined, size: 16),
                                  label: const Text('Start Visit'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AirbnbTheme.dark,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              widget.api.selectShop(shop);
                              if (widget.onNavigateTab != null) {
                                widget.onNavigateTab!(1); // Go to order booking tab
                              }
                            },
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: const Text('Book Order'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AirbnbTheme.coral,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
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

  Widget _buildViewModeToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AirbnbTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _viewMode == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _viewMode == 0
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt, size: 16, color: _viewMode == 0 ? AirbnbTheme.coral : AirbnbTheme.grey),
                    const SizedBox(width: 6),
                    Text(
                      'List View (दुकानें)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _viewMode == 0 ? FontWeight.w800 : FontWeight.w600,
                        color: _viewMode == 0 ? AirbnbTheme.dark : AirbnbTheme.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _viewMode == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _viewMode == 1
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 16, color: _viewMode == 1 ? AirbnbTheme.coral : AirbnbTheme.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Zomato Route Map (रूट)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _viewMode == 1 ? FontWeight.w800 : FontWeight.w600,
                        color: _viewMode == 1 ? AirbnbTheme.dark : AirbnbTheme.grey,
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
