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
  /// Example of what the SDK sends when the day's entries are granted:
  /// ```dart
  /// analytics.track('avafli_daily_entry_claimed', {
  ///   'day': 3,
  ///   'entries': 60,
  /// });
  /// ```
  void track(String eventName, [Map<String, dynamic>? parameters]);

  /// Sets a user property for analytics.
  ///
  /// Part of the adapter contract so your integration can forward
  /// properties; the SDK itself sets none in 3.3.1.
  void setUserProperty(String name, String value);

  /// Identifies a user for analytics tracking.
  ///
  /// Called from [Avafli.configure] with [AvafliUser.id] for a non-guest
  /// user.
  void identify(String userId);
}

/// Analytics event names.
///
/// Emitted by 3.3.1: [sdkConfigured], [experiencePresented],
/// [experienceDismissed], plus the literals `avafli_daily_entry_claimed`
/// (`day`, `entries`, and when present `weekly_bonus`, `monthly_bonus`,
/// `milestone_day`, `milestone_bonus`, `recovered_offline`),
/// `avafli_email_verified`, `avafli_winner_claim_shown` (`giveaway_id`) and
/// `avafli_prize_claim_submitted` (`giveaway_id`, `claim_number`). Events
/// emitted while offline are buffered and flushed later with
/// `original_timestamp` / `original_timestamp_ms` added.
///
/// The remaining constants are reserved names that 3.3.1 does not emit.
class AvafliAnalyticsEvents {
  /// `configure()` ran.
  static const String sdkConfigured = 'avafli_sdk_configured';

  /// Reserved — not emitted.
  static const String userSet = 'avafli_user_set';

  /// The drawer opened (auto-open or `present()`).
  static const String experiencePresented = 'avafli_experience_presented';

  /// The drawer closed without a new claim.
  static const String experienceDismissed = 'avafli_experience_dismissed';

  /// Reserved — not emitted. The grant event is the literal
  /// `avafli_daily_entry_claimed` (singular), matching the other Avafli SDKs.
  static const String dailyEntriesClaimed = 'avafli_daily_entries_claimed';

  /// Reserved — not emitted.
  static const String claimFailed = 'avafli_claim_failed';

  /// Reserved — not emitted.
  static const String emailCaptureStarted = 'avafli_email_capture_started';

  /// Reserved — not emitted.
  static const String emailCaptureCompleted = 'avafli_email_capture_completed';

  /// Reserved — not emitted.
  static const String emailCaptureFailed = 'avafli_email_capture_failed';

  /// Reserved — not emitted.
  static const String streakBroken = 'avafli_streak_broken';

  /// Reserved — not emitted.
  static const String error = 'avafli_error';

  /// Reserved — not emitted.
  static const String networkError = 'avafli_network_error';

  // Prevent instantiation
  AvafliAnalyticsEvents._();
}
