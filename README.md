# WINR Flutter SDK
**Drop-in sweepstakes, prizing, and gamification for your Flutter app**

[![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-blue.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue.svg?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android-lightgrey.svg)](https://flutter.dev)

---

## Overview

WINR lets you add daily-entry sweepstakes and prize experiences to your app in under 20 lines of code. The entire UI — branding, theming, copy, and prize configuration — is managed server-side from the WINR dashboard. You integrate once; your marketing team controls the rest.

**Key capabilities:**
- **Daily entry sweepstakes** — Users earn entries every day they engage
- **V2 auto-open experience** — The bottom-drawer experience opens itself on the first app-open of each day and grants entries automatically
- **Streak ladder + milestone accelerators** — Escalating daily entry rewards, with server-configurable milestone bonuses
- **Winner announcements** — "WE HAVE A WINNER!" banner and winner dialog, driven by the giveaway's `latestWinner`
- **Visit mode** — A never-resetting streak variant for low-frequency apps
- **Push reminders** — Drive re-engagement with daily nudges (FCM)
- **Server-driven branding** — Logo, prize image, and primary color update without app releases
- **GDPR/CCPA compliant** — Built-in consent flows, RTD opt-out, and user data deletion
- **Analytics forwarding** — Route SDK events to your existing analytics stack

## Quick Start

```dart
import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';

// 1. Configure the SDK
final config = WINRConfiguration(
  apiKey: 'YOUR_API_KEY',
  bundleId: 'com.example.myapp',
  environment: WINREnvironment.production,
  user: WINRUser(
    id: 'user_123',
    firstName: 'Jane',
    lastName: 'Doe',
  ),
);
await WINR.configure(config);

// 2. Attach the SDK navigator key so the experience can auto-open on the
//    first app-open of each day
MaterialApp(navigatorKey: WINR.navigatorKey, home: ...);
```

That's the whole integration — the experience presents itself once per day.

## Installation

Add the SDK to your `pubspec.yaml`:

```yaml
dependencies:
  winr_flutter_sdk: ^2.3.3
```

> Published on [pub.dev](https://pub.dev/packages/winr_flutter_sdk). A git dependency on this repo also works if you need an unreleased revision.

Then run:

```bash
flutter pub get
```

> **Note:** Contact [AVAFLI](https://avafli-website.web.app/sdk/pricing) to obtain an API key.

## Configuration

Initialize the SDK with your user and environment settings:

```dart
final config = WINRConfiguration(
  apiKey: 'winr_live_xxxxxxxxxx',
  bundleId: 'com.example.myapp',
  environment: WINREnvironment.production,
  user: WINRUser(
    id: 'user_abc123',
    firstName: 'Jane',
    lastName: 'Doe',
    phone: '+15551234567',  // optional
  ),
  options: WINROptions(
    logging: LoggingLevel.debug,
    enablePushReminders: true,
    analyticsAdapter: myAdapter,  // optional
  ),
);

final success = await WINR.configure(config);
```

### WINRConfiguration

| Parameter | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `apiKey` | `String` | ✅ | Your WINR API key from the dashboard |
| `bundleId` | `String` | ✅ | App bundle ID (e.g., com.example.myapp) |
| `environment` | `WINREnvironment` | — | `.production` (default) |
| `user` | `WINRUser` | ✅ | The authenticated user |
| `options` | `WINROptions?` | — | Optional behavior toggles |

### WINRUser

| Parameter | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | `String` | ✅ | Unique, stable user identifier |
| `firstName` | `String` | ✅ | User's first name |
| `lastName` | `String` | ✅ | User's last name |
| `phone` | `String?` | — | Phone number in E.164 format |

> **Email:** The SDK captures email through its own opt-in UI. Do not pass email via `WINRUser`.

## The Experience Presents Itself

There is no manual launch API — the WINR experience is exclusively SDK-driven. The V2 bottom-drawer experience presents itself automatically at most once per calendar day (first app-open of the day) when `WINR.navigatorKey` is attached to your `MaterialApp`. Auto-open respects the server-side kill switch (`sdkConfig.experience.autoOpenEnabled`), an unregistered-impression cap (default 3 impressions until the user confirms their email), and the RTD opt-out — an opted-out user never sees the experience again.

Entries are claimed automatically when the drawer opens, and the celebration is the first thing the user sees: the dashboard opens with today's grant already showing — the day tile checks off with a confetti burst, the total counts up and pops, and the bar leads with a "YOU'RE ON A ROLL!" toast before settling into the come-back message. There is no button to tap to collect entries; the pill just reads GOT IT and closes. Brand-new users first submit their email, then land straight on the same celebrating dashboard — the toast just reads "YOU'RE IN!" on Day 1.

## Winner Experience

When one of your users is drawn as a giveaway winner, the drawer automatically opens on a winner splash instead of the dashboard, then walks them through a prize-claim form (name, shipping address) and a confirmation with their claim number. This requires no integration work — the flow appears only for the drawn winner and disappears once their claim is submitted.

## Push Notifications

Drive re-engagement with daily reminders. Publishers forward their FCM token to WINR:

### 1. Setup Firebase Cloud Messaging

Follow the [Firebase setup guide](https://firebase.google.com/docs/cloud-messaging/flutter/client) for Flutter.

### 2. Forward FCM Token

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

// Get the FCM token and forward it to WINR
final fcmToken = await FirebaseMessaging.instance.getToken();
if (fcmToken != null) {
  await WINRPushNotificationManager.instance.didReceiveRegistrationToken(fcmToken);
}

// Listen for token refreshes
FirebaseMessaging.instance.onTokenRefresh.listen((token) {
  WINRPushNotificationManager.instance.didReceiveRegistrationToken(token);
});
```

Or the one-line equivalent:

```dart
FirebaseMessaging.instance.onTokenRefresh.listen(WINR.registerPushToken);
```

### 3. Upload FCM Service Account Key

Upload your FCM service account key via the [WINR Dashboard](https://avafli-website.web.app/sdk/dashboard) to enable push notifications.

### 4. Enable Push Reminders

Set `enablePushReminders: true` in `WINROptions` during configuration.

## Customization

The V2 experience is hardcoded to the WINR design; publishers customize exactly three things through the [WINR Dashboard](https://avafli-website.web.app/sdk/dashboard):

- **Logo** — Shown in the drawer header
- **Prize image** — Art for the dashboard prize card
- **Primary color** — Accent for CTAs, streak tiles, and highlights

Plus prize configuration (active giveaways, ladder, milestones) and push reminder schedules.

Changes apply instantly across all app installations without requiring an app update.

## Analytics

Forward WINR events to your existing analytics stack:

```dart
class MyAnalyticsAdapter implements AnalyticsAdapter {
  @override
  void track(String eventName, [Map<String, dynamic>? parameters]) {
    // Forward to Segment, Amplitude, Mixpanel, etc.
    analytics.track(eventName, parameters);
  }
}

// Pass during configuration
await WINR.configure(WINRConfiguration(
  // ... other config
  options: WINROptions(
    analyticsAdapter: MyAnalyticsAdapter(),
  ),
));
```

**Events emitted by the SDK:**
- `winr_sdk_configured` — SDK configured successfully
- `winr_experience_presented` — User opened the WINR experience
- `winr_daily_entry_claimed` — Daily entries awarded (auto-claimed on open). Params: `day`, `entries`, plus `weekly_bonus`, `monthly_bonus`, and `milestone_day` when awarded.
- `winr_experience_dismissed` — User closed the WINR experience without a new claim

## GDPR / Delete User Data

Support GDPR/CCPA deletion requests:

```dart
await WINR.deleteUserData();
```

This permanently removes all user data, entries, preferences, and consent records from WINR servers.

## API Reference

### Core Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `WINR.configure(config)` | `Future<bool>` | Initialize the SDK with user and settings |
| `WINR.navigatorKey` | `GlobalKey<NavigatorState>` | Attach to your `MaterialApp` so the experience can auto-open |
| `WINR.optOut()` | `Future<void>` | RTD opt-out — permanently silence the experience |
| `WINR.deleteUserData()` | `Future<void>` | Permanently delete all user data |

### Push Notifications

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `WINRPushNotificationManager.instance.didReceiveRegistrationToken(token)` | `Future<void>` | Forward FCM token to WINR |

For detailed API documentation, see the [WINR Docs](https://avafli-website.web.app/sdk/flutter).

## Links

- **Dashboard:** [https://avafli-website.web.app/sdk/dashboard](https://avafli-website.web.app/sdk/dashboard)
- **Documentation:** [https://avafli-website.web.app/sdk/flutter](https://avafli-website.web.app/sdk/flutter)
- **Support:** [info@avafli.com](mailto:info@avafli.com)

---

© 2026 Avafli. All Rights Reserved.
