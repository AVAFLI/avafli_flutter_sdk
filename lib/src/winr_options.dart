import 'services/analytics/analytics_adapter.dart';

/// Optional behavior toggles for the WINR SDK.
///
/// These are non-required settings that customize SDK behavior.
/// Pass them to [WINRConfiguration.options] when configuring the SDK.
///
/// Example:
/// ```dart
/// final options = WINROptions(
///   logging: LoggingLevel.debug,
///   enablePushReminders: false,
/// );
/// ```
class WINROptions {
  /// Logging level for SDK debug output.
  final LoggingLevel logging;

  /// Custom analytics adapter for tracking events.
  final AnalyticsAdapter? analyticsAdapter;

  /// Whether to enable push notification reminders.
  final bool enablePushReminders;

  /// Creates a new [WINROptions] instance with optional behavior toggles.
  const WINROptions({
    this.logging = LoggingLevel.error,
    this.analyticsAdapter,
    this.enablePushReminders = true,
  });

  /// Creates a copy with the given fields replaced.
  WINROptions copyWith({
    LoggingLevel? logging,
    AnalyticsAdapter? analyticsAdapter,
    bool? enablePushReminders,
  }) {
    return WINROptions(
      logging: logging ?? this.logging,
      analyticsAdapter: analyticsAdapter ?? this.analyticsAdapter,
      enablePushReminders: enablePushReminders ?? this.enablePushReminders,
    );
  }
}

/// Logging levels for SDK debug output.
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
