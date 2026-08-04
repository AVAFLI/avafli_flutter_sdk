// Design system for the V2 experience — tokens, fonts, and assets extracted
// from the WINR-High-V2 Figma. Everything here is intentionally HARDCODED to
// the design except the publisher-configurable primary color: publishers can
// customize ONLY their logo, prize image, and primary color.
//
// Mirrors the iOS SDK's WINRV2Theme.swift.

import 'package:flutter/widgets.dart';

import '../../domain/giveaway.dart';

/// Colors (Figma design tokens) — mirrors iOS `WINRV2Color`.
class WINRV2Colors {
  WINRV2Colors._();

  /// background/primary — the drawer + tile background ("gunmetal").
  static const Color gunmetal = Color(0xFF1D2330);

  /// black (deep charcoal) — header circle buttons.
  static const Color deepCharcoal = Color(0xFF0B0D12);

  /// Modal panel background.
  static const Color panel = Color(0xFF141519);

  /// Modal hairline border.
  static const Color panelBorder = Color(0xFF515151);

  /// WINR brand blue — the DEFAULT primary when a publisher hasn't set one.
  static const Color winrBlue = Color(0xFF268FFF);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xBFFFFFFF); // white 75%
  static const Color textTertiary = Color(0x99FFFFFF); // white 60%
  static const Color foregroundSecondary = Color(0x80FFFFFF); // white 50%
}

/// The publisher's primary color (branding.primaryColor) with the WINR-blue
/// default. Drives: CTA buttons, streak-tile outlines/glow, accent text,
/// power-up tiles. Mirrors iOS `WINRV2Accent`.
class WINRV2Accent {
  final Color color;

  WINRV2Accent(String? hex) : color = _parse(hex) ?? WINRV2Colors.winrBlue;

  static Color? _parse(String? hex) {
    if (hex == null) return null;
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }
}

/// Fonts (Inter + Oswald, bundled with the package) — mirrors iOS
/// `WINRV2Font`. Fonts are declared in this package's pubspec so host apps
/// get them automatically; the `package:` parameter namespaces the family.
class WINRV2Font {
  WINRV2Font._();

  static const String _package = 'winr_flutter_sdk';

  static TextStyle inter(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = WINRV2Colors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      package: _package,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
    );
  }

  static TextStyle oswald(
    double size, {
    bool bold = false,
    Color color = WINRV2Colors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Oswald',
      package: _package,
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
    );
  }
}

/// Bundled images — mirrors iOS `WINRV2Asset`.
class WINRV2Assets {
  WINRV2Assets._();

  static const String package = 'winr_flutter_sdk';

  /// Default prize hero (money pile) — used when the publisher hasn't set a
  /// prize image.
  static const String cashHero = 'assets/images/cash-hero-single.png';
  static const String trophy = 'assets/images/trophy.png';
  static const String winnerModalBg = 'assets/images/winner-modal-bg.png';

  /// Joe's Figma reveal-beat animations (one-shot GIFs played by
  /// `WINRV2GifView`; same files the iOS SDK bundles).
  static const String tileBurst = 'assets/images/tile-burst.gif';
  static const String confettiBurst = 'assets/images/confetti-burst.gif';

  static Image image(String name, {BoxFit fit = BoxFit.contain}) {
    return Image.asset(name, package: package, fit: fit);
  }
}

/// Ladder math (mirrors the backend + iOS `WINRV2Ladder` exactly).
class WINRV2Ladder {
  WINRV2Ladder._();

  /// Explicit ladder values cover days 1..ladder.length; beyond that the daily
  /// increment is the bonusEntries of the LATEST passed milestone (the
  /// "+25 EVERY DAY!" accelerators). No milestones → flat at the ladder top.
  static int entries({
    required int day,
    required List<int> ladder,
    List<MilestoneConfig>? milestones,
  }) {
    if (ladder.isEmpty) return 10;
    if (day <= ladder.length) {
      return ladder[(day - 1).clamp(0, ladder.length - 1)];
    }
    final ms = List<MilestoneConfig>.of(milestones ?? const [])
      ..sort((a, b) => a.day.compareTo(b.day));
    var value = ladder[ladder.length - 1];
    for (var d = ladder.length + 1; d <= day; d++) {
      var rate = 0;
      for (final m in ms) {
        if (m.day < d) rate = m.bonusEntries;
      }
      value += rate;
    }
    return value;
  }
}

/// Formats an int with comma grouping ("12,345") — mirrors Swift's
/// `formatted()`.
String winrV2FormatInt(int value) {
  final digits = value.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return value < 0 ? '-$grouped' : grouped;
}
