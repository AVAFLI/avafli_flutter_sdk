import 'package:flutter/material.dart';

import '../domain/giveaway.dart';
import '../domain/daily_entry_grant.dart';
import '../domain/sdk_copy.dart';
import '../domain/sdk_media.dart';
import '../domain/streak_engine.dart';
import '../domain/streak_state.dart';
import '../network/network_client.dart';
import '../network/winr_api.dart';
import '../rewards/rewarded_video_provider.dart';
import '../services/logger.dart';
import '../storage/preferences_storage.dart';
import '../storage/secure_storage.dart';
import '../storage/storage.dart';
import '../winr_branding.dart';
import '../winr_configuration.dart';
import '../winr_user.dart';
import 'bonus_entries_view.dart';
import 'email_capture_view.dart';
import 'how_it_works_view.dart';
import 'streak_dashboard_view.dart';
import 'winr_experience_header.dart';

/// Experience state — mirrors iOS WINRExperienceViewModel.State.
enum _ExperiencePhase {
  loading,
  noActiveGiveaway,
  emailCapture,
  streak,
  bonus,
  completed,
  howItWorks,
  error,
}

/// Main experience screen — matches iOS WINRExperienceView.swift.
///
/// ZStack: background gradient + radial glow → content (padded top 50) → header overlay.
/// State machine: loading → emailCapture → streak → bonus → completed.
class WINRExperienceScreen extends StatefulWidget {
  final WINRConfiguration configuration;
  final WINRUser user;
  final NetworkClient networkClient;
  final SecureStorage secureStorage;
  final PreferencesStorage preferencesStorage;
  final StreakEngine streakEngine;
  final RewardedVideoProvider? rewardedVideoProvider;
  final Giveaway? cachedGiveaway;
  final StreakState? cachedStreakState;
  final bool? cachedClaimedToday;
  final Map<String, dynamic>? sdkConfig;
  final SdkCopy? sdkCopy;
  final SdkMedia? sdkMedia;

  const WINRExperienceScreen({
    super.key,
    required this.configuration,
    required this.user,
    required this.networkClient,
    required this.secureStorage,
    required this.preferencesStorage,
    required this.streakEngine,
    this.rewardedVideoProvider,
    this.cachedGiveaway,
    this.cachedStreakState,
    this.cachedClaimedToday,
    this.sdkConfig,
    this.sdkCopy,
    this.sdkMedia,
  });

  @override
  State<WINRExperienceScreen> createState() => _WINRExperienceScreenState();
}

class _WINRExperienceScreenState extends State<WINRExperienceScreen> {
  // State machine
  _ExperiencePhase _phase = _ExperiencePhase.loading;
  _ExperiencePhase? _lastPrimaryPhase;

  // Data
  Giveaway? _giveaway;
  StreakState? _streakState;
  int _entriesToday = 0;
  List<int> _ladder = [];
  bool _claimedToday = false;
  DailyEntryGrant? _lastGrant;
  String? _errorMessage;

  // Backend cache
  bool? _backendClaimedToday;
  int? _backendStreakDay;

  /// Branding with server-driven overrides merged in.
  late final WINRBranding _branding = widget.configuration.branding
      .applyingServerBranding(_serverBranding);

  /// Server branding map from sdkConfig (nullable).
  Map<String, dynamic>? get _serverBranding {
    final branding = widget.sdkConfig?['branding'];
    return branding is Map<String, dynamic> ? branding : null;
  }



  @override
  void initState() {
    super.initState();
    _giveaway = widget.cachedGiveaway;
    _streakState = widget.cachedStreakState;
    _claimedToday = widget.cachedClaimedToday ?? false;
    _loadExperience();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background layer
          _buildBackground(),

          // Main content (padded top 50 for header clearance)
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: _buildContent(),
          ),

