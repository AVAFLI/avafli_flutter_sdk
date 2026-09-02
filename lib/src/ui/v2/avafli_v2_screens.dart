// The V2 experience screens, matched to the Figma flows: new-user capture,
// return-user dashboard, celebration modal, and how-it-works. Publisher can
// customize ONLY: logo, prize image, primary color. Everything else is
// hardcoded to the design or derived from the prize.
//
// Mirrors the iOS SDK's AvafliV2Screens.swift.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/giveaway.dart';
import 'avafli_v2_components.dart';
import 'avafli_v2_legal.dart';
import 'avafli_v2_strings.dart';
import 'avafli_v2_theme.dart';
import 'avafli_v2_winner.dart';

/// Email shape check shared by the capture CTA gate and the inline error, so
/// the two can never disagree (an enabled CTA under a visible error, or vice
/// versa). Deliberately a SHAPE check only — the server revalidates.
bool avafliV2IsValidEmail(String raw) {
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
class AvafliV2LoadingView extends StatefulWidget {
  const AvafliV2LoadingView({super.key});

  @override
  State<AvafliV2LoadingView> createState() => _AvafliV2LoadingViewState();
}

class _AvafliV2LoadingViewState extends State<AvafliV2LoadingView>
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
      color: AvafliV2Colors.gunmetal,
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
              const AvafliV2TabGrabber(),
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
class AvafliV2EmptyStateView extends StatelessWidget {
  final Color accent;
  final VoidCallback onClose;

  const AvafliV2EmptyStateView({
    super.key,
    required this.accent,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nothing to see here yet',
            style: AvafliV2Font.inter(20, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Check back soon for your next chance to win!',
            style: AvafliV2Font.inter(14, color: AvafliV2Colors.textTertiary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: AvafliV2PillButton(
              accent: accent,
              title: 'CLOSE',
              onTap: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

/// Geo-blocked (`AvafliError.geographyNotAllowed`) — a DEDICATED state, not the
/// generic empty state: the person needs to know WHY there's nothing here
/// (US-only sweepstakes) and that it isn't an outage on our side.
class AvafliV2GeoBlockedView extends StatelessWidget {
  final Color accent;
  final VoidCallback onClose;

  const AvafliV2GeoBlockedView({
    super.key,
    required this.accent,
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
              AvafliV2Strings.geoBlockedHeadline,
              textAlign: TextAlign.center,
              style: AvafliV2Font.inter(20, weight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              AvafliV2Strings.geoBlockedBody,
              textAlign: TextAlign.center,
              style: AvafliV2Font.inter(
                14,
                color: AvafliV2Colors.textTertiary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: AvafliV2PillButton(
                accent: accent,
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
class AvafliV2SessionExpiredView extends StatelessWidget {
  final Color accent;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const AvafliV2SessionExpiredView({
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
              AvafliV2Strings.sessionExpired,
              textAlign: TextAlign.center,
              style:
                  AvafliV2Font.inter(16, weight: FontWeight.w600, height: 1.3),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: AvafliV2PillButton(
                accent: accent,
                title: AvafliV2Strings.retry,
                onTap: onRetry,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'CLOSE',
                style: AvafliV2Font.inter(
                  14,
                  weight: FontWeight.w700,
                  color: AvafliV2Colors.textTertiary,
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
class AvafliV2DashboardNotice extends StatelessWidget {
  final Color accent;
  final String notice;
  final VoidCallback? onRetry;

  const AvafliV2DashboardNotice({
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
          Text(notice, style: AvafliV2Font.inter(13, height: 1.35)),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onRetry,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  AvafliV2Strings.tryAgain,
                  style: AvafliV2Font.inter(
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
typedef AvafliV2CaptureSubmit = void Function(
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
const String avafliV2DefaultMarketingConsentText =
    'I agree to receive marketing emails from this app';

/// SDK default for the AGE-GATE line, used only when the server sends no
/// `ageGateText` AND no configured minimum age reaches this widget. The
/// canonical fallback is BUILT from the publisher's minimum age
/// ([AvafliSdkConfig.resolvedAgeGateText]); this literal is the last-resort
/// offline default (minimum age 18).
const String avafliV2DefaultAgeGateText =
    'I confirm I am 18 years of age or older';

class AvafliV2CaptureView extends StatefulWidget {
  final Color accent;
  final String? logoUrl;
  final String? rulesUrl;
  final Giveaway? giveaway;
  final bool isSubmitting;
  final AvafliV2CaptureSubmit onSubmit;
  final VoidCallback onInfo;
  final VoidCallback onClose;

  /// Server-supplied consent copy; null → [avafliV2DefaultMarketingConsentText].
  final String? marketingConsentText;

  /// Fully-resolved AGE-GATE label (server text, else a sentence built from
  /// the publisher's minimum age); null → [avafliV2DefaultAgeGateText]. Passed
  /// pre-resolved so this widget never hardcodes a minimum age.
  final String? ageGateText;

  /// Inline, retryable submit failure from the experience (e.g. the email
  /// POST died in transit). Rendered under the email field in the same error
  /// styling as validation; the user stays here and can try again.
  final String? submitError;

  const AvafliV2CaptureView({
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
    this.ageGateText,
    this.prefilledEmail,
    this.submitError,
  });

  /// Partner-authenticated email (AvafliUser.email). Well-formed → rendered
  /// pre-filled and READ-ONLY; malformed or null → the editable field.
  final String? prefilledEmail;

  @override
  State<AvafliV2CaptureView> createState() => _AvafliV2CaptureViewState();
}

class _AvafliV2CaptureViewState extends State<AvafliV2CaptureView> {
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

  /// Tap recognizers for the Official Rules / Privacy Policy spans inside the
  /// legal sentence — the sentence IS the legal entry point here (the separate
  /// links row was removed from this screen; other screens keep theirs).
  /// Rules opens [AvafliV2CaptureView.rulesUrl]; the policy span opens the real
  /// policy at [avafliV2PrivacyPolicyUrl] — both in the in-app legal webview
  /// (2.9.4), no longer the external browser.
  late final TapGestureRecognizer _rulesTap;
  late final TapGestureRecognizer _privacyTap;

  /// Shape check only — the server revalidates. Its job is to pick pre-fill
  /// vs editable, so a partner bug degrades to the normal typed flow instead
  /// of locking a garbage value into a read-only field.
  String? get _lockedEmail {
    final e = widget.prefilledEmail?.trim().toLowerCase();
    if (e == null) return null;
    final ok =
        e.contains('@') && e.contains('.') && e.length >= 6 && e.length <= 254;
    return ok ? e : null;
  }

  int get _day1Entries {
    final ladder = widget.giveaway?.streakLadder;
    return (ladder != null && ladder.isNotEmpty) ? ladder.first : 10;
  }

  bool get _canSubmit =>
      _isAdult && (_lockedEmail != null || avafliV2IsValidEmail(_email.text));

  /// Validation error visible? Only for the editable field, only once
  /// touched, and only for a non-empty invalid value (an empty field dims
  /// the CTA but never scolds).
  bool get _showsEmailError =>
      _lockedEmail == null &&
      _emailTouched &&
      _email.text.trim().isNotEmpty &&
      !avafliV2IsValidEmail(_email.text);

  @override
  void initState() {
    super.initState();
    _rulesTap = TapGestureRecognizer()..onTap = _openRules;
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => avafliV2OpenPrivacyPolicy(context);
    _email.addListener(() => setState(() {}));
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus &&
          _email.text.trim().isNotEmpty &&
          !avafliV2IsValidEmail(_email.text)) {
        setState(() => _emailTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _rulesTap.dispose();
    _privacyTap.dispose();
    _email.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  /// Opens the publisher's rules URL in the in-app legal webview, exactly as
  /// the AvafliV2LegalLinks rows on the other screens do.
  void _openRules() => avafliV2OpenOfficialRules(context, widget.rulesUrl);

  @override
  Widget build(BuildContext context) {
    // Natural dismissal (shared helper): tap on empty space or a drag on the
    // scrollable closes the keyboard; controls keep winning their taps.
    return AvafliV2KeyboardDismiss(
        child: Stack(
      fit: StackFit.expand,
      children: [
        // 2.9: the accent-blue radial glow is gone — the capture screen sits
        // on the SAME flat dark surface as the streak dashboard drawer
        // (AvafliV2Colors.gunmetal), so Day 1 and Day 2+ read as one product.
        const ColoredBox(color: AvafliV2Colors.gunmetal),
        // LayoutBuilder + minHeight + IntrinsicHeight let the Spacer below the
        // CTA push the legal block to the drawer's bottom edge on tall
        // screens, while short screens / a raised keyboard degrade to plain
        // scrolling (the Spacer collapses to zero; the SizedBox above the
        // legal block is the guaranteed minimum gap under the button).
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            // Keyboard-aware: inside the experience's resizing Scaffold this
            // resolves to 0; it guards hosts/tests without that chrome so the
            // email field and CTA always scroll clear of the keyboard.
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    AvafliV2Header(
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
                            // "EARN." carries the publisher's PRIMARY brand
                            // color (the same branding primary the CTAs
                            // use); VISIT. / WIN. stay white.
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'VISIT. '),
                                  TextSpan(
                                    text: 'EARN.',
                                    style: TextStyle(color: widget.accent),
                                  ),
                                  const TextSpan(text: ' WIN.'),
                                ],
                              ),
                              maxLines: 1,
                              style: AvafliV2Font.inter(
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
                            style:
                                AvafliV2Font.inter(15, weight: FontWeight.w700),
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
                          // Focusing the email field scrolls it (and the CTA
                          // below) clear of the software keyboard.
                          AvafliV2EnsureVisible(
                            focusNode: _emailFocus,
                            child: _emailField(),
                          ),
                          if (_showsEmailError ||
                              widget.submitError != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  // Validation wins: a malformed address must be
                                  // fixed before a transport retry means anything.
                                  _showsEmailError
                                      ? AvafliV2Strings.invalidEmail
                                      : widget.submitError!,
                                  style: AvafliV2Font.inter(
                                    13,
                                    color: AvafliV2Colors.errorRed,
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
                          AvafliV2PillButton(
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
                    // Anchors the legal block to the bottom of the drawer on tall
                    // screens; collapses to zero when space is tight so the
                    // SizedBox above the legal block stays the minimum CTA gap.
                    const Spacer(),
                    const SizedBox(height: 18),
                    // The single legal instance on this screen: the sentence itself
                    // carries the tappable, underlined Official Rules / Privacy
                    // Policy spans (the separate links row lives on other screens
                    // only).
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text.rich(
                        TextSpan(
                          style: AvafliV2Font.inter(
                            12,
                            color: AvafliV2Colors.textTertiary,
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  'Your email lets us contact you if you win. '
                                  'By entering you agree to the ',
                            ),
                            TextSpan(
                              text: 'Official Rules',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: AvafliV2Colors.textTertiary,
                              ),
                              recognizer: _rulesTap,
                            ),
                            const TextSpan(text: ' & '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: AvafliV2Colors.textTertiary,
                              ),
                              recognizer: _privacyTap,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Powered by © Avafli',
                      style: AvafliV2Font.inter(12,
                          color: AvafliV2Colors.textTertiary),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ));
  }

  /// PRIZE-derived white strip (Day-1 examples):
  /// cash → "$1,000.00 CASH PRIZE"; other → "Win a $500 Amazon Gift Card"
  /// + value line only when the description lacks the $amount.
  Widget _prizeStrip() {
    final description = widget.giveaway?.prizeDescription ?? '';
    final value = (widget.giveaway?.prizeValue ?? 0).toInt();
    final isCash = avafliV2IsCashPrize(description);
    final article = avafliV2Article(description);

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
                '\$${avafliV2FormatInt(value)}.00 CASH PRIZE',
                maxLines: 1,
                style: AvafliV2Font.inter(
                  24,
                  weight: FontWeight.w900,
                  color: AvafliV2Colors.gunmetal,
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
                  style: AvafliV2Font.inter(
                    23,
                    weight: FontWeight.w900,
                    color: AvafliV2Colors.gunmetal,
                    letterSpacing: -0.7,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            if (avafliV2ShowsValueLine(description, value))
              Text(
                '\$${avafliV2FormatInt(value)}.00 Value!',
                style: AvafliV2Font.inter(16, color: AvafliV2Colors.gunmetal),
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
            color: AvafliV2Colors.gunmetal.withValues(alpha: 0.6),
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
                style: AvafliV2Font.inter(16, color: AvafliV2Colors.gunmetal),
              ),
            ),
            Semantics(
              label: 'Email provided by this app',
              child: Icon(
                Icons.lock,
                size: 14,
                color: AvafliV2Colors.gunmetal.withValues(alpha: 0.45),
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
                style: AvafliV2Font.inter(16, color: AvafliV2Colors.gunmetal),
                cursorColor: AvafliV2Colors.gunmetal,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Enter your email address',
                  hintStyle: AvafliV2Font.inter(
                    16,
                    color: AvafliV2Colors.gunmetal.withValues(alpha: 0.5),
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
        label: widget.ageGateText?.isNotEmpty == true
            ? widget.ageGateText!
            : avafliV2DefaultAgeGateText,
        onTap: () => setState(() => _isAdult = !_isAdult),
      );

  /// MARKETING consent (unchecked by default), sitting directly under the age
  /// gate and styled identically to it (see [_checkbox]).
  Widget _marketingConsentCheckbox() => _checkbox(
        checked: _marketingConsent,
        label: widget.marketingConsentText?.isNotEmpty == true
            ? widget.marketingConsentText!
            : avafliV2DefaultMarketingConsentText,
        onTap: () => setState(() => _marketingConsent = !_marketingConsent),
      );

  /// One checkbox row — box size, glyph treatment, spacing, color, text style
  /// and tap target are defined ONCE here so both rows are pixel-identical.
  ///
  /// 2.9.3: both boxes are tinted the publisher's PRIMARY brand color —
  /// checked is a primary fill with a contrasting check (white on dark
  /// brands, gunmetal on light ones), unchecked is a primary-tinted border.
  Widget _checkbox({
    required bool checked,
    required String label,
    required VoidCallback onTap,
  }) {
    final accent = widget.accent;
    final checkColor = accent.computeLuminance() > 0.5
        ? AvafliV2Colors.gunmetal
        : Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: checked ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: checked ? accent : accent.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child:
                checked ? Icon(Icons.check, size: 16, color: checkColor) : null,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(label, style: AvafliV2Font.inter(14)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Return-user dashboard (Day 2+ drawer)
// ---------------------------------------------------------------------------

class AvafliV2DashboardView extends StatelessWidget {
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

  /// Server flag (`sdkConfig.experience.winnerBannerEnabled`): the winner
  /// banner + its winner-feed modal render ONLY when this is true. Defaults
  /// to false — hidden unless the server explicitly enables it (Aug 31 GTM
  /// decision; keeps GOT IT above the fold on small screens).
  final bool showWinnerBanner;

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

  /// Soft email-verification: while true (and [onVerifyTap] is wired) a small,
  /// persistent "Verify your email" chip sits near the top of the dashboard.
  /// It NEVER blocks play — tapping it opens the dismissible code screen.
  final bool unverified;
  final VoidCallback? onVerifyTap;

  const AvafliV2DashboardView({
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
    this.showWinnerBanner = false,
    this.pendingClaimEntries,
    this.revealed = true,
    this.notice,
    this.onNoticeRetry,
    this.unverified = false,
    this.onVerifyTap,
  });

  bool get _visitMode => giveaway?.isVisitMode ?? false;

  // Pinned while today is unclaimed OR the reveal hasn't played — matching
  // the experience controller. Without the claimedToday clause the current
  // tile animates at claim-response time, ~1s BEFORE the count-up/toast beat.
  bool get _preReveal =>
      !revealed && (pendingClaimEntries != null || !claimedToday);

  int _ladderValue(int day) => AvafliV2Ladder.entries(
        day: day,
        ladder: ladder,
        milestones: giveaway?.milestones,
      );

  int get _nextEntries => _ladderValue(streakDay + 1);

  List<AvafliV2RailEntry> get _railEntries {
    final entries = <AvafliV2RailEntry>[];
    final maxDay = streakDay + 2 > 31 ? streakDay + 2 : 31;
    final milestoneDays = <int, int>{
      for (final m in giveaway?.milestones ?? const <MilestoneConfig>[])
        m.day: m.bonusEntries,
    };
    for (var day = 1; day <= maxDay; day++) {
      final state = day < streakDay
          ? AvafliV2TileState.completed
          : (day == streakDay
              ? (_preReveal
                  ? AvafliV2TileState.ready
                  : AvafliV2TileState.active)
              : AvafliV2TileState.locked);
      entries.add(AvafliV2RailEntry.day(
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
        entries.add(AvafliV2RailEntry.powerUp(
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
      color: AvafliV2Colors.gunmetal,
      child: Column(
        children: [
          const SizedBox(height: 15),
          const AvafliV2TabGrabber(),
          const SizedBox(height: 15),
          AvafliV2Header(logoUrl: logoUrl, onInfo: onInfo, onClose: onClose),
          const SizedBox(height: 15),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Soft email-verification nudge — a gentle pill directly
                  // under the header, above the streak content. Persistent
                  // while unverified; never covers or gates the dashboard.
                  if (unverified && onVerifyTap != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 22, right: 22, bottom: 15),
                      child: AvafliV2VerifyEmailChip(
                        accent: accent,
                        onTap: onVerifyTap!,
                      ),
                    ),
                  // Server-flag-gated (sdkConfig.experience.winnerBannerEnabled,
                  // default hidden): even with a latestWinner present the
                  // banner — and the winner-feed modal it opens — only shows
                  // when [showWinnerBanner] is true.
                  if (showWinnerBanner &&
                      giveaway?.latestWinner != null &&
                      onWinnerTap != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: AvafliV2WinnerBanner(onTap: onWinnerTap!),
                    ),
                  if (notice != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 22, right: 22, bottom: 15),
                      child: AvafliV2DashboardNotice(
                        accent: accent,
                        notice: notice!,
                        onRetry: onNoticeRetry,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: AvafliV2PrizeCard(
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
                  AvafliV2StreakRail(
                    accent: accent,
                    entries: _railEntries,
                    activeID: 'day-$streakDay',
                    visitMode: _visitMode,
                  ),
                  const SizedBox(height: 15),
                  AvafliV2ComeBackBar(
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
                    child: AvafliV2PillButton(
                      accent: accent,
                      title: 'GOT IT',
                      onTap: onClose,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AvafliV2LegalLinks(rulesUrl: rulesUrl),
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

class AvafliV2HowItWorksView extends StatelessWidget {
  final Color accent;
  final String? logoUrl;
  final int day1Entries;
  final bool visitMode;
  final VoidCallback onDone;
  final VoidCallback onClose;

  const AvafliV2HowItWorksView({
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
      color: AvafliV2Colors.panel,
      child: Column(
        children: [
          const SizedBox(height: 18),
          // The back ARROW replaces the "?" in the header.
          AvafliV2Header(
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
              style: AvafliV2Font.inter(
                26,
                weight: FontWeight.w900,
                color: AvafliV2Colors.gunmetal,
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
                      style: AvafliV2Font.inter(
                        20,
                        weight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: AvafliV2PillButton(
                      accent: accent,
                      title: 'GOT IT - START MY STREAK',
                      onTap: onDone,
                    ),
                  ),
                  // 2.9.5: the muted "Privacy choices" entry is gone —
                  // the legal-links rows and the capture screen's inline
                  // Privacy Policy links keep the delete path findable
                  // (the delete section lives inside the privacy page,
                  // behind avafli://delete).
                  const SizedBox(height: 24),
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
            style: AvafliV2Font.inter(18, weight: FontWeight.w900)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AvafliV2Font.inter(18, weight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(body, style: AvafliV2Font.inter(16, height: 1.25)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Verification code entry — shown when the typed email matches an EXISTING
/// account and the OTP gate is on. One numeric field, auto-submits at 6 digits.
class AvafliV2CodeEntryView extends StatefulWidget {
  const AvafliV2CodeEntryView({
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
    this.title,
    this.subtitle,
    this.showsBack = false,
    this.onBack,
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

  /// Header copy override. Null → the cross-device adoption default
  /// ('CHECK YOUR EMAIL'); the soft email-verification flow passes its own.
  final String? title;

  /// Subtitle override. Null → the adoption default (interpolates [email]);
  /// the soft email-verification flow passes address-free copy.
  final String? subtitle;

  /// When true the header shows a back arrow (in place of the "?") that returns
  /// to the dashboard — the soft-verification flow is dismissible and gates
  /// nothing. The adoption flow leaves this false (that flow is a gate).
  final bool showsBack;
  final VoidCallback? onBack;

  @override
  State<AvafliV2CodeEntryView> createState() => _AvafliV2CodeEntryViewState();
}

class _AvafliV2CodeEntryViewState extends State<AvafliV2CodeEntryView> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Natural dismissal (shared helper): tap-anywhere / drag-to-scroll close
    // the keyboard, so the code screen never traps it over VERIFY.
    return AvafliV2KeyboardDismiss(
        child: Container(
      // 2.9.3 (Ryan): the code-entry screen sits on the SAME flat gunmetal
      // drawer surface as capture and the dashboard — no glow, no
      // off-drawer charcoal — so adoption/verify reads as the same product.
      color: AvafliV2Colors.gunmetal,
      child: SafeArea(
        child: Column(
          children: [
            AvafliV2Header(
              logoUrl: widget.logoUrl,
              showsBack: widget.showsBack,
              onBack: widget.onBack ?? widget.onInfo,
              onInfo: widget.onInfo,
              onClose: widget.onClose,
            ),
            Expanded(
              child: SingleChildScrollView(
                // Keyboard-aware bottom padding (0 inside the resizing
                // experience Scaffold; guards bare hosts/tests).
                padding: EdgeInsets.only(
                  left: 22,
                  right: 22,
                  top: 18,
                  bottom: 18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  children: [
                    Text(
                      widget.title ?? 'CHECK YOUR EMAIL',
                      textAlign: TextAlign.center,
                      style: AvafliV2Font.inter(28,
                          weight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.subtitle ??
                          'This email is already part of an Avafli streak. Enter '
                              'the 6-digit code we sent to ${widget.email} to '
                              'pick it up on this device.',
                      textAlign: TextAlign.center,
                      style: AvafliV2Font.inter(14,
                          color: Colors.white.withValues(alpha: 0.75)),
                    ),
                    const SizedBox(height: 22),
                    AvafliV2EnsureVisible(
                      focusNode: _codeFocus,
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _code,
                          focusNode: _codeFocus,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textAlign: TextAlign.center,
                          style: AvafliV2Font.inter(22,
                              weight: FontWeight.w700,
                              color: AvafliV2Colors.gunmetal),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: AvafliV2Font.inter(22,
                                color: AvafliV2Colors.gunmetal
                                    .withValues(alpha: 0.4)),
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
                    ),
                    if (widget.errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.errorText!,
                        textAlign: TextAlign.center,
                        style: AvafliV2Font.inter(13,
                            color: AvafliV2Colors.errorRed),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AvafliV2PillButton(
                      accent: widget.accent,
                      title: 'VERIFY',
                      isLoading: widget.isVerifying,
                      enabled: !widget.isVerifying,
                      onTap: () {
                        final digits = _code.text.replaceAll(RegExp(r'\D'), '');
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
                          style: AvafliV2Font.inter(14,
                              color: Colors.white.withValues(alpha: 0.65)),
                        ),
                        TextSpan(
                          text: 'Send a new code',
                          style: AvafliV2Font.inter(14,
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
            AvafliV2LegalLinks(rulesUrl: widget.rulesUrl, showPoweredBy: true),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ));
  }
}
