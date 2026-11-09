// 3.3.0: network giveaway sponsor disclosure.
//
// The giveaway payload may carry `scope: "network"` and `sponsorDisclosure`
// ("Sponsored by Avafli LLC"). The SDK must (a) parse both as nullable and
// expose them on the public `Giveaway`, (b) render the disclosure as one
// small line under the prize wherever the prize is presented, and (c) render
// NOTHING — same widget tree, same geometry — when the field is absent, so an
// exclusive giveaway looks exactly as it did in 3.2.2.
//
// The `prizeClaim` block carries the same two fields for a network-giveaway
// winner. The winner splash must read the line from THERE: the draw clears
// the network pointer, so a winner usually opens the app with no served
// giveaway at all, and a served-giveaway match would find nothing.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avafli_sdk/avafli_sdk.dart';
import 'package:avafli_sdk/src/domain/claim_verification.dart';
import 'package:avafli_sdk/src/network/api_request.dart';
import 'package:avafli_sdk/src/network/avafli_api.dart';
import 'package:avafli_sdk/src/network/network_client.dart';
import 'package:avafli_sdk/src/storage/secure_storage.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_claim.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_components.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_experience.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';

const _disclosure = 'Sponsored by Avafli LLC';

Map<String, dynamic> _claimJson({bool network = false}) => {
      'status': 'pending',
      'giveawayId': network ? 'network-nov-2026' : 'g-1',
      'prizeDescription': '',
      'prizeValue': 1000,
      'maskedEmail': 'w****r@avafli.example.com',
      if (network) 'scope': 'network',
      if (network) 'sponsorDisclosure': _disclosure,
    };

/// Scripted backend for the end-to-end splash check: a pending claim, with
/// or without the network fields, and NO served giveaway on either call —
/// exactly where a real winner arrives (the giveaway ended at the draw).
class _FakeNetworkClient implements NetworkClient {
  _FakeNetworkClient({required this.network});

  final bool network;

  PrizeClaimBlock get _claim =>
      PrizeClaimBlock.fromJson(_claimJson(network: network));

