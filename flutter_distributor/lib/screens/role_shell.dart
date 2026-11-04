import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/auth/role_routing.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sync_worker.dart';
import '../theme/airbnb_theme.dart';
import 'dashboards/admin_dashboard.dart';
import 'dashboards/delivery_dashboard.dart';
import 'dashboards/role_blocked_view.dart';
import 'dashboards/sales_dashboard.dart';
import 'dashboards/warehouse_dashboard.dart';
import 'organization_select_view.dart';
import 'views/admin_subviews.dart';
import 'views/delivery_subviews.dart';
import 'views/sales_subviews.dart';
import 'views/warehouse_subviews.dart';

/// Server-Authoritative Role-Based Shell.
/// Inspects the authenticated user session, resolves the canonical role,
/// mounts the role-specific landing dashboard, and renders role-specific navigation tabs.
/// Fails closed (mounts RoleBlockedView) for unknown or unsupported roles.
class RoleShell extends StatefulWidget {
  final ApiService api;
  final AuthService? authService;
  final SyncWorker? syncWorker;

  const RoleShell({
    super.key,
    required this.api,
    this.authService,
    this.syncWorker,
  });

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _currentTabIndex = 0;
  CanonicalRole? _lastRole;

  @override
  void initState() {
    super.initState();
    _syncRole();
    widget.syncWorker?.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    widget.syncWorker?.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant RoleShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRole();
  }

