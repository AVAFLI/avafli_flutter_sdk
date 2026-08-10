// The V2 experience root: the bottom drawer presented over the host app
// (dim backdrop, gunmetal sheet flush to bottom/sides, top corners rounded 30,
// ~90% screen height, spring slide-up) plus the experience state machine.
//
// Mirrors the iOS SDK's WINRV2ExperienceRoot (WINRV2Screens.swift) and
// WINRExperienceViewModel.swift:
//   loading → emailCapture | streak → howItWorks…
// Entries are granted automatically when the drawer opens (auto-claim).
// Day 1 AND Day 2+ celebrate IN PLACE (the Day-1 "You're in!" modal is
// gone): the dashboard mounts as the first-frame celebration — Day 1 stages
// the REAL grant from the awaited email-path claim, Day 2+ stages a
// PREDICTED grant from the pre-claim status response; the celebration (tile
// check + confetti + totals count-up + toast-first bar) fires on its own a
// beat after mount (Joe's Slice prototype); the pill reads GOT IT the whole
// time. Only the toast headline differs ("YOU'RE IN!" vs "YOU'RE ON A
// ROLL!"). "Already claimed" is silent (claimed dashboard) with a one-shot
// re-load to sync totals.

import 'dart:async';

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
import 'winr_v2_claim.dart';
import 'winr_v2_components.dart';
import 'winr_v2_effects.dart';
import 'winr_v2_screens.dart';
import 'winr_v2_theme.dart';
import 'winr_v2_winner.dart';

/// Experience state — mirrors iOS `WINRExperienceViewModel.State` (the V2
/// subset; bonus/milestone states are parked for Phase 1).
enum _V2Phase {
  loading,
  noActiveGiveaway,
  emailCapture,
  codeEntry,
  streak,
  howItWorks,

  /// This person is the drawn winner and hasn't submitted their claim yet —
  /// the drawer shows the winner splash → claim form → confirmation flow
  /// instead of the dashboard. Takes precedence on open.
  winnerClaim,
  error,
}

/// Sub-screen of the winner claim flow (`_phase == winnerClaim`) — mirrors
/// iOS `WinnerClaimStep`.
enum _WinnerClaimStep { splash, form, confirmation }

