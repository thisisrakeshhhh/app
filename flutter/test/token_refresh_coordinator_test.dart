import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/domain/auth/auth_exceptions.dart';
import 'package:lala_distributor/domain/auth/token_refresh_coordinator.dart';

void main() {
  group('TokenRefreshCoordinator Tests', () {
    test('1. Valid, non-expired token returns immediately without invoking refresh callback', () async {
      final coordinator = TokenRefreshCoordinator();
      coordinator.setAccessToken(
        'valid_access_token',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      var refreshCallCount = 0;
      final token = await coordinator.getOrRefreshToken(() async {
        refreshCallCount++;
        return const TokenRefreshResult(
          accessToken: 'refreshed_token',
          refreshToken: 'new_ref',
        );
      });

      expect(token, 'valid_access_token');
      expect(refreshCallCount, 0);
    });

    test('2. Missing or expired token triggers refresh callback and updates RAM state', () async {
      final coordinator = TokenRefreshCoordinator();
      // Initially no token
      var refreshCallCount = 0;
      final token = await coordinator.getOrRefreshToken(() async {
        refreshCallCount++;
        return TokenRefreshResult(
          accessToken: 'new_token_from_refresh',
          refreshToken: 'new_refresh_token',
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        );
      });

      expect(token, 'new_token_from_refresh');
      expect(refreshCallCount, 1);
      expect(coordinator.currentAccessToken, 'new_token_from_refresh');
    });

    test('3. CONCURRENT REFRESH MUTEX: Parallel callers trigger exactly ONE network refresh', () async {
      final coordinator = TokenRefreshCoordinator();
      var networkCallCount = 0;

      // Simulate a refresh call that takes 50 milliseconds to complete
      Future<TokenRefreshResult> slowNetworkRefresh() async {
        networkCallCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return TokenRefreshResult(
          accessToken: 'deduplicated_jwt_token',
          refreshToken: 'deduplicated_ref_token',
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        );
      }

      // 5 concurrent requests hit getOrRefreshToken simultaneously
      final future1 = coordinator.getOrRefreshToken(slowNetworkRefresh);
      final future2 = coordinator.getOrRefreshToken(slowNetworkRefresh);
      final future3 = coordinator.getOrRefreshToken(slowNetworkRefresh);
      final future4 = coordinator.getOrRefreshToken(slowNetworkRefresh);
      final future5 = coordinator.getOrRefreshToken(slowNetworkRefresh);

      final results = await Future.wait([future1, future2, future3, future4, future5]);

      // All 5 callers get the exact same token
      for (final r in results) {
        expect(r, 'deduplicated_jwt_token');
      }

      // CRITICAL INVARIANT: The network call was executed exactly once
      expect(networkCallCount, 1);
    });

    test('4. Token safety buffer: token expiring in 30 seconds is treated as expired', () {
      final coordinator = TokenRefreshCoordinator();
      // Set token that expires in 30 seconds (default safety buffer is 60s)
      coordinator.setAccessToken(
        'near_expired_token',
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );

      expect(coordinator.isTokenExpired(), isTrue);

      // Set token that expires in 5 minutes
      coordinator.setAccessToken(
        'fresh_token',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      expect(coordinator.isTokenExpired(), isFalse);
    });

    test('5. clearAccessToken wipes token and expiry from memory immediately', () {
      final coordinator = TokenRefreshCoordinator();
      coordinator.setAccessToken(
        'secret_token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(coordinator.hasAccessToken, isTrue);
      coordinator.clearAccessToken();

      expect(coordinator.hasAccessToken, isFalse);
      expect(coordinator.currentAccessToken, isNull);
      expect(coordinator.tokenExpiresAt, isNull);
    });

    test('6. RefreshTokenReuseException wipes RAM access token immediately on error', () async {
      final coordinator = TokenRefreshCoordinator();
      coordinator.setAccessToken('old_token');

      await expectLater(
        coordinator.forceRefresh(() async {
          throw const RefreshTokenReuseException('Security alert: Token reuse');
        }),
        throwsA(isA<RefreshTokenReuseException>()),
      );

      // RAM token must be wiped
      expect(coordinator.hasAccessToken, isFalse);
      expect(coordinator.currentAccessToken, isNull);
    });

    test('7. toString() never exposes sensitive tokens in logs or crash reporters', () {
      final coordinator = TokenRefreshCoordinator();
      coordinator.setAccessToken('SUPER_SECRET_BEARER_TOKEN_9999');

      final description = coordinator.toString();
      expect(description.contains('SUPER_SECRET_BEARER_TOKEN_9999'), isFalse);
      expect(description, contains('hasToken: true'));
    });
  });
}
