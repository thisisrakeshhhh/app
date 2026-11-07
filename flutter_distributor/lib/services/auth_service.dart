import 'package:flutter/foundation.dart';
import '../data/auth/auth_repository.dart';
import '../data/auth/secure_token_storage.dart';
import '../domain/auth/auth_exceptions.dart';
import '../domain/auth/auth_models.dart';
import '../domain/auth/tenant_boundary_gate.dart';
import '../domain/auth/token_refresh_coordinator.dart';

/// Central service managing RouteFlow authentication lifecycle,
/// multi-organization switching restrictions, and token rotation with generation fencing.
class AuthService extends ChangeNotifier {
  final AuthRepository repository;
  final SecureTokenStorage secureStorage;
  final TokenRefreshCoordinator _coordinator;
  final TenantBoundaryGate tenantBoundaryGate;
  final Future<void> Function()? onLogoutCleanup;

  AuthState _state = const AuthState.unauthenticated();
  int _sessionGeneration = 0;

  AuthService({
    required this.repository,
    required this.secureStorage,
    required this.tenantBoundaryGate,
    TokenRefreshCoordinator? coordinator,
    this.onLogoutCleanup,
  })  : _coordinator = coordinator ?? TokenRefreshCoordinator();

  AuthState get state => _state;
  UserSession? get session => _state.session;
  bool get isAuthenticated => _state.isAuthenticated;
  bool get isTenantBoundaryBlocked => _state.status == AuthStatus.tenantBoundaryBlocked;
  List<OrganizationMembership> get organizations => _state.session?.organizations ?? [];
  OrganizationMembership? get activeOrganization => _state.session?.activeMembership;
  String? get currentRole => _state.session?.activeRole;
  int get sessionGeneration => _sessionGeneration;

  @visibleForTesting
  TokenRefreshCoordinator get coordinator => _coordinator;

  /// Initialize session from secure storage (e.g. at app launch).
  Future<void> initialize() async {
    final capturedGen = _sessionGeneration;
    final String? storedRefreshToken;
    final UserSession? storedSession;
    try {
      storedRefreshToken = await secureStorage.getRefreshToken();
      storedSession = await secureStorage.getUserSession();
    } on KeystoreInaccessibleException catch (e) {
      await _handleSessionRevocation(e.message, generation: capturedGen);
      return;
    }

    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      _state = const AuthState.unauthenticated();
      notifyListeners();
      return;
    }

