import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// ── Minimal SVG path-data renderer ──
// Renders plain SVG `d` path strings (the export format of the Avafli Figma
// brand icons: fill-only paths, no strokes/arcs/transforms) without any
// third-party SVG dependency. Supports the M/L/H/V/C/S/Q/T/Z commands in
// absolute and relative form with implicit repetition — everything the brand
// set uses, plus the common shorthands. Elliptical arcs (A/a) are NOT
// supported; none of our assets use them.

/// Parses an SVG path-data string into a [Path].
///
/// Throws [FormatException] on an unsupported command so a bad asset fails
/// loudly in development rather than drawing garbage.
Path avafliParseSvgPathData(String d) {
  final tokens = RegExp(
    r'[A-DF-Za-df-z]|[+-]?(?:\d*\.\d+|\d+\.?)(?:[eE][+-]?\d+)?',
  ).allMatches(d).map((m) => m.group(0)!).toList();

  final path = Path();
  var i = 0;
  var cmd = '';
  double cx = 0, cy = 0; // Current point.
  double sx = 0, sy = 0; // Subpath start (for Z).
  double rcx = 0, rcy = 0; // Reflection point for S/T shorthands.
  var lastWasCubic = false, lastWasQuad = false;

  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    final t = tokens[i];
    if (t.length == 1 && RegExp(r'[A-Za-z]').hasMatch(t)) {
      cmd = t;
      i++;
      if (cmd == 'Z' || cmd == 'z') {
        path.close();
        cx = sx;
        cy = sy;
        lastWasCubic = lastWasQuad = false;
        continue;
      }
    } else {
      // Implicit repeat: extra coordinate pairs after M/m behave as L/l;
      // every other command simply repeats.
      if (cmd == 'M') cmd = 'L';
      if (cmd == 'm') cmd = 'l';
    }

    final rel = cmd.toLowerCase() == cmd;
    final dx = rel ? cx : 0.0;
    final dy = rel ? cy : 0.0;
    var cubic = false, quad = false;

    switch (cmd.toUpperCase()) {
      case 'M':
        cx = dx + next();
        cy = dy + next();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
      case 'L':
        cx = dx + next();
        cy = dy + next();
        path.lineTo(cx, cy);
      case 'H':
        cx = dx + next();
        path.lineTo(cx, cy);
      case 'V':
        cy = dy + next();
        path.lineTo(cx, cy);
      case 'C':
        final x1 = dx + next(), y1 = dy + next();
        final x2 = dx + next(), y2 = dy + next();
        cx = dx + next();
        cy = dy + next();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
        rcx = x2;
        rcy = y2;
        cubic = true;
      case 'S':
        final x1 = lastWasCubic ? 2 * cx - rcx : cx;
        final y1 = lastWasCubic ? 2 * cy - rcy : cy;
        final x2 = dx + next(), y2 = dy + next();
        cx = dx + next();
        cy = dy + next();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
        rcx = x2;
        rcy = y2;
        cubic = true;
      case 'Q':
        final x1 = dx + next(), y1 = dy + next();
        cx = dx + next();
        cy = dy + next();
        path.quadraticBezierTo(x1, y1, cx, cy);
        rcx = x1;
        rcy = y1;
        quad = true;
      case 'T':
        final x1 = lastWasQuad ? 2 * cx - rcx : cx;
        final y1 = lastWasQuad ? 2 * cy - rcy : cy;
        cx = dx + next();
        cy = dy + next();
        path.quadraticBezierTo(x1, y1, cx, cy);
        rcx = x1;
        rcy = y1;
        quad = true;
      default:
        throw FormatException('Unsupported SVG path command: $cmd');
    }
    lastWasCubic = cubic;
    lastWasQuad = quad;
  }
  return path;
}

