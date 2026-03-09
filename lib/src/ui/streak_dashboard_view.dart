import 'package:flutter/material.dart';

import '../domain/campaign.dart';
import '../domain/sdk_copy.dart';
import '../domain/streak_state.dart';
import '../winr_branding.dart';
import 'streak_day_tile.dart';

/// Streak dashboard view — matches iOS StreakDashboardView.swift.
///
/// Hero logo + prize banner → horizontal streak tiles → bonus progress → sticky footer.
class StreakDashboardView extends StatelessWidget {
  final WINRBranding branding;
  final StreakState streakState;
  final int entriesToday;
  final List<int> ladder;
  final bool claimedToday;
  final Campaign? campaign;
  final VoidCallback onClaim;
  final VoidCallback onClose;
  final SdkCopy? sdkCopy;

  const StreakDashboardView({
    super.key,
    required this.branding,
    required this.streakState,
    required this.entriesToday,
    required this.ladder,
    required this.claimedToday,
    required this.onClaim,
    required this.onClose,
    this.campaign,
    this.sdkCopy,
  });

  static String formatPrize(double value) {
    final intVal = value.toInt();
    final formatted = intVal.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '\$$formatted CASH';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final safeBottom = bottomPadding == 0 ? 16.0 : bottomPadding;

        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Main scrollable content
            SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: 120,
              ),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Headroom for animations
                    const SizedBox(height: 20),

                    // Hero logo
                    _buildHeroLogo(constraints),
                    const SizedBox(height: 14),

                    // Prize banner
                    _buildPrizeBanner(),
                    const SizedBox(height: 14),

                    // Streak tiles carousel
                    _buildStreakTiles(),
                    const SizedBox(height: 14),

                    // Bonus progress
                    if (campaign != null) _buildBonusProgress(),
                  ],
                ),
              ),
            ),

            // Sticky footer
            _buildStickyFooter(safeBottom),
          ],
        );
      },
    );
  }

  Widget _buildHeroLogo(BoxConstraints constraints) {
    final heroLogo = branding.logoTwo ?? branding.logo;
    if (heroLogo == null) return const SizedBox.shrink();

    final heroWidth = constraints.maxWidth * 0.75;
    final heroHeight = constraints.maxHeight * 0.22;

    return Container(
      constraints: BoxConstraints(
        maxWidth: constraints.maxWidth * 0.85,
        maxHeight: constraints.maxHeight * 0.24,
      ),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: branding.accentGlowColor.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: heroWidth,
        height: heroHeight,
        child: heroLogo,
      ),
    );
  }

  Widget _buildPrizeBanner() {
    final prizeText = campaign?.prizeValue != null
        ? 'WIN ${formatPrize(campaign!.prizeValue!)}!'
        : 'WIN PRIZES!';

    return Column(
      children: [
        Text(
          prizeText,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              Shadow(
                color: branding.accentGlowColor.withValues(alpha: 0.8),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sdkCopy?.streakDashboard?.streakMessage ??
              sdkCopy?.streakMessage ??
              'Keep your daily streak alive to unlock more entries.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: branding.mutedTextColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStreakTiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            sdkCopy?.streakDashboard?.upcomingLabel ?? 'Upcoming rewards',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: branding.secondaryTextColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 155,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: List.generate(ladder.length, (index) {
                final day = index + 1;
                final entries = ladder[index];
                final isClaimed = day < streakState.currentDay ||
                    (day == streakState.currentDay && claimedToday);
                final isToday =
                    day == streakState.currentDay && !claimedToday;

                return Padding(
                  padding: EdgeInsets.only(
                      right: index < ladder.length - 1 ? 10 : 0),
                  child: CompactStreakTile(
                    dayNumber: day,
                    entries: entries,
                    isClaimed: isClaimed,
                    isToday: isToday,
                    branding: branding,
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBonusProgress() {
    final config = campaign!.streakConfig;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sdkCopy?.streakDashboard?.bonusProgress ?? 'Bonus Progress',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: branding.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BonusProgressPill(
                  label: sdkCopy?.streakDashboard?.weekLabel ?? 'Week',
                  current: streakState.weeklyCurrent,
                  target: config.weeklyBonusThreshold,
                  bonus: config.weeklyBonusEntries,
                  branding: branding,
                  sdkCopy: sdkCopy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BonusProgressPill(
                  label: sdkCopy?.streakDashboard?.monthLabel ?? 'Month',
                  current: streakState.monthlyCurrent,
                  target: config.monthlyBonusThreshold,
                  bonus: config.monthlyBonusEntries,
                  branding: branding,
                  sdkCopy: sdkCopy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter(double safeBottom) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: safeBottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            branding.backgroundColor.withValues(alpha: 0.0),
            branding.backgroundColor.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: claimedToday ? _buildClaimedFooter() : _buildClaimFooter(),
    );
  }

  Widget _buildClaimedFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          size: 28,
          color: branding.accentGlowColor,
        ),
        const SizedBox(height: 6),
        Text(
          sdkCopy?.streakDashboard?.alreadyClaimedTitle ?? "Today's entries claimed!",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: branding.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sdkCopy?.streakDashboard?.alreadyClaimedSubtitle ?? 'Come back tomorrow to continue your streak.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: branding.mutedTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: branding.cardBackgroundColor.withValues(alpha: 0.8),
                borderRadius:
                    BorderRadius.circular(branding.cornerRadius),
                border: Border.all(
                  color:
                      branding.accentGlowColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  sdkCopy?.streakDashboard?.doneButton ?? 'Done',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: branding.secondaryTextColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClaimFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (sdkCopy?.streakDashboard?.dayRewardLabel ?? 'Day {day} reward')
              .replaceAll('{day}', '${streakState.currentDay}'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: branding.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          (sdkCopy?.streakDashboard?.claimDescription ?? 'Claim {entries} entries for today\'s visit to keep your streak alive.')
              .replaceAll('{entries}', '$entriesToday'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: branding.mutedTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: onClaim,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: branding.primaryButtonColor,
                borderRadius:
                    BorderRadius.circular(branding.cornerRadius),
                boxShadow: [
                  BoxShadow(
                    color: branding.accentGlowColor
                        .withValues(alpha: 0.6),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  (sdkCopy?.streakDashboard?.claimButton ?? sdkCopy?.dailyClaimButton ?? 'Claim {entries} Entries')
                      .replaceAll('{entries}', '$entriesToday'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: branding.primaryButtonTextColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bonus progress pill — matches iOS BonusProgressPill.
class _BonusProgressPill extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final int bonus;
  final WINRBranding branding;
  final SdkCopy? sdkCopy;

  const _BonusProgressPill({
    required this.label,
    required this.current,
    required this.target,
    required this.bonus,
    required this.branding,
    this.sdkCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: branding.cardBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(branding.cornerRadius),
        border: Border.all(
          color: branding.accentGlowColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: branding.mutedTextColor,
                ),
              ),
              const Spacer(),
              Text(
                '$current/$target days',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: branding.secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (current / target).clamp(0.0, 1.0),
              backgroundColor: branding.cardBorderColor,
              color: branding.accentGlowColor,
              minHeight: 4.8,
            ),
          ),
          const SizedBox(height: 6),
          if (current >= target)
            Text(
              sdkCopy?.streakDashboard?.bonusEarned ?? '✓ Bonus earned!',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: branding.accentGlowColor,
              ),
            )
          else
            Text(
              (sdkCopy?.streakDashboard?.entriesLabel ?? '+{bonus} entries')
                  .replaceAll('{bonus}', '$bonus'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: branding.mutedTextColor,
              ),
            ),
        ],
      ),
    );
  }
}
