import 'dart:async';
import 'dart:math';
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
import 'ui/v2/winr_v2_effects.dart';
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

  /// Adoption re-entry (2.9): true when the latest register/status response
  /// carried `adoptionPending: true` — an interrupted verification-gated
  /// adoption the experience should re-stage (fresh code + code screen)
  /// instead of showing email capture. Null-safe against current prod.
  static bool? _cachedAdoptionPending;

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
  /// Keep in sync with pubspec.yaml `version:`. Sent to the backend WITHOUT a
  /// leading `v`, matching the iOS/Android/web SDKs (the min-version parser
  /// strips a leading `v`, so the bare number is the canonical form).
  static const String sdkVersion = '2.9.3';

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
      WINRRequestDefaults.sdkVersion = sdkVersion;

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
      if (!config.user.isGuest) {
        _configuration!.options.analyticsAdapter?.identify(config.user.id);
      }
      Logger.instance.debug(config.user.isGuest
          ? 'User set: guest session'
          : 'User set: ${_redactId(config.user.id)}');

      // Register device in background, then attempt the once-a-day
      // auto-present.
      unawaited(
          _registerDeviceIfNeeded().then((_) => _autoPresentIfEligible()));

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

  /// True while the host has asked auto-open to wait (see [holdAutoOpen]).
  static bool _autoOpenHeld = false;

  /// Set by the experience when the user themselves closed it (X / GOT IT).
  /// If the route completes WITHOUT this flag and without a grant, something
  /// in the host removed it — e.g. a splash screen finishing with
  /// `Get.offAll` / `pushAndRemoveUntil`, which clears every route including
  /// ours.
  static bool _userDismissedExperience = false;

  /// Bounded retry budget for auto-presents killed by host navigation.
  static int _autoPresentRetries = 0;
  static const int _maxAutoPresentRetries = 2;

  /// @internal — the experience calls this from its own dismiss path.
  static void noteUserDismissedExperience() {
    _userDismissedExperience = true;
  }

  /// Pauses the once-a-day auto-open.
  ///
  /// Call this before [configure] when your app has a boot flow (splash
  /// screen, auth gate) that ends by clearing the navigation stack
  /// (`Get.offAll`, `pushAndRemoveUntil`, …) — otherwise the drawer can
  /// present over the splash and be destroyed by that navigation a moment
  /// later. Call [releaseAutoOpen] once your main screen is mounted.
  static void holdAutoOpen() {
    _autoOpenHeld = true;
  }

  /// Releases a [holdAutoOpen] and immediately attempts the once-a-day
  /// auto-open if it is due. Safe to call when the SDK is not configured,
  /// and safe to call repeatedly.
  static Future<void> releaseAutoOpen() async {
    _autoOpenHeld = false;
    await _autoPresentIfEligible();
  }

  /// Presents the experience automatically, at most once per calendar day,
  /// when all conditions allow. Called after registration completes and on
  /// each app foreground. All short-circuits are silent by design.
  static Future<void> _autoPresentIfEligible() async {
    if (_autoOpenHeld) {
      Logger.instance
          .debug('Auto-present deferred: host is holding auto-open (boot)');
      return;
    }
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

    _userDismissedExperience = false;
    final pushedAt = DateTime.now();
    DailyEntryGrant? grant;
    try {
      grant = await _present(presentContext);
    } catch (_) {
      return; // suspended / opted out — already logged by _present.
    }

    // Route completed with no grant and no user-tapped dismiss shortly after
    // opening: host navigation (splash → Get.offAll etc.) destroyed the
    // drawer before the user could interact. Refund the once-a-day flag and
    // the impression, and retry after the boot navigation settles.
    final killedExternally = grant == null &&
        !_userDismissedExperience &&
        DateTime.now().difference(pushedAt) < const Duration(seconds: 5);
    if (killedExternally && _autoPresentRetries < _maxAutoPresentRetries) {
      _autoPresentRetries += 1;
      Logger.instance
          .info('Auto-presented experience was removed by host navigation — '
              'retrying ($_autoPresentRetries/$_maxAutoPresentRetries). '
              'If your app boots through a splash screen that clears the '
              'navigation stack, call WINR.holdAutoOpen() during boot and '
              'WINR.releaseAutoOpen() once your main screen is mounted.');
      await prefs.remove(_lastAutoPresentKey);
      if (pendingImpressionCount) {
        final seen = prefs.getInt(_unregisteredImpressionsKey) ?? 0;
        if (seen > 0) {
          await prefs.setInt(_unregisteredImpressionsKey, seen - 1);
        }
      }
      unawaited(Future<void>.delayed(
          const Duration(seconds: 2), _autoPresentIfEligible));
      return;
    }
    _autoPresentRetries = 0;
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
    Logger.instance
        .info('User opted out of WINR (RTD) — experience permanently silenced');
  }

  /// @internal — Records the RTD flag (from the backend or [optOut]) so the
  /// suppression holds on future launches even offline.
  static void markOptedOut() {
    _cachedOptedOut = true;
    unawaited(SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_optedOutKey, true)));
  }

  /// @internal — Records that the person just completed email capture.
  ///
  /// [_cachedEmailConsent] is otherwise only ever refreshed by
  /// getActiveGiveaway, so between a successful submit and the next refresh
  /// the SDK still believed the user was unregistered and would have counted
  /// their next auto-open against the unregistered impression cap. In
  /// practice the once-a-day mark is checked FIRST, so today the stale flag
  /// is never reached — this makes the correctness explicit instead of
  /// leaving it dependent on the order of two unrelated guards.
  static void markEmailConsentGranted() {
    _cachedEmailConsent = true;
  }

  /// @internal — Clears the cached pending-adoption flag once the person
  /// completes (or the backend disowns) the re-staged adoption, so later
  /// drawer opens don't re-stage a resolved flow.
  static void clearAdoptionPending() {
    _cachedAdoptionPending = null;
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
          // No route-level transition: the experience widget animates its own
          // scrim fade and sheet slide, and finishes them BEFORE popping. A
          // route fade on top double-exposes the still-visible sheet over the
          // host app during dismissal.
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
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
            adoptionPending: _cachedAdoptionPending,
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

  /// Right-to-be-Forgotten (GDPR/CCPA)
  ///
  /// `deleteUserData()` was REMOVED. It called a backend hard-delete that wiped the
  /// user's entries, leaving no tombstone — so delete -> re-register -> claim again
  /// the same day farmed unlimited entries. It also destroyed the records proving the
  /// drawing was fair, and left prize-claim PII orphaned.
  ///
  /// Use [optOut] instead. It is the correct erasure: identity-wide, PII scrubbed
  /// everywhere including prize claims, tombstoned so it survives a reinstall, and
  /// the experience stays permanently silenced on the device.

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
      _cachedAdoptionPending = response.adoptionPending;
      if (response.optedOut == true) markOptedOut();

      // Cache streak state
      if (response.giveaway != null) {
        await preferencesStorage.cacheGiveaway(response.giveaway!);
      }
      _prewarmPublisherArt();

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

  /// Decodes the publisher's remote art (prize hero + logo) into the image
  /// cache as soon as the SDK learns the giveaway config — registration and
  /// every giveaway refresh — so the drawer paints the prize card complete on
  /// its first frame instead of the art popping in after everything else.
  /// Fire-and-forget; failures just fall back to loading at display time.
  static void _prewarmPublisherArt() {
    WINRV2ImageWarmer.prewarm(_cachedGiveaway?.prizeImageUrl);
    WINRV2ImageWarmer.prewarm(_cachedSdkConfig?.branding?.logoUrl);
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
      _cachedAdoptionPending = response.adoptionPending;
      if (response.optedOut == true) markOptedOut();

      // Update cached data
      if (response.giveaway != null) {
        await _preferencesStorage!.cacheGiveaway(response.giveaway!);
      }
      _prewarmPublisherArt();

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

  /// @internal — Session-expired recovery for the experience's RETRY button.
  ///
  /// Mirrors the automatic stale-token path in [_registerDeviceIfNeeded]:
  /// clears the dead credentials and re-runs the device-registration
  /// handshake so the shared network client holds a fresh token before the
  /// experience reloads. Safe no-op when the SDK facade isn't configured
  /// (e.g. widget tests that mount the experience directly).
  static Future<void> recoverExpiredSession() async {
    final secureStorage = _secureStorage;
    if (secureStorage == null || _configuration == null) return;
    _networkClient?.setAuthToken(null);
    await secureStorage.deleteAuthData();
    await _registerDeviceIfNeeded();
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
      // Guests get the SDK-minted stable id (persisted, so attribution doesn't
      // churn per session); a later configure with the signed-in user
      // overwrites it in place.
      final effectiveId = user.isGuest ? await _loadOrCreateGuestId() : user.id;
      final request = SubmitUserProfileRequest(
        firstName: _validName(user.firstName),
        lastName: _validName(user.lastName),
        phone: _validPhone(user.phone),
        publisherUserId: effectiveId,
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

  /// Stable per-install guest identity, minted on first use.
  static Future<String> _loadOrCreateGuestId() async {
    const key = 'winr_guest_id';
    final existing = await _preferencesStorage?.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    // 128 bits from the platform CSPRNG — collision-safe without a uuid dep.
    final rng = Random.secure();
    final hex = List.generate(
        16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final fresh = 'winr_guest_$hex';
    await _preferencesStorage?.setString(key, fresh);
    return fresh;
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
    _cachedAdoptionPending = null;
    _cachedOptedOut = false;
    _isRegistering = false;
    _registrationCompleter = null;
    _isSuspended = false;
    _isPresenting = false;
    _autoOpenHeld = false;
    _userDismissedExperience = false;
    _autoPresentRetries = 0;
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
