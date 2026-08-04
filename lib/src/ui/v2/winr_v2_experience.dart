// The V2 experience root: the bottom drawer presented over the host app
// (dim backdrop, gunmetal sheet flush to bottom/sides, top corners rounded 30,
// ~90% screen height, spring slide-up) plus the experience state machine.
//
// Mirrors the iOS SDK's WINRV2ExperienceRoot (WINRV2Screens.swift) and
// WINRExperienceViewModel.swift:
//   loading → emailCapture | streak → dailyConfirmed → streak → howItWorks…
// Entries are granted automatically when the drawer opens (auto-claim); a
// successful claim ALWAYS lands on the celebration modal; "Already claimed"
// is silent (claimed dashboard) with a one-shot re-load to sync totals.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/daily_entry_grant.dart';
import '../../domain/giveaway.dart';
import '../../domain/sdk_config.dart';
import '../../domain/streak_engine.dart';
import '../../domain/streak_state.dart';
import '../../network/network_client.dart';
import '../../network/winr_api.dart';
import '../../services/logger.dart';
import '../../storage/preferences_storage.dart';
import '../../storage/secure_storage.dart';
import '../../storage/storage.dart';
import '../../winr.dart';
import '../../winr_configuration.dart';
import '../../winr_error.dart';
import 'winr_v2_screens.dart';
import 'winr_v2_theme.dart';
import 'winr_v2_winner.dart';

/// Experience state — mirrors iOS `WINRExperienceViewModel.State` (the V2
/// subset; bonus/milestone states are parked for Phase 1).
enum _V2Phase {
  loading,
  noActiveGiveaway,
  emailCapture,
  streak,
  dailyConfirmed,
  howItWorks,
  error,
}

class WINRV2Experience extends StatefulWidget {
  final WINRConfiguration configuration;
  final NetworkClient networkClient;
  final SecureStorage secureStorage;
  final PreferencesStorage preferencesStorage;
  final StreakEngine streakEngine;
  final Giveaway? cachedGiveaway;
  final bool? cachedClaimedToday;
  final int? cachedStreakDay;
  final WinrSdkConfig? sdkConfig;

  const WINRV2Experience({
    super.key,
    required this.configuration,
    required this.networkClient,
    required this.secureStorage,
    required this.preferencesStorage,
    required this.streakEngine,
    this.cachedGiveaway,
    this.cachedClaimedToday,
    this.cachedStreakDay,
    this.sdkConfig,
  });

  @override
  State<WINRV2Experience> createState() => _WINRV2ExperienceState();
}

class _WINRV2ExperienceState extends State<WINRV2Experience> {
  _V2Phase _phase = _V2Phase.loading;
  _V2Phase? _lastPrimaryPhase;

  Giveaway? _giveaway;
  StreakState? _streakState;
  List<int> _ladder = const [];
  int _entriesToday = 0;
  bool _claimedToday = false;

  bool? _backendClaimedToday;
  int? _backendStreakDay;
  int? _backendMonthlyCurrent;
  int? _backendWeeklyCurrent;
  int? _backendTotalEntries;

  DailyEntryGrant? _grant;
  int _confirmedTotalEntries = 0;

  bool _isClaiming = false;
  bool _isSubmittingEmail = false;

  /// One-shot guard for the "already claimed on another device" re-sync.
  bool _didResyncAfterAlreadyClaimed = false;

  bool _showWinnerModal = false;
  bool _drawerAppeared = false;
  bool _isDismissing = false;

  // -------------------------------------------------------------------------
  // Derived display values (mirror iOS view-model accessors)
  // -------------------------------------------------------------------------

  Color get _accent =>
      WINRV2Accent(widget.sdkConfig?.branding?.primaryColor).color;

  String? get _logoUrl => widget.sdkConfig?.branding?.logoUrl;

  String? get _rulesUrl => _giveaway?.rulesUrl ?? widget.sdkConfig?.rulesUrl;

  bool get _visitMode => _giveaway?.isVisitMode ?? false;

  int get _displayStreakDay =>
      _backendStreakDay ?? _streakState?.currentDay ?? 1;

  /// The effective reward ladder (giveaway config, else engine defaults).
  List<int> get _displayLadder {
    final ladder = _giveaway?.streakLadder;
    if (ladder != null && ladder.isNotEmpty) return ladder;
    return List.generate(7, (i) => widget.streakEngine.baseEntries(i + 1));
  }

