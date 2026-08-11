// The V2 experience screens, matched to the Figma flows: new-user capture,
// return-user dashboard, celebration modal, and how-it-works. Publisher can
// customize ONLY: logo, prize image, primary color. Everything else is
// hardcoded to the design or derived from the prize.
//
// Mirrors the iOS SDK's WINRV2Screens.swift.

import 'package:flutter/material.dart';

import '../../domain/giveaway.dart';
import 'winr_v2_components.dart';
import 'winr_v2_strings.dart';
import 'winr_v2_theme.dart';
import 'winr_v2_winner.dart';

/// Email shape check shared by the capture CTA gate and the inline error, so
/// the two can never disagree (an enabled CTA under a visible error, or vice
/// versa). Deliberately a SHAPE check only — the server revalidates.
bool winrV2IsValidEmail(String raw) {
  final e = raw.trim();
  return e.length <= 254 && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e);
}

// ---------------------------------------------------------------------------
// Loading + empty states
// ---------------------------------------------------------------------------

/// Cold start (no cached giveaway/streak to paint from): a SKELETON of the
/// dashboard rather than a centered spinner.
///
/// The drawer auto-opens before its sequential network calls resolve
/// (registerDevice → getActiveGiveaway → claim). A bare spinner made that wait
/// read as "nothing is here yet"; blocking out the real layout — header, prize
/// card, streak tiles, come-back bar, pill — in the drawer's own gunmetal
/// reads as the content arriving, at identical latency. The warm path never
/// gets here at all: a cached giveaway + streak paints the real dashboard
/// immediately (see `_hydrateFromCache`).
class WINRV2LoadingView extends StatefulWidget {
  const WINRV2LoadingView({super.key});

  @override
  State<WINRV2LoadingView> createState() => _WINRV2LoadingViewState();
}

class _WINRV2LoadingViewState extends State<WINRV2LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WINRV2Colors.gunmetal,
      child: FadeTransition(
        // A single shared pulse keeps every block in phase, so it reads as one
        // surface breathing rather than a field of blinking rectangles.
        opacity: Tween<double>(begin: 0.45, end: 0.85).animate(
          CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
        ),
        // Never scrolls — the wrapper just lets the blocked-out layout run off
        // a short drawer instead of overflowing it.
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 15),
              const WINRV2TabGrabber(),
              const SizedBox(height: 15),
              // Header: "?" circle • logo • "X" circle.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _block(36, 36, radius: 18),
                    const Spacer(),
                    _block(140, 34),
                    const Spacer(),
                    _block(36, 36, radius: 18),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Prize card.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _block(double.infinity, 200, radius: 10),
              ),
              const SizedBox(height: 15),
              // Streak rail: three tiles.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _block(106, 134, radius: 10),
                    _block(106, 134, radius: 10),
                    _block(106, 134, radius: 10),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              // Come-back bar.
              _block(double.infinity, 71, radius: 0),
              const SizedBox(height: 15),
              // CTA pill.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: _block(double.infinity, 54, radius: 27),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(double width, double height, {double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(radius),
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

/// Geo-blocked (`WINRError.geographyNotAllowed`) — a DEDICATED state, not the
/// generic empty state: the person needs to know WHY there's nothing here
/// (US-only sweepstakes) and that it isn't an outage on our side.
class WINRV2GeoBlockedView extends StatelessWidget {
  final VoidCallback onClose;

  const WINRV2GeoBlockedView({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              WINRV2Strings.geoBlockedHeadline,
              textAlign: TextAlign.center,
              style: WINRV2Font.inter(20, weight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              WINRV2Strings.geoBlockedBody,
              textAlign: TextAlign.center,
              style: WINRV2Font.inter(
                14,
                color: WINRV2Colors.textTertiary,
                height: 1.35,
              ),
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
      ),
    );
  }
}