  void _syncRole() {
    final roleStr = widget.authService?.session?.activeRole;
    final canonicalRole = CanonicalRole.fromString(roleStr);

    if (canonicalRole != _lastRole) {
      _lastRole = canonicalRole;
      _currentTabIndex = 0; // Reset to landing dashboard on role change
    }

    // Synchronize legacy AppRole in ApiService for backward compatibility
    if (canonicalRole == CanonicalRole.warehouse) {
      widget.api.switchRole(AppRole.inventory);
    } else if (canonicalRole == CanonicalRole.delivery) {
      widget.api.switchRole(AppRole.logistics);
    } else if (canonicalRole == CanonicalRole.sales) {
      widget.api.switchRole(AppRole.sales);
    }
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
                          'Accountant & GST Summary',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
                        ),
                        Text(
                          'Estimated FMCG Ledger & Tax Invoices (Illustrative Only)',
                          style: TextStyle(fontSize: 11, color: AirbnbTheme.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('ESTIMATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF856404))),
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

  void _showCloudflareInfo() async {
    final pendingCount = (await widget.api.db.outboxDao.getPendingQueue()).length;
    final failedCount = (await widget.api.db.outboxDao.getFailedMutations()).length;
    final worker = widget.syncWorker;
    final lastSync = worker?.lastSuccessfulSyncTime;
    final lastSyncText = lastSync != null
        ? '${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}:${lastSync.second.toString().padLeft(2, '0')}'
        : 'Never (Local Mode)';

    final urlController = TextEditingController(text: widget.api.cloudflareUrl);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                lastSync != null ? Icons.cloud_done : Icons.cloud_off,
                color: lastSync != null ? const Color(0xFF2E7D32) : const Color(0xFFF57C00),
              ),
              const SizedBox(width: 10),
              const Text('RouteFlow Cloud Sync', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Backend: Central Office Cloudflare Worker', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Text('Server URL: ${widget.api.cloudflareUrl}', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
              const SizedBox(height: 10),

              // Real Sync Status Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AirbnbTheme.lightGrey,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AirbnbTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${worker?.isSyncing == true ? "Syncing in progress..." : (lastSync != null ? "Online & Synced" : "Offline / Unsynchronized")}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: worker?.isSyncing == true
                              ? Colors.blue
                              : (lastSync != null ? Colors.green.shade800 : Colors.orange.shade800),
                        )),
                    const SizedBox(height: 4),
                    Text('Last Successful Sync: $lastSyncText', style: const TextStyle(fontSize: 11, color: AirbnbTheme.grey)),
                    const SizedBox(height: 4),
                    Text('Pending Outbox: $pendingCount mutations', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    if (failedCount > 0) ...[
                      const SizedBox(height: 2),
                      Text('Needs Attention: $failedCount mutations', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red)),
                    ],
                    if (worker?.lastError != null) ...[
                      const SizedBox(height: 4),
                      Text('Last Network Note: ${worker!.lastError}', style: const TextStyle(fontSize: 10, color: Colors.red)),
                    ],
                  ],
                ),
              ),

              if (kDebugMode) ...[
                const SizedBox(height: 12),
                const Text('Debug Config: Server Base URL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                TextField(
                  controller: urlController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'e.g. http://127.0.0.1:8787',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        widget.api.setDebugBaseUrl(urlController.text.trim());
                        setDialogState(() {});
                        setState(() {});
                      },
                      child: const Text('Apply Base URL', style: TextStyle(fontSize: 11)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        urlController.text = 'http://127.0.0.1:8787';
                        widget.api.setDebugBaseUrl('http://127.0.0.1:8787');
                        setDialogState(() {});
                        setState(() {});
                      },
                      child: const Text('Localhost (USB Reverse)', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            if (worker != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.sync, size: 14),
                label: const Text('Sync Now (सिंक करें)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbTheme.dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final res = await worker.processPendingOutbox();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.success
                            ? 'Sync completed! Processed ${res.syncedCount} mutations.'
                            : 'Sync attempt: ${res.errorMessage ?? "Offline"}'),
                        backgroundColor: res.success ? AirbnbTheme.dark : Colors.orange.shade800,
                      ),
                    );
                    setState(() {});
                  }
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, color: AirbnbTheme.grey)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleStr = widget.authService?.session?.activeRole;
    final canonicalRole = CanonicalRole.fromString(roleStr);

    // 1. FAIL-CLOSED BARRIER FOR UNKNOWN OR UNSUPPORTED ROLES
    if (canonicalRole == null) {
      return RoleBlockedView(
        attemptedRole: roleStr,
        authService: widget.authService,
      );
    }

    final roleColor = switch (canonicalRole) {
      CanonicalRole.owner => const Color(0xFFD97706),
      CanonicalRole.sales => AirbnbTheme.coral,
      CanonicalRole.warehouse => AirbnbTheme.jodhpurBlue,
      CanonicalRole.delivery => AirbnbTheme.success,
      CanonicalRole.admin => const Color(0xFF6C5CE7),
    };

    final userName = widget.authService?.session?.name ?? canonicalRole.displayName;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 10,
        toolbarHeight: 64,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ROUTIDROW',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      color: AirbnbTheme.dark,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      canonicalRole.badgeLabel,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: roleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AirbnbTheme.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ' (${canonicalRole.badgeLabel})',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: roleColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Active Organization Selector Chip
          if (widget.authService != null && widget.authService!.session != null) ...[
            GestureDetector(
              onTap: () => OrganizationSelectSheet.show(context, widget.authService!),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AirbnbTheme.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AirbnbTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business, size: 13, color: AirbnbTheme.dark),
                    const SizedBox(width: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 68),
                      child: Text(
                        widget.authService!.session?.activeMembership?.name ??
                            widget.authService!.session?.activeOrganizationId ??
                            'Depot',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 13, color: AirbnbTheme.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 2),
          ],

          // Dynamic honest sync status indicator derived from real SyncWorker state
          Builder(
            builder: (ctx) {
              final worker = widget.syncWorker;
              final isSyncing = worker?.isSyncing ?? false;
              final lastSync = worker?.lastSuccessfulSyncTime;

              final String label;
              final Color bgColor;
              final Color borderColor;
              final Color textColor;
              final IconData icon;

              if (isSyncing) {
                label = 'Syncing...';
                bgColor = const Color(0xFFE3F2FD);
                borderColor = const Color(0xFF90CAF9);
                textColor = const Color(0xFF1976D2);
                icon = Icons.sync;
              } else if (lastSync != null) {
                label = 'Synced';
                bgColor = const Color(0xFFE8F5E9);
                borderColor = const Color(0xFFA5D6A7);
                textColor = const Color(0xFF2E7D32);
                icon = Icons.cloud_done;
              } else {
                label = 'Offline';
                bgColor = const Color(0xFFF5F5F5);
                borderColor = const Color(0xFFE0E0E0);
                textColor = const Color(0xFF757575);
                icon = Icons.cloud_off;
              }

              return GestureDetector(
                onTap: _showCloudflareInfo,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 0.6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 10, color: textColor),
                      const SizedBox(width: 3),
                      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: textColor)),
                    ],
                  ),
                ),
              );
            },
          ),

          // Accountant / GST button (available for owner, admin, warehouse, delivery; hidden for sales)
          if (canonicalRole != CanonicalRole.sales)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined, size: 20),
              tooltip: 'Accountant GST Summary',
              onPressed: _showAccountantSheet,
            ),

          // Modern Polished Logout Button with tooltip 'Sign Out'
          IconButton(
            tooltip: 'Sign Out',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AirbnbTheme.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AirbnbTheme.coral.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, size: 14, color: AirbnbTheme.coral),
                  SizedBox(width: 4),
                  Text(
                    'Exit',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AirbnbTheme.coral),
                  ),
                ],
              ),
            ),
            onPressed: () async {
              if (widget.authService != null) {
                await widget.authService!.logout();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildRoleView(canonicalRole),
      ),
      bottomNavigationBar: _buildRoleNavigationBar(canonicalRole, roleColor),
    );
  }

  /// Builds the active view depending on the selected role and active tab index.
  Widget _buildRoleView(CanonicalRole role) {
    switch (role) {
      case CanonicalRole.sales:
        return switch (_currentTabIndex) {
          0 => SalesDashboard(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
            ),
          1 => SalesOrderBookingView(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
            ),
          2 => SalesRetailersView(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
            ),
          3 => SalesProductsView(api: widget.api),
          4 => SalesVisitsView(api: widget.api),
          _ => SalesDashboard(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
            ),
        };

      case CanonicalRole.warehouse:
        return switch (_currentTabIndex) {
          0 => WarehouseDashboard(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
            ),
          1 => WarehouseStockView(api: widget.api),
          2 => WarehouseInwardView(api: widget.api),
          3 => WarehousePickingView(api: widget.api),
          4 => WarehouseLoadingView(api: widget.api),
          _ => WarehouseDashboard(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
            ),
        };

      case CanonicalRole.delivery:
        return switch (_currentTabIndex) {
          0 => DeliveryDashboard(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
            ),
          1 => DeliveryTripsView(api: widget.api),
          2 => DeliveryStopsView(api: widget.api),
          3 => DeliveryCollectionsView(api: widget.api),
          4 => DeliveryHandoverView(api: widget.api),
          _ => DeliveryDashboard(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
            ),
        };

      case CanonicalRole.owner:
      case CanonicalRole.admin:
        return switch (_currentTabIndex) {
          0 => AdminDashboard(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
              syncWorker: widget.syncWorker,
            ),
          1 => AdminOrdersView(api: widget.api),
          2 => AdminProductsView(api: widget.api),
          3 => AdminRetailersView(api: widget.api),
          4 => AdminEmployeesView(api: widget.api),
          5 => AdminInventoryView(api: widget.api),
          6 => AdminReportsView(api: widget.api),
          _ => AdminDashboard(
              api: widget.api,
              onNavigateTab: (t) => setState(() => _currentTabIndex = t),
              syncWorker: widget.syncWorker,
            ),
        };
    }
  }

  /// Builds the role-specific bottom navigation bar.
  Widget _buildRoleNavigationBar(CanonicalRole role, Color roleColor) {
    final navItems = switch (role) {
      CanonicalRole.sales => const [
          _RoleNavItem(label: 'Home', icon: Icons.home, unselectedIcon: Icons.home_outlined),
          _RoleNavItem(label: 'New Order', icon: Icons.add_shopping_cart, unselectedIcon: Icons.add_shopping_cart_outlined),
          _RoleNavItem(label: 'Retailers', icon: Icons.store, unselectedIcon: Icons.store_outlined),
          _RoleNavItem(label: 'Products', icon: Icons.menu_book, unselectedIcon: Icons.menu_book_outlined),
          _RoleNavItem(label: 'My Visits', icon: Icons.timer, unselectedIcon: Icons.timer_outlined),
        ],
      CanonicalRole.warehouse => const [
          _RoleNavItem(label: 'Home', icon: Icons.home, unselectedIcon: Icons.home_outlined),
          _RoleNavItem(label: 'Godown Stock', icon: Icons.inventory_2, unselectedIcon: Icons.inventory_2_outlined),
          _RoleNavItem(label: 'Inward', icon: Icons.input_rounded, unselectedIcon: Icons.input_outlined),
          _RoleNavItem(label: 'Pick & Pack', icon: Icons.checklist, unselectedIcon: Icons.checklist_outlined),
          _RoleNavItem(label: 'Load Van', icon: Icons.local_shipping, unselectedIcon: Icons.local_shipping_outlined),
        ],
      CanonicalRole.delivery => const [
          _RoleNavItem(label: 'Home', icon: Icons.home, unselectedIcon: Icons.home_outlined),
          _RoleNavItem(label: 'My Trips', icon: Icons.map, unselectedIcon: Icons.map_outlined),
          _RoleNavItem(label: 'Stops', icon: Icons.pin_drop, unselectedIcon: Icons.pin_drop_outlined),
          _RoleNavItem(label: 'Collections', icon: Icons.payments, unselectedIcon: Icons.payments_outlined),
          _RoleNavItem(label: 'Handover', icon: Icons.assignment_turned_in, unselectedIcon: Icons.assignment_turned_in_outlined),
        ],
      CanonicalRole.owner || CanonicalRole.admin => const [
          _RoleNavItem(label: 'Overview', icon: Icons.dashboard, unselectedIcon: Icons.dashboard_outlined),
          _RoleNavItem(label: 'Orders', icon: Icons.receipt_long, unselectedIcon: Icons.receipt_long_outlined),
          _RoleNavItem(label: 'Products', icon: Icons.inventory_2, unselectedIcon: Icons.inventory_2_outlined),
          _RoleNavItem(label: 'Retailers', icon: Icons.store, unselectedIcon: Icons.store_outlined),
          _RoleNavItem(label: 'Staff', icon: Icons.people, unselectedIcon: Icons.people_outline),
          _RoleNavItem(label: 'Inventory', icon: Icons.warehouse, unselectedIcon: Icons.warehouse_outlined),
          _RoleNavItem(label: 'Reports', icon: Icons.assessment, unselectedIcon: Icons.assessment_outlined),
        ],
    };

    return Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: (role == CanonicalRole.admin || role == CanonicalRole.owner)
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: navItems.asMap().entries.map((entry) {
                      return _buildNavItem(entry.key, entry.value, roleColor);
                    }).toList(),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: navItems.asMap().entries.map((entry) {
                    return _buildNavItem(entry.key, entry.value, roleColor);
                  }).toList(),
                ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _RoleNavItem item, Color roleColor) {
    final isSelected = _currentTabIndex == index;
    final color = isSelected ? roleColor : AirbnbTheme.grey;

    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? item.icon : item.unselectedIcon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10.5,
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

class _RoleNavItem {
  final String label;
  final IconData icon;
  final IconData unselectedIcon;

  const _RoleNavItem({
    required this.label,
    required this.icon,
    required this.unselectedIcon,
  });
}
