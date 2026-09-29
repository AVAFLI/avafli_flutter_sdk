// 24-hour rejoin after "Delete my data" (3.2.0 spec, Part B).
//
// Deleting blocks the email and the device for 24 hours. Until then nothing
// changes (no presentation, present() is a no-op); after it, the next
// configure() / app-foreground clears the opt-out AND the old session, and
// the device registers as a brand-new participant.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avafli_sdk/src/network/api_request.dart';
import 'package:avafli_sdk/src/network/avafli_api.dart';
import 'package:avafli_sdk/src/network/network_client.dart';
import 'package:avafli_sdk/src/storage/secure_storage.dart';
import 'package:avafli_sdk/src/storage/storage.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_experience.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_strings.dart';
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

/// Scripted backend. `optedOut` / `optedOutUntil` are what the server says
/// about this device on registerDevice and getActiveGiveaway.
class _FakeNetworkClient implements NetworkClient {
  bool optedOut = false;
  DateTime? optedOutUntil;

  /// When set, registerDevice waits on it before answering.
  Completer<void>? registerGate;

  final List<ApiRequest<dynamic>> requests = [];
  final List<String?> authTokens = [];

  int get registerCalls => requests.whereType<RegisterDeviceRequest>().length;
  int get statusCalls => requests.whereType<GetActiveGiveawayRequest>().length;

  @override
  Future<T> send<T>(ApiRequest<T> request) async {
    requests.add(request);
    if (request is RegisterDeviceRequest) {
      final gate = registerGate;
      if (gate != null) await gate.future;
      return RegisterDeviceResponse(
        token: 'token-new',
        refreshToken: 'refresh-new',
        uuid: 'uuid-new',
        giveaway: optedOut ? null : _giveaway(),
        isNewUser: !optedOut,
        optedOut: optedOut,
        optedOutUntil: optedOut ? optedOutUntil : null,
      ) as T;
    }
    if (request is SubmitUserProfileRequest || request is OptOutRequest) {
      return const SuccessResponse(success: true) as T;
    }
    if (request is GetActiveGiveawayRequest) {
      return GetActiveGiveawayResponse(
        giveaway: optedOut ? null : _giveaway(),
        optedOut: optedOut,
        optedOutUntil: optedOut ? optedOutUntil : null,
      ) as T;
    }
    return Completer<T>().future; // drawer-internal calls: never complete
  }

