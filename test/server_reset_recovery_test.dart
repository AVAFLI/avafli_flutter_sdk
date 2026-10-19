// 3.2.2: identity-scoped local state is reconciled with the server.
//
// Scenario (Skape, Oct 2026): the account behind a device was deleted on the
// server. The device still held the "email submitted" flag, a Day-5 streak
// and a claimed-today stamp. Its cached token expired, registerDevice minted a
// FRESH user (isNewUser: true, no email on file), and the SDK — trusting the
// stale flags — skipped email capture and auto-claimed. The backend refused
// every claim with "email required"; the person saw a Day-1 dashboard forever.
//
// The load-bearing rules under test:
//   * registerDevice with `isNewUser: true` → cached identity state is
//     dropped, the drawer lands on email capture, NO claim is attempted;
//   * a returning device (`isNewUser: false`, email on file) → nothing is
//     dropped and the normal auto-claim runs;
//   * a cached session whose status call says `emailConsentStatus: false` →
//     the email flag is dropped (streak snapshot left to the status reconcile);
//   * a backend that predates these fields leaves local state alone;
//   * a claim refused with `emailRequired` (older backend, stale flag) → the
//     flag is dropped and the drawer moves to email capture, no retry queued.

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
import 'package:avafli_sdk/avafli_sdk.dart';

Giveaway _giveaway() => const Giveaway(
      id: 'g1',
      title: 'Test Giveaway',
      period: GiveawayPeriod.monthly,
      maxDailyBaseEntries: 300,
      doublingEnabled: false,
      streakConfig: StreakConfig(),
      streakLadder: [10, 30, 60, 130, 240, 300, 500],
      prizeDescription: '',
      prizeValue: 1000,
      rulesUrl: 'https://example.com/rules',
    );

class _FakeNetworkClient implements NetworkClient {
  /// Whether the cached token is still good (status call succeeds) or stale
  /// (status call fails with authenticationFailed → re-registration).
  bool cachedTokenValid = true;

  /// What registerDevice answers.
  bool? registerIsNewUser;
  bool? registerEmailConsent;

  /// What getActiveGiveaway answers (null → field omitted, older backend).
  bool? statusEmailConsent;

  /// How claimDailyEntries answers: a grant, or a thrown error.
  Object? claimError;

  final List<ApiRequest<dynamic>> requests = [];

  int get registerCalls => requests.whereType<RegisterDeviceRequest>().length;
  int get statusCalls => requests.whereType<GetActiveGiveawayRequest>().length;
  int get claimCalls => requests.whereType<ClaimDailyEntriesRequest>().length;

  @override
  Future<T> send<T>(ApiRequest<T> request) async {
    requests.add(request);
    if (request is RegisterDeviceRequest) {
      // A fresh registration issues a good token: later status calls succeed.
      cachedTokenValid = true;
      return RegisterDeviceResponse(
        token: 'token-new',
        refreshToken: 'refresh-new',
        uuid: 'uuid-new',
        giveaway: _giveaway(),
        isNewUser: registerIsNewUser,
        emailConsentStatus: registerEmailConsent,
      ) as T;
    }
    if (request is GetActiveGiveawayRequest) {
      if (!cachedTokenValid) {
        throw const AvafliException(AvafliError.authenticationFailed);
      }
      return GetActiveGiveawayResponse(
        giveaway: _giveaway(),
        emailConsentStatus: statusEmailConsent ?? false,
        emailConsentStatusReported: statusEmailConsent,
      ) as T;
    }
    if (request is ClaimDailyEntriesRequest) {
      final err = claimError;
      if (err != null) throw err;
      return const ClaimDailyEntriesResponse(
        entries: 10,
        streakDay: 1,
        totalEntries: 10,
      ) as T;
    }
    if (request is SubmitUserProfileRequest) {
      return const SuccessResponse(success: true) as T;
    }
    return Completer<T>().future;
  }

  @override
  void setAuthToken(String? token) {}

  @override
  void setRefreshHandler(Future<String?> Function() handler) {}
}

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
const _adoptionStampKey = '${StorageKeys.adoptionCodeSentAt}_$_bundleId';

