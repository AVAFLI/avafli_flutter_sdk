import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../domain/daily_entry_grant.dart';
import '../domain/giveaway.dart';
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
import '../winr.dart';
import '../winr_error.dart';
import '../winr_user.dart';
import 'bonus_entries_view.dart';
import 'email_capture_view.dart';
import 'how_it_works_view.dart';
import 'skeleton_views.dart';
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
  final int cachedTotalEntries;
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
    this.cachedTotalEntries = 0,
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
  int _backendTotalEntries = 0;

  // Loading states
  bool _isClaiming = false;
  final bool _isSubmittingEmail = false;

  /// Branding with server-driven overrides merged in.
  late final WINRBranding _branding =
      widget.configuration.branding.applyingServerBranding(_serverBranding);

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
          isSubmitting: _isSubmittingEmail,
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
          isClaiming: _isClaiming,
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
    return StreakDashboardSkeleton(branding: _branding);
  }

  Widget _buildCompleted() {
    final grant = _lastGrant;
    final entries = grant?.baseEntries ?? _entriesToday;
    final bonus = grant?.bonusEntries ?? 0;

    // Resolve prize headline: copy.completed.title → copy.streakDashboard.prizeHeadline → giveaway prize
    final prizeHeadline = widget.sdkCopy?.completed?.title ??
        widget.sdkCopy?.streakDashboard?.prizeHeadline ??
        (_giveaway?.prizeValue != null
            ? 'WIN ${StreakDashboardView.formatPrize(_giveaway!.prizeValue!)}!'
            : 'WIN PRIZES!');

    final subtitle = widget.sdkCopy?.completed?.subtitle ?? 'Entries Claimed!';
    final buttonText = widget.sdkCopy?.completed?.closeButton ?? 'Continue';

    return _CompletedCelebrationView(
      branding: _branding,
      entries: entries,
      bonusEntries: bonus,
      prizeHeadline: prizeHeadline,
      subtitle: subtitle.replaceAll('{entries}', '$entries'),
      buttonText: buttonText,
      sdkMedia: widget.sdkMedia,
      onContinue: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildNoActiveGiveaway() {
    final title =
        widget.sdkCopy?.noActiveGiveaway?.title ?? 'No Active Giveaway';
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
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _branding.primaryButtonColor,
                  borderRadius: BorderRadius.circular(_branding.cornerRadius),
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
        _errorMessage ??
        'Please try again later.';
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
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _branding.primaryButtonColor,
                  borderRadius: BorderRadius.circular(_branding.cornerRadius),
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
        _backendTotalEntries = response.totalEntries;
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

      // If backend says not claimed, check local persistence + in-memory cache
      // as belt-and-suspenders. The in-memory cache (`widget.cachedClaimedToday`)
      // is the most reliable source during a single app session — it's set
      // immediately on claim and survives SDK re-presentations. Without this
      // check, a backend timezone mismatch or propagation delay can reset the
      // UI to the unclaimed state after the user already claimed.
      if (backendClaimed != true) {
        final localClaimed = await WINR.checkLocalClaimedToday(widget.preferencesStorage);
        if (localClaimed || widget.cachedClaimedToday == true) {
          backendClaimed = true;
        }
      }

      _backendClaimedToday = backendClaimed;
      _backendStreakDay = backendStreakDay;

      // Use the stored user_uid (from the registration handshake) as the
      // "already registered" sentinel. We do NOT persist the raw email locally
      // (PII-High): once registration completes the backend keys everything off
      // user_uid, so the presence of a uuid means email capture is done.
      final storedUuid = await widget.secureStorage.getUserUuid();

      if (storedUuid == null) {
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
      7,
      (i) => widget.streakEngine.baseEntries(i + 1),
    );

    if (backendClaimedToday != null) {
      final day = backendStreakDay ?? _streakState?.currentDay ?? 1;
      final dayIndex = (day - 1).clamp(0, _ladder.length - 1);
      _entriesToday = _ladder[dayIndex];
      final totalEntries = _backendTotalEntries > 0
          ? _backendTotalEntries
          : widget.cachedTotalEntries;
      _streakState = _streakState ??
          StreakState(
            currentDay: day,
            lastClaimedDate: backendClaimedToday ? DateTime.now() : null,
            weeklyCurrent: 1,
            monthlyCurrent: 1,
            totalEntriesEarned: totalEntries,
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

    // Do NOT persist the raw email locally (PII-High). The backend returns a
    // user_uid on the handshake which we use as the registered sentinel.

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
    if (_claimedToday || _isClaiming) return;

    setState(() => _isClaiming = true);
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

      // Sync static cache + persist to local storage (Option C)
      WINR.syncClaimedToday(true);
      await WINR.persistClaimedToday(widget.preferencesStorage);

      await widget.preferencesStorage.saveStreakState(_streakState!);

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
        WINR.syncClaimedToday(true);
        unawaited(WINR.persistClaimedToday(widget.preferencesStorage));
        final grant = DailyEntryGrant(baseEntries: _entriesToday);
        _lastGrant = grant;
        _complete(grant);
        return;
      }

      // Only allow offline fallback for network errors — not auth or server errors.
      // Faking a successful claim when the backend rejected it causes duplicate
      // claim attempts and inconsistent state.
      if (e is WINRException && e.error == WINRError.networkError) {
        Logger.instance
            .error('Network error during claim, using local fallback', e);
        _streakState = _streakState?.copyWith(lastClaimedDate: DateTime.now());
        _claimedToday = true;
        WINR.syncClaimedToday(true);
        unawaited(WINR.persistClaimedToday(widget.preferencesStorage));
        final grant = DailyEntryGrant(baseEntries: _entriesToday);
        _lastGrant = grant;

        final bonusFallbackEnabled =
            widget.sdkConfig?['bonusEntriesEnabled'] == true;
        if (bonusFallbackEnabled && widget.rewardedVideoProvider != null) {
          setState(() => _phase = _ExperiencePhase.bonus);
        } else {
          _complete(grant);
        }
        return;
      }

      // For all other errors, show error state
      Logger.instance.error('Backend claim failed', e);
      setState(() {
        _isClaiming = false;
        _errorMessage = e.toString();
        _phase = _ExperiencePhase.error;
      });
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

// ---------------------------------------------------------------------------
// COMPLETED CELEBRATION VIEW — matches iOS DailyEntriesConfirmedView.swift
// ---------------------------------------------------------------------------

class _CompletedCelebrationView extends StatefulWidget {
  final WINRBranding branding;
  final int entries;
  final int bonusEntries;
  final String prizeHeadline;
  final String subtitle;
  final String buttonText;
  final SdkMedia? sdkMedia;
  final VoidCallback onContinue;

  const _CompletedCelebrationView({
    required this.branding,
    required this.entries,
    required this.bonusEntries,
    required this.prizeHeadline,
    required this.subtitle,
    required this.buttonText,
    required this.onContinue,
    this.sdkMedia,
  });

  @override
  State<_CompletedCelebrationView> createState() =>
      _CompletedCelebrationViewState();
}

class _CompletedCelebrationViewState extends State<_CompletedCelebrationView>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _confettiController;
  bool _showContent = false;

  static String _formatEntries(int value) {
    return value
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _showContent = true);
      _scaleController.forward();
      _confettiController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  WINRBranding get b => widget.branding;

  Widget _buildHeroMedia(ScreenMedia? media, Widget defaultWidget) {
    // Try completed media first, then fall back to streakDashboard media
    final completedMedia = media;
    final streakMedia = widget.sdkMedia?.streakDashboard;

    final lottieUrl = completedMedia?.lottieUrl ?? streakMedia?.lottieUrl;
    final imageUrl = completedMedia?.imageUrl ?? streakMedia?.imageUrl;

    if (lottieUrl != null && lottieUrl.isNotEmpty) {
      return Lottie.network(
        lottieUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => defaultWidget,
      );
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => defaultWidget,
      );
    }
    return defaultWidget;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final safeBottom = bottomPadding == 0 ? 24.0 : bottomPadding + 4;

        return Stack(
          children: [
            // Confetti particles
            if (_showContent)
              _ConfettiOverlay(
                controller: _confettiController,
                accentColor: b.accentGlowColor,
                size: constraints.biggest,
              ),

            // Main content — vertically centered like iOS
            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: safeBottom + 80, // Room for Continue button
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Hero media
                  _buildHeroMedia(
                    widget.sdkMedia?.completed,
                    b.logoTwo != null || b.logo != null
                        ? SizedBox(
                            width: constraints.maxWidth * 0.6,
                            height: constraints.maxHeight * 0.18,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: (b.logoTwo ?? b.logo)!,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),

                  // Prize headline
                  Text(
                    widget.prizeHeadline,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: b.accentGlowColor.withValues(alpha: 0.8),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Big entry count with scale animation
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _showContent ? 1.0 : 0.0,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _formatEntries(widget.entries),
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: b.accentGlowColor.withValues(alpha: 0.6),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle — "Entries Claimed!"
                  AnimatedOpacity(
                    opacity: _showContent ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: b.secondaryTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Bonus entries breakdown
                  if (widget.bonusEntries > 0) ...[
                    const SizedBox(height: 10),
                    AnimatedOpacity(
                      opacity: _showContent ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 400),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            size: 12,
                            color: b.accentGlowColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+${_formatEntries(widget.bonusEntries)} bonus entries',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: b.accentGlowColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Encouragement text
                  AnimatedOpacity(
                    opacity: _showContent ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      'Come back tomorrow to keep your streak alive!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: b.mutedTextColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Continue button — inline, not sticky
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onContinue();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: b.primaryButtonColor,
                        borderRadius: BorderRadius.circular(b.cornerRadius),
                        boxShadow: [
                          BoxShadow(
                            color: b.accentGlowColor.withValues(alpha: 0.6),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.buttonText,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: b.primaryButtonTextColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// CONFETTI OVERLAY — lightweight particle effect for celebration
// ---------------------------------------------------------------------------

class _ConfettiOverlay extends StatelessWidget {
  final AnimationController controller;
  final Color accentColor;
  final Size size;

  const _ConfettiOverlay({
    required this.controller,
    required this.accentColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          size: size,
          painter: _ConfettiPainter(
            progress: controller.value,
            accentColor: accentColor,
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  static final math.Random _rng = math.Random(42);
  static late List<_ConfettiParticle> _particles;
  static bool _initialized = false;

  _ConfettiPainter({required this.progress, required this.accentColor}) {
    if (!_initialized) {
      _particles = List.generate(40, (i) => _ConfettiParticle(_rng));
      _initialized = true;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final fadeOut = progress > 0.7 ? (1.0 - progress) / 0.3 : 1.0;

    for (final p in _particles) {
      final x = p.startX * size.width + p.driftX * size.width * progress;
      final y = p.startY * size.height + p.speed * size.height * progress;

      if (y > size.height || y < 0) continue;

      final paint = Paint()
        ..color = p.color(accentColor).withValues(alpha: fadeOut * 0.8)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * p.rotationSpeed);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConfettiParticle {
  final double startX;
  final double startY;
  final double driftX;
  final double speed;
  final double rotation;
  final double rotationSpeed;
  final double w;
  final double h;
  final int colorIndex;

  _ConfettiParticle(math.Random rng)
      : startX = rng.nextDouble(),
        startY = -rng.nextDouble() * 0.3,
        driftX = (rng.nextDouble() - 0.5) * 0.4,
        speed = 0.6 + rng.nextDouble() * 0.5,
        rotation = rng.nextDouble() * math.pi * 2,
        rotationSpeed = (rng.nextDouble() - 0.5) * 10,
        w = 4 + rng.nextDouble() * 6,
        h = 3 + rng.nextDouble() * 4,
        colorIndex = rng.nextInt(5);

  Color color(Color accent) {
    switch (colorIndex) {
      case 0:
        return accent;
      case 1:
        return Colors.white;
      case 2:
        return const Color(0xFFFFD700);
      case 3:
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF7C3AED);
    }
  }
}
