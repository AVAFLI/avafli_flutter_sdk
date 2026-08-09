// Consent capture (2.4.0): the email-capture screen's TWO checkboxes, the
// copy that drives the new one, and the payload both of them produce.
//
// The load-bearing rules:
//   * age gate → unchecked by default, GATES the CTA;
//   * marketing consent → checked by default, does NOT gate the CTA, and
//     declining it changes nothing about entry or winner contact;
//   * submitEmail carries the real state of both, never a literal.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winr_flutter_sdk/src/network/winr_api.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_components.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_screens.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_theme.dart';
import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';

const String _ageLabel = 'I confirm I am 18 years of age or older';

Giveaway _giveaway() {
  return const Giveaway(
    id: 'g1',
    title: 'Test Giveaway',
    period: GiveawayPeriod.monthly,
    maxDailyBaseEntries: 300,
    doublingEnabled: false,
    streakConfig: StreakConfig(),
    streakLadder: [10, 30, 60],
    prizeDescription: '',
    prizeValue: 1000,
    rulesUrl: 'https://example.com/rules',
  );
}

/// Real bundled faces so the capture screen measures like production (the
/// test-default Ahem font is far wider and would overflow the checkbox rows).
Future<void> _loadRealFonts() async {
  final inter = FontLoader('packages/winr_flutter_sdk/Inter');
  for (final file in [
    'inter-v20-latin-regular.ttf',
    'inter-v20-latin-500.ttf',
    'inter-v20-latin-600.ttf',
    'inter-v20-latin-700.ttf',
    'inter-v20-latin-800.ttf',
    'inter-v20-latin-900.ttf',
  ]) {
    inter.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await inter.load();

  final oswald = FontLoader('packages/winr_flutter_sdk/Oswald');
  for (final file in [
    'oswald-v57-latin-500.ttf',
    'oswald-v57-latin-700.ttf',
  ]) {
    oswald.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await oswald.load();
}

void main() {
  setUpAll(_loadRealFonts);

  group('capture view consent checkboxes', () {
    /// Records the most recent submit so the payload can be asserted.
    late List<Object?> submitted;

    Future<void> pumpCapture(
      WidgetTester tester, {
      String? marketingConsentText,
    }) async {
      submitted = [];
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: WINRV2CaptureView(
            accent: WINRV2Accent(null).color,
            logoUrl: null,
            rulesUrl: null,
            giveaway: _giveaway(),
            isSubmitting: false,
            marketingConsentText: marketingConsentText,
            onSubmit: (
              email, {
              required ageConfirmed,
              required marketingConsent,
            }) {
              submitted = [email, ageConfirmed, marketingConsent];
            },
            onInfo: () {},
            onClose: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
    }

    bool ctaEnabled(WidgetTester tester) =>
        tester.widget<WINRV2PillButton>(find.byType(WINRV2PillButton)).enabled;

    testWidgets('BOTH checkboxes start unchecked — consent is an affirmative act',
        (tester) async {
      // Marketing was pre-checked until Aug 2026. Changed on governance
      // review: pre-ticked consent boxes are invalid under GDPR and
      // disfavored by US state regulators.
      await pumpCapture(tester);

      expect(find.text(_ageLabel), findsOneWidget);
      expect(find.text(winrV2DefaultMarketingConsentText), findsOneWidget);

      // No ticked glyphs anywhere; two empty boxes.
      expect(find.byIcon(Icons.check_box), findsNothing);
      expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));
    });

    testWidgets('the age gate — not the consent box — gates the CTA',
        (tester) async {
      await pumpCapture(tester);

      // Valid email alone is not enough.
      await tester.enterText(find.byType(TextField), 'winner@example.com');
      await tester.pump();
      expect(ctaEnabled(tester), isFalse);

      // Age gate ticked → enabled.
      await tester.tap(find.text(_ageLabel));
      await tester.pump();
      expect(ctaEnabled(tester), isTrue);
    });

    testWidgets('toggling marketing consent never affects the CTA',
        (tester) async {
      await pumpCapture(tester);
      await tester.enterText(find.byType(TextField), 'winner@example.com');
      await tester.tap(find.text(_ageLabel));
      await tester.pump();
      expect(ctaEnabled(tester), isTrue);

      // Checking it: CTA unchanged.
      await tester.tap(find.text(winrV2DefaultMarketingConsentText));
      await tester.pump();
      expect(find.byIcon(Icons.check_box), findsNWidgets(2));
      expect(ctaEnabled(tester), isTrue);

      // Unchecking it again: CTA still unchanged.
      await tester.tap(find.text(winrV2DefaultMarketingConsentText));
      await tester.pump();
      expect(find.byIcon(Icons.check_box), findsOneWidget); // the age box
      expect(ctaEnabled(tester), isTrue);
    });

    testWidgets('submit reports the real state of both checkboxes',
        (tester) async {
      await pumpCapture(tester);
      await tester.enterText(find.byType(TextField), '  winner@example.com  ');
      await tester.tap(find.text(_ageLabel));
      await tester.pump();

      // Default path: consent left UNTOUCHED — silence is not consent.
      await tester.tap(find.byType(WINRV2PillButton));
      await tester.pump();
      expect(submitted, ['winner@example.com', true, false]);

      // Affirmative path: user ticks the box, submit carries true.
      await tester.tap(find.text(winrV2DefaultMarketingConsentText));
      await tester.pump();
      await tester.tap(find.byType(WINRV2PillButton));
      await tester.pump();
      expect(submitted, ['winner@example.com', true, true]);
    });

    // The production path: the backend interpolates the publisher name and
    // ships the finished string — the SDK never substitutes one itself.
    testWidgets('server-supplied consent copy overrides the default',
        (tester) async {
      const serverCopy = 'I agree to receive marketing emails from Acme News';
      await pumpCapture(tester, marketingConsentText: serverCopy);

      expect(find.text(serverCopy), findsOneWidget);
      expect(find.text(winrV2DefaultMarketingConsentText), findsNothing);
    });
  });

  group('SubmitEmailRequest body', () {
    test('carries ageConfirmed + marketingConsent under those exact keys', () {
      final body = SubmitEmailRequest(
        email: 'winner@example.com',
        ageConfirmed: true,
        marketingConsent: false,
        publisherUserId: 'pub_1',
      ).body;

      expect(body['email'], 'winner@example.com');
      expect(body['ageConfirmed'], isTrue);
      expect(body['marketingConsent'], isFalse);
      expect(body['publisherUserId'], 'pub_1');

      // `emailConsent` was never the contract — the wire name is
      // `marketingConsent`, and nothing else may leak in.
      expect(body.containsKey('emailConsent'), isFalse);
      expect(
        body.keys.toSet(),
        {'email', 'ageConfirmed', 'marketingConsent', 'publisherUserId'},
      );
    });

    test('omits publisherUserId when absent, but never ageConfirmed', () {
      final body = SubmitEmailRequest(
        email: 'winner@example.com',
        ageConfirmed: true,
        marketingConsent: true,
      ).body;

      expect(body['marketingConsent'], isTrue);
      expect(body.containsKey('publisherUserId'), isFalse);
      // The backend keys off the PRESENCE of ageConfirmed to detect a 2.4.0+
      // client, so it is unconditional.
      expect(body.containsKey('ageConfirmed'), isTrue);
    });
  });

  group('sdkConfig marketing-consent copy', () {
    test('nested emailCapture copy wins over the flat legacy field', () {
      final config = WinrSdkConfig.fromJson({
        'copy': {
          'emailCapture': {'emailConsentText': 'Nested wins'},
          'emailConsentText': 'Flat loses',
        },
      });

      expect(config.copy?.resolvedEmailConsentText, 'Nested wins');
    });

    test('falls back to the flat legacy field', () {
      final config = WinrSdkConfig.fromJson({
        'copy': {'emailConsentText': 'Flat fallback'},
      });

      expect(config.copy?.resolvedEmailConsentText, 'Flat fallback');
    });

    test('resolves to null when the server says nothing usable', () {
      expect(WinrSdkConfig.fromJson({}).copy, isNull);
      expect(
        WinrSdkConfig.fromJson({
          'copy': {
            'emailCapture': {'emailConsentText': ''},
            'emailConsentText': '',
          },
        }).copy?.resolvedEmailConsentText,
        isNull,
      );
    });
  });
}