/// Fills one or more SVG path-data strings (sharing one viewBox anchored at
/// the origin) in a single color, scaled to fit and centered in the widget's
/// size. Uses the SVG-default nonzero fill rule, which is what gives the
/// brand glyphs their cutouts.
class AvafliSvgIconPainter extends CustomPainter {
  const AvafliSvgIconPainter({
    required this.pathData,
    required this.color,
    this.viewBox = 48,
    double? viewBoxWidth,
    double? viewBoxHeight,
  })  : _viewBoxWidth = viewBoxWidth,
        _viewBoxHeight = viewBoxHeight;

  /// SVG `d` strings, all in the same viewBox coordinate space.
  final List<String> pathData;

  final Color color;

  /// Side of the square `0 0 n n` viewBox the path data was authored in.
  /// Used when [viewBoxWidth]/[viewBoxHeight] are not given (the social
  /// glyph set is square; the Avafli brand glyphs are not).
  final double viewBox;

  final double? _viewBoxWidth;
  final double? _viewBoxHeight;

  double get viewBoxWidth => _viewBoxWidth ?? viewBox;
  double get viewBoxHeight => _viewBoxHeight ?? viewBox;

  // Parsing is pure string→Path work, so cache per `d` string; the brand set
  // is a handful of constants and repaints shouldn't re-tokenize them.
  static final Map<String, Path> _cache = {};

  static Path _pathFor(String d) =>
      _cache.putIfAbsent(d, () => avafliParseSvgPathData(d));

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / viewBoxWidth,
      size.height / viewBoxHeight,
    );
    canvas.save();
    canvas.translate(
      (size.width - viewBoxWidth * scale) / 2,
      (size.height - viewBoxHeight * scale) / 2,
    );
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final d in pathData) {
      canvas.drawPath(_pathFor(d), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AvafliSvgIconPainter oldDelegate) =>
      oldDelegate.pathData != pathData ||
      oldDelegate.color != color ||
      oldDelegate.viewBoxWidth != viewBoxWidth ||
      oldDelegate.viewBoxHeight != viewBoxHeight;
}

// ── Avafli brand glyph set ──
// The exact vectors from the iOS SDK's AvafliV2Assets.xcassets (template
// rendering, preserves-vector): path data is verbatim from the asset SVGs —
// treat it as the source of truth and don't hand-edit. Where an asset bakes a
// fill-opacity into the SVG (mail 0.4, lock 0.5), iOS's template rendering
// keeps that alpha under the tint, so the glyph records it and
// [AvafliV2BrandIcon] applies it to the tint color — both platforms render
// the identical wash by construction.

/// One brand glyph: its `d` path strings and the exact viewBox they were
/// authored in, plus the asset's baked fill-opacity (see note above).
class AvafliV2BrandGlyph {
  const AvafliV2BrandGlyph({
    required this.paths,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    this.opacity = 1,
  });

  final List<String> paths;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final double opacity;
}

/// The Avafli brand glyphs (iOS `avafli-*` imagesets + `winner-plus`).
abstract final class AvafliV2BrandGlyphs {
  /// avafli-flame.svg (the asset repeats the identical path twice; once is
  /// enough under nonzero fill).
  static const flame = AvafliV2BrandGlyph(
    viewBoxWidth: 15.9963,
    viewBoxHeight: 20.5049,
    paths: [
      'M15.48 10.854C13.91 6.77405 8.32 6.55405 9.67 0.624047C9.77 '
          '0.184047 9.3 -0.155953 8.92 0.0740467C5.29 2.21405 2.68 6.50405 '
          '4.87 12.124C5.05 12.584 4.51 13.014 4.12 12.714C2.31 11.344 2.12 '
          '9.37405 2.28 7.96405C2.34 7.44405 1.66 7.19405 1.37 7.62405C0.69 '
          '8.66405 0 10.344 0 12.874C0.38 18.474 5.11 20.194 6.81 '
          '20.414C9.24 20.724 11.87 20.274 13.76 18.544C15.84 16.614 16.6 '
          '13.534 15.48 10.854ZM6.2 15.884C7.64 15.534 8.38 14.494 8.58 '
          '13.574C8.91 12.144 7.62 10.744 8.49 8.48405C8.82 10.354 11.76 '
          '11.524 11.76 13.564C11.84 16.094 9.1 18.264 6.2 15.884Z',
    ],
  );

