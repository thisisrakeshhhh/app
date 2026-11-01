import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/airbnb_theme.dart';

class SalesView extends StatefulWidget {
  final ApiService api;
  const SalesView({super.key, required this.api});

  @override
  State<SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<SalesView> {
  String _selectedCategory = 'All';
  RetailerShop? _activeShop;
  Timer? _ticker;
  final Map<String, OrderUnit> _selectedUnits = {};
  final Map<String, int> _selectedQuantities = {};

  List<String> get _categories {
    final cats = <String>{'All'};
    for (final p in widget.api.products) {
      if (p.category.trim().isNotEmpty) cats.add(p.category.trim());
    }
    return cats.toList();
  }

  void _onApiUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.api.addListener(_onApiUpdate);
    if (widget.api.retailers.isNotEmpty) {
      _activeShop = widget.api.retailers.first;
    }
    // Start periodic 1-second ticker for live visit stopwatch
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    widget.api.removeListener(_onApiUpdate);
    _ticker?.cancel();
    super.dispose();
  }

  OrderUnit _getUnit(ProductItem p) => _selectedUnits[p.id] ?? OrderUnit.box;
  int _getQty(ProductItem p) => _selectedQuantities[p.id] ?? 1;

  void _selectShop(RetailerShop shop) {
    setState(() {
      _activeShop = shop;
    });
  }

  void _startVisit(RetailerShop shop) {
    widget.api.startShopVisit(shop.id);
    setState(() {
      _activeShop = shop;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Checked in at ${shop.name} (GPS Beat Geofence Verified)'),
        backgroundColor: AirbnbTheme.dark,
      ),
    );
  }

