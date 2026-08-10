// Every user-facing error/notice string in the V2 experience, centralized —
// this file IS the "User Message (UI)" column of the Master Field List.
// UI code must reference these constants, never re-type the copy inline, so
// the wording stays byte-identical across screens and matches the spec (and
// the iOS/Android SDKs) exactly.
//
// Rule of the house: users NEVER see raw backend text. Anything thrown as a
// `WINRException` keeps its `serverMessage` for logs only; what renders is
// always one of the strings below (or the quiet empty state).

/// User-facing copy for the V2 experience's error and notice states.
abstract final class WINRV2Strings {
  // ── Field validation (email capture + winner claim form) ──

  /// Inline error under the capture screen's email field.
  static const String invalidEmail = 'Please enter a valid email address.';

  /// Inline error under the claim form's First Name field.
  static const String invalidFirstName = 'Please enter a valid first name.';

  /// Inline error under the claim form's Last Name field.
  static const String invalidLastName = 'Please enter a valid last name.';

  /// Inline error under the claim form's optional phone field — shown only
  /// when a non-empty value doesn't normalize to 10 US digits.
  static const String invalidPhone =
      'Please enter a valid 10-digit mobile number.';

  // ── Email capture submit ──

  /// Inline, retryable error when the email submit fails in transit. The
  /// user stays on the capture screen — the SDK never proceeds as if the
  /// submit worked.
  static const String emailSubmitFailed =
      'Something went wrong sending your email. Please try again.';

  // ── Dashboard notices (non-blocking) ──

  /// Transient notice when the backend rejects a claim as already-claimed
  /// and local state didn't already know (e.g. entered on another device).
  static const String alreadyEnteredToday =
      "You've already entered today. Come back tomorrow to keep your streak "
      'going!';

  /// Notice when the daily auto-claim fails in transit — the dashboard shows
  /// the honest unclaimed state (never a fabricated success) plus this.
  static const String entryNotRecorded =
      "We couldn't record today's entry. Check your connection and try again.";

  /// Retry affordance on [entryNotRecorded].
  static const String tryAgain = 'TRY AGAIN';

  // ── Dedicated full-drawer states ──

  /// Geo-blocked ([WINRError.geographyNotAllowed]) headline.
  static const String geoBlockedHeadline = 'Not available in your location';

  /// Geo-blocked body.
  static const String geoBlockedBody =
      'This promotion is only available to users located in the United '
      'States. Please check your location settings or try again from an '
      'eligible location.';

  /// Session-expired state (token refresh AND re-registration both failed).
  static const String sessionExpired =
      'Your session has expired. Please try again.';

  /// The session-expired state's re-register/reload button.
  static const String retry = 'RETRY';
}
