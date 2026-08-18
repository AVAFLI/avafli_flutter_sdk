/// Represents errors that can occur within the WINR SDK.
///
/// Each error type provides specific information about what went wrong
/// and can be used to implement appropriate error handling and user feedback.
enum WINRError {
  /// SDK has not been configured with [WINR.configure]
  notConfigured('SDK not configured. Call WINR.configure() first.'),

  /// No user has been set in configuration
  noUser('No user set. Pass WINRUser in WINRConfiguration.'),

  /// User already claimed their entries today
  ineligibleToday('Already claimed entries today. Try again tomorrow.'),

  /// Invalid API key provided
  invalidApiKey('Invalid API key provided.'),

  /// Network error occurred during API call
  networkError('Network error occurred. Check your connection.'),

  /// Authentication failed - invalid or expired token
  authenticationFailed('Authentication failed. Please try again.'),

  /// User is under the minimum age requirement (13)
  underage('Must be 13 or older to participate.'),

  /// Invalid email format provided
  invalidEmail('Invalid email format provided.'),

  /// A confirmed email is required before the user can enter. The backend
  /// consent gate rejects claims until the user submits their email — the SDK
  /// should (re-)present the email-capture screen rather than failing.
  emailRequired('Please confirm your email to enter.'),

  /// Giveaway is not active or available
  giveawayNotAvailable('Giveaway is not available at this time.'),

  /// User location is not allowed for this giveaway
  geographyNotAllowed('Giveaway not available in your location.'),

  /// Internal server error occurred
  serverError('Server error occurred. Please try again later.'),

  /// The WINR experience is no longer available for this publisher — the
  /// publisher account has been suspended or its API key revoked (typically
  /// due to a billing lapse). Surfaced from a failed device registration.
  serviceUnavailable('The WINR experience is no longer available.'),

  /// The user opted out (RTD — Right To Delete). The experience is
  /// permanently silenced on this device: it is never auto-presented again.
  optedOut('User has opted out of the WINR experience.'),

  /// Unknown or unexpected error
  unknown('An unexpected error occurred.'),

  /// SDK is in an invalid state
  invalidState('SDK is in an invalid state.'),

  /// No presenting view controller available
  noPresentingViewController('No presenting view controller available.');

  const WINRError(this.message);

  /// Human-readable error message
  final String message;

  @override
  String toString() => 'WINRError.$name: $message';
}

/// Exception wrapper for [WINRError] that can be thrown and caught.
///
/// Use this when you need to throw a WINR-specific error that can
/// be caught with a try-catch block.
class WINRException implements Exception {
  const WINRException(this.error, [this.serverMessage]);

  final WINRError error;

  /// The backend's actual error message, when one was returned. Lets the SDK
  /// surface what really went wrong instead of a generic enum description —
  /// e.g. a `failed-precondition` from the claim consent gate.
  final String? serverMessage;

  /// The best human-readable message: the server's text when present, else the
  /// enum's default description.
  String get displayMessage => serverMessage ?? error.message;

  @override
  String toString() => serverMessage == null
      ? error.toString()
      : 'WINRError.${error.name}: $serverMessage';
}
