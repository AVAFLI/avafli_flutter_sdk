import 'package:flutter/material.dart';

/// Defines the visual branding and theme for the WINR SDK.
/// 
/// This class allows customization of colors, typography, and imagery
/// to match your app's brand identity and provide a cohesive user experience.
class WINRBranding {
  /// Primary text color
  final Color primaryColor;
  
  /// Secondary text color (typically slightly faded)
  final Color secondaryTextColor;
  
  /// Muted text color for less important text
  final Color mutedTextColor;
  
  /// Main background color
  final Color backgroundColor;
  
  /// Card/container background color
  final Color cardBackgroundColor;
  
  /// Border color for cards and containers
  final Color cardBorderColor;
  
  /// Primary button background color
  final Color primaryButtonColor;
  
  /// Primary button text color
  final Color primaryButtonTextColor;
  
  /// Secondary button background color
  final Color secondaryButtonColor;
  
  /// Secondary button text color
  final Color secondaryButtonTextColor;
  
  /// Input field background color
  final Color inputFieldBackgroundColor;
  
  /// Input field border color
  final Color inputFieldBorderColor;
  
  /// Input field placeholder text color
  final Color inputFieldPlaceholderColor;
  
  /// Accent color used for glows and highlights
  final Color accentGlowColor;
  
  /// Corner radius for rounded elements
  final double cornerRadius;
  
  /// Logo/brand image asset path or widget
  final Widget? logo;
  
  /// Secondary logo (optional)
  final Widget? logoTwo;
  
  /// Size for the primary logo display
  final Size primaryLogoSize;
  
  /// Size for secondary logo display
  final Size? secondaryLogoSize;
  
  /// Creates a new [WINRBranding] instance with the specified visual properties.
  const WINRBranding({
    required this.primaryColor,
    required this.secondaryTextColor,
    required this.mutedTextColor,
    required this.backgroundColor,
    required this.cardBackgroundColor,
    required this.cardBorderColor,
    required this.primaryButtonColor,
    required this.primaryButtonTextColor,
    required this.secondaryButtonColor,
    required this.secondaryButtonTextColor,
    required this.inputFieldBackgroundColor,
    required this.inputFieldBorderColor,
    required this.inputFieldPlaceholderColor,
    required this.accentGlowColor,
    this.cornerRadius = 16.0,
    this.logo,
    this.logoTwo,
    this.primaryLogoSize = const Size(130, 72),
    this.secondaryLogoSize,
  });
  
  /// Creates the default WINR branding theme.
  /// 
  /// This provides a dark theme with blue accents that matches
  /// the standard WINR aesthetic.
  factory WINRBranding.defaultBranding({Widget? logo, Widget? logoTwo}) {
    return WINRBranding(
      primaryColor: Colors.white,
      secondaryTextColor: Colors.white.withValues(alpha: 0.96),
      mutedTextColor: Colors.white.withValues(alpha: 0.74),
      backgroundColor: const Color(0xFF020617),
      cardBackgroundColor: const Color(0xFF020818),
      cardBorderColor: Colors.white.withValues(alpha: 0.16),
      primaryButtonColor: const Color(0xFF0284FF),
      primaryButtonTextColor: Colors.white,
      secondaryButtonColor: Colors.white.withValues(alpha: 0.06),
      secondaryButtonTextColor: Colors.white.withValues(alpha: 0.92),
      inputFieldBackgroundColor: Colors.white.withValues(alpha: 0.03),
      inputFieldBorderColor: Colors.white.withValues(alpha: 0.18),
      inputFieldPlaceholderColor: Colors.white.withValues(alpha: 0.55),
      accentGlowColor: const Color(0xFF0EA5E9),
      cornerRadius: 24,
      logo: logo ?? const Icon(Icons.card_giftcard, color: Colors.white),
      logoTwo: logoTwo,
      primaryLogoSize: const Size(100, 52),
      secondaryLogoSize: const Size(40, 18),
    );
  }
  
  /// Creates a carnival-style theme with blue and orange accents.
  factory WINRBranding.carnivalBlueOrange({Widget? logo, Widget? logoTwo}) {
    return WINRBranding(
      primaryColor: Colors.white,
      secondaryTextColor: Colors.white.withValues(alpha: 0.95),
      mutedTextColor: Colors.white.withValues(alpha: 0.7),
      backgroundColor: const Color(0xFF0F0F1A),
      cardBackgroundColor: const Color(0xFF1E40AF),
      cardBorderColor: const Color(0xFF3B82F6).withValues(alpha: 0.5),
      primaryButtonColor: const Color(0xFF10B981),
      primaryButtonTextColor: Colors.white,
      secondaryButtonColor: const Color(0xFF34D399),
      secondaryButtonTextColor: Colors.white,
      inputFieldBackgroundColor: Colors.white.withValues(alpha: 0.08),
      inputFieldBorderColor: Colors.white.withValues(alpha: 0.25),
      inputFieldPlaceholderColor: Colors.white.withValues(alpha: 0.6),
      accentGlowColor: const Color(0xFFF97316),
      cornerRadius: 20,
      logo: logo ?? const Icon(Icons.card_giftcard, color: Colors.white),
      logoTwo: logoTwo,
      primaryLogoSize: const Size(130, 72),
      secondaryLogoSize: const Size(40, 18),
    );
  }
  
