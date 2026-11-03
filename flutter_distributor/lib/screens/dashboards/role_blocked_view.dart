import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/airbnb_theme.dart';

/// Screen displayed when an authenticated session carries an unknown or unsupported role.
/// Fails closed to protect distributor business operations.
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AirbnbTheme.coral.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_outlined,
                    size: 44,
                    color: AirbnbTheme.coral,
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 16),
              Text(
                attemptedRole?.toUpperCase() == 'OWNER'
                    ? 'The OWNER role is not mapped to Admin and requires a separately approved Owner dashboard specification.\n\nTo maintain strict role separation and prevent unauthorized privilege escalation, access remains fail-closed until an explicit Owner dashboard is authorized.'
                    : 'Your authenticated account has been assigned a role that is not supported by this pilot application, or lacks access permissions for this distributor organization.\n\nTo ensure multi-tenant security, the client fails closed rather than defaulting to an administrative or privileged view.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5, color: AirbnbTheme.grey),
              ),
              const SizedBox(height: 32),
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
