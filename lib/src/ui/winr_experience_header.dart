import 'package:flutter/material.dart';
import '../winr_branding.dart';

/// Header component for the WINR experience with branding and navigation.
/// 
/// Displays the campaign title, branding elements, and provides navigation
/// controls like close button and optional action buttons.
class WINRExperienceHeader extends StatefulWidget {
  /// The branding configuration for styling
  final WINRBranding branding;
  
  /// The title to display
  final String title;
  
  /// Callback when the close button is pressed
  final VoidCallback onClose;
  
  /// Optional subtitle text
  final String? subtitle;
  
  /// Optional action button
  final Widget? actionButton;
  
  /// Whether to show the logo
  final bool showLogo;
  
  /// Whether to show a back button instead of close
  final bool showBackButton;
  
  /// Callback for back button (if showBackButton is true)
  final VoidCallback? onBack;

  const WINRExperienceHeader({
    super.key,
    required this.branding,
    required this.title,
    required this.onClose,
    this.subtitle,
    this.actionButton,
    this.showLogo = true,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  State<WINRExperienceHeader> createState() => _WINRExperienceHeaderState();
}

class _WINRExperienceHeaderState extends State<WINRExperienceHeader>
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _fadeController.forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.branding.backgroundColor,
              widget.branding.backgroundColor.withValues(alpha: 0.9),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildNavigationRow(),
              if (widget.showLogo) ...[
                const SizedBox(height: 20),
                _buildLogo(),
              ],
              const SizedBox(height: 20),
              _buildTitleSection(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavigationRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back/Close button
        IconButton(
          onPressed: widget.showBackButton ? widget.onBack : widget.onClose,
          icon: Icon(
            widget.showBackButton ? Icons.arrow_back : Icons.close,
            color: widget.branding.primaryColor,
            size: 24,
          ),
          style: IconButton.styleFrom(
            backgroundColor: widget.branding.cardBackgroundColor.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
          ),
        ),
        
        // Action button (if provided)
        if (widget.actionButton != null)
          widget.actionButton!
        else
          const SizedBox(width: 48), // Spacer to balance layout
      ],
    );
  }
  
  Widget _buildLogo() {
    if (widget.branding.logo != null) {
      return SizedBox(
        height: 60,
        child: widget.branding.logo!,
      );
    }
    
    return _buildDefaultLogo();
  }
  
  Widget _buildDefaultLogo() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.branding.primaryButtonColor,
            widget.branding.accentGlowColor,
          ],
        ),
        borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
        boxShadow: [
          BoxShadow(
            color: widget.branding.accentGlowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.emoji_events,
        size: 32,
        color: widget.branding.primaryButtonTextColor,
      ),
    );
  }
  
  Widget _buildTitleSection() {
    return Column(
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: widget.branding.primaryColor,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: widget.branding.secondaryTextColor,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Specialized header for campaigns with prize information.
class WINRCampaignHeader extends StatelessWidget {
  /// The branding configuration for styling
  final WINRBranding branding;
  
  /// Campaign title
  final String title;
  
  /// Prize value to display
  final double prizeValue;
  
  /// Callback when the close button is pressed
  final VoidCallback onClose;
  
  /// Optional campaign end date
  final DateTime? endDate;

  const WINRCampaignHeader({
    super.key,
    required this.branding,
    required this.title,
    required this.prizeValue,
    required this.onClose,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return WINRExperienceHeader(
      branding: branding,
      title: title,
      subtitle: _buildSubtitle(),
      onClose: onClose,
      actionButton: _buildPrizeChip(),
    );
  }
  
  String _buildSubtitle() {
    final subtitle = 'Win ${_formatPrize(prizeValue)}';
    
    if (endDate != null) {
      final daysLeft = endDate!.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        return '$subtitle • $daysLeft days left';
      }
    }
    
    return subtitle;
  }
  
  Widget _buildPrizeChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            branding.primaryButtonColor,
            branding.accentGlowColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: branding.accentGlowColor.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events,
            size: 16,
            color: branding.primaryButtonTextColor,
          ),
          const SizedBox(width: 6),
          Text(
            _formatPrize(prizeValue),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: branding.primaryButtonTextColor,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatPrize(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '\$${value.toStringAsFixed(0)}';
    }
  }
}

/// Simple header for informational screens.
class WINRInfoHeader extends StatelessWidget {
  /// The branding configuration for styling
  final WINRBranding branding;
  
  /// Title to display
  final String title;
  
  /// Icon to show
  final IconData icon;
  
  /// Callback when the close button is pressed
  final VoidCallback onClose;

  const WINRInfoHeader({
    super.key,
    required this.branding,
    required this.title,
    required this.icon,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: Icon(
                Icons.close,
                color: branding.primaryColor,
                size: 24,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: branding.primaryButtonColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: branding.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48), // Balance the close button
          ],
        ),
      ),
    );
  }
}