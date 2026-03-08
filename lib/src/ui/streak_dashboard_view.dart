import 'package:flutter/material.dart';
import '../winr_branding.dart';
import '../domain/campaign.dart';
import '../domain/streak_state.dart';
import '../rewards/rewarded_video_provider.dart';
import 'streak_day_tile.dart';
import 'bonus_entries_view.dart';

/// Streak dashboard view showing the user's streak progress with day tiles.
/// 
/// Displays the current streak with individual day tiles, bonus multipliers,
/// and available actions like claiming daily entries or bonus videos.
class StreakDashboardView extends StatefulWidget {
  /// The active campaign
  final Campaign campaign;
  
  /// Current streak state
  final StreakState streakState;
  
  /// Whether today's entry has been claimed
  final bool claimedToday;
  
  /// Callback when daily entries are claimed
  final VoidCallback onClaimDaily;
  
  /// Callback when bonus entries are claimed
  final VoidCallback onClaimBonus;
  
  /// Optional rewarded video provider
  final RewardedVideoProvider? rewardedVideoProvider;

  const StreakDashboardView({
    super.key,
    required this.campaign,
    required this.streakState,
    required this.claimedToday,
    required this.onClaimDaily,
    required this.onClaimBonus,
    this.rewardedVideoProvider,
  });

  @override
  State<StreakDashboardView> createState() => _StreakDashboardViewState();
}

class _StreakDashboardViewState extends State<StreakDashboardView>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;
  
  final PageController _pageController = PageController();
  // ignore: unused_field
  bool _showBonusEntries = false;
  
  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.streakState.currentDay / 30.0, // Assuming 30-day cycle
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _slideController.forward();
    _progressController.forward();
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        children: [
          _buildStreakHeader(),
          const SizedBox(height: 24),
          _buildProgressIndicator(),
          const SizedBox(height: 32),
          _buildDayTiles(),
          const SizedBox(height: 24),
          _buildStreakInfo(),
          if (widget.rewardedVideoProvider != null) ...[
            const SizedBox(height: 16),
            _buildBonusSection(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStreakHeader() {
    final branding = _getBranding();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            branding.primaryColor.withOpacity(0.2),
            branding.cardBackgroundColor.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(branding.cornerRadius),
        border: Border.all(
          color: branding.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department,
                color: branding.accentGlowColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Day ${widget.streakState.currentDay} Streak',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: branding.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.streakState.totalEntriesEarned} total entries earned',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: branding.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildPrizeInfo(),
        ],
      ),
    );
  }
  
  Widget _buildPrizeInfo() {
    final branding = _getBranding();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: branding.primaryButtonColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: branding.primaryButtonColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        'Win ${_formatPrize(widget.campaign.prizeValue ?? 0)}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: branding.primaryButtonColor,
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    final branding = _getBranding();
    
    return Column(
      children: [
        Text(
          'Streak Progress',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: branding.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: branding.cardBackgroundColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        branding.primaryButtonColor,
                        branding.accentGlowColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: branding.accentGlowColor.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.streakState.currentDay} / 30 days',
          style: TextStyle(
            fontSize: 12,
            color: branding.mutedTextColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDayTiles() {
    final branding = _getBranding();
    final visibleDays = _getVisibleDays();
    
    return Container(
      height: 180,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: visibleDays.map((dayData) {
            final day = dayData['day'] ?? 0;
            final entries = dayData['entries'] ?? 0;
            final isToday = day == widget.streakState.currentDay && !widget.claimedToday;
            final isClaimed = day < widget.streakState.currentDay || 
                             (day == widget.streakState.currentDay && widget.claimedToday);
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: StreakDayTile(
                dayNumber: day,
                entries: entries,
                isClaimed: isClaimed,
                isToday: isToday,
                branding: branding,
                onTap: isToday ? widget.onClaimDaily : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  Widget _buildStreakInfo() {
    final branding = _getBranding();
    final multiplier = _calculateMultiplier();
    
    if (multiplier <= 1.0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            branding.accentGlowColor.withOpacity(0.1),
            branding.primaryButtonColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(branding.cornerRadius),
        border: Border.all(
          color: branding.accentGlowColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up,
            color: branding.accentGlowColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streak Bonus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: branding.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${multiplier.toStringAsFixed(1)}x multiplier active',
                  style: TextStyle(
                    fontSize: 14,
                    color: branding.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: branding.accentGlowColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${multiplier.toStringAsFixed(1)}x',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: branding.accentGlowColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBonusSection() {
    final branding = _getBranding();
    
    return Container(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _showBonusEntries = true;
          });
          _showBonusEntriesModal();
        },
        icon: Icon(
          Icons.play_circle_fill,
          color: branding.primaryButtonColor,
        ),
        label: Text(
          'Watch Video for Bonus Entries',
          style: TextStyle(
            color: branding.primaryButtonColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: branding.primaryButtonColor,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(branding.cornerRadius),
          ),
        ),
      ),
    );
  }
  
  void _showBonusEntriesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BonusEntriesView(
        branding: _getBranding(),
        rewardedVideoProvider: widget.rewardedVideoProvider!,
        onComplete: () {
          widget.onClaimBonus();
          Navigator.of(context).pop();
        },
      ),
    );
  }
  
  // MARK: - Helper Methods
  
  WINRBranding _getBranding() {
    // In a real implementation, this would come from the widget
    // For now, using a default branding
    return WINRBranding.defaultBranding();
  }
  
  List<Map<String, int>> _getVisibleDays() {
    final days = <Map<String, int>>[];
    final currentDay = widget.streakState.currentDay;
    
    // Show current day and next few days
    for (int i = 1; i <= (currentDay + 2).clamp(1, 30); i++) {
      days.add({
        'day': i,
        'entries': _calculateEntriesForDay(i),
      });
    }
    
    return days;
  }
  
  int _calculateEntriesForDay(int day) {
    // Base entries calculation - matches StreakEngine logic
    final baseEntries = 10;
    final weeklyBonus = ((day - 1) ~/ 7) * 10; // Every 7 days
    final monthlyBonus = ((day - 1) ~/ 30) * 50; // Every 30 days
    
    return baseEntries + weeklyBonus + monthlyBonus;
  }
  
  double _calculateMultiplier() {
    final day = widget.streakState.currentDay;
    
    if (day >= 30) return 3.0;
    if (day >= 21) return 2.5;
    if (day >= 14) return 2.0;
    if (day >= 7) return 1.5;
    
    return 1.0;
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