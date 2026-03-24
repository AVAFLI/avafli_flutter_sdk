import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/giveaway.dart';
import '../domain/sdk_copy.dart';
import '../domain/sdk_media.dart';
import '../domain/streak_state.dart';
import '../winr_branding.dart';

/// Streak dashboard view — matches iOS StreakDashboardView.swift.
///
/// Hero logo + prize banner → 4-column grid streak tiles → sticky footer
/// with entry progress pill, claim CTA, and legal links.
class StreakDashboardView extends StatelessWidget {
  final WINRBranding branding;
  final StreakState streakState;
  final int entriesToday;
  final List<int> ladder;
  final bool claimedToday;
  final Giveaway? giveaway;
  final VoidCallback onClaim;
  final VoidCallback onClose;
  final SdkCopy? sdkCopy;
  final SdkMedia? sdkMedia;

  const StreakDashboardView({
    super.key,
    required this.branding,
    required this.streakState,
    required this.entriesToday,
    required this.ladder,
    required this.claimedToday,
    required this.onClaim,
    required this.onClose,
    this.giveaway,
    this.sdkCopy,
    this.sdkMedia,
  });

  static String formatPrize(double value) {
    final intVal = value.toInt();
    final formatted = intVal
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '\$$formatted CASH';
  }

  static String _formatEntries(int value) {
    return value
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Widget _buildHeroMedia(
    ScreenMedia? media,
    Widget defaultWidget, {
    double? width,
    double? height,
  }) {
    if (media?.lottieUrl != null && media!.lottieUrl!.isNotEmpty) {
      return Lottie.network(
        media.lottieUrl!,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => defaultWidget,
      );
    }
    if (media?.imageUrl != null && media!.imageUrl!.isNotEmpty) {
      return Image.network(
        media.imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => defaultWidget,
      );
    }
    return defaultWidget;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final safeBottom = bottomPadding == 0 ? 20.0 : bottomPadding + 4;

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: safeBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // Hero media — large, prominent like iOS
              _buildHeroLogo(constraints),
              const SizedBox(height: 18),

              // Prize banner
              _buildPrizeBanner(),
              const SizedBox(height: 16),

              // Streak tiles grid (4-column like iOS)
              _buildStreakGrid(),
              const SizedBox(height: 24),

              // Footer — flows directly after grid
              _buildFooterContent(safeBottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroLogo(BoxConstraints constraints) {
    final heroLogo = branding.logoTwo ?? branding.logo;
    // Use full screen height for sizing (constraints are reduced by header/padding).
    // iOS uses geo.size.height * 0.22 with maxHeight 0.24 — approximate by
    // using the screen height directly so the hero is comparably large.
    final screenHeight = MediaQueryData.fromView(
            WidgetsBinding.instance.platformDispatcher.views.first)
        .size
        .height;
    final heroWidth = constraints.maxWidth * 0.85;
    final heroHeight = screenHeight * 0.22;

    final defaultWidget = heroLogo != null
        ? Container(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * 0.85,
              maxHeight: screenHeight * 0.24,
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
              child: FittedBox(
                fit: BoxFit.contain,
                child: heroLogo,
              ),
            ),
          )
        : const SizedBox.shrink();

    return _buildHeroMedia(
      sdkMedia?.streakDashboard,
      defaultWidget,
      width: heroWidth,
      height: heroHeight,
    );
  }

  Widget _buildPrizeBanner() {
    final prizeText = sdkCopy?.streakDashboard?.prizeHeadline ??
        (giveaway?.prizeValue != null
            ? 'WIN ${formatPrize(giveaway!.prizeValue!)}!'
            : 'WIN PRIZES!');

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

  Widget _buildStreakGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: _StreakGrid(
        ladder: ladder,
        currentDay: streakState.currentDay,
        claimedToday: claimedToday,
        branding: branding,
      ),
    );
  }

  Widget _buildFooterContent(double safeBottom) {
    return claimedToday ? _buildClaimedFooter() : _buildClaimFooter();
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
          sdkCopy?.streakDashboard?.alreadyClaimedTitle ??
              "Today's entries claimed!",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: branding.secondaryTextColor,
          ),
        ),

        // Total entries pill
        if (streakState.totalEntriesEarned > 0) ...[
          const SizedBox(height: 8),
          _TotalEntriesPill(
            total: streakState.totalEntriesEarned,
            branding: branding,
          ),
        ],

