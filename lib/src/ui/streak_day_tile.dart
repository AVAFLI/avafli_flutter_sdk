import 'package:flutter/material.dart';
import '../winr_branding.dart';

/// Individual day tile widget for the streak dashboard.
/// 
/// Displays a single day in the streak with its entries, state (claimed/today/locked),
/// and appropriate visual styling. Supports animations and different states.
class StreakDayTile extends StatefulWidget {
  /// The day number in the streak (1-based)
  final int dayNumber;
  
  /// Number of entries for this day
  final int entries;
  
  /// Whether this day has been claimed
  final bool isClaimed;
  
  /// Whether this is today's tile (should be highlighted)
  final bool isToday;
  
  /// The branding configuration for styling
  final WINRBranding branding;
  
  /// Optional callback when the tile is tapped
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
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Pulse animation for today's tile
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    
    // Scale animation for all tiles
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: widget.isToday ? 1.08 : 0.96,
      end: widget.isToday ? 1.12 : 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    // Start animations
    if (widget.isToday) {
      _pulseController.repeat(reverse: true);
    }
    _scaleController.forward();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 130,
              height: 160,
              decoration: _buildTileDecoration(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDayPill(),
                    _buildEntriesSection(),
                    _buildStatusIcon(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDayPill() {
    return AnimatedBuilder(
      animation: widget.isToday ? _pulseAnimation : kAlwaysCompleteAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _getPillBackgroundColor(),
            borderRadius: BorderRadius.circular(20),
            border: widget.isToday ? Border.all(
              color: widget.branding.accentGlowColor,
              width: 2,
            ) : null,
            boxShadow: widget.isToday ? [
              BoxShadow(
                color: widget.branding.accentGlowColor.withValues(alpha: 0.5 * _pulseAnimation.value),
                blurRadius: 8 * _pulseAnimation.value,
                spreadRadius: 2 * _pulseAnimation.value,
              ),
            ] : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Text(
              'DAY ${widget.dayNumber}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _getPillTextColor(),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEntriesSection() {
    return Column(
      children: [
        Text(
          '${widget.entries}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: _getEntriesTextColor(),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Entries',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _getEntriesLabelColor(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusIcon() {
    final iconSize = widget.isToday ? 22.0 : 20.0;
    
    if (widget.isToday) {
      return Icon(
        Icons.local_fire_department,
        size: iconSize,
        color: widget.branding.accentGlowColor,
        shadows: [
          Shadow(
            color: widget.branding.accentGlowColor,
            blurRadius: 10,
          ),
        ],
      );
    } else if (widget.isClaimed) {
      return Icon(
        Icons.verified,
        size: iconSize,
        color: widget.branding.primaryColor,
      );
    } else {
      return Icon(
        Icons.lock,
        size: iconSize,
        color: widget.branding.mutedTextColor.withValues(alpha: 0.7),
      );
    }
  }
  
  BoxDecoration _buildTileDecoration() {
    return BoxDecoration(
      gradient: _getTileGradient(),
      borderRadius: BorderRadius.circular(widget.branding.cornerRadius + 4),
      border: Border.all(
        color: _getTileBorderColor(),
        width: widget.isToday ? 2.5 : 1.3,
      ),
      boxShadow: [
        BoxShadow(
          color: _getShadowColor(),
          blurRadius: _getShadowRadius(),
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
  
  LinearGradient _getTileGradient() {
    if (widget.isToday) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          widget.branding.primaryButtonColor,
          widget.branding.cardBackgroundColor.withValues(alpha: 0.9),
        ],
      );
    } else if (widget.isClaimed) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          widget.branding.primaryColor.withValues(alpha: 0.25),
          widget.branding.cardBackgroundColor.withValues(alpha: 0.95),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          widget.branding.cardBackgroundColor.withValues(alpha: 0.5),
          widget.branding.cardBackgroundColor.withValues(alpha: 0.35),
        ],
      );
    }
  }
  
  Color _getTileBorderColor() {
    if (widget.isToday) return widget.branding.accentGlowColor;
    if (widget.isClaimed) return widget.branding.primaryColor.withValues(alpha: 0.7);
    return Colors.white.withValues(alpha: 0.18);
  }
  
  Color _getShadowColor() {
    if (widget.isToday) return widget.branding.accentGlowColor.withValues(alpha: 0.7);
    if (widget.isClaimed) return widget.branding.primaryColor.withValues(alpha: 0.4);
    return Colors.black.withValues(alpha: 0.35);
  }
  
  double _getShadowRadius() {
    if (widget.isToday) return 8.0;
    if (widget.isClaimed) return 4.0;
    return 0.0;
  }
  
  Color _getPillBackgroundColor() {
    if (widget.isToday) {
      return widget.branding.cardBackgroundColor.withValues(alpha: 0.95);
    } else if (widget.isClaimed) {
      return widget.branding.primaryColor.withValues(alpha: 0.4);
    } else {
      return widget.branding.cardBackgroundColor.withValues(alpha: 0.9);
    }
  }
  
  Color _getPillTextColor() {
    if (widget.isToday) {
      return widget.branding.primaryButtonTextColor;
    } else {
      return widget.branding.secondaryTextColor;
    }
  }
  
  Color _getEntriesTextColor() {
    if (widget.isToday) return Colors.white;
    if (widget.isClaimed) return widget.branding.primaryColor;
    return widget.branding.mutedTextColor.withValues(alpha: 0.9);
  }
  
  Color _getEntriesLabelColor() {
    if (widget.isToday) return Colors.white.withValues(alpha: 0.9);
    if (widget.isClaimed) return widget.branding.primaryColor.withValues(alpha: 0.85);
    return widget.branding.mutedTextColor.withValues(alpha: 0.7);
  }
}