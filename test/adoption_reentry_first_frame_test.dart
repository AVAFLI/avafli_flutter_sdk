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
import 'package:avafli_sdk/src/ui/v2/avafli_v2_experience.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';
import 'package:avafli_sdk/avafli_sdk.dart';

/// Sept 2026 field report: a device with a parked cross-device link (typed an
/// email owned by another device, never entered the code) painted the cached
/// "day 1" dashboard for the network round-trips, mailed a code, and only then
/// switched to the code screen — close the sheet inside that window and you
/// have an e-mail and no memory of any code prompt. The code screen must be
/// the FIRST frame, even with a warm cache and the local consent flag set.

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
  required bool adoptionPending,
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
      cachedGiveaway: _giveaway(),
      cachedClaimedToday: false,
      cachedStreakDay: 3,
      adoptionPending: adoptionPending,
    ),
  );
}

Future<void> _pumpLocalReads(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 8));
  }
}

void main() {
  setUpAll(_loadRealFonts);

  late PreferencesStorage prefs;

  Future<void> seedWarmConsentedCache() async {
    await prefs.cacheGiveaway(_giveaway());
    await prefs.saveStreakState(const StreakState(
      currentDay: 3,
      totalEntriesEarned: 40,
      weeklyCurrent: 3,
      monthlyCurrent: 3,
    ));
    // The exact state of the field report: the backend had echoed the shell
    // user's consent on an earlier open, so the local flag is already set.
    await prefs.setBool(StorageKeys.emailConfirmed, true);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = PreferencesStorage();
  });

  testWidgets(
      'a parked link paints the code screen as the first frame — '
      'never the cached dashboard', (tester) async {
    await seedWarmConsentedCache();
    final client = _HangingNetworkClient();

    await tester.pumpWidget(_experience(
      client: client,
      prefs: prefs,
      adoptionPending: true,
    ));
    await _pumpLocalReads(tester);

    expect(find.byType(AvafliV2CodeEntryView), findsOneWidget);
    expect(find.byType(AvafliV2DashboardView), findsNothing);
    expect(find.byType(AvafliV2CaptureView), findsNothing);
  });

  testWidgets(
      'the same warm, consented cache without a parked link still paints '
      'the dashboard first', (tester) async {
    await seedWarmConsentedCache();
    final client = _HangingNetworkClient();

    await tester.pumpWidget(_experience(
      client: client,
      prefs: prefs,
      adoptionPending: false,
    ));
    await _pumpLocalReads(tester);

    expect(find.byType(AvafliV2DashboardView), findsOneWidget);
    expect(find.byType(AvafliV2CodeEntryView), findsNothing);

    // Drain the dashboard's own timers (the rail's auto-center) so the tree
    // tears down clean.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  });
}
