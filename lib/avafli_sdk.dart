/// Avafli Flutter SDK
///
/// A sweepstakes and engagement SDK for Flutter applications.
///
/// This SDK provides:
/// - Daily streak engagement system (V2 auto-open bottom-drawer experience)
/// - Email capture and age verification
/// - Push notification support
/// - Analytics integration
/// - GDPR / RTD compliance features
///
/// Example usage:
/// ```dart
/// import 'package:avafli_sdk/avafli_sdk.dart';
///
/// // Configure the SDK with user (call once at app launch)
/// await Avafli.configure(AvafliConfiguration(
///   apiKey: 'YOUR_API_KEY',
///   environment: AvafliEnvironment.production,
///   bundleId: 'com.example.myapp',
///   user: AvafliUser(
///     id: 'user_123',
///     firstName: 'Jane',
///     lastName: 'Doe',
///   ),
/// ));
///
/// // Attach the SDK navigator key so the experience can auto-open on the
/// // first app-open of the day:
/// MaterialApp(navigatorKey: Avafli.navigatorKey, ...);
///
/// // Prefer to choose the moment yourself (e.g. after onboarding)? Set
/// // `autoOpen: AvafliAutoOpen.never` on the configuration and call
/// // `Avafli.present()` from your own code.
/// ```
library avafli_sdk;

// Core SDK
export 'src/avafli.dart';
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
