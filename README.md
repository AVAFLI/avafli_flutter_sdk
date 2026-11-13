# Avafli SDK for Flutter

**Drop-in daily-streak sweepstakes for your Flutter app.** One `configure()` call and one navigator key; the SDK presents its own bottom drawer, captures the email, grants the day's entries, and runs the winner's prize claim. Branding, prize, ladder and copy are managed from your Avafli dashboard — no app release needed to change them.

[![pub package](https://img.shields.io/pub/v/avafli_sdk.svg)](https://pub.dev/packages/avafli_sdk)
[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-blue.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5%2B-blue.svg?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2013%2B%20%7C%20Android%2024%2B-lightgrey.svg)](#requirements)

- [Requirements](#requirements)
- [Install](#install)
- [Configure](#configure)
- [What the user sees](#what-the-user-sees)
- [Controlling presentation](#controlling-presentation)
- [Push reminders](#push-reminders)
- [Account deletion](#account-deletion)
- [Testing checklist](#testing-checklist)
- [API reference](#api-reference)

## Requirements

| | Minimum |
| --- | --- |
| Flutter / Dart | Flutter 3.24, Dart 3.5 |
| iOS | 13.0 (floor of the bundled `webview_flutter`, `image_picker` and `url_launcher` plugins) |
| Android | `minSdk 24` (floor of the bundled `flutter_secure_storage`, `webview_flutter` and `shared_preferences` plugins) |
| App shell | A `MaterialApp` (or `GetMaterialApp` / `MaterialApp.router`) whose **root** navigator key the SDK can use — see [Configure](#configure) |
| API key | From your [Avafli dashboard](https://sdk.avafli.com/dashboard): `avafli_live_…` for release builds, `avafli_test_…` for everything else. No account yet? Start at [sdk.avafli.com/pricing](https://sdk.avafli.com/pricing). |

Platform setup in your host app (both are already in `example/`):

- **iOS `Info.plist`** — the prize-claim photo step uses `image_picker`, so add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` (iOS requires them for any binary that links the picker).
- **Android `AndroidManifest.xml`** — `<uses-permission android:name="android.permission.INTERNET"/>` in your **main** manifest (Flutter's template only grants it in the debug/profile manifests).

The SDK ships its own fonts, icons and images; nothing else to add to `pubspec.yaml`.

## Install

```yaml
dependencies:
  avafli_sdk: ^3.3.1
```

```bash
flutter pub get
```

```dart
import 'package:avafli_sdk/avafli_sdk.dart';
```

> A git dependency on [AVAFLI/avafli_flutter_sdk](https://github.com/AVAFLI/avafli_flutter_sdk) also works if you need an unreleased revision.

## Configure

This is the whole integration. Copy it as-is: `main()`, `Avafli.configure(...)`, and a `MaterialApp` that carries `Avafli.navigatorKey`.

```dart
import 'package:avafli_sdk/avafli_sdk.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mount the app FIRST so the navigator below exists by the time the SDK
  // wants to open — then configure. (Configuring from your root widget's
  // initState works just as well.)
  runApp(const MyApp());

  await Avafli.configure(AvafliConfiguration(
    // Release builds hit your real giveaway; every other build hits your
    // isolated sandbox — same backend, same behaviour, never your real draw.
    apiKey: kReleaseMode
        ? 'avafli_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
        : 'avafli_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    bundleId: 'com.example.myapp', // exactly as registered in your dashboard
    user: AvafliUser(id: 'user_123'), // your stable user id — or AvafliUser.guest
    options: AvafliOptions(
      logging: kReleaseMode ? LoggingLevel.error : LoggingLevel.debug,
    ),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // REQUIRED. The drawer is pushed through this navigator. Without it the
      // SDK logs "Avafli.navigatorKey not attached" and never appears.
      navigatorKey: Avafli.navigatorKey,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Your app')));
  }
}
```

From here the SDK registers the device (every launch, every mode — this is the DAU/MAU heartbeat) and opens the drawer **at most once per calendar day** on the first app-open of the day. `configure()` resolves `true` on success and `false` (after logging) if initialisation threw; it never throws.

### Pass the identity you have

Only `id` is required. The SDK captures the email on its own screen and the name at prize-claim time.

```dart
// Signed-in user, no email on file (the common case — the SDK captures one):
user: AvafliUser(id: 'user_123', firstName: 'Jane', lastName: 'Doe')

// Signed-in user with an email: the capture field is pre-filled and LOCKED
// (consent is still an explicit tick inside the flow):
user: AvafliUser(id: 'user_123', email: 'jane@example.com')

// Nobody signed in: the SDK mints a stable per-install guest id
// (`avafli_guest_…`). Call configure() again with the real user after sign-in
// and attribution upgrades in place; the streak is device-anchored and stays.
user: AvafliUser.guest
```

`firstName` / `lastName` must match `^[a-zA-Z '-]{1,50}$` and `phone` must normalise to a 10-digit US number — anything else is dropped silently (they are optional).

### Your app already has a navigator key

`Avafli.navigatorKey` is an assignable static. Hand it your existing **root** key before `configure()` instead of changing your `MaterialApp`:

```dart
final rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Avafli.navigatorKey = rootNavigatorKey; // before configure()
  runApp(MaterialApp(navigatorKey: rootNavigatorKey, home: const HomeScreen()));
  await Avafli.configure(/* ... */);
}
```

The SDK pushes with `rootNavigator: true`, so the key must be the root navigator's — a nested navigator (a tab shell, a `ShellRoute`) will not do.

### GetX, GoRouter, auto_route and splash screens

Give the router the SDK's key as its root navigator key (or assign your own root key to `Avafli.navigatorKey` as above):

```dart
// GetX
GetMaterialApp(navigatorKey: Avafli.navigatorKey, home: const SplashScreen());

// GoRouter — the key goes on the router, not on MaterialApp.router
final router = GoRouter(navigatorKey: Avafli.navigatorKey, routes: [/* ... */]);
MaterialApp.router(routerConfig: router);

// auto_route — construct your generated router with the SDK's key
final appRouter = AppRouter(navigatorKey: Avafli.navigatorKey);
MaterialApp.router(routerConfig: appRouter.config());
```

**If your boot flow clears the navigation stack** (`Get.offAll`, `context.go` from a splash, `Navigator.pushAndRemoveUntil`, an auth gate), that navigation can destroy the drawer the instant it auto-opens. The SDK detects a drawer removed within 5 seconds without a user tap, refunds the day and retries twice — but the right fix is to tell it to wait:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Avafli.holdAutoOpen(); // BEFORE configure: nothing is burned while held
  runApp(const MyApp());
  await Avafli.configure(/* ... */);
}

// In the screen your boot flow lands on (after Get.offAll / go('/home')):
class HomeScreen extends StatefulWidget { /* ... */ }

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Releases the hold and opens right away if today's drawer is due.
    WidgetsBinding.instance.addPostFrameCallback((_) => Avafli.releaseAutoOpen());
  }
  // ...
}
```

`releaseAutoOpen()` is safe to call repeatedly and before `configure()`. `Avafli.present()` ignores the hold.

### Sandbox key vs live key

Your dashboard shows two keys. Both hit the **same production backend** with identical behaviour — registration, streaks, entries, the full drawer — but `avafli_test_…` lands every device and entry in a separate sandbox tenant with its own always-active test giveaway:

- Developers, testers and CI can never enter (or win) your real giveaway.
- Sandbox usage never counts toward your MAU or your bill.
- Your registered bundle IDs work with both keys.

Swap the key per build configuration (the `kReleaseMode` ternary above) and nothing else changes. Keys minted before the Avafli rename carry an older prefix and remain valid.

## What the user sees

Everything below is built into the drawer. There is no host-app code for any of it.

**Day 1 — email capture.** The drawer opens on "VISIT. EARN. WIN." with the prize, an email field, an **age-gate tick** (the publisher's configured minimum age, default 18; the tick gates the button) and a **marketing-consent checkbox that is unchecked by default and never gates entry**. Official Rules and the Privacy Policy are tappable in the fine print and open in an in-app webview. Submitting claims Day 1 and lands on the dashboard celebrating — the day tile checks off with confetti, the total counts up, the bar reads "YOU'RE IN!", the pill reads GOT IT. Nothing to tap to collect entries.

- If the typed email already belongs to an existing Avafli account (another device or app), the SDK asks for a **6-digit code** emailed to that address before linking the streak to this device.
- A never-before-seen email gets a dismissible **"Verify your email"** chip on the dashboard. It never blocks play or the draw; confirming early means no code step if they win.
- Until an email is on file, the auto-open shows at most **3 times** (server-configurable `unregisteredImpressionCap`), then stays quiet until the person registers or you call `present()`.

**Day 2 onward — auto-claim.** The drawer opens once per day, claims that day's entries silently and celebrates ("YOU'RE ON A ROLL!"). Entries follow the giveaway's ladder from your dashboard; the built-in default is 10 → 30 → 60 → 130 → 240 → 300 → 500 for days 1–7, plus any milestone accelerators ("+25 EVERY DAY!" tiles). A missed day resets a daily streak to Day 1; a giveaway in **visit mode** counts visits and never resets. A claim that already happened on another device shows a short notice instead of a second grant. A claim that fails on the network is queued and retried the same day on resume / next launch (capped backoff, at most 5 attempts per session); the server dedups, so a retry can never double-grant.

**Winner.** When the person is drawn, the drawer opens on "WE HAVE A WINNER!" instead of the dashboard. CONTINUE goes to a 6-digit email-ownership code when the backend asks for one (people whose inbox is already proven skip it), then a 3-step claim form — about you, US shipping address (50 states + DC, with address autocomplete when the platform ships a Places key in `sdkConfig`), optional photo — a review screen with an optional likeness-consent tick, and a confirmation with their claim number and a share step. The claim is open for the giveaway's **claim window: 3 days (72 hours) from the winner notification by default**, configurable per giveaway from 1 to 60 days by Avafli; once it has passed the backend refuses the claim and the drawer simply closes. While a claim is pending the drawer re-opens on every cold start and at most every 30 minutes on foreground, regardless of the once-a-day rule — see [Controlling presentation](#controlling-presentation).

**Shared giveaway.** If you opt your app into the shared giveaway (one prize pool across many Avafli apps, Avafli LLC as Sponsor of Record), the served `Giveaway` carries `scope: "network"` and a `sponsorDisclosure` ("Sponsored by Avafli LLC") that renders, small and muted, under the prize on the capture strip, the prize card and the winner splash. It is a legal disclosure and cannot be hidden. Exclusive giveaways show nothing extra.

**Branding.** The drawer design is fixed. From the dashboard you set the **logo**, the **prize image** and the **primary colour** (CTAs, tiles, highlights); the age-gate sentence and marketing-consent line are also server copy. Changes apply on the next open without an app update.

**Busy backend.** An HTTP 429/5xx that is the platform refusing the request (no structured error — instances warming up) is retried automatically four times on a jittered backoff (≈15 s worst case, `Retry-After` honoured up to 10 s) before `AvafliError.serverError` surfaces. Real backend answers (rate limit, cooldown, geo, consent, already claimed) are never retried.

## Controlling presentation

Registration always runs on `configure()`; the modes below only change **when the drawer opens**.

| `AvafliConfiguration.autoOpen` | Behaviour |
| --- | --- |
| `AvafliAutoOpen.always` (default) | Opens once per calendar day on the first app-open of the day, and again on a foreground that crosses midnight. |
| `AvafliAutoOpen.returningUsersOnly` | Skips the auto-open in the one session where the device registered for the first time (so it never pops over first-run onboarding). Every later launch auto-opens. |
| `AvafliAutoOpen.never` | Never auto-opens. You call `Avafli.present()`. |

Your dashboard can set a server-side mode too (`experience.autoOpenMode`); the **more restrictive** of the two applies, and the server kill switch (`experience.autoOpenEnabled: false`) always wins.

```dart
await Avafli.configure(AvafliConfiguration(
  apiKey: 'avafli_test_…',
  bundleId: 'com.example.myapp',
  user: AvafliUser(id: 'user_123'),
  autoOpen: AvafliAutoOpen.never, // we choose the moment
));

// Later — after onboarding, or from a "Daily prize" button:
final shown = await Avafli.present(); // true once the drawer was shown and closed
```

**`Avafli.present()`** waits for an in-flight registration, then opens the drawer if the SDK is configured, the person is not opted out, the publisher is not suspended, a giveaway is live (or a prize claim is pending) and the drawer is not already up — each failing guard resolves `false` with an info log, never a throw. It ignores the once-a-day mark, the impression cap and `holdAutoOpen()`, counts no impression, and on close writes the once-a-day mark so an auto-open later that day does not double-pop.

**`Avafli.holdAutoOpen()` / `Avafli.releaseAutoOpen()`** pause and resume the auto-open around a boot flow — see [GetX, GoRouter, auto_route and splash screens](#getx-gorouter-auto_route-and-splash-screens).

**Pending prize claim.** A winner must always be able to get back to an unfinished claim, so while one is pending the auto-open bypasses the once-a-day mark, the impression cap and `returningUsersOnly`: it opens on every cold start and on foreground at most every 30 minutes. The hold, the opt-out, a suspended publisher, the kill switch and mode `never` still apply — on `never`, `present()` opens straight onto the winner splash, and resolves `true` for a winner even when no giveaway is active (the usual case, since the giveaway has ended by the time its winner is drawn).

**`Avafli.isAvailable`** is `false` until `configure()` ran, or when the backend reported the publisher suspended / the key revoked (billing lapse) — the drawer stays silent and `present()` resolves `false` in that state.

## Push reminders

Streak reminders are sent through **your** Firebase project. The SDK never links Firebase itself; you forward the FCM token.

1. Set up [Firebase Cloud Messaging for Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/client) in your app.
2. Forward every token to Avafli:

   ```dart
   import 'package:firebase_messaging/firebase_messaging.dart';

   final token = await FirebaseMessaging.instance.getToken();
   if (token != null) await Avafli.registerPushToken(token);
   FirebaseMessaging.instance.onTokenRefresh.listen(Avafli.registerPushToken);
   ```

   `Avafli.registerPushToken` is a no-op until `configure()` has run. If your token can arrive earlier, use `AvafliPushNotificationManager.instance.didReceiveRegistrationToken(token)` instead — it queues the token and sends it once the SDK is configured, and skips the network when the token is unchanged.
3. Upload your FCM service-account key in the [Avafli dashboard](https://sdk.avafli.com/dashboard) and set the reminder schedule there.

`AvafliOptions.enablePushReminders` defaults to `true`; set it to `false` to keep the SDK from registering tokens at all. `Avafli.registerForPushNotifications()` exists for source compatibility only — it writes a debug log and does nothing else; you do not need to call it.

## Account deletion

Users can delete their Avafli data themselves: the in-app Privacy Policy page has a "Delete my data" section that raises the SDK's confirmation ("Delete my data & stop participating") and performs the erasure. No integration required.

If your app has its own delete-account flow, call the same erasure from it:

```dart
try {
  await Avafli.optOut();
} on AvafliException catch (e) {
  // e.error == AvafliError.notConfigured if configure() never ran;
  // otherwise the backend call failed — tell the user and let them retry.
}
```

`optOut()` is identity-wide (one call covers all of the person's devices) and includes prize-claim records. Entries and streaks are forfeited and cannot be restored; de-identified entry records are kept as the legally required evidence that drawings were fair (GDPR Art. 17(3)) — the person is erased, the proof is kept.

**24-hour rejoin.** For 24 hours after a deletion that email and that device cannot register, the drawer stays silent and `present()` resolves `false`. On the first `configure()` or app-foreground after that, the SDK clears what is left of the old session and registers the device again: the person is a brand-new participant with no link to the old profile and sees the normal email-capture flow. Nothing for the host app to do.

## Testing checklist

Run every item with your `avafli_test_…` key and `logging: LoggingLevel.debug`.

1. **First launch** — the drawer opens on email capture within a few seconds of `configure()`. If the log says `Auto-present skipped: Avafli.navigatorKey not attached to a MaterialApp`, the key is missing or on a nested navigator.
2. **Submit an email** — the dashboard celebrates "YOU'RE IN!" and the log shows `avafli_daily_entry_claimed` with `day: 1`.
3. **Relaunch the same day** — no second auto-open (`present()` still opens it). To see the auto-open again today, delete the app's data or use the example app's reset button.
4. **Next day** (or the device clock moved forward a day, then a cold start) — the drawer auto-opens and claims Day 2.
5. **Splash / boot navigation** — if you use `holdAutoOpen()`, confirm the log reads `Auto-present deferred: host is holding auto-open` during boot and the drawer appears over your home screen after `releaseAutoOpen()`. A log line `Auto-presented experience was removed by host navigation — retrying` means the hold is missing or released too early.
6. **`autoOpen: AvafliAutoOpen.never`** — nothing opens on its own; `await Avafli.present()` resolves `true`.
7. **Delete my data** — Privacy Policy → Delete my data (or `Avafli.optOut()`): the drawer dismisses and stays silent; after 24 hours a relaunch shows email capture again.
8. **Push** — after forwarding a token there is no `registerPushToken failed:` line in the log (through the manager you also get `Push token registered with backend`).
9. **Platform setup** — iOS `Info.plist` has both usage strings; Android main manifest has `INTERNET`; a release build uses the `avafli_live_…` key.

The example app (`example/`, `flutter run`) wires all of this up with a demo key and a "Reset demo state" button.

## API reference

Everything below is exported by `package:avafli_sdk/avafli_sdk.dart`. Members documented `@internal` in the source (`markOptedOut`, `syncClaimedToday`, `recoverExpiredSession`, …) are used by the drawer and are not for host apps.

### `Avafli`

| Member | Type | Description |
| --- | --- | --- |
| `Avafli.configure(config)` | `Future<bool>` | Initialise the SDK, register the device, then attempt the once-a-day auto-open. `false` (logged) if initialisation threw. |
| `Avafli.navigatorKey` | `GlobalKey<NavigatorState>` (assignable) | The root navigator the drawer is pushed through. Attach to `MaterialApp`, or assign your own root key before `configure()`. |
| `Avafli.present()` | `Future<bool>` | Open the drawer on demand. `true` once it was shown and closed; `false` for any failing guard (never throws). |
| `Avafli.holdAutoOpen()` | `void` | Pause the auto-open during a boot flow. Nothing is burned while held. |
| `Avafli.releaseAutoOpen()` | `Future<void>` | Release the hold and open at once if today's drawer is due. Safe before `configure()` and repeatedly. |
| `Avafli.isAvailable` | `bool` | `false` before `configure()` or while the publisher is suspended / key revoked. |
| `Avafli.registerPushToken(token)` | `Future<void>` | Forward an FCM token. No-op before `configure()` or for an empty token; failures are logged. |
| `Avafli.registerForPushNotifications()` | `Future<void>` | Source-compatibility shim: logs at debug level, nothing else. Throws `AvafliError.notConfigured` before `configure()`. |
| `Avafli.optOut()` | `Future<void>` | Erase the person and silence the drawer for 24 hours; they may rejoin as a new participant after that. Throws `AvafliException` on failure / when not configured. |
| `Avafli.sdkVersion` | `String` | `'3.3.1'` — sent to the backend and in the User-Agent. |
| `Avafli.platformOS` | `String` | `'iOS'`, `'Android'` or `'Web'` at runtime. |

### `AvafliConfiguration`

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `apiKey` | `String` | required | `avafli_live_…` or `avafli_test_…` from your dashboard |
| `bundleId` | `String` | required | Must match a bundle ID registered in your dashboard |
| `user` | `AvafliUser` | required | Your user, or `AvafliUser.guest` |
| `options` | `AvafliOptions` | `AvafliOptions()` | Logging, analytics, push |
| `autoOpen` | `AvafliAutoOpen` | `.always` | `.always` / `.returningUsersOnly` / `.never` |
| `environment` | `AvafliEnvironment` | `.production` | The only value; sandboxing is by key, not environment |

### `AvafliUser`

| Parameter | Type | Description |
| --- | --- | --- |
| `id` | `String` | Required. Your stable user id. `AvafliUser.guest` when nobody is signed in. |
| `firstName`, `lastName` | `String` | Optional (`''`). Letters, spaces, apostrophes, hyphens, max 50; otherwise dropped. Collected at prize-claim if missing. |
| `phone` | `String?` | Optional. Must normalise to 10 US digits; otherwise dropped. |
| `email` | `String?` | Optional. Pre-fills and locks the capture field; consent is still ticked in the flow. A malformed value is ignored. |

### `AvafliOptions`

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `logging` | `LoggingLevel` | `.error` | `.none`, `.error`, `.info`, `.debug` |
| `analyticsAdapter` | `AnalyticsAdapter?` | `null` | Receives the events below |
| `enablePushReminders` | `bool` | `true` | `false` disables token registration |

### `AvafliAutoOpen`

`always` (default), `returningUsersOnly`, `never`. `AvafliAutoOpen.mostRestrictive(a, b)` and `AvafliAutoOpen.fromWire(string)` are the helpers the SDK uses to combine the server's mode with yours.

### Errors

`AvafliException` (`implements Exception`) wraps an `AvafliError` and carries `serverMessage`, `displayMessage`, `details` / `reason` (the backend's structured payload, e.g. `claim_expired`), `transport` (the request never completed), `retryable` / `statusCode` / `retryAfter` (an infrastructure 429/5xx). Only `optOut()` and `registerForPushNotifications()` throw it to the host app; `configure()` and `present()` log and return `false` instead.

`AvafliError`: `notConfigured`, `noUser`, `ineligibleToday`, `invalidApiKey`, `networkError`, `authenticationFailed`, `underage`, `invalidEmail`, `emailRequired`, `giveawayNotAvailable`, `geographyNotAllowed`, `serverError`, `serviceUnavailable` (publisher suspended / key revoked), `optedOut`, `unknown`, `invalidState`, `noPresentingViewController`. Each has a `message`.

### Analytics

Implement `AnalyticsAdapter` (`track`, `setUserProperty`, `identify`) and pass it in `AvafliOptions.analyticsAdapter`:

```dart
class MyAnalyticsAdapter implements AnalyticsAdapter {
  @override
  void track(String eventName, [Map<String, dynamic>? parameters]) =>
      analytics.track(eventName, parameters);

  @override
  void setUserProperty(String name, String value) =>
      analytics.setUserProperty(name, value);

  @override
  void identify(String userId) => analytics.identify(userId);
}
```

Events the SDK emits in 3.3.1:

| Event | When | Parameters |
| --- | --- | --- |
| `avafli_sdk_configured` | `configure()` ran | — |
| `avafli_experience_presented` | the drawer opened (auto or `present()`) | — |
| `avafli_experience_dismissed` | the drawer closed without a new claim | — |
| `avafli_daily_entry_claimed` | the day's entries were granted | `day`, `entries`; `weekly_bonus`, `monthly_bonus`, `milestone_day`, `milestone_bonus` when present; `recovered_offline: true` when a queued claim landed later |
| `avafli_email_verified` | the "Verify your email" code was confirmed | — |
| `avafli_winner_claim_shown` | the winner splash opened | `giveaway_id` |
| `avafli_prize_claim_submitted` | the claim form was submitted | `giveaway_id`, `claim_number` |

`identify(userId)` is called on `configure()` for a non-guest user. Events emitted while offline are buffered (last 100, persisted) and flushed on resume / next launch with `original_timestamp` and `original_timestamp_ms` added. The `AvafliAnalyticsEvents` constants that have no row above are reserved names that 3.3.1 does not emit.

### Push

`AvafliPushNotificationManager.instance.didReceiveRegistrationToken(token)` — forward an FCM token; queues it before `configure()`, skips an unchanged token. `getCachedToken()` / `clearToken()` read and clear the locally cached token.

### Models

`Giveaway` (with `streakLadder`, `milestones`, `streakMode` / `isVisitMode`, `scope` / `sponsorDisclosure` / `isNetworkGiveaway`, `latestWinner`, `rulesUrl`, `prizeImageUrl`), `MilestoneConfig`, `GiveawayWinner`, `StreakConfig`, `GiveawayPeriod`, `AvafliSdkConfig` (`branding`, `experience`, `copy`, `ageGateEnabled`, `ageGateMinAge`, …), `StreakEngine` / `StreakState`, `DailyEntryGrant` and `AvafliBranding` are exported so you can inspect what the server sent; the drawer renders from them and they are not host-app configuration. `AvafliBranding.defaultBranding()` and its preset factories are the SDK's fallback palette; server branding overrides it at runtime.

## Links

- Dashboard: [sdk.avafli.com/dashboard](https://sdk.avafli.com/dashboard)
- Flutter docs: [sdk.avafli.com/flutter](https://sdk.avafli.com/flutter)
- Package: [pub.dev/packages/avafli_sdk](https://pub.dev/packages/avafli_sdk)
- Source: [github.com/AVAFLI/avafli_flutter_sdk](https://github.com/AVAFLI/avafli_flutter_sdk)
- Support: [info@avafli.com](mailto:info@avafli.com)

---

© 2026 Avafli. All Rights Reserved.
