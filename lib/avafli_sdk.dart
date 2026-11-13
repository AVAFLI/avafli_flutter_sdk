/// Avafli SDK for Flutter — daily-streak sweepstakes in a self-presenting
/// bottom drawer.
///
/// The SDK registers the device on [Avafli.configure], opens its drawer at
/// most once per calendar day through [Avafli.navigatorKey], captures the
/// email, grants the day's entries and runs the winner's prize claim.
/// Branding, prize and ladder come from the Avafli dashboard.
///
/// Complete integration:
/// ```dart
/// import 'package:avafli_sdk/avafli_sdk.dart';
/// import 'package:flutter/material.dart';
///
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   runApp(const MyApp()); // mount the navigator first, then configure
///   await Avafli.configure(AvafliConfiguration(
///     apiKey: 'avafli_test_…', // avafli_live_… in release builds
///     bundleId: 'com.example.myapp',
///     user: AvafliUser(id: 'user_123'), // or AvafliUser.guest
///   ));
/// }
///
/// class MyApp extends StatelessWidget {
///   const MyApp({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       navigatorKey: Avafli.navigatorKey, // REQUIRED: the drawer opens here
///       home: const HomeScreen(),
///     );
///   }
/// }
/// ```
///
/// Already have a root navigator key? Assign it before configuring:
/// `Avafli.navigatorKey = myRootKey;`. Boot flow that clears the stack
/// (`Get.offAll`, `pushAndRemoveUntil`)? Call [Avafli.holdAutoOpen] before
/// [Avafli.configure] and [Avafli.releaseAutoOpen] once your main screen is
/// mounted. Want to pick the moment yourself? Set
/// `autoOpen: AvafliAutoOpen.never` and call [Avafli.present].
library avafli_sdk;

// Core SDK. performOptOut is the in-experience "Delete my data" erasure and
// is deliberately NOT public: a host app must not be able to erase a
// person's Avafli data (3.3.3).
export 'src/avafli.dart' hide performOptOut;
export 'src/avafli_auto_open.dart';
export 'src/avafli_options.dart';
export 'src/avafli_configuration.dart';
export 'src/avafli_environment.dart';
export 'src/avafli_error.dart';
export 'src/avafli_user.dart';
export 'src/avafli_branding.dart';

// Domain Models
export 'src/domain/giveaway.dart';
export 'src/domain/sdk_config.dart';
export 'src/domain/streak_engine.dart';
export 'src/domain/streak_state.dart';
export 'src/domain/daily_entry_grant.dart';

// Analytics
export 'src/services/analytics/analytics_adapter.dart';

// Push Notifications
export 'src/services/push_notification_manager.dart';