  /// Creates a premium gold-themed branding.
  factory WINRBranding.luxuryGold({Widget? logo, Widget? logoTwo}) {
    return WINRBranding(
      primaryColor: const Color(0xFFF59E0B),
      secondaryTextColor: Colors.white,
      mutedTextColor: const Color(0xFFF59E0B).withValues(alpha: 0.8),
      backgroundColor: const Color(0xFF0A0A0A),
      cardBackgroundColor: const Color(0xFF1A1400),
      cardBorderColor: const Color(0xFFF59E0B).withValues(alpha: 0.3),
      primaryButtonColor: const Color(0xFFF59E0B),
      primaryButtonTextColor: Colors.white,
      secondaryButtonColor: const Color(0xFFFFD700),
      secondaryButtonTextColor: Colors.black,
      inputFieldBackgroundColor: Colors.black.withValues(alpha: 0.4),
      inputFieldBorderColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
      inputFieldPlaceholderColor: const Color(0xFFF59E0B).withValues(alpha: 0.7),
      accentGlowColor: const Color(0xFFFFD700),
      cornerRadius: 24,
      logo: logo ?? const Icon(Icons.card_giftcard, color: Color(0xFFF59E0B)),
      logoTwo: logoTwo,
      primaryLogoSize: const Size(130, 72),
      secondaryLogoSize: const Size(40, 18),
    );
  }
  
  /// Returns a new [WINRBranding] with server-driven overrides applied.
  ///
  /// Server values from `sdkConfig.branding` override code-level defaults.
  /// Missing or null server fields fall back to the current values.
  ///
  /// Field mapping:
  /// - `primaryColor`   → [primaryColor], [primaryButtonColor]
  /// - `secondaryColor` → [secondaryButtonColor], [accentGlowColor]
  /// - `backgroundColor`→ [backgroundColor]
  /// - `logoUrl`        → reserved for future network-image logo support
  WINRBranding applyingServerBranding(Map<String, dynamic>? serverBranding) {
    if (serverBranding == null || serverBranding.isEmpty) return this;

    final serverPrimary = _parseColor(serverBranding['primaryColor']);
    final serverSecondary = _parseColor(serverBranding['secondaryColor']);
    final serverBg = _parseColor(serverBranding['backgroundColor']);
    // logoUrl reserved for future use
    // final serverLogoUrl = serverBranding['logoUrl'] as String?;

    return WINRBranding(
      primaryColor: serverPrimary ?? primaryColor,
      secondaryTextColor: secondaryTextColor,
      mutedTextColor: mutedTextColor,
      backgroundColor: serverBg ?? backgroundColor,
      cardBackgroundColor: cardBackgroundColor,
      cardBorderColor: cardBorderColor,
      primaryButtonColor: serverPrimary ?? primaryButtonColor,
      primaryButtonTextColor: primaryButtonTextColor,
      secondaryButtonColor: serverSecondary ?? secondaryButtonColor,
      secondaryButtonTextColor: secondaryButtonTextColor,
      inputFieldBackgroundColor: inputFieldBackgroundColor,
      inputFieldBorderColor: inputFieldBorderColor,
      inputFieldPlaceholderColor: inputFieldPlaceholderColor,
      accentGlowColor: serverSecondary ?? accentGlowColor,
      cornerRadius: cornerRadius,
      logo: logo,
      logoTwo: logoTwo,
      primaryLogoSize: primaryLogoSize,
      secondaryLogoSize: secondaryLogoSize,
    );
  }

  /// Parses a hex color string (e.g. `"#0284FF"` or `"0284FF"`) into a [Color].
  ///
  /// Returns `null` if the value is null, not a string, empty, or unparseable.
  static Color? _parseColor(dynamic hex) {
    if (hex == null || hex is! String || hex.isEmpty) return null;
    final h = hex.replaceAll('#', '');
    final value = int.tryParse(h, radix: 16);
    if (value == null) return null;
    return Color(value | 0xFF000000);
  }

  /// Creates a cosmic purple and pink themed branding.
  factory WINRBranding.cosmicPurplePink({Widget? logo, Widget? logoTwo}) {
    return WINRBranding(
      primaryColor: Colors.white,
      secondaryTextColor: Colors.white.withValues(alpha: 0.96),
      mutedTextColor: Colors.white.withValues(alpha: 0.74),
      backgroundColor: const Color(0xFF0D0818),
      cardBackgroundColor: Colors.black.withValues(alpha: 0.9),
      cardBorderColor: const Color(0xFFE879F9).withValues(alpha: 0.4),
      primaryButtonColor: const Color(0xFFEC4899),
      primaryButtonTextColor: Colors.white,
      secondaryButtonColor: const Color(0xFFA78BFA),
      secondaryButtonTextColor: Colors.white,
      inputFieldBackgroundColor: Colors.white.withValues(alpha: 0.05),
      inputFieldBorderColor: Colors.white.withValues(alpha: 0.2),
      inputFieldPlaceholderColor: Colors.white.withValues(alpha: 0.6),
      accentGlowColor: const Color(0xFFEC4899),
      cornerRadius: 20,
      logo: logo ?? const Icon(Icons.card_giftcard, color: Colors.white),
      logoTwo: logoTwo,
      primaryLogoSize: const Size(130, 72),
      secondaryLogoSize: const Size(40, 18),
    );
  }
}