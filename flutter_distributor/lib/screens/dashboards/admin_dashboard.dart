import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/airbnb_theme.dart';
import '../views/sync_status_view.dart';

/// Distributor Admin Landing Dashboard.
/// Displays executive financial overview, CBIC GST breakdown, driver cash vs retailer udhaar,
/// godown inventory totals, and management navigation shortcuts.
class AdminDashboard extends StatelessWidget {
  final ApiService api;
  final Function(int targetTab) onNavigateTab;

  const AdminDashboard({
    super.key,
    required this.api,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final totalDeliveredSales = api.totalDeliveredSalesRupees;
    final totalGst = api.totalGstCollectedRupees;
    final cgst = totalGst / 2;
    final sgst = totalGst / 2;
    final driverCash = api.driverCashCustodyRupees;
    final totalUdhaar = api.totalUdhaarRupees;
    final godownBoxes = api.totalGodownBoxes;
    final carBoxes = api.totalCarBoxes;
    final totalOrders = api.orders.length;
    final totalRetailers = api.retailers.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (api.retailers.isEmpty && api.products.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.storefront, color: Color(0xFF1E40AF)),
                      SizedBox(width: 8),
                      Text(
                        'Fresh Installation — Database Empty',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No products or retailers loaded yet. You can start adding real shops and inward stock, or load sample FMCG demonstration data.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => api.loadDemoData(),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Load Demo Shops & Products'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // 1. ADMIN EXECUTIVE BANNER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B1E54), Color(0xFF5B1A8A)],
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
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'DISTRIBUTOR EXECUTIVE OVERVIEW',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFD6C0B3),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Audit Grade',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Jodhpur FMCG Depot [Sample Org]',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sample Configuration • Operational Overview',
                  style: TextStyle(
                    color: Color(0xFFEAD8C0),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. FINANCIAL OVERVIEW: DELIVERED TURNOVER & GST
          Container(
            padding: const EdgeInsets.all(16),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Delivered Sales Turnover (Delivered Orders)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AirbnbTheme.grey, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ESTIMATE ONLY',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF856404)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${totalDeliveredSales.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AirbnbTheme.dark,
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CGST (Est.)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                          const SizedBox(height: 2),
                          Text('₹${cgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('SGST (Est.)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                          const SizedBox(height: 2),
                          Text('₹${sgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AirbnbTheme.dark)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total GST', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                          const SizedBox(height: 2),
                          Text('₹${totalGst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF6C5CE7))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '* Note: Illustrative estimate assuming standard rate. Product-level HSN tax brackets and interstate IGST are not computed in this client preview.',
                  style: TextStyle(fontSize: 9.5, color: AirbnbTheme.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. CASH CUSTODY VS RETAILER UDHAAR
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Van Cash Custody',
                  value: '₹${driverCash.toStringAsFixed(0)}',
                  subtitle: 'Held by delivery driver',
                  color: AirbnbTheme.success,
                  icon: Icons.payments,
                  onTap: () => onNavigateTab(5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Retailer Udhaar',
                  value: '₹${totalUdhaar.toStringAsFixed(0)}',
                  subtitle: '$totalRetailers Khata Accounts',
                  color: AirbnbTheme.coral,
                  icon: Icons.receipt_long,
                  onTap: () => onNavigateTab(3),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. INVENTORY ALLOCATION CARD
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AirbnbTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Central Godown Stock', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                    const SizedBox(height: 4),
                    Text('$godownBoxes Petis', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                    const SizedBox(height: 2),
                    const Text('Basni Industrial Area', style: TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                  ],
                ),
                Container(width: 1, height: 36, color: AirbnbTheme.border),
                Column(
                  children: [
                    Text('Active Van Stock (${api.carNumber})', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                    const SizedBox(height: 4),
                    Text('$carBoxes Petis', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AirbnbTheme.jodhpurBlue)),
                    const SizedBox(height: 2),
                    const Text('Field Delivery Stock', style: TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5. QUICK ADMIN NAVIGATION SHORTCUTS
          const Text(
            'Distributor Management',
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
                  icon: Icons.shopping_bag_outlined,
                  label: 'Orders ($totalOrders)',
                  color: AirbnbTheme.coral,
                  onTap: () => onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.inventory_2_outlined,
                  label: 'Products (${api.products.length})',
                  color: AirbnbTheme.jodhpurBlue,
                  onTap: () => onNavigateTab(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.store_outlined,
                  label: 'Retailers ($totalRetailers)',
                  color: const Color(0xFF6C5CE7),
                  onTap: () => onNavigateTab(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.assessment_outlined,
                  label: 'GST Reports',
                  color: AirbnbTheme.success,
                  onTap: () => onNavigateTab(6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 6. CLOUDFLARE EDGE & AUDIT BANNER (Tap to view Honest Sync Status Screen)
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SyncStatusView(api: api)),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_done, color: Color(0xFFF57C00), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Cloudflare Workers & D1 Edge Storage',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Offline Outbox • Tap to view sync monitor & audit trail',
                          style: TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AirbnbTheme.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey, fontWeight: FontWeight.w600)),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AirbnbTheme.grey)),
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
