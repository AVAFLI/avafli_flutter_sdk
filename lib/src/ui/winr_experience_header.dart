import 'package:flutter/material.dart';
import '../winr_branding.dart';

/// Header component for the WINR experience — matches iOS WINRExperienceHeaderView.
///
/// Simple row with circular icon buttons: left (back or info) + spacer + close.
class WINRExperienceHeader extends StatelessWidget {
  final WINRBranding branding;
  final bool showsBack;
  final bool showsInfo;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final VoidCallback onClose;

  const WINRExperienceHeader({
    super.key,
    required this.branding,
    this.showsBack = false,
    this.showsInfo = false,
    required this.onBack,
    required this.onInfo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showsBack)
          _circularIcon(Icons.chevron_left, onBack)
        else if (showsInfo)
          _circularIcon(Icons.help_outline, onInfo)
        else
          const SizedBox(width: 34),
        const Spacer(),
        _circularIcon(Icons.close, onClose),
      ],
    );
  }

  Widget _circularIcon(IconData icon, VoidCallback action) {
    return GestureDetector(
      onTap: action,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: branding.cardBackgroundColor.withValues(alpha: 0.9),
          border: Border.all(
            color: branding.cardBorderColor,
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 14,
            color: branding.primaryColor,
          ),
        ),
      ),
    );
  }
}
