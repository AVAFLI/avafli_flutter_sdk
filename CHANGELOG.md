## 3.0.1 — 2026-08-28

### Fixed
- Legal-webview RETRY pill now uses the publisher accent color (was hardcoded blue).

### Verified
- Streak data flow audited against the server contract — no changes needed (header, tiles, and come-back bar already render from server truth).

## 3.0.0 — 2026-08-25

**Full brand rename: WINR → Avafli.** This release renames the package, its
entrypoint, and the entire public API. It is published as the NEW pub.dev
package `avafli_sdk`; the old `winr_flutter_sdk` listing will be marked
discontinued (with `avafli_sdk` as its replacement) and receives no further
updates. No feature or behavior changes beyond the rename.

### Migration

| Before (winr_flutter_sdk 2.9.x) | After (avafli_sdk 3.0.0) |
| --- | --- |
| `winr_flutter_sdk: ^2.9.5` in `pubspec.yaml` dependencies | `avafli_sdk: ^3.0.0` |
| `import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';` | `import 'package:avafli_sdk/avafli_sdk.dart';` |
| `WINR.configure(...)`, `WINR.navigatorKey`, `WINR.holdAutoOpen()` / `WINR.releaseAutoOpen()`, `WINR.optOut()`, `WINR.registerPushToken` | `Avafli.` equivalents |
| `WINRConfiguration`, `WINRUser`, `WINROptions`, `WINREnvironment` | `AvafliConfiguration`, `AvafliUser`, `AvafliOptions`, `AvafliEnvironment` |
| `WINRError`, `WINRException` | `AvafliError`, `AvafliException` |
| `WINRPushNotificationManager.instance` | `AvafliPushNotificationManager.instance` |
| `WINRBranding` | `AvafliBranding` |
| Internal `winr_*.dart` / `winr_v2_*.dart` files, `WINRV2*` classes | `avafli_*.dart` / `avafli_v2_*.dart`, `AvafliV2*` |
| Analytics event names `winr_*` (`winr_sdk_configured`, `winr_daily_entry_claimed`, `winr_experience_presented`, …) | `avafli_*` (`avafli_sdk_configured`, `avafli_daily_entry_claimed`, `avafli_experience_presented`, …) — matching iOS/Android/web 3.0; update adapter filters and dashboards keyed on the old names |
| Guest ids minted as `winr_guest_…` | NEW mints are `avafli_guest_…`; ids already stored on a device are returned verbatim — stored identities are never rewritten (and the storage key is unchanged) |

`Avafli.sdkVersion` (and the request-metadata default) now report `3.0.0`.

### Deliberately unchanged — compatibility

- **API keys**: the `winr_live_…` / `winr_test_…` key formats are issued by the
  backend and keep working as-is.
- **Legal webview URLs stay on winrmedia.com** (`https://winrmedia.com/sdk/privacy`
  et al.) — the hosted legal surface has not moved.
- **Delete bridge accepts both schemes**: the privacy page's Delete-my-data
  bridge is intercepted as `winr://delete` (what the hosted page emits today)
  AND `avafli://delete` (the canonical 3.0 scheme), so the page can migrate
  schemes without stranding either SDK generation.
- **On-device state survives the upgrade**: secure-storage keychain account
  (`winr_flutter_sdk`), token/streak storage keys (`winr_*`), and the
  per-bundle SharedPreferences bookkeeping keys are unchanged — upgraded users
  keep their session, streak, and opt-out state.

### User-visible branding

- All user-facing "WINR" copy now reads Avafli: the fallback header wordmark
  (AVAFLI), "Powered by © Avafli", the delete-my-data confirmation copy, error
  messages, and log/analytics console tags.
- Share-link UTM tagging now appends `utm_medium=avafli_share` (was
  `winr_share`) — update any campaign filters keyed on the old value.

## 2.9.5 — 2026-08-18

- **Delete confirmation now presents over the experience after the webview
  closes, matching iOS**: on `winr://delete` the privacy webview pops FIRST,
  then the destructive delete-my-data confirmation presents over the SDK
  drawer — cancel returns to the SDK screen the user came from, not the
  privacy page. Success behavior is unchanged (the deleted copy holds a
  beat, then the whole experience dismisses).
- **Removed the redundant "Privacy choices" link** from the how-it-works
  fine print — the legal-links rows and the capture screen's inline Privacy
  Policy links keep the delete path findable.

## 2.9.4 — 2026-08-18

