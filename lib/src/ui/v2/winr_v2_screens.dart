// The V2 experience screens, matched to the Figma flows: new-user capture,
// return-user dashboard, celebration modal, and how-it-works. Publisher can
// customize ONLY: logo, prize image, primary color. Everything else is
// hardcoded to the design or derived from the prize.
//
// Mirrors the iOS SDK's WINRV2Screens.swift.

import 'package:flutter/material.dart';

import '../../domain/giveaway.dart';
import 'winr_v2_components.dart';
import 'winr_v2_effects.dart';
import 'winr_v2_theme.dart';
import 'winr_v2_winner.dart';

// ---------------------------------------------------------------------------
// Loading + empty states
// ---------------------------------------------------------------------------

class WINRV2LoadingView extends StatelessWidget {
  const WINRV2LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading…',
            style: WINRV2Font.inter(14, color: WINRV2Colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Nothing to pitch (or opted out / errored) — quiet empty state.
class WINRV2EmptyStateView extends StatelessWidget {
  final VoidCallback onClose;

  const WINRV2EmptyStateView({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nothing to see here yet',
            style: WINRV2Font.inter(20, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Check back soon for your next chance to win!',
            style: WINRV2Font.inter(14, color: WINRV2Colors.textTertiary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: WINRV2PillButton(
              accent: WINRV2Colors.winrBlue,
              title: 'CLOSE',
              onTap: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// New-user capture ("VISIT. EARN. WIN.")
// ---------------------------------------------------------------------------

class WINRV2CaptureView extends StatefulWidget {
  final Color accent;
  final String? logoUrl;
  final String? rulesUrl;
  final Giveaway? giveaway;
  final bool isSubmitting;
  final ValueChanged<String> onSubmit;
  final VoidCallback onInfo;
  final VoidCallback onClose;

  const WINRV2CaptureView({
    super.key,
    required this.accent,
    required this.logoUrl,
    required this.rulesUrl,
    required this.giveaway,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onInfo,
    required this.onClose,
  });

  @override
  State<WINRV2CaptureView> createState() => _WINRV2CaptureViewState();
}

class _WINRV2CaptureViewState extends State<WINRV2CaptureView> {
  final TextEditingController _email = TextEditingController();
  bool _isAdult = false;

  int get _day1Entries {
    final ladder = widget.giveaway?.streakLadder;
    return (ladder != null && ladder.isNotEmpty) ? ladder.first : 10;
  }

  bool get _canSubmit =>
      _isAdult && _email.text.contains('@') && _email.text.contains('.');

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WINRV2TopGlow(accent: widget.accent),
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 18),
              WINRV2Header(
                logoUrl: widget.logoUrl,
                onInfo: widget.onInfo,
                onClose: widget.onClose,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'VISIT. EARN. WIN.',
                        maxLines: 1,
                        style: WINRV2Font.inter(
                          40,
                          weight: FontWeight.w900,
                          letterSpacing: -1.2,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'VISIT DAILY.  EARN ENTRIES.  WIN BIG!',
                      style: WINRV2Font.inter(15, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _prizeStrip(),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    _emailField(),
                    const SizedBox(height: 14),
                    _ageCheckbox(),
                    const SizedBox(height: 14),
                    WINRV2PillButton(
                      accent: widget.accent,
                      title: 'CLAIM MY $_day1Entries ENTRIES',
                      isLoading: widget.isSubmitting,
                      enabled: _canSubmit,
                      onTap: () => widget.onSubmit(_email.text.trim()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Your email lets us contact you if you win. By entering you '
                  'agree to the Official Rules & Privacy Policy',
                  textAlign: TextAlign.center,
                  style:
                      WINRV2Font.inter(12, color: WINRV2Colors.textTertiary),
                ),
              ),
              const SizedBox(height: 3),
              WINRV2LegalLinks(rulesUrl: widget.rulesUrl, showPoweredBy: true),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  /// PRIZE-derived white strip (Day-1 examples):
  /// cash → "$1,000.00 CASH PRIZE"; other → "Win a $500 Amazon Gift Card"
  /// + value line only when the description lacks the $amount.
  Widget _prizeStrip() {
    final description = widget.giveaway?.prizeDescription ?? '';
    final value = (widget.giveaway?.prizeValue ?? 0).toInt();
    final isCash = winrV2IsCashPrize(description);
    final article = winrV2Article(description);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCash)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '\$${winrV2FormatInt(value)}.00 CASH PRIZE',
                maxLines: 1,
                style: WINRV2Font.inter(
                  24,
                  weight: FontWeight.w900,
                  color: WINRV2Colors.gunmetal,
                  letterSpacing: -0.7,
                  height: 1.1,
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Win $article $description',
                  maxLines: 1,
                  style: WINRV2Font.inter(
                    23,
                    weight: FontWeight.w900,
                    color: WINRV2Colors.gunmetal,
                    letterSpacing: -0.7,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            if (winrV2ShowsValueLine(description, value))
              Text(
                '\$${winrV2FormatInt(value)}.00 Value!',
                style: WINRV2Font.inter(16, color: WINRV2Colors.gunmetal),
              ),
          ],
        ],
      ),
    );
  }

  Widget _emailField() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xBFFFFFFF), width: 2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mail_outline,
            size: 22,
            color: WINRV2Colors.gunmetal.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              style: WINRV2Font.inter(16, color: WINRV2Colors.gunmetal),
              cursorColor: WINRV2Colors.gunmetal,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Enter your email address',
                hintStyle: WINRV2Font.inter(
                  16,
                  color: WINRV2Colors.gunmetal.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ageCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _isAdult = !_isAdult),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isAdult ? Icons.check_box : Icons.check_box_outline_blank,
            size: 22,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Text(
            'I confirm I am 18 years of age or older',
            style: WINRV2Font.inter(14),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Return-user dashboard (Day 2+ drawer)
// ---------------------------------------------------------------------------

class WINRV2DashboardView extends StatelessWidget {
  final Color accent;
  final String? logoUrl;
  final String? rulesUrl;
  final Giveaway? giveaway;
  final int streakDay;
  final int totalEntries;
  final int entriesToday;
  final List<int> ladder;
  final bool claimedToday;
  final VoidCallback onInfo;
  final VoidCallback onClose;
  final VoidCallback? onWinnerTap;

  /// Reveal flow (Day 2+): the claim already succeeded server-side, but the UI
  /// holds yesterday's numbers until the user taps "CLAIM N ENTRIES" — that tap
  /// is the celebration (tile check + confetti + totals update), no modal.
  final int? pendingClaimEntries;
  final bool revealed;
  final VoidCallback? onClaim;

  const WINRV2DashboardView({
    super.key,
    required this.accent,
    required this.logoUrl,
    required this.rulesUrl,
    required this.giveaway,
    required this.streakDay,
    required this.totalEntries,
    required this.entriesToday,
    required this.ladder,
    required this.claimedToday,
    required this.onInfo,
    required this.onClose,
    this.onWinnerTap,
    this.pendingClaimEntries,
    this.revealed = true,
    this.onClaim,
  });

  bool get _visitMode => giveaway?.isVisitMode ?? false;

  bool get _preReveal => pendingClaimEntries != null && !revealed;

  int _ladderValue(int day) => WINRV2Ladder.entries(
        day: day,
        ladder: ladder,
        milestones: giveaway?.milestones,
      );

  int get _nextEntries => _ladderValue(streakDay + 1);

  List<WINRV2RailEntry> get _railEntries {
    final entries = <WINRV2RailEntry>[];
    final maxDay = streakDay + 2 > 31 ? streakDay + 2 : 31;
    final milestoneDays = <int, int>{
      for (final m in giveaway?.milestones ?? const <MilestoneConfig>[])
        m.day: m.bonusEntries,
    };
    for (var day = 1; day <= maxDay; day++) {
      final state = day < streakDay
          ? WINRV2TileState.completed
          : (day == streakDay
              ? (_preReveal ? WINRV2TileState.ready : WINRV2TileState.active)
              : WINRV2TileState.locked);
      entries.add(WINRV2RailEntry.day(
        id: 'day-$day',
        day: day,
        entries: _ladderValue(day),
        state: state,
      ));
      final bonus = milestoneDays[day];
      if (bonus != null) {
        final String label;
        switch (day) {
          case 7:
            label = '1 WEEK';
          case 14:
            label = '2 WEEK';
          case 21:
            label = '3 WEEK';
          case 29 || 30:
            label = '1 MONTH';
          default:
            label = 'DAY $day';
        }
        final footnote = day == streakDay
            ? 'STARTING TOMORROW'
            : 'STARTING AT ${_visitMode ? 'VISIT' : 'DAY'} ${day + 1}';
        entries.add(WINRV2RailEntry.powerUp(
          id: 'power-$day',
          label: label,
          bonus: bonus,
          footnote: footnote,
        ));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WINRV2Colors.gunmetal,
      child: Column(
        children: [
          const SizedBox(height: 15),
          const WINRV2TabGrabber(),
          const SizedBox(height: 15),
          WINRV2Header(logoUrl: logoUrl, onInfo: onInfo, onClose: onClose),
          const SizedBox(height: 15),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (giveaway?.latestWinner != null && onWinnerTap != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: WINRV2WinnerBanner(onTap: onWinnerTap!),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: WINRV2PrizeCard(
                      accent: accent,
                      // Pre-reveal the streak label still reads yesterday's
                      // day; the CLAIM tap advances it to today.
                      streakDay: _preReveal
                          ? (streakDay - 1 > 1 ? streakDay - 1 : 1)
                          : streakDay,
                      totalEntries: totalEntries,
                      prizeImageUrl: giveaway?.prizeImageUrl,
                      prizeValue: (giveaway?.prizeValue ?? 0).toInt(),
                      prizeDescription: giveaway?.prizeDescription ?? '',
                      visitMode: _visitMode,
                    ),
                  ),
                  const SizedBox(height: 15),
                  WINRV2StreakRail(
                    accent: accent,
                    entries: _railEntries,
                    activeID: 'day-$streakDay',
                    visitMode: _visitMode,
                  ),
                  const SizedBox(height: 15),
                  WINRV2ComeBackBar(
                    accent: accent,
                    nextEntries: _nextEntries,
                    visitMode: _visitMode,
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    // CLAIM ⇄ GOT IT cross-fades on the reveal.
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      child: _preReveal
                          ? WINRV2PillButton(
                              key: const ValueKey('claim'),
                              accent: accent,
                              title:
                                  'CLAIM ${winrV2FormatInt(pendingClaimEntries!)} ENTRIES',
                              onTap: onClaim ?? onClose,
                            )
                          : WINRV2PillButton(
                              key: const ValueKey('got-it'),
                              accent: accent,
                              title: 'GOT IT',
                              onTap: onClose,
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  WINRV2LegalLinks(rulesUrl: rulesUrl),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Celebration modal (Day 1 "You're in!" / Day 2+ streak)
// ---------------------------------------------------------------------------

class WINRV2CelebrationModal extends StatefulWidget {
  final Color accent;
  final int streakDay;
  final int earnedEntries;
  final int nextEntries;
  final bool visitMode;
  final VoidCallback onDismiss;

  const WINRV2CelebrationModal({
    super.key,
    required this.accent,
    required this.streakDay,
    required this.earnedEntries,
    required this.nextEntries,
    this.visitMode = false,
    required this.onDismiss,
  });

  @override
  State<WINRV2CelebrationModal> createState() =>
      _WINRV2CelebrationModalState();
}

class _WINRV2CelebrationModalState extends State<WINRV2CelebrationModal> {
  bool _appeared = false;

  bool get _isFirstDay => widget.streakDay <= 1;
  Color get accent => widget.accent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _appeared = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Explicit dismiss only — the scrim does NOT dismiss.
        const ColoredBox(color: Color(0x8C000000)),
        Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 340,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: WINRV2Colors.panel,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: WINRV2Colors.panelBorder),
                    ),
                    child: _content(),
                  ),
                  // Confetti flutters over the upper card.
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 330,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      child: WINRV2Confetti(count: 34),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: widget.onDismiss,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: WINRV2Colors.gunmetal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated circle-then-check draw-on in white.
        SizedBox(
          height: 110,
          child: Padding(
            padding: const EdgeInsets.only(top: 17),
            child: AnimatedScale(
              scale: _appeared ? 1 : 0.4,
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              child: const SizedBox(
                width: 88,
                height: 88,
                child: WINRV2AnimatedCheckmark(lineWidth: 7),
              ),
            ),
          ),
        ),
        if (_isFirstDay) ...[
          Text("You’re in!", style: WINRV2Font.inter(14, weight: FontWeight.w700)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${widget.earnedEntries} ENTRIES HAVE BEEN ADDED',
                maxLines: 1,
                style: WINRV2Font.inter(
                  23,
                  weight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
          ),
        ] else ...[
          Text("YOU’RE ON A",
              style: WINRV2Font.inter(20, weight: FontWeight.w700)),
          Text(
            '${widget.streakDay} ${widget.visitMode ? 'VISIT' : 'DAY'} STREAK!',
            style: WINRV2Font.inter(
              32,
              weight: FontWeight.w900,
              color: accent,
              letterSpacing: -0.96,
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Container(height: 1, color: const Color(0x26FFFFFF)),
        ),
        if (_isFirstDay) ...[
          Text(
            widget.visitMode
                ? 'NEXT TIME YOU VISIT GET'
                : 'COME BACK TOMORROW TO KEEP\nYOUR STREAK GOING AND GET',
            textAlign: TextAlign.center,
            style: WINRV2Font.inter(14, weight: FontWeight.w700, height: 1.25),
          ),
          _bigNumber(widget.nextEntries),
        ] else ...[
          Text('YOU EARNED',
              style: WINRV2Font.inter(20, weight: FontWeight.w700)),
          _bigNumber(widget.earnedEntries),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
            child: Container(
              height: 71,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 24, color: accent),
                  const SizedBox(width: 14),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.visitMode
                            ? 'Come back again for'
                            : 'Come back tomorrow for',
                        style: WINRV2Font.inter(15, height: 1.15),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${winrV2FormatInt(widget.nextEntries)} ENTRIES',
                        style: WINRV2Font.inter(
                          20,
                          weight: FontWeight.w900,
                          color: accent,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(
              left: 28, right: 28, top: 20, bottom: 24),
          child: WINRV2PillButton(
            accent: accent,
            title: 'GOT IT',
            onTap: widget.onDismiss,
          ),
        ),
      ],
    );
  }

  Widget _bigNumber(int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              winrV2FormatInt(value),
              maxLines: 1,
              style: WINRV2Font.inter(
                96,
                weight: FontWeight.w900,
                color: accent,
                letterSpacing: -4.8,
                height: 1.0,
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -14),
          child: Text(
            'ENTRIES',
            style: WINRV2Font.inter(
              32,
              weight: FontWeight.w900,
              letterSpacing: -0.96,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// How it works
// ---------------------------------------------------------------------------

class WINRV2HowItWorksView extends StatelessWidget {
  final Color accent;
  final String? logoUrl;
  final int day1Entries;
  final bool visitMode;
  final VoidCallback onDone;
  final VoidCallback onClose;

  const WINRV2HowItWorksView({
    super.key,
    required this.accent,
    required this.logoUrl,
    required this.day1Entries,
    this.visitMode = false,
    required this.onDone,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WINRV2Colors.panel,
      child: Column(
        children: [
          const SizedBox(height: 18),
          // The back ARROW replaces the "?" in the header.
          WINRV2Header(
            logoUrl: logoUrl,
            showsBack: true,
            onBack: onDone,
            onInfo: _noop,
            onClose: onClose,
          ),
          const SizedBox(height: 12),
          Container(
            height: 39,
            width: double.infinity,
            color: const Color(0x80FFFFFF),
            alignment: Alignment.center,
            child: Text(
              'HOW IT WORKS',
              style: WINRV2Font.inter(
                26,
                weight: FontWeight.w900,
                color: WINRV2Colors.gunmetal,
                letterSpacing: -0.78,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _item(
                          '1',
                          'ENTER ONCE',
                          'Submit your email to receive $day1Entries entries '
                              'instantly and start your streak.',
                        ),
                        const SizedBox(height: 14),
                        _item(
                          '2',
                          visitMode ? 'KEEP VISITING' : 'VISIT EVERY DAY',
                          visitMode
                              ? 'Simply open the app whenever you like. Your '
                                  'entries are added automatically—no forms or '
                                  'extra steps.'
                              : 'Simply open the app each day. Your entries '
                                  'are added automatically—no forms or extra '
                                  'steps.',
                        ),
                        const SizedBox(height: 14),
                        _item(
                          '3',
                          'KEEP YOUR STREAK GROWING',
                          visitMode
                              ? 'Earn more entries with every visit. The more '
                                  'you come back, the bigger your rewards!'
                              : 'Earn more entries with every consecutive '
                                  'visit. The longer your streak, the bigger '
                                  'your daily rewards!',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      visitMode
                          ? 'Every visit counts - your streak never resets.'
                          : 'Don’t miss a day - your streak resets if you do.',
                      textAlign: TextAlign.center,
                      style: WINRV2Font.inter(
                        20,
                        weight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: WINRV2PillButton(
                      accent: accent,
                      title: 'GOT IT - START MY STREAK',
                      onTap: onDone,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _noop() {}

  Widget _item(String number, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$number.',
            style: WINRV2Font.inter(18, weight: FontWeight.w900)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: WINRV2Font.inter(18, weight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(body, style: WINRV2Font.inter(16, height: 1.25)),
            ],
          ),
        ),
      ],
    );
  }
}
