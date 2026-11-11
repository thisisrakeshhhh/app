import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/airbnb_theme.dart';

/// Screen displayed when an authenticated session carries an unknown or unsupported role.
/// Fails closed to protect distributor business operations, while providing quick role selectors in pilot demo.
class RoleBlockedView extends StatelessWidget {
  final String? attemptedRole;
  final AuthService? authService;

  const RoleBlockedView({
    super.key,
    this.attemptedRole,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Access Denied', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AirbnbTheme.coral.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_outlined,
                    size: 40,
                    color: AirbnbTheme.coral,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Role Not Authorized',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AirbnbTheme.dark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AirbnbTheme.lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ROLE: ${attemptedRole ?? "UNKNOWN"} • FAIL-CLOSED POLICY',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AirbnbTheme.grey,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                attemptedRole?.toUpperCase() == 'OWNER'
                    ? 'The OWNER role is not mapped to Admin and requires a separately approved Owner dashboard specification.\n\nTo maintain strict role separation and prevent unauthorized privilege escalation, access remains fail-closed until an explicit Owner dashboard is authorized.'
                    : 'Your authenticated account has been assigned a role that is not supported by this pilot application, or lacks access permissions for this distributor organization.\n\nTo ensure multi-tenant security, the client fails closed rather than defaulting to an administrative or privileged view.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, height: 1.45, color: AirbnbTheme.grey),
              ),
              const SizedBox(height: 24),

              // Quick Authorized Role Selectors for Pilot & Testing
              const Text(
                'Select an Authorized Role to Enter:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AirbnbTheme.dark,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.warehouse_outlined, size: 14, color: AirbnbTheme.jodhpurBlue),
                    label: const Text('Warehouse (गोदाम)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    backgroundColor: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.1),
                    side: BorderSide(color: AirbnbTheme.jodhpurBlue.withValues(alpha: 0.3)),
                    onPressed: () {
                      authService?.switchRoleForDemo('WAREHOUSE');
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.point_of_sale_outlined, size: 14, color: AirbnbTheme.coral),
                    label: const Text('Sales Rep (बिक्री)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    backgroundColor: AirbnbTheme.coral.withValues(alpha: 0.1),
                    side: BorderSide(color: AirbnbTheme.coral.withValues(alpha: 0.3)),
                    onPressed: () {
                      authService?.switchRoleForDemo('SALES');
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.local_shipping_outlined, size: 14, color: AirbnbTheme.success),
                    label: const Text('Delivery (डिलीवरी)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    backgroundColor: AirbnbTheme.success.withValues(alpha: 0.1),
                    side: BorderSide(color: AirbnbTheme.success.withValues(alpha: 0.3)),
                    onPressed: () {
                      authService?.switchRoleForDemo('DELIVERY');
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.admin_panel_settings_outlined, size: 14, color: Color(0xFF6C5CE7)),
                    label: const Text('Distributor Owner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                    side: BorderSide(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
                    onPressed: () {
                      authService?.switchRoleForDemo('OWNER');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () async {
                  if (authService != null) {
                    await authService!.logout();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign Out & Return to Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbTheme.dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
