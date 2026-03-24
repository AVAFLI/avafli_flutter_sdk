import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/sdk_copy.dart';
import '../domain/sdk_media.dart';
import '../winr_branding.dart';

/// Bonus entries view — matches iOS BonusEntriesView.swift.
///
/// Simple: title, description, watch & claim button, skip button.
class BonusEntriesView extends StatelessWidget {
  final WINRBranding branding;
  final int entries;
  final SdkCopy? sdkCopy;
  final SdkMedia? sdkMedia;
  final VoidCallback onClaim;
  final VoidCallback onSkip;

  const BonusEntriesView({
    super.key,
    required this.branding,
    required this.entries,
    this.sdkCopy,
    this.sdkMedia,
    required this.onClaim,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50, left: 24, right: 24),
      child: Column(
        children: [
          // Title
          Text(
            sdkCopy?.bonusEntries?.title ?? 'BONUS ENTRIES',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: branding.primaryColor,
            ),
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            (sdkCopy?.bonusEntries?.subtitle ?? 'Watch a short video to double today\'s {entries} entries.')
                .replaceAll('{entries}', '$entries'),
            style: TextStyle(
              fontSize: 16,
              color: branding.primaryColor.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Watch & Claim button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onClaim();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: branding.primaryColor,
                borderRadius: BorderRadius.circular(branding.cornerRadius),
              ),
              child: Center(
                child: Text(
                  (sdkCopy?.bonusEntries?.watchButton ?? 'WATCH & CLAIM {total} ENTRIES')
                      .replaceAll('{total}', '${entries * 2}'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: branding.backgroundColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Skip button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onSkip();
            },
            child: Text(
              (sdkCopy?.bonusEntries?.skipText ?? 'No thanks, continue with {entries} entries')
                  .replaceAll('{entries}', '$entries'),
              style: TextStyle(
                fontSize: 14,
                color: branding.primaryColor.withValues(alpha: 0.7),
              ),
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}
