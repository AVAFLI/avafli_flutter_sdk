// Widget smoke tests for the winner prize-claim steps (2.9 flow):
// splash → stepped form (3 steps + review, iOS parity) → submit →
// share/celebrate → confirmation.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_claim.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_effects.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';

Widget _host(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(child: child),
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

void main() {
  setUpAll(_loadRealFonts);

  final accent = AvafliV2Accent(null).color;

  Widget stepsFlow({
    String? maskedEmail = 'c******a@avafli.example.com',
    String? appName,
    AvafliPrizeClaimForm? initialForm,
    String? submitError,
    ValueChanged<AvafliPrizeClaimForm>? onSubmit,
    AvafliClaimPhotoPick? pickPhoto,
  }) {
    return _host(AvafliV2ClaimStepsFlow(
      accent: accent,
      logoUrl: null,
      appName: appName,
      maskedEmail: maskedEmail,
      initialForm: initialForm ?? AvafliPrizeClaimForm(),
      pickPhoto: pickPhoto,
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
    await tester.pumpWidget(_host(AvafliV2WinnerSplashView(
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
    expect(find.byType(AvafliV2GifView), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(AvafliV2GifView),
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

  testWidgets('stepped form walks 3 steps, gates each, and submits',
      (tester) async {
    AvafliPrizeClaimForm? submitted;
    await tester.pumpWidget(stepsFlow(
      initialForm: AvafliPrizeClaimForm(
        firstName: 'Catherine',
        lastName: 'Cinosta',
      ),
      onSubmit: (form) => submitted = form,
    ));
    await tester.pump(const Duration(seconds: 1));

    // ── Step 1 of 3: TELL US ABOUT YOURSELF ──
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text('TELL US ABOUT YOURSELF'), findsOneWidget);
    // The winning email is locked/display-only, masked by the backend.
    expect(find.text('c******a@avafli.example.com'), findsOneWidget);
    // No back chevron on step 1.
    expect(find.byKey(const ValueKey('claim-back')), findsNothing);

    // Names are prefilled → CONTINUE advances.
    await tapContinue(tester);

    // ── Step 2 of 3: address ──
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('WHERE SHOULD WE\nSEND YOUR PRIZE?'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-back')), findsOneWidget);

    // Incomplete address: CONTINUE is a no-op.
    await tapContinue(tester);
    expect(find.text('STEP 2 OF 3'), findsOneWidget);

    // Fill the address (text fields run street, apt, city, zip).
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '5 Haide Pl.');
    await tester.enterText(fields.at(2), 'Brooklyn');
    await tester.enterText(fields.at(3), '11737');
    // Let the focus-follows-keyboard centering (AvafliV2EnsureVisible) finish
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

    // ── Step 3 of 3: SHOW OFF YOUR WIN! (optional photo, iOS parity) ──
    expect(find.text('STEP 3 OF 3'), findsOneWidget);
    expect(find.text('SHOW OFF YOUR WIN!'), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-photo-upload')), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-photo-take')), findsOneWidget);

    // The photo is fully optional — CONTINUE advances with none attached.
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
    expect(submitted!.photoBase64, isNull);

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
      initialForm: AvafliPrizeClaimForm(firstName: 'Sam', lastName: 'Winner'),
    ));
    await tester.pump(const Duration(seconds: 1));

    await tapContinue(tester);
    expect(find.text('STEP 2 OF 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('claim-back')));
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 3'), findsOneWidget);

    // Prefilled values survive the round trip.
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Winner'), findsOneWidget);
  });

  testWidgets(
      'photo step attaches via the picker, rides the submitted payload, '
      'and a cancelled re-pick clears it (iOS attach(nil) parity)',
      (tester) async {
    // A 1×1 transparent PNG — decodable by Image.memory for the preview.
    final png = Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, // IDAT
      0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND
      0x42, 0x60, 0x82,
    ]);
    final picks = <bool>[];
    Uint8List? nextPick = png;
    AvafliPrizeClaimForm? submitted;

    await tester.pumpWidget(stepsFlow(
      initialForm: AvafliPrizeClaimForm(
        firstName: 'Catherine',
        lastName: 'Cinosta',
        street: '5 Haide Pl.',
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
      ),
      pickPhoto: ({required bool preferCamera}) async {
        picks.add(preferCamera);
        return nextPick;
      },
      onSubmit: (form) => submitted = form,
    ));
    await tester.pump(const Duration(seconds: 1));

    await tapContinue(tester); // → step 2
    await tapContinue(tester); // → step 3 (photo)
    expect(find.text('SHOW OFF YOUR WIN!'), findsOneWidget);

    // UPLOAD PHOTO goes straight to the library (no camera preference).
    await tester.tap(find.byKey(const ValueKey('claim-photo-upload')));
    await tester.pumpAndSettle();
    expect(picks, [false]);
    expect(
      find.byKey(const ValueKey('claim-photo-preview')),
      findsOneWidget, // circular preview
    );

    // TAKE PHOTO prefers the camera.
    await tester.tap(find.byKey(const ValueKey('claim-photo-take')));
    await tester.pumpAndSettle();
    expect(picks, [false, true]);

    // The attached photo rides the submitted payload base64-encoded.
    await tapContinue(tester); // → review
    await tester.ensureVisible(find.text('SUBMIT PRIZE CLAIM'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SUBMIT PRIZE CLAIM'));
    expect(submitted, isNotNull);
    expect(submitted!.photoBase64, base64Encode(png));

    // Going back keeps the preview; a pick that returns nothing CLEARS the
    // photo — identical to iOS's attach(nil).
    await tester.tap(find.byKey(const ValueKey('claim-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('claim-photo-preview')), findsOneWidget);
    nextPick = null;
    await tester.tap(find.byKey(const ValueKey('claim-photo-upload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('claim-photo-preview')), findsNothing);

    submitted = null;
    await tapContinue(tester); // → review
    await tester.ensureVisible(find.text('SUBMIT PRIZE CLAIM'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SUBMIT PRIZE CLAIM'));
    expect(submitted!.photoBase64, isNull);
  });

  test('claim photo encoding: base64 under the cap, dropped over it', () {
    final small = Uint8List.fromList([1, 2, 3]);
    expect(AvafliClaimPhoto.base64Jpeg(small), base64Encode(small));
    expect(
      AvafliClaimPhoto.base64Jpeg(
        Uint8List(AvafliClaimPhoto.maxBytes + 1),
      ),
      isNull,
    );
  });

  testWidgets('missing maskedEmail falls back to the generic locked copy',
      (tester) async {
    await tester.pumpWidget(stepsFlow(maskedEmail: null));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('On file with your winning entry'), findsOneWidget);
  });

  testWidgets('review surfaces the inline submit error', (tester) async {
    await tester.pumpWidget(stepsFlow(
      initialForm: AvafliPrizeClaimForm(
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
    await tapContinue(tester); // → step 3 (photo, optional)
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
      AvafliV2ClaimStepsFlow.likenessConsentLabel('Skape'),
      'I authorize Skape and its promotional partners to use my name, city, '
      'profile photo, and likeness for winner announcements and promotional '
      'purposes. (Optional)',
    );
    // Absent/blank appName → the generic wording, unchanged.
    for (final absent in [null, '', '   ']) {
      expect(
        AvafliV2ClaimStepsFlow.likenessConsentLabel(absent),
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
      initialForm: AvafliPrizeClaimForm(
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
    await tapContinue(tester); // → step 3 (photo, optional)
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
    await tester.pumpWidget(_host(AvafliV2ClaimConfirmationView(
      accent: accent,
      logoUrl: null,
      form: AvafliPrizeClaimForm(
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
    expect(find.byType(AvafliV2Confetti), findsOneWidget);
    expect(find.byType(AvafliV2GifView), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('YOUR PRIZE CLAIM HAS BEEN SUBMITTED'), findsOneWidget);
    // No white "Avafli MEDIA PRIZE CLAIM" strip — that's a canvas label in
    // Joe's frame, not UI.
    expect(find.text('Avafli MEDIA PRIZE CLAIM'), findsNothing);
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
      AvafliV2ClaimShareView.shareLine(r'$1,000.00 CASH PRIZE', 'Skape'),
      r'I just won $1,000.00 CASH PRIZE in Skape!',
    );
    expect(
      AvafliV2ClaimShareView.shareLine(r'$1,000.00 CASH PRIZE', null),
      r'I just won $1,000.00 CASH PRIZE!',
    );
    expect(
      AvafliV2ClaimShareView.shareLine(r'$1,000.00 CASH PRIZE', '  '),
      r'I just won $1,000.00 CASH PRIZE!',
    );
  });

  group('share-link UTM tagging', () {
    test('appends utm params to a plain URL', () {
      expect(
        AvafliV2ClaimShareView.taggedShareUrl('https://example.com/app', 'x'),
        'https://example.com/app?utm_source=x&utm_medium=avafli_share',
      );
    });

    test('appends utm params to a URL with an existing query string', () {
      expect(
        AvafliV2ClaimShareView.taggedShareUrl(
            'https://example.com/app?ref=abc', 'facebook'),
        'https://example.com/app?ref=abc&utm_source=facebook'
        '&utm_medium=avafli_share',
      );
    });

    test('leaves a URL with an existing utm_source untouched', () {
      const url = 'https://example.com/app?utm_source=publisher'
          '&utm_medium=email';
      expect(AvafliV2ClaimShareView.taggedShareUrl(url, 'x'), url);
    });

    test('passes through null and empty', () {
      expect(AvafliV2ClaimShareView.taggedShareUrl(null, 'x'), isNull);
      expect(AvafliV2ClaimShareView.taggedShareUrl('', 'x'), '');
    });

    test('each network carries its own utm_source value', () {
      for (final network in [
        'x',
        'facebook',
        'instagram',
        'snapchat',
        'tiktok'
      ]) {
        final tagged = AvafliV2ClaimShareView.taggedShareUrl(
            'https://example.com/app', network);
        expect(
          Uri.parse(tagged!).queryParameters['utm_source'],
          network,
        );
        expect(Uri.parse(tagged).queryParameters['utm_medium'], 'avafli_share');
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
    await tester.pumpWidget(_host(AvafliV2ClaimShareView(
      accent: accent,
      logoUrl: null,
      prizeHeadline: r'$1,000.00 CASH PRIZE',
      appName: 'Skape',
      shareUrl: 'https://avafli.example.com/s/abc',
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
          'https://avafli.example.com/s/abc'
          '?utm_source=instagram&utm_medium=avafli_share',
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
    await tester.pumpWidget(_host(AvafliV2ClaimShareView(
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
    await tester.tap(find.byKey(const ValueKey('claim-close')));
    await tester.pump();
    expect(closed, 1);
    expect(stories, ['Buying mom dinner.']);
  });

  testWidgets('an empty story is never delivered', (tester) async {
    final stories = <String>[];
    var advanced = false;
    await tester.pumpWidget(_host(AvafliV2ClaimShareView(
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
