# Avafli Engagement SDK for Flutter
**Drop-in sweepstakes, prizing, and gamification for your Flutter app**

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-blue.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5%2B-blue.svg?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android-lightgrey.svg)](https://flutter.dev)

---

## Overview

Avafli lets you add daily-entry sweepstakes and prize experiences to your app in under 20 lines of code. The entire UI — branding, theming, copy, and prize configuration — is managed server-side from the Avafli dashboard. You integrate once; your marketing team controls the rest.

**Key capabilities:**
- **Daily entry sweepstakes** — Users earn entries every day they engage
- **V2 auto-open experience** — The bottom-drawer experience opens itself on the first app-open of each day and grants entries automatically (requires `Avafli.navigatorKey` on your `MaterialApp`)
- **Daily streak + auto-claim** — Entries climb a +10/day ladder; the drawer auto-opens once per day and claims that day's entries — there is no manual present API
- **Email capture** — The SDK captures an email through its own opt-in screen, with an UNCHECKED-by-default marketing-consent tick and a publisher-configurable age gate
- **Cross-device verified adoption** — When a typed email matches an existing account, the SDK confirms a 6-digit code before merging the streak across devices
- **Soft email verification** — A brand-new typed email shows a persistent, dismissible "Verify your email" chip; it never blocks play, only prize-draw eligibility
- **Winner claim flow** — "WE HAVE A WINNER!" splash and an in-drawer prize-claim flow (name, shipping address incl. DC, claim number)
- **Visit mode** — A never-resetting streak variant for low-frequency apps
- **Push reminders** — Drive re-engagement with daily nudges (FCM)
- **Server-driven branding** — Logo, prize image, and primary color update without app releases
- **GDPR/CCPA compliant** — Built-in consent flows, RTD opt-out via `optOut()`, and a self-serve "Delete my data & stop participating" section inside the in-app Privacy Policy
- **Analytics forwarding** — Route SDK events to your existing analytics stack

## Quick Start

```dart
import 'package:avafli_sdk/avafli_sdk.dart';

await Avafli.configure(AvafliConfiguration(
  apiKey: 'YOUR_API_KEY', // debug builds: use your avafli_test_ sandbox key
  bundleId: 'com.example.myapp',
  user: AvafliUser(
    id: 'user_123',             // only id is required — pass whatever identity you have
    firstName: 'Jane',
    lastName: 'Doe',
    email: 'jane@example.com',  // include it when you have it — pre-fills & locks the capture form (consent stays explicit)
  ),
  // Nobody signed in? use user: AvafliUser.guest
  options: AvafliOptions(
    logging: LoggingLevel.error,  // LoggingLevel.debug while integrating
    enablePushReminders: true,    // streak reminders via YOUR Firebase project (upload the key in your dashboard)
  ),
));

// Attach the navigator key so the daily auto-open can present:
//   MaterialApp(navigatorKey: Avafli.navigatorKey, ...)
// Splash screen that clears the nav stack? Call Avafli.holdAutoOpen() before
// configure, then Avafli.releaseAutoOpen() once your main screen mounts.
// Push reminders: forward FCM tokens with Avafli.registerPushToken(token).
```

That's the whole integration — the experience presents itself once per day.

> **Boot flows that clear the nav stack.** If your app boots through a splash
> screen or auth gate that ends by clearing the navigation stack
> (`Get.offAll`, `Navigator.pushAndRemoveUntil`, …), that navigation can destroy
> the drawer the instant it auto-opens. Call `Avafli.holdAutoOpen()` **before**
> `configure()` during boot, then `Avafli.releaseAutoOpen()` once your main screen
> is mounted — it releases the hold and immediately opens if the day is due.

### Identity — pass what you have, the SDK captures the rest

Only `id` is required. Construct an `AvafliUser` from whatever identity data you
already hold — even just an id — and the SDK fills in the gaps: it captures the
email through its own screen, and the name at prize-claim time if the user wins.
There are three cases:

**1. Signed-in user without an email (the common case, and Avafli's main value).**
Pass the id plus whatever you have and OMIT `email`. The SDK shows its capture
screen and the user types their email — so you capture an address you didn't
have before:

```dart
user: AvafliUser(id: 'user_123', firstName: 'Jane', lastName: 'Doe')   // no email
```

Even just `AvafliUser(id: 'user_123')` is valid — name is collected later at
prize-claim, only if they win.

**2. Signed-in user with an email.** Pass `email` too and it pre-fills and
**locks** the capture field (consent is still an explicit tick inside the flow).
`email` is a plain `String`:

```dart
user: AvafliUser(id: 'user_123', firstName: 'Jane', lastName: 'Doe', email: 'jane@example.com')
```

**3. No signed-in user at all.** Pass `AvafliUser.guest`:

```dart
await Avafli.configure(AvafliConfiguration(
  apiKey: 'YOUR_API_KEY',
  bundleId: 'com.example.myapp',
  user: AvafliUser.guest,
));
```

The SDK mints a stable per-install guest id (`avafli_guest_…`) for attribution —
never fabricate placeholder ids yourself. The experience is fully functional
for guests. When the user signs in, call `configure` again with the real user:
attribution upgrades in place and the streak carries over automatically.

## Installation

Add the SDK to your `pubspec.yaml`:

```yaml
dependencies:
  avafli_sdk: ^3.1.2
```

> Published on [pub.dev](https://pub.dev/packages/avafli_sdk). A git dependency on this repo also works if you need an unreleased revision.

Then run:

```bash
flutter pub get
```

> **Note:** Contact [AVAFLI](https://sdk.avafli.com/pricing) to obtain an API key.

## Configuration

Initialize the SDK with your user and environment settings:

```dart
final config = AvafliConfiguration(
  apiKey: 'avafli_live_xxxxxxxxxx',
  bundleId: 'com.example.myapp',
  environment: AvafliEnvironment.production,
  user: AvafliUser(
    id: 'user_abc123',
    firstName: 'Jane',
    lastName: 'Doe',
    phone: '+15551234567',  // optional
  ),
  options: AvafliOptions(
    logging: LoggingLevel.debug,
    enablePushReminders: true,
    analyticsAdapter: myAdapter,  // optional
  ),
);

final success = await Avafli.configure(config);
```

### AvafliConfiguration

| Parameter | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `apiKey` | `String` | ✅ | Your Avafli API key from the dashboard |
| `bundleId` | `String` | ✅ | App bundle ID (e.g., com.example.myapp) |
| `environment` | `AvafliEnvironment` | — | `.production` (default) |
| `user` | `AvafliUser` | ✅ | The authenticated user |
| `options` | `AvafliOptions?` | — | Optional behavior toggles |

### AvafliUser

| Parameter | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | `String` | ✅ | Unique, stable user identifier (the only required field) |
| `firstName` | `String` | — | User's first name; captured at prize-claim if omitted |
| `lastName` | `String` | — | User's last name; captured at prize-claim if omitted |
| `phone` | `String?` | — | Phone number in E.164 format |
| `email` | `String?` | — | If passed, pre-fills and locks the capture field; if omitted, the SDK captures it |

> **Email:** Omit it and the SDK captures an address through its own opt-in
> screen (the common case). Pass it and that address pre-fills and locks —
> consent is still an explicit tick inside the flow. See the three identity
> cases above.

## Test in Development: Your Sandbox Key

Your publisher dashboard shows two API keys:

| Key | Use it in |
| --- | --------- |
| `avafli_live_…` | Release builds — your real giveaway |
| `avafli_test_…` | Debug/dev builds and CI — an isolated sandbox |

The sandbox key hits the **same production backend** with identical behavior —
registration, streaks, entries, the full experience — but every user and entry
lands in a separate sandbox tenant with its own always-active test giveaway.
That means:

- Your developers and testers **can never enter (or win) your real giveaway.**
- Sandbox usage **never counts toward your MAU** or your bill.
- Your registered bundle IDs work with both keys automatically.

Swap keys per build configuration and nothing else about your integration
changes.

## The Experience Presents Itself

There is no manual launch API — the Avafli experience is exclusively SDK-driven. The V2 bottom-drawer experience presents itself automatically at most once per calendar day (first app-open of the day) when `Avafli.navigatorKey` is attached to your `MaterialApp`. Auto-open respects the server-side kill switch (`sdkConfig.experience.autoOpenEnabled`), an unregistered-impression cap (default 3 impressions until the user confirms their email), and the RTD opt-out — an opted-out user never sees the experience again.

Entries are claimed automatically when the drawer opens, and the celebration is the first thing the user sees: the dashboard opens with today's grant already showing — the day tile checks off with a confetti burst, the total counts up and pops, and the bar leads with a "YOU'RE ON A ROLL!" toast before settling into the come-back message. There is no button to tap to collect entries; the pill just reads GOT IT and closes. Brand-new users first submit their email, then land straight on the same celebrating dashboard — the toast just reads "YOU'RE IN!" on Day 1.

If your app boots through a splash/auth flow that clears the navigation stack, guard the auto-open with `Avafli.holdAutoOpen()` / `Avafli.releaseAutoOpen()` (see [Quick Start](#quick-start)).

## Email Capture & Verification

Email is captured inside the SDK's own opt-in screen (see the identity section above). The screen shows a publisher-configurable **age gate** — an affirmative tick that gates the CTA — and a **marketing-consent** checkbox that is **unchecked by default** and never gates entry (declining it costs neither the entry nor, if drawn, winner contact).

Two verification paths run from that screen:

- **Cross-device verified adoption.** When the typed email matches an existing Avafli account (from another device or install), the SDK asks for a **6-digit code** emailed to that address before the two identities are merged — so a streak follows the person across devices without letting anyone attach to someone else's record.
- **Soft email verification (2.7.0+).** A brand-new, never-before-seen typed email surfaces a persistent, dismissible **"Verify your email"** chip on the dashboard. It **never blocks play** — the user keeps earning entries — it only affects prize-draw eligibility until the address is confirmed.

## Winner Experience

When one of your users is drawn as a giveaway winner, the drawer automatically opens on a winner splash instead of the dashboard, then walks them through a prize-claim form (name, shipping address) and a confirmation with their claim number. This requires no integration work — the flow appears only for the drawn winner and disappears once their claim is submitted.

## Push Notifications

Drive re-engagement with daily reminders. Publishers forward their FCM token to Avafli:

### 1. Setup Firebase Cloud Messaging

Follow the [Firebase setup guide](https://firebase.google.com/docs/cloud-messaging/flutter/client) for Flutter.

### 2. Forward FCM Token

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

// Get the FCM token and forward it to Avafli
final fcmToken = await FirebaseMessaging.instance.getToken();
if (fcmToken != null) {
  await AvafliPushNotificationManager.instance.didReceiveRegistrationToken(fcmToken);
}

// Listen for token refreshes
FirebaseMessaging.instance.onTokenRefresh.listen((token) {
  AvafliPushNotificationManager.instance.didReceiveRegistrationToken(token);
});
```

Or the one-line equivalent:

```dart
FirebaseMessaging.instance.onTokenRefresh.listen(Avafli.registerPushToken);
```

### 3. Upload FCM Service Account Key

Upload your FCM service account key via the [Avafli Dashboard](https://sdk.avafli.com/dashboard) to enable push notifications.

### 4. Enable Push Reminders

Set `enablePushReminders: true` in `AvafliOptions` during configuration, then call
`Avafli.registerForPushNotifications()` after `configure()`. It is a no-op when
`enablePushReminders` is false.

```dart
await Avafli.registerForPushNotifications();
```

## Customization

The V2 experience is hardcoded to the Avafli design; publishers customize exactly three things through the [Avafli Dashboard](https://sdk.avafli.com/dashboard):

- **Logo** — Shown in the drawer header
- **Prize image** — Art for the dashboard prize card
- **Primary color** — Accent for CTAs, streak tiles, and highlights

Plus prize configuration (active giveaways, the entry ladder) and push reminder schedules.

Changes apply instantly across all app installations without requiring an app update.

## Analytics

Forward Avafli events to your existing analytics stack:

```dart
class MyAnalyticsAdapter implements AnalyticsAdapter {
  @override
  void track(String eventName, [Map<String, dynamic>? parameters]) {
    // Forward to Segment, Amplitude, Mixpanel, etc.
    analytics.track(eventName, parameters);
  }

  @override
  void setUserProperty(String name, String value) {
    analytics.setUserProperty(name, value);
  }

  @override
  void identify(String userId) {
    analytics.identify(userId);
  }
}

// Pass during configuration
await Avafli.configure(AvafliConfiguration(
  apiKey: 'YOUR_API_KEY',
  bundleId: 'com.example.myapp',
  user: AvafliUser(id: 'user_123'),
  options: AvafliOptions(
    analyticsAdapter: MyAnalyticsAdapter(),
  ),
));
```

**Events emitted by the SDK:**
- `avafli_sdk_configured` — SDK configured successfully
- `avafli_experience_presented` — User opened the Avafli experience
- `avafli_daily_entry_claimed` — Daily entries awarded (auto-claimed on open). Params: `day`, `entries`.
- `avafli_experience_dismissed` — User closed the Avafli experience without a new claim

## Account deletion in your app

If your app has its own delete-account flow, call `optOut()` from it so the
user's Avafli data is erased along with their account. Users can also delete
their data themselves at any time from the Privacy Policy screen inside the
experience — no integration required.

```dart
// From your delete-account flow
await Avafli.optOut();
```

The erasure is identity-wide (one call covers all of the person's devices),
includes prize-claim records, and permanently silences the experience on the
device — it survives a reinstall. De-identified entry records are retained as
the legally required evidence that drawings were fair (GDPR Art. 17(3)): the
person is erased, the proof is kept.

## API Reference

### Core Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `Avafli.configure(config)` | `Future<bool>` | Initialize the SDK with user and settings |
| `Avafli.navigatorKey` | `GlobalKey<NavigatorState>` | Attach to your `MaterialApp` so the experience can auto-open (required) |
| `Avafli.holdAutoOpen()` | `void` | Pause the once-a-day auto-open during a boot flow that clears the nav stack |
| `Avafli.releaseAutoOpen()` | `Future<void>` | Release a `holdAutoOpen()` and open immediately if the day is due |
| `Avafli.optOut()` | `Future<void>` | RTD opt-out — permanently silence the experience |

### Push Notifications

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `Avafli.registerForPushNotifications()` | `Future<void>` | Enable streak reminders; no-op when `enablePushReminders` is false |
| `Avafli.registerPushToken(token)` | `Future<void>` | Forward an FCM token to Avafli (one-line `onTokenRefresh` listener) |
| `AvafliPushNotificationManager.instance.didReceiveRegistrationToken(token)` | `Future<void>` | Forward FCM token to Avafli |

For detailed API documentation, see the [Avafli Docs](https://sdk.avafli.com/flutter).

## Links

- **Dashboard:** [https://sdk.avafli.com/dashboard](https://sdk.avafli.com/dashboard)
- **Documentation:** [https://sdk.avafli.com/flutter](https://sdk.avafli.com/flutter)
- **Support:** [info@avafli.com](mailto:info@avafli.com)

---

© 2026 Avafli. All Rights Reserved.
