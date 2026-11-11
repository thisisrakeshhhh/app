import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lala_distributor/data/auth/auth_repository.dart';
import 'package:lala_distributor/domain/auth/auth_exceptions.dart';

void main() {
  const testBaseUrl = 'https://routeflow-api-staging.workers.dev';

  // Helper to create valid fake JWT with exp claim (1 hour in future)
  String makeTestJwt({int expiresInSeconds = 3600, String companyId = 'comp_jodhpur', String role = 'SALES'}) {
    final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresInSeconds;
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': 'usr_test_123',
      'name': 'Vikram Rathore',
      'company_id': companyId,
      'role': role,
      'exp': exp,
    })));
    return '$header.$payload.fake_signature_bytes';
  }

  group('HttpAuthRepository Tests', () {
    test('1. Successful login parses tokens, session, and organizations correctly', () async {
      final validJwt = makeTestJwt();
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/auth/login');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['username'], 'sales_rep');
        expect(body['password'], 'secret123');

        return http.Response(
          jsonEncode({
            'access_token': validJwt,
            'refresh_token': 'ref_uuid_v4_abc123',
            'user': {
              'id': 'usr_test_123',
              'name': 'Vikram Rathore',
              'company_id': 'comp_jodhpur',
              'role': 'SALES',
            },
            'organizations': [
              {
                'id': 'comp_jodhpur',
                'name': 'Jodhpur FMCG Depot',
                'role': 'SALES',
              },
              {
                'id': 'comp_jaipur',
                'name': 'Jaipur Central Hub',
                'role': 'WAREHOUSE',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final response = await repo.login(username: 'sales_rep', password: 'secret123');

      expect(response.accessToken, validJwt);
      expect(response.refreshToken, 'ref_uuid_v4_abc123');
      expect(response.session.userId, 'usr_test_123');
      expect(response.session.name, 'Vikram Rathore');
      expect(response.session.activeOrganizationId, 'comp_jodhpur');
      expect(response.session.activeRole, 'SALES');
      expect(response.session.organizations.length, 2);
      expect(response.session.organizations[0].name, 'Jodhpur FMCG Depot');
      expect(response.session.organizations[1].name, 'Jaipur Central Hub');
      expect(response.expiresAt, isNotNull);
    });

    test('2. Invalid username or password (HTTP 401) throws InvalidCredentialsException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Invalid username or password'}), 401);
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      expect(
        () => repo.login(username: 'bad_user', password: 'bad_password'),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });

    test('3. Account disabled (HTTP 403) throws AccountDisabledException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Account is disabled'}), 403);
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      expect(
        () => repo.login(username: 'disabled_user', password: 'password'),
        throwsA(isA<AccountDisabledException>()),
      );
    });

    test('4. Rate limited (HTTP 429) throws RateLimitedException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Too many requests'}), 429);
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      expect(
        () => repo.login(username: 'spammer', password: 'password'),
        throwsA(isA<RateLimitedException>()),
      );
    });

    test('5. Malformed payload missing required token fields throws MalformedTokenException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'only_user': 'no_tokens_here'}), 200);
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      expect(
        () => repo.login(username: 'user', password: 'pass'),
        throwsA(isA<MalformedTokenException>()),
      );
    });

    test('6. Successful token refresh rotates access and refresh tokens', () async {
      final newJwt = makeTestJwt();
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/auth/refresh');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['refresh_token'], 'old_refresh_token_xyz');

        return http.Response(
          jsonEncode({
            'access_token': newJwt,
            'refresh_token': 'new_rotated_refresh_token_uvw',
            'user': {
              'id': 'usr_test_123',
              'name': 'Vikram Rathore',
              'company_id': 'comp_jodhpur',
              'role': 'SALES',
            },
          }),
          200,
        );
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final result = await repo.refreshToken(refreshToken: 'old_refresh_token_xyz');

      expect(result.accessToken, newJwt);
      expect(result.refreshToken, 'new_rotated_refresh_token_uvw');
      expect(result.expiresAt, isNotNull);
    });

    test('7. Refresh token reuse detection (HTTP 401 with reuse indicator) throws RefreshTokenReuseException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Session revoked due to token reuse'}),
          401,
        );
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      expect(
        () => repo.refreshToken(refreshToken: 'reused_compromised_token'),
        throwsA(isA<RefreshTokenReuseException>()),
      );
    });

    test('8. Normal token expiry or revocation (HTTP 401) throws SessionRevokedException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Invalid or expired refresh token'}), 401);
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      expect(
        () => repo.refreshToken(refreshToken: 'expired_token'),
        throwsA(isA<SessionRevokedException>()),
      );
    });

    test('9. Successful organization switch returns new access token and scoped role', () async {
      final jaipurJwt = makeTestJwt(companyId: 'comp_jaipur', role: 'WAREHOUSE');
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/auth/switch-organization');
        expect(request.headers['Authorization'], 'Bearer initial_token_abc');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['organization_id'], 'comp_jaipur');

        return http.Response(
          jsonEncode({
            'access_token': jaipurJwt,
            'user': {
              'id': 'usr_test_123',
              'name': 'Vikram Rathore',
              'company_id': 'comp_jaipur',
              'role': 'WAREHOUSE',
            },
          }),
          200,
        );
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      final result = await repo.switchOrganization(
        organizationId: 'comp_jaipur',
        accessToken: 'initial_token_abc',
      );

      expect(result.accessToken, jaipurJwt);
      expect(result.organizationId, 'comp_jaipur');
      expect(result.role, 'WAREHOUSE');
    });

    test('10. Switch organization without authorization (HTTP 403) throws UnauthorizedOrganizationException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Not a member of this organization'}),
          403,
        );
      });

      final repo = HttpAuthRepository(baseUrl: testBaseUrl, client: mockClient);
      expect(
        () => repo.switchOrganization(organizationId: 'comp_unauthorized', accessToken: 'token'),
        throwsA(isA<UnauthorizedOrganizationException>()),
      );
    });

    test('11. JWT expiration parser parses valid exp and handles invalid strings gracefully', () {
      final validJwt = makeTestJwt(expiresInSeconds: 7200);
      final parsed = HttpAuthRepository.parseTokenExpiry(validJwt);
      expect(parsed, isNotNull);
      expect(parsed!.isAfter(DateTime.now().add(const Duration(minutes: 110))), isTrue);

      expect(HttpAuthRepository.parseTokenExpiry('invalid.jwt'), isNull);
      expect(HttpAuthRepository.parseTokenExpiry(''), isNull);
    });
  });
}
