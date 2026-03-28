/// Abstract interface for data storage operations.
/// 
/// Provides a unified interface for both secure storage (keychain/encrypted)
/// and regular preferences storage.
abstract class Storage {
  /// Saves a string value with the given key.
  Future<void> setString(String key, String value);
  
  /// Retrieves a string value for the given key.
  Future<String?> getString(String key);
  
  /// Saves an integer value with the given key.
  Future<void> setInt(String key, int value);
  
  /// Retrieves an integer value for the given key.
  Future<int?> getInt(String key);
  
  /// Saves a boolean value with the given key.
  Future<void> setBool(String key, bool value);
  
  /// Retrieves a boolean value for the given key.
  Future<bool?> getBool(String key);
  
  /// Removes the value for the given key.
  Future<void> remove(String key);
  
  /// Removes all stored values.
  Future<void> clear();
  
  /// Checks if a key exists.
  Future<bool> containsKey(String key);
}

/// Storage keys used throughout the SDK.
class StorageKeys {
  // Secure storage keys (keychain/encrypted)
  static const String authToken = 'winr_auth_token';
  static const String refreshToken = 'winr_refresh_token';
  static const String userUuid = 'winr_user_uuid';
  
  // Preferences storage keys
  static const String streakState = 'winr_streak_state';
  static const String lastClaimedDate = 'winr_last_claimed_date';
  static const String cachedGiveaway = 'winr_cached_giveaway';
  static const String sdkConfig = 'winr_sdk_config';
  static const String pushToken = 'winr_push_token';
  static const String claimedTodayDate = 'winr_claimed_today_date';
  
  // Prevent instantiation
  StorageKeys._();
}