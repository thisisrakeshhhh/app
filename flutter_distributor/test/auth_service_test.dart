import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/auth/auth_repository.dart';
import 'package:lala_distributor/data/auth/secure_token_storage.dart';
import 'package:lala_distributor/domain/auth/auth_exceptions.dart';
import 'package:lala_distributor/domain/auth/auth_models.dart';
import 'package:lala_distributor/domain/auth/tenant_boundary_gate.dart';
import 'package:lala_distributor/domain/auth/token_refresh_coordinator.dart';
import 'package:lala_distributor/services/auth_service.dart';

void main() {
  const testBaseUrl = 'https://routeflow-api-staging.workers.dev';

  String makeJwt({
    int expiresInSeconds = 3600,
    String companyId = 'comp_jodhpur',
    String role = 'SALES',
  }) {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresInSeconds;
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': 'usr_vikram_456',
      'name': 'Vikram Rathore',
      'company_id': companyId,
      'role': role,
      'exp': exp,
    })));
    return '$header.$payload.signature_abc';
  }

  group('AuthService Multi-Organization & Lifecycle Tests', () {
    test('1. Initial state is unauthenticated with empty session', () {
      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: MockClient((_) async => http.Response('', 200)));
      final storage = InMemoryTokenStorage();
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      expect(authService.state.status, AuthStatus.unauthenticated);
      expect(authService.isAuthenticated, isFalse);
      expect(authService.session, isNull);
    });

    test('2. Successful login isolates refresh token in storage and keeps access token in RAM only', () async {
      final jwt = makeJwt();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': jwt,
            'refresh_token': 'secure_refresh_token_001',
            'user': {
              'id': 'usr_vikram_456',
              'name': 'Vikram Rathore',
              'company_id': 'comp_jodhpur',
              'role': 'SALES',
            },
            'organizations': [
              {'id': 'comp_jodhpur', 'name': 'Jodhpur Hub', 'role': 'SALES'},
            ],
          }),
          200,
        );
      });

      final storage = InMemoryTokenStorage();
      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await authService.login('sales_rep', 'password123');

      expect(authService.state.status, AuthStatus.authenticated);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.session?.activeOrganizationId, 'comp_jodhpur');
      expect(authService.session?.activeRole, 'SALES');

      // Refresh token is in storage
      expect(await storage.getRefreshToken(), 'secure_refresh_token_001');

      // Access token is in RAM coordinator, NOT in persistent storage
      expect(authService.coordinator.currentAccessToken, jwt);
    });

    test('3. F-05 SAFE BLOCKING RULE: Organization switching is blocked to prevent local cross-tenant data leakage', () async {
      final jodhpurJwt = makeJwt(companyId: 'comp_jodhpur', role: 'SALES');

      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'access_token': jodhpurJwt,
              'refresh_token': 'refresh_token_multi',
              'user': {
                'id': 'usr_vikram_456',
                'name': 'Vikram Rathore',
                'company_id': 'comp_jodhpur',
                'role': 'SALES',
              },
              'organizations': [
                {'id': 'comp_jodhpur', 'name': 'Jodhpur Hub', 'role': 'SALES'},
                {'id': 'comp_jaipur', 'name': 'Jaipur Central Depot', 'role': 'WAREHOUSE'},
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final storage = InMemoryTokenStorage();
      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await authService.login('vikram', 'pass');
      expect(authService.session?.activeOrganizationId, 'comp_jodhpur');

      // Switching to a different organization is strictly blocked
      await expectLater(
        authService.switchOrganization('comp_jaipur'),
        throwsA(isA<OrganizationSwitchBlockedException>()),
      );

      // Local session and state remain untouched under Organization A
      expect(authService.session?.activeOrganizationId, 'comp_jodhpur');
      expect(authService.session?.activeRole, 'SALES');
    });

    test('4. Switching to an unauthorized organization throws error and preserves current session', () async {
      final initialJwt = makeJwt(companyId: 'comp_jodhpur', role: 'SALES');
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': initialJwt,
            'refresh_token': 'ref_token',
            'user': {
              'id': 'usr_vikram_456',
              'name': 'Vikram Rathore',
              'company_id': 'comp_jodhpur',
              'role': 'SALES',
            },
            'organizations': [
              {'id': 'comp_jodhpur', 'name': 'Jodhpur Hub', 'role': 'SALES'},
            ],
          }),
          200,
        );
      });

      final storage = InMemoryTokenStorage();
      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await authService.login('vikram', 'pass');

      // Attempt to switch to an organization not in user's memberships
      expect(
        () => authService.switchOrganization('comp_unauthorized_999'),
        throwsA(isA<UnauthorizedOrganizationException>()),
      );

      // State is preserved without corruption
      expect(authService.session?.activeOrganizationId, 'comp_jodhpur');
      expect(authService.isAuthenticated, isTrue);
    });

    test('5. Token reuse detection immediately wipes storage, clears RAM, and marks session expired', () async {
      final initialJwt = makeJwt();
      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'access_token': initialJwt,
              'refresh_token': 'compromised_refresh_token',
              'user': {'id': 'usr_1', 'name': 'User 1', 'company_id': 'comp_1', 'role': 'SALES'},
              'organizations': [{'id': 'comp_1', 'name': 'Org 1', 'role': 'SALES'}],
            }),
            200,
          );
        } else if (request.url.path == '/auth/refresh') {
          return http.Response(
            jsonEncode({'error': 'Session revoked due to token reuse'}),
            401,
          );
        }
        return http.Response('Not Found', 404);
      });

      final storage = InMemoryTokenStorage();
      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await authService.login('user', 'pass');
      expect(await storage.getRefreshToken(), 'compromised_refresh_token');

      // Expire RAM access token to force refresh
      authService.coordinator.setAccessToken('old_token', expiresAt: DateTime.now().subtract(const Duration(minutes: 5)));

      // Call getValidAccessToken, which will invoke backend refresh
      await expectLater(
        authService.getValidAccessToken(),
        throwsA(isA<RefreshTokenReuseException>()),
      );

      // Storage and RAM tokens must be wiped completely
      expect(await storage.getRefreshToken(), isNull);
      expect(authService.coordinator.hasAccessToken, isFalse);
      expect(authService.state.status, AuthStatus.sessionExpired);
    });

    test('6. Explicit logout invalidates generation, wipes RAM token, and clears secure storage', () async {
      var backendLogoutCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'access_token': makeJwt(),
              'refresh_token': 'token_to_logout',
              'user': {'id': 'usr_1', 'name': 'User 1', 'company_id': 'comp_1', 'role': 'SALES'},
              'organizations': [{'id': 'comp_1', 'name': 'Org 1', 'role': 'SALES'}],
            }),
            200,
          );
        } else if (request.url.path == '/auth/logout') {
          backendLogoutCalled = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('', 200);
      });

      final storage = InMemoryTokenStorage();
      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await authService.login('user', 'pass');
      expect(authService.isAuthenticated, isTrue);

      final genBefore = authService.sessionGeneration;
      await authService.logout();

      // Generation must be incremented synchronously
      expect(authService.sessionGeneration, greaterThan(genBefore));
      expect(backendLogoutCalled, isTrue);
      expect(await storage.getRefreshToken(), isNull);
      expect(authService.coordinator.hasAccessToken, isFalse);
      expect(authService.state.status, AuthStatus.unauthenticated);
      expect(authService.isAuthenticated, isFalse);
    });

    test('7. F-03: GET /me flat payload parsing correctly extracts sub and company_id without nested user', () async {
      final freshJwt = makeJwt(companyId: 'comp_flat_real', role: 'ADMIN');
      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          return http.Response(
            jsonEncode({
              'access_token': freshJwt,
              'refresh_token': 'rotated_flat_refresh_token',
              'user': {'id': 'usr_flat', 'name': 'Flat User', 'company_id': 'comp_flat_real', 'role': 'ADMIN'},
            }),
            200,
          );
        } else if (request.url.path == '/me') {
          // Real backend contract: flat JWT claims directly returned by c.json(user)
          return http.Response(
            jsonEncode({
              'sub': 'usr_flat_authoritative',
              'sid': 'sid_flat_999',
              'company_id': 'comp_flat_real',
              'role': 'ADMIN',
              'name': 'Authoritative Flat User',
              'exp': 1899999999,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final storage = InMemoryTokenStorage();
      await storage.saveRefreshToken('existing_stored_token');

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final authService = AuthService(
        repository: repo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await authService.initialize();

      expect(authService.isAuthenticated, isTrue);
      // Authoritative sub must be extracted, NOT empty string
      expect(authService.session?.userId, 'usr_flat_authoritative');
      expect(authService.session?.name, 'Authoritative Flat User');
      expect(authService.session?.activeOrganizationId, 'comp_flat_real');
      expect(authService.session?.activeRole, 'ADMIN');
    });

    test('8. F-04 REGRESSION 1: Refresh begins, logout occurs synchronously, late refresh cannot restore credentials', () async {
      final refreshCompleter = Completer<TokenRefreshResult>();

      // Custom fake repo where refresh can be controlled manually
      final fakeRepo = _FakeAuthRepo(
        onRefresh: () => refreshCompleter.future,
      );

      final storage = InMemoryTokenStorage();
      await storage.saveRefreshToken('initial_refresh_token');

      final authService = AuthService(
        repository: fakeRepo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );
      authService.coordinator.setAccessToken('expired_token', expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));

      // 1. Trigger asynchronous refresh
      final refreshFuture = authService.getValidAccessToken();

      // 2. Synchronous logout while refresh is in flight across the network
      await authService.logout();
      expect(authService.isAuthenticated, isFalse);
      expect(await storage.getRefreshToken(), isNull);

      // 3. Late network refresh finishes successfully
      refreshCompleter.complete(const TokenRefreshResult(
        accessToken: 'late_zombie_access_token',
        refreshToken: 'late_zombie_refresh_token',
      ));

      // 4. Awaiting refresh must throw SessionRevokedException due to generation fencing
      await expectLater(
        refreshFuture,
        throwsA(isA<SessionRevokedException>()),
      );

      // CRITICAL SECURITY INVARIANT: Late refresh must NEVER restore credentials or write to disk
      expect(authService.isAuthenticated, isFalse);
      expect(await storage.getRefreshToken(), isNull);
      expect(authService.coordinator.hasAccessToken, isFalse);
    });

    test('9. F-04 REGRESSION 2: Refresh begins, logout occurs, refresh error is safely discarded without mutating session', () async {
      final refreshCompleter = Completer<TokenRefreshResult>();

      final fakeRepo = _FakeAuthRepo(
        onRefresh: () => refreshCompleter.future,
      );

      final storage = InMemoryTokenStorage();
      await storage.saveRefreshToken('initial_token');

      final authService = AuthService(
        repository: fakeRepo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );
      authService.coordinator.setAccessToken('expired_token', expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));

      final refreshFuture = authService.getValidAccessToken();

      // Logout during refresh
      await authService.logout();

      // Late refresh fails with error
      refreshCompleter.completeError(const SessionRevokedException('Late network revocation'));

      await expectLater(
        refreshFuture,
        throwsA(isA<SessionRevokedException>()),
      );

      // Still unauthenticated
      expect(authService.isAuthenticated, isFalse);
      expect(authService.state.status, AuthStatus.unauthenticated);
    });

    test('10. F-04 REGRESSION 4: Late refresh response cannot overwrite a newly established session', () async {
      final slowRefreshCompleter = Completer<TokenRefreshResult>();
      var callCount = 0;

      final fakeRepo = _FakeAuthRepo(
        onRefresh: () {
          callCount++;
          if (callCount == 1) {
            return slowRefreshCompleter.future;
          }
          return Future.value(const TokenRefreshResult(
            accessToken: 'session_2_access_token',
            refreshToken: 'session_2_refresh_token',
          ));
        },
        onLogin: () => AuthLoginResponse(
          accessToken: 'session_2_access_token',
          refreshToken: 'session_2_refresh_token',
          session: const UserSession(
            userId: 'usr_new',
            name: 'New User',
            activeOrganizationId: 'comp_new',
            activeRole: 'SALES',
            organizations: [OrganizationMembership(id: 'comp_new', name: 'New Org', role: 'SALES')],
          ),
        ),
      );

      final storage = InMemoryTokenStorage();
      await storage.saveRefreshToken('session_1_token');

      final authService = AuthService(
        repository: fakeRepo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );
      authService.coordinator.setAccessToken('s1_expired', expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));

      // In-flight refresh for Session 1
      final slowRefreshFuture = authService.getValidAccessToken();

      // Session 1 is logged out, and Session 2 logs in
      await authService.logout();
      await authService.login('new_user', 'pass');
      expect(authService.session?.userId, 'usr_new');
      expect(authService.coordinator.currentAccessToken, 'session_2_access_token');

      // Now Session 1's slow refresh finally resolves
      slowRefreshCompleter.complete(const TokenRefreshResult(
        accessToken: 'zombie_s1_token',
        refreshToken: 'zombie_s1_refresh_token',
      ));

      await expectLater(
        slowRefreshFuture,
        throwsA(isA<SessionRevokedException>()),
      );

      // CRITICAL INVARIANT: Session 2 is NOT overwritten by Session 1's late tokens!
      expect(authService.session?.userId, 'usr_new');
      expect(authService.coordinator.currentAccessToken, 'session_2_access_token');
      expect(await storage.getRefreshToken(), 'session_2_refresh_token');
    });

    test('11. Offline session persistence: initialize restores authenticated session when network unavailable', () async {
      final storage = InMemoryTokenStorage();
      const initialSession = UserSession(
        userId: 'usr_offline_sales',
        name: 'Offline Sales Rep',
        activeOrganizationId: 'comp_offline',
        activeRole: 'SALES',
        organizations: [
          OrganizationMembership(id: 'comp_offline', name: 'Offline Org', role: 'SALES'),
        ],
      );
      await storage.saveRefreshToken('valid_offline_refresh_token');
      await storage.saveUserSession(initialSession);

      final fakeRepo = _FakeAuthRepo(
        onRefresh: () async => throw const NetworkUnavailableException('No network'),
      );

      final authService = AuthService(
        repository: fakeRepo,
        secureStorage: storage,
        tenantBoundaryGate: TenantBoundaryGate.permissiveForTesting(),
      );

      await authService.initialize();

      expect(authService.isAuthenticated, isTrue);
      expect(authService.session?.userId, 'usr_offline_sales');
      expect(authService.session?.activeRole, 'SALES');

      // Logout clears both refresh token and stored session
      await authService.logout();
      expect(authService.isAuthenticated, isFalse);
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getUserSession(), isNull);
    });
  });
}

class _FakeAuthRepo implements AuthRepository {
  final Future<TokenRefreshResult> Function()? onRefresh;
  final AuthLoginResponse Function()? onLogin;

  _FakeAuthRepo({this.onRefresh, this.onLogin});

  @override
  Future<AuthLoginResponse> login({required String username, required String password, String? deviceId}) async {
    if (onLogin != null) return onLogin!();
    throw UnimplementedError();
  }

  @override
  Future<TokenRefreshResult> refreshToken({required String refreshToken}) async {
    if (onRefresh != null) return await onRefresh!();
    return const TokenRefreshResult(accessToken: 'default_acc', refreshToken: 'default_ref');
  }

  @override
  Future<AuthSwitchOrgResponse> switchOrganization({required String organizationId, required String accessToken}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout({required String accessToken}) async {}

  @override
  Future<Map<String, dynamic>> getCurrentUser({required String accessToken}) async {
    return {
      'sub': 'usr_fake',
      'company_id': 'comp_fake',
      'role': 'SALES',
      'name': 'Fake User',
    };
  }
}
