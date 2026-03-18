/// WINR Flutter SDK
/// 
/// A comprehensive sweepstakes and engagement SDK for Flutter applications.
/// 
/// This SDK provides:
/// - Daily streak engagement system
/// - Rewarded video integrations
/// - Email capture and age verification
/// - Push notification support
/// - Analytics integration
/// - GDPR compliance features
/// - Customizable UI themes and branding
/// 
/// Example usage:
/// ```dart
/// import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';
/// 
/// // Initialize the SDK
/// await WINR.configure(WINRConfiguration(
///   apiKey: 'winr_live_xxxxxxxxxx',
///   environment: WINREnvironment.production,
/// ));
/// 
/// // Set user information
/// WINR.setUser(WINRUser(id: 'user123'));
/// 
/// // Present the experience
/// WINR.present(context);
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
export 'src/domain/streak_engine.dart';
export 'src/domain/streak_state.dart';
export 'src/domain/daily_entry_grant.dart';

// UI Components
export 'src/ui/winr_experience_screen.dart';
export 'src/ui/winr_experience_card.dart';
export 'src/ui/how_it_works_view.dart';
export 'src/ui/winr_theme.dart';

// Analytics
export 'src/services/analytics/analytics_adapter.dart';

// Rewards
export 'src/rewards/rewarded_video_provider.dart';