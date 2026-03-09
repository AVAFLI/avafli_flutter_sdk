import 'package:flutter/material.dart';
import '../winr_branding.dart';

/// Bonus entries view — matches iOS BonusEntriesView.swift.
///
/// Simple: title, description, watch & claim button, skip button.
class BonusEntriesView extends StatelessWidget {
  final WINRBranding branding;
  final int entries;
  final VoidCallback onClaim;
  final VoidCallback onSkip;

  const BonusEntriesView({
    super.key,
    required this.branding,
    required this.entries,
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
            'BONUS ENTRIES',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: branding.primaryColor,
            ),
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            'Watch a short video to double today\'s $entries entries.',
            style: TextStyle(
              fontSize: 16,
              color: branding.primaryColor.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Watch & Claim button
          GestureDetector(
            onTap: onClaim,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: branding.primaryColor,
                borderRadius: BorderRadius.circular(branding.cornerRadius),
              ),
              child: Center(
                child: Text(
                  'WATCH & CLAIM ${entries * 2} ENTRIES',
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
            onTap: onSkip,
            child: Text(
              'No thanks, continue with $entries entries',
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
