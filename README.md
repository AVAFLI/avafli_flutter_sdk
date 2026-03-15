# WINR Flutter SDK

A comprehensive sweepstakes and engagement SDK for Flutter apps. Add daily streaks, rewarded video entries, and sweepstakes giveaways with a few lines of code.

[![pub package](https://img.shields.io/pub/v/winr_flutter_sdk.svg)](https://pub.dev/packages/winr_flutter_sdk)

## Features

- **Daily Streak System** — 3-tier engagement (base entries, weekly bonus, monthly bonus)
- **Rewarded Video** — Pluggable ad provider interface (AdMob, AppLovin, IronSource, Unity)
- **Email Capture** — Built-in age gate (13+) and email validation
- **Push Notifications** — FCM streak reminders
- **Server-Driven Config** — Copy, branding, and theme controlled from your dashboard
- **GDPR Compliance** — One-call user data deletion
- **Offline Resilience** — Claims cached locally when network fails
- **Customizable UI** — Material 3 dark theme, fully brandable

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  winr_flutter_sdk: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize the SDK

Call `WINR.configure()` at app startup (e.g., in `main()` or your root widget's `initState`):

```dart
import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await WINR.configure(WINROptions(
    apiKey: 'your-api-key',
    environment: WINREnvironment.production,
  ));

  runApp(const MyApp());
}
```

### 2. Set the User

After authentication, set the current user:

```dart
WINR.setUser(WINRUser(id: 'user-123'));
```

### 3. Present the Experience

Show the full-screen WINR experience:

```dart
// Full-screen modal
final result = await WINR.present(context);

// Or embed as a card widget
Widget card = WINR.presentAsCard(
  onEntryGranted: () => print('Entries claimed!'),
);
```

## Custom Branding

```dart
await WINR.configure(WINROptions(
  apiKey: 'your-api-key',
  environment: WINREnvironment.production,
  branding: WINRBranding(
    primaryColor: Color(0xFF6C63FF),
    secondaryColor: Color(0xFF3F3D56),
    logoUrl: 'https://your-app.com/logo.png',
    appName: 'Your App',
  ),
));
```

## Rewarded Video

Implement `RewardedVideoProvider` for your ad network:

```dart
class MyAdProvider implements RewardedVideoProvider {
  @override
  Future<void> initialize(String adUnitId) async {
    // Initialize your ad SDK
  }

  @override
  Future<bool> showRewardedAd() async {
    // Show ad, return true if user earned reward
    return true;
  }

  @override
  bool get isReady => true;
}

// Set the provider before presenting
WINR.setRewardedVideoProvider(MyAdProvider());
```

## Analytics

Plug in your analytics system:

```dart
class FirebaseAnalyticsAdapter implements AnalyticsAdapter {
  @override
  void track(String event, [Map<String, dynamic>? properties]) {
    FirebaseAnalytics.instance.logEvent(name: event, parameters: properties);
  }

  @override
  void identify(String userId) {
    FirebaseAnalytics.instance.setUserId(id: userId);
  }
}

await WINR.configure(WINROptions(
  apiKey: 'your-api-key',
  analyticsAdapter: FirebaseAnalyticsAdapter(),
));
```

## Push Notifications

Enable streak reminders:

```dart
await WINR.configure(WINROptions(
  apiKey: 'your-api-key',
  enablePushReminders: true,
));

// Register after user grants permission
await WINR.registerForPushNotifications();
```

## GDPR Compliance

Delete all user data with one call:

```dart
await WINR.deleteUserData();
```

## API Reference

| Method | Description |
|--------|-------------|
| `WINR.configure(options)` | Initialize the SDK |
| `WINR.setUser(user)` | Set the current user |
| `WINR.present(context)` | Show full-screen experience |
| `WINR.presentAsCard()` | Get embeddable card widget |
| `WINR.registerForPushNotifications()` | Enable push reminders |
| `WINR.deleteUserData()` | GDPR data deletion |

## Requirements

- Flutter 3.10+
- Dart SDK 3.0+
- iOS 13+ / Android API 21+

## License

MIT — see [LICENSE](LICENSE) for details.
