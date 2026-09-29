// Winners can always reopen a pending claim (3.2.0 addendum).
//
// The auto-open used to gate on the once-a-day mark alone, so a winner who
// closed the drawer could not get back to their claim until the next
// calendar day. While `prizeClaim.status == "pending"` the auto-open now
// bypasses the daily mark, the unregistered impression cap and the
// returningUsersOnly mode — and still respects the hold, the opt-out, a
// suspended publisher, the kill switch and mode never. Throttle: every cold
// start, and a foreground at most once per 30 minutes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avafli_sdk/src/network/api_request.dart';
import 'package:avafli_sdk/src/network/avafli_api.dart';
import 'package:avafli_sdk/src/network/network_client.dart';
import 'package:avafli_sdk/src/storage/secure_storage.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_claim.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_experience.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';
import 'package:avafli_sdk/avafli_sdk.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

Giveaway _giveaway() => const Giveaway(
      id: 'g1',
      title: 'Test Giveaway',
      period: GiveawayPeriod.monthly,
      maxDailyBaseEntries: 300,
      doublingEnabled: false,
      streakConfig: StreakConfig(),
      streakLadder: [10, 30, 60, 130, 240, 300, 500],
      milestones: [MilestoneConfig(day: 7, bonusEntries: 25)],
      prizeDescription: '',
      prizeValue: 1000,
      rulesUrl: 'https://example.com/rules',
    );

/// Scripted backend: registration and status both carry [claimStatus]'s
/// `prizeClaim` block (null = no block at all).
class _FakeNetworkClient implements NetworkClient {
  String? claimStatus = 'pending';
  bool? isNewUser;
  bool withGiveaway = true;
  bool emailConsent = true;
  Map<String, dynamic>? sdkConfig;

  final List<ApiRequest<dynamic>> requests = [];

  PrizeClaimBlock? get _claim {
    final status = claimStatus;
    if (status == null) return null;
    return PrizeClaimBlock(
      status: status,
      giveawayId: 'g0',
      prizeDescription: 'Cash prize',
      prizeValue: 1000,
      maskedEmail: 'w****r@avafli.example.com',
      claimNumber: status == 'submitted' ? 'C-1' : null,
    );
  }

  @override
  Future<T> send<T>(ApiRequest<T> request) async {
    requests.add(request);
    if (request is RegisterDeviceRequest) {
      return RegisterDeviceResponse(
        token: 'token-1',
        refreshToken: 'refresh-1',
        uuid: 'uuid-1',
        giveaway: withGiveaway ? _giveaway() : null,
        sdkConfig: sdkConfig,
        isNewUser: isNewUser,
        prizeClaim: _claim,
      ) as T;
    }
    if (request is SubmitUserProfileRequest) {
      return const SuccessResponse(success: true) as T;
    }
    if (request is GetActiveGiveawayRequest) {
      return GetActiveGiveawayResponse(
        giveaway: withGiveaway ? _giveaway() : null,
        claimedToday: true,
        streakDay: 3,
        totalEntries: 40,
        weeklyCurrent: 3,
        monthlyCurrent: 3,
        emailConsentStatus: emailConsent,
        sdkConfig: sdkConfig,
        prizeClaim: _claim,
      ) as T;
    }
    return Completer<T>().future; // drawer-internal calls: never complete
  }

  @override
  void setAuthToken(String? token) {}

  @override
  void setRefreshHandler(Future<String?> Function() handler) {}
}

/// In-memory keychain — the real one has no plugin host under `flutter test`.
class _MemorySecureStorage extends SecureStorage {
  final Map<String, String> map = {};

  @override
  Future<void> setString(String key, String value) async => map[key] = value;

  @override
  Future<String?> getString(String key) async => map[key];

  @override
  Future<void> remove(String key) async => map.remove(key);

  @override
  Future<void> clear() async => map.clear();

  @override
  Future<bool> containsKey(String key) async => map.containsKey(key);
}

const _bundleId = 'com.example.test';
const _lastAutoPresentKey = 'winr_last_auto_present_$_bundleId';
const _lastClaimAutoPresentKey = 'winr_last_claim_auto_present_$_bundleId';
const _impressionsKey = 'winr_unregistered_impressions_$_bundleId';
const _optedOutKey = 'winr_opted_out_$_bundleId';
const _optedOutUntilKey = 'winr_opted_out_until_$_bundleId';

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

AvafliConfiguration _config({AvafliAutoOpen? autoOpen}) => AvafliConfiguration(
      apiKey: 'winr_test_key',
      bundleId: _bundleId,
      user: const AvafliUser(id: 'user-1'),
      options: const AvafliOptions(enablePushReminders: false),
      autoOpen: autoOpen ?? AvafliAutoOpen.always,
    );

/// Host app with the SDK navigator key attached.
Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    navigatorKey: Avafli.navigatorKey,
    home: const Scaffold(body: SizedBox.expand()),
  ));
}

