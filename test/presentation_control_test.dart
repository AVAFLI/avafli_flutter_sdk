// Publisher presentation control (Sept 24 2026 spec): `AvafliConfiguration
// .autoOpen`, the server's `experience.autoOpenMode`, and `Avafli.present()`.
// Non-negotiable #2 — registerDevice runs on configure() in EVERY mode — is
// pinned here too, as is the boot-resilience foreground retry.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avafli_sdk/src/network/api_request.dart';
import 'package:avafli_sdk/src/network/avafli_api.dart';
import 'package:avafli_sdk/src/network/network_client.dart';
import 'package:avafli_sdk/src/storage/secure_storage.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_experience.dart';
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

/// Scripted backend: answers registration / profile / status; anything the
/// drawer asks for after that (claims, etc.) hangs so the experience just
/// sits on its first frame.
class _FakeNetworkClient implements NetworkClient {
  bool? isNewUser;
  Map<String, dynamic>? sdkConfig;
  bool withGiveaway = true;

  /// Errors to throw from registerDevice, consumed one per call.
  final List<Object> registerFailures = [];

  /// When set, registerDevice waits on it before answering.
  Completer<void>? registerGate;

  final List<ApiRequest<dynamic>> requests = [];

  int get registerCalls => requests.whereType<RegisterDeviceRequest>().length;

