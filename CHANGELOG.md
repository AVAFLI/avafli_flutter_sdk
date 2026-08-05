# Changelog

## [2.3.3] - 2026-08-05

Three defects found testing the SDK inside a real publisher app.

### Fixed
- **Prize headline no longer overlaps itself.** The prize card's cash lockup
  ("WIN $1,000" over "CASH PRIZE") set `height: 1.0` on the big line — a line
  box exactly `fontSize` tall with NO leading — and then pulled the second
  line up into it with `Transform.translate(offset: Offset(0, -5))`. Inter
  Black's real metrics don't fit a 1.0 line box, so the two lines physically
  collided; the iOS original is safe only because SwiftUI's `VStack(spacing:
  -5)` operates on line boxes that carry natural leading. Both display lines
  now carry real leading (1.15) with no negative offset, and the whole lockup
  shares ONE `FittedBox` so a narrow screen scales both lines by the same
  factor. Same leading fix applied to the wrapping non-cash lockup ("Win a
  $500 Amazon Gift Card").
- **The drawer no longer sits on a spinner for seconds.** It auto-opens ahead
  of its sequential network calls (registerDevice → getActiveGiveaway →
  claim). When the device already has a cached giveaway and streak, the real
  dashboard now paints IMMEDIATELY from that cache and the fresh response
  reconciles silently in place — the same no-replay reconcile the celebration
  staging already used (a celebration staged after the cache render still
  fires exactly once). The email-capture gate is unchanged: an unconsented
  user never sees a cached dashboard.
- **Cold start shows a skeleton, not a bare spinner.** With nothing cached to
  paint, the loading view is now a pulsing block-out of the real layout
  (header, prize card, three streak tiles, come-back bar, pill) in the
  drawer's own colors instead of a centered `CircularProgressIndicator` and
  "Loading…".
- **The prize image arrives with the card instead of popping in after it.**
  The publisher's `prizeImageUrl` (and logo) are now decoded into the image
  cache as soon as the SDK learns the giveaway config — at registration and
  on every refresh, mirroring the iOS GIF prewarm — so the card normally
  paints its art on its first frame. A cold URL fades in over ~200ms against
  the card's dark background rather than flashing, and a broken one falls
  back to the bundled cash hero.
- **A successful email submit now marks the cached email-consent flag
  immediately.** `WINR._cachedEmailConsent` was only ever refreshed by
  `getActiveGiveaway`, so between capture and the next refresh the SDK still
  believed a just-registered user was unregistered. Not reachable today — the
  once-a-day auto-present mark is checked before the unregistered impression
  cap — but the correctness no longer depends on the order of two unrelated
  guards.

## [2.3.0] - 2026-08-04

### Added
- **Winner prize-claim flow (Joe's stepped Figma design)** — when the
  backend marks the user as the drawn winner (`prizeClaim.status ==
  "pending"` on `getActiveGiveaway`), the drawer opens on the winner splash
  instead of the dashboard: CONGRATULATIONS! + prize strip → the stepped
  form over the gold-sparkle backdrop — STEP 1 OF 3 "TELL US ABOUT
  YOURSELF" (names, the LOCKED masked winning email from
  `prizeClaim.maskedEmail` with a generic fallback, optional phone) →
  STEP 2 "WHERE SHOULD WE SEND YOUR PRIZE?" (US address, 50-state dropdown,
  Country locked to United States) → STEP 3 "PLEASE SHARE A LITTLE"
  (optional story + social glyph row; pure-Dart has no share sheet, so the
  glyphs copy the winner line to the clipboard) → review "ALMOST DONE!"
  with the three consent checkboxes PRE-CHECKED (defaults true per the Aug
  2026 CTO decision; unticking any disables SUBMIT) → `submitPrizeClaim`
  (now including `story`) → confirmation with the gold OFFICIAL WINNER card
  (trophy breaking the top border, serif name, "MONTH, YYYY • claimNumber")
  and RETURN TO APP. Progress dots + "STEP N OF 3", back chevron from step
  2, one-direction horizontal slide between steps. NOTE: iOS/Android/web
  run this as 4 steps; Flutter deliberately SKIPS the photo step (this
  package ships no image-picker dependency — pure-Dart) and renumbers to 3,
  rather than showing a step whose only actions are disabled.
  `photoBase64` stays wired in the API for future use. Appears
  automatically; no integration work. The daily auto-claim still fires
  silently while the flow is up, and an already-submitted claim shows the
  normal dashboard.

### Changed
- **First-frame celebration beat, Day 1 AND Day 2+ (unified)** — on a
  claim-day open the dashboard mounts with a grant already staged, so the
  celebration is the first visible frame. Day 2+ stages a PREDICTED grant
  from the pre-claim status (the SDK's ladder math mirrors the backend)
  while the real claim runs in the background and reconciles totals/streak
  silently in place (no second celebration; failures settle back to server
  truth quietly). Day 1's "You're in!" welcome modal is GONE (CTO decision):
  after email submit the claim is awaited while the capture spinner is
  still up, and the dashboard mounts celebrating from the REAL grant —
  count-up 0 → N with burst, Day-1 tile explosion + check + falling
  confetti, toast-first bar headlined "YOU'RE IN!" (Day 2+ keeps "YOU'RE ON
  A ROLL!"; the subline is unchanged), GOT IT closes. The 2.2.0 "CLAIM N
  ENTRIES" tap is gone — nothing to press, the pill reads GOT IT
  throughout.
- **Toast-first come-back bar, new copy** — on celebration opens the bar's
  first visible state is the "YOU'RE ON A ROLL! / Your {N} entries have been
  added automatically." toast; it holds ~2.5s, then slides once to the
  resting come-back pitch. Non-celebration opens rest on the pitch.
- **Reveal-beat tile: confetti-burst explosion + restored check/confetti** —
  the active day tile keeps the breathing glow, drifting confetti field, and
  the small animated check drawing into the icon slot, now topped by a
  one-shot confetti-burst overlay that explodes over the tile (the big-check
  tile-burst asset was rejected and removed). The burst fires only on a
  ready→active flip, never on a same-day reopen.
- **Count-up total with burst** — Total Entries counts up (ease-out) and pops
  a confetti burst as it lands.
- **Prize card — the Delta A/B visuals** — dark and full-bleed: the prize
  image fills the whole card, the streak/total-entries stats sit in a solid
  black strip inside the top edge, and the headline overlays the bottom over
  a black→transparent scrim, in two layouts (A: right-aligned "WIN $1,000 /
  CASH PRIZE" for cash; B: centered "Win a {Prize}" + accent value line
  otherwise).

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