    try {
      // 1. Refresh tokens to verify active validity and obtain fresh access token
      final refreshResult = await repository.refreshToken(refreshToken: storedRefreshToken);

      // Generation fence check
      if (capturedGen != _sessionGeneration) return;

      await secureStorage.saveRefreshToken(refreshResult.refreshToken);
      _coordinator.setAccessToken(
        refreshResult.accessToken,
        expiresAt: refreshResult.expiresAt,
      );

      // 2. Fetch current user context via GET /me
      final userContext = await repository.getCurrentUser(
        accessToken: refreshResult.accessToken,
      );

      // Generation fence check
      if (capturedGen != _sessionGeneration) return;

      // F-03: Authoritative flat claims extraction from GET /me
      // Contract: { sub, sid, company_id, role, name, exp }
      final userObj = userContext['user'] as Map<String, dynamic>?;
      final userId = (userContext['sub'] as String? ?? userObj?['id'] as String? ?? '').trim();
      if (userId.isEmpty) {
        throw const MalformedTokenException('Invalid identity payload: missing authoritative user ID (sub)');
      }

      final activeOrgId = (userContext['company_id'] as String? ?? userObj?['company_id'] as String? ?? '').trim();
      if (activeOrgId.isEmpty) {
        throw const MalformedTokenException('Invalid identity payload: missing authoritative company_id');
      }

      final activeRole = (userContext['role'] as String? ?? userObj?['role'] as String? ?? '').trim();
      if (activeRole.isEmpty) {
        throw const MalformedTokenException('Invalid identity payload: missing authoritative role');
      }

      final userName = (userContext['name'] as String? ?? userObj?['name'] as String? ?? userContext['username'] as String? ?? 'Authorized User').trim();

      final orgs = [
        OrganizationMembership(
          id: activeOrgId,
          name: activeOrgId,
          role: activeRole,
        )
      ];

      final userSession = UserSession(
        userId: userId,
        name: userName,
        activeOrganizationId: activeOrgId,
        activeRole: activeRole,
        organizations: orgs,
        tokenExpiresAt: refreshResult.expiresAt,
      );

      await secureStorage.saveUserSession(userSession);

      final assessment = await tenantBoundaryGate.assessBoundary();
      if (capturedGen != _sessionGeneration) return;
      if (assessment.isBlocked) {
        _state = AuthState.tenantBoundaryBlocked(userSession, assessment.message);
        notifyListeners();
        return;
      }

      _state = AuthState.authenticated(userSession);
      notifyListeners();
    } on RefreshTokenReuseException catch (e) {
      await _handleSessionRevocation(e.message, generation: capturedGen);
    } on SessionRevokedException catch (e) {
      await _handleSessionRevocation(e.message, generation: capturedGen);
    } on NetworkUnavailableException {
      if (capturedGen == _sessionGeneration) {
        if (storedSession != null) {
          final assessment = await tenantBoundaryGate.assessBoundary();
          if (capturedGen != _sessionGeneration) return;
          if (assessment.isBlocked) {
            _state = AuthState.tenantBoundaryBlocked(storedSession, assessment.message);
          } else {
            _state = AuthState.authenticated(storedSession);
          }
        } else {
          _state = AuthState.networkUnavailable(_state.session);
        }
        notifyListeners();
      }
    } catch (e) {
      if (capturedGen == _sessionGeneration) {
        if (kDebugMode) {
          debugPrint('Auth initialization error: $e');
        }
        _state = const AuthState.unauthenticated('Failed to initialize session');
        notifyListeners();
      }
    }
  }

  /// Authenticate with username and password.
  Future<void> login(String username, String password, {String? deviceId}) async {
    final capturedGen = ++_sessionGeneration;
    _state = const AuthState.authenticating();
    notifyListeners();

    try {
      final response = await repository.login(
        username: username,
        password: password,
        deviceId: deviceId,
      );

      // Verify generation before persisting rotated token or state
      if (capturedGen != _sessionGeneration) return;

      // 1. Securely isolate refresh token in Keystore-backed storage
      await secureStorage.saveRefreshToken(response.refreshToken);

      // 2. Keep access token exclusively in RAM
      _coordinator.setAccessToken(
        response.accessToken,
        expiresAt: response.expiresAt,
      );

      // 3. Set authenticated session
      final session = response.session;
      if (session.organizations.isEmpty) {
        _state = const AuthState.unauthenticated(
          'Account is not assigned to any distributor organization.',
        );
      } else {
        await secureStorage.saveUserSession(session);
        final assessment = await tenantBoundaryGate.assessBoundary();
        if (capturedGen != _sessionGeneration) return;
        if (assessment.isBlocked) {
          _state = AuthState.tenantBoundaryBlocked(session, assessment.message);
          notifyListeners();
          return;
        }
        _state = AuthState.authenticated(session);
      }
      notifyListeners();
    } on InvalidCredentialsException catch (e) {
      if (capturedGen == _sessionGeneration) {
        _state = AuthState.unauthenticated(e.message);
        notifyListeners();
      }
      rethrow;
    } on AccountDisabledException catch (e) {
      if (capturedGen == _sessionGeneration) {
        _state = AuthState.unauthenticated(e.message);
        notifyListeners();
      }
      rethrow;
    } on NetworkUnavailableException catch (e) {
      if (capturedGen == _sessionGeneration) {
        _state = AuthState.unauthenticated(e.message);
        notifyListeners();
      }
      rethrow;
    } catch (e) {
      if (capturedGen == _sessionGeneration) {
        _state = AuthState.unauthenticated('Login error: $e');
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Switch active organization tenant.
  ///
  /// F-05 SAFE BLOCKING RULE:
  /// Drift SQLite database schema v2 maintains unscoped B1 tables (products, retailers,
  /// inventory_snapshots, inventory_movements). Switching organization without multi-tenant SQLite
  /// partitioning would cause cross-tenant data leakage or destructive data truncation.
  /// Organization switching is strictly blocked at the service layer until Phase B2.2.
  Future<void> switchOrganization(String targetOrgId) async {
    final currentSession = _state.session;
    if (currentSession == null) {
      throw const SessionRevokedException('Cannot switch organization without an active session.');
    }

    if (currentSession.activeOrganizationId == targetOrgId) {
      return; // Already in target organization
    }

    // Verify membership exists in active user session
    final targetMembership = currentSession.organizations.cast<OrganizationMembership?>().firstWhere(
          (o) => o?.id == targetOrgId,
          orElse: () => null,
        );

    if (targetMembership == null) {
      throw const UnauthorizedOrganizationException(
        'User does not belong to the selected distributor organization.',
      );
    }

    // SAFE BLOCKING RULE (v1.3.2 Architecture Enforcement)
    throw const OrganizationSwitchBlockedException(
      'Multi-tenant distributor switching is deferred to Phase B2.2 pending local multi-tenant database migration. Switching active distributor is blocked to prevent local cross-tenant data leakage.',
    );
  }

  /// Switch active role for live demo & cross-role testing.
  void switchRoleForDemo(String newRole) {
    final s = _state.session;
    if (s != null) {
      final updated = s.copyWith(activeRole: newRole);
      _state = AuthState.authenticated(updated);
      notifyListeners();
    }
  }

  /// Acquires a valid, non-expired access token from RAM, coordinating concurrent refreshes.
  /// Enforces session-generation fencing against stale or late refresh responses.
  Future<String> getValidAccessToken() async {
    final capturedGen = _sessionGeneration;

    return await _coordinator.getOrRefreshToken(() async {
      // 1. Verify generation before starting
      if (capturedGen != _sessionGeneration) {
        throw const SessionRevokedException('Token refresh aborted: session was invalidated.');
      }

      final storedRefreshToken = await secureStorage.getRefreshToken();
      if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
        throw const SessionRevokedException('No refresh token present. Please log in.');
      }

      try {
        final result = await repository.refreshToken(refreshToken: storedRefreshToken);

        // 2. GENERATION FENCING: Verify captured generation before persisting rotated token!
        if (capturedGen != _sessionGeneration) {
          throw const SessionRevokedException('Token refresh discarded: session was invalidated during refresh.');
        }

        // Persist newly rotated refresh token
        await secureStorage.saveRefreshToken(result.refreshToken);
        return result;
      } on RefreshTokenReuseException catch (e) {
        await _handleSessionRevocation(e.message, generation: capturedGen);
        rethrow;
      } on SessionRevokedException catch (e) {
        await _handleSessionRevocation(e.message, generation: capturedGen);
        rethrow;
      }
    });
  }

  /// Terminate session, revoking backend tokens and wiping all local state.
  /// F-04: Session generation is invalidated synchronously before any async operations.
  Future<void> logout() async {
    // 1. Invalidate session generation SYNCHRONOUSLY to fence any in-flight refresh calls
    _sessionGeneration++;
    _state = const AuthState(status: AuthStatus.loggingOut);
    notifyListeners();

    // 2. Clear transient in-memory business state (cart, orders, stops)
    if (onLogoutCleanup != null) {
      try {
        await onLogoutCleanup!();
      } catch (_) {}
    }

    final currentToken = _coordinator.currentAccessToken;

    // 2. Clear RAM access token immediately
    _coordinator.clearAccessToken();

    // 3. Delete persisted credentials locally
    try {
      await secureStorage.clearAll();
    } catch (_) {}

    // 4. Best-effort remote revocation (failure must not leave user locally authenticated)
    if (currentToken != null && currentToken.isNotEmpty) {
      try {
        await repository.logout(accessToken: currentToken);
      } catch (_) {
        // Discard remote network error; local logout has already succeeded
      }
    }

    _state = const AuthState.unauthenticated();
    notifyListeners();
  }

  /// Internal handler for security revocation events (e.g. token reuse detected).
  /// F-04: Fenced by session generation so obsolete errors cannot overwrite newer sessions.
  Future<void> _handleSessionRevocation(String reason, {required int generation}) async {
    if (generation != _sessionGeneration) {
      // Obsolete generation error: discard safely
      return;
    }
    _sessionGeneration++;
    _coordinator.clearAccessToken();
    try {
      await secureStorage.clearAll();
    } catch (_) {}
    _state = AuthState.sessionExpired(reason);
    notifyListeners();
  }
}
