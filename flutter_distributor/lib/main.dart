import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'data/auth/auth_repository.dart';
import 'data/auth/secure_token_storage.dart';
import 'domain/auth/tenant_boundary_gate.dart';
import 'screens/login_view.dart';
import 'screens/role_shell.dart';
import 'screens/tenant_boundary_blocked_view.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/sync_worker.dart';
import 'theme/airbnb_theme.dart';
import 'l10n/app_language.dart';
import 'l10n/language_controller.dart';

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
  final SyncWorker? syncWorker;

  const RoutidrowApp({
    super.key,
    this.api,
    this.authService,
    this.syncWorker,
  });

  @override
  State<RoutidrowApp> createState() => _RoutidrowAppState();
}

class _RoutidrowAppState extends State<RoutidrowApp> {
  late final ApiService _api;
  late final AuthService _auth;
  late final SyncWorker _syncWorker;
  final http.Client _httpClient = http.Client();

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

    _syncWorker = widget.syncWorker ??
        SyncWorker(
          db: _api.db,
          httpClient: _httpClient,
          baseUrl: _api.cloudflareUrl,
          authService: _auth,
          apiService: _api,
          accessTokenProvider: () async {
            try {
              return await _auth.getValidAccessToken();
            } catch (_) {
              return null;
            }
          },
          refreshTokenTrigger: () async {
            try {
              await _auth.getValidAccessToken();
              return true;
            } catch (_) {
              return false;
            }
          },
        );

    // Wire immediate sync pass upon outbox mutation insertion
    _api.onOutboxMutationEnqueued = () => _syncWorker.processPendingOutbox();

    _api.addListener(_onStateChanged);
    _auth.addListener(_onAuthStateChanged);

    // Initialize session and saved language asynchronously
    _auth.initialize();
    LanguageController.instance.loadSavedLanguage();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onAuthStateChanged() {
    if (_auth.isAuthenticated && !_auth.isTenantBoundaryBlocked) {
      _syncWorker.startPeriodicRunner();
      _syncWorker.processPendingOutbox();
    } else {
      _syncWorker.stopRunner();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _syncWorker.stopRunner();
    _api.removeListener(_onStateChanged);
    _auth.removeListener(_onAuthStateChanged);
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget homeScreen;
    if (!_auth.isAuthenticated) {
      homeScreen = LoginView(authService: _auth);
    } else if (_auth.isTenantBoundaryBlocked) {
      homeScreen = TenantBoundaryBlockedView(
        authService: _auth,
        api: _api,
      );
    } else {
      homeScreen = RoleShell(
        api: _api,
        authService: _auth,
        syncWorker: _syncWorker,
        salesV2Enabled: true,
      );
    }

    return LanguageScope(
      controller: LanguageController.instance,
      child: ListenableBuilder(
        listenable: LanguageController.instance,
        builder: (context, _) {
          final language = LanguageController.instance.currentLanguage;
          return MaterialApp(
            title: 'Routidrow FMCG Logistics',
            debugShowCheckedModeBanner: false,
            locale: language.locale,
            theme: AirbnbTheme.lightTheme,
            home: homeScreen,
          );
        },
      ),
    );
  }
}