  /// Tomorrow's reward, for the celebration modal + come-back messaging.
  /// Uses the shared ladder math so accelerator milestones keep increasing it.
  int get _displayNextEntries => WINRV2Ladder.entries(
        day: _displayStreakDay + 1,
        ladder: _displayLadder,
        milestones: _giveaway?.milestones,
      );

  @override
  void initState() {
    super.initState();
    _giveaway = widget.cachedGiveaway;
    _backendClaimedToday = widget.cachedClaimedToday;
    _backendStreakDay = widget.cachedStreakDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _drawerAppeared = true);
    });
    _load();
  }

  // -------------------------------------------------------------------------
  // State machine (port of WINRExperienceViewModel)
  // -------------------------------------------------------------------------

  /// Whether the registration handshake produced a user_uid.
  Future<bool> get _hasRegistered async =>
      (await widget.secureStorage.getUserUuid()) != null;

  /// Whether the user has completed email capture (required before claiming).
  /// Gated on the non-PII "email submitted" flag — raw email is never stored.
  Future<bool> get _hasEmailConsent async {
    final submitted =
        await widget.preferencesStorage.getBool(StorageKeys.emailConfirmed) ??
            false;
    return submitted && await _hasRegistered;
  }

  Future<void> _load() async {
    final storage = widget.preferencesStorage;

    // Always fetch fresh claim status from the backend. The giveaway config
    // may already be cached, but claimedToday can change between opens.
    var backendClaimedToday = _backendClaimedToday;
    var backendStreakDay = _backendStreakDay;

    try {
      final response =
          await widget.networkClient.send(GetActiveGiveawayRequest());

      // RTD: an opted-out person never sees the experience content.
      if (response.optedOut == true) {
        WINR.markOptedOut();
        _setPhase(_V2Phase.noActiveGiveaway);
        return;
      }

      if (response.giveaway == null) {
        _giveaway = null;
        await storage.remove(StorageKeys.cachedGiveaway);
        _setPhase(_V2Phase.noActiveGiveaway);
        return;
      }

      _giveaway = response.giveaway;
      backendClaimedToday = response.claimedToday;
      backendStreakDay = response.streakDay;
      _backendMonthlyCurrent = response.monthlyCurrent;
      _backendWeeklyCurrent = response.weeklyCurrent;
      _backendTotalEntries = response.totalEntries;

      // Backend is the source of truth for email consent. If it confirms an
      // email on file, seed the local "submitted" flag so a user whose local
      // flag was lost (e.g. reinstall) isn't re-prompted for email.
      if (response.emailConsentStatus) {
        await storage.setBool(StorageKeys.emailConfirmed, true);
      }

      await storage.cacheGiveaway(response.giveaway!);
    } catch (e) {
      // Offline fallback: use cached giveaway.
      _giveaway ??= await storage.getCachedGiveaway();
      Logger.instance.debug('Using cached giveaway (offline): $e');
    }

    _backendClaimedToday = backendClaimedToday;
    _backendStreakDay = backendStreakDay;

    if (_giveaway == null) {
      _setPhase(_V2Phase.noActiveGiveaway);
      return;
    }

    // Email-capture gate: shown until the user completes the consent flow.
    if (!await _hasEmailConsent) {
      _setPhase(_V2Phase.emailCapture);
      return;
    }

    await _computeStreakAndMoveToDashboard(
      backendClaimedToday: backendClaimedToday,
      backendStreakDay: backendStreakDay,
    );

    // V2 experience: entries are granted automatically when the drawer
    // opens — no tap required. Registered + consented + not-yet-claimed →
    // claim now. Failures are silent (the dashboard just shows the
    // unclaimed state).
    if (_phase == _V2Phase.streak && !_claimedToday) {
      await _claimDailyEntries(auto: true);
    }
  }

  Future<void> _computeStreakAndMoveToDashboard({
    bool? backendClaimedToday,
    int? backendStreakDay,
  }) async {
    final storage = widget.preferencesStorage;
    final stored = await storage.getStreakState();
    final today = DateTime.now();
    final ladder = _displayLadder;

    // ── Backend is source of truth for claim status ──
    if (backendClaimedToday != null) {
      final day = backendStreakDay ?? stored?.currentDay ?? 1;
      final dayIndex = (day - 1).clamp(0, ladder.length - 1);
      final entriesToday = ladder[dayIndex];

      var displayState = stored ??
          StreakState(
            currentDay: day,
            lastClaimedDate: backendClaimedToday ? today : null,
            totalEntriesEarned: 0,
            weeklyCurrent: 1,
            monthlyCurrent: 1,
          );

      // Always sync with the backend — it is the source of truth. Seed the
      // running total from the backend so the Total-entries readout reflects
      // entries claimed on OTHER devices.
      displayState = displayState.copyWith(
        currentDay: day,
        monthlyCurrent: _backendMonthlyCurrent,
        weeklyCurrent: _backendWeeklyCurrent,
        totalEntriesEarned: _backendTotalEntries,
        lastClaimedDate:
            (backendClaimedToday && stored?.lastClaimedDate == null)
                ? today
                : null,
      );
      await storage.saveStreakState(displayState);

      if (!mounted) return;
      setState(() {
        _streakState = displayState;
        _ladder = ladder;
        _entriesToday = entriesToday;
        _claimedToday = backendClaimedToday;
        _phase = _V2Phase.streak;
      });
      return;
    }

    // ── Offline fallback: use local StreakEngine ──
    final result = widget.streakEngine.nextState(stored, today);
    if (!mounted) return;
    if (result.isError) {
      if (result.error == WINRError.ineligibleToday && stored != null) {
        final dayIndex = (stored.currentDay - 1).clamp(0, ladder.length - 1);
        setState(() {
          _streakState = stored;
          _ladder = ladder;
          _entriesToday = ladder[dayIndex];
          _claimedToday = true;
          _phase = _V2Phase.streak;
        });
      } else {
        _setPhase(_V2Phase.error);
      }
      return;
    }
    final newState = result.value;
    final dayIndex = (newState.currentDay - 1).clamp(0, ladder.length - 1);
    setState(() {
      _streakState = newState;
      _ladder = ladder;
      _entriesToday = ladder[dayIndex];
      _claimedToday = false;
      _phase = _V2Phase.streak;
    });
  }

  // -------------------------------------------------------------------------
  // Email capture
  // -------------------------------------------------------------------------

  Future<void> _submitEmail(String email) async {
    if (email.isEmpty || _isSubmittingEmail) return;

    // NOTE: we deliberately do NOT persist the raw email locally (PII-High).
    // The backend stores it encrypted and returns a user_uid handshake.
    await widget.preferencesStorage.setBool(StorageKeys.emailConfirmed, true);

    setState(() => _isSubmittingEmail = true);
    try {
      final response = await widget.networkClient.send(SubmitEmailRequest(
        email: email,
        hasConsent: true,
        publisherUserId: widget.configuration.user.id,
      ));

      // Cross-device streak unification: if this email already belonged to an
      // existing user under this publisher (another device/SDK), the backend
      // hands back that canonical user's credentials. Switch to them so the
      // person keeps ONE streak per publisher across devices.
      if (response.adopted && response.token != null && response.uuid != null) {
        await widget.secureStorage.saveAuthToken(response.token!);
        if (response.refreshToken != null) {
          await widget.secureStorage.saveRefreshToken(response.refreshToken!);
        }
        await widget.secureStorage.saveUserUuid(response.uuid!);
        widget.networkClient.setAuthToken(response.token!);
        Logger.instance
            .info('Adopted existing account — streak unified across devices');
      }
      Logger.instance.debug('Email submitted to backend');
    } catch (e) {
      Logger.instance.error('Email submit to backend failed (will retry later)', e);
    } finally {
      if (mounted) setState(() => _isSubmittingEmail = false);
    }

    // Re-load so the (possibly switched) canonical user's authoritative
    // streak + claim status drive the UI.
    if (mounted) {
      _setPhase(_V2Phase.loading);
      await _load();
    }
  }

  // -------------------------------------------------------------------------
  // Daily entries (auto-claim)
  // -------------------------------------------------------------------------

  Future<void> _claimDailyEntries({bool auto = false}) async {
    if (_phase != _V2Phase.streak || _isClaiming) return;
    final streak = _streakState;
    if (streak == null) return;
    _isClaiming = true;

    try {
      final response =
          await widget.networkClient.send(ClaimDailyEntriesRequest());

      // Bonus entries from all sources (milestones, weekly/monthly bonuses)
      // go into bonusEntries so the UI can show a proper breakdown.
      var streakBonusEntries = 0;
      streakBonusEntries += response.weeklyBonusEntries ?? 0;
      streakBonusEntries += response.monthlyBonusEntries ?? 0;
      streakBonusEntries += response.milestone?.bonusEntries ?? 0;
      streakBonusEntries += response.monthlyMilestone?.bonusEntries ?? 0;

      final grant = DailyEntryGrant(
        baseEntries: response.entries,
        bonusEntries: streakBonusEntries,
      );

      // Keep the display caches in sync so the post-celebration dashboard
      // shows the fresh totals (not the pre-claim snapshot).
      _backendTotalEntries = response.totalEntries;
      _backendStreakDay = response.streakDay;
      _backendClaimedToday = true;

      var updatedStreak = streak.copyWith(
        currentDay: response.streakDay,
        lastClaimedDate: DateTime.now(),
        totalEntriesEarned: response.totalEntries,
        monthlyCurrent: response.monthlyCurrent,
        weeklyCurrent: response.weeklyCurrent,
      );
      await widget.preferencesStorage.saveStreakState(updatedStreak);
      WINR.syncClaimedToday(true);
      await WINR.persistClaimedToday(widget.preferencesStorage);

      widget.configuration.options.analyticsAdapter?.track(
        'winr_daily_entry_claimed',
        {
          'day': response.streakDay,
          'entries': response.entries,
          if (response.weeklyBonusEntries != null)
            'weekly_bonus': response.weeklyBonusEntries,
          if (response.monthlyBonusEntries != null)
            'monthly_bonus': response.monthlyBonusEntries,
          if (response.milestone != null)
            'milestone_day': response.milestone!.day,
          if (response.milestone != null)
            'milestone_bonus': response.milestone!.bonusEntries,
        },
      );

      if (!mounted) return;
      // V2: a claim always lands on the celebration modal.
      setState(() {
        _streakState = updatedStreak;
        _claimedToday = true;
        _grant = grant;
        _entriesToday = grant.baseEntries;
        _confirmedTotalEntries = response.totalEntries;
        _phase = _V2Phase.dailyConfirmed;
        _isClaiming = false;
      });
    } catch (e) {
      _isClaiming = false;
      final isAlreadyClaimed =
          (e is WINRException && e.error == WINRError.ineligibleToday) ||
              e.toString().contains('Already claimed');

      // "Already claimed" means the user already got their entries today —
      // another device beat us between the status fetch and the claim. For an
      // auto-claim this isn't news worth celebrating: show the dashboard in
      // its claimed state and re-load ONCE to pull the authoritative totals.
      if (isAlreadyClaimed) {
        Logger.instance.info('Already claimed today — updating local state');
        final updatedStreak = streak.copyWith(lastClaimedDate: DateTime.now());
        await widget.preferencesStorage.saveStreakState(updatedStreak);
        WINR.syncClaimedToday(true);
        await WINR.persistClaimedToday(widget.preferencesStorage);
        if (!mounted) return;
        setState(() {
          _streakState = updatedStreak;
          _claimedToday = true;
          _phase = _V2Phase.streak;
        });
        // One-shot: never loop if status + claim keep disagreeing.
        if (!_didResyncAfterAlreadyClaimed) {
          _didResyncAfterAlreadyClaimed = true;
          unawaited(_load());
        }
        return;
      }

      // Auto-claim failures are SILENT by design: the dashboard simply shows
      // the unclaimed state. Never fake a local success for an auto-claim.
      Logger.instance.info('Auto-claim declined: $e');
      if (!mounted) return;
      setState(() {
        _claimedToday = false;
        _phase = _V2Phase.streak;
      });
    }
  }

  /// The celebration modal's GOT IT — settle onto the dashboard.
  void _showDashboardAfterCelebration() {
    unawaited(_computeStreakAndMoveToDashboard(
      backendClaimedToday: true,
      backendStreakDay: _backendStreakDay,
    ));
  }

  // -------------------------------------------------------------------------
  // Navigation helpers
  // -------------------------------------------------------------------------

  void _setPhase(_V2Phase phase) {
    if (!mounted) return;
    setState(() => _phase = phase);
  }

  void _showHowItWorks() {
    setState(() {
      _lastPrimaryPhase = _phase;
      _phase = _V2Phase.howItWorks;
    });
  }

  void _hideHowItWorks() {
    setState(() {
      final previous = _lastPrimaryPhase;
      _lastPrimaryPhase = null;
      if (previous != null) {
        _phase = previous;
      } else {
        _phase = _V2Phase.loading;
        unawaited(_load());
      }
    });
  }

  /// Close the whole experience (X buttons / GOT IT on the dashboard):
  /// slide the drawer down + fade the dim, then pop with the grant (if any).
  Future<void> _requestDismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    setState(() => _drawerAppeared = false);
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    Navigator.of(context).pop(_grant);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final latestWinner = _giveaway?.latestWinner;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Dimmed host app behind the drawer.
              AnimatedOpacity(
                opacity: _drawerAppeared ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: const SizedBox.expand(
                  child: ColoredBox(color: Color(0x73000000)),
                ),
              ),
              // The drawer: gunmetal sheet flush to bottom/sides, top corners
              // rounded 30, ~90% screen height, spring slide-up.
              AnimatedSlide(
                offset: _drawerAppeared ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 450),
                curve: _drawerAppeared ? Curves.easeOutCubic : Curves.easeInCubic,
                child: SizedBox(
                  height: constraints.maxHeight * 0.90,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30)),
                    child: ColoredBox(
                      color: WINRV2Colors.gunmetal,
                      child: _drawerContent(),
                    ),
                  ),
                ),
              ),
              if (_showWinnerModal && latestWinner != null)
                WINRV2WinnerModal(
                  accent: _accent,
                  winner: latestWinner,
                  onDismiss: () => setState(() => _showWinnerModal = false),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _drawerContent() {
    switch (_phase) {
      case _V2Phase.loading:
        return const WINRV2LoadingView();

      case _V2Phase.noActiveGiveaway:
      case _V2Phase.error:
        // Nothing to pitch (or opted out / errored) — quiet empty state.
        return WINRV2EmptyStateView(onClose: _requestDismiss);

      case _V2Phase.emailCapture:
        return WINRV2CaptureView(
          accent: _accent,
          logoUrl: _logoUrl,
          rulesUrl: _rulesUrl,
          giveaway: _giveaway,
          isSubmitting: _isSubmittingEmail,
          onSubmit: (email) => unawaited(_submitEmail(email)),
          onInfo: _showHowItWorks,
          onClose: _requestDismiss,
        );

      case _V2Phase.streak:
        return WINRV2DashboardView(
          accent: _accent,
          logoUrl: _logoUrl,
          rulesUrl: _rulesUrl,
          giveaway: _giveaway,
          streakDay: _streakState?.currentDay ?? _displayStreakDay,
          totalEntries: _streakState?.totalEntriesEarned ??
              _backendTotalEntries ??
              0,
          entriesToday: _entriesToday,
          ladder: _ladder.isNotEmpty ? _ladder : _displayLadder,
          claimedToday: _claimedToday,
          onInfo: _showHowItWorks,
          onClose: _requestDismiss,
          onWinnerTap: () => setState(() => _showWinnerModal = true),
        );

      case _V2Phase.dailyConfirmed:
        // Dashboard behind (blurred) + celebration modal on top.
        final grant = _grant ?? DailyEntryGrant(baseEntries: _entriesToday);
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: WINRV2DashboardView(
                accent: _accent,
                logoUrl: _logoUrl,
                rulesUrl: _rulesUrl,
                giveaway: _giveaway,
                streakDay: _displayStreakDay,
                totalEntries: _confirmedTotalEntries,
                entriesToday: grant.baseEntries,
                ladder: _displayLadder,
                claimedToday: true,
                onInfo: _showHowItWorks,
                onClose: _requestDismiss,
              ),
            ),
            WINRV2CelebrationModal(
              accent: _accent,
              streakDay: _displayStreakDay,
              earnedEntries: grant.total,
              nextEntries: _displayNextEntries,
              visitMode: _visitMode,
              onDismiss: _showDashboardAfterCelebration,
            ),
          ],
        );

      case _V2Phase.howItWorks:
        return WINRV2HowItWorksView(
          accent: _accent,
          logoUrl: _logoUrl,
          day1Entries:
              _displayLadder.isNotEmpty ? _displayLadder.first : 10,
          visitMode: _visitMode,
          onDone: _hideHowItWorks,
          onClose: _requestDismiss,
        );
    }
  }
}
