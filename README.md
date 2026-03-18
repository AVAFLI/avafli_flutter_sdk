<p align="center">
  <img src="https://avafli.com/winr-logo.png" alt="WINR" width="200" />
</p>

<h1 align="center">WINR Flutter SDK</h1>

<p align="center">
  <a href="https://pub.dev/packages/winr_flutter_sdk"><img src="https://img.shields.io/pub/v/winr_flutter_sdk.svg" alt="pub.dev" /></a>
  <a href="https://pub.dev/packages/winr_flutter_sdk"><img src="https://img.shields.io/badge/flutter-%3E%3D3.10-blue.svg" alt="Flutter 3.10+" /></a>
  <a href="https://pub.dev/packages/winr_flutter_sdk"><img src="https://img.shields.io/badge/dart-%3E%3D3.0-blue.svg" alt="Dart 3.0+" /></a>
  <a href="https://pub.dev/packages/winr_flutter_sdk"><img src="https://img.shields.io/badge/platforms-iOS%20%7C%20Android-lightgrey.svg" alt="Platforms" /></a>
</p>

<p align="center">
  Drop-in sweepstakes, prizing, and gamification for your Flutter app.<br />
  Built by <a href="https://avafli.com">Avafli</a>.
</p>

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

## Requirements

| Platform | Minimum Version |
| -------- | --------------- |
| Flutter  | 3.10+           |
| Dart     | 3.0+            |
| iOS      | 13.0+           |
| Android  | API 21+         |

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

