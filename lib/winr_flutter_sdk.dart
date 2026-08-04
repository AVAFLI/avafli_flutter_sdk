/// WINR Flutter SDK
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
/// import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';
///
/// // Configure the SDK with user (call once at app launch)
/// await WINR.configure(WINRConfiguration(
///   apiKey: 'winr_live_xxxxxxxxxx',
///   environment: WINREnvironment.production,
///   bundleId: 'com.example.myapp',
///   user: WINRUser(
///     id: 'user123',
///     firstName: 'Jane',
///     lastName: 'Doe',
///   ),
/// ));
///
/// // Attach the SDK navigator key so the experience can auto-open on the
/// // first app-open of the day (the experience presents itself; there is
/// // no manual launch API):
/// MaterialApp(navigatorKey: WINR.navigatorKey, ...);
/// ```
library winr_flutter_sdk;

// Core SDK
export 'src/winr.dart';
export 'src/winr_options.dart';
export 'src/winr_configuration.dart';
export 'src/winr_environment.dart';
export 'src/winr_error.dart';
export 'src/winr_user.dart';
export 'src/winr_branding.dart';

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
