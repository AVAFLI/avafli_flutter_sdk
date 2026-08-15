// Reusable pieces of the V2 experience, matched to the Figma components:
// TOP UI header, Cash/Prize tile, STREAK STEP rail, CONFIRMATION bar, CTA.
//
// Mirrors the iOS SDK's WINRV2Components.swift.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'winr_v2_effects.dart';
import 'winr_v2_strings.dart';
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
        // Cache hits (the prewarmed path) render synchronously; a cold load
        // eases in rather than popping a frame after the drawer appears.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: child,
          );
        },
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

/// Keyboard-aware focus helper: scrolls its child into view whenever
/// [focusNode] gains focus, so a field near the bottom of a form screen is
/// never left hidden under the software keyboard.
///
/// Flutter's built-in caret-reveal only nudges the caret line visible; on
/// short drawers (the experience sheet is ~90% of a possibly-small screen,
/// shrunk further by the keyboard via `resizeToAvoidBottomInset`) that can
/// leave the field's label or error clipped. This waits one beat for the
/// keyboard animation to change the viewport, then centers the whole wrapped
/// field in the nearest enclosing [Scrollable]. No-op when there is no
/// enclosing scrollable or the focus was lost meanwhile.
class WINRV2EnsureVisible extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;

  const WINRV2EnsureVisible({
    super.key,
    required this.focusNode,
    required this.child,
  });

  @override
  State<WINRV2EnsureVisible> createState() => _WINRV2EnsureVisibleState();
}

