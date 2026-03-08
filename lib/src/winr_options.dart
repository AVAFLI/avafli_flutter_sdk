import 'winr_environment.dart';
import 'winr_branding.dart';
import 'services/analytics/analytics_adapter.dart';
import 'rewards/rewarded_video_provider.dart';

/// Configuration options for the WINR SDK.
/// 
/// This class contains all the settings needed to initialize and customize
/// the WINR SDK behavior, including API credentials, environment settings,
/// branding, and feature toggles.
class WINROptions {
  /// Your WINR API key from the publisher dashboard
  final String apiKey;
  
  /// Target environment (production or staging)
  final WINREnvironment environment;
  
  /// Your app's bundle identifier (auto-detected if not provided)
  final String? bundleId;
  
  /// Visual branding and theme customization
  final WINRBranding branding;
  
  /// Logging level for SDK debug output
  final LoggingLevel logging;
  
  /// Custom analytics adapter for tracking events
  final AnalyticsAdapter? analyticsAdapter;
  
  /// Rewarded video provider for bonus entries
  final RewardedVideoProvider? rewardedVideoProvider;
  
  /// Whether to enable push notification reminders
  final bool enablePushReminders;
  
  /// Creates a new [WINROptions] configuration.
  /// 
  /// The [apiKey] is required and can be obtained from your WINR publisher dashboard.
  /// 
  /// Example:
  /// ```dart
  /// final options = WINROptions(
  ///   apiKey: 'your-api-key',
  ///   environment: WINREnvironment.production,
  ///   branding: WINRBranding.defaultBranding(),
  /// );
  /// ```
  WINROptions({
    required this.apiKey,
    this.environment = WINREnvironment.production,
    this.bundleId,
    WINRBranding? branding,
    this.logging = LoggingLevel.error,
    this.analyticsAdapter,
    this.rewardedVideoProvider,
    this.enablePushReminders = true,
  }) : branding = branding ?? WINRBranding.defaultBranding();
  
  /// Creates a copy of these options with the given fields replaced.
  WINROptions copyWith({
    String? apiKey,
    WINREnvironment? environment,
    String? bundleId,
    WINRBranding? branding,
    LoggingLevel? logging,
    AnalyticsAdapter? analyticsAdapter,
    RewardedVideoProvider? rewardedVideoProvider,
    bool? enablePushReminders,
  }) {
    return WINROptions(
      apiKey: apiKey ?? this.apiKey,
      environment: environment ?? this.environment,
      bundleId: bundleId ?? this.bundleId,
      branding: branding ?? this.branding,
      logging: logging ?? this.logging,
      analyticsAdapter: analyticsAdapter ?? this.analyticsAdapter,
      rewardedVideoProvider: rewardedVideoProvider ?? this.rewardedVideoProvider,
      enablePushReminders: enablePushReminders ?? this.enablePushReminders,
    );
  }
}

/// Logging levels for SDK debug output.
/// 
/// Controls how much diagnostic information the SDK will output
/// to help with development and troubleshooting.
enum LoggingLevel {
  /// No logging output
  none,
  
  /// Only error messages
  error,
  
  /// Error and info messages
  info,
  
  /// All messages including debug details
  debug,
}