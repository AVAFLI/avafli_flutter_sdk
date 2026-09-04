import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_screens.dart';

/// Parity regression: the age-gate and marketing checkboxes must share the
/// same left edge (start-aligned, full-width rows) — a shrink-wrapped centered
/// row used to float the short age-gate line into the middle of the screen.
void main() {
  testWidgets('capture-screen checkbox rows are left-aligned and line up', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          child: AvafliV2CaptureView(
            accent: const Color(0xFF2E7D32),
            logoUrl: null,
            rulesUrl: null,
            giveaway: null,
            isSubmitting: false,
            onSubmit: (_, {required ageConfirmed, required marketingConsent}) {},
            onInfo: () {},
            onClose: () {},
            marketingConsentText: 'I agree to receive marketing emails from Skape Test Account (Sandbox) and its partners',
            ageGateText: 'I confirm I am 18 years of age or older',
            submitError: null,
          ),
        ),
      ),
    ));
    await tester.pump();
    // The two 20x20 boxes are AnimatedContainers with fixed size.
    final boxes = find.byWidgetPredicate(
      (w) => w is AnimatedContainer && w.constraints?.maxWidth == 20 && w.constraints?.maxHeight == 20,
    );
    expect(boxes, findsNWidgets(2));
    final a = tester.getTopLeft(boxes.at(0));
    final b = tester.getTopLeft(boxes.at(1));
    expect(a.dx, b.dx, reason: 'age-gate box x=${a.dx} vs marketing box x=${b.dx}');
    // Start-aligned: the box sits at the row's left edge, not screen centre.
    expect(a.dx, lessThan(200));
  });
}
