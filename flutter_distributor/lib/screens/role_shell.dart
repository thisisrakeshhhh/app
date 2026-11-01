import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/airbnb_theme.dart';
import 'sales_view.dart';
import 'inventory_view.dart';
import 'logistics_view.dart';
import 'organization_select_view.dart';

class RoleShell extends StatefulWidget {
  final ApiService api;
  final AuthService? authService;
  const RoleShell({super.key, required this.api, this.authService});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  @override
  void initState() {
    super.initState();
    final roleStr = widget.authService?.session?.activeRole.toUpperCase();
    if (roleStr == 'WAREHOUSE' || roleStr == 'INVENTORY') {
      widget.api.switchRole(AppRole.inventory);
    } else if (roleStr == 'DELIVERY' || roleStr == 'LOGISTICS' || roleStr == 'DELIVERY_EXECUTIVE') {
      widget.api.switchRole(AppRole.logistics);
    } else if (roleStr == 'SALES' || roleStr == 'SALESPERSON') {
      widget.api.switchRole(AppRole.sales);
    }
  }

  void _openRolePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              const Text(
                'Switch Routidrow Role',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AirbnbTheme.dark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Switch between Salesman, Kirana Retailer, and Van Logistics',
                style: TextStyle(fontSize: 12, color: AirbnbTheme.grey),
              ),
              const SizedBox(height: 16),
              _buildRoleTile(
                role: AppRole.sales,
                title: 'Salesman (Field Beat & Kurkure Booking)',
                subtitle: 'Vikram Rathore • Jodhpur Central Beat',
                icon: Icons.navigation_outlined,
                color: AirbnbTheme.coral,
              ),
              const SizedBox(height: 10),
              _buildRoleTile(
                role: AppRole.inventory,
                title: 'Godown Inventory (Stock Intake & SKUs)',
                subtitle: 'Central Warehouse • Basni Industrial Area',
                icon: Icons.warehouse_outlined,
                color: AirbnbTheme.jodhpurBlue,
              ),
              const SizedBox(height: 10),
              _buildRoleTile(
                role: AppRole.logistics,
                title: 'Logistics (Godown & Car Stock Transfer)',
                subtitle: 'Suresh Yadav • Car: ${widget.api.carNumber}',
                icon: Icons.local_shipping_outlined,
                color: AirbnbTheme.success,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleTile({
    required AppRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = widget.api.currentRole == role;

    return InkWell(
      onTap: () {
        widget.api.switchRole(role);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AirbnbTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? color : AirbnbTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AirbnbTheme.dark,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : AirbnbTheme.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  void _showAccountantSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance, color: Color(0xFF6C5CE7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Accountant & GST Portal',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                        ),
                        Text(
                          'Server-Verified FMCG Ledger & Tax Invoices',
                          style: TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AirbnbTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('CBIC GST OK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.success)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // GST Breakdown Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AirbnbTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AirbnbTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivered Sales Turnover', style: TextStyle(fontSize: 13, color: AirbnbTheme.grey)),
                        Text('₹${widget.api.totalDeliveredSalesRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Central GST (CGST @ 6-9%)', style: TextStyle(fontSize: 12, color: AirbnbTheme.dark)),
                        Text('₹${(widget.api.totalGstCollectedRupees / 2).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AirbnbTheme.dark)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('State GST (SGST @ 6-9%)', style: TextStyle(fontSize: 12, color: AirbnbTheme.dark)),
                        Text('₹${(widget.api.totalGstCollectedRupees / 2).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AirbnbTheme.dark)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total GST Collected', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6C5CE7))),
                        Text('₹${widget.api.totalGstCollectedRupees.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF6C5CE7))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Cash vs Udhaar Metrics
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AirbnbTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Van Cash Custody', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                          const SizedBox(height: 4),
                          Text('₹${widget.api.driverCashCustodyRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AirbnbTheme.success)),
                          const SizedBox(height: 2),
                          const Text('Held by Driver', style: TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AirbnbTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Retailer Udhaar', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                          const SizedBox(height: 4),
                          Text('₹${widget.api.totalUdhaarRupees.toStringAsFixed(0)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AirbnbTheme.coral)),
                          const SizedBox(height: 2),
                          const Text('Outstanding Khata', style: TextStyle(fontSize: 10, color: AirbnbTheme.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Godown vs Car boxes
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
                        const Text('Godown Stock', style: TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        const SizedBox(height: 2),
                        Text('${widget.api.totalGodownBoxes} Boxes', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.dark)),
                      ],
                    ),
                    Container(width: 1, height: 28, color: AirbnbTheme.border),
                    Column(
                      children: [
                        Text('Car (${widget.api.carNumber})', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                        const SizedBox(height: 2),
                        Text('${widget.api.totalCarBoxes} Boxes', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AirbnbTheme.jodhpurBlue)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Back to Operations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbTheme.dark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCloudflareInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.cloud_done, color: Color(0xFFF38020)),
            SizedBox(width: 10),
            Text('Cloudflare Serverless', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend: Cloudflare Workers + D1 Database',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'Edge Endpoint: ${widget.api.cloudflareUrl}',
              style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AirbnbTheme.lightGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '⚡ Sub-50ms latency edge routing\n🔒 Tamper-proof 6-digit delivery OTP\n📦 Atomic D1 stock & car reservations\n📊 Live GST invoice breakdown',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700, color: AirbnbTheme.coral)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.api.currentRole;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ROUTIDROW',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: AirbnbTheme.dark,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'JODHPUR',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: AirbnbTheme.jodhpurBlue,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              role.personaName,
              style: const TextStyle(
                fontSize: 10.5,
                color: AirbnbTheme.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.authService != null && widget.authService!.session != null) ...[
            GestureDetector(
              onTap: () => OrganizationSelectSheet.show(context, widget.authService!),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AirbnbTheme.lightGrey,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AirbnbTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business, size: 14, color: AirbnbTheme.dark),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        widget.authService!.session?.activeMembership?.name ??
                            widget.authService!.session?.activeOrganizationId ??
                            'Org',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AirbnbTheme.dark,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 14, color: AirbnbTheme.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _showAccountantSheet,
            icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFF6C5CE7), size: 21),
            tooltip: 'Accountant & GST Summary',
          ),
          GestureDetector(
            onTap: _showCloudflareInfo,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D), width: 0.6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.cloud, size: 11, color: Color(0xFFF57C00)),
                  SizedBox(width: 3),
                  Text(
                    'Edge D1',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _openRolePicker,
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AirbnbTheme.lightGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.swap_horiz, size: 16, color: AirbnbTheme.dark),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildRoleView(role),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AirbnbTheme.border, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, -3),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  role: AppRole.sales,
                  label: 'Salesman',
                  icon: Icons.navigation,
                  unselectedIcon: Icons.navigation_outlined,
                ),
                _buildNavItem(
                  role: AppRole.inventory,
                  label: 'Inventory',
                  icon: Icons.warehouse,
                  unselectedIcon: Icons.warehouse_outlined,
                ),
                _buildNavItem(
                  role: AppRole.logistics,
                  label: 'Logistics',
                  icon: Icons.local_shipping,
                  unselectedIcon: Icons.local_shipping_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleView(AppRole role) {
    switch (role) {
      case AppRole.sales:
        return SalesView(api: widget.api);
      case AppRole.inventory:
        return InventoryView(api: widget.api);
      case AppRole.logistics:
        return LogisticsView(api: widget.api);
    }
  }

  Widget _buildNavItem({
    required AppRole role,
    required String label,
    required IconData icon,
    required IconData unselectedIcon,
  }) {
    final isSelected = widget.api.currentRole == role;
    final color = isSelected ? AirbnbTheme.coral : AirbnbTheme.grey;

    return InkWell(
      onTap: () => widget.api.switchRole(role),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? icon : unselectedIcon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
