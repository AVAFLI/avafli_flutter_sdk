import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'domain/giveaway.dart';
import 'domain/daily_entry_grant.dart';
import 'domain/sdk_copy.dart';
import 'domain/sdk_media.dart';
import 'domain/streak_engine.dart';
import 'domain/streak_state.dart';
import 'network/network_client.dart';
import 'network/winr_api.dart';
import 'rewards/ad_provider_factory.dart';
import 'rewards/rewarded_video_provider.dart';
import 'services/analytics/analytics_adapter.dart';
import 'services/logger.dart';
import 'services/push_notification_manager.dart';
import 'storage/preferences_storage.dart';
import 'storage/secure_storage.dart';
import 'ui/winr_experience_screen.dart';
import 'winr_configuration.dart';
import 'winr_error.dart';
import 'winr_user.dart';

/// Main entry point for the WINR Flutter SDK.
///
/// This class provides the primary interface for initializing the SDK,
/// setting user information, and presenting the WINR experience.
///
/// Example usage:
/// ```dart
/// // Initialize the SDK
/// await WINR.configure(WINRConfiguration(
///   apiKey: 'winr_live_xxxxxxxxxx',
///   environment: WINREnvironment.production,
/// ));
///
/// // Set user information
/// WINR.setUser(WINRUser(id: 'user123'));
///
/// // Present the experience
/// final result = await WINR.present(context);
/// ```
class WINR {
  static WINRConfiguration? _configuration;
  static WINRUser? _currentUser;
  static NetworkClient? _networkClient;
  static SecureStorage? _secureStorage;
  static PreferencesStorage? _preferencesStorage;
  static StreakEngine? _streakEngine;
  static RewardedVideoProvider? _rewardedVideoProvider;

  // Cached data
  static Giveaway? _cachedGiveaway;
  static StreakState? _cachedStreakState;
  static Map<String, dynamic>? _cachedSdkConfig;
  static SdkCopy? _cachedSdkCopy;
  static SdkMedia? _cachedSdkMedia;
  static bool? _cachedClaimedToday;

  // Registration state
  static bool _isRegistering = false;
  static Completer<void>? _registrationCompleter;

  /// Package version and constants
  static const String sdkVersion = '1.0.0';
  static const String platformOS = 'flutter';

  /// Configures the WINR SDK with the provided configuration.
  ///
  /// This must be called before any other SDK methods. It initializes
  /// the networking, storage, and other core components.
  ///
  /// Returns `true` if configuration was successful, `false` otherwise.
  static Future<bool> configure(WINRConfiguration config) async {
    try {
      // Get bundle ID if not provided
      String bundleId = config.bundleId ?? '';
      if (bundleId.isEmpty) {
        final packageInfo = await PackageInfo.fromPlatform();
        bundleId = packageInfo.packageName;
      }

      // Store configuration (resolve bundleId)
      _configuration = WINRConfiguration(
        apiKey: config.apiKey,
        environment: config.environment,
        bundleId: bundleId,
        options: config.options,
      );

      // Initialize logger
      Logger.instance.level = config.options.logging;
      Logger.instance.info('WINR SDK configured for ${config.environment}');

      // Initialize storage
      _secureStorage = SecureStorage();
      _preferencesStorage = PreferencesStorage();

      // Initialize streak engine
      _streakEngine = StreakEngine();

      // Initialize network client
      _networkClient = NetworkClientImpl(
        baseURL: _configuration!.baseURL,
        apiKey: config.apiKey,
      );

      // Set up token refresh handler
      _networkClient!.setRefreshHandler(_refreshTokenIfNeeded);

      // Initialize push notification manager
      if (config.options.enablePushReminders) {
        PushNotificationManager.instance.setNetworkClient(_networkClient!);
      }

      // Track configuration event
      config.options.analyticsAdapter?.track(WINRAnalyticsEvents.sdkConfigured);

      // Register device in background
      unawaited(_registerDeviceIfNeeded());

      return true;
    } catch (e) {
      Logger.instance.error('SDK configuration failed', e);
      return false;
    }
  }