          // Header overlay
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: SafeArea(
              bottom: false,
              child: WINRExperienceHeader(
                branding: _branding,
                showsBack: _phase == _ExperiencePhase.howItWorks,
                showsInfo: (_phase == _ExperiencePhase.streak ||
                        _phase == _ExperiencePhase.emailCapture) &&
                    _phase != _ExperiencePhase.howItWorks,
                onBack: _hideHowItWorks,
                onInfo: _showHowItWorks,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        // Linear gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _branding.backgroundColor,
                _branding.backgroundColor.withValues(alpha: 0.94),
              ],
            ),
          ),
        ),
        // Radial accent glow
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.0,
                colors: [
                  _branding.accentGlowColor.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_phase) {
      case _ExperiencePhase.loading:
        return _buildLoading();

      case _ExperiencePhase.noActiveGiveaway:
        return _buildNoActiveGiveaway();

      case _ExperiencePhase.emailCapture:
        return EmailCaptureView(
          branding: _branding,
          rulesUrl: null, // giveaway rulesUrl if available
          prefillEmail: null,
          prizeValue: _giveaway?.prizeValue,
          sdkCopy: widget.sdkCopy,
          sdkMedia: widget.sdkMedia,
          onSubmit: _submitEmail,
          onSkip: _skipEmailCapture,
        );

      case _ExperiencePhase.streak:
        return StreakDashboardView(
          branding: _branding,
          streakState: _streakState!,
          entriesToday: _entriesToday,
          ladder: _ladder,
          claimedToday: _claimedToday,
          giveaway: _giveaway,
          sdkCopy: widget.sdkCopy,
          sdkMedia: widget.sdkMedia,
          onClaim: _claimDailyEntries,
          onClose: () => Navigator.of(context).pop(),
        );

      case _ExperiencePhase.bonus:
        return BonusEntriesView(
          branding: _branding,
          entries: _lastGrant?.baseEntries ?? _entriesToday,
          sdkCopy: widget.sdkCopy,
          sdkMedia: widget.sdkMedia,
          onClaim: _claimBonus,
          onSkip: _skipBonus,
        );

      case _ExperiencePhase.howItWorks:
        return HowItWorksView(
          branding: _branding,
          sdkCopy: widget.sdkCopy,
          sdkMedia: widget.sdkMedia,
          onPrimary: _hideHowItWorks,
        );

      case _ExperiencePhase.completed:
        return _buildCompleted();

      case _ExperiencePhase.error:
        return _buildError();
    }
  }

  // ---------------------------------------------------------------------------
  // STATIC SCREENS
  // ---------------------------------------------------------------------------

  Widget _buildLoading() {
    final loadingText = widget.sdkCopy?.loading?.text ?? 
        'Loading today\'s reward…';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _branding.accentGlowColor),
          const SizedBox(height: 16),
          Text(
            loadingText,
            style: TextStyle(color: _branding.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleted() {
    final grant = _lastGrant;
    final title = widget.sdkCopy?.completed?.title ?? 'Entries Claimed!';
    final subtitle = widget.sdkCopy?.completed?.subtitle ?? 
        '+${grant?.total ?? _entriesToday} entries added to this month\'s drawing.';
    final buttonText = widget.sdkCopy?.completed?.closeButton ?? 'Close';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _branding.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle.replaceAll('{total}', '${grant?.total ?? _entriesToday}'),
              style: TextStyle(color: _branding.mutedTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _branding.primaryButtonColor,
                  borderRadius:
                      BorderRadius.circular(_branding.cornerRadius),
                ),
                child: Center(
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _branding.primaryButtonTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveGiveaway() {
    final title = widget.sdkCopy?.noActiveGiveaway?.title ?? 'No Active Giveaway';
    final subtitle = widget.sdkCopy?.noActiveGiveaway?.subtitle ?? 
        'Check back soon for your next chance to win!';
    final buttonText = widget.sdkCopy?.noActiveGiveaway?.closeButton ?? 'Close';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo placeholder — branding logo handled by sdkMedia if configured
            const SizedBox(height: 20),
            
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _branding.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: _branding.mutedTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _branding.primaryButtonColor,
                  borderRadius:
                      BorderRadius.circular(_branding.cornerRadius),
                ),
                child: Center(
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _branding.primaryButtonTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final title = widget.sdkCopy?.error?.title ?? 'Something went wrong.';
    final subtitle = widget.sdkCopy?.error?.subtitle ?? 
        _errorMessage ?? 'Please try again later.';
    final buttonText = widget.sdkCopy?.error?.closeButton ?? 'Close';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _branding.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(color: _branding.mutedTextColor),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _branding.primaryButtonColor,
                  borderRadius:
                      BorderRadius.circular(_branding.cornerRadius),
                ),
                child: Center(
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _branding.primaryButtonTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATE MACHINE ACTIONS
  // ---------------------------------------------------------------------------

  void _showHowItWorks() {
    setState(() {
      _lastPrimaryPhase = _phase;
      _phase = _ExperiencePhase.howItWorks;
    });
  }

  void _hideHowItWorks() {
    setState(() {
      _phase = _lastPrimaryPhase ?? _ExperiencePhase.loading;
      _lastPrimaryPhase = null;
      if (_phase == _ExperiencePhase.loading) {
        _loadExperience();
      }
    });
  }

  void _skipEmailCapture() {
    // Email is mandatory — stay on email capture
    setState(() => _phase = _ExperiencePhase.emailCapture);
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------

  Future<void> _loadExperience() async {
    setState(() => _phase = _ExperiencePhase.loading);
    try {
      // Fetch giveaway from backend
      bool? backendClaimed = widget.cachedClaimedToday;
      int? backendStreakDay;

      try {
        final response =
            await widget.networkClient.send(GetActiveGiveawayRequest());
        
        // Handle null giveaway response (no active giveaway)
        if (response.giveaway == null) {
          _giveaway = null;
          // Clear cached giveaway from storage
          await widget.preferencesStorage.remove(StorageKeys.cachedGiveaway);
          setState(() => _phase = _ExperiencePhase.noActiveGiveaway);
          return;
        }
        
        _giveaway = response.giveaway;
        backendClaimed = response.claimedToday;
        backendStreakDay = response.streakDay;
        await widget.preferencesStorage.cacheGiveaway(response.giveaway!);
      } catch (e) {
        // Offline fallback
        _giveaway ??= await widget.preferencesStorage.getCachedGiveaway();
        Logger.instance.error('Using cached giveaway (offline)', e);
      }
      
      // If we still don't have a giveaway after trying cache, show no active giveaway
      if (_giveaway == null) {
        setState(() => _phase = _ExperiencePhase.noActiveGiveaway);
        return;
      }

      _backendClaimedToday = backendClaimed;
      _backendStreakDay = backendStreakDay;

      // Check stored email
      final storedEmail = await widget.secureStorage.getString('email');

      if (storedEmail == null) {
        setState(() => _phase = _ExperiencePhase.emailCapture);
        return;
      }

      _computeStreakAndShow(
        backendClaimedToday: backendClaimed,
        backendStreakDay: backendStreakDay,
      );
    } catch (e) {
      Logger.instance.error('Failed to load experience', e);
      setState(() {
        _errorMessage = e.toString();
        _phase = _ExperiencePhase.error;
      });
    }
  }

  void _computeStreakAndShow({
    bool? backendClaimedToday,
    int? backendStreakDay,
  }) {
    // Build ladder from engine defaults
    _ladder = List.generate(
      6,
      (i) => widget.streakEngine.baseEntries(i + 1),
    );

    if (backendClaimedToday != null) {
      final day = backendStreakDay ?? _streakState?.currentDay ?? 1;
      final dayIndex = (day - 1).clamp(0, _ladder.length - 1);
      _entriesToday = _ladder[dayIndex];
      _streakState = _streakState ??
          StreakState(
            currentDay: day,
            lastClaimedDate: backendClaimedToday ? DateTime.now() : null,
            weeklyCurrent: 1,
            monthlyCurrent: 1,
          );
      _claimedToday = backendClaimedToday;
    } else {
      // Offline fallback
      final result =
          widget.streakEngine.nextState(_streakState, DateTime.now());
      if (result.isError) {
        // ineligibleToday → already claimed
        _claimedToday = true;
        final day = _streakState?.currentDay ?? 1;
        final dayIndex = (day - 1).clamp(0, _ladder.length - 1);
        _entriesToday = _ladder[dayIndex];
      } else {
        _streakState = result.value;
        _claimedToday = false;
        final dayIndex =
            (result.value.currentDay - 1).clamp(0, _ladder.length - 1);
        _entriesToday = _ladder[dayIndex];
      }
    }

    setState(() => _phase = _ExperiencePhase.streak);
  }

  // ---------------------------------------------------------------------------
  // EMAIL
  // ---------------------------------------------------------------------------

  Future<void> _submitEmail(String email, bool marketingConsent) async {
    if (email.isEmpty) return;

    await widget.secureStorage.setString('email', email);

    // Fire-and-forget backend submission
    widget.networkClient
        .send(SubmitEmailRequest(
          email: email,
          hasConsent: marketingConsent,
          publisherUserId: widget.user.id,
        ))
        .then((_) {})
        .catchError((Object e) {
      Logger.instance.error('Email backend submit failed', e);
    });

    _computeStreakAndShow(
      backendClaimedToday: _backendClaimedToday,
      backendStreakDay: _backendStreakDay,
    );
  }

  // ---------------------------------------------------------------------------
  // DAILY CLAIM
  // ---------------------------------------------------------------------------

  Future<void> _claimDailyEntries() async {
    if (_claimedToday) return;

    try {
      final response =
          await widget.networkClient.send(ClaimDailyEntriesRequest());

      final grant = DailyEntryGrant(
        baseEntries: response.baseEntries + response.bonusEntries,
      );

      // Update local state
      _streakState = _streakState?.copyWith(
        currentDay: response.newStreakDay,
        lastClaimedDate: DateTime.now(),
      );
      _claimedToday = true;
      _lastGrant = grant;

      await widget.preferencesStorage
          .saveStreakState(_streakState!);

      // Decide next phase — feature flag gates the bonus flow
      final bonusEnabled = widget.sdkConfig?['bonusEntriesEnabled'] == true;
      if (bonusEnabled &&
          widget.rewardedVideoProvider != null &&
          (_giveaway?.doublingEnabled ?? false)) {
        setState(() => _phase = _ExperiencePhase.bonus);
      } else {
        _complete(grant);
      }

      widget.configuration.options.analyticsAdapter?.track(
        'winr_daily_entry_claimed',
        {
          'day': response.newStreakDay,
          'entries': response.baseEntries,
        },
      );
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Already claimed')) {
        _claimedToday = true;
        final grant = DailyEntryGrant(baseEntries: _entriesToday);
        _lastGrant = grant;
        _complete(grant);
        return;
      }

      // Offline fallback
      Logger.instance.error('Backend claim failed, using local', e);
      _streakState = _streakState?.copyWith(lastClaimedDate: DateTime.now());
      _claimedToday = true;
      final grant = DailyEntryGrant(baseEntries: _entriesToday);
      _lastGrant = grant;

      final bonusFallbackEnabled = widget.sdkConfig?['bonusEntriesEnabled'] == true;
      if (bonusFallbackEnabled && widget.rewardedVideoProvider != null) {
        setState(() => _phase = _ExperiencePhase.bonus);
      } else {
        _complete(grant);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BONUS
  // ---------------------------------------------------------------------------

  Future<void> _claimBonus() async {
    final grant = _lastGrant ?? DailyEntryGrant(baseEntries: _entriesToday);

    final provider = widget.rewardedVideoProvider;
    if (provider == null) {
      _complete(grant);
      return;
    }

    try {
      final shown = await provider.showAd();
      if (shown) {
        try {
          final response =
              await widget.networkClient.send(ClaimBonusEntriesRequest());
          final finalGrant = DailyEntryGrant(
            baseEntries: grant.baseEntries,
            bonusEntries: response.bonusEntries,
          );
          _complete(finalGrant);
        } catch (e) {
          // Offline fallback: assume doubling
          final finalGrant = DailyEntryGrant(
            baseEntries: grant.baseEntries,
            bonusEntries: grant.baseEntries,
          );
          _complete(finalGrant);
        }
      } else {
        _complete(grant);
      }
    } catch (e) {
      Logger.instance.error('Rewarded video failed', e);
      _complete(grant);
    }
  }

  void _skipBonus() {
    final grant = _lastGrant ?? DailyEntryGrant(baseEntries: _entriesToday);
    _complete(grant);
  }

  // ---------------------------------------------------------------------------
  // COMPLETION
  // ---------------------------------------------------------------------------

  void _complete(DailyEntryGrant grant) {
    setState(() {
      _lastGrant = grant;
      _phase = _ExperiencePhase.completed;
    });
    widget.configuration.options.analyticsAdapter?.track(
      'winr_experience_closed',
      {'total_entries': grant.total},
    );
  }
}
