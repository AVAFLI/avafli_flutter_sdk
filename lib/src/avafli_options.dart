import 'services/analytics/analytics_adapter.dart';

/// Optional behavior toggles for the Avafli SDK.
///
/// These are non-required settings that customize SDK behavior.
/// Pass them to [AvafliConfiguration.options] when configuring the SDK.
///
/// Example:
/// ```dart
/// final options = AvafliOptions(
///   logging: LoggingLevel.debug,
///   enablePushReminders: false,
/// );
/// ```
class AvafliOptions {
  /// Logging level for SDK debug output.
  final LoggingLevel logging;

  /// Custom analytics adapter for tracking events.
  final AnalyticsAdapter? analyticsAdapter;

  /// Whether to enable push notification reminders.
  final bool enablePushReminders;

  /// Creates a new [AvafliOptions] instance with optional behavior toggles.
  const AvafliOptions({
    this.logging = LoggingLevel.error,
    this.analyticsAdapter,
    this.enablePushReminders = true,
  });

  /// Creates a copy with the given fields replaced.
  AvafliOptions copyWith({
    LoggingLevel? logging,
    AnalyticsAdapter? analyticsAdapter,
    bool? enablePushReminders,
  }) {
    return AvafliOptions(
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
