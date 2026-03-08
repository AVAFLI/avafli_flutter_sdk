import 'package:flutter/material.dart';
import '../winr_branding.dart';

/// How it works view that explains the WINR sweepstakes system.
/// 
/// Provides an educational overlay or bottom sheet that explains how users
/// can earn entries, build streaks, and increase their chances to win.
class HowItWorksView extends StatefulWidget {
  /// The branding configuration for styling
  final WINRBranding branding;
  
  /// Callback when the view is closed
  final VoidCallback onClose;
  
  /// Optional campaign-specific information
  final String? campaignTitle;
  final double? prizeValue;
  
  /// Whether to show as a modal overlay (vs embedded)
  final bool isModal;

  const HowItWorksView({
    super.key,
    required this.branding,
    required this.onClose,
    this.campaignTitle,
    this.prizeValue,
    this.isModal = true,
  });

  @override
  State<HowItWorksView> createState() => _HowItWorksViewState();
}

class _HowItWorksViewState extends State<HowItWorksView>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<HowItWorksStep> _steps = [];
  
  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _initializeSteps();
    
    // Start animations
    _slideController.forward();
    _fadeController.forward();
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModal) {
      return _buildModal();
    } else {
      return _buildEmbedded();
    }
  }
  
  Widget _buildModal() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.branding.backgroundColor.withOpacity(0.95),
              widget.branding.cardBackgroundColor.withOpacity(0.98),
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmbedded() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.branding.backgroundColor.withOpacity(0.95),
              widget.branding.cardBackgroundColor.withOpacity(0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
          border: Border.all(
            color: widget.branding.primaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (widget.isModal) ...[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.branding.mutedTextColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.branding.primaryButtonColor,
                      widget.branding.accentGlowColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: widget.branding.accentGlowColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.help_outline,
                  size: 24,
                  color: widget.branding.primaryButtonTextColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How It Works',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: widget.branding.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Learn how to maximize your chances',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.branding.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isModal)
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(
                    Icons.close,
                    color: widget.branding.mutedTextColor,
                    size: 24,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _steps.length,
            itemBuilder: (context, index) {
              return _buildStepPage(_steps[index]);
            },
          ),
        ),
        _buildPageIndicator(),
        _buildNavigationButtons(),
      ],
    );
  }
  
  Widget _buildStepPage(HowItWorksStep step) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  step.color.withOpacity(0.2),
                  step.color.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: step.color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              step.icon,
              size: 48,
              color: step.color,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            step.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.branding.primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            step.description,
            style: TextStyle(
              fontSize: 16,
              color: widget.branding.secondaryTextColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (step.benefits.isNotEmpty) _buildBenefits(step.benefits),
        ],
      ),
    );
  }
  
  Widget _buildBenefits(List<String> benefits) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.branding.cardBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
        border: Border.all(
          color: widget.branding.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: benefits.map((benefit) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: widget.branding.accentGlowColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    benefit,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.branding.secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_steps.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == _currentPage ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == _currentPage 
                  ? widget.branding.primaryButtonColor
                  : widget.branding.mutedTextColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentPage > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: widget.branding.primaryButtonColor,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
                  ),
                ),
                child: Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.branding.primaryButtonColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: _currentPage == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _currentPage == _steps.length - 1 ? widget.onClose : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.branding.primaryButtonColor,
                foregroundColor: widget.branding.primaryButtonTextColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
                ),
                elevation: 0,
              ),
              child: Text(
                _currentPage == _steps.length - 1 ? 'Get Started' : 'Next',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // MARK: - Navigation
  
  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  // MARK: - Data Initialization
  
  void _initializeSteps() {
    _steps.addAll([
      HowItWorksStep(
        title: 'Daily Entries',
        description: 'Claim free entries every day to enter the sweepstakes. The more consistent you are, the more entries you earn!',
        icon: Icons.calendar_today,
        color: widget.branding.primaryButtonColor,
        benefits: [
          'Free daily entries',
          'No purchase necessary',
          'Build your streak for bonuses',
        ],
      ),
      HowItWorksStep(
        title: 'Build Your Streak',
        description: 'Come back every day to build your streak. Longer streaks unlock bonus multipliers and extra entries.',
        icon: Icons.local_fire_department,
        color: widget.branding.accentGlowColor,
        benefits: [
          'Week 1: 1.5x multiplier',
          'Week 2: 2x multiplier',
          'Week 3: 2.5x multiplier',
          'Month+: 3x multiplier',
        ],
      ),
      HowItWorksStep(
        title: 'Bonus Entries',
        description: 'Watch optional video ads to earn bonus entries. More entries means better chances to win!',
        icon: Icons.play_circle_filled,
        color: widget.branding.primaryColor,
        benefits: [
          '+10 bonus entries per video',
          'Watch multiple times per day',
          'Safe and secure ads',
        ],
      ),
      HowItWorksStep(
        title: 'Win Prizes',
        description: widget.campaignTitle != null 
            ? 'You\'re entered to win ${_formatPrize(widget.prizeValue ?? 0)} in ${widget.campaignTitle}!'
            : 'You\'re automatically entered to win amazing prizes. Winners are selected randomly.',
        icon: Icons.emoji_events,
        color: widget.branding.accentGlowColor,
        benefits: [
          'Random selection process',
          'More entries = better odds',
          'Winners notified directly',
          '100% legitimate sweepstakes',
        ],
      ),
    ]);
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

/// Data model for a single step in the how it works flow
class HowItWorksStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> benefits;
  
  const HowItWorksStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.benefits = const [],
  });
}