import 'package:flutter/material.dart';

import '../rewards/rewarded_video_provider.dart';
import '../winr_branding.dart';

/// Bonus entries view for rewarded video ads.
///
/// Provides an interface for users to watch rewarded videos to earn bonus
/// entries. Handles ad loading, playback, and completion tracking.
class BonusEntriesView extends StatefulWidget {
  /// The branding configuration for styling
  final WINRBranding branding;

  /// The rewarded video provider
  final RewardedVideoProvider rewardedVideoProvider;

  /// Callback when video is completed and bonus entries are awarded
  final VoidCallback onComplete;

  /// Optional callback when the view is dismissed
  final VoidCallback? onDismiss;

  const BonusEntriesView({
    super.key,
    required this.branding,
    required this.rewardedVideoProvider,
    required this.onComplete,
    this.onDismiss,
  });

  @override
  State<BonusEntriesView> createState() => _BonusEntriesViewState();
}

class _BonusEntriesViewState extends State<BonusEntriesView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _isAdReady = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _slideController.forward();
    _pulseController.repeat(reverse: true);

    // Check if ad is ready
    _checkAdAvailability();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.branding.backgroundColor.withValues(alpha: 0.95),
              widget.branding.cardBackgroundColor.withValues(alpha: 0.98),
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                const SizedBox(height: 24),
                _buildHeader(),
                const SizedBox(height: 32),
                if (_hasError) _buildErrorState() else _buildContent(),
                const SizedBox(height: 24),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: widget.branding.mutedTextColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.branding.primaryButtonColor,
                widget.branding.accentGlowColor,
              ],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: widget.branding.accentGlowColor.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Icon(
                  Icons.play_circle_fill,
                  size: 40,
                  color: widget.branding.primaryButtonTextColor,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Bonus Entries',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: widget.branding.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Watch a short video to earn extra entries',
          style: TextStyle(
            fontSize: 16,
            color: widget.branding.secondaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.branding.cardBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
        border: Border.all(
          color: widget.branding.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam,
                color: widget.branding.accentGlowColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Video Reward',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: widget.branding.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBenefitsList(),
          const SizedBox(height: 20),
          if (_isLoading) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      {'icon': Icons.add_circle, 'text': '+10 Bonus Entries'},
      {'icon': Icons.timer, 'text': '30 seconds or less'},
      {'icon': Icons.security, 'text': 'Safe & secure ads'},
    ];

    return Column(
      children: benefits.map((benefit) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                benefit['icon'] as IconData,
                color: widget.branding.accentGlowColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                benefit['text'] as String,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.branding.secondaryTextColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.branding.primaryButtonColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Loading ad...',
          style: TextStyle(
            fontSize: 14,
            color: widget.branding.mutedTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(widget.branding.cornerRadius),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Ad Not Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ??
                'No rewarded videos are available at the moment. Please try again later.',
            style: TextStyle(
              fontSize: 14,
              color: widget.branding.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        if (!_hasError) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isAdReady && !_isLoading) ? _watchVideo : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.branding.primaryButtonColor,
                foregroundColor: widget.branding.primaryButtonTextColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(widget.branding.cornerRadius),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    _isLoading ? 'Loading...' : 'Watch Video',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _close,
            child: Text(
              _hasError ? 'Close' : 'Maybe Later',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: widget.branding.mutedTextColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Ad Management

  Future<void> _checkAdAvailability() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final isReady = await widget.rewardedVideoProvider.isAdAvailable();
      setState(() {
        _isAdReady = isReady;
        _isLoading = false;
        _hasError = !isReady;
        if (!isReady) {
          _errorMessage =
              'No ads are available right now. Please try again later.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to check ad availability. Please try again.';
      });
    }
  }

  Future<void> _watchVideo() async {
    if (!_isAdReady || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await widget.rewardedVideoProvider.showAd();

      if (success) {
        // Video completed successfully
        widget.onComplete();
        _close();
      } else {
        // Video was not completed
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Video was not completed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to show video. Please try again.';
      });
    }
  }

  void _close() {
    widget.onDismiss?.call();
    Navigator.of(context).pop();
  }
}
