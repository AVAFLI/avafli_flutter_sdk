import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'storage.dart';
import '../domain/streak_state.dart';
import '../domain/campaign.dart';

/// Preferences storage implementation using SharedPreferences.
/// 
/// Used for storing non-sensitive data like streak state, cached campaign data,
/// and SDK configuration that can be stored in plain text.
class PreferencesStorage implements Storage {
  SharedPreferences? _prefs;
  
  /// Ensures SharedPreferences is initialized.
  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }
  
  @override
  Future<void> setString(String key, String value) async {
    final prefs = await _preferences;
    await prefs.setString(key, value);
  }
  
  @override
  Future<String?> getString(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }
  
  @override
  Future<void> setInt(String key, int value) async {
    final prefs = await _preferences;
    await prefs.setInt(key, value);
  }
  
  @override
  Future<int?> getInt(String key) async {
    final prefs = await _preferences;
    return prefs.getInt(key);
  }
  
  @override
  Future<void> setBool(String key, bool value) async {
    final prefs = await _preferences;
    await prefs.setBool(key, value);
  }
  
  @override
  Future<bool?> getBool(String key) async {
    final prefs = await _preferences;
    return prefs.getBool(key);
  }
  
  @override
  Future<void> remove(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
  }
  
  @override
  Future<void> clear() async {
    final prefs = await _preferences;
    await prefs.clear();
  }
  
  @override
  Future<bool> containsKey(String key) async {
    final prefs = await _preferences;
    return prefs.containsKey(key);
  }
  
  /// Gets the cached streak state.
  Future<StreakState?> getStreakState() async {
    final data = await getString(StorageKeys.streakState);
    if (data == null) return null;
    
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return StreakState.fromJson(json);
    } catch (e) {
      // Invalid data - remove it
      await remove(StorageKeys.streakState);
      return null;
    }
  }
  
  /// Saves the streak state.
  Future<void> saveStreakState(StreakState state) async {
    final json = jsonEncode(state.toJson());
    await setString(StorageKeys.streakState, json);
  }
  
  /// Gets the cached campaign data.
  Future<Campaign?> getCachedCampaign() async {
    final data = await getString(StorageKeys.cachedCampaign);
    if (data == null) return null;
    
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return Campaign.fromJson(json);
    } catch (e) {
      // Invalid data - remove it
      await remove(StorageKeys.cachedCampaign);
      return null;
    }
  }
  
  /// Caches the campaign data.
  Future<void> cacheCampaign(Campaign campaign) async {
    final json = jsonEncode(campaign.toJson());
    await setString(StorageKeys.cachedCampaign, json);
  }
  
  /// Gets the last claimed date as an ISO string.
  Future<DateTime?> getLastClaimedDate() async {
    final data = await getString(StorageKeys.lastClaimedDate);
    if (data == null) return null;
    
    try {
      return DateTime.parse(data);
    } catch (e) {
      // Invalid date - remove it
      await remove(StorageKeys.lastClaimedDate);
      return null;
    }
  }
  
  /// Saves the last claimed date.
  Future<void> saveLastClaimedDate(DateTime date) async {
    await setString(StorageKeys.lastClaimedDate, date.toIso8601String());
  }
  
  /// Gets cached SDK configuration.
  Future<Map<String, dynamic>?> getSdkConfig() async {
    final data = await getString(StorageKeys.sdkConfig);
    if (data == null) return null;
    
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      // Invalid data - remove it
      await remove(StorageKeys.sdkConfig);
      return null;
    }
  }
  
  /// Caches SDK configuration.
  Future<void> cacheSdkConfig(Map<String, dynamic> config) async {
    final json = jsonEncode(config);
    await setString(StorageKeys.sdkConfig, json);
  }
  
  /// Gets the cached push token.
  Future<String?> getPushToken() async {
    return await getString(StorageKeys.pushToken);
  }
  
  /// Saves the push token.
  Future<void> savePushToken(String token) async {
    await setString(StorageKeys.pushToken, token);
  }
  
  /// Clears all cached data (but preserves user preferences).
  Future<void> clearCache() async {
    await remove(StorageKeys.cachedCampaign);
    await remove(StorageKeys.sdkConfig);
    await remove(StorageKeys.lastClaimedDate);
    await remove(StorageKeys.streakState);
  }
}