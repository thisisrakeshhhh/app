import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/airbnb_theme.dart';

class ShopView extends StatefulWidget {
  final ApiService api;
  const ShopView({super.key, required this.api});

  @override
  State<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<ShopView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, OrderUnit> _selectedUnits = {};
  final Map<String, int> _selectedQuantities = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  OrderUnit _getUnit(ProductItem p) => _selectedUnits[p.id] ?? OrderUnit.box;
  int _getQty(ProductItem p) => _selectedQuantities[p.id] ?? 1;

  void _showGstInvoice(DistributorOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.receipt, color: Color(0xFF6C5CE7)),
            const SizedBox(width: 8),
            Text(order.orderNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} • Status: ${order.stage.label}',
                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
            const SizedBox(height: 12),
            const Text('GST Tax Invoice Breakdown:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            ...order.items.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${it.product.name} (${it.quantity} ${it.unit.shortCode})', style: const TextStyle(fontSize: 11)),
                      Text('₹${it.totalRupees.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Taxable Value', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                Text('₹${order.taxableRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CGST (Central Tax)', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                Text('₹${(order.gstRupees / 2).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SGST (Rajasthan State Tax)', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                Text('₹${(order.gstRupees / 2).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Invoice Grand Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text('₹${order.totalRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AirbnbTheme.coral)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current shop persona: Shree Ganesh Kirana
    final shop = widget.api.retailers.first;

    return Column(
      children: [
        // Shop Khata & Credit Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AirbnbTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
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
                      Text(
                        shop.name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AirbnbTheme.dark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prop. ${shop.ownerName} • ${shop.area}',
                        style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'CREDIT OK',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AirbnbTheme.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Credit', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${shop.availableCreditRupees.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AirbnbTheme.success),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Outstanding Udhaar', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${shop.outstandingRupees.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AirbnbTheme.coral),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Credit Limit', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${shop.creditLimitRupees.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AirbnbTheme.dark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tabs: [ Full Godown Stock ] [ Wholesale Catalog ] [ My Orders & Khata ]
        Container(
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AirbnbTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AirbnbTheme.dark,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AirbnbTheme.grey,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Full Godown Stock'),
              Tab(text: 'Order from Godown'),
              Tab(text: 'Orders & Khata'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. FULL GODOWN STOCK OVERVIEW (What the distributor has right now)
              _buildFullGodownStockView(),

              // 2. WHOLESALE DIRECT ORDERING
              _buildWholesaleOrderingView(shop),

              // 3. RETAILER ORDERS & KHATA INVOICES
              _buildRetailerOrdersView(shop),
            ],
          ),
        ),
      ],
    );
  }

  // 1. Full Godown Stock View (Live Warehouse Inventory)
  Widget _buildFullGodownStockView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warehouse_outlined, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Routidrow Central Godown',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Ready Stock: ${widget.api.totalGodownBoxes} Master Boxes in Warehouse',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Live Godown Inventory List', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AirbnbTheme.dark)),
            Text('Updated Real-time', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
          ],
        ),
        const SizedBox(height: 10),
        ...widget.api.products.map((p) {
          final totalPiecesInGodown = p.godownStockBoxes * p.boxQty;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.category.contains('Snacks') ? const Color(0xFFFFF3E0) : AirbnbTheme.cardBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      p.category.contains('Snacks') ? Icons.fastfood : Icons.inventory_2,
                      color: p.category.contains('Snacks') ? const Color(0xFFF57C00) : AirbnbTheme.dark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AirbnbTheme.dark)),
                      Text('${p.hindiName} • 1 Box = ${p.boxQty} Pcs', style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('MRP: ₹${p.mrpRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                          const SizedBox(width: 8),
                          Text('Wholesale Box: ₹${p.priceRupeesForUnit(OrderUnit.box).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6C5CE7))),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.godownStockBoxes > 20
                            ? AirbnbTheme.success.withValues(alpha: 0.12)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${p.godownStockBoxes} Boxes',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: p.godownStockBoxes > 20 ? AirbnbTheme.success : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalPiecesInGodown Pcs Ready',
                      style: const TextStyle(fontSize: 9, color: AirbnbTheme.grey),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 2. Wholesale Direct Ordering View
  Widget _buildWholesaleOrderingView(RetailerShop shop) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: widget.api.products.length,
      itemBuilder: (ctx, i) {
        final p = widget.api.products[i];
        final unit = _getUnit(p);
        final qty = _getQty(p);
        final price = p.priceRupeesForUnit(unit);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ready: ${p.godownStockBoxes} Boxes',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(p.hindiName, style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
              const SizedBox(height: 10),

              // Unit Selector: Piece / Strip / Box
              Row(
                children: [
                  const Text('Order in: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
                  const SizedBox(width: 4),
                  _buildUnitChip(p, OrderUnit.piece, 'Piece'),
                  const SizedBox(width: 6),
                  if (p.stripQty > 1) ...[
                    _buildUnitChip(p, OrderUnit.strip, 'Strip (${p.stripQty})'),
                    const SizedBox(width: 6),
                  ],
                  _buildUnitChip(p, OrderUnit.box, 'Box (${p.boxQty})'),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${price.toStringAsFixed(1)} / ${unit.shortCode}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AirbnbTheme.dark),
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AirbnbTheme.lightGrey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: qty > 1 ? () => setState(() => _selectedQuantities[p.id] = qty - 1) : null,
                            ),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: () => setState(() => _selectedQuantities[p.id] = qty + 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          widget.api.addToCart(p, unit, qty);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added $qty ${unit.shortCode} of ${p.name}')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbTheme.jodhpurBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('Add to Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Retailer Orders & Khata Invoices View
  Widget _buildRetailerOrdersView(RetailerShop shop) {
    final shopOrders = widget.api.orders.where((o) => o.shopId == shop.id).toList();

    if (shopOrders.isEmpty) {
      return const Center(child: Text('No previous orders for this Kirana Store'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: shopOrders.length,
      itemBuilder: (ctx, i) {
        final o = shopOrders[i];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AirbnbTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: o.stage == OrderLifecycleStage.delivered
                          ? AirbnbTheme.success.withValues(alpha: 0.12)
                          : AirbnbTheme.jodhpurBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      o.stage.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: o.stage == OrderLifecycleStage.delivered ? AirbnbTheme.success : AirbnbTheme.jodhpurBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${o.items.length} items • Car: ${o.assignedCarNumber} • Payment: ${o.paymentMode}',
                style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total: ₹${o.totalRupees.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AirbnbTheme.dark)),
                      Text('GST included: ₹${o.gstRupees.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6C5CE7), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showGstInvoice(o),
                    icon: const Icon(Icons.receipt_outlined, size: 14),
                    label: const Text('GST Invoice', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6C5CE7)),
                      foregroundColor: const Color(0xFF6C5CE7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget _buildUnitChip(ProductItem p, OrderUnit unit, String title) {
    final isSelected = _getUnit(p) == unit;

    return InkWell(
      onTap: () => setState(() => _selectedUnits[p.id] = unit),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AirbnbTheme.jodhpurBlue : AirbnbTheme.lightGrey,
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
