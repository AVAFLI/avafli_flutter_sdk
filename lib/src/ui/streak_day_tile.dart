import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../winr_branding.dart';

/// Standalone streak day tile (130×160) — matches iOS StreakDayTile.swift.
class StreakDayTile extends StatefulWidget {
  final int dayNumber;
  final int entries;
  final bool isClaimed;
  final bool isToday;
  final WINRBranding branding;
  final VoidCallback? onTap;

  const StreakDayTile({
    super.key,
    required this.dayNumber,
    required this.entries,
    required this.isClaimed,
    required this.isToday,
    required this.branding,
    this.onTap,
  });

  @override
  State<StreakDayTile> createState() => _StreakDayTileState();
}

class _StreakDayTileState extends State<StreakDayTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isToday) {
      _pulseController.repeat(reverse: false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  WINRBranding get b => widget.branding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap?.call();
      },
      child: Transform.scale(
        scale: widget.isToday ? 1.08 : 0.96,
        child: Container(
          width: 130,
          height: 160,
          decoration: BoxDecoration(
            gradient: _tileGradient,
            borderRadius: BorderRadius.circular(b.cornerRadius + 4),
            border: Border.all(
              color: _borderColor,
              width: widget.isToday ? 2.5 : 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: _shadowColor,
                blurRadius: _shadowRadius,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Day pill
                _buildDayPill(),
                // Entries count
                Text(
                  '${widget.entries}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: _entriesTextColor,
                  ),
                ),
                // Entries label
                Text(
                  'Entries',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _entriesLabelColor,
                  ),
                ),
                // Status icon
                _buildStatusIcon(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayPill() {
    return AnimatedBuilder(
      animation: widget.isToday ? _pulseAnimation : kAlwaysCompleteAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: _pillBackground,
            borderRadius: BorderRadius.circular(20),
            border: widget.isToday
                ? Border.all(color: b.accentGlowColor, width: 2)
                : null,
            boxShadow: widget.isToday
                ? [
                    BoxShadow(
                      color: b.accentGlowColor.withValues(
                          alpha: 0.5 *
                              (widget.isToday
                                  ? _pulseAnimation.value
                                  : 1.0)),
                      blurRadius:
                          8 * (widget.isToday ? _pulseAnimation.value : 1.0),
                      spreadRadius:
                          2 * (widget.isToday ? _pulseAnimation.value : 1.0),
                    ),
                  ]
                : null,
          ),
          child: Text(
            'DAY ${widget.dayNumber}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _pillTextColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon() {
    final size = widget.isToday ? 22.0 : 20.0;
    if (widget.isToday) {
      return Icon(
        Icons.local_fire_department,
        size: size,
        color: b.accentGlowColor,
        shadows: [Shadow(color: b.accentGlowColor, blurRadius: 10)],
      );
    } else if (widget.isClaimed) {
      return Icon(Icons.verified, size: size, color: b.primaryColor);
    } else {
      return Icon(
        Icons.lock,
        size: size,
        color: b.mutedTextColor.withValues(alpha: 0.7),
      );
    }
  }

  // -- Visual states --

  LinearGradient get _tileGradient {
    if (widget.isToday) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          b.primaryButtonColor,
          b.cardBackgroundColor.withValues(alpha: 0.9),
        ],
      );
    } else if (widget.isClaimed) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          b.primaryColor.withValues(alpha: 0.25),
          b.cardBackgroundColor.withValues(alpha: 0.95),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          b.cardBackgroundColor.withValues(alpha: 0.5),
          b.cardBackgroundColor.withValues(alpha: 0.35),
        ],
      );
    }
  }

  Color get _borderColor {
    if (widget.isToday) return b.accentGlowColor;
    if (widget.isClaimed) return b.primaryColor.withValues(alpha: 0.7);
    return Colors.white.withValues(alpha: 0.18);
  }

  Color get _shadowColor {
    if (widget.isToday) return b.accentGlowColor.withValues(alpha: 0.7);
    if (widget.isClaimed) return b.primaryColor.withValues(alpha: 0.4);
    return Colors.black.withValues(alpha: 0.35);
  }

  double get _shadowRadius {
    if (widget.isToday) return 8;
    if (widget.isClaimed) return 4;
    return 0;
  }

  Color get _entriesTextColor {
    if (widget.isToday) return Colors.white;
    if (widget.isClaimed) return b.primaryColor;
    return b.mutedTextColor.withValues(alpha: 0.9);
  }

  Color get _entriesLabelColor {
    if (widget.isToday) return Colors.white.withValues(alpha: 0.9);
    if (widget.isClaimed) return b.primaryColor.withValues(alpha: 0.85);
    return b.mutedTextColor.withValues(alpha: 0.7);
  }

  Color get _pillBackground {
    if (widget.isToday) return b.cardBackgroundColor.withValues(alpha: 0.95);
    if (widget.isClaimed) return b.primaryColor.withValues(alpha: 0.4);
    return b.cardBackgroundColor.withValues(alpha: 0.9);
  }

  Color get _pillTextColor {
    if (widget.isToday) return b.primaryButtonTextColor;
    return b.secondaryTextColor;
  }
}