/// Session expired — token refresh AND re-registration both failed. Unlike
/// every other error (which keeps the quiet empty state), this one is
/// actionable: RETRY re-registers the device and reloads.
class WINRV2SessionExpiredView extends StatelessWidget {
  final Color accent;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const WINRV2SessionExpiredView({
    super.key,
    required this.accent,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              WINRV2Strings.sessionExpired,
              textAlign: TextAlign.center,
              style: WINRV2Font.inter(16, weight: FontWeight.w600, height: 1.3),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: WINRV2PillButton(
                accent: accent,
                title: WINRV2Strings.retry,
                onTap: onRetry,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'CLOSE',
                style: WINRV2Font.inter(
                  14,
                  weight: FontWeight.w700,
                  color: WINRV2Colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-blocking dashboard notice (duplicate same-day entry, failed
/// auto-claim). Sits above the prize card in the info-card styling; an
/// optional TRY AGAIN affordance re-attempts the claim.
class WINRV2DashboardNotice extends StatelessWidget {
  final Color accent;
  final String notice;
  final VoidCallback? onRetry;

  const WINRV2DashboardNotice({
    super.key,
    required this.accent,
    required this.notice,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF), // white 8%
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notice, style: WINRV2Font.inter(13, height: 1.35)),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onRetry,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  WINRV2Strings.tryAgain,
                  style: WINRV2Font.inter(
                    13,
                    weight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// New-user capture ("VISIT. EARN. WIN.")
// ---------------------------------------------------------------------------

/// Capture-screen submit: the typed email plus BOTH checkbox states, which
/// the experience forwards verbatim to `submitEmail`.
typedef WINRV2CaptureSubmit = void Function(
  String email, {
  required bool ageConfirmed,
  required bool marketingConsent,
});

/// SDK default for the marketing-consent line, used only when the server
/// sends no `copy.emailCapture.emailConsentText` (or flat
/// `copy.emailConsentText`).
///
/// In practice the server wins: it populates that field with a
/// publisher-named string ("I agree to receive marketing emails from
/// {PublisherName}"). This generic literal is the offline/no-config
/// fallback — the SDK never interpolates a publisher name itself.
const String winrV2DefaultMarketingConsentText =
    'I agree to receive marketing emails from this app';

class WINRV2CaptureView extends StatefulWidget {
  final Color accent;
  final String? logoUrl;
  final String? rulesUrl;
  final Giveaway? giveaway;
  final bool isSubmitting;
  final WINRV2CaptureSubmit onSubmit;
  final VoidCallback onInfo;
  final VoidCallback onClose;

  /// Server-supplied consent copy; null → [winrV2DefaultMarketingConsentText].
  final String? marketingConsentText;

  /// Inline, retryable submit failure from the experience (e.g. the email
  /// POST died in transit). Rendered under the email field in the same error
  /// styling as validation; the user stays here and can try again.
  final String? submitError;

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
    this.marketingConsentText,
    this.prefilledEmail,
    this.submitError,
  });

  /// Partner-authenticated email (WINRUser.email). Well-formed → rendered
  /// pre-filled and READ-ONLY; malformed or null → the editable field.
  final String? prefilledEmail;

  @override
  State<WINRV2CaptureView> createState() => _WINRV2CaptureViewState();
}

class _WINRV2CaptureViewState extends State<WINRV2CaptureView> {
  final TextEditingController _email = TextEditingController();
  final FocusNode _emailFocus = FocusNode();

  /// Errors appear only once the field has been "touched" — focus lost (or a
  /// submit attempted) while holding an invalid non-empty value. Typing a
  /// first, still-incomplete address never flashes red mid-keystroke.
  bool _emailTouched = false;

  /// Age gate requires an affirmative action — starts UNCHECKED and gates the
  /// CTA.
  bool _isAdult = false;

  /// Marketing consent — permission to send promotional email, and NOTHING
  /// else. Unchecked by default (consent must be an affirmative act; pre-ticked
  /// boxes are invalid under GDPR), and deliberately absent from [_canSubmit]:
  /// leaving it unticked must still let the user enter, and never affects
  /// winner contact.
  bool _marketingConsent = false;

  /// Shape check only — the server revalidates. Its job is to pick pre-fill
  /// vs editable, so a partner bug degrades to the normal typed flow instead
  /// of locking a garbage value into a read-only field.
  String? get _lockedEmail {
    final e = widget.prefilledEmail?.trim().toLowerCase();
    if (e == null) return null;
    final ok = e.contains('@') && e.contains('.') && e.length >= 6 && e.length <= 254;
    return ok ? e : null;
  }

  int get _day1Entries {
    final ladder = widget.giveaway?.streakLadder;
    return (ladder != null && ladder.isNotEmpty) ? ladder.first : 10;
  }

  bool get _canSubmit =>
      _isAdult && (_lockedEmail != null || winrV2IsValidEmail(_email.text));

  /// Validation error visible? Only for the editable field, only once
  /// touched, and only for a non-empty invalid value (an empty field dims
  /// the CTA but never scolds).
  bool get _showsEmailError =>
      _lockedEmail == null &&
      _emailTouched &&
      _email.text.trim().isNotEmpty &&
      !winrV2IsValidEmail(_email.text);

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus &&
          _email.text.trim().isNotEmpty &&
          !winrV2IsValidEmail(_email.text)) {
        setState(() => _emailTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _emailFocus.dispose();
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
                    if (_showsEmailError || widget.submitError != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            // Validation wins: a malformed address must be
                            // fixed before a transport retry means anything.
                            _showsEmailError
                                ? WINRV2Strings.invalidEmail
                                : widget.submitError!,
                            style: WINRV2Font.inter(
                              13,
                              color: WINRV2Colors.errorRed,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ageCheckbox(),
                    const SizedBox(height: 10),
                    _marketingConsentCheckbox(),
                    const SizedBox(height: 14),
                    WINRV2PillButton(
                      accent: widget.accent,
                      title: 'CLAIM MY $_day1Entries ENTRIES',
                      isLoading: widget.isSubmitting,
                      enabled: _canSubmit,
                      onTap: () => widget.onSubmit(
                        _lockedEmail ?? _email.text.trim(),
                        ageConfirmed: _isAdult,
                        marketingConsent: _marketingConsent,
                      ),
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
                  style: WINRV2Font.inter(12, color: WINRV2Colors.textTertiary),
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
          if (_lockedEmail != null) ...[
            // Read-only but VISIBLE: the user must see exactly which address
            // they are consenting for. Text, not a disabled field, so no
            // keyboard affordance appears.
            Expanded(
              child: Text(
                _lockedEmail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WINRV2Font.inter(16, color: WINRV2Colors.gunmetal),
              ),
            ),
            Semantics(
              label: 'Email provided by this app',
              child: Icon(
                Icons.lock,
                size: 14,
                color: WINRV2Colors.gunmetal.withValues(alpha: 0.45),
              ),
            ),
          ] else
            Expanded(
              child: TextField(
                controller: _email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                // A keyboard "done" is a submit attempt — the error may show
                // even though the dimmed CTA swallowed the tap.
                onSubmitted: (_) => setState(() => _emailTouched = true),
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

  Widget _ageCheckbox() => _checkbox(
        checked: _isAdult,
        label: 'I confirm I am 18 years of age or older',
        onTap: () => setState(() => _isAdult = !_isAdult),
      );

  /// MARKETING consent (unchecked by default), sitting directly under the age
  /// gate and styled identically to it (see [_checkbox]).
  Widget _marketingConsentCheckbox() => _checkbox(
        checked: _marketingConsent,
        label: widget.marketingConsentText?.isNotEmpty == true
            ? widget.marketingConsentText!
            : winrV2DefaultMarketingConsentText,
        onTap: () => setState(() => _marketingConsent = !_marketingConsent),
      );

  /// One checkbox row — box size, glyph treatment, spacing, color, text style
  /// and tap target are defined ONCE here so both rows are pixel-identical.
  Widget _checkbox({
    required bool checked,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 22,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(label, style: WINRV2Font.inter(14)),
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

  /// Reveal flow (Day 2+): the celebration is the dashboard's FIRST VISIBLE
  /// FRAME. The experience stages a PREDICTED grant before this view mounts,
  /// the UI renders one imperceptible pinned "before" frame, and the reveal
  /// (tile flip + confetti burst + count-up; the bar opens ON the toast)
  /// fires ~0.15s after mount — no claim tap, no modal.
  final int? pendingClaimEntries;
  final bool revealed;

  /// Non-blocking notice above the prize card (duplicate same-day entry,
  /// failed auto-claim); [onNoticeRetry] adds a TRY AGAIN affordance.
  final String? notice;
  final VoidCallback? onNoticeRetry;

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
    this.notice,
    this.onNoticeRetry,
  });

  bool get _visitMode => giveaway?.isVisitMode ?? false;

  // Pinned while today is unclaimed OR the reveal hasn't played — matching
  // the experience controller. Without the claimedToday clause the current
  // tile animates at claim-response time, ~1s BEFORE the count-up/toast beat.
  bool get _preReveal =>
      !revealed && (pendingClaimEntries != null || !claimedToday);

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
                  if (notice != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 22, right: 22, bottom: 15),
                      child: WINRV2DashboardNotice(
                        accent: accent,
                        notice: notice!,
                        onRetry: onNoticeRetry,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: WINRV2PrizeCard(
                      accent: accent,
                      // Pre-reveal the streak label still reads yesterday's
                      // day; the auto-reveal advances it to today.
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
                    // Celebration open: the bar's FIRST visible frame is
                    // the toast — "YOU'RE IN!" on Day 1, "YOU'RE ON A
                    // ROLL!" on Day 2+ — which holds a beat and slides once
                    // to the resting pitch. Non-celebration opens rest on
                    // the pitch with no toast.
                    celebrating: pendingClaimEntries != null,
                    firstDay: streakDay <= 1,
                    claimedEntries: pendingClaimEntries ?? entriesToday,
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    // Always GOT IT (Slice prototype) — the celebration
                    // plays on its own; the pill only ever closes.
                    child: WINRV2PillButton(
                      accent: accent,
                      title: 'GOT IT',
                      onTap: onClose,
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
// How it works
// ---------------------------------------------------------------------------

/// The "Privacy choices" → delete-my-data confirmation's phase:
///
///     idle → confirming → inFlight → done → (dismiss whole experience)
///                     ↘ failed (inline error, retryable) ↗
///
/// Failure NEVER pretends success — the confirmation stays up with the error
/// and the destructive button remains available to retry.
enum WINRV2OptOutPhase { idle, confirming, inFlight, failed, done }

class WINRV2HowItWorksView extends StatefulWidget {
  final Color accent;
  final String? logoUrl;
  final int day1Entries;
  final bool visitMode;
  final VoidCallback onDone;
  final VoidCallback onClose;

  /// Performs the RTD opt-out (the experience wires `WINR.optOut`). MUST
  /// throw on failure so the confirmation can show an honest error instead
  /// of pretending the deletion succeeded. Null (previews/tests that don't
  /// care) renders the link but treats a confirm as a failure.
  final Future<void> Function()? optOutAction;

  /// How long "Your data has been deleted." holds before [onClose] fires.
  static const Duration optOutSuccessHold = Duration(milliseconds: 1400);

  const WINRV2HowItWorksView({
    super.key,
    required this.accent,
    required this.logoUrl,
    required this.day1Entries,
    this.visitMode = false,
    required this.onDone,
    required this.onClose,
    this.optOutAction,
  });

  @override
  State<WINRV2HowItWorksView> createState() => _WINRV2HowItWorksViewState();
}

class _WINRV2HowItWorksViewState extends State<WINRV2HowItWorksView> {
  WINRV2OptOutPhase _optOutPhase = WINRV2OptOutPhase.idle;

  void _showOptOutConfirmation() {
    if (_optOutPhase != WINRV2OptOutPhase.idle) return;
    setState(() => _optOutPhase = WINRV2OptOutPhase.confirming);
  }

  void _cancelOptOut() {
    if (_optOutPhase != WINRV2OptOutPhase.confirming &&
        _optOutPhase != WINRV2OptOutPhase.failed) {
      return;
    }
    setState(() => _optOutPhase = WINRV2OptOutPhase.idle);
  }

  Future<void> _confirmOptOut() async {
    if (_optOutPhase != WINRV2OptOutPhase.confirming &&
        _optOutPhase != WINRV2OptOutPhase.failed) {
      return;
    }
    setState(() => _optOutPhase = WINRV2OptOutPhase.inFlight);
    try {
      final action = widget.optOutAction;
      if (action == null) throw StateError('optOutAction not wired');
      await action();
      if (!mounted) return;
      setState(() => _optOutPhase = WINRV2OptOutPhase.done);
      // Hold the success copy a beat, then dismiss the WHOLE experience.
      await Future<void>.delayed(WINRV2HowItWorksView.optOutSuccessHold);
      if (!mounted) return;
      widget.onClose();
    } catch (_) {
      if (!mounted) return;
      setState(() => _optOutPhase = WINRV2OptOutPhase.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _content(),
        if (_optOutPhase != WINRV2OptOutPhase.idle) _optOutDialog(),
      ],
    );
  }

  Widget _content() {
    final accent = widget.accent;
    final logoUrl = widget.logoUrl;
    final day1Entries = widget.day1Entries;
    final visitMode = widget.visitMode;
    final onDone = widget.onDone;
    final onClose = widget.onClose;
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
                  const SizedBox(height: 18),
                  // Muted privacy opt-out entry point — deliberately quiet:
                  // present for those who look for it, invisible to the pitch.
                  GestureDetector(
                    onTap: _showOptOutConfirmation,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        WINRV2Strings.privacyChoices,
                        style: WINRV2Font.inter(
                          12,
                          color: WINRV2Colors.textTertiary,
                        ).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The destructive confirmation (and its in-flight / failed / deleted
  /// states) — same scrim-plus-card treatment as the winners dialog.
  Widget _optOutDialog() {
    final inFlight = _optOutPhase == WINRV2OptOutPhase.inFlight;
    return Stack(
      children: [
        GestureDetector(
          onTap: inFlight ? null : _cancelOptOut,
          child: const ColoredBox(
            color: Color(0x8C000000),
            child: SizedBox.expand(),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () {}, // swallow taps inside the card
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: WINRV2Colors.deepCharcoal,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _optOutPhase == WINRV2OptOutPhase.done
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              WINRV2Strings.optOutSuccess,
                              textAlign: TextAlign.center,
                              style: WINRV2Font.inter(
                                18,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ]
                      : [
                          Text(
                            WINRV2Strings.optOutTitle,
                            textAlign: TextAlign.center,
                            style: WINRV2Font.inter(
                              18,
                              weight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            WINRV2Strings.optOutBody,
                            textAlign: TextAlign.center,
                            style: WINRV2Font.inter(
                              14,
                              color: const Color(0xBFFFFFFF),
                              height: 1.3,
                            ),
                          ),
                          if (_optOutPhase == WINRV2OptOutPhase.failed) ...[
                            const SizedBox(height: 14),
                            Text(
                              WINRV2Strings.optOutFailed,
                              textAlign: TextAlign.center,
                              style: WINRV2Font.inter(
                                13,
                                color: WINRV2Colors.errorRed,
                                height: 1.3,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          WINRV2PillButton(
                            accent: WINRV2Colors.errorRed,
                            title: WINRV2Strings.optOutConfirm,
                            isLoading: inFlight,
                            onTap: _confirmOptOut,
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: inFlight ? null : _cancelOptOut,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                WINRV2Strings.optOutCancel,
                                style: WINRV2Font.inter(
                                  14,
                                  color: WINRV2Colors.textTertiary,
                                ).copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static void _noop() {}

  Widget _item(String number, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$number.', style: WINRV2Font.inter(18, weight: FontWeight.w900)),
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

/// Verification code entry — shown when the typed email matches an EXISTING
/// account and the OTP gate is on. One numeric field, auto-submits at 6 digits.
class WINRV2CodeEntryView extends StatefulWidget {
  const WINRV2CodeEntryView({
    super.key,
    required this.accent,
    required this.logoUrl,
    required this.rulesUrl,
    required this.email,
    required this.isVerifying,
    required this.errorText,
    required this.onSubmit,
    required this.onResend,
    required this.onInfo,
    required this.onClose,
  });

  final Color accent;
  final String? logoUrl;
  final String? rulesUrl;
  final String email;
  final bool isVerifying;
  final String? errorText;
  final void Function(String code) onSubmit;
  final VoidCallback onResend;
  final VoidCallback onInfo;
  final VoidCallback onClose;

  @override
  State<WINRV2CodeEntryView> createState() => _WINRV2CodeEntryViewState();
}

class _WINRV2CodeEntryViewState extends State<WINRV2CodeEntryView> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WINRV2Colors.deepCharcoal,
      child: SafeArea(
        child: Column(
          children: [
            WINRV2Header(
              logoUrl: widget.logoUrl,
              onInfo: widget.onInfo,
              onClose: widget.onClose,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Column(
                  children: [
                    Text(
                      'CHECK YOUR EMAIL',
                      textAlign: TextAlign.center,
                      style: WINRV2Font.inter(28,
                          weight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This email is already part of a WINR streak. Enter the '
                      '6-digit code we sent to ${widget.email} to pick it up '
                      'on this device.',
                      textAlign: TextAlign.center,
                      style: WINRV2Font.inter(14,
                          color: Colors.white.withValues(alpha: 0.75)),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textAlign: TextAlign.center,
                        style: WINRV2Font.inter(22,
                            weight: FontWeight.w700,
                            color: WINRV2Colors.gunmetal),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          counterText: '',
                          hintText: '••••••',
                          hintStyle: WINRV2Font.inter(22,
                              color:
                                  WINRV2Colors.gunmetal.withValues(alpha: 0.4)),
                        ),
                        onChanged: (v) {
                          // Auto-submit on the sixth digit.
                          final digits = v.replaceAll(RegExp(r'\D'), '');
                          if (digits.length == 6 && !widget.isVerifying) {
                            widget.onSubmit(digits);
                          }
                        },
                      ),
                    ),
                    if (widget.errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.errorText!,
                        textAlign: TextAlign.center,
                        style: WINRV2Font.inter(13,
                            color: WINRV2Colors.errorRed),
                      ),
                    ],
                    const SizedBox(height: 16),
                    WINRV2PillButton(
                      accent: widget.accent,
                      title: 'VERIFY',
                      isLoading: widget.isVerifying,
                      enabled: !widget.isVerifying,
                      onTap: () {
                        final digits =
                            _code.text.replaceAll(RegExp(r'\D'), '');
                        if (digits.length == 6) widget.onSubmit(digits);
                      },
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: widget.onResend,
                      // Two-tone: the question reads as copy, the underlined
                      // action reads as a control.
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                          text: "Didn't get it? ",
                          style: WINRV2Font.inter(14,
                              color: Colors.white.withValues(alpha: 0.65)),
                        ),
                        TextSpan(
                          text: 'Send a new code',
                          style: WINRV2Font.inter(14,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF7FB0FF))
                              .copyWith(
                                  decoration: TextDecoration.underline,
                                  decorationColor: const Color(0xFF7FB0FF)),
                        ),
                      ])),
                    ),
                  ],
                ),
              ),
            ),
            // Same legal footer as the capture screen — one consent flow, one
            // footer; without it the sheet trails off into a void.
            WINRV2LegalLinks(rulesUrl: widget.rulesUrl, showPoweredBy: true),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
