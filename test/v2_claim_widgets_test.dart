// Widget smoke tests for the winner prize-claim steps (2.9 flow):
// splash → stepped form (2 steps + review on Flutter) → submit →
// share/celebrate → confirmation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_claim.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_effects.dart';
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
    String? appName,
    WINRPrizeClaimForm? initialForm,
    String? submitError,
    ValueChanged<WINRPrizeClaimForm>? onSubmit,
  }) {
    return _host(WINRV2ClaimStepsFlow(
      accent: accent,
      logoUrl: null,
      appName: appName,
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
    // The one-shot confetti burst mounts WITH the splash (2.9.3) — same
    // machinery as the streak tile's reveal beat — wrapped in IgnorePointer
    // so it can never block CONTINUE. (It removes itself when the GIF ends,
    // so assert on the first frame, before the clock advances.)
    expect(find.byType(WINRV2GifView), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(WINRV2GifView),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
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
    // The removed checkboxes stay gone, and 2.9.3 removed the "By
    // submitting you agree to…" sentence AND its Official Rules / Privacy
    // Policy links from this screen entirely — only the optional likeness
    // checkbox, SUBMIT, and the secure-note remain.
    expect(find.byKey(const ValueKey('consent-accuracy')), findsNothing);
    expect(find.byKey(const ValueKey('consent-rules')), findsNothing);
    expect(find.byKey(const ValueKey('consent-likeness')), findsOneWidget);
    expect(find.textContaining('By submitting'), findsNothing);
    expect(find.textContaining('Official Rules'), findsNothing);
    expect(find.textContaining('Privacy Policy'), findsNothing);
    // No appName configured → the generic likeness wording.
    expect(
      find.textContaining("I authorize this app's publisher"),
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

  test('likeness consent copy names the publisher only when configured', () {
    expect(
      WINRV2ClaimStepsFlow.likenessConsentLabel('Skape'),
      'I authorize Skape and its promotional partners to use my name, city, '
      'profile photo, and likeness for winner announcements and promotional '
      'purposes. (Optional)',
    );
    // Absent/blank appName → the generic wording, unchanged.
    for (final absent in [null, '', '   ']) {
      expect(
        WINRV2ClaimStepsFlow.likenessConsentLabel(absent),
        "(Optional) I authorize this app's publisher and its promotional "
        'partners to use my name, city, profile photo, and likeness for '
        'winner announcements and promotional purposes.',
      );
    }
  });

  testWidgets('review names the publisher in the likeness consent',
      (tester) async {
    await tester.pumpWidget(stepsFlow(
      appName: 'Skape',
      initialForm: WINRPrizeClaimForm(
        firstName: 'Catherine',
        lastName: 'Cinosta',
        street: '5 Haide Pl.',
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    await tapContinue(tester); // → step 2
    await tapContinue(tester); // → review

    expect(find.text('ALMOST DONE!'), findsOneWidget);
    expect(
      find.textContaining('I authorize Skape and its promotional partners'),
      findsOneWidget,
    );
    expect(find.textContaining("this app's publisher"), findsNothing);
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
    // Celebration mounts WITH the confirmation (2.9.3): the drifting gold
    // confetti field plus the one-shot burst GIF (asserted on the first
    // frame, before the burst can finish and remove itself) — both behind
    // IgnorePointer so RETURN TO APP is never blocked.
    expect(find.byType(WINRV2Confetti), findsOneWidget);
    expect(find.byType(WINRV2GifView), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('YOUR PRIZE CLAIM HAS BEEN SUBMITTED'), findsOneWidget);
    // No white "WINR MEDIA PRIZE CLAIM" strip — that's a canvas label in
    // Joe's frame, not UI.
    expect(find.text('WINR MEDIA PRIZE CLAIM'), findsNothing);
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

  group('share-link UTM tagging', () {
    test('appends utm params to a plain URL', () {
      expect(
        WINRV2ClaimShareView.taggedShareUrl('https://example.com/app', 'x'),
        'https://example.com/app?utm_source=x&utm_medium=winr_share',
      );
    });

    test('appends utm params to a URL with an existing query string', () {
      expect(
        WINRV2ClaimShareView.taggedShareUrl(
            'https://example.com/app?ref=abc', 'facebook'),
        'https://example.com/app?ref=abc&utm_source=facebook'
        '&utm_medium=winr_share',
      );
    });

    test('leaves a URL with an existing utm_source untouched', () {
      const url = 'https://example.com/app?utm_source=publisher'
          '&utm_medium=email';
      expect(WINRV2ClaimShareView.taggedShareUrl(url, 'x'), url);
    });

    test('passes through null and empty', () {
      expect(WINRV2ClaimShareView.taggedShareUrl(null, 'x'), isNull);
      expect(WINRV2ClaimShareView.taggedShareUrl('', 'x'), '');
    });

    test('each network carries its own utm_source value', () {
      for (final network in ['x', 'facebook', 'instagram', 'snapchat', 'tiktok']) {
        final tagged = WINRV2ClaimShareView.taggedShareUrl(
            'https://example.com/app', network);
        expect(
          Uri.parse(tagged!).queryParameters['utm_source'],
          network,
        );
        expect(Uri.parse(tagged).queryParameters['utm_medium'], 'winr_share');
      }
    });
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

    // Instagram has no text-prefill API → clipboard + confirmation. The
    // shareUrl is UTM-tagged with the tapped network even on this path.
    await tester.tap(find.bySemanticsLabel('Share on Instagram'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(copied, [
      r'I just won $1,000.00 CASH PRIZE in Skape! '
          'https://winr.example.com/s/abc'
          '?utm_source=instagram&utm_medium=winr_share',
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
