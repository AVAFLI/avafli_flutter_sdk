import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../storage/preferences_storage.dart';
import '../network/network_client.dart';
import '../network/winr_api.dart';
import 'logger.dart';

/// Manages push notification registration and token handling.
/// 
/// Handles Firebase Cloud Messaging (FCM) token registration,
/// permission requests, and token updates for streak reminders.
class PushNotificationManager {
  static final PushNotificationManager _instance = PushNotificationManager._internal();
  static PushNotificationManager get instance => _instance;
  
  PushNotificationManager._internal();
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final PreferencesStorage _storage = PreferencesStorage();
  
  NetworkClient? _networkClient;
  bool _isRegistering = false;
  
  /// Sets the network client for API calls.
  void setNetworkClient(NetworkClient client) {
    _networkClient = client;
  }
  
  /// Requests notification permissions and registers for FCM.
  Future<void> register() async {
    if (_isRegistering) return;
    _isRegistering = true;
    
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        Logger.instance.debug('Push notification permission denied');
        return;
      }
      
      // Get FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        await _handleTokenUpdate(token);
        
        // Listen for token updates
        FirebaseMessaging.instance.onTokenRefresh.listen(_handleTokenUpdate);
      }
      
      Logger.instance.debug('Push notification registration completed');
    } catch (e) {
      Logger.instance.error('Push notification registration failed', e);
    } finally {
      _isRegistering = false;
    }
  }
  
  /// Handles FCM token updates.
  Future<void> _handleTokenUpdate(String token) async {
    try {
      // Check if token has changed
      final cachedToken = await _storage.getPushToken();
      if (cachedToken == token) {
        Logger.instance.debug('FCM token unchanged, skipping update');
        return;
      }
      
      // Save new token locally
      await _storage.savePushToken(token);
      
      // Send to backend if we have a network client
      if (_networkClient != null) {
        await _registerTokenWithBackend(token);
      }
      
      Logger.instance.debug('FCM token updated successfully');
    } catch (e) {
      Logger.instance.error('Failed to handle FCM token update', e);
    }
  }
  
  /// Registers the FCM token with the WINR backend.
  Future<void> _registerTokenWithBackend(String token) async {
    final client = _networkClient;
    if (client == null) {
      Logger.instance.debug('No network client available for token registration');
      return;
    }
    
    try {
      final request = RegisterPushTokenRequest(
        pushToken: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      
      await client.send(request);
      Logger.instance.debug('FCM token registered with backend');
    } catch (e) {
      Logger.instance.error('Failed to register FCM token with backend', e);
    }
  }
  
  /// Called when the app receives a new FCM registration token.
  /// 
  /// This should be called from your app's Firebase initialization
  /// or when handling token updates.
  void didReceiveRegistrationToken(String token) {
    _handleTokenUpdate(token);
  }
  
  /// Configures foreground notification presentation.
  Future<void> configureForegroundNotifications() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
  
  /// Gets the current FCM token.
  Future<String?> getCurrentToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      Logger.instance.error('Failed to get FCM token', e);
      return null;
    }
  }
  
  /// Unregisters from push notifications.
  Future<void> unregister() async {
    try {
      // Delete token from FCM
      await _messaging.deleteToken();
      
      // Clear cached token
      await _storage.remove('winr_push_token');
      
      Logger.instance.debug('Push notifications unregistered');
    } catch (e) {
      Logger.instance.error('Failed to unregister push notifications', e);
    }
  }
  
  /// Handles background messages (for future use).
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    Logger.instance.debug('Handling background FCM message: ${message.messageId}');
    // Handle background message processing here
  }
}