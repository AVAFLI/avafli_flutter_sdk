// Widget smoke tests for the three winner prize-claim steps:
// splash → form → confirmation (mirrors iOS WINRV2Claim.swift).

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

  testWidgets('claim form gates SUBMIT on validity', (tester) async {
    WINRPrizeClaimForm? submitted;
    await tester.pumpWidget(_host(WINRV2ClaimFormView(
      accent: accent,
      logoUrl: null,
      initialForm: WINRPrizeClaimForm(
        firstName: 'Catherine',
        lastName: 'Cinosta',
      ),
      isSubmitting: false,
      submitError: null,
      onSubmit: (form) => submitted = form,
      onClose: () {},
    )));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('PRIZE CLAIM FORM'), findsOneWidget);
    expect(find.text('TELL US ABOUT YOURSELF'), findsOneWidget);
    // The winning email is locked/display-only — the SDK never stores raw
    // email, the claim is keyed to the account server-side.
    expect(find.text('On file with your winning entry'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(
      find.text('Your information is secure and encrypted.'),
      findsOneWidget,
    );

    // Incomplete form: SUBMIT is disabled.
    await tester.ensureVisible(find.text('SUBMIT PRIZE CLAIM'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SUBMIT PRIZE CLAIM'), warnIfMissed: false);
    expect(submitted, isNull);

    // Fill the required fields (first/last are prefilled; text fields run
    // firstName, lastName, phone, street, apt, city, zip).
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(3), '5 Haide Pl.');
    await tester.enterText(fields.at(5), 'Brooklyn');
    await tester.enterText(fields.at(6), '11737');

    // 50-state dropdown.
    await tester.ensureVisible(find.text('Select'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alabama').last);
    await tester.pumpAndSettle();

    // Still gated: all three consents must be affirmed.
    await tester.ensureVisible(find.text('SUBMIT PRIZE CLAIM'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SUBMIT PRIZE CLAIM'), warnIfMissed: false);
    expect(submitted, isNull);

    // Tick the three consent checkboxes (tap the 24pt box at the row's left
    // edge — the underlined rules/privacy spans open a URL instead).
    for (final key in const [
      ValueKey('consent-accuracy'),
      ValueKey('consent-likeness'),
      ValueKey('consent-rules'),
    ]) {
      await tester.ensureVisible(find.byKey(key));
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(tester.getTopLeft(find.byKey(key)) + const Offset(12, 12));
      await tester.pump(const Duration(milliseconds: 200));
    }

    await tester.ensureVisible(find.text('SUBMIT PRIZE CLAIM'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SUBMIT PRIZE CLAIM'));
    expect(submitted, isNotNull);
    expect(submitted!.isValid, isTrue);
    expect(submitted!.state, 'Alabama');
    expect(submitted!.zip, '11737');
    expect(submitted!.confirmsAccuracy, isTrue);
    expect(submitted!.authorizesLikeness, isTrue);
    expect(submitted!.agreesToRules, isTrue);
  });

  testWidgets('claim form surfaces inline submit error', (tester) async {
    await tester.pumpWidget(_host(WINRV2ClaimFormView(
      accent: accent,
      logoUrl: null,
      initialForm: WINRPrizeClaimForm(),
      isSubmitting: false,
      submitError:
          'Something went wrong. Please check your connection and try again.',
      onSubmit: (_) {},
      onClose: () {},
    )));
    await tester.pump(const Duration(seconds: 1));

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
