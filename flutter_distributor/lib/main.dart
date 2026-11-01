import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/auth/auth_repository.dart';
import 'data/auth/secure_token_storage.dart';
import 'domain/auth/tenant_boundary_gate.dart';
import 'screens/login_view.dart';
import 'screens/role_shell.dart';
import 'screens/tenant_boundary_blocked_view.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'theme/airbnb_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const RoutidrowApp());
}

class RoutidrowApp extends StatefulWidget {
  final ApiService? api;
  final AuthService? authService;

  const RoutidrowApp({
    super.key,
    this.api,
    this.authService,
  });

  @override
  State<RoutidrowApp> createState() => _RoutidrowAppState();
}

class _RoutidrowAppState extends State<RoutidrowApp> {
  late final ApiService _api;
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _auth = widget.authService ??
        AuthService(
          repository: HttpAuthRepository(baseUrl: _api.cloudflareUrl),
          secureStorage: EncryptedSecureTokenStorage(),
          tenantBoundaryGate: TenantBoundaryGate(_api.db),
          onLogoutCleanup: _api.clearTransientState,
        );

    _api.addListener(_onStateChanged);
    _auth.addListener(_onStateChanged);

    // Initialize session asynchronously
    _auth.initialize();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _api.removeListener(_onStateChanged);
    _auth.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget homeScreen;
    if (!_auth.isAuthenticated) {
      homeScreen = LoginView(authService: _auth);
    } else if (_auth.isTenantBoundaryBlocked) {
      homeScreen = TenantBoundaryBlockedView(authService: _auth);
    } else {
      homeScreen = RoleShell(api: _api, authService: _auth);
    }

    return MaterialApp(
      title: 'Routidrow FMCG Logistics',
      debugShowCheckedModeBanner: false,
      theme: AirbnbTheme.lightTheme,
      home: homeScreen,
    );
  }
}
