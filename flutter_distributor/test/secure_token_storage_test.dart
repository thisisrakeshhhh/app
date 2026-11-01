import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lala_distributor/data/auth/secure_token_storage.dart';
import 'package:lala_distributor/domain/auth/auth_exceptions.dart';

class _FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> data = {};
  bool throwOnRead = false;
  bool throwOnWrite = false;

  _FakeFlutterSecureStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    if (throwOnWrite) throw Exception('Keystore write failed: keymaster error');
    if (value != null) {
      data[key] = value;
    } else {
      data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    if (throwOnRead) throw Exception('Keystore inaccessible: UserNotAuthenticatedException');
    return data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    data.clear();
  }
}

void main() {
  group('SecureTokenStorage & Android Keystore Contract Tests', () {
    test('1. EncryptedSecureTokenStorage saves and reads tokens securely', () async {
      final fakeStorage = _FakeFlutterSecureStorage();
      final storage = EncryptedSecureTokenStorage(storage: fakeStorage);

      await storage.saveRefreshToken('test_refresh_token_xyz');
      expect(fakeStorage.data['routeflow_refresh_token_v2'], 'test_refresh_token_xyz');

      final retrieved = await storage.getRefreshToken();
      expect(retrieved, 'test_refresh_token_xyz');
    });

    test('2. F-01: Keystore read failure fails closed with KeystoreInaccessibleException without plaintext fallback', () async {
      final fakeStorage = _FakeFlutterSecureStorage();
      fakeStorage.throwOnRead = true;
      final storage = EncryptedSecureTokenStorage(storage: fakeStorage);

      await expectLater(
        storage.getRefreshToken(),
        throwsA(isA<KeystoreInaccessibleException>()),
      );
    });

    test('3. F-01: Keystore write failure fails closed with AuthException', () async {
      final fakeStorage = _FakeFlutterSecureStorage();
      fakeStorage.throwOnWrite = true;
      final storage = EncryptedSecureTokenStorage(storage: fakeStorage);

      await expectLater(
        storage.saveRefreshToken('sample_token'),
        throwsA(isA<AuthException>()),
      );
    });

    test('4. Secure deletion deletes tokens from Keystore storage', () async {
      final fakeStorage = _FakeFlutterSecureStorage();
      final storage = EncryptedSecureTokenStorage(storage: fakeStorage);

      await storage.saveRefreshToken('token_to_delete');
      expect(await storage.getRefreshToken(), 'token_to_delete');

      await storage.deleteRefreshToken();
      expect(await storage.getRefreshToken(), isNull);
    });
  });
}
