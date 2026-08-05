import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/giveaway.dart';
import 'domain/daily_entry_grant.dart';
import 'domain/sdk_config.dart';
import 'domain/streak_engine.dart';
import 'network/network_client.dart';
import 'network/winr_api.dart';
import 'services/analytics/analytics_adapter.dart';
import 'services/logger.dart';
import 'services/push_notification_manager.dart';
import 'storage/preferences_storage.dart';
import 'storage/secure_storage.dart';
import 'storage/storage.dart';
import 'ui/v2/winr_v2_experience.dart';
import 'winr_configuration.dart';
import 'winr_error.dart';
import 'winr_user.dart';

/// Main entry point for the WINR Flutter SDK.
///
/// This class provides the primary interface for initializing the SDK. The
/// WINR experience presents itself — the SDK auto-opens the bottom drawer at
/// most once per calendar day; there is no manual launch API.
///
/// Example usage:
/// ```dart
/// // Configure the SDK with user (call once at app launch)
/// await WINR.configure(WINRConfiguration(
///   apiKey: 'winr_live_xxxxxxxxxx',
///   environment: WINREnvironment.production,
///   user: WINRUser(id: 'user123', firstName: 'Jane', lastName: 'Doe'),
/// ));
///
/// // For the once-a-day auto-open, attach the SDK's navigator key:
/// MaterialApp(navigatorKey: WINR.navigatorKey, ...)
/// ```
class WINR {
  static WINRConfiguration? _configuration;
  static NetworkClient? _networkClient;
  static SecureStorage? _secureStorage;
  static PreferencesStorage? _preferencesStorage;
  static StreakEngine? _streakEngine;

  // Cached data
  static Giveaway? _cachedGiveaway;
  static Map<String, dynamic>? _cachedSdkConfigRaw;
  static WinrSdkConfig? _cachedSdkConfig;
  static bool? _cachedClaimedToday;
  static int? _cachedStreakDay;

  /// Backend truth for whether this person has confirmed email + consent
  /// (drives the unregistered impression cap for auto-present).
  static bool? _cachedEmailConsent;

  /// RTD opt-out — from the backend or the local persisted flag. Once true
  /// the experience is never auto-presented.
  static bool _cachedOptedOut = false;

  // Registration state
  static bool _isRegistering = false;
  static Completer<void>? _registrationCompleter;

  /// Set when the backend reports the publisher is suspended / its API key has
  /// been revoked (typically a billing lapse). Cached from a failed device
  /// registration so repeated auto-present attempts short-circuit without
  /// hitting the network or pushing a screen. Reset on each [configure].
  static bool _isSuspended = false;

  /// Whether the experience route is currently on screen (don't stack).
  static bool _isPresenting = false;

  static _WinrLifecycleObserver? _lifecycleObserver;

  /// Navigator key for the V2 auto-open flow. Attach it to your app's
  /// `MaterialApp(navigatorKey: WINR.navigatorKey)` so the SDK can present the
  /// experience on the first app-open of the day. Without it, auto-open is
  /// silently skipped and the experience never appears.
  ///
  /// Apps that already have their own navigator key can hand it to the SDK
  /// instead (before the first auto-open opportunity):
  /// `WINR.navigatorKey = myExistingKey;`
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Package version and constants.
  /// Keep in sync with pubspec.yaml `version:` (uses leading `v` per spec
  /// field 21: sdk_version format `v1.x.x`).
  static const String sdkVersion = '2.3.2';

  /// Real platform OS for the platform_os field (spec enum: iOS / Android /
  /// Web). Derived at runtime.
  static String get platformOS =>
      Platform.isIOS ? 'iOS' : (Platform.isAndroid ? 'Android' : 'Web');

  // Auto-present persistence (per-bundle keys so app reinstalls of a different
  // publisher app on the same device don't cross-contaminate). Key names match
  // the iOS SDK.
  static String get _lastAutoPresentKey =>
      'winr_last_auto_present_${_configuration?.bundleId ?? ''}';
  static String get _unregisteredImpressionsKey =>
      'winr_unregistered_impressions_${_configuration?.bundleId ?? ''}';
  static String get _optedOutKey =>
      'winr_opted_out_${_configuration?.bundleId ?? ''}';

