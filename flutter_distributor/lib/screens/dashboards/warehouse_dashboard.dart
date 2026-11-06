import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import '../views/add_edit_inventory_item_sheet.dart';

/// Inventory & Warehouse Landing Dashboard.
/// Displays Godown stock metrics, low-stock warnings, vehicle loading status,
/// quick actions for inward intake, order picking, and vehicle loading.
class WarehouseDashboard extends StatelessWidget {
  final ApiService api;
  final Function(int targetTab) onNavigateTab;

  const WarehouseDashboard({
    super.key,
    required this.api,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final products = api.products;
    final totalGodownBoxes = api.totalGodownBoxes;
    final totalCarBoxes = api.totalCarBoxes;
    final carNumber = api.carNumber;

    final totalGodownValuationRupees = products.fold<double>(0.0, (sum, p) => sum + p.godownValuationRupees);
    final nearExpiryProducts = products.where((p) => p.isExpiringSoon || p.isExpired).toList();

    // Filter products with low stock (less than 40 boxes in godown)
    final lowStockProducts = products.where((p) => p.godownStockBoxes < 40).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. GODOWN LOCATION BANNER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.warehouse_rounded,
                              color: Color(0xFF60A5FA),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'CENTRAL FMCG GODOWN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => AddEditInventoryItemSheet.show(context, api),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('+ Add SKU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AirbnbTheme.coral,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Live Stock Sync',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Basni Industrial Area Phase II [Sample Facility]',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sample Configuration • Vehicle Loading Bay: $carNumber',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. LIVE GODOWN KPI CARDS (2x2 Grid: Stock, Value, Van, Expiry)
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Godown Stock',
                  value: '$totalGodownBoxes',
                  subtitle: '${products.length} Active SKUs',
                  icon: Icons.inventory_2_outlined,
                  color: AirbnbTheme.jodhpurBlue,
                  onTap: () => onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Stock Valuation',
                  value: '₹${(totalGodownValuationRupees / 100000).toStringAsFixed(2)}L',
                  subtitle: 'Asset Value (Central)',
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF0284C7),
                  onTap: () => onNavigateTab(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Loaded in Van',
                  value: '$totalCarBoxes',
                  subtitle: carNumber,
                  icon: Icons.local_shipping_outlined,
                  color: AirbnbTheme.success,
                  onTap: () => onNavigateTab(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Expiry Radar',
                  value: '${nearExpiryProducts.length}',
                  subtitle: nearExpiryProducts.isNotEmpty ? 'Near Expiry (<60d)' : 'All Batches Fresh',
                  icon: Icons.timelapse_outlined,
                  color: nearExpiryProducts.isNotEmpty ? Colors.amber.shade800 : Colors.green,
                  onTap: () => onNavigateTab(1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. LOW STOCK WARNING BANNER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: lowStockProducts.isNotEmpty
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: lowStockProducts.isNotEmpty
                    ? const Color(0xFFFDBA74)
                    : const Color(0xFF86EFAC),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  lowStockProducts.isNotEmpty
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: lowStockProducts.isNotEmpty
                      ? const Color(0xFFEA580C)
                      : AirbnbTheme.success,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lowStockProducts.isNotEmpty
                            ? '${lowStockProducts.length} SKUs Below Reorder Threshold (<40 Petis)'
                            : 'All SKUs Healthy & Above Threshold',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: lowStockProducts.isNotEmpty
                              ? const Color(0xFFC2410C)
                              : const Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lowStockProducts.isNotEmpty
                            ? 'Factory inward shipment required soon to prevent stockout.'
                            : 'Central godown buffer is adequate for current sales volume.',
                        style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                      ),
                    ],
                  ),
                ),
                if (lowStockProducts.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => onNavigateTab(2), // Inward tab
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Inward +', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 4. QUICK ACTIONS HEADER & GRID
          const Text(
            'Godown Operations',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AirbnbTheme.dark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.inventory_outlined,
                  label: 'Godown Stock',
                  color: AirbnbTheme.jodhpurBlue,
                  onTap: () => onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.input_rounded,
                  label: 'Inward Intake',
                  color: AirbnbTheme.coral,
                  onTap: () => onNavigateTab(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.checklist_rounded,
                  label: 'Pick & Pack',
                  color: const Color(0xFF6C5CE7),
                  onTap: () => onNavigateTab(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.local_shipping_outlined,
                  label: 'Load Vehicle',
                  color: AirbnbTheme.success,
                  onTap: () => onNavigateTab(4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 5. CRITICAL STOCK LEVELS TABLE / LIST
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Warehouse Inventory Highlights',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AirbnbTheme.dark,
                ),
              ),
              GestureDetector(
                onTap: () => onNavigateTab(1),
                child: const Text(
                  'View All SKUs →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AirbnbTheme.jodhpurBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.take(5).length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final prod = products[idx];
              final isLow = prod.godownStockBoxes < 40;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLow ? const Color(0xFFFDBA74) : AirbnbTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isLow
                            ? const Color(0xFFFFF7ED)
                            : AirbnbTheme.jodhpurBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: isLow ? const Color(0xFFEA580C) : AirbnbTheme.jodhpurBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prod.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AirbnbTheme.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${prod.category} • ${prod.boxQty} pcs/box',
                            style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${prod.godownStockBoxes} Boxes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isLow ? const Color(0xFFEA580C) : AirbnbTheme.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLow
                                ? const Color(0xFFFFF7ED)
                                : AirbnbTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isLow ? 'LOW STOCK' : 'IN STOCK',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isLow ? const Color(0xFFEA580C) : AirbnbTheme.success,
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
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AirbnbTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