String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The local state of a device whose account was alive yesterday.
Map<String, Object> _staleIdentity() {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  return <String, Object>{
    StorageKeys.emailConfirmed: true,
    StorageKeys.cachedGiveaway: jsonEncode(_giveaway().toJson()),
    StorageKeys.streakState: jsonEncode(const StreakState(
      currentDay: 5,
      totalEntriesEarned: 470,
      weeklyCurrent: 5,
      monthlyCurrent: 5,
    ).toJson()),
    StorageKeys.lastClaimedDate: yesterday.toIso8601String(),
    StorageKeys.claimedTodayDate: _day(yesterday),
    _adoptionStampKey: yesterday.millisecondsSinceEpoch,
    StorageKeys.offlinePendingIntents: jsonEncode([
      {
        'kind': 'claim',
        'dayKey': _day(DateTime.now()),
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      }
    ]),
  };
}

const _identityKeys = [
  StorageKeys.emailConfirmed,
  StorageKeys.streakState,
  StorageKeys.lastClaimedDate,
  StorageKeys.claimedTodayDate,
  _adoptionStampKey,
];

AvafliConfiguration _config() => const AvafliConfiguration(
      apiKey: 'winr_test_key',
      bundleId: _bundleId,
      user: AvafliUser(id: 'user-1'),
      options: AvafliOptions(enablePushReminders: false),
      autoOpen: AvafliAutoOpen.always,
    );

Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    navigatorKey: Avafli.navigatorKey,
    home: const Scaffold(body: SizedBox.expand()),
  ));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _teardown(WidgetTester tester) async {
  final ctx = tester.any(find.byType(AvafliV2Experience))
      ? tester.element(find.byType(AvafliV2Experience))
      : null;
  if (ctx != null) {
    Navigator.of(ctx).pop();
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

bool _hasQueuedClaim(SharedPreferences prefs) {
  final raw = prefs.getString(StorageKeys.offlinePendingIntents);
  if (raw == null) return false;
  final list = jsonDecode(raw) as List<dynamic>;
  return list.any((e) => (e as Map<String, dynamic>)['kind'] == 'claim');
}

void main() {
  late _FakeNetworkClient client;
  late _MemorySecureStorage secure;

  Future<void> seedCredentials() async {
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
  });

  tearDown(Avafli.resetForTesting);

  test('RegisterDeviceResponse parses emailConsentStatus (absent → null)', () {
    expect(
      RegisterDeviceResponse.fromJson({
        'token': 't',
        'refreshToken': 'r',
        'uuid': 'u',
        'emailConsentStatus': false,
      }).emailConsentStatus,
      isFalse,
    );
    expect(
      RegisterDeviceResponse.fromJson(
          {'token': 't', 'refreshToken': 'r', 'uuid': 'u'}).emailConsentStatus,
      isNull,
    );
  });

  testWidgets(
      'account reset on the server: expired token → registerDevice mints a '
      'fresh user → stale identity state is dropped, the drawer lands on '
      'email capture and NO claim is attempted', (tester) async {
    SharedPreferences.setMockInitialValues(_staleIdentity());
    await seedCredentials();
    client
      ..cachedTokenValid = false
      ..registerIsNewUser = true
      ..registerEmailConsent = false;

    await _pumpHost(tester);
    expect(await Avafli.configure(_config()), isTrue);
    await _settle(tester);

    expect(client.registerCalls, 1);
    final prefs = await SharedPreferences.getInstance();
    for (final key in _identityKeys) {
      expect(prefs.containsKey(key), isFalse, reason: '$key must be dropped');
    }
    expect(_hasQueuedClaim(prefs), isFalse,
        reason: 'the dead account\'s queued claim must not replay');
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(find.byType(AvafliV2CaptureView), findsOneWidget);
    expect(client.claimCalls, 0);
    await _teardown(tester);
  });

  testWidgets(
      'returning device (isNewUser: false, email on file): nothing is '
      'dropped and the normal auto-claim runs', (tester) async {
    final seeded = _staleIdentity();
    SharedPreferences.setMockInitialValues(seeded);
    await seedCredentials();
    client
      ..cachedTokenValid = false
      ..registerIsNewUser = false
      ..registerEmailConsent = true
      ..statusEmailConsent = true;

    await _pumpHost(tester);
    expect(await Avafli.configure(_config()), isTrue);
    await _settle(tester);

    expect(client.registerCalls, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(StorageKeys.emailConfirmed), isTrue);
    expect(prefs.getString(StorageKeys.streakState), isNotNull);
    expect(find.byType(AvafliV2CaptureView), findsNothing);
    expect(client.claimCalls, greaterThanOrEqualTo(1),
        reason: 'requests: ${client.requests.map((r) => r.runtimeType).toList()} '
            'experience: ${find.byType(AvafliV2Experience).evaluate().length} '
            'capture: ${find.byType(AvafliV2CaptureView).evaluate().length}');
    await _teardown(tester);
  });

  testWidgets(
      'cached session, status says no email on file → the email flag is '
      'dropped and the drawer lands on email capture', (tester) async {
    SharedPreferences.setMockInitialValues(_staleIdentity());
    await seedCredentials();
    client
      ..cachedTokenValid = true
      ..statusEmailConsent = false;

    await _pumpHost(tester);
    expect(await Avafli.configure(_config()), isTrue);
    await _settle(tester);

    expect(client.registerCalls, 0);
    expect(client.statusCalls, greaterThanOrEqualTo(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(StorageKeys.emailConfirmed), isFalse);
    // Only the email flag: the streak snapshot is the status reconcile's job.
    expect(prefs.getString(StorageKeys.streakState), isNotNull);
    expect(find.byType(AvafliV2CaptureView), findsOneWidget);
    expect(client.claimCalls, 0);
    await _teardown(tester);
  });

  testWidgets(
      'cached session, older backend (status omits emailConsentStatus) → '
      'local state is left alone', (tester) async {
    SharedPreferences.setMockInitialValues(_staleIdentity());
    await seedCredentials();
    client
      ..cachedTokenValid = true
      ..statusEmailConsent = null;

    await _pumpHost(tester);
    expect(await Avafli.configure(_config()), isTrue);
    await _settle(tester);

    expect(client.registerCalls, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(StorageKeys.emailConfirmed), isTrue);
    expect(prefs.getString(StorageKeys.streakState), isNotNull);
    await _teardown(tester);
  });

  testWidgets(
      'older backend (no isNewUser / emailConsentStatus on registerDevice) '
      'leaves local state alone', (tester) async {
    SharedPreferences.setMockInitialValues(_staleIdentity());
    await seedCredentials();
    client
      ..cachedTokenValid = false
      ..registerIsNewUser = null
      ..registerEmailConsent = null
      ..statusEmailConsent = true;

    await _pumpHost(tester);
    expect(await Avafli.configure(_config()), isTrue);
    await _settle(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(StorageKeys.emailConfirmed), isTrue);
    expect(prefs.getString(StorageKeys.streakState), isNotNull);
    await _teardown(tester);
  });

  testWidgets(
      'claim refused with emailRequired (stale flag, backend silent about '
      'consent) → flag dropped, drawer moves to email capture, no retry '
      'queued', (tester) async {
    SharedPreferences.setMockInitialValues(_staleIdentity());
    await seedCredentials();
    client
      ..cachedTokenValid = false
      ..registerIsNewUser = false
      ..registerEmailConsent = null
      ..statusEmailConsent = true
      ..claimError = const AvafliException(
          AvafliError.emailRequired, 'Email confirmation is required');

    await _pumpHost(tester);
    expect(await Avafli.configure(_config()), isTrue);
    await _settle(tester);

    expect(client.claimCalls, greaterThanOrEqualTo(1),
        reason: 'requests: ${client.requests.map((r) => r.runtimeType).toList()} '
            'experience: ${find.byType(AvafliV2Experience).evaluate().length} '
            'capture: ${find.byType(AvafliV2CaptureView).evaluate().length}');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(StorageKeys.emailConfirmed), isFalse);
    expect(_hasQueuedClaim(prefs), isFalse);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(find.byType(AvafliV2CaptureView), findsOneWidget);
    await _teardown(tester);
  });
}