  /// Configures the WINR SDK with the provided configuration.
  ///
  /// This must be called before any other SDK methods. It initializes the
  /// networking, storage, and other core components, registers the device in
  /// the background, and then attempts the once-a-day auto-present of the V2
  /// experience (kill switch, unregistered impression cap, and RTD opt-out
  /// respected).
  ///
  /// Returns `true` if configuration was successful, `false` otherwise.
  static Future<bool> configure(WINRConfiguration config) async {
    try {
      // Store configuration
      _configuration = config;

      // Re-check suspension on every configure — a previously suspended
      // publisher may have been reinstated since the last run.
      _isSuspended = false;

      // Initialize logger
      Logger.instance.level = config.options.logging;
      Logger.instance.info('WINR SDK configured for ${config.environment}');

      // Keep request metadata in sync (used by claim requests).
      WINRRequestDefaults.platformOS = platformOS;
      WINRRequestDefaults.sdkVersion = 'v$sdkVersion';

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

      // Restore the persisted RTD flag so an opted-out user stays suppressed
      // even before (or without) a network round-trip.
      final prefs = await SharedPreferences.getInstance();
      _cachedOptedOut = prefs.getBool(_optedOutKey) ?? false;

      // Initialize push notification manager
      if (config.options.enablePushReminders) {
        WINRPushNotificationManager.instance.setNetworkClient(_networkClient!);
      }

      // Track configuration event
      config.options.analyticsAdapter?.track(WINRAnalyticsEvents.sdkConfigured);

      // Identify user and submit profile
      _configuration!.options.analyticsAdapter?.identify(config.user.id);
      Logger.instance.debug('User set: ${_redactId(config.user.id)}');

      // Register device in background, then attempt the once-a-day
      // auto-present.
      unawaited(_registerDeviceIfNeeded().then((_) => _autoPresentIfEligible()));

      // Auto-present on subsequent foregrounds too (covers the "app stayed in
      // memory overnight" case — a new day should re-open the experience).
      if (_lifecycleObserver == null) {
        _lifecycleObserver = _WinrLifecycleObserver();
        WidgetsBinding.instance.addObserver(_lifecycleObserver!);
      }

      // Submit user profile in background
      unawaited(_submitUserProfileIfNeeded(config.user));

      return true;
    } catch (e) {
      Logger.instance.error('SDK configuration failed', e);
      return false;
    }
  }

  /// Whether the WINR experience is currently available (i.e. eligible to
  /// auto-open).
  ///
  /// Returns `false` if the SDK has not been configured, or if the publisher
  /// account is suspended / its API key has been revoked. Publishers can poll
  /// this after configuration completes to know whether the once-a-day
  /// auto-open can occur (e.g. to show their own "service unavailable"
  /// messaging elsewhere in the app).
  static bool get isAvailable => _configuration != null && !_isSuspended;

  // MARK: - Auto-present (V2 experience: open once per day on app open)

  /// Presents the experience automatically, at most once per calendar day,
  /// when all conditions allow. Called after registration completes and on
  /// each app foreground. All short-circuits are silent by design.
  static Future<void> _autoPresentIfEligible() async {
    final config = _configuration;
    if (config == null || _isSuspended || _cachedOptedOut) return;

    // Kill switch: sdkConfig.experience.autoOpenEnabled (default true).
    final experience = _cachedSdkConfig?.experience;
    if (!(experience?.autoOpenEnabled ?? true)) return;
    if (_cachedGiveaway == null) return;

    // Once per day.
    final today = _dayString(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastAutoPresentKey) == today) return;

    // Unregistered users (no confirmed email) see the auto-open at most N
    // times (default 3 per the MVP decision), then the SDK goes quiet until
    // they register or the publisher opens it manually.
    var pendingImpressionCount = false;
    if (_cachedEmailConsent != true) {
      final cap = experience?.unregisteredImpressionCap ?? 3;
      final seen = prefs.getInt(_unregisteredImpressionsKey) ?? 0;
      if (seen >= cap) {
        Logger.instance.debug(
            'Auto-present skipped: unregistered impression cap ($cap) reached');
        return;
      }
      pendingImpressionCount = true;
    }