  /// Sets the current user for the SDK.
  ///
  /// This should be called after [configure] and whenever the user
  /// identity changes in your app.
  static void setUser(WINRUser user) {
    _currentUser = user;
    Logger.instance.debug('User set: ${user.id}');

    // Track user identification
    _configuration?.options.analyticsAdapter?.identify(user.id);
    _configuration?.options.analyticsAdapter
        ?.track(WINRAnalyticsEvents.userSet);

    // Submit profile data (always send publisher user ID)
    if (_networkClient != null) {
      unawaited(_submitUserProfileIfNeeded(user));
    }
  }

  /// Presents the WINR experience screen.
  ///
  /// Shows the main engagement UI where users can claim their daily entries.
  /// Returns a [DailyEntryGrant] if the user successfully claims entries,
  /// or throws a [WINRException] if an error occurs.
  static Future<DailyEntryGrant> present(BuildContext context) async {
    final config = _configuration;
    if (config == null) {
      throw const WINRException(WINRError.notConfigured);
    }

    final user = _currentUser;
    if (user == null) {
      throw const WINRException(WINRError.noUser);
    }

    // Ensure registration is complete
    await _ensureRegistrationComplete();

    // Track presentation
    config.options.analyticsAdapter
        ?.track(WINRAnalyticsEvents.experiencePresented);

    // Create and show the experience screen
    if (context.mounted) {
      final result = await Navigator.of(context).push<DailyEntryGrant>(
        MaterialPageRoute(
          builder: (context) => WINRExperienceScreen(
            configuration: config,
            user: user,
            networkClient: _networkClient!,
            secureStorage: _secureStorage!,
            preferencesStorage: _preferencesStorage!,
            streakEngine: _streakEngine!,
            rewardedVideoProvider: _rewardedVideoProvider,
            cachedGiveaway: _cachedGiveaway,
            cachedStreakState: _cachedStreakState,
            cachedClaimedToday: _cachedClaimedToday,
            sdkConfig: _cachedSdkConfig,
            sdkCopy: _cachedSdkCopy,
            sdkMedia: _cachedSdkMedia,
          ),
          fullscreenDialog: true,
        ),
      );

      if (result != null) {
        return result;
      } else {
        // User dismissed without claiming
        config.options.analyticsAdapter
            ?.track(WINRAnalyticsEvents.experienceDismissed);
        throw const WINRException(WINRError.invalidState);
      }
    }
    throw const WINRException(WINRError.invalidState);
  }

  /// Returns a widget that can be embedded in your app.
  ///
  /// This provides a card-style experience that can be integrated
  /// directly into your app's UI instead of being presented modally.
  static Widget presentAsCard({
    VoidCallback? onEntryGranted,
    VoidCallback? onError,
  }) {
    final config = _configuration;
    final user = _currentUser;

    if (config == null || user == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text('WINR SDK not configured'),
      );
    }

