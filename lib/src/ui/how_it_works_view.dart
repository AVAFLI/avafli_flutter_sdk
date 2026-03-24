import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:winr_flutter_sdk/shared/constants/image_strings.dart';

import '../domain/sdk_copy.dart';
import '../domain/sdk_media.dart';
import '../winr_branding.dart';

/// How It Works view — matches iOS WINRExperienceHowItWorksView.swift.
///
/// Scrollable view with numbered step rows, pro-tip card, and sticky "Got It!" CTA.
class HowItWorksView extends StatelessWidget {
  final WINRBranding branding;
  final SdkCopy? sdkCopy;
  final SdkMedia? sdkMedia;
  final VoidCallback onPrimary;

  const HowItWorksView({
    super.key,
    required this.branding,
    this.sdkCopy,
    this.sdkMedia,
    required this.onPrimary,
  });

  Widget _buildHeroMedia(
    ScreenMedia? media,
    Widget defaultWidget, {
    double? width,
    double? height,
  }) {
    if (media?.lottieUrl != null && media!.lottieUrl!.isNotEmpty) {
      return Lottie.network(
        media.lottieUrl!,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => defaultWidget,
      );
    }
    if (media?.imageUrl != null && media!.imageUrl!.isNotEmpty) {
      return Image.network(
        media.imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => defaultWidget,
      );
    }
    return defaultWidget;
  }

  List<({IconData icon, String title, String desc})> get _steps => [
        (
          icon: Icons.calendar_month,
          title: sdkCopy?.howItWorks?.step1Title ?? 'Visit Daily',
          desc: sdkCopy?.howItWorks?.step1Description ??
              'Open the app each day to claim your daily entries.',
        ),
        (
          icon: Icons.local_fire_department,
          title: sdkCopy?.howItWorks?.step2Title ?? 'Build Your Streak',
          desc: sdkCopy?.howItWorks?.step2Description ??
              'Keep your streak alive — the longer it goes, the more entries you earn each day.',
        ),
        (
          icon: Icons.play_circle_filled,
          title: sdkCopy?.howItWorks?.step3Title ?? 'Watch & Double',
          desc: sdkCopy?.howItWorks?.step3Description ??
              'Watch an optional short video to double your daily entries.',
        ),
        (
          icon: Icons.card_giftcard,
          title: sdkCopy?.howItWorks?.step4Title ?? 'Win Prizes',
          desc: sdkCopy?.howItWorks?.step4Description ??
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
                  // Hero media
                  const SizedBox(height: 4),
                  _buildHeroMedia(
                    sdkMedia?.howItWorks,
                    branding.logo != null
                        ? SizedBox(
                            width: constraints.maxWidth * 0.5,
                            height: constraints.maxHeight * 0.15,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: branding.logo!,
                            ),
                          )
                        : Lottie.asset(ImageStrings.howItWorksAnimation),
                    width: constraints.maxWidth * 0.5,
                    height: constraints.maxHeight * 0.15,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sdkCopy?.howItWorks?.title ?? 'How It Works',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: branding.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sdkCopy?.howItWorks?.subtitle ??
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
                        color:
                            branding.primaryButtonColor.withValues(alpha: 0.2),
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
                            sdkCopy?.howItWorks?.tip ??
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
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onPrimary();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: branding.primaryButtonColor,
                      borderRadius:
                          BorderRadius.circular(branding.cornerRadius),
                      boxShadow: [
                        BoxShadow(
                          color:
                              branding.accentGlowColor.withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        sdkCopy?.howItWorks?.gotItButton ?? 'Got It!',
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