/// Tiny mount-settle delay before the Day 2+ celebration fires — just enough
/// for Flutter to render the staged "before" frame so every transition and
/// count has something to animate from. Visually imperceptible; the drawer's
/// slide-up covers it.
/// Mirrors iOS `WINRExperienceViewModel.mountRevealDelay`.
const winrV2MountRevealDelay = Duration(milliseconds: 150);

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

  bool _isClaiming = false;
  bool _isSubmittingEmail = false;

  /// Verification-gated adoption: the email awaiting its 6-digit code, plus the
  /// consents from the ORIGINAL submit (resend must reuse them — fabricating
  /// values would overwrite the marketing choice the person actually made).
  /// In-memory only; the raw email is never persisted locally.
  String? _pendingVerificationEmail;
  bool _pendingAgeConfirmed = false;
  bool _pendingMarketingConsent = false;
  bool _isVerifyingCode = false;
  String? _codeError;

  // ── V2 reveal flow (Day 2+) — mirrors iOS WINRExperienceViewModel ──
  //
  // The dashboard's FIRST VISIBLE FRAME is the celebration (the CTO's final
  // spec): toast bar, streak flip, counting total, and tile confetti all
  // fire in one beat at mount. Because the claim round-trip lands AFTER the
  // dashboard mounts, the grant is PREDICTED client-side from the pre-claim
  // status (WINRV2Ladder mirrors the backend's math exactly) and the real
  // response reconciles silently — identical numbers in the normal case.
  // The pill reads "GOT IT" the whole time — there is no claim tap.

  /// The grant staged for the celebration (null when nothing is pending).
  /// Predicted at load; replaced by the real grant when the claim lands.
  DailyEntryGrant? _pendingRevealGrant;

  /// Whether the in-place celebration has played.
  bool _claimRevealed = false;

  /// Total entries as of before today's claim, for the pre-reveal frame.
  int? _preClaimTotalEntries;

  void _revealClaim() {
    if (_pendingRevealGrant == null || _claimRevealed) return;
    setState(() => _claimRevealed = true);
  }

  /// Fires the celebration one imperceptible beat after the dashboard
  /// mounts, making the first visible frame the celebrating one. Idempotent
  /// — the guards here and in [_revealClaim] make double-fires harmless.
  void _armCelebrationReveal() {
    if (_pendingRevealGrant == null || _claimRevealed) return;
    unawaited(Future<void>.delayed(winrV2MountRevealDelay, () {
      if (!mounted) return;
      _revealClaim();
    }));
  }

  /// One-shot guard for the "already claimed on another device" re-sync.
  bool _didResyncAfterAlreadyClaimed = false;

  // ── Winner prize claim (mirrors iOS WINRExperienceViewModel) ──

  /// The pending prize-claim block driving the winner flow.
  PrizeClaimBlock? _prizeClaim;

  /// Which screen of the winner claim flow is showing.
  _WinnerClaimStep _winnerClaimStep = _WinnerClaimStep.splash;

  /// Spinner state for the claim form's SUBMIT pill.
  bool _isSubmittingClaim = false;

  /// Transport-level submit failure surfaced inline on the form ("Not the
  /// winner"/"Already submitted" instead fall back to the dashboard silently).
  String? _claimSubmitError;

  /// The submitted form, kept for the confirmation screen's winner card.
  WINRPrizeClaimForm? _submittedClaimForm;

  /// Confirmation payload from the backend.
  String _claimNumber = '';
  String _claimSubmittedAt = '';

  /// Set after a "Not the winner"/"Already submitted" rejection so the next
  /// load skips the winner flow and lands on the normal dashboard.
  bool _suppressWinnerClaim = false;

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

  @override
  void initState() {
    super.initState();
    _giveaway = widget.cachedGiveaway;
    _backendClaimedToday = widget.cachedClaimedToday;
    _backendStreakDay = widget.cachedStreakDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _drawerAppeared = true);
    });
    // Decode the confetti-burst GIF NOW so mounting it at the reveal beat
    // (dashboard mount) plays instantly from frame 0.
    WINRV2GifAsset.prewarm(WINRV2Assets.confettiBurst);
    // Same idea for the publisher's remote prize art: normally already warm
    // (the SDK warms it at registration/refresh), but a drawer opened before
    // that landed gets one more chance to have it decoded before the prize
    // card paints.
    WINRV2ImageWarmer.prewarm(_giveaway?.prizeImageUrl);
    WINRV2ImageWarmer.prewarm(widget.sdkConfig?.branding?.logoUrl);
    // Paint the dashboard from cache on the first frames — before any network
    // call resolves — then let [_load] reconcile silently.
    unawaited(_hydrateFromCache());
    _load();
  }

  // -------------------------------------------------------------------------
  // Cache-first render
  // -------------------------------------------------------------------------

  /// True once the dashboard has been painted from cached values, so the
  /// network reconcile knows it is updating a live dashboard rather than
  /// replacing a loading screen.
  bool _hydratedFromCache = false;

  /// Renders the dashboard IMMEDIATELY from cached state (giveaway config +
  /// persisted streak), skipping the loading phase entirely.
  ///
  /// The drawer used to sit on a spinner for as long as the sequential
  /// registerDevice → getActiveGiveaway → claim round-trips took (5s+ on a
  /// slow network) even when every value it needed was already on the device.
  /// Everything here is a LOCAL read, so this lands within a frame or two of
  /// mount; [_load] then reconciles the same way the celebration staging
  /// already does — silently, with no re-animation (the reveal flags are
  /// untouched, so a staged celebration still fires exactly once).
  ///
  /// Bails out (leaving the skeleton up) when anything is missing or when a
  /// fresh response has already resolved the phase — a first-ever open, an
  /// un-consented user who must see email capture first, or a cold cache all
  /// take the genuine loading path.
  Future<void> _hydrateFromCache() async {
    if (_phase != _V2Phase.loading) return;

    final storage = widget.preferencesStorage;
    final giveaway = widget.cachedGiveaway ?? await storage.getCachedGiveaway();
    if (giveaway == null) return;

    // Day 1 / unconsented users must land on email capture, never a dashboard.
    if (!await _hasEmailConsent) return;

    final stored = await storage.getStreakState();
    final day = widget.cachedStreakDay ?? stored?.currentDay;
    if (stored == null || day == null) return;

    // A network response beat us here — never stomp fresher truth.
    if (!mounted || _phase != _V2Phase.loading) return;

    final ladder = (giveaway.streakLadder.isNotEmpty)
        ? giveaway.streakLadder
        : List.generate(7, (i) => widget.streakEngine.baseEntries(i + 1));
    final dayIndex = (day - 1).clamp(0, ladder.length - 1);

    setState(() {
      _giveaway = giveaway;
      _streakState = stored.copyWith(currentDay: day);
      _ladder = ladder;
      _entriesToday = ladder[dayIndex];
      _claimedToday = widget.cachedClaimedToday ?? false;
      _hydratedFromCache = true;
      _phase = _V2Phase.streak;
    });
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

  Future<void> _load({bool claimBeforeDashboard = false}) async {
    final storage = widget.preferencesStorage;

    // Always fetch fresh claim status from the backend. The giveaway config
    // may already be cached, but claimedToday can change between opens.
    var backendClaimedToday = _backendClaimedToday;
    var backendStreakDay = _backendStreakDay;
    PrizeClaimBlock? pendingPrizeClaim;

    try {
      final response =
          await widget.networkClient.send(GetActiveGiveawayRequest());

      // RTD: an opted-out person never sees the experience content.
      if (response.optedOut == true) {
        WINR.markOptedOut();
        _setPhase(_V2Phase.noActiveGiveaway);
        return;
      }

      // Winner prize claim: a PENDING block takes precedence over the
      // dashboard on open (routed below, once the caches are synced).
      // A "submitted" block is ignored — the normal dashboard shows.
      final claim = response.prizeClaim;
      if (claim != null && claim.isPending && !_suppressWinnerClaim) {
        pendingPrizeClaim = claim;
      }

      // Check if backend returned no active giveaway. (A pending prize claim
      // can outlive its giveaway — the winner flow still shows.)
      if (response.giveaway == null && pendingPrizeClaim == null) {
        _giveaway = null;
        await storage.remove(StorageKeys.cachedGiveaway);
        _setPhase(_V2Phase.noActiveGiveaway);
        return;
      }

      if (response.giveaway != null) {
        _giveaway = response.giveaway;
        await storage.cacheGiveaway(response.giveaway!);
        // Keep the prize art warm across prize changes mid-session.
        WINRV2ImageWarmer.prewarm(response.giveaway!.prizeImageUrl);
      }
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
    } catch (e) {
      // Offline fallback: use cached giveaway.
      _giveaway ??= await storage.getCachedGiveaway();
      Logger.instance.debug('Using cached giveaway (offline): $e');
    }

    _backendClaimedToday = backendClaimedToday;
    _backendStreakDay = backendStreakDay;

    // Winner prize claim takes precedence over auto-claim/dashboard on open —
    // but the daily auto-claim still fires silently in the background so the
    // winner's entries keep accruing. Routed BEFORE the email gate.
    if (pendingPrizeClaim != null) {
      final hasConsent = await _hasEmailConsent;
      if (!mounted) return;
      setState(() {
        _prizeClaim = pendingPrizeClaim;
        _winnerClaimStep = _WinnerClaimStep.splash;
        _claimSubmitError = null;
        _phase = _V2Phase.winnerClaim;
      });
      widget.configuration.options.analyticsAdapter?.track(
        'winr_winner_claim_shown',
        {'giveaway_id': pendingPrizeClaim.giveawayId},
      );
      if (backendClaimedToday != true && hasConsent) {
        _silentDailyClaim();
      }
      return;
    }

    if (_giveaway == null) {
      _setPhase(_V2Phase.noActiveGiveaway);
      return;
    }

    // Email-capture gate: shown until the user completes the consent flow.
    if (!await _hasEmailConsent) {
      _setPhase(_V2Phase.emailCapture);
      return;
    }

    // Email path (Day 1): claim FIRST, while the capture view's spinner is
    // still up. On success the celebration is staged from the REAL response
    // (synchronous with the transition — no prediction needed) and the
    // caches already reflect the claim, so the predicted staging below is
    // naturally skipped. On failure this is a no-op and the normal predict →
    // auto-claim → reconcile path takes over.
    if (claimBeforeDashboard && backendClaimedToday == false) {
      await _claimAndStageBeforeDashboard();
      backendClaimedToday = _backendClaimedToday;
      backendStreakDay = _backendStreakDay;
    }

    // Auto-claim staging (Day 1 AND Day 2+): stage the PREDICTED grant
    // BEFORE the dashboard state is set, so the celebration is the
    // dashboard's first visible frame — the claim round-trip lands later and
    // reconciles silently. Day 1 celebrates in place exactly like Day 2+
    // (the "You're in!" modal is gone); only the toast headline differs.
    // Day 1 normally never reaches this — the email path claims first — but
    // an interrupted Day-1 open (killed between email submit and claim)
    // falls through here and still celebrates in place.
    if (backendClaimedToday == false &&
        backendStreakDay != null &&
        backendStreakDay >= 1 &&
        _backendTotalEntries != null) {
      final predicted = WINRV2Ladder.entries(
        day: backendStreakDay,
        ladder: _displayLadder,
        milestones: _giveaway?.milestones,
      );
      _pendingRevealGrant = DailyEntryGrant(baseEntries: predicted);
      _claimRevealed = false;
      _preClaimTotalEntries = _backendTotalEntries;
    }

    await _computeStreakAndMoveToDashboard(
      backendClaimedToday: backendClaimedToday,
      backendStreakDay: backendStreakDay,
    );

    // Day 2+: the celebration IS the first visible frame — the reveal flips
    // one imperceptible beat after the dashboard mounts so every transition
    // has a "before" frame to animate from. (No-op without a staged grant.)
    _armCelebrationReveal();

    // V2 experience: entries are granted automatically when the drawer
    // opens — no tap required. Registered + consented + not-yet-claimed →
    // claim now, in the background of the already-playing celebration.
    // Failures are silent (the dashboard settles to the unclaimed state).
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
      } else if (!_hydratedFromCache) {
        _setPhase(_V2Phase.error);
      }
      // Already showing a cache-rendered dashboard: a local streak-engine
      // hiccup is not worth replacing it with an error screen.
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

  Future<void> _submitEmail(
    String email, {
    required bool ageConfirmed,
    required bool marketingConsent,
  }) async {
    if (email.isEmpty || _isSubmittingEmail) return;

    // NOTE: we deliberately do NOT persist the raw email locally (PII-High).
    // The backend stores it encrypted and returns a user_uid handshake.
    await widget.preferencesStorage.setBool(StorageKeys.emailConfirmed, true);

    setState(() => _isSubmittingEmail = true);
    try {
      final response = await widget.networkClient.send(SubmitEmailRequest(
        email: email,
        ageConfirmed: ageConfirmed,
        marketingConsent: marketingConsent,
        publisherUserId: widget.configuration.user.id,
      ));

      // Cross-device streak unification: if this email already belonged to an
      // existing user under this publisher (another device/SDK), the backend
      // hands back that canonical user's credentials. Switch to them so the
      // person keeps ONE streak per publisher across devices.
      if (response.verificationRequired) {
        // The typed address matches an EXISTING account: the merge is parked
        // until the person proves the inbox is theirs.
        if (mounted) {
          setState(() {
            _pendingVerificationEmail = email;
            _pendingAgeConfirmed = ageConfirmed;
            _pendingMarketingConsent = marketingConsent;
            _codeError = null;
            _isSubmittingEmail = false;
            _phase = _V2Phase.codeEntry;
          });
        }
        return;
      }

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
      // The backend now holds a confirmed email + consent for this user, but
      // WINR's cached copy of that flag is only ever refreshed by
      // getActiveGiveaway. Mark it here too so nothing downstream (notably
      // the unregistered auto-open impression cap) keeps treating a
      // just-registered user as unregistered until the next refresh lands.
      WINR.markEmailConsentGranted();
      Logger.instance.debug('Email submitted to backend');
    } catch (e) {
      Logger.instance
          .error('Email submit to backend failed (will retry later)', e);
    } finally {
      if (mounted) setState(() => _isSubmittingEmail = false);
    }

    // Re-load so the (possibly switched) canonical user's authoritative
    // streak + claim status drive the UI. The Day-1 claim is awaited INSIDE
    // the load (capture spinner stays up) so the dashboard mounts already
    // celebrating — never an uncelebrated streak page.
    if (mounted) {
      _setPhase(_V2Phase.loading);
      await _load(claimBeforeDashboard: true);
    }
  }

  /// Email path (Day 1): awaited claim BEFORE the dashboard ever mounts. On
  /// success the celebration is staged from the REAL response, so the first
  /// dashboard frame counts 0 → N under the "YOU'RE IN!" toast. On failure
  /// this is a no-op — [_load] falls through to the predicted staging and
  /// the silent auto-claim retry, the same as any other open.
  Future<void> _claimAndStageBeforeDashboard() async {
    try {
      final response =
          await widget.networkClient.send(ClaimDailyEntriesRequest());

      var streakBonusEntries = 0;
      streakBonusEntries += response.weeklyBonusEntries ?? 0;
      streakBonusEntries += response.monthlyBonusEntries ?? 0;
      streakBonusEntries += response.milestone?.bonusEntries ?? 0;
      streakBonusEntries += response.monthlyMilestone?.bonusEntries ?? 0;
      final grant = DailyEntryGrant(
        baseEntries: response.entries,
        bonusEntries: streakBonusEntries,
      );

      _backendTotalEntries = response.totalEntries;
      _backendStreakDay = response.streakDay;
      _backendClaimedToday = true;
      _backendMonthlyCurrent = response.monthlyCurrent;
      _backendWeeklyCurrent = response.weeklyCurrent;

      _grant = grant;
      _pendingRevealGrant = grant;
      _preClaimTotalEntries = response.totalEntries - grant.total;
      _claimRevealed = false;

      WINR.syncClaimedToday(true);
      await WINR.persistClaimedToday(widget.preferencesStorage);

      widget.configuration.options.analyticsAdapter?.track(
        'winr_daily_entry_claimed',
        {'day': response.streakDay, 'entries': response.entries},
      );
    } catch (e) {
      Logger.instance.info(
          'Day-1 claim after email submit failed (dashboard will retry): $e');
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
      // V2 auto-claim routing (Day 1 AND Day 2+, unified — the Day-1
      // celebration modal is gone): the celebration already played (or is
      // playing) at mount off the staged grant — reconcile the staged
      // numbers with the real response. In the normal case they're
      // identical, so nothing visibly changes; a mismatch silently corrects
      // the readouts. `_claimRevealed` is NOT reset — the celebration never
      // replays. Day 1 only differs in the toast headline ("YOU'RE IN!"
      // instead of "YOU'RE ON A ROLL!").
      setState(() {
        _streakState = updatedStreak;
        _claimedToday = true;
        _grant = grant;
        _entriesToday = grant.baseEntries;
        _pendingRevealGrant = grant;
        _preClaimTotalEntries = response.totalEntries - grant.total;
        _phase = _V2Phase.streak;
        _isClaiming = false;
      });
      // Safety net: if no prediction was staged pre-mount (e.g. the status
      // fetch was offline), the mount found nothing pending — fire the
      // reveal now. No-op when the reveal already played.
      _armCelebrationReveal();
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
          // Roll back the predicted celebration NUMBERS — the prediction was
          // built on a stale total. The reveal state itself stays (no
          // animation replay); the re-load silently corrects the total.
          _pendingRevealGrant = null;
          _preClaimTotalEntries = null;
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
        // Roll back the predicted celebration — nothing was granted. The
        // dashboard settles to the calm unclaimed state and the total
        // readout reverts silently (no animation replay).
        _pendingRevealGrant = null;
        _preClaimTotalEntries = null;
        _claimRevealed = false;
        _claimedToday = false;
        _phase = _V2Phase.streak;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Winner prize claim
  // -------------------------------------------------------------------------

  /// Prefill for the claim form (host-app-provided identity) — mirrors iOS
  /// `claimFormPrefill`.
  WINRPrizeClaimForm get _claimFormPrefill => WINRPrizeClaimForm(
        firstName: widget.configuration.user.firstName,
        lastName: widget.configuration.user.lastName,
        phone: widget.configuration.user.phone ?? '',
      );

  /// Fire-and-forget daily claim while the winner flow is on screen — the
  /// winner still accrues their streak entries, but nothing is revealed.
  void _silentDailyClaim() {
    unawaited(() async {
      try {
        final response =
            await widget.networkClient.send(ClaimDailyEntriesRequest());
        _backendClaimedToday = true;
        _backendStreakDay = response.streakDay;
        _backendTotalEntries = response.totalEntries;
        _claimedToday = true;
        WINR.syncClaimedToday(true);
        await WINR.persistClaimedToday(widget.preferencesStorage);
        Logger.instance.debug(
            'Silent daily claim during winner flow: +${response.entries}');
      } catch (e) {
        Logger.instance
            .debug('Silent daily claim declined during winner flow: $e');
      }
    }());
  }

  /// Splash CONTINUE → the claim form.
  void _winnerClaimContinue() {
    if (_phase != _V2Phase.winnerClaim) return;
    setState(() => _winnerClaimStep = _WinnerClaimStep.form);
  }

  /// SUBMIT on the claim form. Success → confirmation screen. A backend
  /// "Not the winner"/"Already submitted" rejection falls back to the normal
  /// dashboard silently (logged); transport failures surface inline.
  Future<void> _submitPrizeClaim(WINRPrizeClaimForm form) async {
    final claim = _prizeClaim;
    if (_phase != _V2Phase.winnerClaim || claim == null || _isSubmittingClaim) {
      return;
    }
    if (!form.isValid) return;
    setState(() {
      _claimSubmitError = null;
      _isSubmittingClaim = true;
    });

    try {
      final response = await widget.networkClient.send(SubmitPrizeClaimRequest(
        giveawayId: claim.giveawayId,
        firstName: form.firstName.trim(),
        lastName: form.lastName.trim(),
        phone: form.phone.trim().isEmpty ? null : form.phone.trim(),
        street: form.street.trim(),
        apt: form.apt.trim().isEmpty ? null : form.apt.trim(),
        city: form.city.trim(),
        state: form.state.trim(),
        zip: form.zip.trim(),
        country: form.country,
        photoBase64: form.photoBase64,
        story: form.story.trim().isEmpty ? null : form.story.trim(),
      ));
      if (!mounted) return;
      setState(() {
        _isSubmittingClaim = false;
        _submittedClaimForm = form;
        _claimNumber = response.claimNumber;
        _claimSubmittedAt = response.submittedAt;
        _winnerClaimStep = _WinnerClaimStep.confirmation;
      });
      widget.configuration.options.analyticsAdapter?.track(
        'winr_prize_claim_submitted',
        {
          'giveaway_id': claim.giveawayId,
          'claim_number': response.claimNumber,
        },
      );
    } catch (e) {
      _isSubmittingClaim = false;
      final message =
          e is WINRException ? (e.serverMessage ?? e.toString()) : '$e';
      if (message.contains('Not the winner') ||
          message.contains('Already submitted')) {
        // Stale/duplicate winner state — never trap the user in the claim
        // flow. Fall back to the normal dashboard silently.
        Logger.instance.info(
            'Prize claim rejected ($message) — falling back to dashboard');
        _suppressWinnerClaim = true;
        _setPhase(_V2Phase.loading);
        await _load();
        return;
      }
      Logger.instance.error('Prize claim submit failed', e);
      if (!mounted) return;
      setState(() {
        _claimSubmitError =
            'Something went wrong. Please check your connection and try again.';
      });
    }
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
                curve:
                    _drawerAppeared ? Curves.easeOutCubic : Curves.easeInCubic,
                child: SizedBox(
                  height: constraints.maxHeight * 0.90,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(30)),
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

  /// Check the 6-digit adoption code; approved → adopt the canonical user's
  /// credentials and reload into the dashboard (same as a direct adoption).
  Future<void> _submitVerificationCode(String code) async {
    if (_isVerifyingCode) return;
    setState(() {
      _isVerifyingCode = true;
      _codeError = null;
    });
    try {
      final response =
          await widget.networkClient.send(VerifyAdoptionCodeRequest(code: code));
      if (response.adopted && response.token != null && response.uuid != null) {
        await widget.secureStorage.saveAuthToken(response.token!);
        if (response.refreshToken != null) {
          await widget.secureStorage.saveRefreshToken(response.refreshToken!);
        }
        await widget.secureStorage.saveUserUuid(response.uuid!);
        widget.networkClient.setAuthToken(response.token!);
        Logger.instance.info('Adoption verified — streak unified across devices');
      }
      WINR.markEmailConsentGranted();
      if (mounted) {
        setState(() {
          _pendingVerificationEmail = null;
          _isVerifyingCode = false;
          _phase = _V2Phase.loading;
        });
        await _load(claimBeforeDashboard: true);
      }
    } catch (e) {
      Logger.instance.error('Adoption code check failed', e);
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
          _codeError = "That code didn't match. Check the email and try again.";
        });
      }
    }
  }

  /// Request a fresh code by re-submitting the ORIGINAL email + consents.
  Future<void> _resendVerificationCode() async {
    final email = _pendingVerificationEmail;
    if (email == null) return;
    setState(() => _phase = _V2Phase.emailCapture);
    await _submitEmail(
      email,
      ageConfirmed: _pendingAgeConfirmed,
      marketingConsent: _pendingMarketingConsent,
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

      case _V2Phase.codeEntry:
        return WINRV2CodeEntryView(
          accent: _accent,
          logoUrl: _logoUrl,
          email: _pendingVerificationEmail ?? '',
          isVerifying: _isVerifyingCode,
          errorText: _codeError,
          onSubmit: (code) => unawaited(_submitVerificationCode(code)),
          onResend: () => unawaited(_resendVerificationCode()),
          onInfo: _showHowItWorks,
          onClose: _requestDismiss,
        );

      case _V2Phase.emailCapture:
        return WINRV2CaptureView(
          accent: _accent,
          logoUrl: _logoUrl,
          rulesUrl: _rulesUrl,
          giveaway: _giveaway,
          isSubmitting: _isSubmittingEmail,
          marketingConsentText:
              widget.sdkConfig?.copy?.resolvedEmailConsentText,
          prefilledEmail: widget.configuration.user.email,
          onSubmit: (email, {required ageConfirmed, required marketingConsent}) =>
              unawaited(_submitEmail(
            email,
            ageConfirmed: ageConfirmed,
            marketingConsent: marketingConsent,
          )),
          onInfo: _showHowItWorks,
          onClose: _requestDismiss,
        );

      case _V2Phase.streak:
        // Staged "before" frame: while the reveal hasn't played, show
        // yesterday's numbers (on a celebration open this frame lasts one
        // imperceptible beat — winrV2MountRevealDelay). Without the
        // claimedToday clause there's a flash of the raw post-claim server
        // state during the network round-trip, and elements flip at
        // different times.
        final preReveal =
            !_claimRevealed && (_pendingRevealGrant != null || !_claimedToday);
        // A staged celebration counts up to the PREDICTED post-claim total —
        // the real claim response reconciles this silently (normally a
        // no-op, since WINRV2Ladder mirrors the backend's math).
        final grant = _pendingRevealGrant;
        final postClaimTotal = (grant != null && _preClaimTotalEntries != null)
            ? _preClaimTotalEntries! + grant.total
            : _streakState?.totalEntriesEarned ?? _backendTotalEntries ?? 0;
        return WINRV2DashboardView(
          accent: _accent,
          logoUrl: _logoUrl,
          rulesUrl: _rulesUrl,
          giveaway: _giveaway,
          streakDay: _streakState?.currentDay ?? _displayStreakDay,
          totalEntries: preReveal
              ? (_preClaimTotalEntries ?? postClaimTotal)
              : postClaimTotal,
          entriesToday: _entriesToday,
          ladder: _ladder.isNotEmpty ? _ladder : _displayLadder,
          claimedToday: _claimedToday,
          onInfo: _showHowItWorks,
          onClose: _requestDismiss,
          onWinnerTap: () => setState(() => _showWinnerModal = true),
          pendingClaimEntries: _pendingRevealGrant?.total,
          revealed: _claimRevealed,
        );

      case _V2Phase.winnerClaim:
        return _winnerClaimContent();

      case _V2Phase.howItWorks:
        return WINRV2HowItWorksView(
          accent: _accent,
          logoUrl: _logoUrl,
          day1Entries: _displayLadder.isNotEmpty ? _displayLadder.first : 10,
          visitMode: _visitMode,
          onDone: _hideHowItWorks,
          onClose: _requestDismiss,
        );
    }
  }

  /// Winner splash → claim form → confirmation, cross-faded between steps
  /// (mirrors iOS's easeInOut step animation on `WINRV2WinnerClaimFlow`).
  Widget _winnerClaimContent() {
    final claim = _prizeClaim;
    if (claim == null) return const WINRV2LoadingView();

    final Widget step;
    switch (_winnerClaimStep) {
      case _WinnerClaimStep.splash:
        step = WINRV2WinnerSplashView(
          key: const ValueKey('winner-splash'),
          accent: _accent,
          logoUrl: _logoUrl,
          prizeHeadline: winrV2StripHeadline(
            claim.prizeDescription,
            claim.prizeValue.toInt(),
          ),
          onContinue: _winnerClaimContinue,
          onClose: _requestDismiss,
        );
      case _WinnerClaimStep.form:
        step = WINRV2ClaimStepsFlow(
          key: const ValueKey('winner-form'),
          accent: _accent,
          logoUrl: _logoUrl,
          rulesUrl: _rulesUrl,
          maskedEmail: claim.maskedEmail,
          prizeHeadline: winrV2StripHeadline(
            claim.prizeDescription,
            claim.prizeValue.toInt(),
          ),
          initialForm: _claimFormPrefill,
          isSubmitting: _isSubmittingClaim,
          submitError: _claimSubmitError,
          onSubmit: (form) => unawaited(_submitPrizeClaim(form)),
          onClose: _requestDismiss,
        );
      case _WinnerClaimStep.confirmation:
        step = WINRV2ClaimConfirmationView(
          key: const ValueKey('winner-confirmation'),
          accent: _accent,
          logoUrl: _logoUrl,
          form: _submittedClaimForm,
          claimNumber: _claimNumber,
          submittedAt: _claimSubmittedAt,
          onDone: _requestDismiss,
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: step,
    );
  }
}
