# Changelog

## [2.2.0] - 2026-08-04

- Day 2+ reveal flow (mirrors iOS): the auto-claim still fires silently the
  moment the drawer opens, but returning users no longer get the celebration
  modal. The dashboard holds YESTERDAY's numbers — streak label N-1, pre-claim
  total, today's tile in a new `ready` state (breathing glow + white flame, no
  checkmark, no confetti) — behind a "CLAIM N ENTRIES" pill. Tapping it is the
  reveal: the tile flips to active (draw-on check + confetti), the streak label
  advances, the total counts up to the post-claim value, and the pill becomes
  "GOT IT" (which closes the drawer).
- Day 1 keeps the "You're in!" celebration modal as its reveal, but its GOT IT
  now dismisses the whole experience (previously settled on the dashboard).
- Email-capture CTA renamed "GET MY N ENTRIES" → "CLAIM MY N ENTRIES".
- "Already claimed" cross-device fallback and silent auto-claim failure are
  unchanged (plain dashboard, no reveal).

## [2.1.0] - 2026-08-04

- Removed (BREAKING): manual `WINR.present()` — the experience is exclusively
  auto-opened by the SDK (at most once per calendar day, respecting the server
  kill switch, the unregistered impression cap, and RTD opt-out). Attach
  `WINR.navigatorKey` to your `MaterialApp`; there is no manual launch API.
- README corrections (installation via pub.dev, auto-open-only integration)

## 2.0.0 (2026-08-03)

- V2 experience — full port of the iOS V2 design (WINR-High-V2 Figma):
  - Bottom drawer over the host app (dim backdrop, gunmetal sheet flush to
    bottom/sides, top corners rounded 30, ~90% height, spring slide-up)
  - Email capture ("VISIT. EARN. WIN."), prize-derived white strip, 18+ gate
  - Dashboard: prize card with cash lockup / prize headline, horizontally
    scrolling streak rail (106x134 tiles, active tile glow + confetti +
    draw-on check, "+N EVERY DAY!" accelerator tiles), come-back bar,
    optional "WE HAVE A WINNER!" banner + winner modal
  - Celebration modal (Day-1 "You're in!" vs Day-2+ streak variants,
    looping confetti, animated checkmark; explicit dismiss only)
  - How-it-works with back arrow in header and visit-mode copy variants
- Bundled Inter (400–900) + Oswald (500/700) fonts and Figma image assets
- Auto-open: presents itself on the first app-open of each calendar day
  (attach `WINR.navigatorKey`); respects the server kill switch
  (`sdkConfig.experience.autoOpenEnabled`), the unregistered impression cap
  (default 3), and RTD opt-out
- Auto-claim on open — a successful claim always lands on the celebration;
  "Already claimed" is silent with a one-shot re-load to sync totals
- Ladder math mirrors the backend exactly (milestone accelerators beyond the
  explicit ladder)
- API models: `prizeImageUrl`, `streakMode` (visit mode), `latestWinner`,
  `sdkConfig.experience` flags, richer claim response; new `WINR.optOut()`
- BREAKING: removed the rewarded-video/bonus flow (provider interface,
  `WINROptions.rewardedVideoProvider`, claimBonusEntries), `presentAsCard`,
  and the V1 server-driven copy/media theming; `WINR.present` now returns
  `Future<DailyEntryGrant?>`

## 1.0.0

- Initial release
- Daily streak engagement system (3-tier: base, weekly bonus, monthly bonus)
- Email capture with age gate (13+)
- Rewarded video provider interface (AdMob, AppLovin, IronSource, Unity)
- Push notification support via FCM
- Server-driven SDK config (copy, branding, theme)
- GDPR compliance (deleteUserData)
- Offline resilience (cache claims locally)
- Certificate pinning for Cloud Functions
- Customizable Material 3 UI with dark theme
- Full analytics adapter system
- Geo-fencing support
