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
- **Bonus entries via rewarded video** — Monetize attention with opt-in ads
- **Push reminders** — Drive re-engagement with daily nudges (FCM)
- **Server-driven UI** — Branding, prizes, and copy update without app releases
- **GDPR/CCPA compliant** — Built-in consent flows and user data deletion
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

// 2. Present the experience
await WINR.present(context);
```

## Installation

Add the SDK to your `pubspec.yaml`:

```yaml
dependencies:
  winr_flutter_sdk: ^1.0.0
```

Then run:

```bash
flutter pub get
```

> **Note:** Contact [team@avafli.com](mailto:team@avafli.com) to obtain an API key.

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
| `environment` | `WINREnvironment` | ✅ | `.production`, `.staging`, or `.qa` |
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

## Present the Experience

Launch the full-screen WINR experience:

```dart
final grant = await WINR.present(context);

if (grant.total > 0) {
  print('${grant.baseEntries} base + ${grant.bonusEntries} bonus = ${grant.total} total');
}
```

The method returns a `DailyEntryGrant` with the entries earned during the session.

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

### 3. Upload FCM Service Account Key

Upload your FCM service account key via the [WINR Dashboard](https://avafli-website.web.app/sdk/dashboard) to enable push notifications.

### 4. Enable Push Reminders

Set `enablePushReminders: true` in `WINROptions` during configuration.

## Customization

All branding, themes, and copy are managed server-side through the [WINR Dashboard](https://avafli-website.web.app/sdk/dashboard):

- **Colors & Branding** — Primary colors, logos, backgrounds
- **Copy & Messaging** — Headlines, CTAs, legal text
- **Prize Configuration** — Active giveaways, entry mechanics
- **Push Notifications** — Reminder schedules and messaging

Changes apply instantly across all app installations without requiring an app update.

## Analytics

Forward WINR events to your existing analytics stack:

```dart
class MyAnalyticsAdapter implements AnalyticsAdapter {
  @override
  void trackEvent(String name, Map<String, dynamic> properties) {
    // Forward to Segment, Amplitude, Mixpanel, etc.
    analytics.track(name, properties);
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
- `winr.session_started` — User opened the WINR experience
- `winr.entry_granted` — Daily entries awarded
- `winr.bonus_entry_granted` — Bonus entries earned via rewarded video
- `winr.session_completed` — User closed the WINR experience
- `winr.push_registered` — Device registered for push reminders

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
| `WINR.present(context)` | `Future<DailyEntryGrant>` | Launch the full-screen WINR experience |
| `WINR.deleteUserData()` | `Future<void>` | Permanently delete all user data |

### Push Notifications

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `WINRPushNotificationManager.instance.didReceiveRegistrationToken(token)` | `Future<void>` | Forward FCM token to WINR |

For detailed API documentation, see the [WINR Docs](https://docs.avafli.com).

## Links

- **Dashboard:** [https://avafli-website.web.app/sdk/dashboard](https://avafli-website.web.app/sdk/dashboard)
- **Documentation:** [https://docs.avafli.com](https://docs.avafli.com)
- **Support:** [team@avafli.com](mailto:team@avafli.com)

---

© 2026 Avafli. All Rights Reserved.