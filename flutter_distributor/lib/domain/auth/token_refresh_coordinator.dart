import 'dart:async';
import 'auth_exceptions.dart';

/// Result container returned by refresh token HTTP operations.
class TokenRefreshResult {
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  const TokenRefreshResult({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });
}

/// Coordinates in-memory access token lifecycle and deduplicates concurrent refresh calls.
///
/// Ensures that when multiple parallel requests hit 401 or detect token expiry,
/// only ONE HTTP POST /auth/refresh is dispatched to the backend. All waiting requests
/// await the single in-flight future and reuse the rotated access token.
///
/// SECURITY INVARIANT:
/// Access tokens are stored exclusively in RAM and are never persisted to disk.
class TokenRefreshCoordinator {
  String? _accessToken;
  DateTime? _tokenExpiresAt;
  Future<String>? _activeRefreshFuture;

  /// Returns whether a valid in-memory access token is present.
  bool get hasAccessToken => _accessToken != null && _accessToken!.isNotEmpty;

  /// Returns current in-memory access token (RAM only).
  String? get currentAccessToken => _accessToken;

  /// Expiry timestamp for the active access token.
  DateTime? get tokenExpiresAt => _tokenExpiresAt;

  /// Set or update the in-memory access token.
  void setAccessToken(String token, {DateTime? expiresAt}) {
    _accessToken = token;
    _tokenExpiresAt = expiresAt;
  }

  /// Wipes access token from memory immediately.
  void clearAccessToken() {
    _accessToken = null;
    _tokenExpiresAt = null;
    _activeRefreshFuture = null;
  }

  /// Checks if token is expired or will expire within [buffer].
  bool isTokenExpired({Duration buffer = const Duration(seconds: 60)}) {
    if (_accessToken == null) return true;
    if (_tokenExpiresAt == null) return false;
    return DateTime.now().isAfter(_tokenExpiresAt!.subtract(buffer));
  }

  /// Acquires an access token, deduplicating concurrent refresh attempts via a mutex Future.
  ///
  /// If the current token is valid, returns it immediately without network activity.
  /// If expired or missing, triggers [onRefresh] under a concurrency lock.
  Future<String> getOrRefreshToken(Future<TokenRefreshResult> Function() onRefresh) async {
    // 1. If we have a valid token that is not expired, return immediately
    if (hasAccessToken && !isTokenExpired()) {
      return _accessToken!;
    }

    // 2. If a refresh is already in progress, wait for the existing future
    if (_activeRefreshFuture != null) {
      return await _activeRefreshFuture!;
    }

    // 3. Initiate single refresh mutex future
    final completer = Completer<String>();
    completer.future.ignore();
    _activeRefreshFuture = completer.future;

    try {
      final result = await onRefresh();
      setAccessToken(result.accessToken, expiresAt: result.expiresAt);
      completer.complete(result.accessToken);
      return result.accessToken;
    } catch (e) {
      // If refresh failed due to token reuse, wipe access token immediately
      if (e is RefreshTokenReuseException) {
        clearAccessToken();
      }
      completer.completeError(e);
      rethrow;
    } finally {
      _activeRefreshFuture = null;
    }
  }

  /// Force a token refresh, deduplicating any concurrent callers.
  Future<String> forceRefresh(Future<TokenRefreshResult> Function() onRefresh) async {
    if (_activeRefreshFuture != null) {
      return await _activeRefreshFuture!;
    }

    final completer = Completer<String>();
    completer.future.ignore();
    _activeRefreshFuture = completer.future;

    try {
      final result = await onRefresh();
      setAccessToken(result.accessToken, expiresAt: result.expiresAt);
      completer.complete(result.accessToken);
      return result.accessToken;
    } catch (e) {
      if (e is RefreshTokenReuseException) {
        clearAccessToken();
      }
      completer.completeError(e);
      rethrow;
    } finally {
      _activeRefreshFuture = null;
    }
  }

  @override
  String toString() =>
      'TokenRefreshCoordinator(hasToken: $hasAccessToken, expiresAt: $_tokenExpiresAt)';
}
