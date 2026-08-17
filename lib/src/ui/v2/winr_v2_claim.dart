// Winner prize-claim flow (Joe's stepped Figma design, 2.9 revision):
// winner splash → stepped form (about you → address) → review + SUBMIT →
// share/celebrate → confirmation with the OFFICIAL WINNER card.
// Shown when the giveaway payload carries prizeClaim.status == "pending".
//
// Mirrors the iOS SDK's WINRV2Claim.swift + WINRV2ClaimSteps/.
//
// 2.9 reorder (14 Aug team decision): the "PLEASE SHARE A LITTLE" step now
// comes AFTER submit — the claim is banked first, then the person is invited
// to share; closing the share screen loses nothing. The story textarea lives
// on the post-submit share screen and rides the new `attachClaimStory`
// callable (fire-and-forget; sent on DONE and on dismiss so a typed story is
// never lost) — it no longer rides the submitPrizeClaim payload.
//
// Photo step note: iOS/Android's "SHOW OFF YOUR WIN!" attaches an optional
// photo via the system pickers. This package deliberately has no
// image-picker dependency (pure-Dart SDK, no heavy plugins), so the photo
// step is SKIPPED on Flutter. The photo is OPTIONAL in the backend contract
// (functions/src/prizeclaim.ts) and `SubmitPrizeClaimRequest.photoBase64`
// stays wired for future use.
//
// Social share note (2.9): X opens the tweet intent with a prefilled winner
// line (+ publisher shareUrl when configured); Facebook opens the sharer
// with the shareUrl only (FB forbids prefilled text). Instagram / Snapchat /
// TikTok have no text-prefill APIs and this package ships no share-sheet
// plugin, so those (and Facebook without a shareUrl) copy the winner line to
// the clipboard with a "Copied — paste it in your post" confirmation.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../network/places_autocomplete.dart';
import 'winr_v2_components.dart';
import 'winr_v2_effects.dart';
import 'winr_v2_strings.dart';
import 'winr_v2_svg_icon.dart';
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

  /// Optional "please share a little" story. 2.9: the story is typed on the
  /// POST-submit share screen and rides the dedicated `attachClaimStory`
  /// callable — never this form's claim payload. Kept (like [photoBase64])
  /// only for request-shape compatibility.
  String story;

  /// The likeness/promo consent — the ONLY checkbox left on the review
  /// screen (14 Aug 2026 team decision). OPTIONAL: it never gates SUBMIT,
  /// and consent must be an affirmative act, so it starts UNCHECKED. The
  /// actual choice is sent as `promoConsentGranted` on the claim payload.
  bool promoConsentGranted;

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
    this.promoConsentGranted = false,
  });

  static bool isValidZip(String zip) {
    final z = zip.trim();
    return z.length == 5 && RegExp(r'^\d{5}$').hasMatch(z);
  }

  /// Name characters per the Master Field List: unicode letters plus
  /// spaces, apostrophes (straight or curly), hyphens, and periods.
  static final RegExp _nameChars = RegExp(r"^[\p{L} .'’\-]+$", unicode: true);
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

  /// SUBMIT enables when every required field across the steps is present
  /// and the zip is a 5-digit US code. Phone, apartment, and the promo
  /// consent are optional — consent NEVER gates submit (2.9).
  bool get isValid => isStep1Valid && isStep2Valid;

  /// "First L." — the public display name on the winner card.
  String get displayName {
    final first = firstName.trim();
    final last = lastName.trim();
    final lastInitial = last.isEmpty ? '' : ' ${last[0]}.';
    return '$first$lastInitial';
  }

  static const List<String> usStates = [
    'Alabama',
    'Alaska',
    'Arizona',
    'Arkansas',
    'California',
    'Colorado',
    'Connecticut',
    'Delaware',
    'District of Columbia',
    'Florida',
    'Georgia',
    'Hawaii',
    'Idaho',
    'Illinois',
    'Indiana',
    'Iowa',
    'Kansas',
    'Kentucky',
    'Louisiana',
    'Maine',
    'Maryland',
    'Massachusetts',
    'Michigan',
    'Minnesota',
    'Mississippi',
    'Missouri',
    'Montana',
    'Nebraska',
    'Nevada',
    'New Hampshire',
    'New Jersey',
    'New Mexico',
    'New York',
    'North Carolina',
    'North Dakota',
    'Ohio',
    'Oklahoma',
    'Oregon',
    'Pennsylvania',
    'Rhode Island',
    'South Carolina',
    'South Dakota',
    'Tennessee',
    'Texas',
    'Utah',
    'Vermont',
    'Virginia',
    'Washington',
    'West Virginia',
    'Wisconsin',
    'Wyoming',
  ];

  /// USPS code → the picker's canonical full name, so a Places-resolved
  /// `administrative_area_level_1` shortText ("CA") lands in the State
  /// dropdown as the same value a person would have picked ("California").
  static const Map<String, String> usStateNamesByCode = {
    'AL': 'Alabama',
    'AK': 'Alaska',
    'AZ': 'Arizona',
    'AR': 'Arkansas',
    'CA': 'California',
    'CO': 'Colorado',
    'CT': 'Connecticut',
    'DE': 'Delaware',
    'DC': 'District of Columbia',
    'FL': 'Florida',
    'GA': 'Georgia',
    'HI': 'Hawaii',
    'ID': 'Idaho',
    'IL': 'Illinois',
    'IN': 'Indiana',
    'IA': 'Iowa',
    'KS': 'Kansas',
    'KY': 'Kentucky',
    'LA': 'Louisiana',
    'ME': 'Maine',
    'MD': 'Maryland',
    'MA': 'Massachusetts',
    'MI': 'Michigan',
    'MN': 'Minnesota',
    'MS': 'Mississippi',
    'MO': 'Missouri',
    'MT': 'Montana',
    'NE': 'Nebraska',
    'NV': 'Nevada',
    'NH': 'New Hampshire',
    'NJ': 'New Jersey',
    'NM': 'New Mexico',
    'NY': 'New York',
    'NC': 'North Carolina',
    'ND': 'North Dakota',
    'OH': 'Ohio',
    'OK': 'Oklahoma',
    'OR': 'Oregon',
    'PA': 'Pennsylvania',
    'RI': 'Rhode Island',
    'SC': 'South Carolina',
    'SD': 'South Dakota',
    'TN': 'Tennessee',
    'TX': 'Texas',
    'UT': 'Utah',
    'VT': 'Vermont',
    'VA': 'Virginia',
    'WA': 'Washington',
    'WV': 'West Virginia',
    'WI': 'Wisconsin',
    'WY': 'Wyoming',
  };
}

