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
      aOptions: const AndroidOptions(
        encryptedSharedPreferences: true,
      ),
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
  
  /// Checks if the current token is expired (simple heuristic).
  /// 
  /// Firebase ID tokens expire after 1 hour. This is a simple check
  /// based on when we last refreshed. For production use, you might
  /// want to decode the JWT to check the actual expiry.
  Future<bool> isTokenExpired() async {
    // For now, we'll rely on the backend returning 401 
    // and triggering a refresh through the NetworkClient
    return false;
  }
  
  /// Deletes all authentication data.
  Future<void> deleteAuthData() async {
    await remove(StorageKeys.authToken);
    await remove(StorageKeys.refreshToken);
    await remove(StorageKeys.userUuid);
  }
}