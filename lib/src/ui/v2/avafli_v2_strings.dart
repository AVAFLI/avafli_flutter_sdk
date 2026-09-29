// Every user-facing error/notice string in the V2 experience, centralized —
// this file IS the "User Message (UI)" column of the Master Field List.
// UI code must reference these constants, never re-type the copy inline, so
// the wording stays byte-identical across screens and matches the spec (and
// the iOS/Android SDKs) exactly.
//
// Rule of the house: users NEVER see raw backend text. Anything thrown as a
// `AvafliException` keeps its `serverMessage` for logs only; what renders is
// always one of the strings below (or the quiet empty state).
//
// One exception (3.2.0): the prize-claim email-ownership step. Its backend
// rejections carry a machine-readable `reason` and a message WRITTEN for the
// person (claimverify.ts), so the claim code screen shows that message — with
// the matching constant below as the fallback when none arrives.

/// User-facing copy for the V2 experience's error and notice states.
abstract final class AvafliV2Strings {
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

  // ── Adoption code entry (cross-device merge) ──

  /// Code check failed because the code is stale (backend message mentions
  /// "expired"). Actionable: the user should request a fresh one.
  static const String codeExpired =
      "That code expired. Tap 'Send a new code' to get a fresh one.";

  /// Code check failed after too many wrong tries (backend message mentions
  /// "attempts").
  static const String codeTooManyAttempts =
      'Too many attempts. Request a new code.';

  /// Code check failed for any other reason (wrong digits) — the default.
  static const String codeIncorrect =
      "That code didn't match. Check the email and try again.";

  /// Resend request failed in transit. The code screen STAYS UP; this shows
  /// in the same inline error slot so the user is never stranded on capture.
  static const String codeResendFailed =
      "Couldn't send a new code. Check your connection and try again.";

  /// Subtitle on the reused 6-digit code screen when an INTERRUPTED adoption
  /// is re-staged (register/status carried `adoptionPending: true` and
  /// `restageAdoption` just sent a fresh code). No address interpolation —
  /// the raw email was never persisted locally.
  static const String adoptionRestagedSubtitle =
      "Let's pick up where you left off. We just sent a fresh 6-digit code "
      'to your email — enter it below to continue.';

  // ── Prize-claim email-ownership step (code before the claim form) ──

  /// Subtitle on the claim code screen. [maskedEmail] is the backend-masked
  /// address from the `prizeClaim` block — the SDK never holds the raw one.
  /// No trailing period: it would read as part of the address.
  static String claimCodeSubtitle(String? maskedEmail) {
    final address = maskedEmail?.trim();
    return 'Enter the 6-digit code we sent to '
        '${address == null || address.isEmpty ? 'your email' : address}';
  }

  /// Small inline status while the send is in flight.
  static const String claimCodeSending = 'Sending your code…';

  /// Small inline status once a send went out (`sent: true`). A re-used live
  /// code (`sent: false`) shows nothing extra.
  static const String claimCodeSent = 'Code sent';

  /// Wrong digits (`code_mismatch`) with the tries left on this code.
  static String claimCodeMismatch(int attemptsRemaining) =>
      "That code didn't match. $attemptsRemaining "
      "${attemptsRemaining == 1 ? 'try' : 'tries'} left.";

  /// Fallback for `fresh_code_sent` when the backend sent no message: the
  /// code was dead and a new one is ALREADY on its way. Informational — not
  /// styled as an error.
  static const String claimCodeFreshSent =
      'That code expired, so we sent you a new one. Check your email.';

  /// Fallback for `resend_cooldown`; the button's countdown carries the time.
  static const String claimCodeResendCooldown =
      'Please wait a moment before requesting another code.';

  /// Fallback for `send_limit` (5 sends per hour).
  static const String claimCodeSendLimit =
      "You've requested several codes. Please try again in a little while, "
      'or contact info@avafli.com.';

