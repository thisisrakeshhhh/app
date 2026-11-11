import 'package:flutter/material.dart';
import '../../../l10n/app_strings.dart';
import '../../../screens/dashboards/sales_dashboard.dart';
import '../../../screens/views/sales_subviews.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/sync_worker.dart';
import '../../../theme/airbnb_theme.dart';
import 'sales_earn_view.dart';
import 'sales_more_view.dart';

/// Sales V2 Shell.
/// 4 Primary Tabs:
/// 1. Today (Home KPIs, Route Map, Assigned Beat, Today's Tasks)
/// 2. Shops (Retailers list/map, Class filters, + Add Shop, Shop Profile)
/// 3. Earn (Booked & delivered performance numbers, incentives hint, day close)
/// 4. More (Past orders, visits history, product catalog, language picker, diagnostics)
class SalesShell extends StatefulWidget {
  final ApiService api;
  final AuthService? authService;
  final SyncWorker? syncWorker;
  final int initialTab;

  const SalesShell({
    super.key,
    required this.api,
    this.authService,
    this.syncWorker,
    this.initialTab = 0,
  });

  @override
  State<SalesShell> createState() => _SalesShellState();
}

class _SalesShellState extends State<SalesShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, 3);
  }

  void _onDashboardNavigate(int legacyTabIndex) {
    switch (legacyTabIndex) {
      case 1:
        // New Order entry point -> Open full order booking screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('New Order'),
                backgroundColor: Colors.white,
                foregroundColor: AirbnbTheme.dark,
                elevation: 0,
              ),
              body: SalesOrderBookingView(
                api: widget.api,
                onNavigateTab: (target) {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        );
        break;
      case 2:
        // Retailers -> Switch to Shops tab
        setState(() => _currentIndex = 1);
        break;
      case 3:
        // Products -> Push products view
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Products & Rate List'),
                backgroundColor: Colors.white,
                foregroundColor: AirbnbTheme.dark,
                elevation: 0,
              ),
              body: SalesProductsView(api: widget.api),
            ),
          ),
        );
        break;
      case 4:
        // Visits -> Push visits view
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Visits History'),
                backgroundColor: Colors.white,
                foregroundColor: AirbnbTheme.dark,
                elevation: 0,
              ),
              body: SalesVisitsView(api: widget.api),
            ),
          ),
        );
        break;
      default:
        setState(() => _currentIndex = 0);
        break;
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return SalesDashboard(
          api: widget.api,
          onNavigateTab: _onDashboardNavigate,
        );
      case 1:
        return SalesRetailersView(
          api: widget.api,
          onNavigateTab: (t) => setState(() => _currentIndex = t.clamp(0, 3)),
        );
      case 2:
        return SalesEarnView(api: widget.api);
      case 3:
        return SalesMoreView(
          api: widget.api,
          authService: widget.authService,
          syncWorker: widget.syncWorker,
        );
      default:
        return SalesDashboard(
          api: widget.api,
          onNavigateTab: _onDashboardNavigate,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: const Color(0xFFE2E8F0), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  label: strings.t('nav_sales_today'),
                  icon: Icons.calendar_today_outlined,
                  selectedIcon: Icons.calendar_today,
                ),
                _buildNavItem(
                  index: 1,
                  label: strings.t('nav_sales_shops'),
                  icon: Icons.storefront_outlined,
                  selectedIcon: Icons.storefront,
                ),
                _buildNavItem(
                  index: 2,
                  label: strings.t('nav_sales_earn'),
                  icon: Icons.monetization_on_outlined,
                  selectedIcon: Icons.monetization_on,
                ),
                _buildNavItem(
                  index: 3,
                  label: strings.t('nav_sales_more'),
                  icon: Icons.more_horiz_outlined,
                  selectedIcon: Icons.more_horiz,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AirbnbTheme.coral : const Color(0xFF64748B);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: color,
                  size: 22,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
