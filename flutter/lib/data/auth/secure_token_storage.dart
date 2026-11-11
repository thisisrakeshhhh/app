import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/auth/auth_exceptions.dart';
import '../../domain/auth/auth_models.dart';

/// Secure token storage contract for RouteFlow.
///
/// CRITICAL SECURITY REQUIREMENT:
/// Short-lived access tokens MUST NOT be persisted to disk. They live strictly in RAM.
/// Only the refresh token and non-sensitive session claims are stored securely via this abstraction.
/// Standard SharedPreferences and plain files must never be used for sensitive tokens.
abstract class SecureTokenStorage {
  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();
  Future<void> deleteRefreshToken();
  Future<void> saveUserSession(UserSession session);
  Future<UserSession?> getUserSession();
  Future<void> deleteUserSession();
  Future<void> clearAll();
}

/// In-memory token storage for testing and memory-only environments.
class InMemoryTokenStorage implements SecureTokenStorage {
  String? _refreshToken;
  UserSession? _userSession;

  @override
  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
  }

  @override
  Future<String?> getRefreshToken() async {
    return _refreshToken;
  }

  @override
  Future<void> deleteRefreshToken() async {
    _refreshToken = null;
  }

  @override
  Future<void> saveUserSession(UserSession session) async {
    _userSession = session;
  }

  @override
  Future<UserSession?> getUserSession() async {
    return _userSession;
  }

  @override
  Future<void> deleteUserSession() async {
    _userSession = null;
  }

  @override
  Future<void> clearAll() async {
    _refreshToken = null;
    _userSession = null;
  }
}

/// Production secure token storage backed by [FlutterSecureStorage].
///
/// On Android, encryption keys are backed by the Android Keystore system.
/// [AndroidOptions.encryptedSharedPreferences] activates AndroidX EncryptedSharedPreferences,
/// wrapping keys with AES-256-GCM / MasterKey.
///
/// SECURITY ARCHITECTURE & LIMITATIONS:
/// 1. Hardware vs Software Protection:
///    On Android 10+ (API 29+), devices featuring a hardware Trusted Execution Environment (TEE)
///    or StrongBox Keymaster protect the master encryption key in hardware. On lower-end or virtual
///    devices lacking TEE/StrongBox, keys may be software-backed.
/// 2. Key Invalidation on Lockscreen Removal:
///    If the device lockscreen is disabled or reset, Android Keystore may invalidate existing keys.
///    This implementation fails closed by throwing [KeystoreInaccessibleException], requiring safe re-login.
/// 3. Zero Plaintext Fallback:
///    Under no circumstances are refresh tokens downgraded to unencrypted files or SharedPreferences.
class EncryptedSecureTokenStorage implements SecureTokenStorage {
  final FlutterSecureStorage _storage;

  static const String _keyRefreshToken = 'routeflow_refresh_token_v2';
  static const String _keyUserSession = 'routeflow_user_session_v2';

  EncryptedSecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: false, // Strict: fail closed on Keystore error
              ),
            );

  @override
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
    } catch (e) {
      throw AuthException(
        'Failed to securely persist token via Android Keystore: $e',
        code: 'KEYSTORE_WRITE_FAILED',
      );
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      // Missing, corrupted or invalidated Keystore key
      // Fail closed: require safe re-authentication without plaintext fallback
      throw const KeystoreInaccessibleException(
        'Android Keystore credentials inaccessible or invalidated. Safe re-authentication required.',
      );
    }
  }

  @override
  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _keyRefreshToken);
    } catch (_) {
      // Best-effort deletion
    }
  }

  @override
  Future<void> saveUserSession(UserSession session) async {
    try {
      await _storage.write(
        key: _keyUserSession,
        value: jsonEncode(session.toJson()),
      );
    } catch (_) {
      // Non-fatal session persistence
    }
  }

  @override
  Future<UserSession?> getUserSession() async {
    try {
      final raw = await _storage.read(key: _keyUserSession);
      if (raw == null || raw.isEmpty) return null;
      return UserSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteUserSession() async {
    try {
      await _storage.delete(key: _keyUserSession);
    } catch (_) {
      // Best-effort deletion
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Best-effort deletion
    }
  }
}