/// Compact streak tile (90×115) used inside StreakDashboardView — matches iOS CompactStreakTile.
class CompactStreakTile extends StatefulWidget {
  final int dayNumber;
  final int entries;
  final bool isClaimed;
  final bool isToday;
  final WINRBranding branding;

  const CompactStreakTile({
    super.key,
    required this.dayNumber,
    required this.entries,
    required this.isClaimed,
    required this.isToday,
    required this.branding,
  });

  @override
  State<CompactStreakTile> createState() => _CompactStreakTileState();
}

class _CompactStreakTileState extends State<CompactStreakTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    if (widget.isToday) {
      _pulseController.repeat(reverse: false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  WINRBranding get b => widget.branding;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: widget.isToday ? 1.05 : 1.0,
      child: Container(
        width: 90,
        height: 115,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          gradient: _tileBg,
          borderRadius: BorderRadius.circular(b.cornerRadius),
          border: Border.all(
            color: _borderColor,
            width: widget.isToday ? 2 : 1,
          ),
          boxShadow: widget.isToday
              ? [
                  BoxShadow(
                    color: b.accentGlowColor.withValues(alpha: 0.7),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Day pill
            _buildDayPill(),
            // Entries count
            Text(
              '${widget.entries}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textColor,
              ),
            ),
            // Entries label
            Text(
              'Entries',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _labelColor,
              ),
            ),
            // Status icon
            _buildStatusIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPill() {
    return AnimatedBuilder(
      animation: widget.isToday ? _pulseController : kAlwaysCompleteAnimation,
      builder: (context, child) {
        final pulseVal = widget.isToday
            ? Tween<double>(begin: 1.0, end: 1.12)
                .evaluate(CurvedAnimation(
                    parent: _pulseController, curve: Curves.easeInOut))
            : 1.0;
        final pulseOpacity = widget.isToday
            ? Tween<double>(begin: 1.0, end: 0.4)
                .evaluate(CurvedAnimation(
                    parent: _pulseController, curve: Curves.easeInOut))
            : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _pillBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                'DAY ${widget.dayNumber}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: widget.isToday
                      ? b.primaryButtonTextColor
                      : b.secondaryTextColor,
                ),
              ),
              if (widget.isToday)
                Positioned.fill(
                  child: Transform.scale(
                    scale: pulseVal,
                    child: Opacity(
                      opacity: pulseOpacity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: b.accentGlowColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon() {
    const size = 16.0;
    if (widget.isToday) {
      return Icon(
        Icons.local_fire_department,
        size: size,
        color: b.accentGlowColor,
        shadows: [Shadow(color: b.accentGlowColor, blurRadius: 6)],
      );
    } else if (widget.isClaimed) {
      return Icon(Icons.verified, size: size, color: b.primaryColor);
    } else {
      return Icon(
        Icons.lock,
        size: size,
        color: b.mutedTextColor.withValues(alpha: 0.6),
      );
    }
  }

  LinearGradient get _tileBg {
    if (widget.isToday) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          b.primaryButtonColor,
          b.cardBackgroundColor.withValues(alpha: 0.9),
        ],
      );
    } else if (widget.isClaimed) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          b.primaryColor.withValues(alpha: 0.2),
          b.cardBackgroundColor.withValues(alpha: 0.9),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          b.cardBackgroundColor.withValues(alpha: 0.45),
          b.cardBackgroundColor.withValues(alpha: 0.3),
        ],
      );
    }
  }

  Color get _pillBg {
    if (widget.isToday) return b.cardBackgroundColor.withValues(alpha: 0.95);
    if (widget.isClaimed) return b.primaryColor.withValues(alpha: 0.35);
    return b.cardBackgroundColor.withValues(alpha: 0.85);
  }

  Color get _borderColor {
    if (widget.isToday) return b.accentGlowColor;
    if (widget.isClaimed) return b.primaryColor.withValues(alpha: 0.6);
    return Colors.white.withValues(alpha: 0.15);
  }

  Color get _textColor {
    if (widget.isToday) return Colors.white;
    if (widget.isClaimed) return b.primaryColor;
    return b.mutedTextColor.withValues(alpha: 0.85);
  }

  Color get _labelColor {
    if (widget.isToday) return Colors.white.withValues(alpha: 0.85);
    if (widget.isClaimed) return b.primaryColor.withValues(alpha: 0.8);
    return b.mutedTextColor.withValues(alpha: 0.6);
  }
}