> **Note:** This package is distributed via [pub.dev](https://pub.dev/packages/winr_flutter_sdk). Contact [sales@avafli.com](mailto:sales@avafli.com) to obtain an API key.

## Quick Start

```dart
import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Configure the SDK
  await WINR.configure(WINROptions(
    apiKey: 'your-api-key',
    environment: WINREnvironment.production,
  ));

  runApp(const MyApp());
}
```

```dart
// 2. Identify the user after authentication
WINR.setUser(WINRUser(id: 'user_abc123'));

// 3. Present the WINR experience
final grant = await WINR.present(context);
print('Entries earned: ${grant.total}');
```

That's it. Three calls — configure, identify, present.

## API Reference

### `WINR.configure(WINROptions options)`

Initializes the SDK. Call once at app startup, before any other WINR methods.

```dart
final success = await WINR.configure(WINROptions(
  apiKey: 'wk_live_xxxxxxxxxx',
  environment: WINREnvironment.production,
  logging: true,
  enablePushReminders: true,
  analyticsAdapter: myAdapter,       // optional — see Analytics section
));
```

**Returns:** `Future<bool>` — `true` if initialization succeeded.

#### `WINROptions`

| Parameter             | Type                   | Required | Description                                       |
| --------------------- | ---------------------- | -------- | ------------------------------------------------- |
| `apiKey`              | `String`               | ✅       | Your WINR API key from the dashboard              |
| `environment`         | `WINREnvironment`      | ✅       | `.production`, `.staging`, or `.qa`                |
| `logging`             | `bool`                 | —        | Enable debug logging. Defaults to `false`.         |
| `analyticsAdapter`    | `AnalyticsAdapter?`    | —        | Forward SDK events to your analytics provider      |
| `enablePushReminders` | `bool`                 | —        | Enable daily push reminder support. Defaults to `false`. |

---

### `WINR.setUser(WINRUser user)`

Identifies the current user. Call after your authentication flow completes. The SDK handles email capture internally — you only need to pass an identifier.

```dart
WINR.setUser(WINRUser(
  id: 'user_abc123',          // required — your stable user ID
  firstName: 'Jane',          // optional
  lastName: 'Doe',            // optional
  phone: '+15551234567',      // optional
));
```

#### `WINRUser`

| Parameter   | Type      | Required | Description                            |
| ----------- | --------- | -------- | -------------------------------------- |
| `id`        | `String`  | ✅       | Unique, stable user identifier         |
| `firstName` | `String?` | —        | User's first name                      |
| `lastName`  | `String?` | —        | User's last name                       |
| `phone`     | `String?` | —        | Phone number in E.164 format           |

> **Email:** The SDK captures email through its own opt-in UI. Do not pass email via `WINRUser`.

---

### `WINR.present(BuildContext context)`

Launches the full-screen WINR experience. The user sees their daily entries, available prizes, and can earn bonus entries through rewarded video.

```dart
final grant = await WINR.present(context);

if (grant.total > 0) {
  print('${grant.baseEntries} base + ${grant.bonusEntries} bonus = ${grant.total} total');
}
```

**Returns:** `Future<DailyEntryGrant>`

#### `DailyEntryGrant`

| Field          | Type  | Description                                   |
| -------------- | ----- | --------------------------------------------- |
| `baseEntries`  | `int` | Entries earned from the daily visit            |
| `bonusEntries` | `int` | Additional entries earned (e.g., rewarded video) |
| `total`        | `int` | Sum of base and bonus entries                  |

---

### `WINR.presentAsCard()`

Embed the WINR experience as an inline card widget — ideal for home feeds, reward sections, or dashboard layouts.

```dart
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      const Text('Your Rewards'),
      WINR.presentAsCard(),     // Inline sweepstakes card
      const SizedBox(height: 16),
      // ... rest of your UI
    ],
  );
}
```

> The card inherits server-driven branding and adapts to the available width.

---

### `WINR.setRewardedVideoProvider(RewardedVideoProvider provider)`

Connects your existing ad mediation layer so users can earn bonus entries by watching rewarded video.

```dart
WINR.setRewardedVideoProvider(MyRewardedVideoProvider());
```

Implement the `RewardedVideoProvider` interface:

```dart
class MyRewardedVideoProvider implements RewardedVideoProvider {
  @override
  Future<bool> isAvailable() async {
    // Return true if a rewarded ad is loaded and ready
    return true;
  }

  @override
  Future<bool> show() async {
    // Show the rewarded ad. Return true if the user completed it.
    final result = await myAdSdk.showRewardedAd();
    return result.completed;
  }
}
```

| Method        | Returns         | Description                                  |
| ------------- | --------------- | -------------------------------------------- |
| `isAvailable` | `Future<bool>`  | Whether a rewarded ad is loaded and ready     |
| `show`        | `Future<bool>`  | Display the ad; return `true` on completion   |

> If no provider is set, the bonus entry option is hidden automatically.

---

### `WINR.registerForPushNotifications()`

Registers the device for WINR push reminders via Firebase Cloud Messaging. Call after the user has granted notification permissions.

```dart
// Request permission first (e.g., via firebase_messaging)
final settings = await FirebaseMessaging.instance.requestPermission();

if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  await WINR.registerForPushNotifications();
}
```

**Prerequisites:**

1. Add `firebase_messaging` to your project ([setup guide](https://firebase.google.com/docs/cloud-messaging/flutter/client))
2. Provide your FCM server key in the [WINR dashboard](https://dashboard.avafli.com)
3. Set `enablePushReminders: true` in `WINROptions`

---

### `WINR.deleteUserData()`

Permanently deletes all data associated with the current user. Use this to honor GDPR/CCPA deletion requests.

```dart
await WINR.deleteUserData();
```

> This action is irreversible. The user's entries, preferences, and consent records are removed from WINR servers.

## Analytics Adapter

Forward WINR events to your existing analytics stack by implementing `AnalyticsAdapter`:

```dart
class MyAnalyticsAdapter implements AnalyticsAdapter {
  @override
  void trackEvent(String name, Map<String, dynamic> properties) {
    // Forward to Segment, Amplitude, Mixpanel, etc.
    analytics.track(name, properties);
  }
}
```

Pass it during configuration:

```dart
await WINR.configure(WINROptions(
  apiKey: 'wk_live_xxxxxxxxxx',
  environment: WINREnvironment.production,
  analyticsAdapter: MyAnalyticsAdapter(),
));
```

**Events emitted by the SDK:**

| Event                        | Description                             |
| ---------------------------- | --------------------------------------- |
| `winr.session_started`       | User opened the WINR experience         |
| `winr.entry_granted`         | Daily entries awarded                   |
| `winr.bonus_entry_granted`   | Bonus entries earned via rewarded video  |
| `winr.session_completed`     | User closed the WINR experience         |
| `winr.push_registered`       | Device registered for push reminders    |

## Full Integration Example

```dart
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await WINR.configure(WINROptions(
    apiKey: 'wk_live_xxxxxxxxxx',
    environment: WINREnvironment.production,
    enablePushReminders: true,
    analyticsAdapter: MyAnalyticsAdapter(),
  ));

  runApp(const MyApp());
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _setupWINR();
  }

  Future<void> _setupWINR() async {
    // Identify user
    WINR.setUser(WINRUser(
      id: 'user_abc123',
      firstName: 'Jane',
    ));

    // Connect rewarded video
    WINR.setRewardedVideoProvider(MyRewardedVideoProvider());

    // Register for push (after permission granted)
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await WINR.registerForPushNotifications();
    }
  }

  Future<void> _openWINR() async {
    final grant = await WINR.present(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You earned ${grant.total} entries!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My App')),
      body: Column(
        children: [
          // Inline card embed
          WINR.presentAsCard(),

          // Or launch full-screen
          ElevatedButton(
            onPressed: _openWINR,
            child: const Text('Open Sweepstakes'),
          ),
        ],
      ),
    );
  }
}
```

## Privacy & Compliance

WINR is designed for privacy-first integration:

- **GDPR & CCPA** — Built-in consent collection and `deleteUserData()` for right-to-erasure
- **Minimal data** — The SDK collects only what's necessary for sweepstakes operation
- **Email capture** — Handled within the SDK's own consent-driven UI; publishers never touch PII
- **No tracking across apps** — WINR does not share user data between publisher integrations
- **SOC 2 Type II** — Avafli maintains enterprise-grade security controls

For questions about data processing, contact [privacy@avafli.com](mailto:privacy@avafli.com).

## Environments

| Environment                    | Use Case                                          |
| ------------------------------ | ------------------------------------------------- |
| `WINREnvironment.production`   | Live app with real prizes and entries              |
| `WINREnvironment.staging`      | Pre-release testing with sandbox prizes            |
| `WINREnvironment.qa`           | Internal QA — no external API calls, mock responses|

## Troubleshooting

| Symptom                        | Solution                                                        |
| ------------------------------ | --------------------------------------------------------------- |
| `configure()` returns `false`  | Verify your API key and network connectivity                    |
| Entries not appearing          | Ensure `setUser()` is called before `present()`                 |
| Push not working               | Confirm FCM setup, `enablePushReminders: true`, and permissions |
| Rewarded video not shown       | Check that `isAvailable()` returns `true` in your provider      |
| Blank UI on present            | Ensure `BuildContext` is from a mounted widget                  |

Enable debug logging for detailed diagnostics:

```dart
await WINR.configure(WINROptions(
  apiKey: 'wk_live_xxxxxxxxxx',
  environment: WINREnvironment.staging,
  logging: true,
));
```

## Support

- **Dashboard:** [dashboard.avafli.com](https://dashboard.avafli.com)
- **Documentation:** [docs.avafli.com](https://docs.avafli.com)
- **Email:** [support@avafli.com](mailto:support@avafli.com)
- **Sales:** [sales@avafli.com](mailto:sales@avafli.com)

---

<p align="center">
  Built by <a href="https://avafli.com">Avafli</a> · © 2025 Avafli, Inc. All rights reserved.
</p>
