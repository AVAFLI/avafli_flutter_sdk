// "WE HAVE A WINNER!" banner + winners dialog, from the Figma
// (MESSAGE TOAST / WINNER, Modal Property 1=Winner). Shown when the giveaway
// payload carries a latestWinner AND the server flag
// `sdkConfig.experience.winnerBannerEnabled` is exactly true (default hidden
// — Aug 31 GTM decision; the banner is also the winner-feed modal's only
// entry point, so hiding it hides the feed).
//
// Mirrors the iOS SDK's AvafliV2Winner.swift.

import 'package:flutter/material.dart';

import '../../domain/giveaway.dart';
import 'avafli_v2_effects.dart';
import 'avafli_v2_svg_icon.dart';
import 'avafli_v2_theme.dart';

// ---------------------------------------------------------------------------
// Banner (below the header, above the prize card)
// ---------------------------------------------------------------------------

class AvafliV2WinnerBanner extends StatelessWidget {
  final VoidCallback onTap;

  const AvafliV2WinnerBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 70,
        width: double.infinity,
        color: AvafliV2Colors.deepCharcoal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Design mirrors the trophy on the toast.
            Transform.flip(
              flipX: true,
              child: SizedBox(
                width: 41,
                height: 54,
                child: ClipRect(
                  child: Image.asset(
                    AvafliV2Assets.trophy,
                    package: AvafliV2Assets.package,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'WE HAVE A WINNER!',
                    style: AvafliV2Font.inter(
                      17,
                      weight: FontWeight.w800,
                      letterSpacing: -0.85,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Tap to see latest winners.',
                    style: AvafliV2Font.inter(
                      12,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AvafliV2Colors.gunmetal,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const AvafliV2BrandIcon(
                AvafliV2BrandGlyphs.winnerPlus,
                width: 18,
                height: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Winners dialog
// ---------------------------------------------------------------------------

class AvafliV2WinnerModal extends StatefulWidget {
  final Color accent;
  final GiveawayWinner winner;
  final VoidCallback onDismiss;

  const AvafliV2WinnerModal({
    super.key,
    required this.accent,
    required this.winner,
    required this.onDismiss,
  });

  @override
  State<AvafliV2WinnerModal> createState() => _AvafliV2WinnerModalState();
}

class _AvafliV2WinnerModalState extends State<AvafliV2WinnerModal> {
  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _appeared = true);
    });
  }

  Color get accent => widget.accent;
  GiveawayWinner get winner => widget.winner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: widget.onDismiss,
          child: const ColoredBox(color: Color(0x8C000000)),
        ),
        Center(
          child: AnimatedScale(
            scale: _appeared ? 1 : 0.9,
            // iOS parity: .spring(response: 0.4, dampingFraction: 0.8) —
            // real spring physics (the opacity fade below stays a plain
            // ramp; raw Opacity can't take the spring's >1 overshoot).
            duration: avafliV2ModalSpring.duration,
            curve: avafliV2ModalSpring,
            child: AnimatedOpacity(
              opacity: _appeared ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _card(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Gold-sparkle art behind the content (Figma bg export + gold
                // confetti drift).
                Positioned.fill(
                  child: ColoredBox(
                    color: AvafliV2Colors.deepCharcoal,
                    child: Opacity(
                      opacity: 0.9,
                      child: Image.asset(
                        AvafliV2Assets.winnerModalBg,
                        package: AvafliV2Assets.package,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x00000000), Color(0xBF000000)],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: AvafliV2Confetti(
                    style: AvafliV2ConfettiStyle.gold,
                    count: 26,
                    speed: 0.7,
                  ),
                ),
                _content(),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: widget.onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AvafliV2Colors.gunmetal,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const AvafliV2BrandIcon(
                  AvafliV2BrandGlyphs.close,
                  width: 11,
                  height: 11,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 129,
                child: Center(
                  child: Transform.rotate(
                    angle: -5.96 * 3.1415926535 / 180,
                    child: Image.asset(
                      AvafliV2Assets.trophy,
                      package: AvafliV2Assets.package,
                      width: 114,
                      height: 153,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'WE HAVE A',
                      style: AvafliV2Font.inter(
                        23,
                        weight: FontWeight.w700,
                        letterSpacing: -1.15,
                        height: 1.1,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'WINNER!',
                        maxLines: 1,
                        style: AvafliV2Font.inter(
                          44,
                          weight: FontWeight.w900,
                          color: accent,
                          letterSpacing: -2.2,
                          height: 1.05,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        'Congratulations to our latest big winner!',
                        textAlign: TextAlign.center,
                        style: AvafliV2Font.inter(
                          15,
                          letterSpacing: -0.75,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'LATEST WINNER:',
            style: AvafliV2Font.inter(19, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _winnerPill(),
          const SizedBox(height: 8),
          if (winner.awardedAtDisplay != null)
            Text(
              'This prize awarded on ${winner.awardedAtDisplay}',
              textAlign: TextAlign.center,
              style: AvafliV2Font.inter(16, height: 1.2),
            ),
          const SizedBox(height: 3),
          Text(
            'All new prize available now! Keep going!',
            textAlign: TextAlign.center,
            style: AvafliV2Font.inter(16, weight: FontWeight.w700, height: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _winnerPill() {
    return Container(
      height: 72,
      padding: const EdgeInsets.only(left: 13, right: 20),
      decoration: BoxDecoration(
        color: AvafliV2Colors.gunmetal,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: accent, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatar(),
          const SizedBox(width: 11),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winner.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AvafliV2Font.inter(
                    20,
                    weight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (winner.location != null)
                  Text(
                    winner.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AvafliV2Font.inter(20, height: 1.15),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final url = winner.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 51,
          height: 51,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsCircle(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _initialsCircle(),
          ),
        ),
      );
    }
    return SizedBox(width: 51, height: 51, child: _initialsCircle());
  }

  /// Initials fallback when there's no avatar image.
  Widget _initialsCircle() {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        winner.name.isEmpty ? '' : winner.name.substring(0, 1),
        style: AvafliV2Font.inter(24, weight: FontWeight.w700),
      ),
    );
  }
}