/// Lets registration → auto-present → the drawer's own status call run.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The person closes the drawer themselves (X / GOT IT).
Future<void> _userCloses(WidgetTester tester) async {
  Avafli.noteUserDismissedExperience();
  final ctx = tester.element(find.byType(AvafliV2Experience));
  Navigator.of(ctx).pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Host navigation (a splash finishing with `offAll`) destroys the drawer.
Future<void> _hostKillsDrawer(WidgetTester tester) async {
  final ctx = tester.element(find.byType(AvafliV2Experience));
  Navigator.of(ctx).pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Unmounts everything (drains the drawer's own timers first).
Future<void> _teardown(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  late _FakeNetworkClient client;
  late _MemorySecureStorage secure;

  /// The test's wall clock (the SDK reads it through its test seam).
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Avafli.resetForTesting();
    Avafli.navigatorKey = GlobalKey<NavigatorState>();
    client = _FakeNetworkClient();
    secure = _MemorySecureStorage();
    Avafli.networkClientForTesting = client;
    Avafli.secureStorageForTesting = secure;
    now = DateTime.now();
    Avafli.clockForTesting = () => now;
  });

  tearDown(Avafli.resetForTesting);

  testWidgets(
      'pending claim + the daily mark already set today → opens on '
      'configure, on the winner splash', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _lastAutoPresentKey: _today(), // the day was already "spent"
    });
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastAutoPresentKey), _today());
    expect(prefs.getInt(_lastClaimAutoPresentKey), now.millisecondsSinceEpoch,
        reason: 'the throttle has its own stamp');

    await _userCloses(tester);
    await _teardown(tester);
  });

  testWidgets(
      'resume inside 30 minutes → does not reopen; after 30 minutes → '
      'reopens', (tester) async {
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    final opened = now;
    await _userCloses(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);

    now = opened.add(const Duration(minutes: 5));
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);

    now = opened.add(const Duration(minutes: 29, seconds: 59));
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getInt(_lastClaimAutoPresentKey), opened.millisecondsSinceEpoch);

    now = opened.add(const Duration(minutes: 30));
    final resumed = Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    expect(prefs.getInt(_lastClaimAutoPresentKey), now.millisecondsSinceEpoch);

    await _userCloses(tester);
    await resumed;
    await _teardown(tester);
  });

  testWidgets('every cold start opens it, however recent the last open',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _lastAutoPresentKey: _today(),
      _lastClaimAutoPresentKey:
          now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    });
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    await _userCloses(tester);
    await _teardown(tester);
  });

  testWidgets(
      'mode never → no auto-open, but present() lands on the winner '
      'splash', (tester) async {
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never));
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);

    now = now.add(const Duration(hours: 1));
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(_lastClaimAutoPresentKey), isNull);

    final presented = Avafli.present();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);

    await _userCloses(tester);
    expect(await presented, isTrue);
    await _teardown(tester);
  });

  testWidgets('server mode never silences it too', (tester) async {
    client.sdkConfig = {
      'experience': {'autoOpenMode': 'never'}
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      _lastAutoPresentKey: _today(),
    });
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets('the server kill switch still wins', (tester) async {
    client.sdkConfig = {
      'experience': {'autoOpenEnabled': false}
    };
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets('an opted-out person is never shown it', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _optedOutKey: true,
      _optedOutUntilKey:
          now.add(const Duration(hours: 5)).millisecondsSinceEpoch,
    });
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsNothing);
    expect(await Avafli.present(), isFalse);
    await _teardown(tester);
  });

  testWidgets('held → deferred, then opens on release', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _lastAutoPresentKey: _today(),
      // Opened a minute ago in the previous run: only the cold-start rule
      // can open it now.
      _lastClaimAutoPresentKey:
          now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    });
    Avafli.holdAutoOpen();
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);

    // A foreground during the boot flow changes nothing.
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);

    final released = Avafli.releaseAutoOpen();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);

    await _userCloses(tester);
    await released;

    // A second release is an ordinary, throttled attempt.
    await Avafli.releaseAutoOpen();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets('status "submitted" → the normal once-a-day rules again',
      (tester) async {
    client.claimStatus = 'submitted';
    SharedPreferences.setMockInitialValues(<String, Object>{
      _lastAutoPresentKey: _today(),
    });
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);

    now = now.add(const Duration(hours: 1));
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(_lastClaimAutoPresentKey), isNull);
    await _teardown(tester);
  });

  testWidgets(
      'status "submitted" with the day unspent → one ordinary auto-open, '
      'on the dashboard', (tester) async {
    client.claimStatus = 'submitted';
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(find.byType(AvafliV2WinnerSplashView), findsNothing);
    expect(find.byType(AvafliV2DashboardView), findsOneWidget);
    await _userCloses(tester);

    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets('the claim leaving pending mid-session restores the daily rule',
      (tester) async {
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    await _userCloses(tester);

    // Claimed from another device in the meantime: the next open's status
    // call says so, and the flag follows it.
    client.claimStatus = 'submitted';
    now = now.add(const Duration(minutes: 31));
    final resumed = Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(find.byType(AvafliV2WinnerSplashView), findsNothing);
    await _userCloses(tester);
    await resumed;

    now = now.add(const Duration(minutes: 31));
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets('the impression cap neither blocks it nor counts it',
      (tester) async {
    client.emailConsent = false;
    SharedPreferences.setMockInitialValues(<String, Object>{
      _lastAutoPresentKey: _today(),
      _impressionsKey: 3, // cap reached
    });
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(_impressionsKey), 3);

    await _userCloses(tester);
    now = now.add(const Duration(minutes: 30));
    final resumed = Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    expect(prefs.getInt(_impressionsKey), 3);
    await _userCloses(tester);
    await resumed;
    await _teardown(tester);
  });

  testWidgets('no impression is counted from zero either', (tester) async {
    client.emailConsent = false;
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(_impressionsKey), isNull);
    await _userCloses(tester);
    await _teardown(tester);
  });

  testWidgets('returningUsersOnly (client) does not hold a winner back',
      (tester) async {
    client.isNewUser = true;
    await _pumpHost(tester);
    await Avafli.configure(
        _config(autoOpen: AvafliAutoOpen.returningUsersOnly));
    await _settle(tester);

    expect(Avafli.isNewUserSessionForTesting, isTrue);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    await _userCloses(tester);
    await _teardown(tester);
  });

  testWidgets('returningUsersOnly (server) does not hold a winner back',
      (tester) async {
    client.isNewUser = true;
    client.sdkConfig = {
      'experience': {'autoOpenMode': 'returningUsersOnly'}
    };
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    await _userCloses(tester);
    await _teardown(tester);
  });

  testWidgets('a claim that outlived its giveaway still opens', (tester) async {
    client.withGiveaway = false;
    SharedPreferences.setMockInitialValues(<String, Object>{
      _lastAutoPresentKey: _today(),
    });
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    await _userCloses(tester);

    final presented = Avafli.present();
    await _settle(tester);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    await _userCloses(tester);
    expect(await presented, isTrue);
    await _teardown(tester);
  });

  testWidgets(
      'a drawer destroyed by host navigation is refunded and retried: the '
      'earlier daily mark survives and the throttle does not block the '
      'retry', (tester) async {
    const earlierToday = 'earlier-mark';
    final lastOpen =
        now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      _lastAutoPresentKey: earlierToday,
      _lastClaimAutoPresentKey: lastOpen,
    });
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);

    await _hostKillsDrawer(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AvafliV2Experience), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastAutoPresentKey), earlierToday,
        reason: 'put back exactly as it was');
    expect(prefs.getInt(_lastClaimAutoPresentKey), lastOpen);

    // The retry (2 s later) opens it again.
    await tester.pump(const Duration(seconds: 2));
    await _settle(tester);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);
    expect(prefs.getInt(_lastClaimAutoPresentKey), now.millisecondsSinceEpoch);

    await _userCloses(tester);
    await _teardown(tester);
  });

  testWidgets('submitting the claim ends the bypass for the session',
      (tester) async {
    final backend = _SubmittingNetworkClient();
    Avafli.networkClientForTesting = backend;
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);
    expect(find.byType(AvafliV2WinnerSplashView), findsOneWidget);

    // Splash → form, straight to a filled review screen is not reachable
    // from here without typing; drive the experience's own submit through
    // the form widget's callback instead.
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('CONTINUE'));
    await _settle(tester);
    final form = tester
        .widget<AvafliV2ClaimStepsFlow>(find.byType(AvafliV2ClaimStepsFlow));
    form.onSubmit(AvafliPrizeClaimForm(
      firstName: 'Sam',
      lastName: 'Winner',
      street: '5 Haide Pl.',
      city: 'Brooklyn',
      state: 'New York',
      zip: '11737',
    ));
    await _settle(tester);
    expect(backend.requests.whereType<SubmitPrizeClaimRequest>().length, 1);
    expect(find.byType(AvafliV2ClaimShareView), findsOneWidget);

    await _userCloses(tester);
    now = now.add(const Duration(hours: 1));
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing,
        reason: 'the day is spent and no claim is pending any more');
    await _teardown(tester);
  });

  testWidgets('the rejoin clears the claim throttle stamp too', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _optedOutKey: true,
      _optedOutUntilKey:
          now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      _lastClaimAutoPresentKey:
          now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
    });
    client.claimStatus = null;
    await secure.saveAuthToken('token-old');
    await secure.saveUserUuid('uuid-old');
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never));
    await _settle(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_lastClaimAutoPresentKey), isFalse);
    expect(prefs.containsKey(_optedOutKey), isFalse);
    await _teardown(tester);
  });
}

/// [_FakeNetworkClient] that also accepts the prize-claim submit.
class _SubmittingNetworkClient extends _FakeNetworkClient {
  @override
  Future<T> send<T>(ApiRequest<T> request) async {
    if (request is SubmitPrizeClaimRequest) {
      requests.add(request);
      claimStatus = 'submitted';
      return const SubmitPrizeClaimResponse(
        claimNumber: 'C-1',
        submittedAt: '2026-09-29T12:00:00.000Z',
      ) as T;
    }
    return super.send(request);
  }
}
