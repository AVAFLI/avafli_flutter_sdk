// The V2 experience root: the bottom drawer presented over the host app
// (dim backdrop, gunmetal sheet flush to bottom/sides, top corners rounded 30,
// ~90% screen height, spring slide-up) plus the experience state machine.
//
// Mirrors the iOS SDK's AvafliV2ExperienceRoot (AvafliV2Screens.swift) and
// AvafliExperienceViewModel.swift:
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
import '../../network/avafli_api.dart';
import '../../services/logger.dart';
import '../../storage/preferences_storage.dart';
import '../../storage/secure_storage.dart';
import '../../storage/storage.dart';
import '../../avafli.dart';
import '../../avafli_configuration.dart';
import '../../avafli_error.dart';
import 'avafli_v2_claim.dart';
import 'avafli_v2_components.dart';
import 'avafli_v2_effects.dart';
import 'avafli_v2_legal.dart';
import 'avafli_v2_screens.dart';
import 'avafli_v2_strings.dart';
import 'avafli_v2_theme.dart';
import 'avafli_v2_winner.dart';

/// Experience state — mirrors iOS `AvafliExperienceViewModel.State` (the V2
/// subset; bonus/milestone states are parked for Phase 1).
enum _V2Phase {
  loading,
  noActiveGiveaway,
  emailCapture,
  codeEntry,

  /// Soft email-verification: the reused 6-digit code screen, opened from the
  /// dashboard's "Verify your email" chip. Unlike [codeEntry] (adoption) this
  /// is DISMISSIBLE — a back arrow returns to the dashboard; it gates nothing.
  emailVerify,
  streak,
  howItWorks,

  /// This person is the drawn winner and hasn't submitted their claim yet —
  /// the drawer shows the winner splash → claim form → confirmation flow
  /// instead of the dashboard. Takes precedence on open.
  winnerClaim,

  /// Geo-blocked (`AvafliError.geographyNotAllowed`) — dedicated US-only
  /// messaging instead of the generic empty state.
  geoBlocked,

  /// Token refresh AND re-registration failed — dedicated retryable state.
  sessionExpired,
  error,
}

/// Sub-screen of the winner claim flow (`_phase == winnerClaim`). 2.9: the
/// share step now comes AFTER submit — form → submit → share → confirmation.
enum _WinnerClaimStep { splash, form, share, confirmation }

/// Tiny mount-settle delay before the Day 2+ celebration fires — just enough
/// for Flutter to render the staged "before" frame so every transition and
/// count has something to animate from. Visually imperceptible; the drawer's
/// slide-up covers it.
/// Mirrors iOS `AvafliExperienceViewModel.mountRevealDelay`.
const avafliV2MountRevealDelay = Duration(milliseconds: 150);

class AvafliV2Experience extends StatefulWidget {
  final AvafliConfiguration configuration;
  final NetworkClient networkClient;
  final SecureStorage secureStorage;
  final PreferencesStorage preferencesStorage;
  final StreakEngine streakEngine;
  final Giveaway? cachedGiveaway;
  final bool? cachedClaimedToday;
  final int? cachedStreakDay;
  final AvafliSdkConfig? sdkConfig;

  /// Adoption re-entry (2.9): true when the register response carried
  /// `adoptionPending: true` — an interrupted verification-gated adoption.
  /// Null-safe against current prod (absent → null → normal flow).
  final bool? adoptionPending;

  const AvafliV2Experience({
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
    this.adoptionPending,
  });

  @override
  State<AvafliV2Experience> createState() => _AvafliV2ExperienceState();
}

class _AvafliV2ExperienceState extends State<AvafliV2Experience> {
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

  /// Inline, retryable error on the capture screen for a failed email
  /// submit — the user stays on capture; the SDK never proceeds as if the
  /// submit worked ([AvafliV2Strings.emailSubmitFailed]).
  String? _emailSubmitError;

  /// Non-blocking dashboard notice (duplicate same-day entry / failed
  /// auto-claim) + its optional retry affordance and auto-clear timer.
  String? _dashboardNotice;
  VoidCallback? _dashboardNoticeRetry;
  Timer? _dashboardNoticeTimer;

  /// How long the transient "already entered today" notice stays up.
  static const _noticeAutoClear = Duration(seconds: 6);

  /// Verification-gated adoption: the email awaiting its 6-digit code, plus the
  /// consents from the ORIGINAL submit (resend must reuse them — fabricating
  /// values would overwrite the marketing choice the person actually made).
  /// In-memory only; the raw email is never persisted locally.
  String? _pendingVerificationEmail;
  bool _pendingAgeConfirmed = false;
  bool _pendingMarketingConsent = false;
  bool _isVerifyingCode = false;
  String? _codeError;