    // Return the embedded experience widget
    return Container(); // TODO: Implement embedded card widget
  }

  /// Registers for push notifications.
  ///
  /// Requests permission and sets up FCM token registration for streak reminders.
  static Future<void> registerForPushNotifications() async {
    final config = _configuration;
    if (config == null) {
      throw const WINRException(WINRError.notConfigured);
    }

    if (!config.options.enablePushReminders) {
      Logger.instance.debug('Push notifications disabled in configuration');
      return;
    }

    Logger.instance.debug('Push reminders enabled — call PushNotificationManager.instance.didReceiveRegistrationToken(token) with your FCM token');
  }

  /// Deletes all user data (GDPR compliance).
  ///
  /// Removes all user data from the backend and clears local storage.
  static Future<void> deleteUserData() async {
    final networkClient = _networkClient;
    if (networkClient == null) {
      throw const WINRException(WINRError.notConfigured);
    }

    try {
      await networkClient.send(DeleteUserDataRequest());

      // Clear local storage
      await _secureStorage?.clear();
      await _preferencesStorage?.clear();

      // Clear cached data
      _cachedGiveaway = null;
      _cachedStreakState = null;
      _cachedSdkConfig = null;
      _cachedSdkCopy = null;
      _cachedSdkMedia = null;
      _cachedClaimedToday = null;
      _currentUser = null;

      Logger.instance.info('User data deleted successfully');
    } catch (e) {
      Logger.instance.error('Failed to delete user data', e);
      rethrow;
    }
  }

  // MARK: - Private Methods

  /// Ensures device registration is complete before proceeding.
  static Future<void> _ensureRegistrationComplete() async {
    if (_isRegistering && _registrationCompleter != null) {
      await _registrationCompleter!.future;
    }
  }

  /// Registers the device with the backend if needed.
  static Future<void> _registerDeviceIfNeeded() async {
    if (_isRegistering) return;

    _isRegistering = true;
    _registrationCompleter = Completer<void>();

    try {
      final config = _configuration!;
      final secureStorage = _secureStorage!;
      final preferencesStorage = _preferencesStorage!;

      // Check if we already have valid auth data
      final existingToken = await secureStorage.getAuthToken();
      final existingUuid = await secureStorage.getUserUuid();

      if (existingToken != null && existingUuid != null) {
        // We have existing auth, just refresh giveaway data
        await _refreshGiveawayData();
        return;
      }

      // Generate device fingerprint
      final deviceFingerprint = await _generateDeviceFingerprint();

      // Register with backend
      final request = RegisterDeviceRequest(
        apiKey: config.apiKey,
        deviceFingerprint: deviceFingerprint,
        bundleId: config.bundleId!,
        timezone: DateTime.now().timeZoneName,
        platformOS: platformOS,
        sdkVersion: sdkVersion,
      );

      final response = await _networkClient!.send(request);

      // Store auth data
      await secureStorage.saveAuthToken(response.token);
      await secureStorage.saveRefreshToken(response.refreshToken);
      await secureStorage.saveUserUuid(response.uuid);

      // Set auth token on network client
      _networkClient!.setAuthToken(response.token);

      // Cache response data
      _cachedGiveaway = response.giveaway;
      _cachedClaimedToday = response.claimedToday;
      _cachedSdkConfig = response.sdkConfig;
      _cachedSdkCopy = _parseSdkCopy(response.sdkConfig);
      _cachedSdkMedia = _parseSdkMedia(response.sdkConfig);

      // Cache streak state
      if (response.giveaway != null) {
        await preferencesStorage.cacheGiveaway(response.giveaway!);
      }

      // Set up rewarded video provider if configured
      _setupRewardedVideoProvider();

      Logger.instance.info('Device registered successfully: ${response.uuid}');
    } catch (e) {
      Logger.instance.error('Device registration failed', e);
    } finally {
      _isRegistering = false;
      _registrationCompleter?.complete();
      _registrationCompleter = null;
    }
  }

  /// Refreshes giveaway data from the backend.
  static Future<void> _refreshGiveawayData() async {
    try {
      final response = await _networkClient!.send(GetActiveGiveawayRequest());

      _cachedGiveaway = response.giveaway;
      _cachedClaimedToday = response.claimedToday;
      _cachedSdkConfig = response.sdkConfig;
      _cachedSdkCopy = _parseSdkCopy(response.sdkConfig);
      _cachedSdkMedia = _parseSdkMedia(response.sdkConfig);

      // Update cached data
      if (response.giveaway != null) {
        await _preferencesStorage!.cacheGiveaway(response.giveaway!);
      }

      _setupRewardedVideoProvider();

      Logger.instance.debug('Giveaway data refreshed');
    } catch (e) {
      Logger.instance.error('Failed to refresh giveaway data', e);
    }
  }

  /// Sets up the rewarded video provider based on giveaway config.
  static void _setupRewardedVideoProvider() {
    final sdkConfig = _cachedSdkConfig;
    if (sdkConfig == null) return;

    final adNetwork = sdkConfig['adNetwork'] as String?;
    final adUnitId = sdkConfig['adUnitId'] as String?;

    _rewardedVideoProvider = AdProviderFactory.create(
      adNetwork: adNetwork,
      adUnitId: adUnitId,
      testMode: false, // TODO: Add test mode detection
    );
  }

  /// Parses SDK config copy into typed model.
  static SdkCopy? _parseSdkCopy(Map<String, dynamic>? sdkConfig) {
    if (sdkConfig == null) return null;
    
    final copyJson = sdkConfig['copy'];
    if (copyJson == null) return null;
    
    if (copyJson is Map<String, dynamic>) {
      try {
        return SdkCopy.fromJson(copyJson);
      } catch (e) {
        Logger.instance.error('Failed to parse SDK copy config', e);
        return null;
      }
    }
    
    return null;
  }

  /// Parses SDK config media into typed model.
  static SdkMedia? _parseSdkMedia(Map<String, dynamic>? sdkConfig) {
    if (sdkConfig == null) return null;
    
    final mediaJson = sdkConfig['media'];
    if (mediaJson == null) return null;
    
    if (mediaJson is Map<String, dynamic>) {
      try {
        return SdkMedia.fromJson(mediaJson);
      } catch (e) {
        Logger.instance.error('Failed to parse SDK media config', e);
        return null;
      }
    }
    
    return null;
  }

  /// Refreshes the authentication token if needed.
  static Future<String?> _refreshTokenIfNeeded() async {
    final secureStorage = _secureStorage;
    if (secureStorage == null) return null;

    final refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final request = RefreshTokenRequest(refreshToken: refreshToken);
      final response = await _networkClient!.send(request);

      await secureStorage.saveAuthToken(response.token);
      await secureStorage.saveRefreshToken(response.refreshToken);

      Logger.instance.debug('Token refreshed successfully');
      return response.token;
    } catch (e) {
      Logger.instance.error('Token refresh failed', e);

      // Clear invalid tokens
      await secureStorage.deleteAuthData();
      return null;
    }
  }

  /// Submits user profile data if available.
  static Future<void> _submitUserProfileIfNeeded(WINRUser user) async {
    try {
      final request = SubmitUserProfileRequest(
        firstName: user.firstName,
        lastName: user.lastName,
        phone: user.phone,
        smsConsent: user.isSMSPermissioned,
        publisherUserId: user.id,
      );

      await _networkClient!.send(request);
      Logger.instance.debug('User profile submitted');
    } catch (e) {
      Logger.instance.error('Failed to submit user profile', e);
    }
  }

  /// Generates a unique device fingerprint.
  static Future<String> _generateDeviceFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use a combination of device identifiers
        return '${androidInfo.model}_${androidInfo.id}_${androidInfo.fingerprint}'
            .hashCode
            .toString();
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor on iOS
        return iosInfo.identifierForVendor ?? 'unknown_ios_device';
      } else {
        // Web or other platforms
        return 'unknown_platform_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      Logger.instance.error('Failed to generate device fingerprint', e);
      return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // MARK: - Testing Support

  /// Gets the current configuration (for testing).
  @visibleForTesting
  static WINRConfiguration? get configurationForTesting => _configuration;

  /// Gets the current user (for testing).
  @visibleForTesting
  static WINRUser? get userForTesting => _currentUser;

  /// Resets the SDK state (for testing).
  @visibleForTesting
  static void resetForTesting() {
    _configuration = null;
    _currentUser = null;
    _networkClient = null;
    _secureStorage = null;
    _preferencesStorage = null;
    _streakEngine = null;
    _rewardedVideoProvider = null;
    _cachedGiveaway = null;
    _cachedStreakState = null;
    _cachedSdkConfig = null;
    _cachedSdkCopy = null;
    _cachedSdkMedia = null;
    _cachedClaimedToday = null;
    _isRegistering = false;
    _registrationCompleter = null;
  }
}
