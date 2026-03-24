import 'package:flutter/material.dart';
import '../winr_branding.dart';

// ---------------------------------------------------------------------------
// SHIMMER EFFECT — animated gradient sweep for skeleton placeholders
// ---------------------------------------------------------------------------

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final Color highlightColor;

  _ShimmerPainter({
    required this.progress,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shimmerWidth = size.width * 0.4;
    final dx = -shimmerWidth + (size.width + shimmerWidth * 2) * progress;

    final gradient = LinearGradient(
      colors: [baseColor, highlightColor, baseColor],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Rect.fromLTWH(dx, 0, shimmerWidth, size.height);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.srcATop;

    canvas.drawRect(Offset.zero & size, Paint()..color = baseColor);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) =>
      old.progress != progress;
}

class WINRShimmer extends StatefulWidget {
  final WINRBranding branding;
  final Widget child;

  const WINRShimmer({
    super.key,
    required this.branding,
    required this.child,
  });

  @override
  State<WINRShimmer> createState() => _WINRShimmerState();
}

class _WINRShimmerState extends State<WINRShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.branding.cardBackgroundColor.withValues(alpha: 0.6);
    final highlight =
        widget.branding.accentGlowColor.withValues(alpha: 0.08);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _ShimmerPainter(
            progress: _controller.value,
            baseColor: base,
            highlightColor: highlight,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// SKELETON BONE — a single rounded placeholder rectangle
// ---------------------------------------------------------------------------

class _SkeletonBone extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color color;

  const _SkeletonBone({
    required this.width,
    required this.height,
    this.borderRadius = 8,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STREAK DASHBOARD SKELETON
// ---------------------------------------------------------------------------

class StreakDashboardSkeleton extends StatelessWidget {
  final WINRBranding branding;

  const StreakDashboardSkeleton({super.key, required this.branding});

  @override
  Widget build(BuildContext context) {
    final bone = branding.cardBackgroundColor.withValues(alpha: 0.5);

    return WINRShimmer(
      branding: branding,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Hero placeholder
            _SkeletonBone(
              width: double.infinity,
              height: 160,
              borderRadius: 16,
              color: bone,
            ),
            const SizedBox(height: 22),

            // Prize text lines
            Center(
              child: _SkeletonBone(width: 260, height: 22, color: bone),
            ),
            const SizedBox(height: 8),
            Center(
              child: _SkeletonBone(width: 220, height: 12, color: bone),
            ),
            const SizedBox(height: 20),

            // Grid: 2 rows × 4 tiles
            for (int row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 10),
              Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : 5,
                        right: i == 3 ? 0 : 5,
                      ),
                      child: _SkeletonBone(
                        width: double.infinity,
                        height: 100,
                        borderRadius: branding.cornerRadius,
                        color: bone,
                      ),
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: 30),

            // Footer pill
            Center(
              child: _SkeletonBone(
                width: 180,
                height: 14,
                color: bone,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: _SkeletonBone(
                width: 140,
                height: 30,
                borderRadius: 20,
                color: bone,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: _SkeletonBone(
                width: 240,
                height: 12,
                color: bone,
              ),
            ),
            const SizedBox(height: 14),

            // CTA button
            _SkeletonBone(
              width: double.infinity,
              height: 50,
              borderRadius: branding.cornerRadius,
              color: bone,
            ),
            const SizedBox(height: 14),

            // Legal links
            Center(
              child: _SkeletonBone(width: 200, height: 10, color: bone),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EMAIL CAPTURE SKELETON
// ---------------------------------------------------------------------------

class EmailCaptureSkeleton extends StatelessWidget {
  final WINRBranding branding;

  const EmailCaptureSkeleton({super.key, required this.branding});

  @override
  Widget build(BuildContext context) {
    final bone = branding.cardBackgroundColor.withValues(alpha: 0.5);

    return WINRShimmer(
      branding: branding,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Logo placeholder
            Center(
              child: _SkeletonBone(
                width: 130,
                height: 72,
                borderRadius: 12,
                color: bone,
              ),
            ),
            const SizedBox(height: 40),

            // Title
            Center(
              child: _SkeletonBone(width: 240, height: 24, color: bone),
            ),
            const SizedBox(height: 12),

            // Subtitle
            Center(
              child: _SkeletonBone(width: 280, height: 14, color: bone),
            ),
            const SizedBox(height: 6),
            Center(
              child: _SkeletonBone(width: 200, height: 14, color: bone),
            ),
            const SizedBox(height: 24),

            // Email label
            Align(
              alignment: Alignment.centerLeft,
              child: _SkeletonBone(width: 50, height: 12, color: bone),
            ),
            const SizedBox(height: 8),

            // Email field
            _SkeletonBone(
              width: double.infinity,
              height: 52,
              borderRadius: 16,
              color: bone,
            ),
            const SizedBox(height: 22),

            // Checkbox rows
            for (int i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              Row(
                children: [
                  _SkeletonBone(
                    width: 20,
                    height: 20,
                    borderRadius: 4,
                    color: bone,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SkeletonBone(
                      width: double.infinity,
                      height: 14,
                      color: bone,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 26),

            // CTA button
            _SkeletonBone(
              width: double.infinity,
              height: 50,
              borderRadius: 22,
              color: bone,
            ),
            const SizedBox(height: 16),

            // Legal text
            Center(
              child: _SkeletonBone(width: 260, height: 10, color: bone),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BONUS ENTRIES SKELETON
// ---------------------------------------------------------------------------

class BonusEntriesSkeleton extends StatelessWidget {
  final WINRBranding branding;

  const BonusEntriesSkeleton({super.key, required this.branding});

  @override
  Widget build(BuildContext context) {
    final bone = branding.cardBackgroundColor.withValues(alpha: 0.5);

    return WINRShimmer(
      branding: branding,
      child: Padding(
        padding: const EdgeInsets.only(top: 50, left: 24, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title
            Center(
              child: _SkeletonBone(width: 200, height: 26, color: bone),
            ),
            const SizedBox(height: 24),

            // Description lines
            Center(
              child: _SkeletonBone(width: 280, height: 14, color: bone),
            ),
            const SizedBox(height: 8),
            Center(
              child: _SkeletonBone(width: 220, height: 14, color: bone),
            ),
            const SizedBox(height: 26),

            // Watch & Claim button
            _SkeletonBone(
              width: double.infinity,
              height: 52,
              borderRadius: branding.cornerRadius,
              color: bone,
            ),
            const SizedBox(height: 24),

            // Skip text
            Center(
              child: _SkeletonBone(width: 240, height: 12, color: bone),
            ),
          ],
        ),
      ),
    );
  }
}
