// Motion for the V2 experience, matched to the Figma prototype GIFs:
// confetti fields/bursts, the draw-on white checkmark, and the pulsing glow on
// the active streak tile. Everything is drawn natively (no GIFs) so it stays
// crisp at any scale and respects the publisher accent.
//
// Mirrors the iOS SDK's WINRV2Effects.swift — the confetti particle math is a
// 1:1 port so both platforms animate identically.

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Confetti
// ---------------------------------------------------------------------------

/// Confetti palette styles: [celebration] is the multicolor sprinkle from the
/// claim/celebration modals and streak tiles; [gold] is the winner-modal gold
/// sparkle.
enum WINRV2ConfettiStyle { celebration, gold }

/// A looping confetti field (1:1 port of iOS `WINRV2ConfettiView`).
class WINRV2Confetti extends StatefulWidget {
  final WINRV2ConfettiStyle style;
  final int count;
  final double speed;

  const WINRV2Confetti({
    super.key,
    this.style = WINRV2ConfettiStyle.celebration,
    this.count = 42,
    this.speed = 1,
  });

  @override
  State<WINRV2Confetti> createState() => _WINRV2ConfettiState();
}

class _WINRV2ConfettiState extends State<WINRV2Confetti>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Wall-clock base so multiple confetti fields share the same global phase
  /// (like iOS's timeIntervalSinceReferenceDate).
  final double _epochBase =
      DateTime.now().millisecondsSinceEpoch.toDouble() / 1000.0;

  double _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed.inMicroseconds / 1e6);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(
          t: (_epochBase + _elapsed) * widget.speed,
          style: widget.style,
          count: widget.count,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final WINRV2ConfettiStyle style;
  final int count;

  _ConfettiPainter({required this.t, required this.style, required this.count});

  static const List<Color> _celebrationPalette = [
    Color.fromRGBO(245, 79, 71, 1), // red
    Color.fromRGBO(89, 199, 107, 1), // green
    Color.fromRGBO(77, 158, 252, 1), // blue
    Color.fromRGBO(252, 204, 71, 1), // yellow
    Color.fromRGBO(184, 133, 245, 1), // purple
  ];
  static const List<Color> _goldPalette = [
    Color.fromRGBO(255, 214, 89, 1),
    Color.fromRGBO(240, 179, 46, 1),
    Color.fromRGBO(255, 237, 168, 1),
  ];

  static double _fract(double v) => v - v.floorToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final palette = style == WINRV2ConfettiStyle.celebration
        ? _celebrationPalette
        : _goldPalette;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      // Deterministic per-particle parameters (no random — stable across
      // frames). Identical constants to the iOS implementation.
      final seed = i.toDouble();
      final fx = _fract(seed * 0.61803398875); // 0..1 x anchor
      final fall = 8.0 + _fract(seed * 0.7548776662) * 7.0; // fall period s
      final phase = _fract(seed * 0.2928932188);
      final progress = _fract(t / fall + phase); // 0..1 down screen
      final sway = math.sin((t * 1.7) + seed * 1.3) * 9.0;
      final x = fx * size.width + sway;
      final y = progress * (size.height + 24) - 12;
      final rotation = t * 2.1 + seed;
      final w = 4.0 + _fract(seed * 0.833) * 4.0;
      final h = w * (0.55 + _fract(seed * 0.377) * 0.5);
      final alpha = style == WINRV2ConfettiStyle.gold
          ? 0.55 + _fract(seed * 0.51) * 0.45
          : 0.9;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      // Flutter: squash on one axis as the piece "tumbles".
      final squash = 0.35 + math.sin(t * 2.6 + seed * 2.0).abs() * 0.65;
      canvas.scale(1, squash);
      paint.color = palette[i % palette.length].withValues(alpha: alpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.style != style ||
      oldDelegate.count != count;
}

// ---------------------------------------------------------------------------
// Animated checkmark (draw-on)
// ---------------------------------------------------------------------------

/// The white circle-check from the modals: the circle sweeps in, then the
/// check strokes on (1:1 port of iOS `WINRV2AnimatedCheckmark`).
///
/// Set [animated] to false to render the fully-drawn glyph (used for the
/// completed streak-tile icon).
class WINRV2AnimatedCheckmark extends StatefulWidget {
  final double lineWidth;
  final bool animated;

  const WINRV2AnimatedCheckmark({
    super.key,
    this.lineWidth = 7,
    this.animated = true,
  });

  @override
  State<WINRV2AnimatedCheckmark> createState() =>
      _WINRV2AnimatedCheckmarkState();
}

class _WINRV2AnimatedCheckmarkState extends State<WINRV2AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circle;
  late final Animation<double> _check;

  @override
  void initState() {
    super.initState();
    // iOS: circle 0.5s easeInOut, check 0.35s easeOut delayed 0.4s.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _circle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 500 / 750, curve: Curves.easeInOut),
    );
    _check = CurvedAnimation(
      parent: _controller,
      curve: const Interval(400 / 750, 1.0, curve: Curves.easeOut),
    );
    if (widget.animated) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _CheckmarkPainter(
          circleProgress: _circle.value,
          checkProgress: _check.value,
          lineWidth: widget.lineWidth,
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final double lineWidth;

  _CheckmarkPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Circle sweep, starting at 12 o'clock.
    if (circleProgress > 0) {
      final rect = Rect.fromLTWH(
        lineWidth / 2,
        lineWidth / 2,
        size.width - lineWidth,
        size.height - lineWidth,
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * circleProgress,
        false,
        paint,
      );
    }

    // Check glyph: starts left-center, dips to the low point, kicks up past
    // the circle's top-right edge (same control points as iOS CheckShape).
    if (checkProgress > 0) {
      final path = Path()
        ..moveTo(size.width * 0.26, size.height * 0.54)
        ..lineTo(size.width * 0.45, size.height * 0.72)
        ..lineTo(size.width * 0.94, size.height * 0.22);
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * checkProgress),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.circleProgress != circleProgress ||
      oldDelegate.checkProgress != checkProgress ||
      oldDelegate.lineWidth != lineWidth;
}

// ---------------------------------------------------------------------------
// Pulsing glow (active streak tile)
// ---------------------------------------------------------------------------

/// The active-tile treatment: the accent glow breathes (port of iOS
/// `WINRV2PulseGlow`, shadow radius 7→14 / opacity 0.55→0.95, 1.1s
/// autoreversing).
class WINRV2PulseGlow extends StatefulWidget {
  final Color accent;
  final BorderRadius borderRadius;
  final Widget child;

  const WINRV2PulseGlow({
    super.key,
    required this.accent,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  State<WINRV2PulseGlow> createState() => _WINRV2PulseGlowState();
}

class _WINRV2PulseGlowState extends State<WINRV2PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final v = Curves.easeInOut.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.55 + 0.40 * v),
                blurRadius: 7 + 7 * v,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
