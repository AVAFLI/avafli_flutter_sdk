/// Abstract interface for analytics tracking.
/// 
/// Provides a pluggable analytics system that allows apps to integrate
/// with their preferred analytics provider (Firebase, Mixpanel, etc.)
/// while keeping the WINR SDK analytics-agnostic.
abstract class AnalyticsAdapter {
  /// Tracks an event with optional parameters.
  /// 
  /// [eventName] should be a descriptive name for the event.
  /// [parameters] can contain additional context data.
  /// 
  /// Example:
  /// ```dart
  /// analytics.track('winr_daily_claim', {
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
  /// analytics.setUserProperty('winr_user_tier', 'premium');
  /// ```
  void setUserProperty(String name, String value);
  
  /// Identifies a user for analytics tracking.
  /// 
  /// Should be called when a user is set in the SDK.
  void identify(String userId);
}

/// Built-in analytics events tracked by the WINR SDK.
class WINRAnalyticsEvents {
  // Configuration events
  static const String sdkConfigured = 'winr_sdk_configured';
  static const String userSet = 'winr_user_set';
  
  // Experience events
  static const String experiencePresented = 'winr_experience_presented';
  static const String experienceDismissed = 'winr_experience_dismissed';
  
  // Claim events
  static const String dailyEntriesClaimed = 'winr_daily_entries_claimed';
  static const String claimFailed = 'winr_claim_failed';
  
  // Email capture events
  static const String emailCaptureStarted = 'winr_email_capture_started';
  static const String emailCaptureCompleted = 'winr_email_capture_completed';
  static const String emailCaptureFailed = 'winr_email_capture_failed';
  
  // Streak events
  static const String streakBroken = 'winr_streak_broken';
  
  // Error events
  static const String error = 'winr_error';
  static const String networkError = 'winr_network_error';
  
  // Prevent instantiation
  WINRAnalyticsEvents._();
}