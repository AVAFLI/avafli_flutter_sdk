import 'package:flutter/material.dart';

import '../domain/campaign.dart';
import '../domain/streak_state.dart';
import '../winr_branding.dart';

/// Embeddable card widget for inline WINR experience integration.
///
/// A compact version of the WINR experience that can be embedded within
/// other app screens. Shows streak status, daily entry counts, and provides
/// quick access to the full experience.
class WINRExperienceCard extends StatefulWidget {
  /// The branding configuration for styling
  final WINRBranding branding;

  /// Optional campaign data
  final Campaign? campaign;

  /// Optional streak state
  final StreakState? streakState;

  /// Whether today's entry has been claimed
  final bool claimedToday;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  /// Optional callback when the claim button is pressed
  final VoidCallback? onQuickClaim;

  /// Card size variant
  final WINRCardSize size;

  /// Whether to show the quick claim button
  final bool showQuickClaim;

  const WINRExperienceCard({
    super.key,
    required this.branding,
    required this.onTap,
    this.campaign,
    this.streakState,
    this.claimedToday = false,
    this.onQuickClaim,
    this.size = WINRCardSize.medium,
    this.showQuickClaim = true,
  });

  @override
  State<WINRExperienceCard> createState() => _WINRExperienceCardState();
}

class _WINRExperienceCardState extends State<WINRExperienceCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    // Start pulse animation if user hasn't claimed today
    if (!widget.claimedToday) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WINRExperienceCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update pulse animation based on claim status
    if (widget.claimedToday && !oldWidget.claimedToday) {
      _pulseController.stop();
      _pulseController.reset();
    } else if (!widget.claimedToday && oldWidget.claimedToday) {
      _pulseController.repeat(reverse: true);
    }
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
      animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressed ? _scaleAnimation.value : _pulseAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              setState(() => _isPressed = true);
              _scaleController.forward();
            },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              _scaleController.reverse();
              widget.onTap();
            },
            onTapCancel: () {
              setState(() => _isPressed = false);
              _scaleController.reverse();
            },
            child: Container(
              width: _getCardWidth(),
              constraints: BoxConstraints(minHeight: _getCardMinHeight()),
              decoration: _buildCardDecoration(),
              child: _buildCardContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent() {
    switch (widget.size) {
      case WINRCardSize.small:
        return _buildSmallCard();
      case WINRCardSize.medium:
        return _buildMediumCard();
      case WINRCardSize.large:
        return _buildLargeCard();
    }
  }

  Widget _buildSmallCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatusIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.branding.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getSubtitleText(),
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.branding.secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: widget.branding.mutedTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildMediumCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.branding.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSubtitleText(),
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.branding.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar(),
          if (widget.showQuickClaim && !widget.claimedToday) ...[
            const SizedBox(height: 16),
            _buildQuickClaimButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildLargeCard() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 20),
          _buildProgressBar(),
          const Spacer(),
          if (widget.showQuickClaim && !widget.claimedToday)
            _buildQuickClaimButton()
          else
            _buildViewDetailsButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.branding.primaryButtonColor,
                widget.branding.accentGlowColor,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.branding.accentGlowColor.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.emoji_events,
            size: 24,
            color: widget.branding.primaryButtonTextColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.campaign?.title ?? 'Daily Entries',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.branding.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getPrizeText(),
                style: TextStyle(
                  fontSize: 14,
                  color: widget.branding.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            'Streak',
            '${widget.streakState?.currentDay ?? 1}',
            Icons.local_fire_department,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatItem(
            'Entries',
            '${widget.streakState?.totalEntriesEarned ?? 0}',
            Icons.confirmation_number,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatItem(
            'Today',
            widget.claimedToday ? 'Done' : 'Ready',
            widget.claimedToday ? Icons.check_circle : Icons.schedule,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.branding.cardBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
        border: Border.all(
          color: widget.branding.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: widget.branding.primaryButtonColor,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.branding.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: widget.branding.mutedTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (widget.claimedToday) {
      return Icon(
        Icons.check_circle,
        size: widget.size == WINRCardSize.small ? 24 : 32,
        color: widget.branding.primaryButtonColor,
      );
    }

    return Icon(
      Icons.local_fire_department,
      size: widget.size == WINRCardSize.small ? 24 : 32,
      color: widget.branding.accentGlowColor,
    );
  }

  Widget _buildProgressBar() {
    final currentDay = widget.streakState?.currentDay ?? 1;
    final progress = (currentDay / 30.0).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Day $currentDay',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.branding.secondaryTextColor,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.branding.secondaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: widget.branding.cardBackgroundColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.branding.primaryButtonColor,
                    widget.branding.accentGlowColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickClaimButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onQuickClaim,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.branding.primaryButtonColor,
          foregroundColor: widget.branding.primaryButtonTextColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Claim Now',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildViewDetailsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: widget.onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: widget.branding.primaryButtonColor,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
          ),
        ),
        child: Text(
          'View Details',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: widget.branding.primaryButtonColor,
          ),
        ),
      ),
    );
  }

  // MARK: - Helper Methods

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          widget.branding.cardBackgroundColor.withValues(alpha: 0.9),
          widget.branding.cardBackgroundColor.withValues(alpha: 0.7),
        ],
      ),
      borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
      border: Border.all(
        color: widget.branding.primaryColor.withValues(alpha: 0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        if (!widget.claimedToday)
          BoxShadow(
            color: widget.branding.accentGlowColor.withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: 2,
          ),
      ],
    );
  }

  double _getCardWidth() {
    switch (widget.size) {
      case WINRCardSize.small:
        return double.infinity;
      case WINRCardSize.medium:
        return double.infinity;
      case WINRCardSize.large:
        return double.infinity;
    }
  }

  double _getCardMinHeight() {
    switch (widget.size) {
      case WINRCardSize.small:
        return 72;
      case WINRCardSize.medium:
        return 140;
      case WINRCardSize.large:
        return 200;
    }
  }

  String _getStatusText() {
    if (widget.claimedToday) {
      return 'Entries Claimed';
    } else {
      return 'Claim Your Daily Entries';
    }
  }

  String _getSubtitleText() {
    if (widget.claimedToday) {
      return 'Come back tomorrow to continue your streak';
    } else {
      final day = widget.streakState?.currentDay ?? 1;
      return 'Day $day • Tap to claim now';
    }
  }

  String _getPrizeText() {
    final prize = widget.campaign?.prizeValue;
    if (prize != null) {
      return 'Win ${_formatPrize(prize)}';
    }
    return 'Win amazing prizes';
  }

  String _formatPrize(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '\$${value.toStringAsFixed(0)}';
    }
  }
}

/// Card size variants
enum WINRCardSize {
  small, // Compact list item style
  medium, // Standard card with progress
  large, // Full-featured card with stats
}
