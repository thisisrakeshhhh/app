import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import 'add_shop_sheet.dart';

/// 1. Admin Orders View: Master orders overview and approval actions.
class AdminOrdersView extends StatelessWidget {
  final ApiService api;
  const AdminOrdersView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final orders = api.orders;

    return orders.isEmpty
        ? const Center(child: Text('No orders recorded across the organization.', style: TextStyle(color: AirbnbTheme.grey)))
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final o = orders[idx];
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
                        Text('Order #${o.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AirbnbTheme.coral.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(o.stage.label.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AirbnbTheme.coral)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Retailer: ${o.shopName} • Assigned Van: ${o.assignedCarNumber}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${o.items.length} items • Payment: ${o.paymentMode}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('₹${o.totalRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
  }
}

/// 2. Admin Products View: Master SKU catalogue & pricing.
class AdminProductsView extends StatelessWidget {
  final ApiService api;
  const AdminProductsView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final prods = api.products;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: prods.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final p = prods[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AirbnbTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('${p.category} • MRP ₹${p.mrpRupees.toStringAsFixed(0)} • GST ${p.gstRate.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${(p.piecePricePaise / 100).toStringAsFixed(2)}/pc', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text('Godown: ${p.godownStockBoxes} bxs', style: const TextStyle(fontSize: 11, color: AirbnbTheme.jodhpurBlue, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 3. Admin Retailers View: Retailer directory & Khata balances.
class AdminRetailersView extends StatelessWidget {
  final ApiService api;
  const AdminRetailersView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final retailers = api.retailers;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Retailers (${retailers.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              ElevatedButton.icon(
                key: const ValueKey('admin_add_retailer_btn'),
                onPressed: () async {
                  await AddShopSheet.show(context, api: api);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbTheme.coral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ Add Retailer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AirbnbTheme.border),
        Expanded(
          child: retailers.isEmpty
              ? const Center(
                  child: Text('No retailers registered yet.', style: TextStyle(color: AirbnbTheme.grey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: retailers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final r = retailers[idx];
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
                              Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              Text('Khata: ₹${r.outstandingRupees.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 13, color: AirbnbTheme.coral)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Proprietor: ${r.ownerName} • Ph: ${r.phone}\n${r.address}, ${r.area}',
                              style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, height: 1.3)),
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

/// 4. Admin Employees View: Distributor workforce directory.
class AdminEmployeesView extends StatefulWidget {
  final ApiService api;
  const AdminEmployeesView({super.key, required this.api});

  @override
  State<AdminEmployeesView> createState() => _AdminEmployeesViewState();
}

class _AdminEmployeesViewState extends State<AdminEmployeesView> {
  void _openAddEmployeeSheet() {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final beatCtrl = TextEditingController();
    String selectedRole = 'SALES';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: AirbnbTheme.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Icon(Icons.person_add_alt_1, color: Color(0xFF6C5CE7), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Assign Role & Create Credentials',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create login ID and password for your field salesperson, warehouse manager, or delivery driver.',
                  style: TextStyle(fontSize: 12, color: AirbnbTheme.grey),
                ),
                const SizedBox(height: 16),

                // Full Name
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g. Ramesh Kumar',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Username (Login ID)
                TextField(
                  controller: usernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Username (Login ID)',
                    hintText: 'e.g. ramesh_sales',
                    prefixIcon: const Icon(Icons.alternate_email, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Password
                TextField(
                  controller: passwordCtrl,
                  obscureText: false,
                  decoration: InputDecoration(
                    labelText: 'Initial Password',
                    hintText: 'e.g. RouteFlow@2026!',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Role Dropdown
                const Text('Assign Functional Role:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SALES', child: Text('Salesperson (Field Beat & Orders)')),
                    DropdownMenuItem(value: 'WAREHOUSE', child: Text('Warehouse Manager (Godown & Stock)')),
                    DropdownMenuItem(value: 'DELIVERY', child: Text('Delivery Executive (Van Logistics)')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Distributor Admin (Operations Desk)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),

                // Optional Beat
                if (selectedRole == 'SALES')
                  TextField(
                    controller: beatCtrl,
                    decoration: InputDecoration(
                      labelText: 'Assigned Beat / Route',
                      hintText: 'e.g. Sardarpura & Nai Sadak',
                      prefixIcon: const Icon(Icons.map_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || usernameCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill in Full Name, Username, and Password.')),
                        );
                        return;
                      }

                      final success = await widget.api.createStaffMember(
                        fullName: nameCtrl.text.trim(),
                        username: usernameCtrl.text.trim(),
                        password: passwordCtrl.text.trim(),
                        role: selectedRole,
                        beatId: beatCtrl.text.trim().isNotEmpty ? beatCtrl.text.trim() : null,
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Staff member ${usernameCtrl.text} created successfully!' : 'Error creating staff.'),
                            backgroundColor: success ? AirbnbTheme.dark : Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, size: 18, color: Colors.white),
                    label: const Text('Create Account & Save Role', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.api.staffList;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Header Card with Add Staff Action
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge, color: Color(0xFF6C5CE7), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Staff Directory & Roles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                    Text('${staff.length} active team members', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddEmployeeSheet,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('Assign Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Staff List
        ...staff.map((m) {
          final roleColor = switch (m.role) {
            'SALES' => AirbnbTheme.coral,
            'WAREHOUSE' => AirbnbTheme.jodhpurBlue,
            'DELIVERY' => AirbnbTheme.success,
            _ => const Color(0xFF6C5CE7),
          };

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  child: Icon(Icons.person, color: roleColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(m.role, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: roleColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${m.username} • ${m.assignedBeat ?? "General Depot"}',
                        style: const TextStyle(fontSize: 11.5, color: AirbnbTheme.grey),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await widget.api.toggleStaffStatus(m.id);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: m.isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: m.isActive ? const Color(0xFFA5D6A7) : const Color(0xFFFFCDD2)),
                    ),
                    child: Text(
                      m.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: m.isActive ? const Color(0xFF2E7D32) : Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// 5. Admin Inventory View: Godown Stock & Valuation Analytics.
class AdminInventoryView extends StatelessWidget {
  final ApiService api;
  const AdminInventoryView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final godownBoxes = api.totalGodownBoxes;
    final vanBoxes = api.totalCarBoxes;
    final godownValuation = api.totalGodownValuationRupees;
    final estimatedProfit = api.totalGodownEstimatedProfitRupees;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Godown Overview Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
                        const Text('Godown Stock Valuation', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        Text('₹${godownValuation.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AirbnbTheme.dark)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Profit Potential', style: TextStyle(fontSize: 10.5, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                          Text('₹${estimatedProfit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Central Godown', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        const SizedBox(height: 2),
                        Text('$godownBoxes Boxes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AirbnbTheme.dark)),
                      ],
                    ),
                    Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                    Column(
                      children: [
                        Text('Van (${api.carNumber})', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        const SizedBox(height: 2),
                        Text('$vanBoxes Boxes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AirbnbTheme.jodhpurBlue)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Product Stock & Profit Margins', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
          const SizedBox(height: 10),

          // SKU Detail Cards
          ...api.products.map((p) {
            final marginPercent = api.getProductMarginPercent(p);
            final soldPieces = api.getProductSoldPieces(p.id);
            final revenue = api.getProductRevenueRupees(p.id);
            final isLowStock = p.godownStockBoxes <= p.reorderLevelBoxes;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isLowStock ? const Color(0xFFFFCC80) : const Color(0xFFE2E8F0)),
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
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AirbnbTheme.dark),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${marginPercent.toStringAsFixed(1)}% Margin',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${p.category} • Wholesale: ₹${(p.piecePricePaise / 100.0).toStringAsFixed(2)}/pc • ${p.boxQty} pcs/box',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Godown: ${p.godownStockBoxes} boxes • Van: ${p.carStockBoxes} boxes', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('Sold: $soldPieces pcs (₹${revenue.toStringAsFixed(0)})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6C5CE7))),
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

/// 6. Admin Reports View: CBIC GST & Profit & Product Performance Analytics.
class AdminReportsView extends StatelessWidget {
  final ApiService api;
  const AdminReportsView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final turnover = api.totalDeliveredSalesRupees;
    final totalGst = api.totalGstCollectedRupees;
    final godownProfit = api.totalGodownEstimatedProfitRupees;
    final godownValuation = api.totalGodownValuationRupees;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profit Overview Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Executive Profit & Turnover Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivered Sales Turnover:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text('₹${turnover.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Godown Stock Valuation:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text('₹${godownValuation.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Godown Gross Margin Potential:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text('₹${godownProfit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total GST Collected:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('₹${totalGst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF6C5CE7))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Top Performing Products Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top Performing Products', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                const SizedBox(height: 10),
                ...api.products.take(5).map((p) {
                  final sold = api.getProductSoldPieces(p.id);
                  final rev = api.getProductRevenueRupees(p.id);
                  final margin = api.getProductMarginPercent(p);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('${p.category} • ${margin.toStringAsFixed(1)}% margin', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Text('$sold pcs\n₹${rev.toStringAsFixed(0)}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
