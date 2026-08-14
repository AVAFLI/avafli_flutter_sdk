import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// ── Minimal SVG path-data renderer ──
// Renders plain SVG `d` path strings (the export format of the WINR Figma
// brand icons: fill-only paths, no strokes/arcs/transforms) without any
// third-party SVG dependency. Supports the M/L/H/V/C/S/Q/T/Z commands in
// absolute and relative form with implicit repetition — everything the brand
// set uses, plus the common shorthands. Elliptical arcs (A/a) are NOT
// supported; none of our assets use them.

/// Parses an SVG path-data string into a [Path].
///
/// Throws [FormatException] on an unsupported command so a bad asset fails
/// loudly in development rather than drawing garbage.
Path winrParseSvgPathData(String d) {
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

/// Fills one or more SVG path-data strings (sharing one `viewBox` of
/// `0 0 viewBox viewBox`) in a single color, scaled to fit and centered in
/// the widget's size. Uses the SVG-default nonzero fill rule, which is what
/// gives the brand glyphs their cutouts.
class WINRSvgIconPainter extends CustomPainter {
  const WINRSvgIconPainter({
    required this.pathData,
    required this.color,
    this.viewBox = 48,
  });

  /// SVG `d` strings, all in the same [viewBox] coordinate space.
  final List<String> pathData;

  final Color color;

  /// Side of the square `0 0 n n` viewBox the path data was authored in.
  final double viewBox;

  // Parsing is pure string→Path work, so cache per `d` string; the brand set
  // is a handful of constants and repaints shouldn't re-tokenize them.
  static final Map<String, Path> _cache = {};

  static Path _pathFor(String d) =>
      _cache.putIfAbsent(d, () => winrParseSvgPathData(d));

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / viewBox;
    canvas.save();
    canvas.translate(
      (size.width - viewBox * scale) / 2,
      (size.height - viewBox * scale) / 2,
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
  bool shouldRepaint(covariant WINRSvgIconPainter oldDelegate) =>
      oldDelegate.pathData != pathData ||
      oldDelegate.color != color ||
      oldDelegate.viewBox != viewBox;
}
