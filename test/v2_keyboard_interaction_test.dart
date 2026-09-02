// Keyboard-interaction guarantees for every V2 input screen:
//
// 1. The focused field scrolls visible ABOVE the software keyboard
//    (AvafliV2EnsureVisible), including the address-autocomplete card.
// 2. With the keyboard open every remaining control — CTA pills, "Send a
//    new code", legal footers — stays reachable by scrolling (viewInsets
//    bottom padding / the experience's resizing Scaffold).
// 3. Natural dismissal (AvafliV2KeyboardDismiss): a drag on the scrollable
//    or a tap on empty space unfocuses; programmatic ensure-visible scrolls
//    never do.
//
// The harness mirrors the production drawer: a Scaffold with
// resizeToAvoidBottomInset inside a MediaQuery carrying a fake keyboard
// inset, so "visible" means "above the simulated keyboard".

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:avafli_sdk/src/network/places_autocomplete.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_claim.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';

// Simulated screen + keyboard geometry. Content laid out under a resizing
// Scaffold ends at _kVisibleBottom — anything below is "under the keyboard".
const double _kScreenHeight = 700;
const double _kKeyboardInset = 300;
const double _kVisibleBottom = _kScreenHeight - _kKeyboardInset;

/// Hosts [child] the way the production experience does: a resizing Scaffold
/// under a MediaQuery whose viewInsets simulate an open software keyboard.
Widget _keyboardHost(Widget child, {double inset = _kKeyboardInset}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(viewInsets: EdgeInsets.only(bottom: inset)),
        child: Material(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: true,
            body: child,
          ),
        ),
      ),
    ),
  );
}

/// Bare host (no Scaffold) — exercises the screens' own viewInsets guard.
Widget _bareHost(Widget child, {double inset = _kKeyboardInset}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(viewInsets: EdgeInsets.only(bottom: inset)),
        child: Material(child: child),
      ),
    ),
  );
}

/// Loads the real bundled Inter faces so text measures like production.
Future<void> _loadRealFonts() async {
  final inter = FontLoader('packages/avafli_sdk/Inter');
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
}

/// Waits out AvafliV2EnsureVisible's keyboard-settle timer (320ms) plus its
/// 200ms scroll animation.
Future<void> _settleEnsureVisible(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

void _sizeScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, _kScreenHeight);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

FocusNode _fieldFocus(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).focusNode!;

