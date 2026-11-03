import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';

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

    return ListView.separated(
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
                  Text('Khata: ₹${r.outstandingRupees.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AirbnbTheme.coral)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Proprietor: ${r.ownerName} • Ph: ${r.phone}\n${r.address}, ${r.area}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, height: 1.3)),
            ],
          ),
        );
      },
    );
  }
}

/// 4. Admin Employees View: Distributor workforce directory.
class AdminEmployeesView extends StatelessWidget {
  final ApiService api;
  const AdminEmployeesView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final staff = [
      {'name': 'Vikram Rathore', 'role': 'Sales Executive', 'beat': 'Jodhpur Central Beat (Sardarpura)', 'status': 'Active in Beat', 'color': AirbnbTheme.coral},
      {'name': 'Mukesh Godown', 'role': 'Warehouse Manager', 'beat': 'Central Godown (Basni Phase II)', 'status': 'At Godown', 'color': AirbnbTheme.jodhpurBlue},
      {'name': 'Suresh Yadav', 'role': 'Delivery Executive', 'beat': 'Van: ${api.carNumber} (City Beat 04)', 'status': 'On Delivery Route', 'color': AirbnbTheme.success},
      {'name': 'Rajesh Sharma', 'role': 'Distributor Admin', 'beat': 'Jodhpur FMCG Depot Head Office', 'status': 'Distributor Desk', 'color': const Color(0xFF6C5CE7)},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFECB3)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SAMPLE DATA ONLY: The employee roster below contains demo mock entries for UI evaluation. No server-side staff directory is connected.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFF57F17), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        ...staff.map((m) {
          final col = m['color'] as Color;
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
                  backgroundColor: col.withValues(alpha: 0.12),
                  child: Icon(Icons.person, color: col),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m['name']} [Sample]', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text('${m['role']} • ${m['beat']}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(m['status'] as String, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: col)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// 5. Admin Inventory View: Godown vs Van stock allocation.
class AdminInventoryView extends StatelessWidget {
  final ApiService api;
  const AdminInventoryView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AirbnbTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Central Godown', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                    const SizedBox(height: 4),
                    Text('${api.totalGodownBoxes} Boxes', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(width: 1, height: 36, color: AirbnbTheme.border),
                Column(
                  children: [
                    Text('Van (${api.carNumber})', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                    const SizedBox(height: 4),
                    Text('${api.totalCarBoxes} Boxes', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AirbnbTheme.jodhpurBlue)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('SKU Allocation Detail', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...api.products.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AirbnbTheme.border)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('Godown: ${p.godownStockBoxes} | Van: ${p.carStockBoxes}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// 6. Admin Reports View: CBIC GST & financial ledger breakdown.
class AdminReportsView extends StatelessWidget {
  final ApiService api;
  const AdminReportsView({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final turnover = api.totalDeliveredSalesRupees;
    final totalGst = api.totalGstCollectedRupees;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GST Summary (Illustrative Estimate Only)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Illustrative tax estimate based on in-memory orders. Product-specific GST tax brackets and place-of-supply are unverified with CBIC.', style: TextStyle(fontSize: 11.5, color: AirbnbTheme.grey)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivered FMCG Turnover:', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                    Text('₹${turnover.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CGST (Estimated Central):', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                    Text('₹${(totalGst / 2).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SGST (Estimated State):', style: TextStyle(fontSize: 12, color: AirbnbTheme.grey)),
                    Text('₹${(totalGst / 2).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Tax Estimate:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('₹${totalGst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF6C5CE7))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null, // GSTR-1 export unavailable until verified backend CBIC integration
              icon: const Icon(Icons.download_for_offline_outlined, size: 18),
              label: const Text('Export GSTR-1 Filing (Unavailable — Demo Only)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
