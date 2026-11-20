import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dealker_vendor/core/constants/storage_keys.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  /// The access token is read for EVERY HTTP request (an auth header) and the home screen fires ~15 at once.
  /// Hitting the platform keychain / Android keystore each time costs a native round-trip + decryption per call,
  /// so the value is read once and kept in memory. Every write goes through this class, which keeps it in sync;
  /// concurrent first reads share one in-flight read.
  Future<String?>? _accessToken;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = Future<String?>.value(accessToken); // new requests use it at once, even before the disk write ends
    await _storage.write(
      key: StorageKeys.accessToken,
      value: accessToken,
    );
    await _storage.write(
      key: StorageKeys.refreshToken,
      value: refreshToken,
    );
  }

  Future<String?> getAccessToken() {
    return _accessToken ??= _storage
        .read(key: StorageKeys.accessToken)
        .catchError((Object e) {
      _accessToken = null; // never remember a failed read
      throw e;
    });
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: StorageKeys.refreshToken);
  }

  Future<void> saveUserId(String userId) {
    return _storage.write(
      key: StorageKeys.userId,
      value: userId,
    );
  }

  Future<String?> getUserId() {
    return _storage.read(key: StorageKeys.userId);
  }

  Future<void> saveVendorProfile({String? vendorId, String? name}) async {
    if (vendorId != null) {
      await _storage.write(key: StorageKeys.vendorId, value: vendorId);
    }
    if (name != null) {
      await _storage.write(key: StorageKeys.displayName, value: name);
    }
  }

  Future<String?> getVendorId() => _storage.read(key: StorageKeys.vendorId);

  Future<String?> getDisplayName() =>
      _storage.read(key: StorageKeys.displayName);

  Future<void> clearAll() async {
    _accessToken = Future<String?>.value(null);
    await _storage.deleteAll();
  }
}