- **Legal documents open in-app**: Official Rules and the Privacy Policy now
  open inside the experience in a gunmetal legal webview (slim title + X
  header, thin load-progress strip, honest offline state with RETRY) instead
  of bouncing out to the external browser — every legal entry point routes
  there: the capture screen's inline Rules/Privacy spans, the
  dashboard/code-entry "OFFICIAL RULES • PRIVACY POLICY" rows, and the
  how-it-works fine print. The winner share screen's social launches still
  open externally (that's the point of a share). Adds the SDK's ONE new
  dependency: `webview_flutter` (the flutter.dev first-party plugin).
- **"Delete my data" moved inside the privacy page**: the privacy policy
  loads with `?app=1`, under which winrmedia.com/sdk/privacy renders a
  Delete-my-data section; tapping it navigates `winr://delete`, which the
  webview intercepts and hands to the SDK's existing destructive
  confirmation + authenticated erasure (`WINR.optOut`) — same honest
  success/failure states, then the whole experience dismisses. The native
  "Privacy choices" screen is gone; the how-it-works "Privacy choices" fine
  print now opens the privacy webview directly. Unknown `winr://` verbs from
  a newer page build degrade to a dead tap, never a webview error page.
- **Share-link UTM tagging** — when the publisher's `shareUrl` is included
  in a share action, the SDK appends `utm_source={network}&utm_medium=winr_share`
  ({network} = x | facebook | instagram | snapchat | tiktok, per the tapped
  button; clipboard-fallback paths keep their network's value). Built with
  `Uri.replace` so URLs with existing query strings extend correctly, and a
  shareUrl that already carries a `utm_source` param is left untouched
  (publisher tagging wins). Share-text URLs only — nothing else changes.

## 2.9.3 — 2026-08-17

- **Claim review slimmed to Joe's updated frame**: the "By submitting you
  agree to…" sentence and its Official Rules / Privacy Policy links were
  removed from the claim review screen entirely — the screen now keeps only
  the optional likeness checkbox, SUBMIT, and the secure-note. (The capture
  screen's legal sentence and the dashboard/how-it-works legal rows are
  unchanged.)
- **Likeness consent names the publisher**: when the server-fed
  `WinrSdkConfig.appName` is present (the same source the share line uses)
  the checkbox reads "I authorize {name} and its promotional partners to use
  my name, city, profile photo, and likeness for winner announcements and
  promotional purposes. (Optional)"; without it the generic wording is
  unchanged.
- **Winner splash celebration**: the one-shot confetti-burst (the same
  machinery as the Day-2+ streak tile's reveal beat) now explodes over the
  trophy art the moment the splash appears — non-blocking, and removes
  itself when done — with a gold drifting confetti field over the art
  beneath it.
- **Claim confirmation matches Joe's frame**: the confirmation screen now
  celebrates on appearance (gold confetti drift + the same one-shot burst as
  the splash, both non-blocking); the "3-5 Business Days" card is a solid
  gunmetal card with a subtle border and an accent-stroked envelope circle;
  and the winner card's OFFICIAL / WINNER labels render in the publisher's
  primary accent instead of fixed gold. No accent color is ever hardcoded —
  everything derives from the server-fed branding primary.
- **Top glow fully retired**: the accent-blue radial top glow (dropped from
  the capture screen in 2.9.0) is now gone from every screen — the unused
  `WINRV2TopGlow` widget was deleted, and the 6-digit code-entry screen
  (cross-device adoption + email verification) moved off its near-black
  charcoal onto the same flat gunmetal drawer surface as capture and the
  dashboard. The gold-sparkle prize art on the winner-flow screens is
  untouched.
- **Capture screen brand accents**: in "VISIT. EARN. WIN." the word "EARN."
  now renders in the publisher's primary brand color (the same branding
  primary the CTAs use); VISIT. / WIN. stay white. Both capture checkboxes
  (18+ age gate, marketing consent) are tinted the primary too — checked is
  a primary fill with a contrasting check, unchecked a primary-tinted
  border — replacing the old white system-glyph boxes.

## 2.9.2 — 2026-08-14

- **Single legal instance on email capture**: the capture screen's legal
  sentence now carries underlined, tappable "Official Rules" and "Privacy
  Policy" spans (opening the publisher's rules URL externally, exactly as the
  old links row did), and the separate "OFFICIAL RULES • PRIVACY POLICY" row
  was removed from that screen only — other screens keep theirs. The
  "Powered by © WINR Media" line remains.
- **Bottom-anchored capture footer**: the legal sentence and powered-by line
  now anchor to the bottom of the capture screen instead of sitting directly
  under the CTA; on short screens or with the keyboard up the layout degrades
  to normal scrolling with a guaranteed minimum gap below the button.
- **Privacy Policy links open the real policy**: every "Privacy Policy"
  link/span (capture sentence, dashboard and how-it-works legal rows, claim
  consent text, privacy-choices screen) previously opened the publisher's
  rules URL because no privacy URL existed in config. They now open
  https://winrmedia.com/sdk/privacy (new `winrV2PrivacyPolicyUrl` constant,
  mirroring iOS `WINRConstants.privacyURL`). "Official Rules" links keep
  `rulesUrl`.