void main() {
  setUpAll(_loadRealFonts);

  final accent = AvafliV2Accent(null).color;

  Widget captureView() {
    return AvafliV2CaptureView(
      accent: accent,
      logoUrl: null,
      rulesUrl: null,
      giveaway: null,
      isSubmitting: false,
      onSubmit: (_, {required ageConfirmed, required marketingConsent}) {},
      onInfo: () {},
      onClose: () {},
    );
  }

  Widget codeEntryView() {
    return AvafliV2CodeEntryView(
      accent: accent,
      logoUrl: null,
      rulesUrl: null,
      email: 'test@example.com',
      isVerifying: false,
      errorText: null,
      onSubmit: (_) {},
      onResend: () {},
      onInfo: () {},
      onClose: () {},
    );
  }

  Widget claimSteps({AvafliPlacesClient? placesClient}) {
    return AvafliV2ClaimStepsFlow(
      accent: accent,
      logoUrl: null,
      maskedEmail: 'w****r@avafli.example.com',
      initialForm: AvafliPrizeClaimForm(),
      placesClient: placesClient,
      isSubmitting: false,
      submitError: null,
      onSubmit: (_) {},
      onClose: () {},
    );
  }

  Future<void> goToAddressStep(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Jane');
    await tester.enterText(find.byType(TextField).at(1), 'Doe');
    await tester.pump();
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SEND YOUR PRIZE'), findsOneWidget);
  }

  group('email capture', () {
    testWidgets(
        'focused email field sits above the keyboard and the CTA + '
        'legal footer stay reachable', (tester) async {
      _sizeScreen(tester);
      await tester.pumpWidget(_keyboardHost(captureView()));

      await tester.tap(find.byType(TextField));
      await _settleEnsureVisible(tester);

      final fieldRect = tester.getRect(find.byType(TextField));
      expect(fieldRect.bottom, lessThanOrEqualTo(_kVisibleBottom + 0.5),
          reason: 'email field must scroll clear of the keyboard on focus');

      await tester.ensureVisible(find.textContaining('CLAIM MY'));
      await tester.pumpAndSettle();
      final cta = tester.getRect(find.textContaining('CLAIM MY'));
      expect(cta.bottom, lessThanOrEqualTo(_kVisibleBottom + 0.5),
          reason: 'CTA must be reachable above the keyboard');

      await tester.ensureVisible(find.text('Powered by © Avafli'));
      await tester.pumpAndSettle();
      final footer = tester.getRect(find.text('Powered by © Avafli'));
      expect(footer.bottom, lessThanOrEqualTo(_kVisibleBottom + 0.5),
          reason: 'legal footer must be reachable above the keyboard');
    });

    testWidgets(
        'drag on the sheet dismisses the keyboard; programmatic '
        'ensure-visible does not', (tester) async {
      _sizeScreen(tester);
      await tester.pumpWidget(_keyboardHost(captureView()));

      final field = find.byType(TextField);
      await tester.tap(field);
      // The EnsureVisible settle scroll is programmatic — focus must survive.
      await _settleEnsureVisible(tester);
      expect(_fieldFocus(tester, field).hasFocus, isTrue);

      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(_fieldFocus(tester, field).hasFocus, isFalse,
          reason: 'a user drag must close the keyboard');
    });

    testWidgets('tap on empty space dismisses the keyboard', (tester) async {
      _sizeScreen(tester);
      await tester.pumpWidget(_keyboardHost(captureView()));

      final field = find.byType(TextField);
      await tester.tap(field);
      await _settleEnsureVisible(tester);
      expect(_fieldFocus(tester, field).hasFocus, isTrue);

      // The VISIT. EARN. WIN. headline carries no tap recognizer — the tap
      // falls through to the shared AvafliV2KeyboardDismiss layer.
      await tester.tap(find.textContaining('VISIT.', findRichText: true));
      await tester.pump();
      expect(_fieldFocus(tester, field).hasFocus, isFalse,
          reason: 'a tap outside any control must close the keyboard');
    });
  });

  group('OTP code entry (adoption + new-address verify)', () {
    testWidgets(
        'VERIFY and "Send a new code" stay reachable with the '
        'keyboard open', (tester) async {
      _sizeScreen(tester);
      await tester.pumpWidget(_keyboardHost(codeEntryView()));

      await tester.tap(find.byType(TextField));
      await _settleEnsureVisible(tester);

      final fieldRect = tester.getRect(find.byType(TextField));
      expect(fieldRect.bottom, lessThanOrEqualTo(_kVisibleBottom + 0.5));

      await tester.ensureVisible(find.text('VERIFY'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('VERIFY')).bottom,
          lessThanOrEqualTo(_kVisibleBottom + 0.5));

      final resend = find.textContaining('Send a new code', findRichText: true);
      await tester.ensureVisible(resend);
      await tester.pumpAndSettle();
      expect(tester.getRect(resend).bottom,
          lessThanOrEqualTo(_kVisibleBottom + 0.5));
    });

    testWidgets(
        'bare host (no resizing Scaffold): the scroll view grows its '
        'bottom padding by the keyboard inset', (tester) async {
      _sizeScreen(tester);
      await tester.pumpWidget(_bareHost(codeEntryView()));

      final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView).first);
      final padding = scroll.padding!.resolve(TextDirection.ltr);
      expect(padding.bottom, 18 + _kKeyboardInset,
          reason: 'viewInsets guard must add the keyboard inset when no '
              'resizing Scaffold consumes it');
    });

    testWidgets('drag dismisses the keyboard on the code screen',
        (tester) async {
      _sizeScreen(tester);
      await tester.pumpWidget(_keyboardHost(codeEntryView()));

      final field = find.byType(TextField);
      await tester.tap(field);
      await _settleEnsureVisible(tester);
      expect(_fieldFocus(tester, field).hasFocus, isTrue);

      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(_fieldFocus(tester, field).hasFocus, isFalse);
    });
  });

  group('prize-claim form', () {
    testWidgets(
        'address step: focusing the bottom (zip) field scrolls it '
        'above the keyboard and CONTINUE stays reachable', (tester) async {
      _sizeScreen(tester);
      await tester.pumpWidget(_keyboardHost(claimSteps()));
      await goToAddressStep(tester);

      // Street, Apt, City, Zip — zip is the last TextField on the step.
      final zip = find.byType(TextField).last;
      await tester.ensureVisible(zip);
      await tester.pumpAndSettle();
      await tester.tap(zip);
      await _settleEnsureVisible(tester);

      expect(
          tester.getRect(zip).bottom, lessThanOrEqualTo(_kVisibleBottom + 0.5),
          reason: 'the focused zip field must sit above the keyboard');

      await tester.ensureVisible(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('CONTINUE')).bottom,
          lessThanOrEqualTo(_kVisibleBottom + 0.5));
    });

    testWidgets(
        'address autocomplete: the suggestions card surfaces above '
        'the keyboard while typing', (tester) async {
      _sizeScreen(tester);
      final client = AvafliPlacesClient(
        apiKey: 'AIza-test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('places:autocomplete')) {
            return http.Response(
                jsonEncode({
                  'suggestions': [
                    {
                      'placePrediction': {
                        'placeId': 'place-1',
                        'text': {
                          'text': '1600 Amphitheatre Pkwy, Mountain View, CA'
                        },
                      },
                    },
                  ],
                }),
                200);
          }
          return http.Response(jsonEncode({'addressComponents': []}), 200);
        }),
      );
      await tester.pumpWidget(_keyboardHost(claimSteps(placesClient: client)));
      await goToAddressStep(tester);

      final street = find.byType(TextField).first;
      await tester.tap(street);
      await _settleEnsureVisible(tester);
      await tester.enterText(street, '1600 Amp');
      // Debounce (300ms) + request + the card's own ensure-visible beat.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final suggestion =
          find.textContaining('1600 Amphitheatre Pkwy, Mountain View');
      expect(suggestion, findsOneWidget);
      expect(tester.getRect(suggestion).bottom,
          lessThanOrEqualTo(_kVisibleBottom + 0.5),
          reason: 'suggestions must not be stranded under the keyboard');
      // The street field itself must remain visible with its list.
      expect(tester.getRect(street).bottom,
          lessThanOrEqualTo(_kVisibleBottom + 0.5));
    });
  });

  group('share screen (story textarea)', () {
    testWidgets(
        'story field scrolls above the keyboard and CONTINUE stays '
        'reachable; drag dismisses', (tester) async {
      _sizeScreen(tester);
      await tester.pumpWidget(_keyboardHost(AvafliV2ClaimShareView(
        accent: accent,
        logoUrl: null,
        prizeHeadline: r'$1,000.00 CASH PRIZE',
        onDone: () {},
        onClose: () {},
      )));
      await tester.pump(const Duration(seconds: 1));

      final story = find.byType(TextField);
      await tester.ensureVisible(story);
      await tester.pumpAndSettle();
      await tester.tap(story);
      await _settleEnsureVisible(tester);
      expect(tester.getRect(story).bottom,
          lessThanOrEqualTo(_kVisibleBottom + 0.5),
          reason: 'the story textarea must sit above the keyboard');

      await tester.ensureVisible(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('CONTINUE')).bottom,
          lessThanOrEqualTo(_kVisibleBottom + 0.5));

      expect(_fieldFocus(tester, story).hasFocus, isTrue);
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(_fieldFocus(tester, story).hasFocus, isFalse);
    });
  });
}
