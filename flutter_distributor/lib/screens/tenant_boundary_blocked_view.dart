import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/airbnb_theme.dart';
import 'role_shell.dart';

/// Screen rendered when an authenticated user session is quarantined
/// because the local device contains unassigned legacy B1 business records.
/// Prevents any access to the business application shell until Phase B2.2.
class TenantBoundaryBlockedView extends StatelessWidget {
  final AuthService authService;
  final ApiService? api;

  const TenantBoundaryBlockedView({
    super.key,
    required this.authService,
    this.api,
  });

  @override
  Widget build(BuildContext context) {
    final session = authService.session;
    final orgName = session?.activeOrganizationName ?? 'Distributor Organization';
    final orgId = session?.activeOrganizationId ?? 'Unknown';
    final userName = session?.name ?? 'Authorized User';
    final userRole = session?.activeRole ?? 'SALES';

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text('Tenant Boundary Containment'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Containment Shield Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AirbnbTheme.coral.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 54,
                    color: AirbnbTheme.coral,
                  ),
                ),
                const SizedBox(height: 24),

                // Main Heading
                const Text(
                  'Local Data Quarantined',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: Color(0xFF856404)),
                      SizedBox(width: 6),
                      Text(
                        'ACCESS BLOCKED • FAIL-CLOSED GATE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF856404),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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
                      _buildInfoRow('Role', userRole),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Boundary Notice Card
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
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: AirbnbTheme.coral),
                          const SizedBox(width: 8),
                          const Text(
                            'Data Isolation Boundary Active',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AirbnbTheme.dark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This device contains pre-existing local business records from Phase B1 without organization ownership columns. '
                        'To prevent cross-tenant data leakage or corruption, authenticated access to local operations is strictly quarantined.\n\n'
                        'Phase B2.2 will introduce tenant-scoped SQLite partitioning and explicit data reconciliation.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AirbnbTheme.grey,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (kDebugMode) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoleShell(
                              api: api ?? ApiService(),
                              authService: authService,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.storefront, size: 18, color: Colors.white),
                      label: const Text(
                        'Continue to Sales Pilot (Demo)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbTheme.coral,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Sign Out Action
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await authService.logout();
                    },
                    icon: const Icon(Icons.logout, size: 18, color: AirbnbTheme.coral),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AirbnbTheme.coral,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AirbnbTheme.coral, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AirbnbTheme.grey,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AirbnbTheme.dark,
            ),
          ),
        ),
      ],
    );
  }
}
