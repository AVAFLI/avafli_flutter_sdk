/// The `prizeClaim.verification` block (3.2.0): the email-ownership step a
/// winner completes before the claim form opens. FIXED API contract,
/// mirroring `ClaimVerificationBlock` in the backend's claimverify.ts.
///
/// The SERVER holds all of this state — nothing here is ever persisted
/// locally. A winner who closes the drawer, kills the app or switches device
/// reads the same block back and resumes where they were.
class ClaimVerification {
  /// False → the inbox is already proven; go straight to the claim form.
  final bool required;

  /// When the live code was sent. Present = a live code exists.
  final DateTime? codeSentAt;

  /// [codeSentAt] + 10 minutes.
  final DateTime? codeExpiresAt;

  /// [codeSentAt] + 60 seconds — when "Send a new code" unlocks.
  final DateTime? resendAvailableAt;

  const ClaimVerification({
    required this.required,
    this.codeSentAt,
    this.codeExpiresAt,
    this.resendAvailableAt,
  });

  /// Lenient decode (same stance as `PrizeClaimBlock`): a malformed date
  /// degrades to "no live code", never a failed giveaway response.
  factory ClaimVerification.fromJson(Map<String, dynamic> json) {
    return ClaimVerification(
      required: json['required'] == true,
      codeSentAt: _parseIso(json['codeSentAt']),
      codeExpiresAt: _parseIso(json['codeExpiresAt']),
      resendAvailableAt: _parseIso(json['resendAvailableAt']),
    );
  }

  static DateTime? _parseIso(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// How long "Send a new code" stays locked, measured from [now] on THIS
  /// device's clock. Zero when there is no live code or the wait is over.
  ///
  /// The server's timestamps are on the server's clock, so the wait is capped
  /// at the block's own cooldown length ([resendAvailableAt] − [codeSentAt]):
  /// a device whose clock runs behind can never be locked out for longer than
  /// the cooldown itself.
  Duration resendWait(DateTime now) {
    final available = resendAvailableAt;
    if (available == null) return Duration.zero;
    var wait = available.difference(now);
    final sent = codeSentAt;
    if (sent != null) {
      final cooldown = available.difference(sent);
      if (wait > cooldown) wait = cooldown;
    }
    return wait.isNegative ? Duration.zero : wait;
  }
}
