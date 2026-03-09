import 'package:flutter/material.dart';
import '../winr_branding.dart';

/// How It Works view — matches iOS WINRExperienceHowItWorksView.swift.
///
/// Scrollable view with numbered step rows, pro-tip card, and sticky "Got It!" CTA.
class HowItWorksView extends StatelessWidget {
  final WINRBranding branding;
  final VoidCallback onPrimary;

  const HowItWorksView({
    super.key,
    required this.branding,
    required this.onPrimary,
  });

  static const _steps = [
    (
      icon: Icons.calendar_month,
      title: 'Visit Daily',
      desc: 'Open the app each day to claim your daily entries.',
    ),
    (
      icon: Icons.local_fire_department,
      title: 'Build Your Streak',
      desc:
          'Keep your streak alive — the longer it goes, the more entries you earn each day.',
    ),
    (
      icon: Icons.play_circle_filled,
      title: 'Watch & Double',
      desc: 'Watch an optional short video to double your daily entries.',
    ),
    (
      icon: Icons.card_giftcard,
      title: 'Win Prizes',
      desc:
          'Your entries go into the monthly prize drawing. More entries = better odds!',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final safeBottom = bottomPadding == 0 ? 20.0 : bottomPadding;

        return Stack(
          children: [
            // Scrollable content
            SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: 140,
                top: 4,
              ),
              child: Column(
                children: [
                  // Hero
                  const SizedBox(height: 4),
                  const Text('🎰', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 10),
                  Text(
                    'How It Works',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: branding.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Earn entries every day for a chance to win big.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: branding.mutedTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Steps
                  ...List.generate(_steps.length, (index) {
                    final step = _steps[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _StepRow(
                        number: index + 1,
                        icon: step.icon,
                        title: step.title,
                        description: step.desc,
                        branding: branding,
                      ),
                    );
                  }),

                  // Tip card
                  Container(
                    padding: const EdgeInsets.all(14),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color:
                          branding.primaryButtonColor.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(branding.cornerRadius),
                      border: Border.all(
                        color: branding.primaryButtonColor
                            .withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb,
                          size: 20,
                          color: branding.primaryButtonColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pro tip: A 5-day streak earns a weekly bonus of extra entries!',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: branding.mutedTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sticky CTA
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: safeBottom,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      branding.backgroundColor.withValues(alpha: 0.0),
                      branding.backgroundColor.withValues(alpha: 0.96),
                    ],
                  ),
                ),
                child: GestureDetector(
                  onTap: onPrimary,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: branding.primaryButtonColor,
                      borderRadius:
                          BorderRadius.circular(branding.cornerRadius),
                      boxShadow: [
                        BoxShadow(
                          color: branding.accentGlowColor
                              .withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Got It!',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: branding.primaryButtonTextColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Individual step row — matches iOS StepRow.
class _StepRow extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String description;
  final WINRBranding branding;

  const _StepRow({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.branding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: branding.cardBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(branding.cornerRadius),
        border: Border.all(
          color: branding.cardBorderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  branding.primaryButtonColor,
                  branding.primaryButtonColor.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: branding.primaryButtonTextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: branding.accentGlowColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: branding.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: branding.mutedTextColor,
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