  /// avafli-ticket.svg — the star-cutout entry ticket. Call sites apply the
  /// design's -25° rotation themselves (matching iOS's `.rotationEffect`).
  static const ticket = AvafliV2BrandGlyph(
    viewBoxWidth: 19.9,
    viewBoxHeight: 12.5,
    paths: [
      'M19.9 4.7V1.6C19.9 0.7 19.2 0 18.3 0H1.6C0.7 0 0 0.7 0 1.6V4.7C0.9 '
          '4.7 1.6 5.4 1.6 6.3C1.6 7.2 0.9 7.9 0 7.9V11C0 11.9 0.7 12.6 1.6 '
          '12.6H18.3C19.2 12.6 19.9 11.9 19.9 11V7.9C19 7.9 18.3 7.2 18.3 '
          '6.3C18.3 5.4 19 4.7 19.9 4.7ZM12.2 9.4L9.9 7.9L7.6 9.4L8.3 '
          '6.8L6.2 5.1L8.9 4.9L9.9 2.4L10.9 4.9L13.6 5.1L11.5 6.8L12.2 '
          '9.4Z',
    ],
  );

  /// avafli-calendar.svg.
  static const calendar = AvafliV2BrandGlyph(
    viewBoxWidth: 25.6142,
    viewBoxHeight: 28.1756,
    paths: [
      'M25.6142 2.56142H21.7721V0H19.2107V2.56142H6.40355V0H3.84213V2.56142H0'
          'V28.1756H25.6142V2.56142ZM23.0528 25.6142H2.56142V8.96498H23.0528'
          'V25.6142Z',
    ],
  );

  /// avafli-close.svg — the rounded-cap brand X.
  static const close = AvafliV2BrandGlyph(
    viewBoxWidth: 10.1884,
    viewBoxHeight: 10.1884,
    paths: [
      'M9.96239 0.23375C9.66102 -0.0676135 9.1742 -0.0676135 8.87284 '
          '0.23375L5.0942 4.00466L1.31557 0.226023C1.0142 -0.0753409 '
          '0.527386 -0.0753409 0.226023 0.226023C-0.0753409 0.527386 '
          '-0.0753409 1.0142 0.226023 1.31557L4.00466 5.0942L0.226023 '
          '8.87284C-0.0753409 9.1742 -0.0753409 9.66102 0.226023 '
          '9.96239C0.527386 10.2637 1.0142 10.2637 1.31557 9.96239L5.0942 '
          '6.18375L8.87284 9.96239C9.1742 10.2637 9.66102 10.2637 9.96239 '
          '9.96239C10.2637 9.66102 10.2637 9.1742 9.96239 8.87284L6.18375 '
          '5.0942L9.96239 1.31557C10.256 1.02193 10.256 0.527387 9.96239 '
          '0.23375V0.23375Z',
    ],
  );

  /// avafli-mail.svg (fill-opacity 0.4 baked into the asset — see the set's
  /// header note).
  static const mail = AvafliV2BrandGlyph(
    viewBoxWidth: 20,
    viewBoxHeight: 16,
    opacity: 0.4,
    paths: [
      'M18 0H2C0.9 0 0 0.9 0 2V14C0 15.1 0.9 16 2 16H18C19.1 16 20 15.1 20 '
          '14V2C20 0.9 19.1 0 18 0ZM17.6 4.25L11.06 8.34C10.41 8.75 9.59 '
          '8.75 8.94 8.34L2.4 4.25C2.15 4.09 2 3.82 2 3.53C2 2.86 2.73 2.46 '
          '3.3 2.81L10 7L16.7 2.81C17.27 2.46 18 2.86 18 3.53C18 3.82 17.85 '
          '4.09 17.6 4.25Z',
    ],
  );