class _WINRV2EnsureVisibleState extends State<WINRV2EnsureVisible> {
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(WINRV2EnsureVisible oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _settleTimer?.cancel();
      _settleTimer = null;
      return;
    }
    // Let the keyboard resize the viewport first — ensureVisible against the
    // pre-keyboard geometry would scroll to a position that is immediately
    // stale. A cancelable timer so a disposed field never fires.
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 320), () {
      _settleTimer = null;
      if (!mounted || !widget.focusNode.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Soft email-verification nudge: a small, persistent pill on the streak
/// dashboard shown while the person's newly-typed email is unverified. A mail
/// glyph + "Verify your email" in the publisher accent, tappable, subtle — it
/// reads as a gentle prompt, not an error, and never blocks play.
class WINRV2VerifyEmailChip extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const WINRV2VerifyEmailChip({
    super.key,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: WINRV2Strings.emailVerifyChip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            // A faint wash of the accent — tinted, not loud; a nudge.
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mail_outline, size: 16, color: accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  WINRV2Strings.emailVerifyChip,
                  style: WINRV2Font.inter(
                    13,
                    weight: FontWeight.w700,
                    color: accent,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 16, color: accent),
            ],
          ),
        ),
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

/// The white-strip headline (Day-1 capture + winner splash):
/// cash → "$1,000.00 CASH PRIZE"; other → "Win a $500 Amazon Gift Card".
/// Mirrors iOS `WINRV2PrizeText.stripHeadline`.
String winrV2StripHeadline(String description, int value) =>
    winrV2IsCashPrize(description)
        ? '\$${winrV2FormatInt(value)}.00 CASH PRIZE'
        : 'Win ${winrV2Article(description)} $description';

/// Day 2+ prize card (Joe's Aug-2026 dark full-bleed revision): the prize art
/// fills the WHOLE card, a solid black stats strip (streak + total entries)
/// sits inside the top edge, and the prize-derived headline rides the bottom
/// over a black→transparent scrim. The image is publisher-configurable
/// (prizeImageUrl); default is the bundled cash pile.
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

  /// Cash prizes render Joe's right-aligned "WIN $1,000 / CASH PRIZE" lockup;
  /// other prizes render "Win a {Prize}" + "$X.00 VALUE!".
  bool get _isCashPrize => winrV2IsCashPrize(prizeDescription);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _hero(),
            Align(alignment: Alignment.topCenter, child: _statsStrip()),
            Align(alignment: Alignment.bottomCenter, child: _headline()),
          ],
        ),
      ),
    );
  }

  /// The prize art fills the whole card (publisher image, else the bundled
  /// cash pile).
  Widget _hero() {
    final url = prizeImageUrl;
    if (url != null && url.isNotEmpty) {
      // Normally already decoded by [WINRV2ImageWarmer] (warmed the moment the
      // SDK learned the giveaway config), so it paints with the rest of the
      // card. A cold URL fades in over the card's dark background instead of
      // popping, and a broken one falls back to the bundled cash hero.
      return WINRV2RemoteImage(
        url: url,
        fit: BoxFit.cover,
        placeholderColor: WINRV2Colors.deepCharcoal,
        fallbackBuilder: (_) => _bundledHero(),
      );
    }
    return _bundledHero();
  }

  Widget _bundledHero() => Image.asset(
        WINRV2Assets.cashHero,
        package: WINRV2Assets.package,
        fit: BoxFit.cover,
      );

  /// Solid black strip inside the top of the card: accent title + white sub.
  Widget _statsStrip() {
    return Container(
      height: 46,
      color: Colors.black,
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
                    // Counts up when the total changes (the Day 2+ reveal
                    // counts up from the pre-claim total) and pops Joe's
                    // one-shot confetti-burst GIF as it lands.
                    WINRV2CountUpText(value: totalEntries, accent: accent),
                    Text(
                      'Total Entries',
                      style: WINRV2Font.inter(
                        12,
                        weight: FontWeight.w500,
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

  /// Prize headline over the bottom scrim.
  Widget _headline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 14, right: 14, top: 34, bottom: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.45, 1],
          colors: [
            Color(0x00000000),
            Color(0x8C000000), // black 55%
            Color(0xE6000000), // black 90%
          ],
        ),
      ),
      child: _isCashPrize ? _cashLockup() : _prizeLockup(),
    );
  }

  Widget _cashLockup() {
    // "WIN $1,000" (Black 44) over "CASH PRIZE" (Black 19), right-aligned.
    //
    // LEADING IS LOAD-BEARING. iOS gets away with `VStack(spacing: -5)`
    // because SwiftUI line boxes carry natural leading (~1.2) that absorbs the
    // negative spacing. A Flutter `height: 1.0` line box is exactly the font
    // size with NO leading, so Inter Black's overshoot plus the comma's
    // descender spilled out of the box and physically collided with the line
    // below it. Both lines now carry real leading (>= 1.15 == 0.23em of
    // descent space, far more than the ~0.11em the comma/"$" actually use)
    // and there is NO negative offset — the lines can never touch.
    //
    // The two lines share ONE FittedBox so a narrow screen scales the whole
    // lockup uniformly (iOS scales the VStack, not just its first line);
    // scaling a single line while the other stayed fixed is what turned a
    // tight lockup into an overlapping one on smaller devices.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'WIN \$${winrV2FormatInt(prizeValue)}',
                maxLines: 1,
                style: WINRV2Font.inter(
                  44,
                  weight: FontWeight.w900,
                  letterSpacing: -2.2,
                  height: winrV2HeadlineLineHeight,
                ),
              ),
              Text(
                'CASH PRIZE',
                maxLines: 1,
                style: WINRV2Font.inter(
                  19,
                  weight: FontWeight.w900,
                  letterSpacing: -0.57,
                  height: winrV2HeadlineLineHeight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _prizeLockup() {
    // Centered "Win a {Prize}" + accent "$X.00 VALUE!". Same leading rule as
    // the cash lockup — this one wraps to TWO lines ("Win a $500 Amazon Gift
    // Card"), so a 1.0 line box collided line-against-line on descenders.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Win ${winrV2Article(prizeDescription)} $prizeDescription',
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: WINRV2Font.inter(
            28,
            weight: FontWeight.w900,
            letterSpacing: -1.0,
            height: winrV2HeadlineLineHeight,
          ),
        ),
        if (winrV2ShowsValueLine(prizeDescription, prizeValue))
          Text(
            '\$${winrV2FormatInt(prizeValue)}.00 VALUE!',
            style: WINRV2Font.inter(
              15,
              weight: FontWeight.w900,
              color: accent,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Streak rail (STREAK STEP + MILESTONE tiles)
// ---------------------------------------------------------------------------

/// [ready] = today's tile before the user taps CLAIM (claim already granted
/// server-side, reveal withheld): glows like [active] but shows no checkmark.
enum WINRV2TileState { completed, active, ready, locked }

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
    final index = widget.entries.indexWhere((e) => e.id == widget.activeID);
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
      padding:
          const EdgeInsets.only(left: _hPadding, right: _hPadding, bottom: 12),
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
class WINRV2StreakTile extends StatefulWidget {
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

  @override
  State<WINRV2StreakTile> createState() => _WINRV2StreakTileState();
}

class _WINRV2StreakTileState extends State<WINRV2StreakTile> {
  /// One-shot: the confetti-burst GIF plays over the tile when it flips
  /// ready → active at the reveal beat, then removes itself. A tile that
  /// MOUNTS as active (already-claimed reopen) never bursts.
  bool _bursting = false;

  Color get accent => widget.accent;
  int get day => widget.day;
  int get entries => widget.entries;
  WINRV2TileState get state => widget.state;

  String get _noun => widget.visitMode ? 'VISIT' : 'DAY';

  bool get _hasAccentBackground =>
      state == WINRV2TileState.active || state == WINRV2TileState.ready;

  @override
  void didUpdateWidget(WINRV2StreakTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == WINRV2TileState.active &&
        oldWidget.state != WINRV2TileState.active) {
      _bursting = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case WINRV2TileState.active:
        // Joe's settled active tile: breathing glow, drifting confetti
        // field, and the small check drawing into the icon slot. At the
        // reveal beat the confetti-burst GIF explodes once on top at ~150%
        // of the tile — overflowing the bounds like an explosion — then is
        // removed via the GIF's onFinished (see [_bursting]).
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
            if (_bursting)
              Positioned(
                width: 200,
                height: 200,
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
        );
      case WINRV2TileState.ready:
        // Pre-reveal the tile is CALM — a static glow only. Every moving
        // element (pulse, confetti, check draw) is saved for the single
        // celebration moment so nothing animates early.
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.75),
                blurRadius: 10,
              ),
            ],
          ),
          child: _card(),
        );
      case WINRV2TileState.completed:
      case WINRV2TileState.locked:
        return _card();
    }
  }

  Color get _numberColor {
    switch (state) {
      case WINRV2TileState.completed:
        return accent;
      case WINRV2TileState.active:
      case WINRV2TileState.ready:
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
        color: _hasAccentBackground ? null : WINRV2Colors.gunmetal,
        gradient: _hasAccentBackground
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      case WINRV2TileState.ready:
        // Joe's frames: the current tile pre-check shows ONLY the glowing
        // number — no icon. The enclosing 24x24 slot keeps its size so the
        // check can draw into place without the card resizing.
        return const SizedBox(width: 20, height: 20);
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
          const Icon(Icons.local_fire_department,
              size: 24, color: Colors.white),
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
              style: WINRV2Font.inter(14, weight: FontWeight.w900, height: 1.1),
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

class WINRV2ComeBackBar extends StatefulWidget {
  final Color accent;
  final int nextEntries;
  final bool visitMode;

  /// Celebration open (auto-claim, Day 1 AND Day 2+): the bar's FIRST
  /// visible frame is the toast — "YOU'RE IN!" on Day 1 ([firstDay]),
  /// "YOU'RE ON A ROLL!" on Day 2+. It holds ~2.5s, then slides ONCE
  /// (carousel: out left, in from right) to the resting pitch — the pitch is
  /// NEVER visible before the toast on a celebration open. Non-celebration
  /// opens (already-claimed reopen, no grant) rest on the pitch, no toast.
  final bool celebrating;
  final int claimedEntries;

  /// Day 1 celebrates in place exactly like Day 2+ (the "You're in!" modal
  /// is gone) — only the toast headline differs.
  final bool firstDay;

  const WINRV2ComeBackBar({
    super.key,
    required this.accent,
    required this.nextEntries,
    this.visitMode = false,
    this.celebrating = false,
    this.claimedEntries = 0,
    this.firstDay = false,
  });

  @override
  State<WINRV2ComeBackBar> createState() => _WINRV2ComeBackBarState();
}

class _WINRV2ComeBackBarState extends State<WINRV2ComeBackBar> {
  /// Whether the toast is on screen (the hold window). Seeded from
  /// [WINRV2ComeBackBar.celebrating] so the toast is the bar's FIRST frame —
  /// no pitch flash, no slide-in. Only the toast → pitch handoff animates.
  late bool _showToast;
  Timer? _holdTimer;

  /// One-shot guard: the toast plays exactly once per bar, whether it was
  /// seeded at mount or arrived late.
  bool _toastPlayed = false;

  @override
  void initState() {
    super.initState();
    _showToast = widget.celebrating;
    if (_showToast) _startHold();
  }

  @override
  void didUpdateWidget(WINRV2ComeBackBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cache-first render: the dashboard now paints from cached values while
    // the network resolves, so the bar can MOUNT before the claim has been
    // staged. When the celebration arrives a moment later the toast slides in
    // from the right (the carousel's normal forward direction) instead of
    // being missed entirely — and, via [_toastPlayed], never twice.
    if (widget.celebrating && !oldWidget.celebrating && !_toastPlayed) {
      setState(() => _showToast = true);
      _startHold();
    }
  }

  /// Hold the toast a beat, then slide once to the resting pitch.
  void _startHold() {
    _toastPlayed = true;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _showToast = false);
    });
  }

  @override
  void dispose() {
    // Teardown-safe: never fire the hold timer after the bar is gone.
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 71,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          // Carousel: every state slides IN from the right and OUT to the
          // left — one continuous forward direction, never a rewind. The
          // outgoing child's animation runs 1→0, so an off-screen-LEFT
          // `begin` drives it out the leading edge.
          ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final incoming =
                    child.key == ValueKey(_showToast ? 'toast' : 'come-back');
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(incoming ? 1 : -1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _showToast
                  ? _toastContent(key: const ValueKey('toast'))
                  : _comeBackContent(key: const ValueKey('come-back')),
            ),
          ),
          // Celebratory sprinkles drifting over the reward line.
          const ClipRect(
            child: WINRV2Confetti(count: 10, speed: 0.55),
          ),
        ],
      ),
    );
  }

  Color get accent => widget.accent;

  Widget _comeBackContent({required Key key}) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.calendar_today, size: 26, color: accent),
        const SizedBox(width: 14),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // "Come back tomorrow"/"Come back again" is BOLD, the rest
            // regular — per Joe's banner lockup.
            Text.rich(
              TextSpan(
                children: widget.visitMode
                    ? [
                        TextSpan(
                          text: 'Come back again',
                          style: WINRV2Font.inter(12,
                              weight: FontWeight.w700, height: 1.2),
                        ),
                        const TextSpan(text: ' to receive:'),
                      ]
                    : [
                        TextSpan(
                          text: 'Come back tomorrow',
                          style: WINRV2Font.inter(12,
                              weight: FontWeight.w700, height: 1.2),
                        ),
                        const TextSpan(
                            text: ' to\nkeep your streak alive and receive:'),
                      ],
              ),
              textAlign: TextAlign.center,
              style: WINRV2Font.inter(12, height: 1.2),
            ),
            const SizedBox(height: 1),
            Text(
              '${winrV2FormatInt(widget.nextEntries)} ENTRIES',
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
    );
  }

  Widget _toastContent({required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 38,
            height: 38,
            child: WINRV2AnimatedCheckmark(lineWidth: 3.5),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.firstDay ? 'YOU’RE IN!' : 'YOU’RE ON A ROLL!',
                    maxLines: 1,
                    style: WINRV2Font.inter(
                      20,
                      weight: FontWeight.w900,
                      color: accent,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Your ${winrV2FormatInt(widget.claimedEntries)} entries '
                    'have been added automatically.',
                    maxLines: 1,
                    style: WINRV2Font.inter(
                      13,
                      weight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
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

/// Canonical WINR privacy policy, mirroring iOS `WINRConstants.privacyURL`.
/// Publisher config carries no privacy URL (`rulesUrl` covers the Official
/// Rules only), so every "Privacy Policy" link/span falls back to this —
/// previously they silently opened `rulesUrl` instead.
const String winrV2PrivacyPolicyUrl = 'https://winrmedia.com/sdk/privacy';

/// Opens [winrV2PrivacyPolicyUrl] externally — the ONE opener shared by every
/// Privacy Policy link and span, so the destination can never drift per
/// screen.
void winrV2OpenPrivacyPolicy() {
  final uri = Uri.tryParse(winrV2PrivacyPolicyUrl);
  if (uri == null) return;
  launchUrl(uri, mode: LaunchMode.externalApplication);
}

class WINRV2LegalLinks extends StatelessWidget {
  final String? rulesUrl;
  final bool showPoweredBy;

  const WINRV2LegalLinks({
    super.key,
    required this.rulesUrl,
    this.showPoweredBy = false,
  });

  void _openRules() {
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
            _link('OFFICIAL RULES', _openRules),
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
            // The real policy, not rulesUrl — see [winrV2PrivacyPolicyUrl].
            _link('PRIVACY POLICY', winrV2OpenPrivacyPolicy),
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

  Widget _link(String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        title,
        style: WINRV2Font.inter(12, color: WINRV2Colors.textSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counting total readout
// ---------------------------------------------------------------------------

/// The stats-strip total, ported from iOS `WINRV2CountUpText`: counts up
/// smoothly (~0.7s ease-out) when the value changes and pops Joe's one-shot
/// confetti-burst GIF as it lands on the new total.
class WINRV2CountUpText extends StatefulWidget {
  final int value;
  final Color accent;

  const WINRV2CountUpText({
    super.key,
    required this.value,
    required this.accent,
  });

  @override
  State<WINRV2CountUpText> createState() => _WINRV2CountUpTextState();
}

class _WINRV2CountUpTextState extends State<WINRV2CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _from;
  bool _burst = false;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1,
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        // The GIF's onFinished removes the burst overlay.
        setState(() => _burst = true);
      });
  }

  @override
  void didUpdateWidget(WINRV2CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    // Restart the ramp from whatever number is currently displayed.
    final eased = Curves.easeOutCubic.transform(_controller.value);
    _from = (_from + (oldWidget.value - _from) * eased).round();
    _burst = false;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final eased = Curves.easeOutCubic.transform(_controller.value);
            final shown = (_from + (widget.value - _from) * eased).round();
            return Text(
              winrV2FormatInt(shown),
              style: WINRV2Font.inter(
                15,
                weight: FontWeight.w900,
                color: widget.accent,
                letterSpacing: -0.3,
                height: 1.1,
              ),
            );
          },
        ),
        if (_burst)
          Positioned(
            width: 54,
            height: 44,
            child: IgnorePointer(
              child: WINRV2GifView(
                WINRV2Assets.confettiBurst,
                onFinished: () {
                  if (mounted) setState(() => _burst = false);
                },
              ),
            ),
          ),
      ],
    );
  }
}