    // Don't stack on top of an already-presented experience, and require a
    // navigator (host must attach WINR.navigatorKey to its MaterialApp).
    if (_isPresenting) return;
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) {
      Logger.instance.debug(
          'Auto-present skipped: WINR.navigatorKey not attached to a MaterialApp');
      return;
    }

    if (pendingImpressionCount) {
      await prefs.setInt(_unregisteredImpressionsKey,
          (prefs.getInt(_unregisteredImpressionsKey) ?? 0) + 1);
    }
    await prefs.setString(_lastAutoPresentKey, today);
    Logger.instance
        .info('Auto-presenting WINR experience (first open of the day)');
    // Re-fetch the navigator context after the awaits above.
    final presentContext = navigatorKey.currentContext;
    if (presentContext == null || !presentContext.mounted) return;
    unawaited(_present(presentContext));
  }

  static String _dayString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // MARK: - Push reminders

  /// Register the host app's Firebase Cloud Messaging token so the WINR
  /// backend can send streak-reminder pushes through the publisher's own
  /// Firebase project (configured in the publisher dashboard).
  ///
  /// Call whenever FirebaseMessaging hands you a token:
  /// ```dart
  /// FirebaseMessaging.instance.onTokenRefresh.listen(WINR.registerPushToken);
  /// ```
  /// No-ops silently if the SDK isn't configured yet.
  static Future<void> registerPushToken(String fcmToken) async {
    final networkClient = _networkClient;
    if (networkClient == null || fcmToken.isEmpty) return;
    try {
      await networkClient.send(RegisterPushTokenRequest(
        pushToken: fcmToken,
        platform: Platform.isIOS ? 'ios' : 'android',
      ));
    } catch (e) {
      Logger.instance.info('registerPushToken failed: $e');
    }
  }

  // MARK: - RTD Opt-out

  /// Right-To-Delete opt-out: tombstones the person on the backend
  /// (identity-wide, PII anonymized, email suppressed) and permanently
  /// silences the experience on this device. Wire this to the opt-out action
  /// in your privacy-policy flow.
  static Future<void> optOut() async {
    final networkClient = _networkClient;
    if (networkClient == null) {
      throw const WINRException(WINRError.notConfigured);
    }
    await networkClient.send(OptOutRequest());
    markOptedOut();
    Logger.instance.info(
        'User opted out of WINR (RTD) — experience permanently silenced');
  }

  /// @internal — Records the RTD flag (from the backend or [optOut]) so the
  /// suppression holds on future launches even offline.
  static void markOptedOut() {
    _cachedOptedOut = true;
    unawaited(SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_optedOutKey, true)));
  }

  /// Presents the WINR experience (the V2 bottom drawer) over the host app.
  ///
  /// Internal-only: the experience is exclusively SDK-driven — it is opened by
  /// the once-a-day auto-present flow ([_autoPresentIfEligible]) and cannot be
  /// launched manually by the host app. Returns the [DailyEntryGrant] when
  /// entries were claimed during this presentation, or `null` if the user
  /// dismissed without a (new) claim.
  ///
  /// If the publisher account is suspended / its API key has been revoked,
  /// this does NOT push any screen and instead throws a [WINRException]
  /// wrapping [WINRError.serviceUnavailable]. If the person opted out (RTD),
  /// throws [WINRError.optedOut].
  static Future<DailyEntryGrant?> _present(BuildContext context) async {
    final config = _configuration;
    if (config == null) {
      throw const WINRException(WINRError.notConfigured);
    }

    // Ensure registration is complete — registration may flip _isSuspended.
    await _ensureRegistrationComplete();

    // If the publisher is suspended, do not present anything.
    if (_isSuspended) {
      Logger.instance.info('WINR present suppressed: publisher suspended');
      throw const WINRException(WINRError.serviceUnavailable);
    }

    // RTD: an opted-out person never sees the experience again.
    if (_cachedOptedOut) {
      Logger.instance.info('WINR present suppressed: user opted out (RTD)');
      throw const WINRException(WINRError.optedOut);
    }

    if (_isPresenting) return null;

    // Track presentation
    config.options.analyticsAdapter
        ?.track(WINRAnalyticsEvents.experiencePresented);

    if (!context.mounted) return null;

    _isPresenting = true;
    try {
      // The V2 drawer renders its own chrome (host app dimmed behind, sheet
      // flush to the screen's bottom + sides, rounded TOP corners only), so
      // it's pushed as a transparent overlay route.
      final result = await Navigator.of(context, rootNavigator: true)
          .push<DailyEntryGrant>(
        PageRouteBuilder<DailyEntryGrant>(
          opaque: false,
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondary, child) =>
              FadeTransition(opacity: animation, child: child),
          pageBuilder: (context, animation, secondary) => WINRV2Experience(
            configuration: config,
            networkClient: _networkClient!,
            secureStorage: _secureStorage!,
            preferencesStorage: _preferencesStorage!,
            streakEngine: _streakEngine!,
            cachedGiveaway: _cachedGiveaway,
            cachedClaimedToday: _cachedClaimedToday,
            cachedStreakDay: _cachedStreakDay,
            sdkConfig: _cachedSdkConfig,
          ),
        ),
      );

      if (result != null) {
        _cachedClaimedToday = true;
        return result;
      }
      // User dismissed without claiming — NOT an error.
      config.options.analyticsAdapter
          ?.track(WINRAnalyticsEvents.experienceDismissed);
      return null;
    } finally {
      _isPresenting = false;
    }
  }

  /// Registers for push notifications.
  ///
  /// Requests permission and sets up FCM token registration for streak
  /// reminders.
  static Future<void> registerForPushNotifications() async {
    final config = _configuration;
    if (config == null) {
      throw const WINRException(WINRError.notConfigured);
    }

    if (!config.options.enablePushReminders) {
      Logger.instance.debug('Push notifications disabled in configuration');
      return;
    }

    Logger.instance.debug(
        'Push reminders enabled — call WINRPushNotificationManager.instance.didReceiveRegistrationToken(token) with your FCM token');
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
      _cachedSdkConfigRaw = null;
      _cachedSdkConfig = null;
      _cachedClaimedToday = null;
      _cachedStreakDay = null;
      _cachedEmailConsent = null;

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
          // If auth failed, the cached token is stale — clear it and
          // re-register
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
      // TODO(winr): user_timezone should be a proper IANA TZ DB identifier
      // (e.g. "America/New_York"), per spec field 16. `DateTime.now()
      // .timeZoneName` returns a locale abbreviation (e.g. "EST"), NOT IANA.
      // dart:core has no IANA source; add the `flutter_timezone` plugin
      // (FlutterTimezone.getLocalTimezone()) to send a real IANA id. Until
      // then we send the abbreviation as a last resort — the backend maps
      // common abbreviations, so this is lower risk.
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
      _cachedStreakDay = response.streakDay;
      _cachedSdkConfigRaw = response.sdkConfig;
      _cachedSdkConfig = WinrSdkConfig.tryParse(response.sdkConfig);
      if (response.optedOut == true) markOptedOut();

      // Cache streak state
      if (response.giveaway != null) {
        await preferencesStorage.cacheGiveaway(response.giveaway!);
      }

      // If backend says not claimed but local storage says claimed today,
      // trust local
      if (!(_cachedClaimedToday ?? false)) {
        final localClaimed = await checkLocalClaimedToday(preferencesStorage);
        if (localClaimed) {
          _cachedClaimedToday = true;
        }
      }

      Logger.instance
          .info('Device registered successfully: ${_redactId(response.uuid)}');
    } catch (e) {
      Logger.instance.error('Device registration failed', e);
      // Cache the suspended state so repeat launches short-circuit cleanly.
      _handleSuspensionIfNeeded(e);
    } finally {
      _isRegistering = false;
      _registrationCompleter?.complete();
      _registrationCompleter = null;
    }
  }

  /// If [error] indicates the publisher is suspended / API key revoked, caches
  /// that state so subsequent [present] calls short-circuit cleanly.
  static void _handleSuspensionIfNeeded(Object error) {
    if (error is WINRException && error.error == WINRError.serviceUnavailable) {
      _isSuspended = true;
      Logger.instance.info('Publisher suspended — WINR experience disabled');
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
      _cachedStreakDay = response.streakDay;
      _cachedSdkConfigRaw = response.sdkConfig;
      _cachedSdkConfig = WinrSdkConfig.tryParse(response.sdkConfig);
      _cachedEmailConsent = response.emailConsentStatus;
      if (response.optedOut == true) markOptedOut();

      // Update cached data
      if (response.giveaway != null) {
        await _preferencesStorage!.cacheGiveaway(response.giveaway!);
      }

      // If backend says not claimed but local storage says claimed today,
      // trust local
      if (!(_cachedClaimedToday ?? false)) {
        final localClaimed = await checkLocalClaimedToday(_preferencesStorage!);
        if (localClaimed) {
          _cachedClaimedToday = true;
        }
      }

      Logger.instance.debug('Giveaway data refreshed');
    } on WINRException catch (e) {
      // Rethrow auth errors so callers can handle stale token recovery
      if (e.error == WINRError.authenticationFailed) {
        Logger.instance.error('Auth failed during giveaway refresh', e);
        rethrow;
      }
      // Rethrow suspension so the caller can cache it and short-circuit.
      if (e.error == WINRError.serviceUnavailable) {
        Logger.instance.error('Publisher suspended during giveaway refresh', e);
        rethrow;
      }
      Logger.instance.error('Failed to refresh giveaway data', e);
    } catch (e) {
      Logger.instance.error('Failed to refresh giveaway data', e);
    }
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
  ///
  /// Optional name/phone fields are validated/normalized before submit (spec
  /// fields 4–6). Invalid values are dropped (sent as null) rather than
  /// rejecting the whole profile, since these are optional.
  static Future<void> _submitUserProfileIfNeeded(WINRUser user) async {
    try {
      final request = SubmitUserProfileRequest(
        firstName: _validName(user.firstName),
        lastName: _validName(user.lastName),
        phone: _validPhone(user.phone),
        publisherUserId: user.id,
      );

      await _networkClient!.send(request);
      Logger.instance.debug('User profile submitted');
    } catch (e) {
      Logger.instance.error('Failed to submit user profile', e);
    }
  }

  /// Validates a name against `^[a-zA-Z '-]{1,50}$`; returns the trimmed value
  /// or null if blank/invalid (names are optional).
  static String? _validName(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return RegExp(r"^[a-zA-Z '-]{1,50}$").hasMatch(trimmed) ? trimmed : null;
  }

  /// Strips non-digits and validates a US mobile number against
  /// `^\+?1?\d{10}$`; returns the digit-normalized value or null if invalid
  /// (phone is optional).
  static String? _validPhone(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^\+?1?\d{10}$').hasMatch(trimmed) && digits.length >= 10
        ? digits
        : null;
  }

  /// Redacts a user id / uuid for logging — keeps only the last 4 chars so
  /// logs remain useful for correlation without leaking the full identifier.
  static String _redactId(String id) {
    if (id.length <= 4) return '****';
    return '****${id.substring(id.length - 4)}';
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
  // These methods are used by the experience within the SDK package.
  // They are not part of the public API and should not be called by
  // publishers.

  /// @internal — Syncs the static cached claimed-today state after a claim.
  static void syncClaimedToday(bool claimed) {
    _cachedClaimedToday = claimed;
  }

  /// @internal — Persists claimed-today date to local storage so the state
  /// survives app restarts within the same calendar day.
  static Future<void> persistClaimedToday(PreferencesStorage storage) async {
    final today = _dayString(DateTime.now());
    await storage.setString(StorageKeys.claimedTodayDate, today);
  }

  /// @internal — Checks local storage for a same-day claim record.
  /// Returns true if the user already claimed today (locally persisted).
  static Future<bool> checkLocalClaimedToday(PreferencesStorage storage) async {
    final stored = await storage.getString(StorageKeys.claimedTodayDate);
    if (stored == null) return false;
    return stored == _dayString(DateTime.now());
  }

  /// @internal — Foreground hook from the lifecycle observer.
  static Future<void> handleAppResumed() async {
    await _ensureRegistrationComplete();
    await _autoPresentIfEligible();
  }

  // MARK: - Testing Support

  /// Gets the current configuration (for testing).
  @visibleForTesting
  static WINRConfiguration? get configurationForTesting => _configuration;

  /// Gets the current user (for testing).
  @visibleForTesting
  static WINRUser? get userForTesting => _configuration?.user;

  /// Gets the raw server sdkConfig (for testing).
  @visibleForTesting
  static Map<String, dynamic>? get sdkConfigForTesting => _cachedSdkConfigRaw;

  /// Resets the SDK state (for testing).
  @visibleForTesting
  static void resetForTesting() {
    _configuration = null;
    _networkClient = null;
    _secureStorage = null;
    _preferencesStorage = null;
    _streakEngine = null;
    _cachedGiveaway = null;
    _cachedSdkConfigRaw = null;
    _cachedSdkConfig = null;
    _cachedClaimedToday = null;
    _cachedStreakDay = null;
    _cachedEmailConsent = null;
    _cachedOptedOut = false;
    _isRegistering = false;
    _registrationCompleter = null;
    _isSuspended = false;
    _isPresenting = false;
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }
}

/// Observes app lifecycle to re-attempt the once-a-day auto-present when the
/// app returns to the foreground (mirrors iOS `didBecomeActiveNotification`).
class _WinrLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(WINR.handleAppResumed());
    }
  }
}