## 2.9.1 — 2026-08-14

- **Official share icons**: the share screen's social row (Instagram /
  Facebook / X / Snapchat / TikTok) now draws the official WINR brand set —
  the Figma 48×48 white-fill glyphs, rendered in-code from their SVG path
  data via a new dependency-free path painter — replacing the previous
  hand-approximated glyphs. Button sizing and behavior are unchanged.

## 2.9.0 — 2026-08-14

Keyboard-safe forms, a flatter capture screen, a streamlined claim review, a
post-submit share step, a dedicated privacy-choices surface, and adoption
re-entry.

- **Keyboard-safe forms**: every SDK text input (email capture, 6-digit code
  entry, claim fields, share-step story) now ensures the focused field is
  scrolled into view after the keyboard settles, and form scrollables gained
  IME-aware (`viewInsets`) bottom padding — fields are never hidden behind the
  keyboard, even in hosts that don't resize for it.
- **Flat capture background**: the capture screen's accent-blue radial glow is
  replaced with the streak dashboard's flat gunmetal surface for a consistent
  look across the experience.
- **Streamlined claim review**: the accuracy and rules checkboxes are gone
  (rules/privacy remain as tappable links); the only checkbox left is the
  likeness/promo one — optional, unchecked by default, and never gating
  SUBMIT. An explicit `promoConsentGranted` boolean now always rides
  `submitPrizeClaim`.
- **Share step after submit**: the claim form is now 2 steps + review; on
  successful submission a celebration/share screen appears. The winner-story
  textarea lives there and is delivered via the new `attachClaimStory`
  callable (fire-and-forget with one retry, sent exactly once on CONTINUE or
  close) — closing the screen loses nothing.
- **Share actions**: X opens a tweet intent with a prefilled winner line (plus
  the publisher `shareUrl` when configured); Facebook uses the sharer with
  `shareUrl`; Instagram/Snapchat/TikTok (and Facebook without a `shareUrl`)
  copy the winner line to the clipboard with a "Copied — paste it in your
  post" confirmation.
- **Publisher config**: new optional `sdkConfig` fields `shareUrl` and
  `appName`, both null-safe against current production responses.
- **Address autocomplete**: when the backend ships `sdkConfig.placesApiKey`,
  the claim form's Street Address field suggests US addresses via the Google
  Places API (New) — debounced typing shows up to five suggestions (with the
  required "powered by Google" attribution) styled to the V2 dark UI; tapping
  one fills street/city/state/zip, all still hand-editable. Uses the SDK's
  existing `package:http` stack (no new dependencies), stays visible above
  the keyboard, dismisses on outside tap or back, and every failure degrades
  silently to plain typing — autocomplete never blocks entry. No key → the
  field behaves exactly as before.
- **Zip field fix**: the fixed-width zip column was clipping five-digit codes;
  the state/zip row now flex-shares the width with relaxed inner padding.
- **Privacy choices**: DELETE MY DATA moved off "How it works" onto a
  dedicated privacy-choices surface (privacy-policy link + the existing
  delete-my-data confirmation flow); the how-it-works link now opens it.
- **Adoption re-entry**: when register/status responses report a pending
  adoption, the new `restageAdoption` callable re-shows the 6-digit code
  screen with "pick up where you left off" copy; resends re-stage the code,
  success clears the cached flag, and failures fall back to email capture.

## 2.8.2 — 2026-08-14

