// Design system for the V2 experience — tokens, fonts, and assets extracted
// from the Avafli-High-V2 Figma. Everything here is intentionally HARDCODED to
// the design except the publisher-configurable primary color: publishers can
// customize ONLY their logo, prize image, and primary color.
//
// Mirrors the iOS SDK's AvafliV2Theme.swift.

import 'package:flutter/widgets.dart';

import '../../domain/giveaway.dart';

/// Colors (Figma design tokens) — mirrors iOS `AvafliV2Color`.
class AvafliV2Colors {
  AvafliV2Colors._();

  /// background/primary — the drawer + tile background ("gunmetal").
  static const Color gunmetal = Color(0xFF1D2330);

  /// black (deep charcoal) — header circle buttons.
  static const Color deepCharcoal = Color(0xFF0B0D12);

  /// Modal panel background.
  static const Color panel = Color(0xFF141519);

  /// Modal hairline border.
  static const Color panelBorder = Color(0xFF515151);

  /// Avafli brand blue — the DEFAULT primary when a publisher hasn't set one.
  static const Color avafliBlue = Color(0xFF268FFF);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xBFFFFFFF); // white 75%
  static const Color textTertiary = Color(0x99FFFFFF); // white 60%
  static const Color foregroundSecondary = Color(0x80FFFFFF); // white 50%

  /// Inline error text — the code-entry screen established this red; every
  /// field-level error uses it so validation reads identically everywhere.
  static const Color errorRed = Color(0xFFFF6B63);
}

/// The publisher's primary color (branding.primaryColor) with the Avafli-blue
/// default. Drives: CTA buttons, streak-tile outlines/glow, accent text,
/// power-up tiles. Mirrors iOS `AvafliV2Accent`.
class AvafliV2Accent {
  final Color color;

  AvafliV2Accent(String? hex)
      : color = _parse(hex) ?? AvafliV2Colors.avafliBlue;

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
/// `AvafliV2Font`. Fonts are declared in this package's pubspec so host apps
/// get them automatically; the `package:` parameter namespaces the family.
class AvafliV2Font {
  AvafliV2Font._();

  static const String _package = 'avafli_sdk';

  static TextStyle inter(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AvafliV2Colors.textPrimary,
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
    Color color = AvafliV2Colors.textPrimary,
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

/// Minimum line height (leading multiple) for the big Inter Black display
/// lines — the prize-card lockups and the white prize strip.
///
/// Flutter's `height` REPLACES the font's natural leading: `height: 1.0`
/// yields a line box exactly `fontSize` tall, and Inter Black's real metrics
/// (ascent 0.969em + descent 0.241em) do not fit in it, so glyphs spill out of
/// their line box and collide with the neighbouring line. 1.15 gives 0.23em of
/// descent space — roughly double the deepest descender in these strings (the
/// comma in "$1,000" and the "$" tail) — so stacked display lines can never
/// touch, at any FittedBox scale.
const double avafliV2HeadlineLineHeight = 1.15;

/// Bundled images — mirrors iOS `AvafliV2Asset`.
class AvafliV2Assets {
  AvafliV2Assets._();

  static const String package = 'avafli_sdk';

  /// Default prize hero (money pile) — used when the publisher hasn't set a
  /// prize image.
  static const String cashHero = 'assets/images/cash-hero-single.png';
  static const String trophy = 'assets/images/trophy.png';
  static const String winnerModalBg = 'assets/images/winner-modal-bg.png';

  /// Joe's Figma reveal-beat confetti explosion (one-shot GIF played by
  /// `AvafliV2GifView`; same file the iOS SDK bundles).
  static const String confettiBurst = 'assets/images/confetti-burst.gif';

  static Image image(String name, {BoxFit fit = BoxFit.contain}) {
    return Image.asset(name, package: package, fit: fit);
  }
}

/// Ladder math (mirrors the backend + iOS `AvafliV2Ladder` exactly).
class AvafliV2Ladder {
  AvafliV2Ladder._();

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
String avafliV2FormatInt(int value) {
  final digits = value.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return value < 0 ? '-$grouped' : grouped;
}
