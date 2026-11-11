import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'role_shell.dart';

/// Screen originally used for legacy unpartitioned record isolation.
/// Automatically grants full authorized permission, dismisses any boundary barrier,
/// and immediately routes to the active role shell.
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.authService.dismissTenantBoundaryBlock();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      api: widget.api ?? ApiService(),
      authService: widget.authService,
      salesV2Enabled: true,
    );
  }
}