  @override
  Future<T> send<T>(ApiRequest<T> request) async {
    if (request is RegisterDeviceRequest) {
      return RegisterDeviceResponse(
        token: 'token-1',
        refreshToken: 'refresh-1',
        uuid: 'uuid-1',
        giveaway: null,
        prizeClaim: _claim,
      ) as T;
    }
    if (request is GetActiveGiveawayRequest) {
      return GetActiveGiveawayResponse(
        giveaway: null,
        claimedToday: true,
        streakDay: 3,
        totalEntries: 40,
        weeklyCurrent: 3,
        monthlyCurrent: 3,
        emailConsentStatus: true,
        prizeClaim: _claim,
      ) as T;
    }
    return Completer<T>().future; // anything else: never completes
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

/// Boots the SDK against [client] on a host app and lets registration →
/// auto-present → the drawer's own status call run.
Future<void> _bootWinner(WidgetTester tester, _FakeNetworkClient client) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  Avafli.resetForTesting();
  Avafli.navigatorKey = GlobalKey<NavigatorState>();
  Avafli.networkClientForTesting = client;
  Avafli.secureStorageForTesting = _MemorySecureStorage();
  await tester.pumpWidget(MaterialApp(
    navigatorKey: Avafli.navigatorKey,
    home: const Scaffold(body: SizedBox.expand()),
  ));
  await Avafli.configure(const AvafliConfiguration(
    apiKey: 'winr_test_key',
    bundleId: 'com.example.test',
    user: AvafliUser(id: 'user-1'),
    options: AvafliOptions(enablePushReminders: false),
    autoOpen: AvafliAutoOpen.always,
  ));
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Closes the drawer and unmounts everything (drains its timers first).
Future<void> _teardownWinner(WidgetTester tester) async {
  Avafli.noteUserDismissedExperience();
  final ctx = tester.element(find.byType(AvafliV2Experience));
  Navigator.of(ctx).pop();
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
  Avafli.resetForTesting();
}

/// Loads the real bundled Inter faces so text measures like production (the
/// test-default font is far wider and overflows the card's stats strip).
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

Map<String, dynamic> _giveawayJson({bool network = false}) => {
      'id': network ? 'network-nov-2026' : 'g-1',
      'title': 'November Giveaway',
      'period': 'monthly',
      'maxDailyBaseEntries': 300,
      'doublingEnabled': false,
      'prizeDescription': r'$500 Amazon Gift Card',
      'prizeValue': 500,
      'streakConfig': <String, dynamic>{},
      if (network) 'scope': 'network',
      if (network) 'sponsorDisclosure': _disclosure,
    };

Widget _host(Widget child, {Color color = AvafliV2Colors.gunmetal}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: color,
        child: Center(child: SizedBox(width: 390, child: child)),
      ),
    );

void main() {
  setUpAll(_loadRealFonts);

  group('Giveaway parsing', () {
    test('scope + sponsorDisclosure parse when present', () {
      final g = Giveaway.fromJson(_giveawayJson(network: true));
      expect(g.scope, 'network');
      expect(g.sponsorDisclosure, _disclosure);
      expect(g.isNetworkGiveaway, isTrue);
      // Round-trips through the cache encoding.
      final again = Giveaway.fromJson(g.toJson());
      expect(again.scope, 'network');
      expect(again.sponsorDisclosure, _disclosure);
    });

    test('both are null when absent (exclusive giveaway)', () {
      final g = Giveaway.fromJson(_giveawayJson());
      expect(g.scope, isNull);
      expect(g.sponsorDisclosure, isNull);
      expect(g.isNetworkGiveaway, isFalse);
      expect(g.toJson().containsKey('scope'), isFalse);
      expect(g.toJson().containsKey('sponsorDisclosure'), isFalse);
    });

    test('an explicit "publisher" scope is not a network giveaway', () {
      final g = Giveaway.fromJson({..._giveawayJson(), 'scope': 'publisher'});
      expect(g.scope, 'publisher');
      expect(g.isNetworkGiveaway, isFalse);
      expect(g.sponsorDisclosure, isNull);
    });

    test('a blank disclosure is treated as absent', () {
      final g = Giveaway.fromJson({..._giveawayJson(), 'sponsorDisclosure': '  '});
      expect(g.sponsorDisclosure, isNull);
    });

    test('fields ride through the registerDevice / getActiveGiveaway envelopes',
        () {
      final reg = RegisterDeviceResponse.fromJson({
        'userId': 'u1',
        'token': 't',
        'giveaway': _giveawayJson(network: true),
      });
      expect(reg.giveaway?.scope, 'network');
      expect(reg.giveaway?.sponsorDisclosure, _disclosure);

      final active = GetActiveGiveawayResponse.fromJson({
        'giveaway': _giveawayJson(network: true),
      });
      expect(active.giveaway?.scope, 'network');
      expect(active.giveaway?.sponsorDisclosure, _disclosure);
    });
  });

  group('PrizeClaimBlock parsing', () {
    test('scope + sponsorDisclosure parse when present', () {
      final block = PrizeClaimBlock.fromJson(_claimJson(network: true));
      expect(block.scope, 'network');
      expect(block.sponsorDisclosure, _disclosure);
      expect(block.isNetworkGiveaway, isTrue);
      // The rest of the contract is untouched.
      expect(block.isPending, isTrue);
      expect(block.prizeValue, 1000);
      expect(block.maskedEmail, 'w****r@avafli.example.com');
    });

    test('both are null when absent (exclusive giveaway)', () {
      final block = PrizeClaimBlock.fromJson(_claimJson());
      expect(block.scope, isNull);
      expect(block.sponsorDisclosure, isNull);
      expect(block.isNetworkGiveaway, isFalse);
    });

    test('a blank disclosure is treated as absent', () {
      final block = PrizeClaimBlock.fromJson(
        {..._claimJson(network: true), 'sponsorDisclosure': '  '},
      );
      expect(block.scope, 'network');
      expect(block.sponsorDisclosure, isNull);
    });

    test('withVerification keeps both fields', () {
      final block = PrizeClaimBlock.fromJson(_claimJson(network: true));
      final fresher = block.withVerification(
        ClaimVerification.fromJson(const {'required': true}),
      );
      expect(fresher.scope, 'network');
      expect(fresher.sponsorDisclosure, _disclosure);
      expect(fresher.requiresVerification, isTrue);
    });

    test('rides through the registerDevice / getActiveGiveaway envelopes', () {
      final reg = RegisterDeviceResponse.fromJson({
        'userId': 'u1',
        'token': 't',
        'prizeClaim': _claimJson(network: true),
      });
      expect(reg.prizeClaim?.sponsorDisclosure, _disclosure);

      final active = GetActiveGiveawayResponse.fromJson({
        'prizeClaim': _claimJson(network: true),
      });
      expect(active.prizeClaim?.scope, 'network');
      expect(active.prizeClaim?.sponsorDisclosure, _disclosure);
    });
  });

  group('AvafliV2SponsorDisclosure', () {
    testWidgets('renders nothing for null / blank', (tester) async {
      await tester.pumpWidget(_host(const AvafliV2SponsorDisclosure(null)));
      expect(find.byType(Text), findsNothing);
      // Zero height — occupies no vertical space (the host forces the width).
      expect(tester.getSize(find.byType(AvafliV2SponsorDisclosure)).height, 0);

      await tester.pumpWidget(_host(const AvafliV2SponsorDisclosure('   ')));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders one readable line (>= 11pt) when present',
        (tester) async {
      await tester.pumpWidget(_host(const AvafliV2SponsorDisclosure(_disclosure)));
      final text = tester.widget<Text>(find.text(_disclosure));
      expect(text.maxLines, 1);
      expect(text.style?.fontSize, greaterThanOrEqualTo(11));
      expect(text.style?.color, AvafliV2Colors.textSecondary);
    });
  });

  group('prize card (dashboard / present())', () {
    Widget card({String? disclosure, String description = ''}) => _host(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: AvafliV2PrizeCard(
              accent: AvafliV2Accent(null).color,
              streakDay: 3,
              totalEntries: 100,
              prizeImageUrl: null,
              prizeValue: 500,
              prizeDescription: description,
              sponsorDisclosure: disclosure,
            ),
          ),
        );

    testWidgets('cash lockup shows the line under the prize', (tester) async {
      await tester.pumpWidget(card(disclosure: _disclosure));
      expect(find.text(_disclosure), findsOneWidget);
      final prize = tester.getRect(find.text('CASH PRIZE'));
      final line = tester.getRect(find.text(_disclosure));
      expect(line.top, greaterThanOrEqualTo(prize.bottom));
    });

    testWidgets('non-cash lockup shows the line under the value',
        (tester) async {
      await tester.pumpWidget(
        card(disclosure: _disclosure, description: 'Amazon Gift Card'),
      );
      expect(find.text(_disclosure), findsOneWidget);
      final value = tester.getRect(find.text(r'$500.00 VALUE!'));
      final line = tester.getRect(find.text(_disclosure));
      expect(line.top, greaterThanOrEqualTo(value.bottom));
    });

    testWidgets('absent → no text, same lockup geometry as before',
        (tester) async {
      await tester.pumpWidget(card());
      expect(find.text(_disclosure), findsNothing);
      final before = tester.getRect(find.text('CASH PRIZE'));
      // Pumping the same card WITH the line must not move the lockup up:
      // the scrim grows downward from the headline, so the disclosure
      // takes the space below, not the space the headline had.
      await tester.pumpWidget(card(disclosure: _disclosure));
      final after = tester.getRect(find.text('CASH PRIZE'));
      expect(after.width, before.width);
      expect(after.height, before.height);
    });
  });

  group('Day-1 capture strip', () {
    Widget capture(Giveaway g) => _host(
          AvafliV2CaptureView(
            accent: AvafliV2Accent(null).color,
            logoUrl: null,
            rulesUrl: null,
            giveaway: g,
            isSubmitting: false,
            onSubmit: (_, {required ageConfirmed, required marketingConsent}) {},
            onInfo: () {},
            onClose: () {},
          ),
        );

    testWidgets('network giveaway → sponsor line on the white strip',
        (tester) async {
      await tester.pumpWidget(
        capture(Giveaway.fromJson(_giveawayJson(network: true))),
      );
      await tester.pump();
      final line = find.text(_disclosure);
      expect(line, findsOneWidget);
      // Muted gunmetal on the white strip — readable, never white-on-white.
      final style = tester.widget<Text>(line).style!;
      expect(style.fontSize, greaterThanOrEqualTo(11));
      expect(style.color!.a, greaterThan(0.5));
      expect(style.color!.r, lessThan(0.5)); // dark ink, not white
    });

    testWidgets('exclusive giveaway → nothing', (tester) async {
      await tester.pumpWidget(capture(Giveaway.fromJson(_giveawayJson())));
      await tester.pump();
      expect(find.text(_disclosure), findsNothing);
      expect(find.byType(AvafliV2SponsorDisclosure), findsNothing);
    });
  });

  group('winner splash', () {
    Widget splash({String? disclosure}) => _host(
          AvafliV2WinnerSplashView(
            accent: AvafliV2Accent(null).color,
            logoUrl: null,
            prizeHeadline: r'$500.00 CASH PRIZE',
            sponsorDisclosure: disclosure,
            onContinue: () {},
            onClose: () {},
          ),
        );

    testWidgets('shows the line under the prize headline', (tester) async {
      await tester.pumpWidget(splash(disclosure: _disclosure));
      await tester.pump();
      expect(find.text(_disclosure), findsOneWidget);
      final headline = tester.getRect(find.text(r'$500.00 CASH PRIZE'));
      final line = tester.getRect(find.text(_disclosure));
      expect(line.top, greaterThanOrEqualTo(headline.bottom));
    });

    testWidgets('absent → nothing', (tester) async {
      await tester.pumpWidget(splash());
      await tester.pump();
      expect(find.text(_disclosure), findsNothing);
    });
  });

  group('winner splash in the real experience, no giveaway served', () {
    testWidgets('network claim → the line comes from the claim block',
        (tester) async {
      await _bootWinner(tester, _FakeNetworkClient(network: true));

      expect(find.byType(AvafliV2Experience), findsOneWidget);
      final splash = find.byType(AvafliV2WinnerSplashView);
      expect(splash, findsOneWidget);
      // Nothing to borrow it from — both calls returned giveaway: null.
      expect(find.byType(AvafliV2DashboardView), findsNothing);
      expect(tester.widget<AvafliV2WinnerSplashView>(splash).sponsorDisclosure,
          _disclosure);
      expect(find.text(_disclosure), findsOneWidget);
      // The prize headline comes from the same block.
      expect(find.textContaining('1,000'), findsWidgets);

      await _teardownWinner(tester);
    });

    testWidgets('exclusive claim → nothing', (tester) async {
      await _bootWinner(tester, _FakeNetworkClient(network: false));

      final splash = find.byType(AvafliV2WinnerSplashView);
      expect(splash, findsOneWidget);
      expect(tester.widget<AvafliV2WinnerSplashView>(splash).sponsorDisclosure,
          isNull);
      expect(find.text(_disclosure), findsNothing);

      await _teardownWinner(tester);
    });
  });
}
