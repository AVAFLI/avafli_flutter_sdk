// Winner prize-claim flow (Joe's stepped Figma design): winner splash →
// stepped form + review → confirmation with the OFFICIAL WINNER card.
// Shown when the giveaway payload carries prizeClaim.status == "pending".
//
// Mirrors the iOS SDK's WINRV2Claim.swift + WINRV2ClaimSteps/.
//
// Photo step note: iOS/Android step 3 ("SHOW OFF YOUR WIN!") attaches an
// optional photo via the system pickers. This package deliberately has no
// image-picker dependency (pure-Dart SDK, no heavy plugins), so the photo
// step is SKIPPED on Flutter and the flow renumbers to 3 steps
// (about you → address → story/share) — showing a step whose only actions
// are disabled would be a dead end. The photo is OPTIONAL in the backend
// contract (functions/src/prizeclaim.ts) and
// `SubmitPrizeClaimRequest.photoBase64` stays wired for future use.
//
// Social share note: pure-Dart has no system share sheet either, so the
// step's social glyphs copy the winner line to the clipboard with a small
// "Copied to clipboard!" confirmation.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'winr_v2_components.dart';
import 'winr_v2_strings.dart';
import 'winr_v2_theme.dart';

// ---------------------------------------------------------------------------
// Form model + validation
// ---------------------------------------------------------------------------

/// The claim form's field values. Kept as a plain value type so validation is
/// unit-testable without any widget machinery (mirrors iOS
/// `WINRPrizeClaimForm`).
class WINRPrizeClaimForm {
  String firstName;
  String lastName;
  String phone;
  String street;
  String apt;
  String city;
  String state;
  String zip;

  /// Fixed — US-only sweepstakes.
  final String country = 'United States';

  /// JPEG/PNG base64 of the optional attached photo (already capped ≤5MB).
  /// Always null on Flutter — see the photo note at the top of this file.
  String? photoBase64;

  /// Optional "please share a little" story (the story step). Sent trimmed;
  /// omitted when empty.
  String story;

  /// Explicit consents (Joe's "review and agree" checkboxes). All three are
  /// REQUIRED for submit, and PRE-CHECKED by default (CTO decision, Aug
  /// 2026) — the user can still untick any of them on the review screen,
  /// which disables SUBMIT until re-affirmed.
  bool confirmsAccuracy;
  bool authorizesLikeness;
  bool agreesToRules;

  WINRPrizeClaimForm({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.street = '',
    this.apt = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.photoBase64,
    this.story = '',
    this.confirmsAccuracy = true,
    this.authorizesLikeness = true,
    this.agreesToRules = true,
  });

  static bool isValidZip(String zip) {
    final z = zip.trim();
    return z.length == 5 && RegExp(r'^\d{5}$').hasMatch(z);
  }

  /// Name characters per the Master Field List: unicode letters plus
  /// spaces, apostrophes (straight or curly), hyphens, and periods.
  static final RegExp _nameChars =
      RegExp(r"^[\p{L} .'’\-]+$", unicode: true);
  static final RegExp _anyLetter = RegExp(r'\p{L}', unicode: true);

  /// A valid first/last name: non-empty trimmed, allowed characters only,
  /// at least one actual letter, max 50 characters.
  static bool isValidName(String raw) {
    final t = raw.trim();
    return t.isNotEmpty &&
        t.length <= 50 &&
        _nameChars.hasMatch(t) &&
        _anyLetter.hasMatch(t);
  }

  /// Normalizes a typed phone to 10 US digits: strips every non-digit and
  /// drops a leading country "1" (keeping the last 10). Returns null when
  /// the result isn't exactly 10 digits.
  static String? normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }
    return digits.length == 10 ? digits : null;
  }

  /// Phone stays OPTIONAL: blank is fine; anything typed must normalize to
  /// 10 digits (see [normalizePhone]).
  static bool isValidOptionalPhone(String raw) =>
      raw.trim().isEmpty || normalizePhone(raw) != null;

  // ── Per-step validity (stepped flow) ──

  /// Step 1 "TELL US ABOUT YOURSELF": valid first + last name (email is
  /// server-side); phone is optional but must be a real 10-digit US number
  /// when present.
  bool get isStep1Valid =>
      isValidName(firstName) &&
      isValidName(lastName) &&
      isValidOptionalPhone(phone);

  /// Step 2 "WHERE SHOULD WE SEND YOUR PRIZE?": full US shipping address.
  bool get isStep2Valid =>
      street.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      state.trim().isNotEmpty &&
      isValidZip(zip);

  // The story step is fully optional — always advanceable.

  /// All three review-screen consents affirmed.
  bool get hasAllConsents =>
      confirmsAccuracy && authorizesLikeness && agreesToRules;

  /// SUBMIT enables when every required field across the steps is present,
  /// the zip is a 5-digit US code, and all three consents are affirmed.
  /// Phone, apartment, and story are optional.
  bool get isValid => isStep1Valid && isStep2Valid && hasAllConsents;

  /// "First L." — the public display name on the winner card.
  String get displayName {
    final first = firstName.trim();
    final last = lastName.trim();
    final lastInitial = last.isEmpty ? '' : ' ${last[0]}.';
    return '$first$lastInitial';
  }

  static const List<String> usStates = [
    'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado',
    'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho',
    'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana',
    'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota',
    'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada',
    'New Hampshire', 'New Jersey', 'New Mexico', 'New York',
    'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon',
    'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota',
    'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington',
    'West Virginia', 'Wisconsin', 'Wyoming',
  ];
}

