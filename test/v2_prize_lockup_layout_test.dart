// Regression tests for the prize-card headline collision the CTO found in
// the Skape build: "CASH PRIZE" printed ON TOP of the bottom of "WIN $1,000".
//
// Root cause was a Flutter/SwiftUI leading mismatch — the big line used
// `height: 1.0` (a line box exactly `fontSize` tall, NO leading, so Inter
// Black's real ascent/descent spill out of it) and the second line was then
// pulled up into that spill by `Transform.translate(offset: Offset(0, -5))`.
// iOS's `VStack(spacing: -5)` is safe because SwiftUI line boxes carry
// natural leading (~1.2) that absorbs the negative spacing.
//
// These tests pin the two invariants that make a collision impossible:
//   1. the stacked display lines' painted boxes never overlap (this is what
//      the negative translate broke — `getRect` includes paint transforms), and
//   2. the display lines carry real leading (>= avafliV2HeadlineLineHeight), so
//      glyphs stay inside their own line box at any FittedBox scale.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_components.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';

/// Loads the real bundled Inter faces so text measures like production (the
/// test-default font has different metrics and would mask a leading bug).
Future<void> _loadRealFonts() async {
  final inter = FontLoader('packages/avafli_sdk/Inter');
  for (final file in [
    'inter-v20-latin-regular.ttf',
    'inter-v20-latin-700.ttf',
    'inter-v20-latin-900.ttf',
  ]) {
    inter.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await inter.load();
}

/// The prize card as the dashboard lays it out: 22pt side padding inside a
/// drawer [width] points wide.
Widget _card({
  required double width,
  required int prizeValue,
  String prizeDescription = '',
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(
      color: AvafliV2Colors.gunmetal,
      child: Center(
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: AvafliV2PrizeCard(
              accent: AvafliV2Accent(null).color,
              streakDay: 3,
              totalEntries: 100,
              prizeImageUrl: null,
              prizeValue: prizeValue,
              prizeDescription: prizeDescription,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The `height` (leading multiple) actually applied to a rendered [Text].
double? _lineHeightOf(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style?.height;

void main() {
  setUpAll(_loadRealFonts);

  group('cash lockup never overlaps', () {
    // Widest realistic case, a short one, and an absurd one that forces the
    // FittedBox to scale the lockup down hard.
    for (final prizeValue in [1000, 25, 1000000]) {
      // iPhone 14/15, iPhone SE (2nd/3rd gen), iPhone SE (1st gen).
      for (final width in [390.0, 375.0, 320.0]) {
        testWidgets('\$$prizeValue at ${width.toInt()}pt wide', (tester) async {
          await tester.pumpWidget(_card(width: width, prizeValue: prizeValue));
          await tester.pump(const Duration(seconds: 1));

          final headline = find.text('WIN \$${avafliV2FormatInt(prizeValue)}');
          final subline = find.text('CASH PRIZE');
          expect(headline, findsOneWidget);
          expect(subline, findsOneWidget);

          final headlineRect = tester.getRect(headline);
          final sublineRect = tester.getRect(subline);

          // THE defect: the two lines must not occupy the same pixels. The
          // old `Transform.translate(0, -5)` put the subline's box 5pt INSIDE
          // the headline's, which is why the glyphs collided.
          expect(
            sublineRect.top,
            greaterThanOrEqualTo(headlineRect.bottom),
            reason: 'CASH PRIZE overlaps the bottom of the WIN line '
                '(headline $headlineRect, subline $sublineRect)',
          );

          // Both lines carry real leading, so glyphs (the comma's descender,
          // the "$" tail) stay inside their own line box rather than spilling
          // into the neighbouring line.
          expect(_lineHeightOf(tester, headline),
              greaterThanOrEqualTo(avafliV2HeadlineLineHeight));
          expect(_lineHeightOf(tester, subline),
              greaterThanOrEqualTo(avafliV2HeadlineLineHeight));

          // And the whole lockup stays inside the 200pt card.
          final cardRect = tester.getRect(find.byType(AvafliV2PrizeCard));
          expect(sublineRect.bottom, lessThanOrEqualTo(cardRect.bottom + 0.5));
        });
      }
    }

    testWidgets('both lines scale together when the lockup is too wide',
        (tester) async {
      // One shared FittedBox: on a narrow screen the WIN line and CASH PRIZE
      // shrink by the SAME factor. Scaling only the big line (the old
      // structure) is what turned a tight lockup into an overlapping one.
      await tester.pumpWidget(_card(width: 390, prizeValue: 1000000));
      await tester.pump(const Duration(seconds: 1));
      final wide = tester.getRect(find.text('CASH PRIZE'));

      await tester.pumpWidget(_card(width: 320, prizeValue: 1000000));
      await tester.pump(const Duration(seconds: 1));
      final narrow = tester.getRect(find.text('CASH PRIZE'));

      expect(narrow.width, lessThan(wide.width),
          reason: 'the subline must scale down with the headline');
    });
  });

  group('non-cash lockup', () {
    testWidgets('"Win a \$500 Amazon Gift Card" wraps with real leading',
        (tester) async {
      await tester.pumpWidget(_card(
        width: 375,
        prizeValue: 500,
        prizeDescription: '\$500 Amazon Gift Card',
      ));
      await tester.pump(const Duration(seconds: 1));

      final headline = find.text('Win a \$500 Amazon Gift Card');
      expect(headline, findsOneWidget);
      // This one WRAPS to two lines inside a single Text, so its leading is
      // what keeps line 1's descenders off line 2's caps.
      expect(_lineHeightOf(tester, headline),
          greaterThanOrEqualTo(avafliV2HeadlineLineHeight));

      // The description already states the amount, so no value line.
      expect(find.text('\$500.00 VALUE!'), findsNothing);

      final cardRect = tester.getRect(find.byType(AvafliV2PrizeCard));
      expect(tester.getRect(headline).bottom,
          lessThanOrEqualTo(cardRect.bottom + 0.5));
    });

    testWidgets('value line sits below the headline without overlapping',
        (tester) async {
      await tester.pumpWidget(_card(
        width: 375,
        prizeValue: 500,
        prizeDescription: 'Nintendo Switch 2',
      ));
      await tester.pump(const Duration(seconds: 1));

      final headline = find.text('Win a Nintendo Switch 2');
      final value = find.text('\$500.00 VALUE!');
      expect(headline, findsOneWidget);
      expect(value, findsOneWidget);
      expect(tester.getRect(value).top,
          greaterThanOrEqualTo(tester.getRect(headline).bottom));
    });
  });
}
