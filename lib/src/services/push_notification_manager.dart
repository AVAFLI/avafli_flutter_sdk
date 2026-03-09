import 'package:flutter/foundation.dart';
import '../storage/preferences_storage.dart';
import '../network/network_client.dart';
import '../network/winr_api.dart';
import 'logger.dart';

/// Manages push notification token registration with the WINR backend.
///
/// This manager does NOT depend on Firebase directly. Instead, the publisher
/// forwards their FCM/APNs token to the SDK via [didReceiveRegistrationToken].
///
/// Example (publisher-side Firebase integration):
/// ```dart
/// FirebaseMessaging.instance.getToken().then((token) {
///   if (token != null) {
///     PushNotificationManager.instance.didReceiveRegistrationToken(token);
///   }
/// });
/// ```
class PushNotificationManager {
  static final PushNotificationManager _instance =
      PushNotificationManager._internal();
  static PushNotificationManager get instance => _instance;

  PushNotificationManager._internal();

  final PreferencesStorage _storage = PreferencesStorage();

  NetworkClient? _networkClient;

  /// Sets the network client for API calls.
  void setNetworkClient(NetworkClient client) {
    _networkClient = client;
  }

  /// Registers a push token received from the publisher's push notification
  /// setup (e.g., Firebase Cloud Messaging).
  ///
  /// Call this when your app receives a new FCM/APNs token.
  Future<void> didReceiveRegistrationToken(String token) async {
    await _handleTokenUpdate(token);
  }

  /// Handles token updates — caches locally and sends to backend.
  Future<void> _handleTokenUpdate(String token) async {
    try {
      // Check if token has changed
      final cachedToken = await _storage.getPushToken();
      if (cachedToken == token) {
        Logger.instance.debug('Push token unchanged, skipping update');
        return;
      }

      // Save new token locally
      await _storage.savePushToken(token);

      // Send to backend if we have a network client
      if (_networkClient != null) {
        await _registerTokenWithBackend(token);
      }

      Logger.instance.debug('Push token updated successfully');
    } catch (e) {
      Logger.instance.error('Failed to handle push token update', e);
    }
  }

  /// Registers the push token with the WINR backend.
  Future<void> _registerTokenWithBackend(String token) async {
    final client = _networkClient;
    if (client == null) {
      Logger.instance.debug('No network client available for token registration');
      return;
    }

    try {
      final request = RegisterPushTokenRequest(
        pushToken: token,
        platform:
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );

      await client.send(request);
      Logger.instance.debug('Push token registered with backend');
    } catch (e) {
      Logger.instance.error('Failed to register push token with backend', e);
    }
  }

  /// Gets the cached push token.
  Future<String?> getCachedToken() async {
    return await _storage.getPushToken();
  }

  /// Clears the cached push token (e.g., on account deletion).
  Future<void> clearToken() async {
    await _storage.remove('winr_push_token');
    Logger.instance.debug('Push token cleared');
  }
}