// ---------------------------------------------------------------------------
// Date helper
// ---------------------------------------------------------------------------

/// Mirrors iOS `WINRClaimDates`.
class WINRClaimDates {
  WINRClaimDates._();

  static const List<String> _months = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
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
/// Defaults to the translucent white-8% fill; the confirmation screen passes
/// a solid gunmetal [fill] + subtle [borderColor] per Joe's 2.9.3 frame.
class _WINRClaimInfoCard extends StatelessWidget {
  final Widget icon;
  final Widget content;
  final Color fill;
  final Color? borderColor;

  const _WINRClaimInfoCard({
    required this.icon,
    required this.content,
    this.fill = const Color(0x14FFFFFF), // white 8%
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: borderColor == null ? null : Border.all(color: borderColor!),
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

class WINRV2WinnerSplashView extends StatefulWidget {
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
  State<WINRV2WinnerSplashView> createState() => _WINRV2WinnerSplashViewState();
}

class _WINRV2WinnerSplashViewState extends State<WINRV2WinnerSplashView> {
  /// One-shot celebration (2.9.3, Joe's frame): the confetti-burst GIF
  /// explodes once over the trophy art the moment the splash appears — the
  /// exact machinery the Day-2+ streak tile uses at its reveal beat — then
  /// removes itself via [WINRV2GifView.onFinished]. A gold drifting
  /// confetti field keeps sparkling over the art beneath it (see
  /// [_trophyArt]). Purely decorative: wrapped in [IgnorePointer] so it
  /// never blocks CONTINUE or the close X.
  bool _bursting = true;

  Color get accent => widget.accent;
  String? get logoUrl => widget.logoUrl;
  String get prizeHeadline => widget.prizeHeadline;
  VoidCallback get onContinue => widget.onContinue;
  VoidCallback get onClose => widget.onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WINRV2Colors.deepCharcoal,
      child: Stack(
        children: [
          Positioned.fill(child: _content()),
          // Confetti burst layer — over the trophy art, on appearance only.
          if (_bursting)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              height: 340,
              child: IgnorePointer(
                child: WINRV2GifView(
                  WINRV2Assets.confettiBurst,
                  onFinished: () {
                    if (mounted) setState(() => _bursting = false);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    return SingleChildScrollView(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          // Gold confetti drift over the art (same layer the winner modal
          // and the claim confirmation use).
          const Positioned.fill(
            child: IgnorePointer(
              child: WINRV2Confetti(
                style: WINRV2ConfettiStyle.gold,
                count: 26,
                speed: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stepped claim form (Joe's Figma flow, 2.9) — 2 steps + review on Flutter
// ---------------------------------------------------------------------------
// Ported from iOS WINRV2ClaimSteps/: a persistent gold-sparkle backdrop +
// header + animated step indicator, with the form steps and the review
// screen sliding horizontally beneath them (push left on advance, push right
// on back). Flutter SKIPS the photo step (no image-picker dependency — see
// the note at the top of this file), and 2.9 moved the share step AFTER
// submit ([WINRV2ClaimShareView]), so the numbered steps are: about you →
// address, then review + SUBMIT.

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

/// Total numbered steps on Flutter (photo step skipped, share step moved
/// post-submit — see file header).
const int _kClaimStepCount = 2;

/// 1..2 are the numbered steps; 3 is the review screen (no indicator).
const int _kClaimReviewStep = 3;

class WINRV2ClaimStepsFlow extends StatefulWidget {
  final Color accent;
  final String? logoUrl;

  /// Publisher display name from the server-fed `WinrSdkConfig.appName`
  /// (the same source the share line uses). Present → the likeness consent
  /// names the publisher; null/blank → generic wording. See
  /// [likenessConsentLabel].
  final String? appName;

  /// Backend-masked winning email ("d********r@winr.example.com"); null for
  /// older backends → generic locked copy.
  final String? maskedEmail;

  /// Host-app-provided identity prefill (first/last name, phone).
  final WINRPrizeClaimForm initialForm;

  /// Google Places (New) API key from `sdkConfig.placesApiKey`. Non-empty →
  /// the Street Address field offers address autocomplete; null/empty → the
  /// field is a plain text input (exactly the pre-autocomplete behavior).
  final String? placesApiKey;

  /// Test seam: an injected Places client (wins over [placesApiKey]).
  @visibleForTesting
  final WINRPlacesClient? placesClient;

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
    this.appName,
    this.maskedEmail,
    required this.initialForm,
    this.placesApiKey,
    this.placesClient,
    required this.isSubmitting,
    required this.submitError,
    required this.onSubmit,
    required this.onClose,
  });

  /// The likeness/promo consent copy (2.9.3, Joe's updated frame): names
  /// the actual app/publisher when the server-fed [appName] is present —
  /// Flutter's only publisher-name source, the same one the share line
  /// uses — and falls back to the generic wording otherwise.
  static String likenessConsentLabel(String? appName) {
    final name = appName?.trim();
    if (name == null || name.isEmpty) {
      return "(Optional) I authorize this app's publisher and its "
          'promotional partners to use my name, city, profile photo, and '
          'likeness for winner announcements and promotional purposes.';
    }
    return 'I authorize $name and its promotional partners to use my '
        'name, city, profile photo, and likeness for winner announcements '
        'and promotional purposes. (Optional)';
  }

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
  String _state = '';

  /// The likeness/promo consent — the only checkbox left on the review
  /// screen. Optional; never gates SUBMIT (2.9).
  late bool _promoConsent;

  /// 1..2 form steps, 3 = review.
  int _step = 1;

  /// Direction of the last navigation — drives the slide edges.
  bool _advancing = true;

  /// Street-field address autocomplete. Null when no `placesApiKey` was
  /// configured (and no test client injected) — the field is then a plain
  /// text input.
  WINRAddressAutocomplete? _places;
  WINRPlacesClient? _placesClient;

  /// Whether this state built [_placesClient] itself (and must dispose it);
  /// an injected test client belongs to the test.
  bool _ownsPlacesClient = false;

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
    _state = form.state;
    _promoConsent = form.promoConsentGranted;
    for (final c in [
      _firstName,
      _lastName,
      _phone,
      _street,
      _apt,
      _city,
      _zip,
    ]) {
      c.addListener(() => setState(() {}));
    }

    final injectedClient = widget.placesClient;
    final placesKey = widget.placesApiKey?.trim();
    final client = injectedClient ??
        ((placesKey != null && placesKey.isNotEmpty)
            ? WINRPlacesClient(apiKey: placesKey)
            : null);
    _placesClient = client;
    _ownsPlacesClient = injectedClient == null && client != null;
    _places = client == null ? null : WINRAddressAutocomplete(client: client);
  }

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _phone,
      _street,
      _apt,
      _city,
      _zip,
    ]) {
      c.dispose();
    }
    _places?.dispose();
    if (_ownsPlacesClient) _placesClient?.dispose();
    super.dispose();
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
        promoConsentGranted: _promoConsent,
      );

  void _go(int next) {
    if (next == _step || next < 1 || next > _kClaimReviewStep) return;
    // Leaving the address step must not leave a stale suggestions list
    // behind for the return trip.
    _places?.dismiss();
    setState(() {
      _advancing = next > _step;
      _step = next;
    });
  }

  /// A tapped street suggestion: resolve it to a full address and fill the
  /// four address fields (all stay hand-editable). Resolution failure →
  /// nothing changes — the person keeps typing (silent degradation).
  Future<void> _selectPlaceSuggestion(WINRPlaceSuggestion suggestion) async {
    final places = _places;
    if (places == null) return;
    final address = await places.select(suggestion);
    if (!mounted || address == null) return;
    setState(() {
      if (address.street.isNotEmpty) _street.text = address.street;
      if (address.city.isNotEmpty) _city.text = address.city;
      if (address.zip.isNotEmpty) _zip.text = address.zip;
      final stateName = _statePickerValue(address.state);
      if (stateName != null) _state = stateName;
    });
  }

  /// Maps the resolved `administrative_area_level_1` shortText ("CA") onto
  /// the State picker's canonical full name ("California"). Anything not a
  /// known USPS code passes through verbatim; empty → null (keep whatever
  /// the person already picked rather than wiping it).
  static String? _statePickerValue(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return null;
    return WINRPrizeClaimForm.usStateNamesByCode[code.toUpperCase()] ?? code;
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
                    color:
                        i <= current ? widget.accent : const Color(0x990B0D12),
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
      // Keyboard-aware: keep the last field and the CTA reachable above the
      // software keyboard. Inside the experience's resizing Scaffold the
      // inset is already consumed (this resolves to 0); the padding guards
      // hosts/tests that mount the flow without that chrome.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
              _WINRStreetAddressField(
                controller: _street,
                places: _places,
                onSuggestionTap: (suggestion) =>
                    unawaited(_selectPlaceSuggestion(suggestion)),
              ),
              const SizedBox(height: 21),
              _WINRStepField(
                label: 'Apartment, Suite, etc. (optional)',
                controller: _apt,
              ),
              const SizedBox(height: 21),
              _WINRStepField(label: 'City', controller: _city),
              const SizedBox(height: 21),
              // State + Zip row. The zip column used to be a fixed 101px —
              // with the field's 25px side padding that left ~50px for five
              // 20px digits, clipping the value (and the label) on narrow
              // screens. Flex-share the row instead (state names shrink via
              // their FittedBox) and relax the zip field's inner padding so
              // "12345" always fits whole.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 11, child: _statePicker()),
                  const SizedBox(width: 13),
                  Expanded(
                    flex: 9,
                    child: _WINRStepField(
                      label: 'Zip Code',
                      controller: _zip,
                      keyboardType: TextInputType.number,
                      horizontalPadding: 16,
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

  /// The State dropdown: same box styling, menu of the 50 states + DC, chevron.
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

  // ── Review: ALMOST DONE! ──

  Widget _review() {
    return _page(
      title: 'ALMOST DONE!',
      subtitle: 'Review your details and claim your prize.',
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

  /// 2.9.3 review consents (Joe's updated frame): ONLY the OPTIONAL
  /// likeness/promo checkbox — it never gates SUBMIT. The "By submitting
  /// you agree to…" sentence and its Official Rules / Privacy Policy links
  /// were removed from this screen entirely; the screen keeps just this
  /// checkbox, SUBMIT, and the secure-note.
  Widget _consentSection() {
    return _WINRClaimConsentRow(
      key: const ValueKey('consent-likeness'),
      accent: widget.accent,
      isOn: _promoConsent,
      onToggle: () => setState(() => _promoConsent = !_promoConsent),
      label: TextSpan(
        text: WINRV2ClaimStepsFlow.likenessConsentLabel(widget.appName),
      ),
    );
  }
}

/// A single consent checkbox row (accent square check + wrapping label).
/// Tapping anywhere on the row toggles.
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
///
/// Stateful (2.9): each field owns a [FocusNode] wrapped in
/// [WINRV2EnsureVisible], so focusing any field scrolls it — label, box, and
/// error — clear of the software keyboard even on small screens.
class _WINRStepField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;

  /// USER edits only (never programmatic `controller.text` fills) — the
  /// street field wires this to the autocomplete query stream so filling
  /// the field from a selected suggestion doesn't re-open the list.
  final ValueChanged<String>? onChanged;

  /// Inner side padding of the box. The frames use 25; tight columns (the
  /// zip field) pass less so the value never clips.
  final double horizontalPadding;

  const _WINRStepField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.errorText,
    this.onChanged,
    this.horizontalPadding = 25,
  });

  @override
  State<_WINRStepField> createState() => _WINRStepFieldState();
}

class _WINRStepFieldState extends State<_WINRStepField> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WINRV2EnsureVisible(
      focusNode: _focus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WINRStepFieldLabel(widget.label),
          const SizedBox(height: 6),
          Container(
            height: 59,
            padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
            decoration: _WINRStepTheme.fieldDecoration,
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              onChanged: widget.onChanged,
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
          if (widget.errorText != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                widget.errorText!,
                style: WINRV2Font.inter(13, color: WINRV2Colors.errorRed),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Street Address field. Without a Places setup ([places] == null) it is
/// exactly the plain [_WINRStepField] it always was. With one, typing
/// (debounced, min 3 chars — see [WINRAddressAutocomplete]) surfaces up to
/// five address suggestions in a dropdown card directly beneath the box,
/// styled like the other step fields. Tap → [onSuggestionTap] (the flow
/// resolves and fills the address); tap outside or the system back → the
/// list dismisses and typing continues untouched.
///
/// Keyboard safety: the card renders inline in the step's scrollable (which
/// already carries IME-aware bottom padding), and [_WINRAddressSuggestionsCard]
/// ensures itself visible when it appears — suggestions are never stranded
/// under the keyboard.
class _WINRStreetAddressField extends StatelessWidget {
  final TextEditingController controller;
  final WINRAddressAutocomplete? places;
  final ValueChanged<WINRPlaceSuggestion> onSuggestionTap;

  const _WINRStreetAddressField({
    required this.controller,
    required this.places,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final places = this.places;
    final field = _WINRStepField(
      label: 'Street Address',
      controller: controller,
      onChanged: places?.onQueryChanged,
    );
    if (places == null) return field;

    return ListenableBuilder(
      listenable: places,
      builder: (context, _) {
        final suggestions = places.suggestions;
        return PopScope(
          // System back with the list open closes the LIST, not the screen.
          canPop: suggestions.isEmpty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) places.dismiss();
          },
          child: TapRegion(
            onTapOutside: (_) => places.dismiss(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                if (suggestions.isNotEmpty)
                  _WINRAddressSuggestionsCard(
                    suggestions: suggestions,
                    onSuggestionTap: onSuggestionTap,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The dropdown card of street suggestions: field-styled dark card, one row
/// per suggestion, hairline dividers, and the required "powered by Google"
/// attribution row (mandatory when Places data is shown without a map).
class _WINRAddressSuggestionsCard extends StatefulWidget {
  final List<WINRPlaceSuggestion> suggestions;
  final ValueChanged<WINRPlaceSuggestion> onSuggestionTap;

  const _WINRAddressSuggestionsCard({
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  State<_WINRAddressSuggestionsCard> createState() =>
      _WINRAddressSuggestionsCardState();
}

class _WINRAddressSuggestionsCardState
    extends State<_WINRAddressSuggestionsCard> {
  @override
  void initState() {
    super.initState();
    // The card just appeared under the (focused, keyboard-up) street field —
    // scroll it clear of the keyboard. Composes with WINRV2EnsureVisible's
    // field centering: last write wins, and this one shows field + list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.7,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: _WINRStepTheme.fieldDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final suggestion in widget.suggestions) ...[
            Semantics(
              button: true,
              label: suggestion.description,
              child: GestureDetector(
                onTap: () => widget.onSuggestionTap(suggestion),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    suggestion.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WINRV2Font.inter(15, height: 1.25),
                  ),
                ),
              ),
            ),
            Container(height: 1, color: _WINRStepTheme.fieldBorder),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'powered by Google',
                style: WINRV2Font.inter(11, color: const Color(0x80FFFFFF)),
              ),
            ),
          ),
        ],
      ),
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

// ── Social glyphs (share step) ──
// The official WINR brand set for the "Share on Social Media:" row
// (Instagram / Facebook / X / Snapchat / TikTok): white fill glyphs authored
// in Figma as 48×48 SVG paths, rendered in-code via [WINRSvgIconPainter] so
// the SDK ships no asset bundle. Path data is verbatim from the brand SVGs —
// treat it as the source of truth and don't hand-edit.

enum _WINRSocialGlyphKind {
  instagram(
    'Instagram',
    [
      'M24 4.32187C30.4125 4.32187 31.1719 4.35 33.6938 4.4625C36.0375 '
          '4.56562 37.3031 4.95938 38.1469 5.2875C39.2625 5.71875 40.0688 '
          '6.24375 40.9031 7.07812C41.7469 7.92188 42.2625 8.71875 42.6938 '
          '9.83438C43.0219 10.6781 43.4156 11.9531 43.5188 14.2875C43.6313 '
          '16.8187 43.6594 17.5781 43.6594 23.9813C43.6594 30.3938 43.6313 '
          '31.1531 43.5188 33.675C43.4156 36.0188 43.0219 37.2844 42.6938 '
          '38.1281C42.2625 39.2438 41.7375 40.05 40.9031 40.8844C40.0594 '
          '41.7281 39.2625 42.2438 38.1469 42.675C37.3031 43.0031 36.0281 '
          '43.3969 33.6938 43.5C31.1625 43.6125 30.4031 43.6406 24 '
          '43.6406C17.5875 43.6406 16.8281 43.6125 14.3063 43.5C11.9625 '
          '43.3969 10.6969 43.0031 9.85313 42.675C8.7375 42.2438 7.93125 '
          '41.7188 7.09688 40.8844C6.25313 40.0406 5.7375 39.2438 5.30625 '
          '38.1281C4.97813 37.2844 4.58438 36.0094 4.48125 33.675C4.36875 '
          '31.1438 4.34063 30.3844 4.34063 23.9813C4.34063 17.5688 4.36875 '
          '16.8094 4.48125 14.2875C4.58438 11.9437 4.97813 10.6781 5.30625 '
          '9.83438C5.7375 8.71875 6.2625 7.9125 7.09688 7.07812C7.94063 '
          '6.23438 8.7375 5.71875 9.85313 5.2875C10.6969 4.95938 11.9719 '
          '4.56562 14.3063 4.4625C16.8281 4.35 17.5875 4.32187 24 '
          '4.32187ZM24 0C17.4844 0 16.6688 0.028125 14.1094 0.140625C11.5594 '
          '0.253125 9.80625 0.665625 8.2875 1.25625C6.70312 1.875 5.3625 '
          '2.69062 4.03125 4.03125C2.69063 5.3625 1.875 6.70313 1.25625 '
          '8.27813C0.665625 9.80625 0.253125 11.55 0.140625 14.1C0.028125 '
          '16.6687 0 17.4844 0 24C0 30.5156 0.028125 31.3312 0.140625 '
          '33.8906C0.253125 36.4406 0.665625 38.1938 1.25625 39.7125C1.875 '
          '41.2969 2.69063 42.6375 4.03125 43.9688C5.3625 45.3 6.70313 '
          '46.125 8.27813 46.7344C9.80625 47.325 11.55 47.7375 14.1 '
          '47.85C16.6594 47.9625 17.475 47.9906 23.9906 47.9906C30.5063 '
          '47.9906 31.3219 47.9625 33.8813 47.85C36.4313 47.7375 38.1844 '
          '47.325 39.7031 46.7344C41.2781 46.125 42.6188 45.3 43.95 '
          '43.9688C45.2812 42.6375 46.1063 41.2969 46.7156 39.7219C47.3063 '
          '38.1938 47.7188 36.45 47.8313 33.9C47.9438 31.3406 47.9719 '
          '30.525 47.9719 24.0094C47.9719 17.4938 47.9438 16.6781 47.8313 '
          '14.1188C47.7188 11.5688 47.3063 9.81563 46.7156 8.29688C46.125 '
          '6.70312 45.3094 5.3625 43.9688 4.03125C42.6375 2.7 41.2969 1.875 '
          '39.7219 1.26562C38.1938 0.675 36.45 0.2625 33.9 0.15C31.3313 '
          '0.028125 30.5156 0 24 0Z',
      'M24 11.6719C17.1938 11.6719 11.6719 17.1938 11.6719 24C11.6719 '
          '30.8062 17.1938 36.3281 24 36.3281C30.8062 36.3281 36.3281 '
          '30.8062 36.3281 24C36.3281 17.1938 30.8062 11.6719 24 '
          '11.6719ZM24 31.9969C19.5844 31.9969 16.0031 28.4156 16.0031 '
          '24C16.0031 19.5844 19.5844 16.0031 24 16.0031C28.4156 16.0031 '
          '31.9969 19.5844 31.9969 24C31.9969 28.4156 28.4156 31.9969 24 '
          '31.9969Z',
      'M39.6937 11.1843C39.6937 12.778 38.4 14.0624 36.8156 '
          '14.0624C35.2219 14.0624 33.9375 12.7687 33.9375 11.1843C33.9375 '
          '9.59053 35.2313 8.30615 36.8156 8.30615C38.4 8.30615 39.6937 '
          '9.5999 39.6937 11.1843Z',
    ],
  ),
  facebook(
    'Facebook',
    [
      'M24 0C10.7453 0 0 10.7453 0 24C0 35.255 7.74912 44.6995 18.2026 '
          '47.2934V31.3344H13.2538V24H18.2026V20.8397C18.2026 12.671 '
          '21.8995 8.8848 29.9194 8.8848C31.44 8.8848 34.0637 9.18336 '
          '35.137 9.48096V16.129C34.5706 16.0694 33.5866 16.0397 32.3645 '
          '16.0397C28.4294 16.0397 26.9088 17.5306 26.9088 '
          '21.4061V24H34.7482L33.4013 31.3344H26.9088V47.8243C38.7926 '
          '46.3891 48.001 36.2707 48.001 24C48 10.7453 37.2547 0 24 0Z',
    ],
  ),
  x(
    'X',
    [
      'M36.6526 3.8078H43.3995L28.6594 20.6548L46 43.5797H32.4225L21.7881 '
          '29.6759L9.61989 43.5797H2.86886L18.6349 25.56L2 '
          '3.8078H15.9222L25.5348 16.5165L36.6526 3.8078ZM34.2846 '
          '39.5414H38.0232L13.8908 7.63406H9.87892L34.2846 39.5414Z',
    ],
  ),
  snapchat(
    'Snapchat',
    [
      'M47.8265 34.9152C47.4955 34.0082 46.8582 33.5179 46.135 '
          '33.1257C46.0001 33.0522 45.8776 32.9786 45.7673 32.9296C45.5466 '
          '32.8193 45.326 32.709 45.1054 32.5986C42.8501 31.3974 41.085 '
          '29.9021 39.8716 28.1125C39.5284 27.61 39.2219 27.0707 38.9768 '
          '26.5191C38.8665 26.2249 38.8787 26.0533 38.9523 25.894C39.0258 '
          '25.7714 39.1239 25.6733 39.2464 25.5875C39.6387 25.3301 40.0309 '
          '25.0727 40.3006 24.9011C40.7786 24.5824 41.1708 24.3373 41.416 '
          '24.1657C42.3353 23.5161 42.9849 22.8297 43.3894 22.0575C43.9655 '
          '20.9788 44.039 19.7163 43.5977 18.5764C42.9849 16.9585 41.465 '
          '15.9656 39.6142 15.9656C39.2219 15.9656 38.842 16.0024 38.4497 '
          '16.0882C38.3517 16.1127 38.2414 16.1372 38.1433 16.1618C38.1556 '
          '15.0586 38.131 13.8942 38.033 12.742C37.6898 8.7094 36.2679 '
          '6.60117 34.7971 4.92193C33.8533 3.86782 32.7501 2.97304 31.5122 '
          '2.27438C29.2814 0.999637 26.7441 0.350006 23.9863 '
          '0.350006C21.2284 0.350006 18.7034 0.999637 16.4726 '
          '2.27438C15.2346 2.97304 14.1315 3.86782 13.1877 4.92193C11.7168 '
          '6.60117 10.3073 8.72166 9.95179 12.742C9.85373 13.8942 9.82922 '
          '15.0586 9.84148 16.1618C9.74342 16.1372 9.64536 16.1127 9.53505 '
          '16.0882C9.15507 16.0024 8.76285 15.9656 8.38287 15.9656C6.53204 '
          '15.9656 5.01215 16.9707 4.39929 18.5764C3.95803 19.7163 4.03157 '
          '20.9788 4.60766 22.0575C5.01215 22.8297 5.66178 23.5161 6.58107 '
          '24.1657C6.82621 24.3373 7.20618 24.5824 7.69647 24.9011C7.95387 '
          '25.0727 8.33384 25.3179 8.71382 25.563C8.84864 25.6488 8.95896 '
          '25.7591 9.04476 25.894C9.1183 26.0533 9.13056 26.2249 9.00799 '
          '26.5436C8.76284 27.0829 8.46867 27.61 8.12547 28.1003C6.93653 '
          '29.8408 5.22052 31.3239 3.03874 32.5128C1.88657 33.1257 '
          '0.685365 33.5302 0.170564 34.9152C-0.209408 35.9571 0.035735 '
          '37.1338 1.00405 38.1389C1.35951 38.5066 1.77625 38.8253 2.22977 '
          '39.0704C3.17357 39.5852 4.17866 39.9897 5.23278 40.2716C5.45341 '
          '40.3329 5.64952 40.4187 5.83338 40.5413C6.18884 40.8477 6.13981 '
          '41.3135 6.60558 41.9999C6.83847 42.3554 7.1449 42.6618 7.4881 '
          '42.9069C8.48093 43.5933 9.59633 43.6301 10.773 43.6791C11.8394 '
          '43.7159 13.0406 43.7649 14.4257 44.2184C15.0017 44.4023 15.5901 '
          '44.77 16.2765 45.199C17.9312 46.2164 20.1865 47.6014 23.974 '
          '47.6014C27.7615 47.6014 30.029 46.2041 31.696 45.1868C32.3824 '
          '44.77 32.9708 44.4023 33.5223 44.2184C34.8951 43.7649 36.1086 '
          '43.7159 37.175 43.6791C38.3517 43.6301 39.4671 43.5933 40.4599 '
          '42.9069C40.8767 42.6128 41.2198 42.245 41.465 41.8038C41.8082 '
          '41.2277 41.7959 40.8232 42.1146 40.5413C42.2862 40.4187 42.4823 '
          '40.3329 42.6785 40.2839C43.7326 40.002 44.7622 39.5975 45.7182 '
          '39.0704C46.1963 38.813 46.6375 38.4698 47.0052 38.0653L47.0175 '
          '38.0531C47.9736 37.0725 48.2064 35.9203 47.8265 34.9152ZM44.468 '
          '36.7171C42.4211 37.8447 41.0483 37.7221 39.9941 38.4085C39.0871 '
          '38.9846 39.6264 40.2349 38.9768 40.6884C38.1678 41.2399 35.7899 '
          '40.6516 32.7256 41.6689C30.1884 42.5024 28.5827 44.9171 24.023 '
          '44.9171C19.4634 44.9171 17.8944 42.5147 15.3204 41.6689C12.2561 '
          '40.6516 9.87825 41.2522 9.06927 40.6884C8.41964 40.2349 8.9467 '
          '38.9846 8.05193 38.4085C6.98556 37.7221 5.62501 37.8447 3.57806 '
          '36.7171C2.26654 35.9939 3.01423 35.5526 3.44323 35.3442C10.8711 '
          '31.7529 12.06 26.2004 12.1091 25.7836C12.1703 25.2811 12.2439 '
          '24.8889 11.6923 24.3863C11.1653 23.896 8.81187 22.4374 8.14999 '
          '21.9839C7.07135 21.224 6.59333 20.4763 6.94878 19.5447C7.19393 '
          '18.9074 7.79453 18.6622 8.41964 18.6622C8.61576 18.6622 8.81187 '
          '18.6867 9.00799 18.7235C10.1969 18.9809 11.3491 19.5693 12.011 '
          '19.7409C12.0968 19.7654 12.1703 19.7776 12.2561 19.7776C12.6116 '
          '19.7776 12.7342 19.5938 12.7097 19.1893C12.6361 17.89 12.4523 '
          '15.365 12.6606 12.9994C12.9425 9.75126 13.9844 8.13331 15.2346 '
          '6.71148C15.8352 6.02508 18.6421 3.05884 24.023 3.05884C29.4039 '
          '3.05884 32.2108 6.01282 32.8114 6.69922C34.0617 8.12106 35.1035 '
          '9.739 35.3854 12.9872C35.5938 15.3528 35.4099 17.8778 35.3241 '
          '19.177C35.2996 19.606 35.4222 19.7654 35.7777 19.7654C35.8635 '
          '19.7654 35.937 19.7531 36.0228 19.7286C36.6847 19.5693 37.8369 '
          '18.9687 39.0258 18.7113C39.2219 18.6622 39.418 18.65 39.6142 '
          '18.65C40.2393 18.65 40.8399 18.8951 41.085 19.5325C41.4405 '
          '20.464 40.9625 21.2117 39.8838 21.9717C39.2342 22.4252 36.8808 '
          '23.8838 36.3415 24.3741C35.7899 24.8766 35.8635 25.2688 35.9248 '
          '25.7714C35.9738 26.1881 37.1627 31.7406 44.5906 35.332C45.0318 '
          '35.5404 45.7673 35.9939 44.468 36.7171Z',
    ],
  ),
  tiktok(
    'TikTok',
    [
      'M34.1451 0H26.0556V32.6956C26.0556 36.5913 22.9444 39.7913 19.0725 '
          '39.7913C15.2007 39.7913 12.0894 36.5913 12.0894 32.6956C12.0894 '
          '28.8696 15.1315 25.7391 18.8651 25.6V17.3913C10.6374 17.5304 4 '
          '24.2783 4 32.6956C4 41.1827 10.7757 48 19.1417 48C27.5075 48 '
          '34.2833 41.1131 34.2833 32.6956V15.9304C37.3255 18.1565 41.059 '
          '19.4783 45 19.5479V11.3391C38.9157 11.1304 34.1451 6.12173 '
          '34.1451 0Z',
    ],
  );

  const _WINRSocialGlyphKind(this.displayName, this.pathData);

  final String displayName;

  /// Official brand glyph: SVG path data in a 48×48 viewBox, filled white.
  final List<String> pathData;
}

class _WINRSocialGlyph extends StatelessWidget {
  final _WINRSocialGlyphKind kind;

  const _WINRSocialGlyph({required this.kind});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WINRSvgIconPainter(pathData: kind.pathData, color: Colors.white),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-submit share step ("PLEASE SHARE A LITTLE") — 2.9
// ---------------------------------------------------------------------------

/// The share/celebrate screen shown AFTER the claim is submitted (14 Aug
/// 2026 reorder): the claim is already banked, so closing this screen loses
/// nothing. CONTINUE advances to the confirmation.
///
/// The optional story textarea lives here too. A typed story is handed to
/// [onStory] EXACTLY ONCE — on CONTINUE or on close, whichever comes first —
/// so it is never lost; the experience forwards it to the backend's
/// `attachClaimStory` callable fire-and-forget.
///
/// Per-network behavior:
/// - X: tweet intent with the prefilled winner line (+ [shareUrl] appended
///   when the publisher configured one).
/// - Facebook: the sharer URL with [shareUrl] only (FB forbids prefilled
///   text); no shareUrl → clipboard fallback.
/// - Instagram / Snapchat / TikTok: no text-prefill APIs and no share-sheet
///   plugin in this package → copy the line + "Copied — paste it in your
///   post".
class WINRV2ClaimShareView extends StatefulWidget {
  final Color accent;
  final String? logoUrl;

  /// The prize-derived headline ("$1,000.00 CASH PRIZE") for the share line.
  final String prizeHeadline;

  /// Publisher display name for "I just won {prize} in {appName}!". Null →
  /// the "in {appName}" clause is dropped.
  final String? appName;

  /// Publisher share landing URL (new optional sdkConfig field). Null →
  /// text-only tweet, clipboard fallback for Facebook.
  final String? shareUrl;

  final VoidCallback onDone;
  final VoidCallback onClose;

  /// Receives the typed story (non-empty, trimmed) at most once — fired on
  /// CONTINUE or close, whichever comes first. Null → the textarea still
  /// renders but the text goes nowhere (previews/tests).
  final ValueChanged<String>? onStory;

  const WINRV2ClaimShareView({
    super.key,
    required this.accent,
    required this.logoUrl,
    required this.prizeHeadline,
    this.appName,
    this.shareUrl,
    required this.onDone,
    required this.onClose,
    this.onStory,
  });

  /// The winner share line — "I just won {prize} in {appName}!" (the app
  /// clause drops when no name is configured). Exposed for tests.
  static String shareLine(String prizeHeadline, String? appName) {
    final app = appName?.trim();
    return (app == null || app.isEmpty)
        ? 'I just won $prizeHeadline!'
        : 'I just won $prizeHeadline in $app!';
  }

  /// Appends `utm_source={network}&utm_medium=winr_share` to the publisher's
  /// [shareUrl] via [Uri] (correct whether or not the URL already has a query
  /// string). A URL already carrying a `utm_source` param is returned
  /// untouched — the publisher's own tagging wins. Unparseable URLs pass
  /// through unchanged. Exposed for tests.
  static String? taggedShareUrl(String? shareUrl, String network) {
    if (shareUrl == null || shareUrl.isEmpty) return shareUrl;
    final Uri uri;
    try {
      uri = Uri.parse(shareUrl);
    } on FormatException {
      return shareUrl;
    }
    if (uri.queryParameters.containsKey('utm_source')) return shareUrl;
    return uri.replace(queryParameters: {
      ...uri.queryParametersAll,
      'utm_source': network,
      'utm_medium': 'winr_share',
    }).toString();
  }

  @override
  State<WINRV2ClaimShareView> createState() => _WINRV2ClaimShareViewState();
}

class _WINRV2ClaimShareViewState extends State<WINRV2ClaimShareView> {
  static const String _storyPlaceholder =
      'Please share anything. What you’re going to do with the prize, why '
      'you love our app, your favorite food, etc.';

  final TextEditingController _story = TextEditingController();
  final FocusNode _storyFocus = FocusNode();

  /// One-shot guard: the typed story is delivered at most once (CONTINUE or
  /// close, whichever comes first) — never lost, never duplicated.
  bool _storyDelivered = false;

  /// Transient "Copied — paste it in your post" confirmation.
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _story.dispose();
    _storyFocus.dispose();
    super.dispose();
  }

  void _deliverStory() {
    if (_storyDelivered) return;
    final text = _story.text.trim();
    if (text.isEmpty) return;
    _storyDelivered = true;
    widget.onStory?.call(text);
  }

  void _handleDone() {
    _deliverStory();
    widget.onDone();
  }

  void _handleClose() {
    _deliverStory();
    widget.onClose();
  }

  String get _shareLine =>
      WINRV2ClaimShareView.shareLine(widget.prizeHeadline, widget.appName);

  /// Share payload: the line plus [url] (the UTM-tagged share URL) when
  /// configured.
  String _shareText(String? url) =>
      (url == null || url.isEmpty) ? _shareLine : '$_shareLine $url';

  void _shareTo(_WINRSocialGlyphKind kind) {
    // UTM-tag the publisher link with the tapped network (the enum names are
    // exactly the utm_source values) so publishers can attribute installs per
    // network — clipboard fallbacks included.
    final taggedUrl =
        WINRV2ClaimShareView.taggedShareUrl(widget.shareUrl, kind.name);
    switch (kind) {
      case _WINRSocialGlyphKind.x:
        // Tweet intent: prefilled text (+ shareUrl appended).
        final uri = Uri.parse('https://twitter.com/intent/tweet')
            .replace(queryParameters: {'text': _shareText(taggedUrl)});
        launchUrl(uri, mode: LaunchMode.externalApplication);
      case _WINRSocialGlyphKind.facebook:
        if (taggedUrl != null && taggedUrl.isNotEmpty) {
          final uri = Uri.parse('https://www.facebook.com/sharer/sharer.php')
              .replace(queryParameters: {'u': taggedUrl});
          launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _copyToClipboard(_shareText(taggedUrl));
        }
      case _WINRSocialGlyphKind.instagram:
      case _WINRSocialGlyphKind.snapchat:
      case _WINRSocialGlyphKind.tiktok:
        _copyToClipboard(_shareText(taggedUrl));
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      _copiedTimer = null;
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WINRV2Colors.deepCharcoal,
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            const SizedBox(height: 18),
            _WINRClaimHeader(logoUrl: widget.logoUrl, onClose: _handleClose),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'PLEASE SHARE A LITTLE',
                textAlign: TextAlign.center,
                style: WINRV2Font.inter(
                  27,
                  weight: FontWeight.w900,
                  letterSpacing: -0.81,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your claim is in! Sharing your win helps us show real '
                'people like you win.',
                textAlign: TextAlign.center,
                style: WINRV2Font.inter(
                  18,
                  weight: FontWeight.w500,
                  letterSpacing: -0.54,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Optional story textarea (Figma field styling). Typed text is
            // delivered once via attachClaimStory — on CONTINUE or close —
            // never with the (already submitted) claim payload.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: WINRV2EnsureVisible(
                focusNode: _storyFocus,
                child: Container(
                  height: 150,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: _WINRStepTheme.fieldDecoration,
                  child: TextField(
                    controller: _story,
                    focusNode: _storyFocus,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: WINRV2Font.inter(17, height: 1.25),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: _storyPlaceholder,
                      hintStyle:
                          WINRV2Font.inter(17, color: const Color(0x99FFFFFF)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // The line being shared — visible so the person knows exactly
            // what a tap posts/copies.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: _WINRStepTheme.fieldDecoration,
                child: Text(
                  _shareLine,
                  textAlign: TextAlign.center,
                  style: WINRV2Font.inter(16, height: 1.3),
                ),
              ),
            ),
            const SizedBox(height: 30),
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
                      onTap: () => _shareTo(kind),
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
                opacity: _copied ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    WINRV2Strings.shareCopied,
                    style: WINRV2Font.inter(12, color: const Color(0xB3FFFFFF)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 21),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: WINRV2PillButton(
                accent: widget.accent,
                title: 'CONTINUE',
                onTap: _handleDone,
              ),
            ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation ("YOUR PRIZE CLAIM HAS BEEN SUBMITTED")
// ---------------------------------------------------------------------------

class WINRV2ClaimConfirmationView extends StatefulWidget {
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

  @override
  State<WINRV2ClaimConfirmationView> createState() =>
      _WINRV2ClaimConfirmationViewState();
}

class _WINRV2ClaimConfirmationViewState
    extends State<WINRV2ClaimConfirmationView> {
  /// One-shot celebration (2.9.3, Joe's frame): the confetti-burst GIF
  /// explodes once over the top of the screen the moment the confirmation
  /// appears — the same machinery as the winner splash — then removes
  /// itself via [WINRV2GifView.onFinished]. A gold drifting confetti field
  /// keeps sparkling beneath it. Both are purely decorative and wrapped in
  /// [IgnorePointer], so they can never block RETURN TO APP or the close X.
  bool _bursting = true;

  Color get accent => widget.accent;
  String? get logoUrl => widget.logoUrl;
  WINRPrizeClaimForm? get form => widget.form;
  String get claimNumber => widget.claimNumber;
  String get submittedAt => widget.submittedAt;
  VoidCallback get onDone => widget.onDone;

  // Gold palette (mirrors iOS `Gold`).
  static const Color _goldText = Color(0xFFB88C29);
  static const Color _goldBorder = Color(0xFFD4AD47);
  static const Color _creamTop = Color(0xFFFFFAEB);
  static const Color _creamBottom = Color(0xFFF2E0AD);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WINRV2Colors.deepCharcoal,
      child: Stack(
        children: [
          // Gold confetti drift across the upper half (Joe's sparkle field),
          // beneath the content so text stays crisp.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 360,
            child: IgnorePointer(
              child: WINRV2Confetti(
                style: WINRV2ConfettiStyle.gold,
                count: 26,
                speed: 0.7,
              ),
            ),
          ),
          Positioned.fill(child: _content()),
          // One-shot burst over the headline area, on appearance only.
          if (_bursting)
            Positioned(
              top: 30,
              left: 0,
              right: 0,
              height: 320,
              child: IgnorePointer(
                child: WINRV2GifView(
                  WINRV2Assets.confettiBurst,
                  onFinished: () {
                    if (mounted) setState(() => _bursting = false);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    return SingleChildScrollView(
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
            // Joe's frame: solid dark gunmetal card with a subtle border;
            // the envelope sits in a circle stroked in the publisher's
            // PRIMARY accent (never a hardcoded blue).
            fill: WINRV2Colors.gunmetal,
            borderColor: const Color(0x1FFFFFFF),
            icon: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2),
              ),
              child:
                  const Icon(Icons.mail_outline, size: 22, color: Colors.white),
            ),
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
                    // Joe's 2.9.3 frame: OFFICIAL / WINNER carry the
                    // publisher's PRIMARY accent (previously fixed gold).
                    Text(
                      'OFFICIAL',
                      style: WINRV2Font.inter(
                        16,
                        weight: FontWeight.w900,
                        color: accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'WINNER',
                      style: WINRV2Font.inter(
                        16,
                        weight: FontWeight.w900,
                        color: accent,
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
