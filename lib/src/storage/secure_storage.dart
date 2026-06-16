import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage.dart';

/// Secure storage implementation using Flutter Secure Storage.
/// 
/// Uses the device's keychain (iOS) or encrypted shared preferences (Android)
/// to store sensitive data like authentication tokens.
class SecureStorage implements Storage {
  late final FlutterSecureStorage _storage;
  
  /// Creates a new secure storage instance.
  SecureStorage({
    String? groupId,
    String? accountName,
  }) {
    _storage = FlutterSecureStorage(
      // Explicitly use EncryptedSharedPreferences on Android (spec: user_uid /
      // tokens must be stored in EncryptedSharedPreferences, AES-256 at rest).
      // NOTE: flutter_secure_storage v11+ deprecates this flag (Jetpack Security
      // is EOL) and auto-migrates to custom AES ciphers; at our pinned v10 it is
      // still the correct way to force encryption. Revisit when bumping to v11.
      // ignore: deprecated_member_use
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        groupId: groupId,
        accountName: accountName ?? 'winr_flutter_sdk',
      ),
    );
  }
  
  @override
  Future<void> setString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }
  
  @override
  Future<String?> getString(String key) async {
    return await _storage.read(key: key);
  }
  
  @override
  Future<void> setInt(String key, int value) async {
    await _storage.write(key: key, value: value.toString());
  }
  
  @override
  Future<int?> getInt(String key) async {
    final value = await _storage.read(key: key);
    return value != null ? int.tryParse(value) : null;
  }
  
  @override
  Future<void> setBool(String key, bool value) async {
    await _storage.write(key: key, value: value.toString());
  }
  
  @override
  Future<bool?> getBool(String key) async {
    final value = await _storage.read(key: key);
    if (value == null) return null;
    return value.toLowerCase() == 'true';
  }
  
  @override
  Future<void> remove(String key) async {
    await _storage.delete(key: key);
  }
  
  @override
  Future<void> clear() async {
    await _storage.deleteAll();
  }
  
  @override
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }
  
  /// Gets the current authentication token.
  Future<String?> getAuthToken() => getString(StorageKeys.authToken);
  
  /// Saves the authentication token.
  Future<void> saveAuthToken(String token) => setString(StorageKeys.authToken, token);
  
  /// Gets the refresh token.
  Future<String?> getRefreshToken() => getString(StorageKeys.refreshToken);
  
  /// Saves the refresh token.
  Future<void> saveRefreshToken(String token) => setString(StorageKeys.refreshToken, token);
  
  /// Gets the user UUID.
  Future<String?> getUserUuid() => getString(StorageKeys.userUuid);
  
  /// Saves the user UUID.
  Future<void> saveUserUuid(String uuid) => setString(StorageKeys.userUuid, uuid);
  
  /// Checks if the stored session token (JWT) is expired.
  ///
  /// Decodes the JWT payload's `exp` claim (seconds since epoch, per RFC 7519)
  /// and compares against the current time. A malformed/missing token or a
  /// missing `exp` is treated as expired (fail-closed) so the caller refreshes.
  Future<bool> isTokenExpired() async {
    final token = await getAuthToken();
    if (token == null) return true;
    return isJwtExpired(token);
  }

  /// Returns true if [token] is not a well-formed JWT, or its `exp` claim is in
  /// the past (with a small clock-skew leeway). Fails closed on any parse error.
  static bool isJwtExpired(String token, {Duration leeway = const Duration(seconds: 30)}) {
    try {
      final parts = token.split('.');
      // JWT structure must be header.payload.signature.
      if (parts.length != 3) return true;

      final payloadJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payload = jsonDecode(payloadJson);
      if (payload is! Map<String, dynamic>) return true;

      final exp = payload['exp'];
      if (exp is! int) return true;

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      return DateTime.now().toUtc().add(leeway).isAfter(expiry);
    } catch (_) {
      // Malformed token → treat as expired so we trigger a refresh.
      return true;
    }
  }
  
  /// Deletes all authentication data.
  Future<void> deleteAuthData() async {
    await remove(StorageKeys.authToken);
    await remove(StorageKeys.refreshToken);
    await remove(StorageKeys.userUuid);
  }
}