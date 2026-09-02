// Smoke coverage for the Avafli brand glyph set (iOS-parity vectors):
// every glyph's path data parses with the in-repo SVG path renderer, the
// baked fill-opacities match the iOS assets, and the widgets that replaced
// the Material stand-ins actually render the brand vectors.

import 'package:avafli_sdk/src/ui/v2/avafli_v2_components.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_svg_icon.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const glyphs = <String, AvafliV2BrandGlyph>{
    'flame': AvafliV2BrandGlyphs.flame,
    'ticket': AvafliV2BrandGlyphs.ticket,
    'calendar': AvafliV2BrandGlyphs.calendar,
    'close': AvafliV2BrandGlyphs.close,
    'mail': AvafliV2BrandGlyphs.mail,
    'lock': AvafliV2BrandGlyphs.lock,
    'arrowDown': AvafliV2BrandGlyphs.arrowDown,
    'winnerPlus': AvafliV2BrandGlyphs.winnerPlus,
  };

  group('brand glyph path data', () {
    for (final entry in glyphs.entries) {
      test('${entry.key} parses and stays inside its viewBox', () {
        final glyph = entry.value;
        for (final d in glyph.paths) {
          final path = avafliParseSvgPathData(d); // throws on a bad command
          final bounds = path.getBounds();
          // The vector must actually draw something…
          expect(bounds.isEmpty, isFalse);
          // …and fit its declared viewBox (small tolerance for curve
          // control-point overshoot in the exports).
          expect(bounds.left, greaterThanOrEqualTo(-1));
          expect(bounds.top, greaterThanOrEqualTo(-1));
          expect(bounds.right, lessThanOrEqualTo(glyph.viewBoxWidth + 1));
          expect(bounds.bottom, lessThanOrEqualTo(glyph.viewBoxHeight + 1));
        }
      });
    }

    test('baked fill-opacities match the iOS assets', () {
      // avafli-mail.svg carries fill-opacity 0.4, avafli-lock.svg 0.5 —
      // iOS's template rendering keeps those under the tint, so the Flutter
      // glyphs must too.
      expect(AvafliV2BrandGlyphs.mail.opacity, 0.4);
      expect(AvafliV2BrandGlyphs.lock.opacity, 0.5);
      for (final entry in glyphs.entries) {
        if (entry.key == 'mail' || entry.key == 'lock') continue;
        expect(entry.value.opacity, 1, reason: entry.key);
      }
    });
  });

  testWidgets('AvafliV2BrandIcon renders at its given size with the tint',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final glyph in glyphs.values)
              AvafliV2BrandIcon(
                glyph,
                width: 24,
                height: 24,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
    expect(find.byType(AvafliV2BrandIcon), findsNWidgets(glyphs.length));
    expect(tester.takeException(), isNull);

    // The baked opacity multiplies into the paint tint.
    final mailPaint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is AvafliV2BrandIcon && w.glyph == AvafliV2BrandGlyphs.mail,
        ),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = mailPaint.painter! as AvafliSvgIconPainter;
    expect(painter.color.a, closeTo(0.4, 0.01));
  });

  testWidgets('dashboard components carry the brand glyphs, not Material',
      (tester) async {
    final accent = AvafliV2Accent(null).color;
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Column(
            children: [
              AvafliV2Header(
                logoUrl: null,
                onInfo: () {},
                onClose: () {},
              ),
              AvafliV2PrizeCard(
                accent: accent,
                streakDay: 3,
                totalEntries: 120,
                prizeImageUrl: null,
                prizeValue: 1000,
                prizeDescription: '',
              ),
              AvafliV2StreakTile(
                accent: accent,
                day: 5,
                entries: 50,
                state: AvafliV2TileState.locked,
              ),
              AvafliV2ComeBackBar(accent: accent, nextEntries: 25),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    AvafliV2BrandGlyph glyphOf(Widget w) => (w as AvafliV2BrandIcon).glyph;
    final rendered =
        tester.widgetList(find.byType(AvafliV2BrandIcon)).map(glyphOf).toSet();
    expect(rendered.contains(AvafliV2BrandGlyphs.close), isTrue);
    expect(rendered.contains(AvafliV2BrandGlyphs.flame), isTrue);
    expect(rendered.contains(AvafliV2BrandGlyphs.ticket), isTrue);
    expect(rendered.contains(AvafliV2BrandGlyphs.lock), isTrue);
    expect(rendered.contains(AvafliV2BrandGlyphs.calendar), isTrue);

    // The Material stand-ins these replaced are gone.
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
    expect(find.byIcon(Icons.confirmation_number), findsNothing);
    expect(find.byIcon(Icons.calendar_today), findsNothing);

    // The header wordmark fallback is title-case (iOS parity).
    expect(find.text('Avafli'), findsOneWidget);
    expect(find.text('AVAFLI'), findsNothing);
  });
}
