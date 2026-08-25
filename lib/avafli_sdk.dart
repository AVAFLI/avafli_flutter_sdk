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
///   apiKey: 'winr_live_xxxxxxxxxx',
///   environment: AvafliEnvironment.production,
///   bundleId: 'com.example.myapp',
///   user: AvafliUser(
///     id: 'user123',
///     firstName: 'Jane',
///     lastName: 'Doe',
///   ),
/// ));
///
/// // Attach the SDK navigator key so the experience can auto-open on the
/// // first app-open of the day (the experience presents itself; there is
/// // no manual launch API):
/// MaterialApp(navigatorKey: Avafli.navigatorKey, ...);
/// ```
library avafli_sdk;

// Core SDK
export 'src/avafli.dart';
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
