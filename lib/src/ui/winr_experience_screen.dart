import 'package:flutter/material.dart';
import '../winr_configuration.dart';
import '../winr_user.dart';
import '../domain/campaign.dart';
import '../domain/streak_state.dart';
import '../domain/streak_engine.dart';
import '../network/network_client.dart';
import '../network/winr_api.dart';
import '../storage/secure_storage.dart';
import '../storage/preferences_storage.dart';
import '../rewards/rewarded_video_provider.dart';
import '../services/logger.dart';
import '../services/analytics/analytics_adapter.dart';
import 'winr_theme.dart';
import 'winr_experience_header.dart';
import 'streak_dashboard_view.dart';
import 'email_capture_view.dart';

/// Main experience screen for the WINR SDK.
/// 
/// This is the primary UI that users interact with to claim their daily entries,
/// view their streak progress, and engage with the sweepstakes experience.
class WINRExperienceScreen extends StatefulWidget {
  final WINRConfiguration configuration;
  final WINRUser user;
  final NetworkClient networkClient;
  final SecureStorage secureStorage;
  final PreferencesStorage preferencesStorage;
  final StreakEngine streakEngine;
  final RewardedVideoProvider? rewardedVideoProvider;
  final Campaign? cachedCampaign;
  final StreakState? cachedStreakState;
  final bool? cachedClaimedToday;
  
  const WINRExperienceScreen({
    super.key,
    required this.configuration,
    required this.user,
    required this.networkClient,
    required this.secureStorage,
    required this.preferencesStorage,
    required this.streakEngine,
    this.rewardedVideoProvider,
    this.cachedCampaign,
    this.cachedStreakState,
    this.cachedClaimedToday,
  });
  
  @override
  State<WINRExperienceScreen> createState() => _WINRExperienceScreenState();
}