        const SizedBox(height: 6),
        Text(
          sdkCopy?.streakDashboard?.alreadyClaimedSubtitle ??
              'Come back tomorrow to continue your streak.',
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
                borderRadius: BorderRadius.circular(branding.cornerRadius),
                border: Border.all(
                  color: branding.accentGlowColor.withValues(alpha: 0.4),
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

        // Legal links
        const SizedBox(height: 10),
        _LegalLinks(branding: branding),
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

        // Entry progress pill (current → new total)
        if (streakState.totalEntriesEarned > 0 || entriesToday > 0) ...[
          const SizedBox(height: 6),
          _EntryProgressPill(
            currentEntries: streakState.totalEntriesEarned,
            entriesToAdd: entriesToday,
            branding: branding,
          ),
        ],

        const SizedBox(height: 6),
        Text(
          (sdkCopy?.streakDashboard?.claimDescription ??
                  "Claim entries for today's visit to keep your streak alive.")
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
                borderRadius: BorderRadius.circular(branding.cornerRadius),
                boxShadow: [
                  BoxShadow(
                    color: branding.accentGlowColor.withValues(alpha: 0.6),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  (sdkCopy?.streakDashboard?.claimButton ??
                          sdkCopy?.dailyClaimButton ??
                          "Claim Today's Entries")
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

        // Legal links
        const SizedBox(height: 10),
        _LegalLinks(branding: branding),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// STREAK GRID — 4-column grid layout matching iOS LazyVGrid
// ---------------------------------------------------------------------------

class _StreakGrid extends StatelessWidget {
  final List<int> ladder;
  final int currentDay;
  final bool claimedToday;
  final WINRBranding branding;

  const _StreakGrid({
    required this.ladder,
    required this.currentDay,
    required this.claimedToday,
    required this.branding,
  });

  @override
  Widget build(BuildContext context) {
    // Build rows: 4 tiles per row (matches iOS)
    final List<Widget> rows = [];
    for (int i = 0; i < ladder.length; i += 4) {
      final rowEnd = (i + 4).clamp(0, ladder.length);
      final rowItems = <Widget>[];
      for (int j = i; j < rowEnd; j++) {
        final day = j + 1;
        final entries = ladder[j];
        final isClaimed =
            day < currentDay || (day == currentDay && claimedToday);
        final isToday = day == currentDay && !claimedToday;

        rowItems.add(
          Expanded(
            child: _GridStreakTile(
              dayNumber: day,
              entries: entries,
              isClaimed: isClaimed,
              isToday: isToday,
              branding: branding,
            ),
          ),
        );
      }
      // Pad with empty expanded to keep grid alignment
      while (rowItems.length < 4) {
        rowItems.add(const Expanded(child: SizedBox.shrink()));
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
          child: Row(
            children:
                rowItems.expand((w) => [w, const SizedBox(width: 10)]).toList()
                  ..removeLast(),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: rows),
    );
  }
}

// ---------------------------------------------------------------------------
// GRID STREAK TILE — matches iOS CompactStreakTile in grid mode
// ---------------------------------------------------------------------------

class _GridStreakTile extends StatefulWidget {
  final int dayNumber;
  final int entries;
  final bool isClaimed;
  final bool isToday;
  final WINRBranding branding;

  const _GridStreakTile({
    required this.dayNumber,
    required this.entries,
    required this.isClaimed,
    required this.isToday,
    required this.branding,
  });

  @override
  State<_GridStreakTile> createState() => _GridStreakTileState();
}

class _GridStreakTileState extends State<_GridStreakTile>
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
      _pulseController.repeat();
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Day pill
            _buildDayPill(),
            const SizedBox(height: 4),
            // Entries count
            Text(
              '${widget.entries}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 2),
            // Entries label
            Text(
              'Entries',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _labelColor,
              ),
            ),
            const SizedBox(height: 4),
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
            ? Tween<double>(begin: 1.0, end: 1.12).evaluate(CurvedAnimation(
                parent: _pulseController, curve: Curves.easeInOut))
            : 1.0;
        final pulseOpacity = widget.isToday
            ? Tween<double>(begin: 1.0, end: 0.4).evaluate(CurvedAnimation(
                parent: _pulseController, curve: Curves.easeInOut))
            : 0.0;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (widget.isToday)
              Transform.scale(
                scale: pulseVal,
                child: Opacity(
                  opacity: pulseOpacity,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: b.accentGlowColor,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'DAY ${widget.dayNumber}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _pillBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'DAY ${widget.dayNumber}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: widget.isToday
                      ? b.primaryButtonTextColor
                      : b.secondaryTextColor,
                ),
              ),
            ),
          ],
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

// ---------------------------------------------------------------------------
// ENTRY PROGRESS PILL — "1,170 → 1,200 entries" (matches iOS)
// ---------------------------------------------------------------------------

class _EntryProgressPill extends StatelessWidget {
  final int currentEntries;
  final int entriesToAdd;
  final WINRBranding branding;

  const _EntryProgressPill({
    required this.currentEntries,
    required this.entriesToAdd,
    required this.branding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: branding.cardBackgroundColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: branding.accentGlowColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            StreakDashboardView._formatEntries(currentEntries),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: branding.mutedTextColor,
            ),
          ),
          const SizedBox(width: 5),
          Icon(
            Icons.arrow_forward,
            size: 9,
            color: branding.accentGlowColor,
          ),
          const SizedBox(width: 5),
          Text(
            StreakDashboardView._formatEntries(currentEntries + entriesToAdd),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'entries',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: branding.mutedTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TOTAL ENTRIES PILL — "★ Total Entries: 1,200" (matches iOS claimed state)
// ---------------------------------------------------------------------------

class _TotalEntriesPill extends StatelessWidget {
  final int total;
  final WINRBranding branding;

  const _TotalEntriesPill({
    required this.total,
    required this.branding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: branding.cardBackgroundColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: branding.accentGlowColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            size: 12,
            color: branding.accentGlowColor,
          ),
          const SizedBox(width: 5),
          Text(
            'Total: ${StreakDashboardView._formatEntries(total)} entries',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: branding.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LEGAL LINKS — "OFFICIAL RULES • PRIVACY POLICY" (matches iOS)
// ---------------------------------------------------------------------------

class _LegalLinks extends StatelessWidget {
  final WINRBranding branding;

  const _LegalLinks({required this.branding});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _openUrl('https://winfrastructure.us/rules'),
          child: Text(
            'OFFICIAL RULES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: branding.mutedTextColor,
              decoration: TextDecoration.underline,
              decorationColor: branding.mutedTextColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '•',
            style: TextStyle(
              fontSize: 11,
              color: branding.mutedTextColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _openUrl('https://winfrastructure.us/privacy'),
          child: Text(
            'PRIVACY POLICY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: branding.mutedTextColor,
              decoration: TextDecoration.underline,
              decorationColor: branding.mutedTextColor,
            ),
          ),
        ),
      ],
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
