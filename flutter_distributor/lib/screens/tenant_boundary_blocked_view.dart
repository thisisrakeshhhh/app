import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/airbnb_theme.dart';

/// Screen rendered when an authenticated user session encounters legacy unpartitioned records.
/// Provides safe reconciliation options: proceeding with authorized role or purging old local cache.
class TenantBoundaryBlockedView extends StatefulWidget {
  final AuthService authService;
  final ApiService? api;

  const TenantBoundaryBlockedView({
    super.key,
    required this.authService,
    this.api,
  });

  @override
  State<TenantBoundaryBlockedView> createState() => _TenantBoundaryBlockedViewState();
}

class _TenantBoundaryBlockedViewState extends State<TenantBoundaryBlockedView> {
  late String _selectedRole;
  bool _isCleaning = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.authService.session?.activeRole ?? 'OWNER';
  }

  void _proceedWithRole(String role) {
    widget.authService.dismissTenantBoundaryBlock(forcedRole: role);
  }

  void _cleanAndProceed() async {
    setState(() => _isCleaning = true);
    await widget.authService.purgeQuarantineAndUnlock(targetRole: _selectedRole);
    if (mounted) {
      setState(() => _isCleaning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.authService.session;
    final orgName = session?.activeOrganizationName ?? 'Distributor Depot';
    final orgId = session?.activeOrganizationId ?? 'comp_jodhpur';
    final userName = session?.name ?? 'Authorized User';

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text('Tenant Boundary & Local Cache', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Containment Shield Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 44,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 18),

                // Main Heading
                const Text(
                  'Local Cache Notice',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AirbnbTheme.dark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Color(0xFF856404)),
                      SizedBox(width: 6),
                      Text(
                        'UNASSIGNED LOCAL DATA DETECTED',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF856404),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Authenticated Context Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AirbnbTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AUTHENTICATED CONTEXT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AirbnbTheme.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Organization', '$orgName ($orgId)'),
                      const Divider(height: 16),
                      _buildInfoRow('User', userName),
                      const Divider(height: 16),
                      _buildInfoRow('Current Session Role', _selectedRole),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Explanation Note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'This device holds previous offline demo records that were created before tenant isolation was enabled.\n\n'
                    'You can proceed directly into your role, or purge the old local cache to sync fresh data from the server.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
                  ),
                ),
                const SizedBox(height: 20),

                // Role Selector Chips
                const Text(
                  'Select Role to Enter As:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AirbnbTheme.dark),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildRoleChip('OWNER', 'Distributor Owner', Icons.admin_panel_settings_outlined, const Color(0xFF6C5CE7)),
                    _buildRoleChip('SALES', 'Sales Rep (बिक्री)', Icons.point_of_sale_outlined, AirbnbTheme.coral),
                    _buildRoleChip('WAREHOUSE', 'Warehouse (गोदाम)', Icons.warehouse_outlined, AirbnbTheme.jodhpurBlue),
                    _buildRoleChip('DELIVERY', 'Delivery (डिलीवरी)', Icons.local_shipping_outlined, AirbnbTheme.success),
                  ],
                ),
                const SizedBox(height: 24),

                // Primary Action: Proceed with Selected Role
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _proceedWithRole(_selectedRole),
                    icon: const Icon(Icons.login, size: 18, color: Colors.white),
                    label: Text(
                      'Proceed to $_selectedRole Console',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbTheme.dark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary Action: Clean Local Cache & Sync Fresh
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isCleaning ? null : _cleanAndProceed,
                    icon: _isCleaning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cleaning_services_outlined, size: 18, color: Color(0xFFD97706)),
                    label: Text(
                      _isCleaning ? 'Cleaning Cache...' : 'Clean Old Local Cache & Sync Fresh',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD97706), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Sign Out Action
                TextButton.icon(
                  onPressed: () => widget.authService.logout(),
                  icon: const Icon(Icons.logout, size: 16, color: AirbnbTheme.grey),
                  label: const Text('Sign Out', style: TextStyle(color: AirbnbTheme.grey, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, String label, IconData icon, Color color) {
    final isSelected = _selectedRole.toUpperCase() == role.toUpperCase();
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedRole = role),
      avatar: Icon(icon, size: 15, color: isSelected ? Colors.white : color),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AirbnbTheme.dark)),
      selectedColor: color,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? color : AirbnbTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AirbnbTheme.grey)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AirbnbTheme.dark),
          ),
        ),
      ],
    );
  }
}