class _WINRExperienceScreenState extends State<WINRExperienceScreen> 
    with TickerProviderStateMixin {
  
  // State
  Campaign? _campaign;
  StreakState? _streakState;
  bool _claimedToday = false;
  bool _isLoading = false;
  String? _error;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Page controller for different views
  late PageController _pageController;
  // ignore: unused_field
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    // Initialize page controller
    _pageController = PageController();
    
    // Initialize state
    _campaign = widget.cachedCampaign;
    _streakState = widget.cachedStreakState;
    _claimedToday = widget.cachedClaimedToday ?? false;
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    
    // Load data
    _loadExperienceData();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = WINRTheme.create(widget.configuration.branding);
    
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: widget.configuration.branding.backgroundColor,
        body: Container(
          decoration: WINRTheme.createGradientBackground(widget.configuration.branding),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildContent(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_error != null) {
      return _buildErrorState();
    }
    
    return PageView(
      controller: _pageController,
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
        });
      },
      children: [
        _buildMainExperience(),
        if (widget.user.email == null) _buildEmailCapture(),
      ],
    );
  }
  
  Widget _buildMainExperience() {
    return Column(
      children: [
        // Header with branding and close button
        WINRExperienceHeader(
          branding: widget.configuration.branding,
          title: _campaign?.title ?? 'Daily Entries',
          onClose: () => Navigator.of(context).pop(),
        ),
        
        // Main content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Streak dashboard
                if (_campaign != null && _streakState != null)
                  StreakDashboardView(
                    campaign: _campaign!,
                    streakState: _streakState!,
                    claimedToday: _claimedToday,
                    onClaimDaily: _handleDailyClaim,
                    onClaimBonus: _handleBonusClaim,
                    rewardedVideoProvider: widget.rewardedVideoProvider,
                  ),
                
                const SizedBox(height: 32),
                
                // Action buttons
                if (!_claimedToday) _buildClaimButton(),
                if (_claimedToday) _buildClaimedState(),
                
                const SizedBox(height: 16),
                
                // Secondary actions
                _buildSecondaryActions(),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildClaimButton() {
    final entries = _calculateDailyEntries();
    
    return Container(
      width: double.infinity,
      decoration: WINRTheme.createCardDecoration(
        widget.configuration.branding,
        withGlow: true,
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleDailyClaim,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.configuration.branding.cornerRadius),
          ),
        ),
        child: Column(
          children: [
            Text(
              'Claim $entries Entries',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Day ${_streakState?.currentDay ?? 1} of your streak',
              style: TextStyle(
                fontSize: 14,
                color: widget.configuration.branding.primaryButtonTextColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildClaimedState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: WINRTheme.createCardDecoration(widget.configuration.branding),
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            color: widget.configuration.branding.accentGlowColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Entries Claimed!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: widget.configuration.branding.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Come back tomorrow to continue your streak',
            style: TextStyle(
              fontSize: 14,
              color: widget.configuration.branding.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSecondaryActions() {
    return Column(
      children: [
        // Rewarded video button
        if (widget.rewardedVideoProvider != null && _claimedToday)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleBonusClaim,
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('Watch Video for Bonus Entries'),
              ),
            ),
          ),
        
        // Email capture prompt
        if (widget.user.email == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                icon: const Icon(Icons.email),
                label: const Text('Enter Email for More Chances'),
              ),
            ),
          ),
        
        // Close button
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
  
  Widget _buildEmailCapture() {
    return EmailCaptureView(
      branding: widget.configuration.branding,
      onEmailSubmitted: (email, age) async {
        try {
          await widget.networkClient.send(SubmitEmailRequest(
            email: email,
            age: age,
          ));
          
          // Update user and go back to main experience
          widget.configuration.options.analyticsAdapter?.track(
            WINRAnalyticsEvents.emailCaptureCompleted,
            {'email_domain': email.split('@').last},
          );
          
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } catch (e) {
          widget.configuration.options.analyticsAdapter?.track(
            WINRAnalyticsEvents.emailCaptureFailed,
            {'error': e.toString()},
          );
          _showError('Failed to submit email. Please try again.');
        }
      },
      onSkip: () {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: widget.configuration.branding.primaryButtonColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your streak...',
            style: TextStyle(
              color: widget.configuration.branding.secondaryTextColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: widget.configuration.branding.primaryColor,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                color: widget.configuration.branding.primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Please try again',
              style: TextStyle(
                color: widget.configuration.branding.secondaryTextColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _loadExperienceData(),
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
  
  // MARK: - Data Loading
  
  Future<void> _loadExperienceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Load cached data first
      await _loadCachedData();
      
      // Refresh from network
      await _refreshFromNetwork();
    } catch (e) {
      Logger.instance.error('Failed to load experience data', e);
      setState(() {
        _error = 'Unable to load data. Please check your connection.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadCachedData() async {
    // Load cached streak state
    final cachedStreak = await widget.preferencesStorage.getStreakState();
    if (cachedStreak != null) {
      setState(() {
        _streakState = cachedStreak;
      });
    }
    
    // Load cached campaign
    final cachedCampaign = await widget.preferencesStorage.getCachedCampaign();
    if (cachedCampaign != null) {
      setState(() {
        _campaign = cachedCampaign;
      });
    }
  }
  
  Future<void> _refreshFromNetwork() async {
    try {
      final response = await widget.networkClient.send(GetActiveCampaignRequest());
      
      setState(() {
        _campaign = response.campaign;
        _claimedToday = response.claimedToday;
      });
      
      // Cache the data
      if (response.campaign != null) {
        await widget.preferencesStorage.cacheCampaign(response.campaign!);
      }
    } catch (e) {
      // Use cached data and log error
      Logger.instance.error('Failed to refresh campaign data', e);
    }
  }
  
  // MARK: - Actions
  
  Future<void> _handleDailyClaim() async {
    if (_isLoading || _claimedToday) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Calculate new streak state
      final currentState = _streakState;
      final now = DateTime.now();
      
      final result = widget.streakEngine.nextState(currentState, now);
      if (result.isError) {
        throw Exception(result.error.message);
      }
      
      // Claim entries from backend
      final response = await widget.networkClient.send(ClaimDailyEntriesRequest());
      
      // Update local state
      final newStreakState = result.value.copyWith(
        totalEntriesEarned: (currentState?.totalEntriesEarned ?? 0) + response.baseEntries + response.bonusEntries,
      );
      
      setState(() {
        _streakState = newStreakState;
        _claimedToday = true;
      });
      
      // Save state
      await widget.preferencesStorage.saveStreakState(newStreakState);
      await widget.preferencesStorage.saveLastClaimedDate(now);
      
      // Track analytics
      widget.configuration.options.analyticsAdapter?.track(
        WINRAnalyticsEvents.dailyEntriesClaimed,
        {
          'streak_day': newStreakState.currentDay,
          'base_entries': response.baseEntries,
          'bonus_entries': response.bonusEntries,
          'total_entries': response.baseEntries + response.bonusEntries,
          'weekly_bonus_earned': response.weeklyBonusEarned,
          'monthly_bonus_earned': response.monthlyBonusEarned,
        },
      );
      
      // Return result to caller
      Navigator.of(context).pop(response.toEntryGrant());
    } catch (e) {
      Logger.instance.error('Daily claim failed', e);
      widget.configuration.options.analyticsAdapter?.track(
        WINRAnalyticsEvents.claimFailed,
        {'error': e.toString()},
      );
      _showError('Failed to claim entries. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _handleBonusClaim() async {
    final provider = widget.rewardedVideoProvider;
    if (provider == null) return;
    
    try {
      widget.configuration.options.analyticsAdapter?.track(
        WINRAnalyticsEvents.rewardedVideoStarted,
      );
      
      final completed = await provider.showAd();
      if (completed) {
        // Claim bonus entries from backend
        final response = await widget.networkClient.send(ClaimBonusEntriesRequest());
        
        widget.configuration.options.analyticsAdapter?.track(
          WINRAnalyticsEvents.rewardedVideoCompleted,
          {'bonus_entries': response.bonusEntries},
        );
        
        _showSuccess('You earned ${response.bonusEntries} bonus entries!');
      }
    } catch (e) {
      Logger.instance.error('Bonus claim failed', e);
      widget.configuration.options.analyticsAdapter?.track(
        WINRAnalyticsEvents.rewardedVideoFailed,
        {'error': e.toString()},
      );
      _showError('Failed to claim bonus entries. Please try again.');
    }
  }
  
  // MARK: - Helpers
  
  int _calculateDailyEntries() {
    if (_campaign == null || _streakState == null) return 10;
    return widget.streakEngine.baseEntries(_streakState!.currentDay);
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}