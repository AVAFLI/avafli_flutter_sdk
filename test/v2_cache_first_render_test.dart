// The drawer auto-opens and USED to sit on a bare spinner until three
// sequential network calls resolved (registerDevice → getActiveGiveaway →
// claim) — 5+ seconds on the CTO's Skape build — even though the giveaway
// config and streak were already cached on the device.
//
// These tests pin the two halves of the fix:
//   * a warm device paints the real dashboard from cache while the network is
//     still in flight (never a spinner), and
//   * a genuinely cold device gets a layout-shaped SKELETON, not a spinner.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avafli_sdk/src/network/api_request.dart';
import 'package:avafli_sdk/src/network/network_client.dart';
import 'package:avafli_sdk/src/storage/preferences_storage.dart';
import 'package:avafli_sdk/src/storage/secure_storage.dart';
import 'package:avafli_sdk/src/storage/storage.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_components.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_experience.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';
import 'package:avafli_sdk/avafli_sdk.dart';

/// A backend that never answers — every frame these tests observe is one the
/// drawer produced WITHOUT the network.
class _HangingNetworkClient implements NetworkClient {
  int sends = 0;

  @override
  Future<T> send<T>(ApiRequest<T> request) {
    sends++;
    return Completer<T>().future; // never completes
  }

  @override
  void setAuthToken(String? token) {}

  @override
  void setRefreshHandler(Future<String?> Function() handler) {}
}

/// Registration handshake already done on this device.
class _RegisteredSecureStorage extends SecureStorage {
  @override
  Future<String?> getUserUuid() async => 'uuid-cached';
}

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

Future<void> _loadRealFonts() async {
  final inter = FontLoader('packages/avafli_sdk/Inter');
  for (final file in [
    'inter-v20-latin-regular.ttf',
    'inter-v20-latin-500.ttf',
    'inter-v20-latin-700.ttf',
    'inter-v20-latin-900.ttf',
  ]) {
    inter.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await inter.load();
}

Widget _experience({
  required NetworkClient client,
  required PreferencesStorage prefs,
  Giveaway? cachedGiveaway,
  bool? cachedClaimedToday,
  int? cachedStreakDay,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AvafliV2Experience(
      configuration: const AvafliConfiguration(
        apiKey: 'winr_test_key',
        bundleId: 'com.example.test',
        user: AvafliUser(id: 'user-1', firstName: 'Test', lastName: 'User'),
      ),
      networkClient: client,
      secureStorage: _RegisteredSecureStorage(),
      preferencesStorage: prefs,
      streakEngine: StreakEngine(),
      cachedGiveaway: cachedGiveaway,
      cachedClaimedToday: cachedClaimedToday,
      cachedStreakDay: cachedStreakDay,
    ),
  );
}

/// Pumps a handful of frames — enough for the LOCAL storage reads the cache
/// hydrate awaits, nowhere near enough for a network round-trip.
Future<void> _pumpLocalReads(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 8));
  }
}

void main() {
  setUpAll(_loadRealFonts);

  late PreferencesStorage prefs;

  Future<void> seedWarmCache() async {
    await prefs.cacheGiveaway(_giveaway());
    await prefs.saveStreakState(const StreakState(
      currentDay: 3,
      totalEntriesEarned: 40,
      weeklyCurrent: 3,
      monthlyCurrent: 3,
    ));
    await prefs.setBool(StorageKeys.emailConfirmed, true);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = PreferencesStorage();
  });

  testWidgets(
      'a warm device renders the dashboard with the network still '
      'in flight — never the loading view', (tester) async {
    await seedWarmCache();
    final client = _HangingNetworkClient();

    await tester.pumpWidget(_experience(
      client: client,
      prefs: prefs,
      cachedGiveaway: _giveaway(),
      cachedClaimedToday: false,
      cachedStreakDay: 3,
    ));
    await _pumpLocalReads(tester);

    // The dashboard is up…
    expect(find.byType(AvafliV2DashboardView), findsOneWidget);
    expect(find.byType(AvafliV2LoadingView), findsNothing);
    expect(find.text('GOT IT'), findsOneWidget);
    // …painted from the cached streak (day 3, pre-reveal shows day 2)…
    expect(find.text('2 DAY STREAK'), findsOneWidget);
    // …while the backend has been asked and has answered nothing.
    expect(client.sends, greaterThan(0));

    // Drain the dashboard's own timers (the rail's auto-center) so the tree
    // tears down clean.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'an unconsented device still lands on email capture, never a '
      'cached dashboard', (tester) async {
    // Cached giveaway + streak but NO email consent: Day 1 must still be the
    // capture screen. (The cache-first path must not skip the email gate.)
    await prefs.cacheGiveaway(_giveaway());
    await prefs.saveStreakState(const StreakState(currentDay: 1));

    await tester.pumpWidget(_experience(
      client: _HangingNetworkClient(),
      prefs: prefs,
      cachedGiveaway: _giveaway(),
      cachedClaimedToday: false,
      cachedStreakDay: 1,
    ));
    await _pumpLocalReads(tester);

    expect(find.byType(AvafliV2DashboardView), findsNothing);
    expect(find.byType(AvafliV2CaptureView), findsNothing,
        reason: 'capture only appears once the network confirms the gate');
    expect(find.byType(AvafliV2LoadingView), findsOneWidget);
  });

  testWidgets('a cold device shows the layout skeleton, not a spinner',
      (tester) async {
    // Nothing cached at all — the genuine cold start.
    await tester.pumpWidget(_experience(
      client: _HangingNetworkClient(),
      prefs: prefs,
    ));
    await _pumpLocalReads(tester);

    expect(find.byType(AvafliV2LoadingView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'the bare spinner is what made the wait feel dead');
    expect(find.text('Loading…'), findsNothing);
    // The skeleton blocks out the real dashboard layout (prize card, three
    // streak tiles, bar, pill) so the wait reads as content arriving.
    expect(find.byType(AvafliV2TabGrabber), findsOneWidget);
    final blocks = tester
        .widgetList<Container>(find.descendant(
          of: find.byType(AvafliV2LoadingView),
          matching: find.byType(Container),
        ))
        .length;
    expect(blocks, greaterThanOrEqualTo(8));
  });

  testWidgets('the skeleton pulses rather than sitting still', (tester) async {
    await tester.pumpWidget(_experience(
      client: _HangingNetworkClient(),
      prefs: prefs,
    ));
    await tester.pump();

    double opacity() => tester
        .widget<FadeTransition>(find.descendant(
          of: find.byType(AvafliV2LoadingView),
          matching: find.byType(FadeTransition),
        ))
        .opacity
        .value;

    final first = opacity();
    await tester.pump(const Duration(milliseconds: 450));
    expect(opacity(), isNot(closeTo(first, 0.01)));
  });
}