// ---------------------------------------------------------------------------
// Date helper
// ---------------------------------------------------------------------------

/// Mirrors iOS `WINRClaimDates`.
class WINRClaimDates {
  WINRClaimDates._();

  static const List<String> _months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  /// "AUGUST, 2026" from an ISO date string (falls back to [now] / the current
  /// date) — the winner card's award line.
  static String monthYearDisplay(String? iso, {DateTime? now}) {
    final date = _parseIso(iso) ?? now ?? DateTime.now();
    return '${_months[date.month - 1]}, ${date.year}';
  }

  static DateTime? _parseIso(String? value) {
    if (value == null || value.isEmpty) return null;
    // Handles internet date-time with/without fractional seconds and plain
    // "yyyy-MM-dd" (DateTime.tryParse accepts all three).
    return DateTime.tryParse(value);
  }
}

// ---------------------------------------------------------------------------
// Shared chrome
// ---------------------------------------------------------------------------

/// Claim-flow header: publisher logo centered, X close only (no "?").
class _WINRClaimHeader extends StatelessWidget {
  final String? logoUrl;
  final VoidCallback onClose;

  const _WINRClaimHeader({required this.logoUrl, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 210, maxHeight: 60),
              child: _logo(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: WINRV2Colors.deepCharcoal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    final url = logoUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const SizedBox.shrink(),
      );
    }
    return Text('WINR', style: WINRV2Font.inter(28, weight: FontWeight.w900));
  }
}

/// Dark info card with a leading icon (shield/mail) — splash + confirmation.
class _WINRClaimInfoCard extends StatelessWidget {
  final Widget icon;
  final Widget content;

  const _WINRClaimInfoCard({required this.icon, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF), // white 8%
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 14),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Winner splash ("CONGRATULATIONS!")
// ---------------------------------------------------------------------------

class WINRV2WinnerSplashView extends StatelessWidget {
  final Color accent;
  final String? logoUrl;
  final String prizeHeadline;
  final VoidCallback onContinue;
  final VoidCallback onClose;

