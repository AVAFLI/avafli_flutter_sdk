// Widget smoke tests for the winner prize-claim steps:
// splash → stepped form (3 steps + review on Flutter) → confirmation
// (mirrors iOS WINRV2Claim.swift + WINRV2ClaimSteps/).

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
      prizeHeadline: r'$1,000.00 CASH PRIZE',
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

  testWidgets('stepped form walks 3 steps, gates each, and submits',
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

    // ── Step 1 of 3: TELL US ABOUT YOURSELF ──
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text('TELL US ABOUT YOURSELF'), findsOneWidget);
    // The winning email is locked/display-only, masked by the backend.
    expect(find.text('c******a@winr.example.com'), findsOneWidget);
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

    // 50-state dropdown.
    await tester.ensureVisible(find.text('Select'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alabama').last);
    await tester.pumpAndSettle();

    await tapContinue(tester);

    // ── Step 3 of 3: story + share ──
    expect(find.text('STEP 3 OF 3'), findsOneWidget);
    expect(find.text('PLEASE SHARE A LITTLE'), findsOneWidget);
    expect(find.text('Share on Social Media:'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'So excited!');
    await tester.pumpAndSettle();
    await tapContinue(tester);

    // ── Review: ALMOST DONE! — consents PRE-CHECKED ──
    expect(find.text('ALMOST DONE!'), findsOneWidget);
    expect(
      find.text('Your information is secure and encrypted.'),
      findsOneWidget,
    );

    // Untick a pre-checked consent → SUBMIT is a no-op.
    await tester.ensureVisible(find.byKey(const ValueKey('consent-likeness')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('consent-likeness'))) +
          const Offset(12, 12),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('SUBMIT PRIZE CLAIM'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SUBMIT PRIZE CLAIM'), warnIfMissed: false);
    expect(submitted, isNull);

    // Re-affirm it → SUBMIT goes through with the whole form.
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
    expect(submitted!.isValid, isTrue);
    expect(submitted!.firstName, 'Catherine');
    expect(submitted!.state, 'Alabama');
    expect(submitted!.zip, '11737');
    expect(submitted!.story, 'So excited!');
    expect(submitted!.confirmsAccuracy, isTrue);
    expect(submitted!.authorizesLikeness, isTrue);
    expect(submitted!.agreesToRules, isTrue);
  });

  testWidgets('back chevron returns to the previous step keeping values',
      (tester) async {
    await tester.pumpWidget(stepsFlow(
      initialForm: WINRPrizeClaimForm(firstName: 'Sam', lastName: 'Winner'),
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
    await tapContinue(tester); // → step 3
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
}