  @override
  Future<T> send<T>(ApiRequest<T> request) async {
    requests.add(request);
    if (request is RegisterDeviceRequest) {
      final gate = registerGate;
      if (gate != null) await gate.future;
      if (registerFailures.isNotEmpty) throw registerFailures.removeAt(0);
      return RegisterDeviceResponse(
        token: 'token-1',
        refreshToken: 'refresh-1',
        uuid: 'uuid-1',
        giveaway: withGiveaway ? _giveaway() : null,
        sdkConfig: sdkConfig,
        isNewUser: isNewUser,
      ) as T;
    }
    if (request is SubmitUserProfileRequest) {
      return const SuccessResponse(success: true) as T;
    }
    if (request is GetActiveGiveawayRequest) {
      return GetActiveGiveawayResponse(
        giveaway: withGiveaway ? _giveaway() : null,
        sdkConfig: sdkConfig,
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
const _impressionsKey = 'winr_unregistered_impressions_$_bundleId';

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
      // Default (unset) must be `always` — see the first test.
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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Avafli.resetForTesting();
    // A fresh key per test: the previous test's MaterialApp is gone.
    Avafli.navigatorKey = GlobalKey<NavigatorState>();
    client = _FakeNetworkClient();
    secure = _MemorySecureStorage();
    Avafli.networkClientForTesting = client;
    Avafli.secureStorageForTesting = secure;
  });

  tearDown(Avafli.resetForTesting);

  test('AvafliConfiguration.autoOpen defaults to always', () {
    const config = AvafliConfiguration(
      apiKey: 'k',
      bundleId: 'b',
      user: AvafliUser(id: 'u'),
    );
    expect(config.autoOpen, AvafliAutoOpen.always);
  });

  test('AvafliAutoOpen wire parsing + restrictiveness order', () {
    expect(AvafliAutoOpen.fromWire('always'), AvafliAutoOpen.always);
    expect(AvafliAutoOpen.fromWire('returningUsersOnly'),
        AvafliAutoOpen.returningUsersOnly);
    expect(AvafliAutoOpen.fromWire('never'), AvafliAutoOpen.never);
    expect(AvafliAutoOpen.fromWire('sometimes'), isNull);
    expect(AvafliAutoOpen.fromWire(null), isNull);
    expect(
        AvafliAutoOpen.mostRestrictive(
            AvafliAutoOpen.always, AvafliAutoOpen.never),
        AvafliAutoOpen.never);
    expect(
        AvafliAutoOpen.mostRestrictive(
            AvafliAutoOpen.returningUsersOnly, AvafliAutoOpen.always),
        AvafliAutoOpen.returningUsersOnly);
  });

  test('sdkConfig.experience.autoOpenMode parses; unknown → null (always)', () {
    expect(
        AvafliExperienceConfig.fromJson({'autoOpenMode': 'never'}).autoOpenMode,
        AvafliAutoOpen.never);
    expect(
        AvafliExperienceConfig.fromJson({'autoOpenMode': 'bogus'}).autoOpenMode,
        isNull);
    expect(AvafliExperienceConfig.fromJson({}).autoOpenMode, isNull);
  });

  test('RegisterDeviceResponse parses isNewUser (absent → null)', () {
    expect(
        RegisterDeviceResponse.fromJson({
          'token': 't',
          'refreshToken': 'r',
          'uuid': 'u',
          'isNewUser': true
        }).isNewUser,
        isTrue);
    expect(
        RegisterDeviceResponse.fromJson(
            {'token': 't', 'refreshToken': 'r', 'uuid': 'u'}).isNewUser,
        isNull);
  });

  // -------------------------------------------------------------------------
  // Non-negotiable #2: registration is unaffected by the mode
  // -------------------------------------------------------------------------

  testWidgets(
      'autoOpen: never still calls registerDevice on configure — and '
      'never presents', (tester) async {
    await _pumpHost(tester);
    expect(await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never)),
        isTrue);
    await _settle(tester);

    expect(client.registerCalls, 1);
    expect(client.requests.whereType<SubmitUserProfileRequest>().length, 1);
    expect(await secure.getAuthToken(), 'token-1',
        reason: 'the session was established and stored as usual');
    expect(find.byType(AvafliV2Experience), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastAutoPresentKey), isNull,
        reason: 'nothing burned when the SDK does not open');
    await _teardown(tester);
  });

  // -------------------------------------------------------------------------
  // Mode gate
  // -------------------------------------------------------------------------

  testWidgets('default (always) auto-opens once per day as before',
      (tester) async {
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(client.registerCalls, 1);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastAutoPresentKey), _today());
    await _closeDrawer(tester);
    await _teardown(tester);
  });

  testWidgets('returningUsersOnly skips the isNewUser session', (tester) async {
    client.isNewUser = true;
    await _pumpHost(tester);
    await Avafli.configure(
        _config(autoOpen: AvafliAutoOpen.returningUsersOnly));
    await _settle(tester);

    expect(client.registerCalls, 1);
    expect(Avafli.isNewUserSessionForTesting, isTrue);
    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets('returningUsersOnly auto-opens when isNewUser is false',
      (tester) async {
    client.isNewUser = false;
    await _pumpHost(tester);
    await Avafli.configure(
        _config(autoOpen: AvafliAutoOpen.returningUsersOnly));
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsOneWidget);
    await _closeDrawer(tester);
    await _teardown(tester);
  });

  testWidgets(
      'returningUsersOnly treats a backend without isNewUser as '
      'returning', (tester) async {
    client.isNewUser = null;
    await _pumpHost(tester);
    await Avafli.configure(
        _config(autoOpen: AvafliAutoOpen.returningUsersOnly));
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsOneWidget);
    await _closeDrawer(tester);
    await _teardown(tester);
  });

  testWidgets('a cached session (no re-registration) is a returning user',
      (tester) async {
    await secure.saveAuthToken('cached-token');
    await secure.saveUserUuid('uuid-cached');
    client.isNewUser = true; // would only matter if it re-registered
    await _pumpHost(tester);
    await Avafli.configure(
        _config(autoOpen: AvafliAutoOpen.returningUsersOnly));
    await _settle(tester);

    expect(client.registerCalls, 0);
    // Boot refreshed via getActiveGiveaway (the drawer then issues its own).
    expect(client.requests.whereType<GetActiveGiveawayRequest>().length,
        greaterThanOrEqualTo(1));
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    await _closeDrawer(tester);
    await _teardown(tester);
  });

  testWidgets('server autoOpenMode: never silences a client set to always',
      (tester) async {
    client.sdkConfig = {
      'experience': {'autoOpenMode': 'never'}
    };
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.always));
    await _settle(tester);

    expect(client.registerCalls, 1);
    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets(
      'server autoOpenMode: returningUsersOnly + isNewUser skips even '
      'when the client says always', (tester) async {
    client.isNewUser = true;
    client.sdkConfig = {
      'experience': {'autoOpenMode': 'returningUsersOnly'}
    };
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.always));
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets('an unknown server autoOpenMode is ignored (always)',
      (tester) async {
    client.sdkConfig = {
      'experience': {'autoOpenMode': 'sometimes'}
    };
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsOneWidget);
    await _closeDrawer(tester);
    await _teardown(tester);
  });

  testWidgets('the server kill switch still wins over every mode',
      (tester) async {
    client.sdkConfig = {
      'experience': {'autoOpenEnabled': false, 'autoOpenMode': 'always'}
    };
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.always));
    await _settle(tester);

    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  // -------------------------------------------------------------------------
  // present()
  // -------------------------------------------------------------------------

  test('present() before configure resolves false, never throws', () async {
    expect(await Avafli.present(), isFalse);
  });

  testWidgets(
      'present() opens the drawer under autoOpen: never, bypasses the '
      'once-a-day mark, counts no impression, and writes the mark on close',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _lastAutoPresentKey: _today(), // already "spent" today
    });
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never));
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);

    final presented = Avafli.present();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsOneWidget);

    await _closeDrawer(tester);
    expect(await presented, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastAutoPresentKey), _today());
    expect(prefs.getInt(_impressionsKey), isNull,
        reason: 'explicit invocation never counts an impression');
    await _teardown(tester);
  });

  testWidgets('present() waits for an in-flight registration', (tester) async {
    client.registerGate = Completer<void>();
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never));
    await _settle(tester);

    final presented = Avafli.present();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing,
        reason: 'must not race registerDevice');

    client.registerGate!.complete();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsOneWidget);

    await _closeDrawer(tester);
    expect(await presented, isTrue);
    await _teardown(tester);
  });

  testWidgets('present() with no active giveaway resolves false',
      (tester) async {
    client.withGiveaway = false;
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never));
    await _settle(tester);

    expect(await Avafli.present(), isFalse);
    expect(find.byType(AvafliV2Experience), findsNothing);
    await _teardown(tester);
  });

  testWidgets('present() while already on screen is a no-op', (tester) async {
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never));
    await _settle(tester);

    final first = Avafli.present();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    expect(await Avafli.present(), isFalse);
    expect(find.byType(AvafliV2Experience), findsOneWidget);

    await _closeDrawer(tester);
    expect(await first, isTrue);
    await _teardown(tester);
  });

  testWidgets('present() works while auto-open is held', (tester) async {
    Avafli.holdAutoOpen();
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsNothing);

    final presented = Avafli.present();
    await _settle(tester);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    await _closeDrawer(tester);
    expect(await presented, isTrue);
    await _teardown(tester);
  });

  // -------------------------------------------------------------------------
  // Boot resilience
  // -------------------------------------------------------------------------

  testWidgets(
      'a boot registration lost to the network is re-run on the next '
      'foreground, and nothing is burned on the failed boot', (tester) async {
    // Non-transport networkError (e.g. a mapped 429/timeout without the
    // transport flag) — exactly the class the offline retry queue ignores.
    client.registerFailures
        .add(const AvafliException(AvafliError.networkError));
    await _pumpHost(tester);
    await Avafli.configure(_config());
    await _settle(tester);

    expect(client.registerCalls, 1);
    expect(find.byType(AvafliV2Experience), findsNothing);
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastAutoPresentKey), isNull);
    expect(prefs.getInt(_impressionsKey), isNull);

    // The lifecycle observer fires this unawaited in production; it resolves
    // only once the drawer it opens has closed.
    final resumed = Avafli.handleAppResumed();
    await _settle(tester);

    expect(client.registerCalls, 2);
    expect(find.byType(AvafliV2Experience), findsOneWidget);
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_lastAutoPresentKey), _today());
    await _closeDrawer(tester);
    await resumed;
    await _teardown(tester);
  });

  testWidgets('a foreground after a clean boot does not re-register',
      (tester) async {
    await _pumpHost(tester);
    await Avafli.configure(_config(autoOpen: AvafliAutoOpen.never));
    await _settle(tester);
    expect(client.registerCalls, 1);

    await Avafli.handleAppResumed();
    await _settle(tester);
    expect(client.registerCalls, 1);
    await _teardown(tester);
  });
}
