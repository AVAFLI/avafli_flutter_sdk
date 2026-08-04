// Motion for the V2 experience: Joe's ACTUAL Figma animation files (bundled
// GIFs, played via [WINRV2GifView]) for the Day 2+ reveal beat, plus natively
// drawn confetti/checkmark/glow used by the modals and toast bar.
//
// Mirrors the iOS SDK's WINRV2Effects.swift — the confetti particle math is a
// 1:1 port so both platforms animate identically.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'winr_v2_theme.dart';

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
// Bundled GIF playback (Joe's Figma animation files)
// ---------------------------------------------------------------------------

/// A decoded GIF: frames plus the per-frame start times from the file's own
/// delay table (port of iOS `WINRV2GifAsset`, built on Flutter's multi-frame
/// `ui.Codec`). Decoding takes long enough to miss a beat, so decoded assets
/// are cached in memory (keyed by asset name) and prewarmed at drawer-open,
/// BEFORE the reveal beat needs them.
class WINRV2GifAsset {
  final List<ui.Image> frames;

  /// Cumulative start time (seconds) of each frame.
  final List<double> starts;
  final double duration;

  WINRV2GifAsset._(this.frames, this.starts, this.duration);

  /// Frame for [time] seconds into playback. Past the end: the LAST frame
  /// (one-shot playback stops there) unless [loops].
  ui.Image frameAt(double time, {bool loops = false}) {
    var t = time;
    if (loops && duration > 0) t = t % duration;
    if (t >= duration) return frames.last;
    var index = 0;
    for (var i = 0; i < starts.length; i++) {
      if (starts[i] <= t) index = i;
    }
    return frames[index];
  }

  // Cache ---------------------------------------------------------------

  static final Map<String, Future<WINRV2GifAsset>> _loads = {};
  static final Map<String, WINRV2GifAsset> _cache = {};

  /// Synchronous cache hit — non-null once a [load]/[prewarm] has finished,
  /// so a reveal-beat mount can paint frame 0 on its very first build.
  static WINRV2GifAsset? cached(String name) => _cache[name];

  /// Decode into the cache ahead of time so a later mount plays instantly.
  static void prewarm(String name) {
    // Errors are swallowed here; a mount retries via [load].
    load(name).then((_) {}, onError: (Object _, StackTrace __) {});
  }

  /// Cached load; kicks off (or joins) the decode on a miss.
  static Future<WINRV2GifAsset> load(String name) {
    return _loads.putIfAbsent(name, () async {
      try {
        final asset = await _decode(name);
        _cache[name] = asset;
        return asset;
      } catch (_) {
        _loads.remove(name); // Allow a retry after a failed decode.
        rethrow;
      }
    });
  }

  static Future<WINRV2GifAsset> _decode(String name) async {
    ByteData data;
    try {
      // Host apps see this package's assets under the packages/ prefix…
      data = await rootBundle.load('packages/${WINRV2Assets.package}/$name');
    } catch (_) {
      // …while the SDK's own tests/tooling see the raw key.
      data = await rootBundle.load(name);
    }
    // Downsample cap like iOS (maxPixelSize 600) — these overlays only ever
    // render at ~200 logical px, so full-size frames would be dead weight.
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 600,
      allowUpscaling: false,
    );
    final frames = <ui.Image>[];
    final starts = <double>[];
    var t = 0.0;
    for (var i = 0; i < codec.frameCount; i++) {
      final frame = await codec.getNextFrame();
      frames.add(frame.image);
      starts.add(t);
      // Honor the file's own delay table; floor pathological 0-delay frames
      // (same 20ms floor as iOS).
      t += math.max(frame.duration.inMicroseconds / 1e6, 0.02);
    }
    codec.dispose();
    if (frames.isEmpty) {
      throw StateError('WINRV2GifAsset: $name decoded no frames');
    }
    return WINRV2GifAsset._(frames, starts, t);
  }
}

/// Plays a bundled GIF ONCE, starting exactly when the widget mounts,
/// honoring the file's own per-frame delays (port of iOS `WINRV2GifView`).
/// When the last frame's delay elapses the ticker stops there and
/// [onFinished] fires — the host removes the widget. [loops] opts into
/// continuous looping instead.
class WINRV2GifView extends StatefulWidget {
  final String name;
  final bool loops;
  final VoidCallback? onFinished;

  const WINRV2GifView(
    this.name, {
    super.key,
    this.loops = false,
    this.onFinished,
  });

  @override
  State<WINRV2GifView> createState() => _WINRV2GifViewState();
}

class _WINRV2GifViewState extends State<WINRV2GifView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  WINRV2GifAsset? _asset;
  double _elapsed = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Mount IS the beat: the playback clock starts NOW, even if the frames
    // are still decoding (prewarming makes that a non-event) — a slow decode
    // skips ahead to the right frame rather than stretching the beat.
    _ticker = createTicker(_tick)..start();
    final hit = WINRV2GifAsset.cached(widget.name);
    if (hit != null) {
      _asset = hit;
    } else {
      WINRV2GifAsset.load(widget.name).then((asset) {
        if (!mounted || _asset != null || _finished) return;
        setState(() => _asset = asset);
      }, onError: (Object _, StackTrace __) {
        // Undecodable asset: finish immediately so a one-shot overlay still
        // cleans itself up instead of sitting invisible forever.
        if (!mounted || _finished) return;
        _ticker.stop();
        setState(() => _finished = true);
        widget.onFinished?.call();
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    final asset = _asset;
    if (asset != null && !widget.loops && t >= asset.duration) {
      // Deterministic end of playback: the codec's own delay table says the
      // last frame is over. Stop on it and tell the host.
      _ticker.stop();
      setState(() {
        _elapsed = asset.duration;
        _finished = true;
      });
      widget.onFinished?.call();
      return;
    }
    setState(() => _elapsed = t);
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    if (asset == null) return const SizedBox.expand();
    return RawImage(
      image: asset.frameAt(_elapsed, loops: widget.loops),
      fit: BoxFit.contain,
    );
  }
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
