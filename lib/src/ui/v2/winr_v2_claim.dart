// Winner prize-claim flow (Joe's Light variant): winner splash →
// single-page claim form → confirmation with the OFFICIAL WINNER card.
// Shown when the giveaway payload carries prizeClaim.status == "pending".
//
// Mirrors the iOS SDK's WINRV2Claim.swift.
//
// Photo attachment note: iOS offers an optional "ATTACH A PHOTO" control
// backed by PHPicker. This package deliberately has no image-picker
// dependency (pure-Dart SDK, no heavy plugins), so the photo field is
// omitted from the Flutter form — it is OPTIONAL in the backend contract
// (functions/src/prizeclaim.ts) and `SubmitPrizeClaimRequest.photoBase64`
// stays wired for future use.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'winr_v2_components.dart';
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
  });

  static bool isValidZip(String zip) {
    final z = zip.trim();
    return z.length == 5 && RegExp(r'^\d{5}$').hasMatch(z);
  }

  /// SUBMIT enables when every required field is present and the zip is a
  /// 5-digit US code. Phone, apartment, and photo are optional.
  bool get isValid =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      street.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      state.trim().isNotEmpty &&
      isValidZip(zip);

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
// Claim form ("TELL US ABOUT YOURSELF")
// ---------------------------------------------------------------------------

class WINRV2ClaimFormView extends StatefulWidget {
  final Color accent;
  final String? logoUrl;

  /// Host-app-provided identity prefill (first/last name, phone).
  final WINRPrizeClaimForm initialForm;
  final bool isSubmitting;

  /// Transport-level submit failure surfaced inline on the form ("Not the
  /// winner"/"Already submitted" instead fall back to the dashboard silently).
  final String? submitError;
  final ValueChanged<WINRPrizeClaimForm> onSubmit;
  final VoidCallback onClose;

  const WINRV2ClaimFormView({
    super.key,
    required this.accent,
    required this.logoUrl,
    required this.initialForm,
    required this.isSubmitting,
    required this.submitError,
    required this.onSubmit,
    required this.onClose,
  });

  @override
  State<WINRV2ClaimFormView> createState() => _WINRV2ClaimFormViewState();
}

class _WINRV2ClaimFormViewState extends State<WINRV2ClaimFormView> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _street;
  late final TextEditingController _apt;
  late final TextEditingController _city;
  late final TextEditingController _zip;
  String _state = '';

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
    for (final c in [_firstName, _lastName, _phone, _street, _apt, _city, _zip]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _phone, _street, _apt, _city, _zip]) {
      c.dispose();
    }
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
      );

  @override
  Widget build(BuildContext context) {
    final form = _form;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: WINRV2Colors.deepCharcoal),
        // Gold-sparkle backdrop at the top, fading into the dark body.
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 430,
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
                      stops: [0, 0.55, 1],
                      colors: [
                        Color(0x260B0D12), // deepCharcoal 15%
                        Color(0x8C0B0D12), // deepCharcoal 55%
                        Color(0xFF0B0D12), // deepCharcoal
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 18),
              _WINRClaimHeader(logoUrl: widget.logoUrl, onClose: widget.onClose),
              const SizedBox(height: 10),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'PRIZE CLAIM FORM',
                  style: WINRV2Font.inter(
                    15,
                    weight: FontWeight.w900,
                    color: WINRV2Colors.gunmetal,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'TELL US ABOUT YOURSELF',
                    maxLines: 1,
                    style: WINRV2Font.inter(
                      24,
                      weight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: Text(
                  'We’ll use this information to verify your prize and '
                  'personalize your winner announcement.',
                  textAlign: TextAlign.center,
                  style: WINRV2Font.inter(15, height: 1.25),
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    _WINRClaimField(label: 'First Name', controller: _firstName),
                    const SizedBox(height: 16),
                    _WINRClaimField(
                      label: 'Last Name (we will only show your last initial)',
                      controller: _lastName,
                    ),
                    const SizedBox(height: 16),
                    // The winning email lives server-side (the SDK never
                    // stores raw email) and the claim is keyed to the
                    // account — shown locked, no value editable.
                    const _WINRClaimField(
                      label: 'Winning Email Address (cannot be changed)',
                      fixedText: 'On file with your winning entry',
                      disabled: true,
                    ),
                    const SizedBox(height: 16),
                    _WINRClaimField(
                      label: 'Phone Number (optional)',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _WINRClaimField(
                      label: 'Street Address',
                      controller: _street,
                    ),
                    const SizedBox(height: 16),
                    _WINRClaimField(
                      label: 'Apartment, Suite, etc. (optional)',
                      controller: _apt,
                    ),
                    const SizedBox(height: 16),
                    _WINRClaimField(label: 'City', controller: _city),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _statePicker()),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: _WINRClaimField(
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
                    const SizedBox(height: 16),
                    _WINRClaimField(
                      label: 'Country',
                      fixedText: form.country,
                      disabled: true,
                    ),
                  ],
                ),
              ),
              if (widget.submitError != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
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
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: WINRV2PillButton(
                  accent: widget.accent,
                  title: 'SUBMIT',
                  isLoading: widget.isSubmitting,
                  enabled: form.isValid,
                  onTap: () => widget.onSubmit(_form),
                ),
              ),
              const SizedBox(height: 34),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('State', style: WINRV2Font.inter(12)),
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
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: _WINRClaimField.fieldDecoration,
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
                        16,
                        color: _state.isEmpty
                            ? const Color(0x66FFFFFF)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Color(0xB3FFFFFF),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A labeled dark rounded text field (claim form).
class _WINRClaimField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;

  /// Non-editable display value (locked email / country rows).
  final String? fixedText;
  final bool disabled;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _WINRClaimField({
    required this.label,
    this.controller,
    this.fixedText,
    this.disabled = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  static BoxDecoration get fieldDecoration => BoxDecoration(
        color: const Color(0x12FFFFFF), // white 7%
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x40FFFFFF)), // white 25%
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: WINRV2Font.inter(12),
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: disabled ? 0.6 : 1,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: fieldDecoration,
            alignment: Alignment.centerLeft,
            child: disabled
                ? Text(
                    fixedText ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WINRV2Font.inter(16, color: const Color(0x66FFFFFF)),
                  )
                : TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: WINRV2Font.inter(16),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
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
