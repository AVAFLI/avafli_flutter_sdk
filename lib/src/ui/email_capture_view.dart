import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../domain/sdk_copy.dart';
import '../domain/sdk_media.dart';
import '../winr_branding.dart';

/// Email capture view — matches iOS EmailCaptureView.swift.
///
/// Logo → title/subtitle → email field → 18+ age gate → ENTER NOW → legal text.
class EmailCaptureView extends StatefulWidget {
  final WINRBranding branding;
  final VoidCallback onSkip;
  final Function(String email) onSubmit;
  final String? rulesUrl;
  final String? prefillEmail;
  final double? prizeValue;
  final SdkCopy? sdkCopy;
  final SdkMedia? sdkMedia;
  final void Function(String url)? onOpenUrl;

  const EmailCaptureView({
    super.key,
    required this.branding,
    required this.onSubmit,
    required this.onSkip,
    this.rulesUrl,
    this.prefillEmail,
    this.prizeValue,
    this.sdkCopy,
    this.sdkMedia,
    this.onOpenUrl,
  });

  @override
  State<EmailCaptureView> createState() => _EmailCaptureViewState();
}

class _EmailCaptureViewState extends State<EmailCaptureView> {
  late TextEditingController _emailController;
  bool _isAgeConfirmed = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.prefillEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _isEmailValid {
    final pattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return pattern.hasMatch(_emailController.text);
  }

  String _formatPrize(double value) {
    if (value >= 1000) {
      final formatted = '\$${value.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
      return 'WIN $formatted CASH!';
    }
    return 'WIN \$${value.toInt()} CASH!';
  }

  Widget _buildHeroMedia(ScreenMedia? media, Widget defaultWidget) {
    if (media?.lottieUrl != null && media!.lottieUrl!.isNotEmpty) {
      return Lottie.network(
        media.lottieUrl!,
        width: 200,
        height: 150,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => defaultWidget,
      );
    }
    if (media?.imageUrl != null && media!.imageUrl!.isNotEmpty) {
      return Image.network(
        media.imageUrl!,
        width: 200,
        height: 150,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => defaultWidget,
      );
    }
    return defaultWidget;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.branding;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          children: [
            // Logo / Hero Media
            _buildHeroMedia(
              widget.sdkMedia?.emailCapture,
              b.logo != null
                  ? SizedBox(
                      width: b.primaryLogoSize.width,
                      height: b.primaryLogoSize.height,
                      child: b.logo!,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 40),

            // Title + subtitle
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Text(
                    widget.sdkCopy?.emailCapture?.prizeHeadline ??
                        widget.sdkCopy?.emailCapture?.title ??
                        widget.sdkCopy?.welcomeTitle ??
                        (widget.prizeValue != null
                            ? _formatPrize(widget.prizeValue!)
                            : 'WIN PRIZES!'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: b.secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.sdkCopy?.emailCapture?.subtitle ??
                        widget.sdkCopy?.welcomeSubtitle ??
                        'Just submit this entry form for your FREE chance to win.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: b.mutedTextColor,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Email field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sdkCopy?.emailCapture?.emailLabel ?? 'Email',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: b.secondaryTextColor.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: b.inputFieldBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _emailError != null
                            ? Colors.red.withValues(alpha: 0.6)
                            : b.inputFieldBorderColor,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        Icon(
                          Icons.email,
                          size: 15,
                          color: b.inputFieldPlaceholderColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: b.primaryColor,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.sdkCopy?.emailCapture?.emailPlaceholder ?? 'Ex. johndoe@gmail.com',
                              hintStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: b.inputFieldPlaceholderColor,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                    ),
                  ),
                  // Inline validation error
                  if (_emailError != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _emailError!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 18+ Age gate checkbox
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => setState(() => _isAgeConfirmed = !_isAgeConfirmed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isAgeConfirmed
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: _isAgeConfirmed
                          ? b.primaryButtonColor
                          : b.mutedTextColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.sdkCopy?.emailCapture?.ageGateText ??
                            widget.sdkCopy?.ageGateText ??
                            'I confirm I am 18 years of age or older',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: b.secondaryTextColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // CTA button
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 20, right: 20),
              child: GestureDetector(
                onTap: _handleSubmit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: (_isAgeConfirmed && _emailController.text.isNotEmpty)
                        ? b.primaryButtonColor
                        : b.primaryButtonColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: b.accentGlowColor.withValues(
                            alpha: _isAgeConfirmed ? 0.5 : 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.sdkCopy?.emailCapture?.submitButton ?? 'ENTER NOW',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: b.primaryButtonTextColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Official Rules & Privacy Policy
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: b.mutedTextColor.withValues(alpha: 0.7),
                  ),
                  children: [
                    TextSpan(text: widget.sdkCopy?.emailCapture?.rulesPrefix ?? 'By entering, you agree to the '),
                    TextSpan(
                      text: widget.sdkCopy?.emailCapture?.rulesLinkText ?? 
                            widget.sdkCopy?.rulesLinkText ?? 'Official Rules',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: b.primaryButtonColor,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          final url = widget.rulesUrl;
                          if (url != null) {
                            widget.onOpenUrl?.call(url);
                          }
                        },
                    ),
                    const TextSpan(text: ' & '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: b.primaryButtonColor,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          widget.onOpenUrl
                              ?.call('https://winfrastructure.us/privacy');
                        },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    final trimmed = _emailController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _emailError = 'Email is required');
      return;
    }
    if (!_isEmailValid) {
      setState(() => _emailError = 'Please enter a valid email address');
      return;
    }
    if (!_isAgeConfirmed) {
      setState(() => _emailError = 'You must be 18+ to enter');
      return;
    }
    setState(() => _emailError = null);
    widget.onSubmit(trimmed);
  }
}
