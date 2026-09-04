import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_components.dart';

/// iOS parity: a long physical-prize name shrinks to fit two lines instead
/// of being cut off with an ellipsis (SwiftUI .minimumScaleFactor(0.55)).
/// Widths are derived from the test font's own metrics so the assertions
/// hold regardless of glyph shapes.
void main() {
  const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w900);
  const text = 'Win an EGO POWER+ 600 Series';

  double singleLineWidth() {
    final p = TextPainter(
      text: const TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return p.width;
  }

  Future<Text> render(WidgetTester tester, double width) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: const AvafliV2ShrinkToFitText(text, style: style, maxLines: 2, minScale: 0.55),
          ),
        ),
      ),
    ));
    return tester.widget<Text>(find.byType(Text));
  }

  testWidgets('keeps the full size when two lines are enough', (tester) async {
    final w = singleLineWidth();
    final t = await render(tester, w * 0.7 + 40); // ~1.5 lines at full size
    expect(t.style!.fontSize, 28);
  });

  testWidgets('shrinks (never below 55%) instead of truncating when it would need 3+ lines', (tester) async {
    final w = singleLineWidth();
    final width = w * 0.42; // needs ~2.4 lines at full size → must shrink
    final t = await render(tester, width);
    expect(t.style!.fontSize, lessThan(28));
    expect(t.style!.fontSize, greaterThanOrEqualTo(28 * 0.55));
    final painter = TextPainter(
      text: TextSpan(text: text, style: t.style),
      maxLines: 2,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    expect(painter.didExceedMaxLines, isFalse, reason: 'must fit two lines at the chosen size');
  });
}