  void _completeVisit(RetailerShop shop) {
    final elapsedSecs = widget.api.endShopVisit(shop.id);
    final formatted = RetailerShop.formatDuration(elapsedSecs);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Visit to ${shop.name} completed! Time logged: $formatted'),
        backgroundColor: AirbnbTheme.success,
      ),
    );
  }

  void _goToNextShop() {
    if (_activeShop == null) return;
    final currentShop = _activeShop!;
    if (currentShop.isCheckedIn) {
      _completeVisit(currentShop);
    }
    final retailers = widget.api.retailers;
    final currentIndex = retailers.indexWhere((r) => r.id == currentShop.id);
    final nextIndex = (currentIndex + 1) % retailers.length;
    final nextShop = retailers[nextIndex];
    _startVisit(nextShop);
  }

  void _showShopSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                  const Text(
                    'Select Kirana Store to Visit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                  ),
                  Text(
                    '${widget.api.retailers.length} Shops',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AirbnbTheme.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Jodhpur Central Beat • Sardarpura, Station Rd, Sojati & Paota',
                style: TextStyle(fontSize: 12, color: AirbnbTheme.grey),
              ),
              const SizedBox(height: 16),
              ...widget.api.retailers.map((shop) {
                final isCurrent = _activeShop?.id == shop.id;
                final isCheckedIn = shop.isCheckedIn;
                final isVisited = shop.visitedToday;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isCurrent ? AirbnbTheme.coral.withValues(alpha: 0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent ? AirbnbTheme.coral : AirbnbTheme.border,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: isCheckedIn
                          ? AirbnbTheme.coral
                          : isVisited
                              ? AirbnbTheme.success
                              : AirbnbTheme.lightGrey,
                      child: Icon(
                        isCheckedIn
                            ? Icons.timer
                            : isVisited
                                ? Icons.check
                                : Icons.storefront,
                        color: (isCheckedIn || isVisited) ? Colors.white : AirbnbTheme.dark,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            shop.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        if (shop.allTimeSpentSeconds > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCheckedIn
                                  ? AirbnbTheme.coral.withValues(alpha: 0.12)
                                  : AirbnbTheme.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '⏱️ ${shop.totalTimeSpentFormatted}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isCheckedIn ? AirbnbTheme.coral : AirbnbTheme.success,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${shop.ownerName} • ${shop.area}\nOutstanding Khata: ₹${shop.outstandingRupees.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, height: 1.3),
                    ),
                    trailing: isCheckedIn
                        ? ElevatedButton(
                            onPressed: () {
                              _completeVisit(shop);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AirbnbTheme.dark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Finish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          )
                        : TextButton(
                            onPressed: () {
                              _selectShop(shop);
                              _startVisit(shop);
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              isVisited ? 'Visit Again' : 'Check In',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isVisited ? AirbnbTheme.jodhpurBlue : AirbnbTheme.coral,
                              ),
                            ),
                          ),
                    onTap: () {
                      _selectShop(shop);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showBeatLogSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                  const Text(
                    'Jodhpur Beat Visit Log',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.dark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Total: ${widget.api.totalBeatTimeSpentFormatted}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Complete record of time spent at each Kirana retailer today',
                style: TextStyle(fontSize: 12, color: AirbnbTheme.grey),
              ),
              const SizedBox(height: 16),
              ...widget.api.retailers.map((shop) {
                final isCheckedIn = shop.isCheckedIn;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCheckedIn
                        ? AirbnbTheme.coral.withValues(alpha: 0.05)
                        : AirbnbTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCheckedIn ? AirbnbTheme.coral : AirbnbTheme.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCheckedIn
                            ? Icons.timer
                            : shop.visitedToday
                                ? Icons.check_circle
                                : Icons.schedule,
                        color: isCheckedIn
                            ? AirbnbTheme.coral
                            : shop.visitedToday
                                ? AirbnbTheme.success
                                : AirbnbTheme.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(
                              '${shop.area} • ${shop.visitCountToday} visit(s)',
                              style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            shop.totalTimeSpentFormatted,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isCheckedIn ? AirbnbTheme.coral : AirbnbTheme.dark,
                            ),
                          ),
                          Text(
                            isCheckedIn
                                ? 'Active now'
                                : shop.visitedToday
                                    ? 'Completed'
                                    : 'Pending',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isCheckedIn
                                  ? AirbnbTheme.coral
                                  : shop.visitedToday
                                      ? AirbnbTheme.success
                                      : AirbnbTheme.grey,
                            ),
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
      },
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cartItems = widget.api.cart.values.toList();

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Booking Cart',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                          ),
                          Text(
                            'For: ${_activeShop?.name ?? "Kirana Store"}',
                            style: const TextStyle(fontSize: 12, color: AirbnbTheme.grey),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          widget.api.clearCart();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (cartItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('No items in order booking cart', style: TextStyle(color: AirbnbTheme.grey)),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: cartItems.length,
                        separatorBuilder: (context, index) => const Divider(height: 12),
                        itemBuilder: (ctx, i) {
                          final item = cartItems[i];
                          return Row(
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
                                      '${item.quantity} x ${item.unit.label} (${item.totalPieces} pcs)',
                                      style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                                    ),
                                    Text(
                                      'Taxable: ₹${item.taxableRupees.toStringAsFixed(1)} + GST: ₹${item.totalGstRupees.toStringAsFixed(1)} (${item.product.gstRate.toInt()}%)',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF6C5CE7)),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: () {
                                      widget.api.updateCartQuantity(item.product.id, -1);
                                      setSheetState(() {});
                                      setState(() {});
                                    },
                                  ),
                                  Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: () {
                                      widget.api.updateCartQuantity(item.product.id, 1);
                                      setSheetState(() {});
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${item.totalRupees.toStringAsFixed(1)}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 14),

                  // GST & Grand Total Summary Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.lightGrey,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AirbnbTheme.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Taxable Subtotal', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                            Text('₹${widget.api.cartTaxableRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('CGST (Central Tax)', style: TextStyle(fontSize: 11, color: Color(0xFF6C5CE7))),
                            Text('₹${widget.api.cartCgstRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6C5CE7))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('SGST (Rajasthan State Tax)', style: TextStyle(fontSize: 11, color: Color(0xFF6C5CE7))),
                            Text('₹${widget.api.cartSgstRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6C5CE7))),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total (GST Incl.)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                            Text('₹${widget.api.cartTotalRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AirbnbTheme.coral)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: cartItems.isEmpty ? null : () {
                            if (_activeShop != null) {
                              final o = widget.api.placeOrder(
                                shopId: _activeShop!.id,
                                paymentMode: 'Credit',
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Order ${o.orderNumber} booked on Kirana Khata!')),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AirbnbTheme.jodhpurBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Book on Khata', style: TextStyle(color: AirbnbTheme.jodhpurBlue, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: cartItems.isEmpty ? null : () {
                            if (_activeShop != null) {
                              final o = widget.api.placeOrder(
                                shopId: _activeShop!.id,
                                paymentMode: 'COD',
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Order ${o.orderNumber} booked for Cash on Delivery!')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AirbnbTheme.coral,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Confirm COD', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final filteredProducts = _selectedCategory == 'All'
        ? widget.api.products
        : widget.api.products.where((p) => p.category == _selectedCategory).toList();

    final shop = _activeShop;
    final isCheckedIn = shop?.isCheckedIn ?? false;
    final liveDurationStr = shop?.activeVisitFormatted ?? '0s';
    final totalDurationStr = shop?.totalTimeSpentFormatted ?? '0s';

    return Column(
      children: [
        // 1. HORIZONTAL BEAT SHOP QUICK-SWITCHER
        Container(
          height: 48,
          margin: const EdgeInsets.only(top: 6),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: widget.api.retailers.length,
            itemBuilder: (ctx, idx) {
              final r = widget.api.retailers[idx];
              final isCurrent = r.id == shop?.id;
              final isShopCheckedIn = r.isCheckedIn;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _selectShop(r),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AirbnbTheme.dark
                          : isShopCheckedIn
                              ? AirbnbTheme.coral.withValues(alpha: 0.12)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent
                            ? AirbnbTheme.dark
                            : isShopCheckedIn
                                ? AirbnbTheme.coral
                                : AirbnbTheme.border,
                        width: isCurrent || isShopCheckedIn ? 1.5 : 1,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: isCurrent
                              ? (isShopCheckedIn ? const Color(0xFF69F0AE) : Colors.white24)
                              : (isShopCheckedIn
                                  ? AirbnbTheme.coral
                                  : r.visitedToday
                                      ? AirbnbTheme.success
                                      : AirbnbTheme.lightGrey),
                          child: Icon(
                            isShopCheckedIn
                                ? Icons.timer
                                : r.visitedToday
                                    ? Icons.check
                                    : Icons.storefront,
                            size: 11,
                            color: isCurrent
                                ? (isShopCheckedIn ? AirbnbTheme.dark : Colors.white)
                                : (isShopCheckedIn || r.visitedToday
                                    ? Colors.white
                                    : AirbnbTheme.dark),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          r.name.length > 15 ? '${r.name.substring(0, 14)}…' : r.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                            color: isCurrent ? Colors.white : AirbnbTheme.dark,
                          ),
                        ),
                        if (isShopCheckedIn) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF69F0AE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.activeVisitFormatted,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AirbnbTheme.dark,
                              ),
                            ),
                          ),
                        ] else if (r.totalTimeSpentSeconds > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${r.totalTimeSpentFormatted})',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isCurrent ? Colors.white70 : AirbnbTheme.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 2. ACTIVE SHOP VISIT & LIVE TIME SPENT CARD
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.all(13),
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
              // Header Row: Area and All Shops Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AirbnbTheme.coral, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        shop?.area ?? 'Jodhpur Central Beat',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _showShopSelector,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Text('All Shops', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_drop_down, color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Shop Title and Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop?.name ?? 'Select Kirana Store',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Owner: ${shop?.ownerName ?? "Proprietor"} • ${shop?.phone ?? ""}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isCheckedIn
                          ? const Color(0xFF00E676).withValues(alpha: 0.2)
                          : (shop?.visitedToday ?? false)
                              ? AirbnbTheme.jodhpurBlue.withValues(alpha: 0.25)
                              : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCheckedIn
                            ? const Color(0xFF00E676)
                            : (shop?.visitedToday ?? false)
                                ? AirbnbTheme.jodhpurBlue
                                : Colors.transparent,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCheckedIn) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E676),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          isCheckedIn
                              ? 'LIVE AT SHOP'
                              : (shop?.visitedToday ?? false)
                                  ? 'VISITED TODAY'
                                  : 'NOT CHECKED IN',
                          style: TextStyle(
                            color: isCheckedIn
                                ? const Color(0xFF69F0AE)
                                : (shop?.visitedToday ?? false)
                                    ? const Color(0xFF90CAF9)
                                    : Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // LIVE TIME SPENT BOX & VISIT CONTROLS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? const Color(0xFF1E272E)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCheckedIn
                        ? const Color(0xFF00E676).withValues(alpha: 0.4)
                        : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isCheckedIn
                            ? const Color(0xFF00E676).withValues(alpha: 0.18)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.timer_outlined,
                        color: isCheckedIn ? const Color(0xFF00E676) : Colors.white70,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isCheckedIn ? 'Time Spent at Store: ' : 'Total Time Today: ',
                                style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                              ),
                              Text(
                                isCheckedIn ? liveDurationStr : totalDurationStr,
                                style: TextStyle(
                                  color: isCheckedIn ? const Color(0xFF69F0AE) : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            isCheckedIn
                                ? 'GPS Geofence Verified • Cumulative: $totalDurationStr'
                                : (shop?.visitedToday ?? false)
                                    ? 'Completed ${shop?.visitCountToday ?? 0} visit(s) today'
                                    : 'Tap Start Visit when at retailer location',
                            style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                          ),
                        ],
                      ),
                    ),
                    if (shop != null) ...[
                      if (!isCheckedIn)
                        ElevatedButton.icon(
                          onPressed: () => _startVisit(shop),
                          icon: const Icon(Icons.play_arrow, size: 14),
                          label: const Text('Start Visit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AirbnbTheme.coral,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(80, 30),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      else ...[
                        OutlinedButton(
                          onPressed: () => _completeVisit(shop),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF69F0AE),
                            side: const BorderSide(color: Color(0xFF69F0AE), width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(60, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Finish', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          onPressed: _goToNextShop,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AirbnbTheme.coral,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(60, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Next ➔', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Bottom Stats: Available Credit, Outstanding Udhaar, Beat Log Pill
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available Credit', style: TextStyle(color: Colors.white54, fontSize: 9)),
                          const SizedBox(height: 1),
                          Text('₹${shop?.availableCreditRupees.toStringAsFixed(0) ?? "0"}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Outstanding Udhaar', style: TextStyle(color: Colors.white54, fontSize: 9)),
                          const SizedBox(height: 1),
                          Text('₹${shop?.outstandingRupees.toStringAsFixed(0) ?? "0"}',
                              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _showBeatLogSheet,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Beat Log', style: TextStyle(color: Color(0xFF90CAF9), fontSize: 9, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 1),
                          Text(widget.api.totalBeatTimeSpentFormatted,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3. CATEGORY FILTER CHIPS
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
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.white : AirbnbTheme.dark,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSel ? AirbnbTheme.dark : AirbnbTheme.border),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 4),

        // 4. PRODUCTS CATALOG WITH PIECE / STRIP / BOX UNIT SELECTOR
        Expanded(
          child: filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.inventory_2_outlined, size: 40, color: AirbnbTheme.grey),
                      SizedBox(height: 8),
                      Text('No items in this category', style: TextStyle(fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
                      SizedBox(height: 4),
                      Text('Add items in the Inventory tab to show them here', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filteredProducts.length,
                  itemBuilder: (ctx, i) {
                    final p = filteredProducts[i];
                    final unit = _getUnit(p);
                    final qty = _getQty(p);
                    final priceForSelectedUnit = p.priceRupeesForUnit(unit);
                    final piecesCount = p.piecesForUnit(unit) * qty;
                    final isOutOfStock = widget.api.availableGodownPieces(p.id) <= 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AirbnbTheme.border),
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
                              p.category.contains('Snacks') ? Icons.fastfood : Icons.inventory_2_outlined,
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
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AirbnbTheme.dark),
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
                                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AirbnbTheme.jodhpurBlue),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.hindiName,
                                style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    widget.api.pendingBookingPieces(p.id) > 0
                                        ? 'Avail: ${widget.api.availableGodownBoxes(p.id)} Bxs (${p.godownStockBoxes} total)'
                                        : 'Godown: ${p.godownStockBoxes} Boxes',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AirbnbTheme.success),
                                  ),
                                  Text(
                                    'Car (${widget.api.carNumber}): ${p.carStockBoxes} Boxes',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AirbnbTheme.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Unit Selection Chips: [ Piece ] [ Strip ] [ Box ]
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('Unit: ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
                          const SizedBox(width: 4),
                          _buildUnitChip(p, OrderUnit.piece, 'Piece (1 pc)'),
                          const SizedBox(width: 5),
                          if (p.stripQty > 1) ...[
                            _buildUnitChip(p, OrderUnit.strip, 'Strip (${p.stripQty} pcs)'),
                            const SizedBox(width: 5),
                          ],
                          _buildUnitChip(p, OrderUnit.box, 'Box (${p.boxQty} pcs)'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Price & Stepper + Add to Cart Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '₹${priceForSelectedUnit.toStringAsFixed(1)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AirbnbTheme.dark),
                                  ),
                                  Text(
                                    ' / ${unit.shortCode}',
                                    style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey),
                                  ),
                                ],
                              ),
                              Text(
                                '($piecesCount pcs • ${p.gstRate.toInt()}% GST incl.)',
                                style: const TextStyle(fontSize: 9, color: Color(0xFF6C5CE7), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Quantity Stepper
                        Container(
                          decoration: BoxDecoration(
                            color: AirbnbTheme.lightGrey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 13),
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                padding: EdgeInsets.zero,
                                onPressed: qty > 1
                                    ? () => setState(() => _selectedQuantities[p.id] = qty - 1)
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '$qty',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 13),
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                padding: EdgeInsets.zero,
                                onPressed: () => setState(() => _selectedQuantities[p.id] = qty + 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: isOutOfStock
                              ? null
                              : () {
                                  widget.api.addToCart(p, unit, qty);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added $qty ${unit.shortCode} of ${p.name}'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOutOfStock ? Colors.grey[300] : AirbnbTheme.coral,
                            foregroundColor: isOutOfStock ? Colors.grey[600] : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(42, 28),
                          ),
                          child: Text(isOutOfStock ? 'Sold Out' : 'Add', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // 5. BOTTOM CART SUMMARY BAR
        if (widget.api.cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AirbnbTheme.dark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.api.cart.length} Products • ${widget.api.cartTotalPieces} Pcs',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '₹${widget.api.cartTotalRupees.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showCartSheet,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 15),
                  label: const Text('Review & Book'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbTheme.coral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUnitChip(ProductItem p, OrderUnit unit, String title) {
    final currentUnit = _getUnit(p);
    final isSelected = currentUnit == unit;

    return InkWell(
      onTap: () => setState(() => _selectedUnits[p.id] = unit),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AirbnbTheme.coral : AirbnbTheme.lightGrey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AirbnbTheme.dark,
          ),
        ),
      ),
    );
  }
}
