import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'storage/storage.dart';
import 'ui/winr_experience_card.dart';
import 'ui/winr_experience_screen.dart';
import 'winr_branding.dart';
import 'winr_configuration.dart';
import 'winr_environment.dart';
import 'winr_error.dart';
import 'winr_user.dart';

/// Main entry point for the WINR Flutter SDK.
///
/// This class provides the primary interface for initializing the SDK
/// and presenting the WINR experience.
///
/// Example usage:
/// ```dart
/// // Configure the SDK with user
/// await WINR.configure(WINRConfiguration(
///   apiKey: 'winr_live_xxxxxxxxxx',
///   environment: WINREnvironment.production,
///   user: WINRUser(id: 'user123', firstName: 'Jane', lastName: 'Doe'),
/// ));
///
/// // Present the experience
/// final result = await WINR.present(context);
/// ```
class WINR {
  static WINRConfiguration? _configuration;
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
  static int _cachedTotalEntries = 0;

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
      // Store configuration
      _configuration = config;

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
        WINRPushNotificationManager.instance.setNetworkClient(_networkClient!);
      }

      // Track configuration event
      config.options.analyticsAdapter?.track(WINRAnalyticsEvents.sdkConfigured);

      // Identify user and submit profile
      _configuration!.options.analyticsAdapter?.identify(config.user.id);
      Logger.instance.debug('User set: ${config.user.id}');

      // Register device in background
      unawaited(_registerDeviceIfNeeded());

      // Submit user profile in background
      unawaited(_submitUserProfileIfNeeded(config.user));

      return true;
    } catch (e) {
      Logger.instance.error('SDK configuration failed', e);
      return false;
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

    final user = config.user;

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
            cachedTotalEntries: _cachedTotalEntries,
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

    if (config == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text('WINR SDK not configured'),
      );
    }

    return WINRExperienceCard(
      branding: WINRBranding.defaultBranding(),
      giveaway: _cachedGiveaway,
      streakState: _cachedStreakState,
      claimedToday: _cachedClaimedToday ?? false,
      onTap: () {
        HapticFeedback.mediumImpact();
        // When card is tapped, the publisher should call WINR.present()
        onEntryGranted?.call();
      },
      onQuickClaim: onEntryGranted,
    );
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

    Logger.instance.debug('Push reminders enabled — call WINRPushNotificationManager.instance.didReceiveRegistrationToken(token) with your FCM token');
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
      _cachedTotalEntries = 0;

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
        // Restore auth token on the network client before making requests
        _networkClient!.setAuthToken(existingToken);
        try {
          // Try to refresh giveaway data with the cached token
          await _refreshGiveawayData();
          return;
        } on WINRException catch (e) {
          // If auth failed, the cached token is stale — clear it and re-register
          if (e.error == WINRError.authenticationFailed) {
            Logger.instance.info('Cached token expired, re-registering device');
            _networkClient!.setAuthToken(null);
            await secureStorage.deleteAuthData();
            // Fall through to fresh registration below
          } else {
            rethrow;
          }
        }
      }

      // Generate device fingerprint
      final deviceFingerprint = await _generateDeviceFingerprint();

      // Register with backend
      final request = RegisterDeviceRequest(
        apiKey: config.apiKey,
        deviceFingerprint: deviceFingerprint,
        bundleId: config.bundleId,
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
      _cachedTotalEntries = response.totalEntries;
      _cachedSdkConfig = response.sdkConfig;
      _cachedSdkCopy = _parseSdkCopy(response.sdkConfig);
      _cachedSdkMedia = _parseSdkMedia(response.sdkConfig);

      // Cache streak state
      if (response.giveaway != null) {
        await preferencesStorage.cacheGiveaway(response.giveaway!);
      }

      // If backend says not claimed but local storage says claimed today, trust local
      if (!(_cachedClaimedToday ?? false)) {
        final localClaimed = await checkLocalClaimedToday(preferencesStorage);
        if (localClaimed) {
          _cachedClaimedToday = true;
        }
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
  ///
  /// Auth errors are rethrown so callers can handle stale token recovery.
  /// Other errors are logged and swallowed (offline fallback).
  static Future<void> _refreshGiveawayData() async {
    try {
      final response = await _networkClient!.send(GetActiveGiveawayRequest());

      _cachedGiveaway = response.giveaway;
      _cachedClaimedToday = response.claimedToday;
      _cachedTotalEntries = response.totalEntries;
      _cachedSdkConfig = response.sdkConfig;
      _cachedSdkCopy = _parseSdkCopy(response.sdkConfig);
      _cachedSdkMedia = _parseSdkMedia(response.sdkConfig);

      // Update cached data
      if (response.giveaway != null) {
        await _preferencesStorage!.cacheGiveaway(response.giveaway!);
      }

      // If backend says not claimed but local storage says claimed today, trust local
      if (!(_cachedClaimedToday ?? false)) {
        final localClaimed = await checkLocalClaimedToday(_preferencesStorage!);
        if (localClaimed) {
          _cachedClaimedToday = true;
        }
      }

      _setupRewardedVideoProvider();

      Logger.instance.debug('Giveaway data refreshed');
    } on WINRException catch (e) {
      // Rethrow auth errors so callers can handle stale token recovery
      if (e.error == WINRError.authenticationFailed) {
        Logger.instance.error('Auth failed during giveaway refresh', e);
        rethrow;
      }
      Logger.instance.error('Failed to refresh giveaway data', e);
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
      testMode: _configuration?.environment == WINREnvironment.staging,
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
      // Clear the stale auth token before calling refreshToken endpoint.
      // Firebase onCall validates Bearer tokens at the transport layer —
      // if a stale token is present, it returns 401 before the function runs.
      _networkClient!.setAuthToken(null);

      final request = RefreshTokenRequest(refreshToken: refreshToken);
      final response = await _networkClient!.send(request);

      await secureStorage.saveAuthToken(response.token);
      await secureStorage.saveRefreshToken(response.refreshToken);

      // Set the fresh token on the network client
      _networkClient!.setAuthToken(response.token);

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

  // MARK: - Internal State Sync
  // These methods are used by WINRExperienceScreen within the SDK package.
  // They are not part of the public API and should not be called by publishers.

  /// @internal — Syncs the static cached claimed-today state after a claim.
  /// Used by [WINRExperienceScreen] within this package.
  static void syncClaimedToday(bool claimed) {
    _cachedClaimedToday = claimed;
  }

  /// @internal — Persists claimed-today date to local storage so the state
  /// survives app restarts within the same calendar day.
  /// Used by [WINRExperienceScreen] within this package.
  static Future<void> persistClaimedToday(PreferencesStorage storage) async {
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    await storage.setString(StorageKeys.claimedTodayDate, today);
  }

  /// @internal — Checks local storage for a same-day claim record.
  /// Returns true if the user already claimed today (locally persisted).
  /// Used by [WINRExperienceScreen] within this package.
  static Future<bool> checkLocalClaimedToday(PreferencesStorage storage) async {
    final stored = await storage.getString(StorageKeys.claimedTodayDate);
    if (stored == null) return false;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return stored == today;
  }

  // MARK: - Testing Support

  /// Gets the current configuration (for testing).
  @visibleForTesting
  static WINRConfiguration? get configurationForTesting => _configuration;

  /// Gets the current user (for testing).
  @visibleForTesting
  static WINRUser? get userForTesting => _configuration?.user;

  /// Resets the SDK state (for testing).
  @visibleForTesting
  static void resetForTesting() {
    _configuration = null;
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
    _cachedTotalEntries = 0;
    _isRegistering = false;
    _registrationCompleter = null;
  }
}
