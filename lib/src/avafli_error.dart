/// Represents errors that can occur within the Avafli SDK.
///
/// Each error type provides specific information about what went wrong
/// and can be used to implement appropriate error handling and user feedback.
enum AvafliError {
  /// SDK has not been configured with [Avafli.configure]
  notConfigured('SDK not configured. Call Avafli.configure() first.'),

  /// No user has been set in configuration
  noUser('No user set. Pass AvafliUser in AvafliConfiguration.'),

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

  /// The Avafli experience is no longer available for this publisher — the
  /// publisher account has been suspended or its API key revoked (typically
  /// due to a billing lapse). Surfaced from a failed device registration.
  serviceUnavailable('The Avafli experience is no longer available.'),

  /// The user opted out (RTD — Right To Delete). The experience is silenced
  /// on this device for 24 hours; after that the person may join again as a
  /// brand-new participant.
  optedOut('User has opted out of the Avafli experience.'),

  /// Unknown or unexpected error
  unknown('An unexpected error occurred.'),

  /// SDK is in an invalid state
  invalidState('SDK is in an invalid state.'),

  /// No presenting view controller available
  noPresentingViewController('No presenting view controller available.');

  const AvafliError(this.message);

  /// Human-readable error message
  final String message;

  @override
  String toString() => 'AvafliError.$name: $message';
}

/// Exception wrapper for [AvafliError] that can be thrown and caught.
///
/// Use this when you need to throw an Avafli-specific error that can
/// be caught with a try-catch block.
class AvafliException implements Exception {
  const AvafliException(this.error,
      [this.serverMessage,
      this.transport = false,
      this.details,
      this.retryable = false])
      : statusCode = null,
        retryAfter = null;

  /// An infrastructure refusal: the platform answered 429/5xx WITHOUT a
  /// callable error body (plain text, HTML, empty — e.g. Cloud Run's "no
  /// available instance" while instances warm up). Not a transport failure
  /// (the server did answer) and not an app error (no function ran), so the
  /// network client's bounded jittered backoff retries it before anything
  /// is surfaced. [retryAfter] carries a `Retry-After` header when present.
  const AvafliException.infraRefusal(this.error,
      {required this.statusCode, this.serverMessage, this.retryAfter})
      : transport = false,
        details = null,
        retryable = true;

  final AvafliError error;

  /// True when the request never completed — a genuine transport failure
  /// (offline, DNS, socket timeout), as opposed to an HTTP response that was
  /// merely MAPPED to [AvafliError.networkError]. The offline retry queue
  /// keys off this: only transport failures are safe to retry automatically.
  /// Stamped by the network client's transport catch blocks.
  final bool transport;

  /// True when the request may safely be re-sent as-is: an infrastructure
  /// refusal (429/5xx with a non-callable body — see
  /// [AvafliException.infraRefusal]). The network client's request loop
  /// retries these on a jittered backoff (1 s, 2 s, 4 s, 8 s base) and only
  /// surfaces the error once that schedule is exhausted — at which point
  /// `retryable` is still true, but the offline queue does NOT enqueue it
  /// (the server answered; it was just busy). Always false for app errors
  /// (a parsable callable error body) and for transport failures.
  final bool retryable;

  /// The HTTP status of an infrastructure refusal; null otherwise.
  final int? statusCode;

  /// The server's `Retry-After` hint on an infrastructure refusal, if any.
  final Duration? retryAfter;

  /// The backend's actual error message, when one was returned. Lets the SDK
  /// surface what really went wrong instead of a generic enum description —
  /// e.g. a `failed-precondition` from the claim consent gate.
  final String? serverMessage;

  /// The backend's structured error payload (`error.details` of the callable
  /// envelope), when one was returned — e.g. `{reason: "code_mismatch",
  /// attemptsRemaining: 4}` from the prize-claim email-ownership step. Null
  /// for every error that carries none.
  final Map<String, dynamic>? details;

  /// The machine-readable rejection reason from [details], if any.
  String? get reason {
    final value = details?['reason'];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// The best human-readable message: the server's text when present, else the
  /// enum's default description.
  String get displayMessage => serverMessage ?? error.message;

  @override
  String toString() => serverMessage == null
      ? error.toString()
      : 'AvafliError.${error.name}: $serverMessage';
}
