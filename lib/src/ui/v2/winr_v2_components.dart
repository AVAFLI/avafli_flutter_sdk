// Reusable pieces of the V2 experience, matched to the Figma components:
// TOP UI header, Cash/Prize tile, STREAK STEP rail, CONFIRMATION bar, CTA.
//
// Mirrors the iOS SDK's WINRV2Components.swift.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'winr_v2_effects.dart';
import 'winr_v2_theme.dart';

// ---------------------------------------------------------------------------
// Drawer chrome
// ---------------------------------------------------------------------------

/// The little grab handle at the top of the drawer (Figma "TAB").
class WINRV2TabGrabber extends StatelessWidget {
  const WINRV2TabGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 51,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }
}

/// TOP UI: "?" circle • publisher logo • "X" circle.
/// The logo is one of the three publisher-configurable elements.
/// When [showsBack] is true the "?" is replaced by a back ARROW.
class WINRV2Header extends StatelessWidget {
  final String? logoUrl;
  final bool showsBack;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final VoidCallback onClose;

  const WINRV2Header({
    super.key,
    required this.logoUrl,
    this.showsBack = false,
    this.onBack = _noop,
    required this.onInfo,
    required this.onClose,
  });

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _circleButton(
            onTap: showsBack ? onBack : onInfo,
            child: showsBack
                ? const Icon(Icons.chevron_left, size: 20, color: Colors.white)
                : Text('?', style: WINRV2Font.inter(16)),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 210, maxHeight: 60),
                child: _logo(),
              ),
            ),
          ),
          _circleButton(
            onTap: onClose,
            child: const Icon(Icons.close, size: 14, color: Colors.white),
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

  Widget _circleButton({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: WINRV2Colors.deepCharcoal,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// The radial primary-color glow that bleeds from the top of the drawer into
/// gunmetal.
class WINRV2TopGlow extends StatelessWidget {
  final Color accent;

  const WINRV2TopGlow({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.15,
            stops: const [0, 0.35, 0.8, 1],
            colors: [
              accent,
              accent.withValues(alpha: 0.55),
              WINRV2Colors.gunmetal.withValues(alpha: 0.9),
              WINRV2Colors.gunmetal,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prize presentation
// ---------------------------------------------------------------------------

/// Whether the prize renders the cash lockup (mirrors iOS `isCashPrize`).
bool winrV2IsCashPrize(String description) =>
    description.isEmpty || description.toLowerCase().contains('cash');

/// Leading-character article rule (mirrors iOS): keyed off the LEADING token —
/// "$500 Amazon..." reads "a five-hundred...", so any non-letter start takes
/// "a"; only a leading vowel takes "an".
String winrV2Article(String description) {
  final trimmed = description.trim();
  if (trimmed.isEmpty) return 'a';
  final first = trimmed[0];
  if (!RegExp(r'[a-zA-Z]').hasMatch(first)) return 'a';
  return 'AEIOU'.contains(first.toUpperCase()) ? 'an' : 'a';
}

/// The value subtitle is redundant when the prize name already states the
/// amount ("$500 Amazon Gift Card") — mirrors iOS.
bool winrV2ShowsValueLine(String description, int value) =>
    value > 0 &&
    !description.contains('\$${winrV2FormatInt(value)}') &&
    !description.contains('\$$value');

/// Day 2+ prize card: white stats strip (streak + total entries) over the
/// prize image. The image is publisher-configurable (prizeImageUrl); default
/// is the bundled cash pile with "WIN $X,XXX" overlaid.
class WINRV2PrizeCard extends StatelessWidget {
  final Color accent;
  final int streakDay;
  final int totalEntries;
  final String? prizeImageUrl;
  final int prizeValue;
  final String prizeDescription;
  final bool visitMode;

  const WINRV2PrizeCard({
    super.key,
    required this.accent,
    required this.streakDay,
    required this.totalEntries,
    required this.prizeImageUrl,
    required this.prizeValue,
    required this.prizeDescription,
    this.visitMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_statsStrip(), _promo()],
      ),
    );
  }

  Widget _statsStrip() {
    return Container(
      height: 46,
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, size: 22, color: accent),
                const SizedBox(width: 7),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streakDay ${visitMode ? 'VISIT' : 'DAY'} STREAK',
                      style: WINRV2Font.inter(
                        15,
                        weight: FontWeight.w900,
                        color: accent,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Keep it going!',
                      style: WINRV2Font.inter(
                        12,
                        weight: FontWeight.w500,
                        color: WINRV2Colors.gunmetal,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.rotate(
                  angle: -25 * 3.1415926535 / 180,
                  child:
                      Icon(Icons.confirmation_number, size: 20, color: accent),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      winrV2FormatInt(totalEntries),
                      style: WINRV2Font.inter(
                        15,
                        weight: FontWeight.w900,
                        color: accent,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Total Entries',
                      style: WINRV2Font.inter(
                        12,
                        weight: FontWeight.w500,
                        color: WINRV2Colors.gunmetal,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _promo() {
    final url = prizeImageUrl;
    if (url != null && url.isNotEmpty) {
      // Publisher-supplied prize art fills the card as-is.
      return SizedBox(
        height: 150,
        width: double.infinity,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: WINRV2Colors.gunmetal),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const ColoredBox(color: WINRV2Colors.gunmetal),
        ),
      );
    }

    // Default: bundled cash pile fading up into white, with the prize-derived
    // headline over the fade (Figma cash card).
    final isCash = winrV2IsCashPrize(prizeDescription);
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: OverflowBox(
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: const Offset(0, 14),
                child: Image.asset(
                  WINRV2Assets.cashHero,
                  package: WINRV2Assets.package,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.3, 0.62],
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0x8CFFFFFF),
                  Color(0x00FFFFFF),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: isCash ? _cashLockup() : _prizeLockup(),
          ),
        ],
      ),
    );
  }

  Widget _cashLockup() {
    // Figma cash lockup: "WIN $1,000" (Black 54) over "CASH PRIZE" (Black 19),
    // right-aligned.
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 4),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'WIN \$${winrV2FormatInt(prizeValue)}',
                maxLines: 1,
                style: WINRV2Font.inter(
                  54,
                  weight: FontWeight.w900,
                  color: WINRV2Colors.gunmetal,
                  letterSpacing: -2.7,
                  height: 1.0,
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -6),
              child: Text(
                'CASH PRIZE',
                style: WINRV2Font.inter(
                  19,
                  weight: FontWeight.w900,
                  color: WINRV2Colors.gunmetal,
                  letterSpacing: -0.57,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prizeLockup() {
    // "WIN A $500 AMAZON GIFT CARD" + "$500.00 Value!"
    final article = winrV2Article(prizeDescription).toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'WIN $article ${prizeDescription.toUpperCase()}',
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: WINRV2Font.inter(
              30,
              weight: FontWeight.w900,
              color: WINRV2Colors.gunmetal,
              letterSpacing: -1.1,
              height: 1.0,
            ),
          ),
          if (winrV2ShowsValueLine(prizeDescription, prizeValue))
            Text(
              '\$${winrV2FormatInt(prizeValue)}.00 Value!',
              style: WINRV2Font.inter(
                15,
                weight: FontWeight.w700,
                color: WINRV2Colors.gunmetal,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak rail (STREAK STEP + MILESTONE tiles)
// ---------------------------------------------------------------------------

enum WINRV2TileState { completed, active, locked }

/// One entry in the horizontally-scrolling streak rail — either a day tile or
/// a milestone "power-up" accelerator tile.
class WINRV2RailEntry {
  final String id;
  final int? day;
  final int? entries;
  final WINRV2TileState? state;
  final String? powerUpLabel;
  final int? powerUpBonus;
  final String? powerUpFootnote;

  const WINRV2RailEntry.day({
    required this.id,
    required int this.day,
    required int this.entries,
    required WINRV2TileState this.state,
  })  : powerUpLabel = null,
        powerUpBonus = null,
        powerUpFootnote = null;

  const WINRV2RailEntry.powerUp({
    required this.id,
    required String label,
    required int bonus,
    required String footnote,
  })  : day = null,
        entries = null,
        state = null,
        powerUpLabel = label,
        powerUpBonus = bonus,
        powerUpFootnote = footnote;

  bool get isPowerUp => powerUpLabel != null;
}

/// Horizontally-scrolling rail of streak tiles with the "DAILY PROGRESS ▾"
/// pointer riding above the CURRENT tile. Auto-centers the active tile after
/// ~350ms (mirrors iOS `WINRV2StreakRail`).
class WINRV2StreakRail extends StatefulWidget {
  final Color accent;
  final List<WINRV2RailEntry> entries;
  final String? activeID;
  final bool visitMode;

  const WINRV2StreakRail({
    super.key,
    required this.accent,
    required this.entries,
    required this.activeID,
    this.visitMode = false,
  });

  @override
  State<WINRV2StreakRail> createState() => _WINRV2StreakRailState();
}

class _WINRV2StreakRailState extends State<WINRV2StreakRail> {
  final ScrollController _controller = ScrollController();

  static const double _tileWidth = 106;
  static const double _spacing = 12;
  static const double _hPadding = 24;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), _centerActive);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _centerActive() {
    if (!mounted || !_controller.hasClients) return;
    final index =
        widget.entries.indexWhere((e) => e.id == widget.activeID);
    if (index < 0) return;
    final tileCenter =
        _hPadding + index * (_tileWidth + _spacing) + _tileWidth / 2;
    final viewport = _controller.position.viewportDimension;
    final target = (tileCenter - viewport / 2)
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(
          left: _hPadding, right: _hPadding, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < widget.entries.length; i++) ...[
            if (i > 0) const SizedBox(width: _spacing),
            // The "DAILY PROGRESS ▾" pointer rides ABOVE the current tile
            // and scrolls with it.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pointer(visible: widget.entries[i].id == widget.activeID),
                _tile(widget.entries[i]),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pointer({required bool visible}) {
    return Opacity(
      opacity: visible ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.visitMode ? 'PROGRESS' : 'DAILY PROGRESS',
              style: WINRV2Font.oswald(12),
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 2),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _tile(WINRV2RailEntry entry) {
    if (entry.isPowerUp) {
      return WINRV2PowerUpTile(
        accent: widget.accent,
        label: entry.powerUpLabel!,
        bonus: entry.powerUpBonus!,
        footnote: entry.powerUpFootnote!,
      );
    }
    return WINRV2StreakTile(
      accent: widget.accent,
      day: entry.day!,
      entries: entry.entries!,
      state: entry.state!,
      visitMode: widget.visitMode,
    );
  }
}

/// A single 106x134 streak day tile (completed / active / locked states).
class WINRV2StreakTile extends StatelessWidget {
  final Color accent;
  final int day;
  final int entries;
  final WINRV2TileState state;
  final bool visitMode;

  const WINRV2StreakTile({
    super.key,
    required this.accent,
    required this.day,
    required this.entries,
    required this.state,
    this.visitMode = false,
  });

  String get _noun => visitMode ? 'VISIT' : 'DAY';

  @override
  Widget build(BuildContext context) {
    if (state == WINRV2TileState.active) {
      // Active-tile motion: breathing glow + confetti specks scattered around
      // the tile.
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Positioned(
            width: 152,
            height: 176,
            child: WINRV2Confetti(count: 12, speed: 0.7),
          ),
          WINRV2PulseGlow(accent: accent, child: _card()),
        ],
      );
    }
    return _card();
  }

  Color get _numberColor {
    switch (state) {
      case WINRV2TileState.completed:
        return accent;
      case WINRV2TileState.active:
        return Colors.white;
      case WINRV2TileState.locked:
        return WINRV2Colors.foregroundSecondary;
    }
  }

  Color get _labelColor => state == WINRV2TileState.locked
      ? WINRV2Colors.foregroundSecondary
      : Colors.white;

  Widget _card() {
    return Container(
      width: 106,
      height: 134,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
      decoration: BoxDecoration(
        color:
            state == WINRV2TileState.active ? null : WINRV2Colors.gunmetal,
        gradient: state == WINRV2TileState.active
            ? RadialGradient(
                center: Alignment.topCenter,
                radius: 1.15,
                stops: const [0, 0.45, 1],
                colors: [
                  accent,
                  accent.withValues(alpha: 0.45),
                  WINRV2Colors.gunmetal,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              day >= 31 ? '$_noun 31 +' : '$_noun $day',
              softWrap: false,
              overflow: TextOverflow.visible,
              style: WINRV2Font.inter(12, weight: FontWeight.w700, height: 1),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  winrV2FormatInt(entries),
                  maxLines: 1,
                  style: WINRV2Font.inter(
                    30,
                    weight: FontWeight.w900,
                    color: _numberColor,
                    letterSpacing: -1.5,
                    height: 1.0,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -2),
                child: Text(
                  'ENTRIES',
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: WINRV2Font.inter(
                    15,
                    weight: FontWeight.w700,
                    color: _labelColor,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 24, height: 24, child: Center(child: _icon())),
        ],
      ),
    );
  }

  Widget _icon() {
    switch (state) {
      case WINRV2TileState.completed:
        return const SizedBox(
          width: 20,
          height: 20,
          child: WINRV2AnimatedCheckmark(lineWidth: 2.5, animated: false),
        );
      case WINRV2TileState.active:
        return const SizedBox(
          width: 20,
          height: 20,
          child: WINRV2AnimatedCheckmark(lineWidth: 2.5),
        );
      case WINRV2TileState.locked:
        return Icon(Icons.lock, size: 18, color: _labelColor);
    }
  }
}

/// The "STREAK BONUS!" accelerator tile (Figma MILESTONE TILE right half) —
/// "+25 EVERY DAY!".
class WINRV2PowerUpTile extends StatelessWidget {
  final Color accent;
  final String label; // e.g. "1 WEEK"
  final int bonus; // e.g. 25
  final String footnote; // e.g. "STARTING TOMORROW"

  const WINRV2PowerUpTile({
    super.key,
    required this.accent,
    required this.label,
    required this.bonus,
    required this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 106,
      height: 134,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_fire_department, size: 24, color: Colors.white),
          const Spacer(),
          Text(
            '$label\nSTREAK BONUS!',
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: WINRV2Font.inter(9, weight: FontWeight.w700, height: 1.1),
          ),
          const SizedBox(height: 7),
          Text(
            '+$bonus',
            softWrap: false,
            overflow: TextOverflow.visible,
            style: WINRV2Font.inter(
              26,
              weight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.0,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -2),
            child: Text(
              'EVERY DAY!',
              softWrap: false,
              overflow: TextOverflow.visible,
              style:
                  WINRV2Font.inter(14, weight: FontWeight.w900, height: 1.1),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            footnote,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: WINRV2Font.oswald(8, bold: true),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation ("come back tomorrow") bar
// ---------------------------------------------------------------------------

class WINRV2ComeBackBar extends StatelessWidget {
  final Color accent;
  final int nextEntries;
  final bool visitMode;

  const WINRV2ComeBackBar({
    super.key,
    required this.accent,
    required this.nextEntries,
    this.visitMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 71,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 26, color: accent),
              const SizedBox(width: 14),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    visitMode
                        ? 'Come back again to receive:'
                        : 'Come back tomorrow to\nkeep your streak alive and receive:',
                    textAlign: TextAlign.center,
                    style: WINRV2Font.inter(12, height: 1.2),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${winrV2FormatInt(nextEntries)} ENTRIES',
                    style: WINRV2Font.inter(
                      16,
                      weight: FontWeight.w900,
                      color: accent,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Celebratory sprinkles drifting over the reward line.
          const ClipRect(
            child: WINRV2Confetti(count: 10, speed: 0.55),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA + legal
// ---------------------------------------------------------------------------

class WINRV2PillButton extends StatelessWidget {
  final Color accent;
  final String title;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const WINRV2PillButton({
    super.key,
    required this.accent,
    required this.title,
    this.isLoading = false,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: (enabled && !isLoading) ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: WINRV2Font.inter(
                        24,
                        weight: FontWeight.w800,
                        letterSpacing: -0.72,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class WINRV2LegalLinks extends StatelessWidget {
  final String? rulesUrl;
  final bool showPoweredBy;

  const WINRV2LegalLinks({
    super.key,
    required this.rulesUrl,
    this.showPoweredBy = false,
  });

  void _open() {
    final url = rulesUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _link('OFFICIAL RULES'),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: WINRV2Colors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            _link('PRIVACY POLICY'),
          ],
        ),
        if (showPoweredBy) ...[
          const SizedBox(height: 3),
          Text(
            'Powered by © WINR Media',
            style: WINRV2Font.inter(12, color: WINRV2Colors.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _link(String title) {
    return GestureDetector(
      onTap: _open,
      behavior: HitTestBehavior.opaque,
      child: Text(
        title,
        style: WINRV2Font.inter(12, color: WINRV2Colors.textSecondary),
      ),
    );
  }
}