  const WINRV2WinnerSplashView({
    super.key,
    required this.accent,
    required this.logoUrl,
    required this.prizeHeadline,
    required this.onContinue,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WINRV2Colors.deepCharcoal,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 18),
            _WINRClaimHeader(logoUrl: logoUrl, onClose: onClose),
            const SizedBox(height: 4),
            _trophyArt(),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'CONGRATULATIONS!',
                  maxLines: 1,
                  style: WINRV2Font.inter(
                    34,
                    weight: FontWeight.w900,
                    letterSpacing: -1.0,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            Text(
              'YOU’RE OUR LATEST WINNER!',
              style: WINRV2Font.inter(
                17,
                weight: FontWeight.w900,
                color: accent,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 18),
            Text('You’ve won:', style: WINRV2Font.inter(14)),
            const SizedBox(height: 8),
            // Full-width white strip with the prize-derived headline
            // (same derivation as the Day-1 capture strip).
            Container(
              width: double.infinity,
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  prizeHeadline,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: WINRV2Font.inter(
                    28,
                    weight: FontWeight.w900,
                    color: WINRV2Colors.gunmetal,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                'To process your prize, we just need a few details.',
                textAlign: TextAlign.center,
                style: WINRV2Font.inter(15),
              ),
            ),
            const SizedBox(height: 14),
            _WINRClaimInfoCard(
              icon: Icon(Icons.shield_outlined, size: 26, color: accent),
              content: Text(
                'Your information is securely collected and only used to '
                'verify your prize and announce you as our winner.',
                style: WINRV2Font.inter(13, height: 1.25),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: WINRV2PillButton(
                accent: accent,
                title: 'CONTINUE',
                onTap: onContinue,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// Trophy over the gold-sparkle art (bundled winner-modal-bg + trophy).
  Widget _trophyArt() {
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -2 * 3.1415926535 / 180,
            child: SizedBox(
              width: 300,
              height: 260,
              child: ClipRect(
                child: Image.asset(
                  WINRV2Assets.winnerModalBg,
                  package: WINRV2Assets.package,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Image.asset(
            WINRV2Assets.trophy,
            package: WINRV2Assets.package,
            height: 230,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stepped claim form (Joe's Figma flow) — 3 steps + review on Flutter
// ---------------------------------------------------------------------------
// Ported from iOS WINRV2ClaimSteps/: a persistent gold-sparkle backdrop +
// header + animated step indicator, with the form steps and the review
// screen sliding horizontally beneath them (push left on advance, push right
// on back). Flutter SKIPS the photo step (no image-picker dependency — see
// the note at the top of this file) and renumbers to 3 steps: about you →
// address → story/share, then review.

/// Field styling from the claim-step frames: #212832 fill, #3D424B border, r10.
class _WINRStepTheme {
  _WINRStepTheme._();

  static const Color fieldFill = Color(0xFF212832);
  static const Color fieldBorder = Color(0xFF3D424B);

  static BoxDecoration get fieldDecoration => BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fieldBorder),
      );
}

/// Total numbered steps on Flutter (photo step skipped — see file header).
const int _kClaimStepCount = 3;

/// 1..3 are the numbered steps; 4 is the review screen (no indicator).
const int _kClaimReviewStep = 4;

class WINRV2ClaimStepsFlow extends StatefulWidget {
  final Color accent;
  final String? logoUrl;

  /// Destination of the Official Rules / Privacy Policy consent links (the
  /// same URL the dashboard legal links open). Null → the links are inert.
  final String? rulesUrl;

  /// Backend-masked winning email ("d********r@winr.example.com"); null for
  /// older backends → generic locked copy.
  final String? maskedEmail;

  /// The prize-derived headline ("$1,000.00 CASH PRIZE") — used for the
  /// story step's copied share line.
  final String prizeHeadline;

  /// Host-app-provided identity prefill (first/last name, phone).
  final WINRPrizeClaimForm initialForm;
  final bool isSubmitting;

  /// Transport-level submit failure surfaced inline on the review screen
  /// ("Not the winner"/"Already submitted" instead fall back to the
  /// dashboard silently).
  final String? submitError;
  final ValueChanged<WINRPrizeClaimForm> onSubmit;
  final VoidCallback onClose;

  const WINRV2ClaimStepsFlow({
    super.key,
    required this.accent,
    required this.logoUrl,
    this.rulesUrl,
    this.maskedEmail,
    required this.prizeHeadline,
    required this.initialForm,
    required this.isSubmitting,
    required this.submitError,
    required this.onSubmit,
    required this.onClose,
  });

  @override
  State<WINRV2ClaimStepsFlow> createState() => _WINRV2ClaimStepsFlowState();
}

class _WINRV2ClaimStepsFlowState extends State<WINRV2ClaimStepsFlow> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _street;
  late final TextEditingController _apt;
  late final TextEditingController _city;
  late final TextEditingController _zip;
  late final TextEditingController _story;
  String _state = '';

  // Joe's "review and agree" consents — PRE-CHECKED (CTO decision, Aug 2026);
  // unticking any of them disables SUBMIT.
  late bool _confirmsAccuracy;
  late bool _authorizesLikeness;
  late bool _agreesToRules;

  /// 1..3 form steps, 4 = review.
  int _step = 1;

  /// Direction of the last navigation — drives the slide edges.
  bool _advancing = true;

  /// Transient "Copied to clipboard!" confirmation on the story step.
  bool _shareCopied = false;

  late final TapGestureRecognizer _rulesTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    final form = widget.initialForm;
    _firstName = TextEditingController(text: form.firstName);
    _lastName = TextEditingController(text: form.lastName);
    _phone = TextEditingController(text: form.phone);
    _street = TextEditingController(text: form.street);
    _apt = TextEditingController(text: form.apt);
    _city = TextEditingController(text: form.city);
    _zip = TextEditingController(text: form.zip);
    _story = TextEditingController(text: form.story);
    _state = form.state;
    _confirmsAccuracy = form.confirmsAccuracy;
    _authorizesLikeness = form.authorizesLikeness;
    _agreesToRules = form.agreesToRules;
    _rulesTap = TapGestureRecognizer()..onTap = _openRules;
    _privacyTap = TapGestureRecognizer()..onTap = _openRules;
    for (final c in [
      _firstName, _lastName, _phone, _street, _apt, _city, _zip, _story,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _phone, _street, _apt, _city, _zip, _story,
    ]) {
      c.dispose();
    }
    _rulesTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  /// Official Rules / Privacy Policy destination — the same URL the
  /// dashboard's legal links open.
  void _openRules() {
    final url = widget.rulesUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  WINRPrizeClaimForm get _form => WINRPrizeClaimForm(
        firstName: _firstName.text,
        lastName: _lastName.text,
        phone: _phone.text,
        street: _street.text,
        apt: _apt.text,
        city: _city.text,
        state: _state,
        zip: _zip.text,
        story: _story.text,
        confirmsAccuracy: _confirmsAccuracy,
        authorizesLikeness: _authorizesLikeness,
        agreesToRules: _agreesToRules,
      );

  void _go(int next) {
    if (next == _step || next < 1 || next > _kClaimReviewStep) return;
    setState(() {
      _advancing = next > _step;
      _step = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: WINRV2Colors.deepCharcoal),
        // Gold-sparkle full-bleed backdrop fading into the dark body, per
        // the frames (406px, transparent → deepCharcoal).
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 406,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  WINRV2Assets.winnerModalBg,
                  package: WINRV2Assets.package,
                  fit: BoxFit.cover,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.05, 0.6, 1],
                      colors: [
                        Color(0x1A0B0D12), // deepCharcoal 10%
                        Color(0x990B0D12), // deepCharcoal 60%
                        Color(0xFF0B0D12), // deepCharcoal
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 18),
            _header(),
            AnimatedOpacity(
              opacity: _step == _kClaimReviewStep ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _stepIndicator(),
              ),
            ),
            Expanded(child: _pages()),
          ],
        ),
      ],
    );
  }

  /// Persistent header: back chevron (steps 2+ / review), publisher logo,
  /// X close.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 210, maxHeight: 60),
              child: _headerLogo(),
            ),
          ),
          if (_step > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                label: 'Back',
                button: true,
                child: GestureDetector(
                  key: const ValueKey('claim-back'),
                  onTap: () => _go(_step - 1),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xD90B0D12), // deepCharcoal 85%
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: WINRV2Colors.deepCharcoal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerLogo() {
    final url = widget.logoUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const SizedBox.shrink(),
      );
    }
    return Text('WINR', style: WINRV2Font.inter(28, weight: FontWeight.w900));
  }

  /// "STEP N OF 3" + the row of dots connected by accent lines: filled with
  /// the accent up to the current step, outlined after it.
  Widget _stepIndicator() {
    final current = _step > _kClaimStepCount ? _kClaimStepCount : _step;
    return Semantics(
      label: 'Step $current of $_kClaimStepCount',
      child: Column(
        children: [
          Text(
            'STEP $current OF $_kClaimStepCount',
            style: WINRV2Font.inter(
              17,
              weight: FontWeight.w600,
              letterSpacing: -0.85,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= _kClaimStepCount; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? widget.accent
                        : const Color(0x990B0D12),
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.accent, width: 1.5),
                  ),
                ),
                if (i < _kClaimStepCount)
                  Container(width: 29, height: 1.5, color: widget.accent),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Steps push left when advancing and right when going back (300ms).
  Widget _pages() {
    final incomingKey = ValueKey<int>(_step);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          final incoming = child.key == incomingKey;
          final begin = incoming
              ? (_advancing ? const Offset(1, 0) : const Offset(-1, 0))
              : (_advancing ? const Offset(-1, 0) : const Offset(1, 0));
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero)
                .animate(animation),
            child: child,
          );
        },
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        child: KeyedSubtree(key: incomingKey, child: _pageFor(_step)),
      ),
    );
  }

  Widget _pageFor(int step) {
    switch (step) {
      case 1:
        return _step1();
      case 2:
        return _step2();
      case 3:
        return _step3();
      default:
        return _review();
    }
  }

  // ── Page scaffold: title / subtitle / content / CTA pill / footer ──

  Widget _page({
    required String title,
    String? subtitle,
    String ctaTitle = 'CONTINUE',
    bool ctaEnabled = true,
    bool ctaLoading = false,
    required VoidCallback onCTA,
    Widget? footer,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: WINRV2Font.inter(
                27,
                weight: FontWeight.w900,
                letterSpacing: -0.81,
                height: 1.15,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: WINRV2Font.inter(
                  18,
                  weight: FontWeight.w500,
                  letterSpacing: -0.54,
                  height: 1.2,
                ),
              ),
            ],
            ...children,
            const SizedBox(height: 21),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: WINRV2PillButton(
                accent: widget.accent,
                title: ctaTitle,
                isLoading: ctaLoading,
                enabled: ctaEnabled,
                onTap: onCTA,
              ),
            ),
            if (footer != null) footer,
            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }

