import 'package:flutter/material.dart';
import '../../../l10n/app_strings.dart';
import '../../../screens/views/sales_subviews.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/sync_worker.dart';
import '../../../theme/airbnb_theme.dart';
import '../widgets/sales_language_picker.dart';

/// Sales Role More Tab.
/// Contains secondary actions: Order History, Visits History, Products/Rate List, Language, Sync Diagnostics, Sign Out.
class SalesMoreView extends StatelessWidget {
  final ApiService api;
  final AuthService? authService;
  final SyncWorker? syncWorker;

  const SalesMoreView({
    super.key,
    required this.api,
    this.authService,
    this.syncWorker,
  });

  void _showOrderHistorySheet(BuildContext context) {
    final strings = AppStrings.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final orders = api.orders.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AirbnbTheme.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.t('more_order_history'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: orders.isEmpty
                    ? Center(
                        child: Text(
                          strings.t('no_orders_booked_today'),
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final o = orders[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AirbnbTheme.coral.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.receipt, color: AirbnbTheme.coral, size: 20),
                            ),
                            title: Text(
                              o.shopName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${o.items.length} items • ${o.createdAt.hour.toString().padLeft(2, '0')}:${o.createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            trailing: Text(
                              '₹${(o.totalPaise / 100.0).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AirbnbTheme.dark),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSyncDiagnostics(BuildContext context) async {
    final pendingCount = (await api.db.outboxDao.getPendingQueue()).length;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.sync, color: AirbnbTheme.dark),
            SizedBox(width: 8),
            Text('Sync & Phone Data', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pending Outbox Mutations: $pendingCount', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Mutations are saved locally on this phone and sent when network is available.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              strings.t('more_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AirbnbTheme.dark),
            ),
            const SizedBox(height: 16),

            // Order History Tile
            _buildActionTile(
              icon: Icons.receipt_long,
              color: AirbnbTheme.coral,
              title: strings.t('more_order_history'),
              subtitle: '${api.orders.length} orders recorded',
              onTap: () => _showOrderHistorySheet(context),
            ),

            // Visits History Tile
            _buildActionTile(
              icon: Icons.timer,
              color: const Color(0xFF6C5CE7),
              title: strings.t('more_visits_history'),
              subtitle: 'View past check-ins and notes',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text(strings.t('more_visits_history')),
                        backgroundColor: Colors.white,
                        foregroundColor: AirbnbTheme.dark,
                        elevation: 0,
                      ),
                      body: SalesVisitsView(api: api),
                    ),
                  ),
                );
              },
            ),

            // Rate List & Product Catalog Tile
            _buildActionTile(
              icon: Icons.menu_book,
              color: const Color(0xFF2E7D32),
              title: strings.t('more_product_catalog'),
              subtitle: 'Active SKUs, packaging and prices',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text(strings.t('more_product_catalog')),
                        backgroundColor: Colors.white,
                        foregroundColor: AirbnbTheme.dark,
                        elevation: 0,
                      ),
                      body: SalesProductsView(api: api),
                    ),
                  ),
                );
              },
            ),

            // App Language Tile
            _buildActionTile(
              icon: Icons.translate,
              color: const Color(0xFF0284C7),
              title: strings.t('more_language'),
              subtitle: 'English • Hinglish • हिंदी • ગુજરાતી',
              onTap: () => SalesLanguagePicker.showSheet(context),
            ),

            // Cloud Sync Status Tile
            _buildActionTile(
              icon: Icons.cloud_sync,
              color: const Color(0xFFD97706),
              title: strings.t('more_sync_status'),
              subtitle: 'Inspect local outbox and sync status',
              onTap: () => _showSyncDiagnostics(context),
            ),

            const SizedBox(height: 16),

            // Honest Phone Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.phone_android, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.t('more_help_phone_note'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            if (authService != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => authService!.logout(),
                icon: const Icon(Icons.logout, size: 18, color: AirbnbTheme.coral),
                label: const Text('Sign Out', style: TextStyle(color: AirbnbTheme.coral, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(color: AirbnbTheme.coral.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          onTap: onTap,
        ),
      ),
    );
  }
}