  @override
  void setAuthToken(String? token) => authTokens.add(token);

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
const _optedOutKey = 'winr_opted_out_$_bundleId';
const _optedOutUntilKey = 'winr_opted_out_until_$_bundleId';
const _lastAutoPresentKey = 'winr_last_auto_present_$_bundleId';
const _lastClaimAutoPresentKey = 'winr_last_claim_auto_present_$_bundleId';
const _impressionsKey = 'winr_unregistered_impressions_$_bundleId';
const _adoptionStampKey = '${StorageKeys.adoptionCodeSentAt}_$_bundleId';
const _guestIdKey = 'winr_guest_id';

/// Every piece of the old session the rejoin must clear.
const _oldSessionKeys = [
  _optedOutKey,
  _optedOutUntilKey,
  StorageKeys.emailConfirmed,
  StorageKeys.cachedGiveaway,
  StorageKeys.streakState,
  StorageKeys.lastClaimedDate,
  StorageKeys.claimedTodayDate,
  _lastAutoPresentKey,
  _lastClaimAutoPresentKey,
  _impressionsKey,
  _adoptionStampKey,
  StorageKeys.offlinePendingIntents,
];

String _day(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// The device as the erased account left it, opted out until [until]
/// (null = an opt-out cached by a pre-3.2.0 build: no time stored).
Map<String, Object> _oldSession({required DateTime? until}) {
  final now = DateTime.now();
  return <String, Object>{
    _optedOutKey: true,
    if (until != null) _optedOutUntilKey: until.millisecondsSinceEpoch,
    StorageKeys.emailConfirmed: true,
    StorageKeys.cachedGiveaway: jsonEncode(_giveaway().toJson()),
    StorageKeys.streakState: jsonEncode(const StreakState(
      currentDay: 5,
      totalEntriesEarned: 470,
      weeklyCurrent: 5,
      monthlyCurrent: 5,
    ).toJson()),
    StorageKeys.lastClaimedDate: now.toIso8601String(),
    StorageKeys.claimedTodayDate: _day(now),
    _lastAutoPresentKey: _day(now),
    _lastClaimAutoPresentKey: now.millisecondsSinceEpoch,
    _impressionsKey: 3,
    _adoptionStampKey: now.millisecondsSinceEpoch,
    StorageKeys.offlinePendingIntents: jsonEncode([
      {
        'kind': 'claim',
        'dayKey': _day(now),
        'createdAtMs': now.millisecondsSinceEpoch,
      }
    ]),
    // Not part of the session: the device's own identity stays.
    _guestIdKey: 'avafli_guest_0123456789abcdef',
  };
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

/// Lets configure's background registration → auto-present chain run.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmounts everything (drains the drawer's own timers first).
Future<void> _teardown(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _closeDrawer(WidgetTester tester) async {
  final ctx = tester.element(find.byType(AvafliV2Experience));
  Navigator.of(ctx).pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late _FakeNetworkClient client;
  late _MemorySecureStorage secure;

  /// The test's wall clock (the SDK reads it through its test seam).
  late DateTime now;

  Future<void> seedOldCredentials() async {
    await secure.saveAuthToken('token-old');
    await secure.saveRefreshToken('refresh-old');
    await secure.saveUserUuid('uuid-old');
  }

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

  test('optedOutUntil parses on both responses (absent → null)', () {
    final registered = RegisterDeviceResponse.fromJson({
      'token': 't',
      'refreshToken': 'r',
      'uuid': 'u',
      'optedOut': true,
      'optedOutUntil': '2026-09-30T12:00:00.000Z',
    });
    expect(registered.optedOutUntil, DateTime.utc(2026, 9, 30, 12));

    final status = GetActiveGiveawayResponse.fromJson({
      'optedOut': true,
      'optedOutUntil': '2026-09-30T12:00:00.000Z',
    });
    expect(status.optedOutUntil, DateTime.utc(2026, 9, 30, 12));

    expect(
        RegisterDeviceResponse.fromJson(
            {'token': 't', 'refreshToken': 'r', 'uuid': 'u'}).optedOutUntil,
        isNull);
    expect(GetActiveGiveawayResponse.fromJson({'optedOut': true}).optedOutUntil,
        isNull);
    expect(
        GetActiveGiveawayResponse.fromJson(
            {'optedOut': true, 'optedOutUntil': 'soon'}).optedOutUntil,
        isNull);
  });

  test('the delete confirmation no longer promises a permanent block', () {
    expect(
        AvafliV2Strings.optOutBody,
        'This permanently erases your information and ends your '
        'participation. Entries and streaks are forfeited and cannot be '
        'restored. You can join again as a new participant after 24 hours.');
  });

  testWidgets(
      'opted out, block still running → nothing changes: the old session '
      'stays, no re-registration, no presentation, present() is a no-op',
      (tester) async {
    final until = now.add(const Duration(hours: 5));
    final seeded = _oldSession(until: until);
    SharedPreferences.setMockInitialValues(seeded);
    await seedOldCredentials();
    client
      ..optedOut = true
      ..optedOutUntil = until;

    await _pumpHost(tester);
    expect(await Avafli.configure(_config()), isTrue);
    await _settle(tester);

    // Exactly the network traffic an opted-out launch made before 3.2.0:
    // the profile, the status refresh on the cached session, and the replay
    // of the claim retry that was already queued. No registration.
    expect(client.registerCalls, 0);
    expect(client.statusCalls, 1);
    expect(client.requests.map((r) => r.runtimeType).toSet(), {
      SubmitUserProfileRequest,
      GetActiveGiveawayRequest,
      ClaimDailyEntriesRequest,
    });
    expect(client.requests, hasLength(3));

    expect(find.byType(AvafliV2Experience), findsNothing);
    expect(await Avafli.present(), isFalse);
    expect(find.byType(AvafliV2Experience), findsNothing);

    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(client.registerCalls, 0);
    expect(client.requests, hasLength(3));
    expect(find.byType(AvafliV2Experience), findsNothing);

    // Every piece of the old session is still there, untouched.
    final prefs = await SharedPreferences.getInstance();
    for (final entry in seeded.entries) {
      expect(prefs.get(entry.key), entry.value, reason: entry.key);
    }
    expect(await secure.getAuthToken(), 'token-old');
    expect(await secure.getRefreshToken(), 'refresh-old');
    expect(await secure.getUserUuid(), 'uuid-old');
    await _teardown(tester);
  });

  testWidgets(
      'opted out, block passed → the old session is cleared key by key, '
      'registerDevice runs, and the normal flow follows', (tester) async {
    SharedPreferences.setMockInitialValues(
        _oldSession(until: now.subtract(const Duration(minutes: 1))));
    await seedOldCredentials();
    // Hold the new registration so the cleared state can be inspected
    // before anything new is written.
    client.registerGate = Completer<void>();

    await _pumpHost(tester);
    expect(await Avafli.configure(_config()), isTrue);
    await _settle(tester);

    final prefs = await SharedPreferences.getInstance();
    for (final key in _oldSessionKeys) {
      expect(prefs.containsKey(key), isFalse, reason: '$key must be cleared');
    }
    expect(await secure.getAuthToken(), isNull);
    expect(await secure.getRefreshToken(), isNull);
    expect(await secure.getUserUuid(), isNull);
    expect(secure.map, isEmpty);
    expect(client.authTokens, contains(null),
        reason: 'the old token is dropped from the network client');
    // The device's own identity is kept.
    expect(prefs.getString(_guestIdKey), 'avafli_guest_0123456789abcdef');

    // No old-session call: straight to a fresh registration.
    expect(client.statusCalls, 0);
    expect(client.registerCalls, 1);
    expect(find.byType(AvafliV2Experience), findsNothing);

    client.registerGate!.complete();
    await _settle(tester);

    // A brand-new participant…
    expect(await secure.getAuthToken(), 'token-new');
    expect(await secure.getUserUuid(), 'uuid-new');
    expect(Avafli.isNewUserSessionForTesting, isTrue);
    expect(prefs.getBool(_optedOutKey), isNull);
    expect(client.registerCalls, 1);
    // …who gets the normal auto-open, counted as an unregistered impression
    // from zero, and lands on email capture.
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(find.byType(AvafliV2CaptureView), findsOneWidget);
    expect(prefs.getInt(_impressionsKey), 1);
    expect(prefs.getBool(StorageKeys.emailConfirmed), isNull);

    await _closeDrawer(tester);
    await _teardown(tester);
  });

  testWidgets('the block also lifts on app-foreground', (tester) async {
    final until = now.add(const Duration(hours: 1));
    SharedPreferences.setMockInitialValues(_oldSession(until: until));
    await seedOldCredentials();
    client
      ..optedOut = true
      ..optedOutUntil = until;

    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never));
    await _settle(tester);
    expect(client.registerCalls, 0);
    expect(await Avafli.present(), isFalse);

    // The app sat in memory past the moment; the server has let go too.
    now = until.add(const Duration(seconds: 1));
    client.optedOut = false;
    await Avafli.handleAppResumed();
    await _settle(tester);

    expect(client.registerCalls, 1);
    expect(await secure.getAuthToken(), 'token-new');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_optedOutKey), isFalse);
    expect(prefs.containsKey(_optedOutUntilKey), isFalse);
    expect(prefs.containsKey(StorageKeys.emailConfirmed), isFalse);

    // present() works again.
    final presented = Avafli.present();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    await _closeDrawer(tester);
    expect(await presented, isTrue);
    await _teardown(tester);
  });

