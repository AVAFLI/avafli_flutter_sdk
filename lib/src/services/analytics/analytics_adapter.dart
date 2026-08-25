/// Abstract interface for analytics tracking.
///
/// Provides a pluggable analytics system that allows apps to integrate
/// with their preferred analytics provider (Firebase, Mixpanel, etc.)
/// while keeping the Avafli SDK analytics-agnostic.
abstract class AnalyticsAdapter {
  /// Tracks an event with optional parameters.
  ///
  /// [eventName] should be a descriptive name for the event.
  /// [parameters] can contain additional context data.
  ///
  /// Example:
  /// ```dart
  /// analytics.track('avafli_daily_claim', {
  ///   'streak_day': 3,
  ///   'entries_granted': 60,
  ///   'bonus_entries': 0,
  /// });
  /// ```
  void track(String eventName, [Map<String, dynamic>? parameters]);

  /// Sets a user property for analytics.
  ///
  /// Used to attach persistent attributes to the user profile
  /// for segmentation and analysis.
  ///
  /// Example:
  /// ```dart
  /// analytics.setUserProperty('avafli_user_tier', 'premium');
  /// ```
  void setUserProperty(String name, String value);

  /// Identifies a user for analytics tracking.
  ///
  /// Should be called when a user is set in the SDK.
  void identify(String userId);
}

/// Built-in analytics events tracked by the Avafli SDK.
class AvafliAnalyticsEvents {
  // Configuration events
  static const String sdkConfigured = 'avafli_sdk_configured';
  static const String userSet = 'avafli_user_set';

  // Experience events
  static const String experiencePresented = 'avafli_experience_presented';
  static const String experienceDismissed = 'avafli_experience_dismissed';

  // Claim events
  static const String dailyEntriesClaimed = 'avafli_daily_entries_claimed';
  static const String claimFailed = 'avafli_claim_failed';

  // Email capture events
  static const String emailCaptureStarted = 'avafli_email_capture_started';
  static const String emailCaptureCompleted = 'avafli_email_capture_completed';
  static const String emailCaptureFailed = 'avafli_email_capture_failed';

  // Streak events
  static const String streakBroken = 'avafli_streak_broken';

  // Error events
  static const String error = 'avafli_error';
  static const String networkError = 'avafli_network_error';

  // Prevent instantiation
  AvafliAnalyticsEvents._();
}