  // ── Step 1: TELL US ABOUT YOURSELF ──

  /// Inline error for a NAME field: shown only once something invalid is
  /// actually typed (an empty field dims CONTINUE but never scolds).
  String? _nameError(TextEditingController controller, String message) {
    final text = controller.text;
    if (text.trim().isEmpty) return null;
    return WINRPrizeClaimForm.isValidName(text) ? null : message;
  }

  /// Inline error for the OPTIONAL phone: blank is fine; anything typed
  /// must normalize to 10 US digits or CONTINUE stays blocked.
  String? get _phoneError {
    final text = _phone.text;
    if (text.trim().isEmpty) return null;
    return WINRPrizeClaimForm.normalizePhone(text) == null
        ? WINRV2Strings.invalidPhone
        : null;
  }

  Widget _step1() {
    return _page(
      title: 'TELL US ABOUT YOURSELF',
      subtitle: "We'll use this information to verify your prize and "
          'personalize your winner announcement.',
      ctaEnabled: _form.isStep1Valid,
      onCTA: () => _go(2),
      children: [
        const SizedBox(height: 34),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              _WINRStepField(
                label: 'First Name',
                controller: _firstName,
                errorText:
                    _nameError(_firstName, WINRV2Strings.invalidFirstName),
              ),
              const SizedBox(height: 21),
              _WINRStepField(
                label: 'Last Name (we will only show your last initial)',
                controller: _lastName,
                errorText: _nameError(_lastName, WINRV2Strings.invalidLastName),
              ),
              const SizedBox(height: 21),
              // The winning email lives server-side (the SDK never stores
              // the raw address) and the claim is keyed to the account —
              // shown locked, masked by the backend for recognition.
              _WINRStepLockedField(
                label: 'Winning Email Address (cannot be changed)',
                value: widget.maskedEmail ?? 'On file with your winning entry',
              ),
              const SizedBox(height: 21),
              _WINRStepField(
                label: 'Phone Number (optional)',
                controller: _phone,
                keyboardType: TextInputType.phone,
                errorText: _phoneError,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2: WHERE SHOULD WE SEND YOUR PRIZE? ──

  Widget _step2() {
    return _page(
      title: 'WHERE SHOULD WE\nSEND YOUR PRIZE?',
      ctaEnabled: _form.isStep2Valid,
      onCTA: () => _go(3),
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              _WINRStepField(label: 'Street Address', controller: _street),
              const SizedBox(height: 21),
              _WINRStepField(
                label: 'Apartment, Suite, etc. (optional)',
                controller: _apt,
              ),
              const SizedBox(height: 21),
              _WINRStepField(label: 'City', controller: _city),
              const SizedBox(height: 21),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _statePicker()),
                  const SizedBox(width: 13),
                  SizedBox(
                    width: 101,
                    child: _WINRStepField(
                      label: 'Zip Code',
                      controller: _zip,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 21),
              // US-only sweepstakes — the country row renders like the
              // frame's dropdown but is fixed.
              const _WINRStepLockedField(
                label: 'Country',
                value: 'United States',
                dimmed: false,
                showsChevron: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The State dropdown: same box styling, menu of the 50 states, chevron.
  Widget _statePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WINRStepFieldLabel('State'),
        const SizedBox(height: 6),
        PopupMenuButton<String>(
          initialValue: _state.isEmpty ? null : _state,
          color: WINRV2Colors.deepCharcoal,
          constraints: const BoxConstraints(maxHeight: 400),
          onSelected: (value) => setState(() => _state = value),
          itemBuilder: (context) => [
            for (final state in WINRPrizeClaimForm.usStates)
              PopupMenuItem<String>(
                value: state,
                child: Text(state, style: WINRV2Font.inter(15)),
              ),
          ],
          child: Container(
            height: 59,
            padding: const EdgeInsets.symmetric(horizontal: 25),
            decoration: _WINRStepTheme.fieldDecoration,
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _state.isEmpty ? 'Select' : _state,
                      maxLines: 1,
                      style: WINRV2Font.inter(
                        20,
                        color: _state.isEmpty
                            ? const Color(0x4DFFFFFF) // white 30%
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: Color(0xB3FFFFFF),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 3: PLEASE SHARE A LITTLE (story + social) ──

  static const String _storyPlaceholder =
      'Please share anything. What you’re going to do with the prize, why '
      'you love our app, your favorite food, etc.';

  /// Generic winner line for the social buttons. Pure-Dart has no system
  /// share sheet, so tapping a glyph copies it to the clipboard.
  String get _shareLine => 'I just won ${widget.prizeHeadline}!';

  void _share() {
    Clipboard.setData(ClipboardData(text: _shareLine));
    setState(() => _shareCopied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _shareCopied = false);
    });
  }

  Widget _step3() {
    return _page(
      title: 'PLEASE SHARE A LITTLE',
      subtitle: 'This helps us show real people like you win!',
      onCTA: () => _go(_kClaimReviewStep),
      children: [
        const SizedBox(height: 29),
        // 199px multiline text area in the Figma field styling.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            height: 215,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: _WINRStepTheme.fieldDecoration,
            child: TextField(
              controller: _story,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: WINRV2Font.inter(20, height: 1.25),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: _storyPlaceholder,
                hintStyle:
                    WINRV2Font.inter(20, color: const Color(0x99FFFFFF)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 38),
        Text(
          'Share on Social Media:',
          style: WINRV2Font.inter(
            18,
            weight: FontWeight.w500,
            letterSpacing: -0.54,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final kind in _WINRSocialGlyphKind.values) ...[
              if (kind != _WINRSocialGlyphKind.values.first)
                const SizedBox(width: 26),
              Semantics(
                label: 'Share on ${kind.displayName}',
                button: true,
                child: GestureDetector(
                  onTap: _share,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _WINRSocialGlyph(kind: kind),
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(
          height: 24,
          child: AnimatedOpacity(
            opacity: _shareCopied ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Copied to clipboard!',
                style: WINRV2Font.inter(12, color: const Color(0xB3FFFFFF)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Review: ALMOST DONE! ──

  Widget _review() {
    return _page(
      title: 'ALMOST DONE!',
      subtitle: 'Please review and agree to claim your prize.',
      ctaTitle: 'SUBMIT PRIZE CLAIM',
      ctaEnabled: _form.isValid,
      ctaLoading: widget.isSubmitting,
      onCTA: () => widget.onSubmit(_form),
      footer: Padding(
        padding: const EdgeInsets.only(top: 30, left: 12, right: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
          decoration: BoxDecoration(
            color: WINRV2Colors.gunmetal,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.lock, size: 26, color: widget.accent),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Your information is secure and encrypted.',
                  style: WINRV2Font.inter(14),
                ),
              ),
            ],
          ),
        ),
      ),
      children: [
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _consentSection(),
        ),
        const SizedBox(height: 12),
        if (widget.submitError != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.submitError!,
              textAlign: TextAlign.center,
              style: WINRV2Font.inter(
                13,
                weight: FontWeight.w600,
                color: const Color(0xFFFF7366),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Joe's "review and agree" consents — pre-checked; all three required
  /// before SUBMIT.
  Widget _consentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WINRClaimConsentRow(
          key: const ValueKey('consent-accuracy'),
          accent: widget.accent,
          isOn: _confirmsAccuracy,
          onToggle: () =>
              setState(() => _confirmsAccuracy = !_confirmsAccuracy),
          label: const TextSpan(
            text: 'I confirm my information is accurate.',
          ),
        ),
        const SizedBox(height: 32),
        _WINRClaimConsentRow(
          key: const ValueKey('consent-likeness'),
          accent: widget.accent,
          isOn: _authorizesLikeness,
          onToggle: () =>
              setState(() => _authorizesLikeness = !_authorizesLikeness),
          label: const TextSpan(
            text: "I authorize this app's publisher and its promotional "
                'partners to use my name, city, profile photo, and likeness '
                'for winner announcements and promotional purposes.',
          ),
        ),
        const SizedBox(height: 32),
        _WINRClaimConsentRow(
          key: const ValueKey('consent-rules'),
          accent: widget.accent,
          isOn: _agreesToRules,
          onToggle: () => setState(() => _agreesToRules = !_agreesToRules),
          label: TextSpan(
            children: [
              const TextSpan(text: 'I agree to the '),
              TextSpan(
                text: 'Official Rules',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
                recognizer: _rulesTap,
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
                recognizer: _privacyTap,
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single consent checkbox row (accent square check + wrapping label).
/// Tapping anywhere on the row toggles; the underlined Official Rules /
/// Privacy Policy spans open their URL instead via their tap recognizers.
class _WINRClaimConsentRow extends StatelessWidget {
  final Color accent;
  final bool isOn;
  final VoidCallback onToggle;
  final TextSpan label;

  const _WINRClaimConsentRow({
    super.key,
    required this.accent,
    required this.isOn,
    required this.onToggle,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isOn,
      child: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isOn ? accent : const Color(0x12FFFFFF), // white 7%
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isOn ? accent : const Color(0x66FFFFFF), // white 40%
                  width: 1.5,
                ),
              ),
              child: isOn
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: WINRV2Font.inter(16, height: 1.3),
                  children: [label],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 12px field label above the box.
class _WINRStepFieldLabel extends StatelessWidget {
  final String text;

  const _WINRStepFieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: WINRV2Font.inter(12),
      ),
    );
  }
}

/// A labeled claim-step text field per the frames: 12px label, 59px box,
/// #212832 fill / #3D424B 1px border / r10, 20px input text. An optional
/// [errorText] renders inline under the box in the shared error red.
class _WINRStepField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;

  const _WINRStepField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WINRStepFieldLabel(label),
        const SizedBox(height: 6),
        Container(
          height: 59,
          padding: const EdgeInsets.symmetric(horizontal: 25),
          decoration: _WINRStepTheme.fieldDecoration,
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            autocorrect: false,
            enableSuggestions: false,
            style: WINRV2Font.inter(20),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              errorText!,
              style: WINRV2Font.inter(13, color: WINRV2Colors.errorRed),
            ),
          ),
        ],
      ],
    );
  }
}

/// A locked (non-editable) field — the winning email and Country rows. Shows
/// dimmed text; [showsChevron] mimics the Country dropdown from the frame.
class _WINRStepLockedField extends StatelessWidget {
  final String label;
  final String value;
  final bool dimmed;
  final bool showsChevron;

  const _WINRStepLockedField({
    required this.label,
    required this.value,
    this.dimmed = true,
    this.showsChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WINRStepFieldLabel(label),
        const SizedBox(height: 6),
        Container(
          height: 59,
          padding: const EdgeInsets.symmetric(horizontal: 25),
          decoration: _WINRStepTheme.fieldDecoration,
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: WINRV2Font.inter(
                      20,
                      color: dimmed
                          ? const Color(0x4DFFFFFF) // white 30%
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              if (showsChevron)
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: Color(0xB3FFFFFF),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Social glyphs (step 3) ──
// Simple white vector glyphs for the "Share on Social Media:" row
// (Instagram / Facebook / X / Snapchat / TikTok), drawn in-code so the SDK
// ships no third-party brand assets (mirrors iOS WINRV2ClaimSocialIcons).

enum _WINRSocialGlyphKind {
  instagram('Instagram'),
  facebook('Facebook'),
  x('X'),
  snapchat('Snapchat'),
  tiktok('TikTok');

  const _WINRSocialGlyphKind(this.displayName);

  final String displayName;
}

class _WINRSocialGlyph extends StatelessWidget {
  final _WINRSocialGlyphKind kind;

  const _WINRSocialGlyph({required this.kind});

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _WINRSocialGlyphKind.instagram:
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 3.2),
                ),
              ),
              Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.2),
                ),
              ),
              Transform.translate(
                offset: const Offset(11.5, -11.5),
                child: Container(
                  width: 4.5,
                  height: 4.5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      case _WINRSocialGlyphKind.facebook:
        return Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Transform.translate(
              offset: const Offset(2, 1),
              child: Text(
                'f',
                style: WINRV2Font.inter(
                  30,
                  weight: FontWeight.w700,
                  color: WINRV2Colors.deepCharcoal,
                ),
              ),
            ),
          ),
        );
      case _WINRSocialGlyphKind.x:
        return Center(
          child: Text(
            'X',
            style: WINRV2Font.inter(36, weight: FontWeight.w900),
          ),
        );
      case _WINRSocialGlyphKind.snapchat:
        return const Center(
          child: CustomPaint(
            size: Size(38, 38),
            painter: _WINRGhostPainter(),
          ),
        );
      case _WINRSocialGlyphKind.tiktok:
        return const Center(
          child: Icon(Icons.music_note, size: 38, color: Colors.white),
        );
    }
  }
}

/// A simplified Snapchat-style ghost: dome head, straight sides flaring into
/// little "arms", and a three-bump scalloped bottom (same path as iOS
/// WINRGhostShape).
class _WINRGhostPainter extends CustomPainter {
  const _WINRGhostPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0.18 * w, 0.42 * h)
      // Dome head.
      ..quadraticBezierTo(0.5 * w, -0.28 * h, 0.82 * w, 0.42 * h)
      // Right side down, flaring out.
      ..lineTo(0.82 * w, 0.62 * h)
      ..quadraticBezierTo(0.86 * w, 0.78 * h, 0.97 * w, 0.86 * h)
      // Scalloped bottom (three bumps).
      ..quadraticBezierTo(0.82 * w, 0.98 * h, 0.66 * w, 0.88 * h)
      ..quadraticBezierTo(0.5 * w, 1.02 * h, 0.34 * w, 0.88 * h)
      ..quadraticBezierTo(0.18 * w, 0.98 * h, 0.03 * w, 0.86 * h)
      // Left flare back up.
      ..quadraticBezierTo(0.14 * w, 0.78 * h, 0.18 * w, 0.62 * h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Confirmation ("YOUR PRIZE CLAIM HAS BEEN SUBMITTED")
// ---------------------------------------------------------------------------

class WINRV2ClaimConfirmationView extends StatelessWidget {
  final Color accent;
  final String? logoUrl;
  final WINRPrizeClaimForm? form;
  final String claimNumber;
  final String submittedAt;
  final VoidCallback onDone;

  const WINRV2ClaimConfirmationView({
    super.key,
    required this.accent,
    required this.logoUrl,
    required this.form,
    required this.claimNumber,
    required this.submittedAt,
    required this.onDone,
  });

  // Gold palette (mirrors iOS `Gold`).
  static const Color _goldText = Color(0xFFB88C29);
  static const Color _goldBorder = Color(0xFFD4AD47);
  static const Color _creamTop = Color(0xFFFFFAEB);
  static const Color _creamBottom = Color(0xFFF2E0AD);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WINRV2Colors.deepCharcoal,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 18),
            _WINRClaimHeader(logoUrl: logoUrl, onClose: onDone),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                'YOUR PRIZE CLAIM HAS BEEN SUBMITTED',
                textAlign: TextAlign.center,
                style: WINRV2Font.inter(
                  26,
                  weight: FontWeight.w900,
                  letterSpacing: -0.7,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Text(
                'Our team is reviewing your information. You’ll receive a '
                'confirmation email shortly.',
                textAlign: TextAlign.center,
                style: WINRV2Font.inter(
                  15,
                  color: const Color(0xD9FFFFFF),
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _WINRClaimInfoCard(
              icon: Icon(Icons.mail_outline, size: 26, color: accent),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expect to receive your prize within',
                    style: WINRV2Font.inter(14),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '3-5 Business Days',
                    style: WINRV2Font.inter(
                      18,
                      weight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: _winnerCard(),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: WINRV2PillButton(
                accent: accent,
                title: 'RETURN TO APP',
                onTap: onDone,
              ),
            ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }

  /// The gold OFFICIAL WINNER keepsake card: cream/gold gradient, small
  /// trophy breaking the top border, serif name, award month + claim number.
  Widget _winnerCard() {
    final city = form?.city.trim() ?? '';
    final state = form?.state.trim() ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_creamTop, _creamBottom],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _goldBorder, width: 2),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 26, right: 26, top: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OFFICIAL',
                      style: WINRV2Font.inter(
                        16,
                        weight: FontWeight.w900,
                        color: _goldText,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'WINNER',
                      style: WINRV2Font.inter(
                        16,
                        weight: FontWeight.w900,
                        color: _goldText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    form?.displayName.trim().isNotEmpty == true
                        ? form!.displayName
                        : 'Our Winner',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1712),
                      fontFamily: 'Georgia',
                      fontFamilyFallback: ['Times New Roman', 'serif'],
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              if (city.isNotEmpty)
                Text(
                  '$city, $state',
                  style: WINRV2Font.inter(14, color: const Color(0xFF737373)),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '${WINRClaimDates.monthYearDisplay(submittedAt)} • $claimNumber',
                  style: WINRV2Font.inter(
                    11,
                    weight: FontWeight.w700,
                    color: _goldText,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        // The little trophy sits centered ON the border, breaking it.
        Positioned(
          top: -27,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              WINRV2Assets.trophy,
              package: WINRV2Assets.package,
              height: 54,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}