- `flutter_secure_storage` floor raised to v10 and the removed `encryptedSharedPreferences` flag dropped (Android encryption is always on in v10+; the flag's removal in v11 broke compilation under latest-dependency analysis and zeroed the pub.dev score). Values written by older versions migrate automatically.

## 2.8.1 — 2026-08-13

- Theme isolation: the experience no longer inherits the host app's `InputDecorationTheme`. A host with filled/rounded inputs was painting a second white pill inside the SDK's code-entry box (and could distort any SDK text field).

## 2.8.0 — 2026-08-13

- Version alignment with the 2.8.0 platform release. No functional changes; `environment` already defaulted to `production`, and sandbox API keys (`winr_test_…`) are the supported way to test.

# Changelog

## 2.7.0 — 2026-08-11

2.7.0 — 'Verify your email' soft-verification: a persistent chip on the streak
dashboard lets users confirm a newly-typed email (reusing the code screen);
never blocks daily play, only prize-draw eligibility.

## 2.6.3 — 2026-08-11

2.6.3 — firstName/lastName are now optional on WINRUser; pass only the identity
data you have and the SDK captures the rest (email via the capture screen).

## 2.6.2 — 2026-08-11

Age-gate text honors publisher config; push notifications functional on
Android/web; resend keeps the code screen; error screens pick up publisher
branding.

- **Age-gate compliance**: the capture screen's age checkbox no longer
  hardcodes "18". The SDK now parses the server's `ageGateEnabled`,
  `ageGateMinAge`, and `ageGateText` (nested `copy.emailCapture.ageGateText`,
  then flat `copy.ageGateText`) and renders the publisher's `ageGateText`
  verbatim when present; otherwise it BUILDS "I confirm I am {minAge} years of
  age or older" from `ageGateMinAge` (default 18) — never a hardcoded 18.
- **Resend keeps the code screen up**: requesting a fresh adoption code no
  longer flips back to email capture first, so a failed resend can't strand
  the user there. The code-entry screen stays up throughout; failures surface
  in the inline code-error slot ("Couldn't send a new code…") and the original
  consents are reused.
- **Adoption-code error taxonomy**: code-check failures now map three ways
  from the backend's reason — "expired" → "That code expired…", "attempts" →
  "Too many attempts…", otherwise → "That code didn't match…" — instead of
  collapsing everything to "didn't match".
- **Error-screen branding**: the empty/no-giveaway and geo-blocked screens'
  CLOSE button now uses the publisher accent color instead of WINR blue,
  matching the dashboard and session-expired screens.
- **SDK version string**: `sdkVersion` is now sent as "2.6.2" without a
  leading `v`, matching the iOS/Android/web SDKs (both the constant and the
  request-defaults fallback).

## 2.6.1 — 2026-08-11

In-experience privacy opt-out (delete my data); District of Columbia added to
the prize-claim form.

- **Privacy choices** — the how-it-works ("?") screen gains a muted "Privacy
  choices" link. It raises a destructive confirmation ("Delete my data & stop
  participating"); confirming performs the existing RTD opt-out
  (`WINR.optOut()`), shows "Your data has been deleted.", and dismisses the
  experience. Failure keeps the confirmation up with "Something went wrong.
  Please check your connection and try again." — never a pretended success.
- **District of Columbia** in the prize-claim state dropdown, per the official
  rules' "50 states and the District of Columbia".

## 2.6.0 — 2026-08-10

User-facing error messaging per the Master Field List; honest failure states
— no fabricated claim success.

- **Centralized copy** (`WINRV2Strings`): every user-facing error/notice
  string lives in one file, matching the Master Field List's "User Message
  (UI)" column exactly. Raw backend error text is never rendered.
- **Email capture**: inline "Please enter a valid email address." under the
  field (after it's touched or a submit is attempted). A failed submit now
  keeps the user on capture with "Something went wrong sending your email.
  Please try again." — and the email-confirmed flag is persisted only AFTER
  the backend accepts the submit (previously a failed submit looked complete
  forever).
- **Winner claim form**: first/last name validated (unicode letters, spaces,
  apostrophes, hyphens, periods, max 50) with inline errors; the optional
  phone must normalize to 10 US digits (leading 1 allowed) or CONTINUE is
  blocked with "Please enter a valid 10-digit mobile number."
- **Duplicate same-day entry**: a claim rejected as already-claimed (e.g.
  entered on another device) shows a transient dashboard notice instead of
  silence.
- **Failed auto-claim**: the dashboard shows the honest unclaimed state plus
  "We couldn't record today's entry. Check your connection and try again."
  with a TRY AGAIN affordance — never a fabricated local success.
- **Geo-blocked**: dedicated "Not available in your location" state (US-only
  messaging) instead of the generic empty state.
- **Session expired**: when token refresh AND re-registration fail, a
  dedicated "Your session has expired. Please try again." state with a RETRY
  button that re-registers the device and reloads.

## 2.5.3 — 2026-08-10

Auto-open now survives host boot navigation.

- **Fixed the drawer being destroyed by splash-screen navigation.** Apps that
  boot through a splash and navigate with stack-clearing calls (`Get.offAll`,
  `pushAndRemoveUntil`) destroyed the auto-opened drawer moments after it
  appeared — and the SDK had already burned its once-a-day flag, so it never
  returned that day. The SDK now detects that the route was removed without
  user interaction, refunds the daily flag and unregistered-impression count,
  and retries (up to twice) after the navigation settles.
- **New `WINR.holdAutoOpen()` / `WINR.releaseAutoOpen()`.** Hosts with a boot
  flow can hold the once-a-day auto-open during startup and release it once
  their main screen is mounted, so the drawer always presents over the right
  screen.

## 2.5.2 — 2026-08-10

Presentation polish — fixes a visibly broken dismiss animation.

- **Fixed ghosted cross-fade on dismiss.** The experience route applied its own
  200ms whole-screen fade on top of the widget's 450ms slide-down, and popped
  280ms in — mid-dismiss, the still-visible sheet double-exposed over the host
  app. The route now has no transition of its own; the widget's scrim fade and
  sheet slide run to completion before the pop.
- **Publisher logo no longer pops in.** On a cold open (e.g. auto-open at app
  launch) the header logo could appear a few frames after the drawer. It now
  eases in over 200ms when it wasn't already cached.

## 2.5.1 — 2026-08-10

Consent correctness and cross-device security.

- **Marketing consent checkbox starts UNCHECKED** — consent is an affirmative
  act (pre-ticked boxes are invalid under GDPR and disfavored by US state
  regulators). Declining still blocks nothing.
- **Email pre-fill**: pass your signed-in user's email via `WINRUser.email` and
  the capture screen shows it read-only — the address the user consents for is
  always one they proved to you. Malformed values fall back to the editable
  field.
- **Guest sessions**: no account system, or the user is signed out? Use the
  guest sentinel (or omit the user on web). The SDK mints a stable per-install
  `winr_guest_…` id for attribution; re-configure with the real user later and
  the streak carries over.
- **Verified adoption**: typing an email that already belongs to an existing
  WINR account now requires a 6-digit code sent to that inbox before the
  streak transfers to the new device. Fresh signups and pre-filled partner
  emails never see it.

## [2.5.0] - 2026-08-06

### Breaking

`WINR.deleteUserData()` is **removed**. Use `WINR.optOut()`. The old call
hard-deleted entry records — the evidence a drawing was fair — left no
tombstone so delete-and-re-register farmed entries, and never cleaned
prize-claim PII. `optOut()` is identity-wide and complete.

### Fixed

The example app shipped a placeholder API key and so could never run as
provided.

## [2.4.0] - 2026-08-05

Consent capture, matched across all four WINR SDKs.

### Added
- **Marketing-consent checkbox on the capture screen.** A second checkbox sits
  directly below the 18+ age gate, styled identically to it, reading "I agree
  to receive marketing emails from {PublisherName}" — the backend interpolates
  the publisher's name and sends the finished string as
  `sdkConfig.copy.emailCapture.emailConsentText` (the flat legacy
  `sdkConfig.copy.emailConsentText` is honored as a fallback); with no config
  the SDK falls back to "I agree to receive marketing emails from this app".

  The box governs **marketing email only**. It is **pre-checked**, and
  declining it affects **nothing else**: the CTA stays enabled, the entry is
  submitted normally, and WINR still contacts the user if they win — winner
  contact is operational and no checkbox gates it. The age gate is unchanged —
  still unchecked by default, still the thing that (with a valid email)
  enables the CTA.

### Changed
- **Age confirmation is now transmitted and stored server-side.** `submitEmail`
  previously sent only `{ email, marketingConsent }` with a hardcoded consent
  value; it now sends `{ email, ageConfirmed, marketingConsent }` carrying the
  real state of both checkboxes. `ageConfirmed` is always present — the
  backend keys off it to tell a 2.4.0+ client from a legacy one.
- `WINRV2CaptureView.onSubmit` now takes `(String email, {required bool
  ageConfirmed, required bool marketingConsent})` instead of a bare email
  string. Internal API — publisher integrations are unaffected.

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