  /// avafli-lock.svg (fill-opacity 0.5 baked into the asset).
  static const lock = AvafliV2BrandGlyph(
    viewBoxWidth: 16,
    viewBoxHeight: 21.0028,
    opacity: 0.5,
    paths: [
      'M16 7.00276H13V5.21276C13 2.60276 11.09 0.272764 8.49 '
          '0.0227641C5.51 -0.257236 3 2.08276 3 5.00276V7.00276H0V21.0028H16'
          'V7.00276ZM8 16.0028C6.9 16.0028 6 15.1028 6 14.0028C6 12.9028 '
          '6.9 12.0028 8 12.0028C9.1 12.0028 10 12.9028 10 14.0028C10 '
          '15.1028 9.1 16.0028 8 16.0028ZM5 7.00276V5.00276C5 3.34276 6.34 '
          '2.00276 8 2.00276C9.66 2.00276 11 3.34276 11 5.00276V7.00276H5Z',
    ],
  );

  /// avafli-arrow-down.svg — the "DAILY PROGRESS" pointer wedge.
  static const arrowDown = AvafliV2BrandGlyph(
    viewBoxWidth: 7.18049,
    viewBoxHeight: 4.5925,
    paths: [
      'M0.296477 1.71L2.88648 4.3C3.27648 4.69 3.90648 4.69 4.29648 '
          '4.3L6.88648 1.71C7.51648 1.08 7.06648 0 6.17648 0H0.996477C'
          '0.106477 0 -0.333523 1.08 0.296477 1.71Z',
    ],
  );

  /// FigmaAssets/winner-plus.svg — the winner banner's "+" in a circle.
  static const winnerPlus = AvafliV2BrandGlyph(
    viewBoxWidth: 18.5455,
    viewBoxHeight: 18.5455,
    paths: [
      'M16.152 9.27816C16.152 8.85196 15.8077 8.50773 15.3815 '
          '8.50773L10.0432 8.50227L10.0432 3.15847C10.0432 2.73228 9.69896 '
          '2.38804 9.27277 2.38804C8.84658 2.38804 8.50234 2.73228 8.50234 '
          '3.15847L8.50235 8.50227L3.15855 8.50227C2.73235 8.50227 2.38812 '
          '8.8465 2.38812 9.27269C2.38812 9.69888 2.73235 10.0431 3.15855 '
          '10.0431L8.50235 10.0431L8.50235 15.3869C8.50235 15.8131 8.84658 '
          '16.1573 9.27277 16.1573C9.69896 16.1573 10.0432 15.8131 10.0432 '
          '15.3869L10.0432 10.0431L15.387 10.0431C15.8023 10.0431 16.152 '
          '9.69342 16.152 9.27816V9.27816Z',
    ],
  );
}

/// Renders one [AvafliV2BrandGlyph] at an explicit size in a tint color —
/// the Flutter counterpart of iOS's
/// `Image("avafli-…").resizable().scaledToFit().foregroundColor(…)`.
class AvafliV2BrandIcon extends StatelessWidget {
  const AvafliV2BrandIcon(
    this.glyph, {
    super.key,
    required this.width,
    required this.height,
    required this.color,
  });

  final AvafliV2BrandGlyph glyph;
  final double width;
  final double height;

  /// Tint color; the glyph's baked [AvafliV2BrandGlyph.opacity] is multiplied
  /// in, matching iOS template rendering.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tint = glyph.opacity >= 1
        ? color
        : color.withValues(alpha: color.a * glyph.opacity);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: AvafliSvgIconPainter(
          pathData: glyph.paths,
          color: tint,
          viewBoxWidth: glyph.viewBoxWidth,
          viewBoxHeight: glyph.viewBoxHeight,
        ),
      ),
    );
  }
}
