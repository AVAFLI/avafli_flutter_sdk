// Widget smoke tests for the winner prize-claim steps (2.9 flow):
// splash → stepped form (2 steps + review on Flutter) → submit →
// share/celebrate → confirmation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_claim.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_theme.dart';

Widget _host(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(child: child),
  );
}

/// Loads the real bundled Inter faces so text measures like production.
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
}

void main() {
  setUpAll(_loadRealFonts);

  final accent = WINRV2Accent(null).color;

  Widget stepsFlow({
    String? maskedEmail = 'c******a@winr.example.com',
    WINRPrizeClaimForm? initialForm,
    String? submitError,
    ValueChanged<WINRPrizeClaimForm>? onSubmit,
  }) {
    return _host(WINRV2ClaimStepsFlow(
      accent: accent,
      logoUrl: null,
      maskedEmail: maskedEmail,
      initialForm: initialForm ?? WINRPrizeClaimForm(),
      isSubmitting: false,
      submitError: submitError,
      onSubmit: onSubmit ?? (_) {},
      onClose: () {},
    ));
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
  }

  testWidgets('winner splash renders and CONTINUE advances', (tester) async {
    var continued = false;
    await tester.pumpWidget(_host(WINRV2WinnerSplashView(
      accent: accent,
      logoUrl: null,
      prizeHeadline: r'$1,000.00 CASH PRIZE',
      onContinue: () => continued = true,
      onClose: () {},
    )));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('CONGRATULATIONS!'), findsOneWidget);
    expect(find.text('YOU’RE OUR LATEST WINNER!'), findsOneWidget);
    expect(find.text('You’ve won:'), findsOneWidget);
    expect(find.text(r'$1,000.00 CASH PRIZE'), findsOneWidget);
    expect(
      find.text('To process your prize, we just need a few details.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('CONTINUE'));
    expect(continued, isTrue);
  });

  testWidgets('stepped form walks 2 steps, gates each, and submits',
      (tester) async {
    WINRPrizeClaimForm? submitted;
    await tester.pumpWidget(stepsFlow(
      initialForm: WINRPrizeClaimForm(
        firstName: 'Catherine',
        lastName: 'Cinosta',
      ),
      onSubmit: (form) => submitted = form,
    ));
    await tester.pump(const Duration(seconds: 1));

    // ── Step 1 of 2: TELL US ABOUT YOURSELF ──
    expect(find.text('STEP 1 OF 2'), findsOneWidget);
    expect(find.text('TELL US ABOUT YOURSELF'), findsOneWidget);
    // The winning email is locked/display-only, masked by the backend.
    expect(find.text('c******a@winr.example.com'), findsOneWidget);
    // No back chevron on step 1.
    expect(find.byKey(const ValueKey('claim-back')), findsNothing);

    // Names are prefilled → CONTINUE advances.
    await tapContinue(tester);

    // ── Step 2 of 2: address ──
    expect(find.text('STEP 2 OF 2'), findsOneWidget);
    expect(find.text('WHERE SHOULD WE\nSEND YOUR PRIZE?'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-back')), findsOneWidget);

    // Incomplete address: CONTINUE is a no-op.
    await tapContinue(tester);
    expect(find.text('STEP 2 OF 2'), findsOneWidget);

    // Fill the address (text fields run street, apt, city, zip).
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '5 Haide Pl.');
    await tester.enterText(fields.at(2), 'Brooklyn');
    await tester.enterText(fields.at(3), '11737');
    // Let the focus-follows-keyboard centering (WINRV2EnsureVisible) finish
    // before choreographing taps against fixed positions.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // 50-state dropdown.
    await tester.ensureVisible(find.text('Select'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alabama').last);
    await tester.pumpAndSettle();

    await tapContinue(tester);

    // ── Review: ALMOST DONE! — only the OPTIONAL promo consent (2.9) ──
    expect(find.text('ALMOST DONE!'), findsOneWidget);
    expect(
      find.text('Your information is secure and encrypted.'),
      findsOneWidget,
    );
    // The removed checkboxes are gone; the rules/privacy links remain as
    // tappable text.
    expect(find.byKey(const ValueKey('consent-accuracy')), findsNothing);
    expect(find.byKey(const ValueKey('consent-rules')), findsNothing);
    expect(find.byKey(const ValueKey('consent-likeness')), findsOneWidget);
    expect(
      find.textContaining('By submitting you agree to the'),
      findsOneWidget,
    );

    // SUBMIT works with the promo consent UNCHECKED — it never gates.
    await tester.ensureVisible(find.text('SUBMIT PRIZE CLAIM'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SUBMIT PRIZE CLAIM'));
    expect(submitted, isNotNull);
    expect(submitted!.isValid, isTrue);
    expect(submitted!.firstName, 'Catherine');
    expect(submitted!.state, 'Alabama');
    expect(submitted!.zip, '11737');
    expect(submitted!.promoConsentGranted, isFalse);

    // Ticking the promo consent carries through the payload.
    submitted = null;
    await tester.ensureVisible(find.byKey(const ValueKey('consent-likeness')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('consent-likeness'))) +
          const Offset(12, 12),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('SUBMIT PRIZE CLAIM'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SUBMIT PRIZE CLAIM'));
    expect(submitted, isNotNull);
    expect(submitted!.promoConsentGranted, isTrue);
  });

  testWidgets('back chevron returns to the previous step keeping values',
      (tester) async {
    await tester.pumpWidget(stepsFlow(
      initialForm: WINRPrizeClaimForm(firstName: 'Sam', lastName: 'Winner'),
    ));
    await tester.pump(const Duration(seconds: 1));

    await tapContinue(tester);
    expect(find.text('STEP 2 OF 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('claim-back')));
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 2'), findsOneWidget);

    // Prefilled values survive the round trip.
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Winner'), findsOneWidget);
  });

  testWidgets('missing maskedEmail falls back to the generic locked copy',
      (tester) async {
    await tester.pumpWidget(stepsFlow(maskedEmail: null));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('On file with your winning entry'), findsOneWidget);
  });

  testWidgets('review surfaces the inline submit error', (tester) async {
    await tester.pumpWidget(stepsFlow(
      initialForm: WINRPrizeClaimForm(
        firstName: 'Catherine',
        lastName: 'Cinosta',
        street: '5 Haide Pl.',
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
      ),
      submitError:
          'Something went wrong. Please check your connection and try again.',
    ));
    await tester.pump(const Duration(seconds: 1));

    // Every step is prefilled valid — walk straight to the review screen.
    await tapContinue(tester); // → step 2
    await tapContinue(tester); // → review

    expect(find.text('ALMOST DONE!'), findsOneWidget);
    expect(
      find.text(
        'Something went wrong. Please check your connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('confirmation renders the OFFICIAL WINNER card', (tester) async {
    var done = false;
    await tester.pumpWidget(_host(WINRV2ClaimConfirmationView(
      accent: accent,
      logoUrl: null,
      form: WINRPrizeClaimForm(
        firstName: 'Catherine',
        lastName: 'Cinosta',
        street: '5 Haide Pl.',
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
      ),
      claimNumber: '9823457758',
      submittedAt: '2026-08-04T12:00:00Z',
      onDone: () => done = true,
    )));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('YOUR PRIZE CLAIM HAS BEEN SUBMITTED'), findsOneWidget);
    expect(find.text('3-5 Business Days'), findsOneWidget);
    expect(find.text('OFFICIAL'), findsOneWidget);
    expect(find.text('WINNER'), findsOneWidget);
    expect(find.text('Catherine C.'), findsOneWidget);
    expect(find.text('Brooklyn, New York'), findsOneWidget);
    expect(find.text('AUGUST, 2026 • 9823457758'), findsOneWidget);

    await tester.ensureVisible(find.text('RETURN TO APP'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('RETURN TO APP'));
    expect(done, isTrue);
  });

  // ── Post-submit share step (2.9) ──

  test('share line drops the app clause when no appName is configured', () {
    expect(
      WINRV2ClaimShareView.shareLine(r'$1,000.00 CASH PRIZE', 'Skape'),
      r'I just won $1,000.00 CASH PRIZE in Skape!',
    );
    expect(
      WINRV2ClaimShareView.shareLine(r'$1,000.00 CASH PRIZE', null),
      r'I just won $1,000.00 CASH PRIZE!',
    );
    expect(
      WINRV2ClaimShareView.shareLine(r'$1,000.00 CASH PRIZE', '  '),
      r'I just won $1,000.00 CASH PRIZE!',
    );
  });

  testWidgets(
      'share step renders post-submit, copies on non-prefill networks, and '
      'CONTINUE advances', (tester) async {
    var advanced = false;
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final stories = <String>[];
    await tester.pumpWidget(_host(WINRV2ClaimShareView(
      accent: accent,
      logoUrl: null,
      prizeHeadline: r'$1,000.00 CASH PRIZE',
      appName: 'Skape',
      shareUrl: 'https://winr.example.com/s/abc',
      onStory: stories.add,
      onDone: () => advanced = true,
      onClose: () {},
    )));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('PLEASE SHARE A LITTLE'), findsOneWidget);
    expect(find.text('Share on Social Media:'), findsOneWidget);
    expect(
      find.text(r'I just won $1,000.00 CASH PRIZE in Skape!'),
      findsOneWidget,
    );

    // The optional story textarea lives here now (post-submit).
    await tester.enterText(find.byType(TextField).first, '  So excited!  ');
    await tester.pump();

    // Instagram has no text-prefill API → clipboard + confirmation.
    await tester.tap(find.bySemanticsLabel('Share on Instagram'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(copied, [
      r'I just won $1,000.00 CASH PRIZE in Skape! '
          'https://winr.example.com/s/abc',
    ]);
    // The confirmation is faded IN (it lives in the tree at opacity 0
    // otherwise), then clears itself after the hold.
    AnimatedOpacity copiedFade() => tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.text('Copied — paste it in your post'),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
    expect(copiedFade().opacity, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(copiedFade().opacity, 0);

    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('CONTINUE'));
    expect(advanced, isTrue);
    // The trimmed story was delivered exactly once, on CONTINUE.
    expect(stories, ['So excited!']);
  });

  testWidgets('closing the share step still delivers a typed story — once',
      (tester) async {
    final stories = <String>[];
    var closed = 0;
    await tester.pumpWidget(_host(WINRV2ClaimShareView(
      accent: accent,
      logoUrl: null,
      prizeHeadline: r'$1,000.00 CASH PRIZE',
      onStory: stories.add,
      onDone: () {},
      onClose: () => closed++,
    )));
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField).first, 'Buying mom dinner.');
    await tester.pump();

    // Close via the header X — the story must not be lost.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(closed, 1);
    expect(stories, ['Buying mom dinner.']);
  });

  testWidgets('an empty story is never delivered', (tester) async {
    final stories = <String>[];
    var advanced = false;
    await tester.pumpWidget(_host(WINRV2ClaimShareView(
      accent: accent,
      logoUrl: null,
      prizeHeadline: r'$1,000.00 CASH PRIZE',
      onStory: stories.add,
      onDone: () => advanced = true,
      onClose: () {},
    )));
    await tester.pump(const Duration(seconds: 1));

    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('CONTINUE'));
    expect(advanced, isTrue);
    expect(stories, isEmpty);
  });
}