  /// Adoption re-entry (2.9): the current code screen was re-staged from an
  /// INTERRUPTED adoption (`adoptionPending: true` + `restageAdoption`).
  /// There is no locally-held email in this mode (the raw address was never
  /// persisted), so resends go through `restageAdoption` again instead of
  /// re-submitting the email.
  bool _isRestagedAdoption = false;

  /// Freshest `adoptionPending` signal from the status call (overrides the
  /// register-time value passed in via the widget).
  bool? _backendAdoptionPending;

  /// Soft email verification (distinct from the adoption gate above). The
  /// backend flags a brand-new, unconfirmed email with `emailVerified == false`
  /// on register/status and submitEmail; only an explicit false counts. While
  /// true the dashboard shows the persistent "Verify your email" chip. This
  /// NEVER blocks daily play, auto-claim, or the streak — it only affects
  /// prize-draw eligibility (enforced server-side).
  bool _unverified = false;
  bool _isVerifyingEmail = false;
  String? _emailVerifyError;

  // ── V2 reveal flow (Day 2+) — mirrors iOS AvafliExperienceViewModel ──
  //
  // The dashboard's FIRST VISIBLE FRAME is the celebration (the CTO's final
  // spec): toast bar, streak flip, counting total, and tile confetti all
  // fire in one beat at mount. Because the claim round-trip lands AFTER the
  // dashboard mounts, the grant is PREDICTED client-side from the pre-claim
  // status (AvafliV2Ladder mirrors the backend's math exactly) and the real
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
    unawaited(Future<void>.delayed(avafliV2MountRevealDelay, () {
      if (!mounted) return;
      _revealClaim();
    }));
  }

  /// One-shot guard for the "already claimed on another device" re-sync.
  bool _didResyncAfterAlreadyClaimed = false;

  // ── Winner prize claim (mirrors iOS AvafliExperienceViewModel) ──

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
  AvafliPrizeClaimForm? _submittedClaimForm;

  /// Confirmation payload from the backend.
  String _claimNumber = '';
  String _claimSubmittedAt = '';

  /// Set after a "Not the winner"/"Already submitted" rejection so the next
  /// load skips the winner flow and lands on the normal dashboard.
  bool _suppressWinnerClaim = false;

  bool _showWinnerModal = false;

  /// The delete-my-data confirmation (2.9.5): presented over the drawer
  /// AFTER the privacy webview pops on avafli://delete (iOS/web parity).
  bool _showsOptOutFlow = false;
  bool _drawerAppeared = false;
  bool _isDismissing = false;

  // -------------------------------------------------------------------------
  // Derived display values (mirror iOS view-model accessors)
  // -------------------------------------------------------------------------

  Color get _accent =>
      AvafliV2Accent(widget.sdkConfig?.branding?.primaryColor).color;

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
    AvafliV2GifAsset.prewarm(AvafliV2Assets.confettiBurst);
    // Same idea for the publisher's remote prize art: normally already warm
    // (the SDK warms it at registration/refresh), but a drawer opened before
    // that landed gets one more chance to have it decoded before the prize
    // card paints.
    AvafliV2ImageWarmer.prewarm(_giveaway?.prizeImageUrl);
    AvafliV2ImageWarmer.prewarm(widget.sdkConfig?.branding?.logoUrl);
    // Paint the dashboard from cache on the first frames — before any network
    // call resolves — then let [_load] reconcile silently.
    unawaited(_hydrateFromCache());
    _load();
  }

  @override
  void dispose() {
    _dashboardNoticeTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Dashboard notices (non-blocking)
  // -------------------------------------------------------------------------

  /// Shows a notice above the prize card. [autoClear] makes it transient;
  /// [onRetry] adds a TRY AGAIN affordance (mutually sensible, not both).
  void _showDashboardNotice(
    String message, {
    VoidCallback? onRetry,
    Duration? autoClear,
  }) {
    _dashboardNoticeTimer?.cancel();
    _dashboardNoticeTimer = null;
    if (!mounted) return;
    setState(() {
      _dashboardNotice = message;
      _dashboardNoticeRetry = onRetry;
    });
    if (autoClear != null) {
      _dashboardNoticeTimer = Timer(autoClear, () {
        _dashboardNoticeTimer = null;
        if (!mounted) return;
        setState(() {
          _dashboardNotice = null;
          _dashboardNoticeRetry = null;
        });
      });
    }
  }

  void _clearDashboardNotice() {
    _dashboardNoticeTimer?.cancel();
    _dashboardNoticeTimer = null;
    if (!mounted ||
        (_dashboardNotice == null && _dashboardNoticeRetry == null)) {
      _dashboardNotice = null;
      _dashboardNoticeRetry = null;
      return;
    }
    setState(() {
      _dashboardNotice = null;
      _dashboardNoticeRetry = null;
    });
  }

  /// TRY AGAIN on the failed-auto-claim notice.
  void _retryDailyClaim() {
    _clearDashboardNotice();
    unawaited(_claimDailyEntries());
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
  // State machine (port of AvafliExperienceViewModel)
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
        Avafli.markOptedOut();
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
        AvafliV2ImageWarmer.prewarm(response.giveaway!.prizeImageUrl);
      }
      backendClaimedToday = response.claimedToday;
      backendStreakDay = response.streakDay;
      _backendMonthlyCurrent = response.monthlyCurrent;
      _backendWeeklyCurrent = response.weeklyCurrent;
      _backendTotalEntries = response.totalEntries;

      // Soft email verification: ONLY an explicit false is "unverified".
      // Absent/null (verified, partner-passed, adoption-verified, no email)
      // clears the nudge.
      _unverified = response.emailVerified == false;

      // Adoption re-entry (2.9): remember the freshest pending-adoption
      // signal; the email gate below routes to the re-staged code screen.
      _backendAdoptionPending = response.adoptionPending;

      // Backend is the source of truth for email consent. If it confirms an
      // email on file, seed the local "submitted" flag so a user whose local
      // flag was lost (e.g. reinstall) isn't re-prompted for email.
      if (response.emailConsentStatus) {
        await storage.setBool(StorageKeys.emailConfirmed, true);
      }
    } catch (e) {
      // Session expired: the network client already tried the refresh-token
      // path and it failed — a dedicated retryable state, because every
      // subsequent call (claim included) would bounce the same way.
      if (e is AvafliException && e.error == AvafliError.authenticationFailed) {
        Logger.instance.error('Session expired during load', e);
        _setPhase(_V2Phase.sessionExpired);
        return;
      }
      // Geo-blocked: the person needs to know WHY (US-only), not a generic
      // "check back soon".
      if (e is AvafliException && e.error == AvafliError.geographyNotAllowed) {
        Logger.instance.info('Load blocked by geography');
        _setPhase(_V2Phase.geoBlocked);
        return;
      }
      // Everything else — offline fallback: use cached giveaway. NOTE: the
      // backend's raw text (serverMessage) is for logs only, never the UI.
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
      // Adoption re-entry (2.9): the person typed an existing email last
      // time but never entered the 6-digit code. Instead of restarting at
      // email capture, re-stage the adoption (fresh code) and pick up on the
      // code screen. Falls back to capture when the restage fails.
      final adoptionPending = _backendAdoptionPending ?? widget.adoptionPending;
      if (adoptionPending == true) {
        await _restageAdoption();
        return;
      }
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
      final predicted = AvafliV2Ladder.entries(
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
      if (result.error == AvafliError.ineligibleToday && stored != null) {
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

    setState(() {
      _isSubmittingEmail = true;
      _emailSubmitError = null;
    });
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
            _isRestagedAdoption = false;
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
      // NOTE: we deliberately do NOT persist the raw email locally
      // (PII-High) — the backend stores it encrypted. The non-PII "email
      // submitted" flag is persisted ONLY NOW, after the backend accepted
      // the submit. Persisting it up-front left a failed submit looking
      // complete forever: the capture gate never showed again while every
      // claim bounced off the backend consent gate.
      await widget.preferencesStorage.setBool(StorageKeys.emailConfirmed, true);

      // A user who just typed a BRAND-NEW email comes back unverified — flip
      // the nudge on now so the chip is there the instant the dashboard mounts
      // (the subsequent reload's status response will confirm it). Only an
      // explicit false counts; absent/null (e.g. a partner-passed address)
      // leaves the person verified.
      _unverified = response.emailVerified == false;

      // The backend now holds a confirmed email + consent for this user, but
      // Avafli's cached copy of that flag is only ever refreshed by
      // getActiveGiveaway. Mark it here too so nothing downstream (notably
      // the unregistered auto-open impression cap) keeps treating a
      // just-registered user as unregistered until the next refresh lands.
      Avafli.markEmailConsentGranted();
      Logger.instance.debug('Email submitted to backend');
    } catch (e) {
      Logger.instance.error('Email submit to backend failed', e);
      if (!mounted) return;
      if (e is AvafliException && e.error == AvafliError.geographyNotAllowed) {
        setState(() {
          _isSubmittingEmail = false;
          _phase = _V2Phase.geoBlocked;
        });
        return;
      }
      // Stay ON the capture screen with an inline, retryable error — never
      // proceed as if the submit worked, and never surface the backend's
      // raw text.
      setState(() {
        _isSubmittingEmail = false;
        _emailSubmitError = AvafliV2Strings.emailSubmitFailed;
      });
      return;
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

      Avafli.syncClaimedToday(true);
      await Avafli.persistClaimedToday(widget.preferencesStorage);

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
      Avafli.syncClaimedToday(true);
      await Avafli.persistClaimedToday(widget.preferencesStorage);

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
      _dashboardNoticeTimer?.cancel();
      _dashboardNoticeTimer = null;
      setState(() {
        _streakState = updatedStreak;
        _claimedToday = true;
        _grant = grant;
        _entriesToday = grant.baseEntries;
        _pendingRevealGrant = grant;
        _preClaimTotalEntries = response.totalEntries - grant.total;
        _phase = _V2Phase.streak;
        _isClaiming = false;
        // A retried claim just landed — retire any failure notice.
        _dashboardNotice = null;
        _dashboardNoticeRetry = null;
      });
      // Safety net: if no prediction was staged pre-mount (e.g. the status
      // fetch was offline), the mount found nothing pending — fire the
      // reveal now. No-op when the reveal already played.
      _armCelebrationReveal();
    } catch (e) {
      _isClaiming = false;

      // Session expired mid-claim (refresh already failed inside the network
      // client) — the dedicated retryable state, same as during load.
      if (e is AvafliException && e.error == AvafliError.authenticationFailed) {
        Logger.instance.error('Session expired during claim', e);
        _setPhase(_V2Phase.sessionExpired);
        return;
      }
      // Geo-blocked mid-claim — dedicated US-only messaging.
      if (e is AvafliException && e.error == AvafliError.geographyNotAllowed) {
        Logger.instance.info('Claim blocked by geography');
        _setPhase(_V2Phase.geoBlocked);
        return;
      }

      final isAlreadyClaimed =
          (e is AvafliException && e.error == AvafliError.ineligibleToday) ||
              e.toString().contains('Already claimed');

      // "Already claimed" means the user already got their entries today —
      // another device beat us between the status fetch and the claim. For an
      // auto-claim this isn't news worth celebrating: show the dashboard in
      // its claimed state and re-load ONCE to pull the authoritative totals.
      // Local state DIDN'T know (we only claim when we believe today is
      // open), so tell the person why nothing new was granted — a transient
      // notice, not a modal.
      if (isAlreadyClaimed) {
        Logger.instance.info('Already claimed today — updating local state');
        final updatedStreak = streak.copyWith(lastClaimedDate: DateTime.now());
        await widget.preferencesStorage.saveStreakState(updatedStreak);
        Avafli.syncClaimedToday(true);
        await Avafli.persistClaimedToday(widget.preferencesStorage);
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
        _showDashboardNotice(
          AvafliV2Strings.alreadyEnteredToday,
          autoClear: _noticeAutoClear,
        );
        // One-shot: never loop if status + claim keep disagreeing.
        if (!_didResyncAfterAlreadyClaimed) {
          _didResyncAfterAlreadyClaimed = true;
          unawaited(_load());
        }
        return;
      }

      // Transport-level auto-claim failure: the dashboard shows the HONEST
      // unclaimed state — never a fabricated local success — plus a
      // non-blocking notice with a retry affordance so the person isn't left
      // believing today's entry landed.
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
      _showDashboardNotice(
        AvafliV2Strings.entryNotRecorded,
        onRetry: _retryDailyClaim,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Winner prize claim
  // -------------------------------------------------------------------------

  /// Prefill for the claim form (host-app-provided identity) — mirrors iOS
  /// `claimFormPrefill`.
  AvafliPrizeClaimForm get _claimFormPrefill => AvafliPrizeClaimForm(
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
        Avafli.syncClaimedToday(true);
        await Avafli.persistClaimedToday(widget.preferencesStorage);
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

  /// Share step CONTINUE (2.9, post-submit) → the confirmation screen.
  void _winnerShareDone() {
    if (_phase != _V2Phase.winnerClaim) return;
    setState(() => _winnerClaimStep = _WinnerClaimStep.confirmation);
  }

  /// Attaches the story typed on the post-submit share screen to the
  /// already-submitted claim via `attachClaimStory`. Fire-and-forget with
  /// ONE retry: the claim is already banked, so a failure must never block
  /// the flow or surface an error — logged only.
  void _attachClaimStory(String story) {
    final trimmed = story.trim();
    if (trimmed.isEmpty) return;
    unawaited(() async {
      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          final response = await widget.networkClient
              .send(AttachClaimStoryRequest(story: trimmed));
          Logger.instance
              .debug('Claim story attached (saved: ${response.saved})');
          return;
        } catch (e) {
          Logger.instance.info('attachClaimStory attempt $attempt failed: $e');
          if (attempt == 1) {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        }
      }
    }());
  }

  /// SUBMIT on the claim form. Success → the share/celebrate step (2.9 —
  /// the claim is banked first, so closing share loses nothing). A backend
  /// "Not the winner"/"Already submitted" rejection falls back to the normal
  /// dashboard silently (logged); transport failures surface inline.
  Future<void> _submitPrizeClaim(AvafliPrizeClaimForm form) async {
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
        // 2.9: the story is typed on the POST-submit share screen and rides
        // the dedicated attachClaimStory callable, never this payload.
        promoConsentGranted: form.promoConsentGranted,
      ));
      if (!mounted) return;
      setState(() {
        _isSubmittingClaim = false;
        _submittedClaimForm = form;
        _claimNumber = response.claimNumber;
        _claimSubmittedAt = response.submittedAt;
        // 2.9: celebrate/share AFTER the claim is banked.
        _winnerClaimStep = _WinnerClaimStep.share;
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
          e is AvafliException ? (e.serverMessage ?? e.toString()) : '$e';
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

  /// RETRY on the session-expired state: clear the stale credentials,
  /// re-run the registration handshake, and reload. If the session is still
  /// broken the load lands right back on sessionExpired.
  Future<void> _retrySessionExpired() async {
    _setPhase(_V2Phase.loading);
    try {
      await Avafli.recoverExpiredSession();
    } catch (e) {
      Logger.instance.error('Session recovery failed', e);
    }
    await _load();
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

  /// avafli://delete landed and the webview has popped — raise the
  /// destructive confirmation over whatever SDK screen is behind it.
  void _presentOptOutFlow() {
    if (!mounted || _showsOptOutFlow) return;
    setState(() => _showsOptOutFlow = true);
  }

  /// Close the whole experience (X buttons / GOT IT on the dashboard):
  /// slide the drawer down + fade the dim, then pop with the grant (if any).
  Future<void> _requestDismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    // Distinguishes a user-tapped close from the route being destroyed by
    // host navigation (which must NOT consume the once-a-day auto-open).
    Avafli.noteUserDismissedExperience();
    setState(() => _drawerAppeared = false);
    // Must outlast the 450ms AnimatedSlide below — the route has no exit
    // transition of its own, so popping early freezes the sheet mid-slide.
    await Future.delayed(const Duration(milliseconds: 470));
    if (!mounted) return;
    Navigator.of(context).pop(_grant);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final latestWinner = _giveaway?.latestWinner;
    // THEME ISOLATION: the drawer renders inside the HOST app's MaterialApp, so
    // the host's InputDecorationTheme bleeds into every SDK TextField — a host
    // with filled/rounded inputs (Skape does this) painted a second white pill
    // inside our code-entry box. The SDK styles all of its inputs explicitly,
    // so reset input theming to the framework default at the experience root.
    // AvafliV2ExperienceScope: the in-app legal webview (avafli_v2_legal.dart)
    // is pushed as a route OUTSIDE this subtree, so its openers capture the
    // delete-confirmation presenter from the tapped link's context here.
    // 2.9.5 (iOS/web parity): on avafli://delete the webview pops FIRST, then
    // this presents AvafliV2OptOutFlow over the drawer — cancel returns the
    // user to the SDK screen they came from, not the privacy page.
    return AvafliV2ExperienceScope(
      presentDeleteConfirmation: _presentOptOutFlow,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(),
        ),
        child: Scaffold(
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
                    curve: _drawerAppeared
                        ? Curves.easeOutCubic
                        : Curves.easeInCubic,
                    child: SizedBox(
                      height: constraints.maxHeight * 0.90,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(30)),
                        child: ColoredBox(
                          color: AvafliV2Colors.gunmetal,
                          child: _drawerContent(),
                        ),
                      ),
                    ),
                  ),
                  if (_showWinnerModal && latestWinner != null)
                    AvafliV2WinnerModal(
                      accent: _accent,
                      winner: latestWinner,
                      onDismiss: () => setState(() => _showWinnerModal = false),
                    ),
                  // The delete-my-data confirmation (2.9.5): presents over
                  // the whole drawer once the privacy webview has closed.
                  // Avafli.optOut throws on failure, so the confirmation can
                  // show an honest error instead of pretending success; on
                  // success it holds the deleted copy, then the entire
                  // experience dismisses.
                  if (_showsOptOutFlow)
                    Positioned.fill(
                      child: AvafliV2OptOutFlow(
                        optOutAction: Avafli.optOut,
                        onCancel: () =>
                            setState(() => _showsOptOutFlow = false),
                        onDeleted: () {
                          setState(() => _showsOptOutFlow = false);
                          unawaited(_requestDismiss());
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
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
      final response = await widget.networkClient
          .send(VerifyAdoptionCodeRequest(code: code));
      if (response.adopted && response.token != null && response.uuid != null) {
        await widget.secureStorage.saveAuthToken(response.token!);
        if (response.refreshToken != null) {
          await widget.secureStorage.saveRefreshToken(response.refreshToken!);
        }
        await widget.secureStorage.saveUserUuid(response.uuid!);
        widget.networkClient.setAuthToken(response.token!);
        Logger.instance
            .info('Adoption verified — streak unified across devices');
      }
      // The email flow is only now truly complete — persist the non-PII
      // "email submitted" flag here, not at submit time (see _submitEmail).
      await widget.preferencesStorage.setBool(StorageKeys.emailConfirmed, true);
      Avafli.markEmailConsentGranted();
      // The pending adoption (if this code screen was a 2.9 re-stage) is now
      // resolved — clear every cached copy so future opens don't re-stage.
      _backendAdoptionPending = false;
      Avafli.clearAdoptionPending();
      if (mounted) {
        setState(() {
          _pendingVerificationEmail = null;
          _isRestagedAdoption = false;
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
          _codeError = _codeErrorFor(e);
        });
      }
    }
  }

  /// Map an adoption-code failure to fixed UI copy (never raw backend text).
  /// The backend surfaces a distinguishable reason in the exception's server
  /// message (verifyAdoptionCode returns invalid-argument/permission-denied
  /// whose text mentions "expired" or "attempts"); a three-way taxonomy —
  /// expired / too-many-attempts / incorrect — mirrors the web SDK exactly.
  String _codeErrorFor(Object e) {
    final message =
        e is AvafliException ? (e.serverMessage ?? e.toString()) : e.toString();
    final lower = message.toLowerCase();
    if (lower.contains('expired')) return AvafliV2Strings.codeExpired;
    if (lower.contains('attempts')) return AvafliV2Strings.codeTooManyAttempts;
    return AvafliV2Strings.codeIncorrect;
  }

  /// Adoption re-entry (2.9): re-stages an INTERRUPTED verification-gated
  /// adoption. Asks the backend to send a fresh 6-digit code to the email on
  /// the pending adoption (the SDK never persisted the raw address), then
  /// shows the code screen with the "pick up where you left off" copy. Any
  /// failure — or a backend that says nothing is pending after all — falls
  /// back to the normal email-capture screen.
  Future<void> _restageAdoption() async {
    try {
      final response =
          await widget.networkClient.send(RestageAdoptionRequest());
      if (!mounted) return;
      if (response.sent) {
        Logger.instance
            .info('Adoption re-staged — fresh code sent, showing code entry');
        setState(() {
          _isRestagedAdoption = true;
          _pendingVerificationEmail = null;
          _codeError = null;
          _phase = _V2Phase.codeEntry;
        });
        return;
      }
      // Backend reports nothing pending after all — clear the stale flag and
      // take the normal capture path.
      _backendAdoptionPending = false;
      Avafli.clearAdoptionPending();
      _setPhase(_V2Phase.emailCapture);
    } catch (e) {
      Logger.instance
          .info('restageAdoption failed — falling back to email capture: $e');
      _setPhase(_V2Phase.emailCapture);
    }
  }

  /// Request a fresh code by re-submitting the ORIGINAL email + consents. The
  /// CODE-entry screen STAYS UP throughout: a failed resend surfaces in the
  /// code-error slot instead of dumping the user back on email capture with
  /// no explanation (mirrors the web SDK's resendVerificationCode).
  ///
  /// In the 2.9 re-staged mode there is no locally-held email, so the resend
  /// goes through `restageAdoption` again instead.
  Future<void> _resendVerificationCode() async {
    if (_phase != _V2Phase.codeEntry ||
        _isVerifyingCode ||
        _isSubmittingEmail) {
      return;
    }
    if (_isRestagedAdoption) {
      setState(() {
        _isSubmittingEmail = true;
        _codeError = null;
      });
      try {
        await widget.networkClient.send(RestageAdoptionRequest());
        if (mounted) setState(() => _isSubmittingEmail = false);
      } catch (e) {
        Logger.instance.error('Adoption re-stage resend failed', e);
        if (mounted) {
          setState(() {
            _isSubmittingEmail = false;
            _codeError = AvafliV2Strings.codeResendFailed;
          });
        }
      }
      return;
    }
    final email = _pendingVerificationEmail;
    if (email == null) return;
    setState(() {
      _isSubmittingEmail = true;
      _codeError = null;
    });
    try {
      // Re-submitting the ORIGINAL consent values is idempotent (same person,
      // same choices) and re-triggers the code send. Fabricating values here
      // would overwrite the marketing choice the person actually made.
      final response = await widget.networkClient.send(SubmitEmailRequest(
        email: email,
        ageConfirmed: _pendingAgeConfirmed,
        marketingConsent: _pendingMarketingConsent,
        publisherUserId: widget.configuration.user.id,
      ));
      if (!mounted) return;
      if (response.verificationRequired) {
        // Fresh code sent — stay on the code screen, ready for input.
        setState(() => _isSubmittingEmail = false);
        return;
      }
      // Verification is no longer required (e.g. the merge already
      // completed) — proceed exactly like a plain successful submit.
      if (response.adopted && response.token != null && response.uuid != null) {
        await widget.secureStorage.saveAuthToken(response.token!);
        if (response.refreshToken != null) {
          await widget.secureStorage.saveRefreshToken(response.refreshToken!);
        }
        await widget.secureStorage.saveUserUuid(response.uuid!);
        widget.networkClient.setAuthToken(response.token!);
      }
      await widget.preferencesStorage.setBool(StorageKeys.emailConfirmed, true);
      Avafli.markEmailConsentGranted();
      if (mounted) {
        setState(() {
          _pendingVerificationEmail = null;
          _isSubmittingEmail = false;
          _phase = _V2Phase.loading;
        });
        await _load(claimBeforeDashboard: true);
      }
    } catch (e) {
      Logger.instance.error('Resend verification code failed', e);
      if (mounted) {
        // Stay on the code screen; surface the failure in the code-error slot.
        setState(() {
          _isSubmittingEmail = false;
          _codeError = AvafliV2Strings.codeResendFailed;
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // Soft email verification (dashboard chip → dismissible code screen)
  // -------------------------------------------------------------------------

  /// Open the dismissible verification screen from the dashboard chip.
  void _openEmailVerify() {
    if (_phase != _V2Phase.streak) return;
    setState(() {
      _emailVerifyError = null;
      _phase = _V2Phase.emailVerify;
    });
  }

  /// Back arrow / cancel — this flow gates nothing, so we simply return to the
  /// dashboard with the chip still there.
  void _cancelEmailVerify() {
    if (_phase != _V2Phase.emailVerify) return;
    setState(() {
      _emailVerifyError = null;
      _phase = _V2Phase.streak;
    });
  }

  /// Confirm the soft email-verification code. On success the chip disappears
  /// and a brief "Email verified ✓" notice shows on the dashboard. On failure
  /// the code screen STAYS UP with the same three-way error copy the adoption
  /// flow uses — nothing about play is affected either way.
  Future<void> _confirmEmailVerification(String code) async {
    if (_isVerifyingEmail) return;
    setState(() {
      _isVerifyingEmail = true;
      _emailVerifyError = null;
    });
    try {
      final response = await widget.networkClient
          .send(ConfirmEmailVerificationRequest(code: code));
      if (!mounted) return;
      if (response.verified) {
        Logger.instance.info('Email verified');
        widget.configuration.options.analyticsAdapter
            ?.track('winr_email_verified', const {});
        setState(() {
          _unverified = false;
          _isVerifyingEmail = false;
          _emailVerifyError = null;
          _phase = _V2Phase.streak;
        });
        _showDashboardNotice(
          AvafliV2Strings.emailVerifiedNotice,
          autoClear: _noticeAutoClear,
        );
        return;
      }
      // A non-throwing, unverified response (defensive) — treat as a mismatch.
      setState(() {
        _isVerifyingEmail = false;
        _emailVerifyError = AvafliV2Strings.codeIncorrect;
      });
    } catch (e) {
      Logger.instance.error('Email verification code check failed', e);
      if (!mounted) return;
      setState(() {
        _isVerifyingEmail = false;
        _emailVerifyError = _codeErrorFor(e);
      });
    }
  }

  /// Request a fresh verification code. The code screen STAYS UP throughout: a
  /// failed resend surfaces inline (same as the adoption resend fix), never
  /// stranding the user.
  Future<void> _resendEmailVerification() async {
    if (_phase != _V2Phase.emailVerify || _isVerifyingEmail) return;
    setState(() => _emailVerifyError = null);
    try {
      await widget.networkClient.send(ResendEmailVerificationRequest());
      // Success (or a benign already-sent) — stay on the code screen, ready
      // for input. Nothing else to do.
    } catch (e) {
      Logger.instance.error('Resend email verification code failed', e);
      if (!mounted) return;
      setState(() => _emailVerifyError = AvafliV2Strings.codeResendFailed);
    }
  }

  Widget _drawerContent() {
    switch (_phase) {
      case _V2Phase.loading:
        return const AvafliV2LoadingView();

      case _V2Phase.noActiveGiveaway:
      case _V2Phase.error:
        // Nothing to pitch (or opted out / errored) — quiet empty state.
        // Raw backend text (AvafliException.serverMessage / displayMessage)
        // is never rendered; unknown errors always land here.
        return AvafliV2EmptyStateView(
            accent: _accent, onClose: _requestDismiss);

      case _V2Phase.geoBlocked:
        return AvafliV2GeoBlockedView(
            accent: _accent, onClose: _requestDismiss);

      case _V2Phase.sessionExpired:
        return AvafliV2SessionExpiredView(
          accent: _accent,
          onRetry: () => unawaited(_retrySessionExpired()),
          onClose: _requestDismiss,
        );

      case _V2Phase.codeEntry:
        return AvafliV2CodeEntryView(
          accent: _accent,
          logoUrl: _logoUrl,
          rulesUrl: _rulesUrl,
          email: _pendingVerificationEmail ?? '',
          isVerifying: _isVerifyingCode,
          errorText: _codeError,
          // Re-staged adoption (2.9): no locally-held email to interpolate —
          // the "pick up where you left off" copy replaces the default.
          subtitle: _isRestagedAdoption
              ? AvafliV2Strings.adoptionRestagedSubtitle
              : null,
          onSubmit: (code) => unawaited(_submitVerificationCode(code)),
          onResend: () => unawaited(_resendVerificationCode()),
          onInfo: _showHowItWorks,
          onClose: _requestDismiss,
        );

      case _V2Phase.emailVerify:
        // Reuses the SAME 6-digit code widget as adoption — only the copy, the
        // callables, and the (dismissible) back arrow differ.
        return AvafliV2CodeEntryView(
          accent: _accent,
          logoUrl: _logoUrl,
          rulesUrl: _rulesUrl,
          email: '',
          isVerifying: _isVerifyingEmail,
          errorText: _emailVerifyError,
          title: AvafliV2Strings.emailVerifyTitle,
          subtitle: AvafliV2Strings.emailVerifySubtitle,
          showsBack: true,
          onBack: _cancelEmailVerify,
          onSubmit: (code) => unawaited(_confirmEmailVerification(code)),
          onResend: () => unawaited(_resendEmailVerification()),
          onInfo: _showHowItWorks,
          onClose: _requestDismiss,
        );

      case _V2Phase.emailCapture:
        return AvafliV2CaptureView(
          accent: _accent,
          logoUrl: _logoUrl,
          rulesUrl: _rulesUrl,
          giveaway: _giveaway,
          isSubmitting: _isSubmittingEmail,
          submitError: _emailSubmitError,
          marketingConsentText:
              widget.sdkConfig?.copy?.resolvedEmailConsentText,
          ageGateText: widget.sdkConfig?.resolvedAgeGateText,
          prefilledEmail: widget.configuration.user.email,
          onSubmit: (email,
                  {required ageConfirmed, required marketingConsent}) =>
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
        // imperceptible beat — avafliV2MountRevealDelay). Without the
        // claimedToday clause there's a flash of the raw post-claim server
        // state during the network round-trip, and elements flip at
        // different times.
        final preReveal =
            !_claimRevealed && (_pendingRevealGrant != null || !_claimedToday);
        // A staged celebration counts up to the PREDICTED post-claim total —
        // the real claim response reconciles this silently (normally a
        // no-op, since AvafliV2Ladder mirrors the backend's math).
        final grant = _pendingRevealGrant;
        final postClaimTotal = (grant != null && _preClaimTotalEntries != null)
            ? _preClaimTotalEntries! + grant.total
            : _streakState?.totalEntriesEarned ?? _backendTotalEntries ?? 0;
        return AvafliV2DashboardView(
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
          notice: _dashboardNotice,
          onNoticeRetry: _dashboardNoticeRetry,
          unverified: _unverified,
          onVerifyTap: _openEmailVerify,
        );

      case _V2Phase.winnerClaim:
        return _winnerClaimContent();

      case _V2Phase.howItWorks:
        return AvafliV2HowItWorksView(
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
  /// (mirrors iOS's easeInOut step animation on `AvafliV2WinnerClaimFlow`).
  Widget _winnerClaimContent() {
    final claim = _prizeClaim;
    if (claim == null) return const AvafliV2LoadingView();

    final Widget step;
    switch (_winnerClaimStep) {
      case _WinnerClaimStep.splash:
        step = AvafliV2WinnerSplashView(
          key: const ValueKey('winner-splash'),
          accent: _accent,
          logoUrl: _logoUrl,
          prizeHeadline: avafliV2StripHeadline(
            claim.prizeDescription,
            claim.prizeValue.toInt(),
          ),
          onContinue: _winnerClaimContinue,
          onClose: _requestDismiss,
        );
      case _WinnerClaimStep.form:
        step = AvafliV2ClaimStepsFlow(
          key: const ValueKey('winner-form'),
          accent: _accent,
          logoUrl: _logoUrl,
          // Names the publisher in the likeness consent (same source as the
          // share line).
          appName: widget.sdkConfig?.appName,
          maskedEmail: claim.maskedEmail,
          initialForm: _claimFormPrefill,
          // Present → the street field offers Google Places address
          // autocomplete; absent → plain typing (current prod behavior).
          placesApiKey: widget.sdkConfig?.placesApiKey,
          isSubmitting: _isSubmittingClaim,
          submitError: _claimSubmitError,
          onSubmit: (form) => unawaited(_submitPrizeClaim(form)),
          onClose: _requestDismiss,
        );
      case _WinnerClaimStep.share:
        step = AvafliV2ClaimShareView(
          key: const ValueKey('winner-share'),
          accent: _accent,
          logoUrl: _logoUrl,
          prizeHeadline: avafliV2StripHeadline(
            claim.prizeDescription,
            claim.prizeValue.toInt(),
          ),
          appName: widget.sdkConfig?.appName,
          shareUrl: widget.sdkConfig?.shareUrl,
          // A typed story is delivered exactly once (DONE or close) and
          // forwarded fire-and-forget — never lost, never blocking.
          onStory: _attachClaimStory,
          onDone: _winnerShareDone,
          onClose: _requestDismiss,
        );
      case _WinnerClaimStep.confirmation:
        step = AvafliV2ClaimConfirmationView(
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