  testWidgets(
      'a legacy cached opt-out with no time gets one stamped, and lifts '
      '24 hours later', (tester) async {
    SharedPreferences.setMockInitialValues(_oldSession(until: null));
    await seedOldCredentials();
    // An older backend: opted out, and no optedOutUntil to offer.
    client.optedOut = true;
    final firstSeen = now;

    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(_optedOutUntilKey),
        firstSeen.add(const Duration(hours: 24)).millisecondsSinceEpoch,
        reason: 'until = first seen + 24 h');
    expect(prefs.getBool(_optedOutKey), isTrue);
    expect(client.registerCalls, 0);
    expect(find.byType(AvafliV2Experience), findsNothing);
    expect(await secure.getAuthToken(), 'token-old');

    // 23 hours on: still blocked, and the stamp has not slid.
    now = firstSeen.add(const Duration(hours: 23));
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(client.registerCalls, 0);
    expect(prefs.getInt(_optedOutUntilKey),
        firstSeen.add(const Duration(hours: 24)).millisecondsSinceEpoch);
    expect(await Avafli.present(), isFalse);

    // 24 hours on: lifted.
    now = firstSeen.add(const Duration(hours: 24));
    client.optedOut = false;
    final resumed = Avafli.handleAppResumed();
    await _settle(tester);

    expect(client.registerCalls, 1);
    expect(prefs.containsKey(_optedOutKey), isFalse);
    expect(prefs.containsKey(_optedOutUntilKey), isFalse);
    expect(await secure.getUserUuid(), 'uuid-new');
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    await _closeDrawer(tester);
    await resumed;
    await _teardown(tester);
  });

  testWidgets(
      'the server still reports opted out → its time is adopted and the '
      'SDK waits for it; never a loop', (tester) async {
    SharedPreferences.setMockInitialValues(
        _oldSession(until: now.subtract(const Duration(minutes: 5))));
    await seedOldCredentials();
    // Clock skew / sweep lag: the server's block runs two more hours.
    final serverUntil = now.add(const Duration(hours: 2));
    client
      ..optedOut = true
      ..optedOutUntil = serverUntil;

    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(client.registerCalls, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_optedOutKey), isTrue);
    expect(prefs.getInt(_optedOutUntilKey), serverUntil.millisecondsSinceEpoch);
    expect(find.byType(AvafliV2Experience), findsNothing);
    expect(await Avafli.present(), isFalse);

    // Foreground after foreground: no further registration attempts.
    final requestsAfterBoot = client.requests.length;
    for (var i = 0; i < 3; i++) {
      now = now.add(const Duration(minutes: 10));
      await Avafli.handleAppResumed();
      await _settle(tester);
    }
    expect(client.registerCalls, 1);
    expect(client.requests.length, requestsAfterBoot);
    expect(prefs.getInt(_optedOutUntilKey), serverUntil.millisecondsSinceEpoch);

    // After the server's time: one more try, and this one goes through.
    now = serverUntil.add(const Duration(seconds: 1));
    client.optedOut = false;
    final resumed = Avafli.handleAppResumed();
    await _settle(tester);

    expect(client.registerCalls, 2);
    expect(prefs.containsKey(_optedOutKey), isFalse);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    await _closeDrawer(tester);
    await resumed;
    await _teardown(tester);
  });

  testWidgets(
      'the server still reports opted out with a time this clock has '
      'already passed → a bounded wait, not a retry per foreground',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        _oldSession(until: now.subtract(const Duration(minutes: 5))));
    await seedOldCredentials();
    client
      ..optedOut = true
      ..optedOutUntil = now.subtract(const Duration(minutes: 1));

    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(client.registerCalls, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_optedOutKey), isTrue);
    expect(prefs.getInt(_optedOutUntilKey),
        now.add(const Duration(minutes: 15)).millisecondsSinceEpoch);

    for (var i = 0; i < 3; i++) {
      await Avafli.handleAppResumed();
      await _settle(tester);
    }
    expect(client.registerCalls, 1);
    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets('optOut() stores the moment the block lifts: now + 24 hours',
      (tester) async {
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never));
    await _settle(tester);
    expect(client.registerCalls, 1);

    await Avafli.optOut();
    await _settle(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_optedOutKey), isTrue);
    expect(prefs.getInt(_optedOutUntilKey),
        now.add(const Duration(hours: 24)).millisecondsSinceEpoch);
    expect(await Avafli.present(), isFalse);

    // Still blocked a minute before; a new participant a minute after.
    now = now.add(const Duration(hours: 23, minutes: 59));
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(client.registerCalls, 1);

    now = now.add(const Duration(minutes: 2));
    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(client.registerCalls, 2);
    expect(prefs.containsKey(_optedOutKey), isFalse);
    await _teardown(tester);
  });
}