  /// Fallback for `send_failed` — shown with [claimCodeRetry].
  static const String claimCodeSendFailed =
      "We couldn't send your code just now. Please try again in a minute.";

  /// Fallback for `no_email_on_file`.
  static const String claimCodeNoEmailOnFile =
      "We don't have an email on file for this account. Contact "
      'info@avafli.com to claim your prize.';

  /// A send or a code check never reached the backend. What the person typed
  /// is kept.
  static const String claimCodeNetworkError =
      "We couldn't reach the server. Check your connection and try again.";

  /// The retry affordance beside a failed send.
  static const String claimCodeRetry = 'Try again';

  /// "Send a new code" while it is locked, with the live countdown.
  static String claimCodeResendIn(Duration remaining) {
    final seconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
    final minutes = seconds ~/ 60;
    return 'Send a new code in '
        "$minutes:${(seconds % 60).toString().padLeft(2, '0')}";
  }

  /// Help line under the code screen's actions (copy half).
  static const String claimCodeHelp = "Can't get to this email? ";

  /// Help line (link half) — opens a mailto: to [supportEmail].
  static const String claimCodeHelpLink = 'Contact info@avafli.com';

  /// The contact address every dead end points at.
  static const String supportEmail = 'info@avafli.com';

  /// Brief confirmation after the code is accepted, before the claim form.
  static const String claimCodeVerified = 'Email verified ✓';

  // ── Soft email verification (persistent dashboard chip → code screen) ──

  /// The persistent, tappable chip on the streak dashboard shown while the
  /// person's newly-typed email is unverified. Non-blocking nudge — daily play,
  /// auto-claim, and the streak keep working; only prize-draw eligibility is
  /// affected (server-side).
  static const String emailVerifyChip = 'Verify your email';

  /// Header on the reused 6-digit code screen when it's confirming an email
  /// (rather than adopting a cross-device streak).
  static const String emailVerifyTitle = 'Verify your email';

  /// Subtitle on that screen — no address interpolation (unlike adoption).
  static const String emailVerifySubtitle =
      "Enter the 6-digit code we sent to your inbox so you're eligible to win.";

  /// Brief transient dashboard notice shown after a successful confirm, just
  /// before the chip disappears.
  static const String emailVerifiedNotice = 'Email verified ✓';

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

  // ── Winner share (post-submit share step) ──

  /// Confirmation shown after a share action copied the winner line to the
  /// clipboard (Instagram/Snapchat/TikTok have no text-prefill APIs, and
  /// Facebook falls back here when no shareUrl is configured).
  static const String shareCopied = 'Copied — paste it in your post';

  // ── Legal webview / RTD opt-out ──

  /// The in-app legal webview couldn't load its page (offline, DNS, server
  /// error) — shown with a RETRY affordance; we never leave a blank sheet.
  static const String legalLoadFailed =
      "We couldn't load this page. Check your connection and try again.";

  /// The destructive confirmation's title.
  static const String optOutTitle = 'Delete my data & stop participating';

  /// The destructive confirmation's body (3.2.0: deletion blocks this email
  /// and device for 24 hours, not forever).
  static const String optOutBody =
      'This permanently erases your information and ends your participation. '
      'Entries and streaks are forfeited and cannot be restored. You can join '
      'again as a new participant after 24 hours.';

  /// The destructive confirm button.
  static const String optOutConfirm = 'DELETE MY DATA';

  /// The confirmation's cancel affordance.
  static const String optOutCancel = 'Cancel';

  /// Brief success state shown before the experience dismisses itself.
  static const String optOutSuccess = 'Your data has been deleted.';

  /// The opt-out call failed — the confirmation stays up and can retry. We
  /// never pretend the deletion succeeded.
  static const String optOutFailed =
      'Something went wrong. Please check your connection and try again.';

  // ── Dedicated full-drawer states ──

  /// Geo-blocked ([AvafliError.geographyNotAllowed]) headline.
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
