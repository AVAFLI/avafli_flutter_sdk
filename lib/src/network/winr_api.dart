import 'package:http/http.dart' as http;
import 'api_request.dart';
import '../domain/giveaway.dart';
import '../domain/daily_entry_grant.dart';

/// Device registration request.
class RegisterDeviceRequest extends PostRequest<RegisterDeviceResponse> {
  @override
  bool get requiresAuth => false;

  final String apiKey;
  final String deviceFingerprint;
  final String bundleId;
  final String timezone;
  final String platformOS;
  final String sdkVersion;

  RegisterDeviceRequest({
    required this.apiKey,
    required this.deviceFingerprint,
    required this.bundleId,
    required this.timezone,
    required this.platformOS,
    required this.sdkVersion,
  });

  @override
  String get endpoint => '/registerDevice';

  @override
  Map<String, dynamic> get body => {
        'apiKey': apiKey,
        'deviceFingerprint': deviceFingerprint,
        'bundleId': bundleId,
        'timezone': timezone,
        'platformOS': platformOS,
        'sdkVersion': sdkVersion,
      };

  @override
  RegisterDeviceResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return RegisterDeviceResponse.fromJson(data);
  }
}

/// Response from device registration.
class RegisterDeviceResponse {
  final String token;
  final String refreshToken;
  final String uuid;
  final Giveaway? giveaway;
  final bool claimedToday;
  final int streakDay;
  final int totalEntries;
  final Map<String, dynamic>? sdkConfig;

  /// True when this device/person has opted out (RTD) — never auto-present.
  final bool? optedOut;

  /// Soft email-verification signal. Explicit `false` means the person typed a
  /// brand-new email that hasn't been confirmed yet — drive the "Verify your
  /// email" nudge. ABSENT/null for verified, partner-passed, adoption-verified,
  /// and no-email users. Only an explicit `false` counts as "unverified"; this
  /// NEVER gates play — it only affects prize-draw eligibility (server-side).
  final bool? emailVerified;

  /// Present only when this person is the drawn winner of one of this
  /// publisher's giveaways (winner prize-claim flow).
  final PrizeClaimBlock? prizeClaim;

  /// OPTIONAL (2.9, absent from current prod): true when this person started
  /// a verification-gated adoption (typed an existing email, never entered
  /// the 6-digit code). The next open calls `restageAdoption` and re-shows
  /// the code screen instead of email capture. Absent/null → normal flow.
  final bool? adoptionPending;

  const RegisterDeviceResponse({
    required this.token,
    required this.refreshToken,
    required this.uuid,
    this.giveaway,
    this.claimedToday = false,
    this.streakDay = 1,
    this.totalEntries = 0,
    this.sdkConfig,
    this.optedOut,
    this.emailVerified,
    this.prizeClaim,
    this.adoptionPending,
  });

  factory RegisterDeviceResponse.fromJson(Map<String, dynamic> json) {
    return RegisterDeviceResponse(
      token: json['token'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      uuid: json['uuid'] ?? '',
      giveaway:
          json['giveaway'] != null ? Giveaway.fromJson(json['giveaway']) : null,
      claimedToday: json['claimedToday'] ?? false,
      streakDay: json['streakDay'] ?? 1,
      totalEntries: json['totalEntries'] ?? 0,
      sdkConfig: json['sdkConfig'] as Map<String, dynamic>?,
      optedOut: json['optedOut'] as bool?,
      emailVerified: json['emailVerified'] as bool?,
      prizeClaim: json['prizeClaim'] is Map<String, dynamic>
          ? PrizeClaimBlock.fromJson(json['prizeClaim'])
          : null,
      adoptionPending: json['adoptionPending'] as bool?,
    );
  }
}

/// Token refresh request.
class RefreshTokenRequest extends PostRequest<RefreshTokenResponse> {
  @override
  bool get requiresAuth => false;

  final String refreshToken;

  RefreshTokenRequest({required this.refreshToken});

  @override
  String get endpoint => '/refreshToken';

  @override
  Map<String, dynamic> get body => {
        'refreshToken': refreshToken,
      };

  @override
  RefreshTokenResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return RefreshTokenResponse.fromJson(data);
  }
}

/// Response from token refresh.
class RefreshTokenResponse {
  final String token;
  final String refreshToken;

  const RefreshTokenResponse({
    required this.token,
    required this.refreshToken,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      token: json['token'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
    );
  }
}

/// Get active giveaway request.
///
/// Uses POST because the backend is a Firebase onCall function (POST-only).
class GetActiveGiveawayRequest extends PostRequest<GetActiveGiveawayResponse> {
  @override
  String get endpoint => '/getActiveGiveaway';

  @override
  Map<String, dynamic> get body => {};

  @override
  GetActiveGiveawayResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return GetActiveGiveawayResponse.fromJson(data);
  }
}

/// Response from get active giveaway.
class GetActiveGiveawayResponse {
  final Giveaway? giveaway;
  final bool claimedToday;
  final int streakDay;
  final int totalEntries;
  final int weeklyCurrent;
  final int monthlyCurrent;
  final int lifetimeCount;

  /// Whether this user has confirmed an email + consent. The SDK uses this to
  /// decide whether to show the email-capture screen — a registered device may
  /// not yet have a confirmed email, in which case a claim would be blocked by
  /// the backend consent gate.
  final bool emailConsentStatus;

  /// Soft email-verification signal (see [RegisterDeviceResponse.emailVerified]).
  /// Explicit `false` → the person typed a new, unconfirmed email; show the
  /// "Verify your email" nudge. ABSENT/null otherwise. NEVER gates play.
  final bool? emailVerified;
  final Map<String, dynamic>? sdkConfig;

  /// True when this person has opted out (RTD) — the SDK must never
  /// auto-present.
  final bool? optedOut;

  /// Present only when this person is the drawn winner of one of this
  /// publisher's giveaways and the winner record is still claimable.
  /// `status == "pending"` drives the winner splash → claim form flow;
  /// `"submitted"` means the form was already sent (normal dashboard shows).
  final PrizeClaimBlock? prizeClaim;

  /// OPTIONAL adoption re-entry signal (2.9) — see
  /// [RegisterDeviceResponse.adoptionPending]. Parsed here too because a
  /// device with a live token never re-registers; the status call is where
  /// the pending flag would actually arrive on a warm open. Null-safe against
  /// current prod (absent → null → normal flow).
  final bool? adoptionPending;

  const GetActiveGiveawayResponse({
    this.giveaway,
    this.claimedToday = false,
    this.streakDay = 1,
    this.totalEntries = 0,
    this.weeklyCurrent = 0,
    this.monthlyCurrent = 0,
    this.lifetimeCount = 0,
    this.emailConsentStatus = false,
    this.emailVerified,
    this.sdkConfig,
    this.optedOut,
    this.prizeClaim,
    this.adoptionPending,
  });

  factory GetActiveGiveawayResponse.fromJson(Map<String, dynamic> json) {
    return GetActiveGiveawayResponse(
      giveaway:
          json['giveaway'] != null ? Giveaway.fromJson(json['giveaway']) : null,
      claimedToday: json['claimedToday'] ?? false,
      streakDay: json['streakDay'] ?? 1,
      totalEntries: json['totalEntries'] ?? 0,
      weeklyCurrent: json['weeklyCurrent'] ?? 0,
      monthlyCurrent: json['monthlyCurrent'] ?? 0,
      lifetimeCount: json['lifetimeCount'] ?? 0,
      emailConsentStatus: json['emailConsentStatus'] ?? false,
      emailVerified: json['emailVerified'] as bool?,
      sdkConfig: json['sdkConfig'] as Map<String, dynamic>?,
      optedOut: json['optedOut'] as bool?,
      prizeClaim: json['prizeClaim'] is Map<String, dynamic>
          ? PrizeClaimBlock.fromJson(json['prizeClaim'])
          : null,
      adoptionPending: json['adoptionPending'] as bool?,
    );
  }
}

/// Claim daily entries request (mirrors iOS `ClaimDailyEntriesRequest`).
class ClaimDailyEntriesRequest extends PostRequest<ClaimDailyEntriesResponse> {
  final String timezone;
  final String platformOS;
  final String sdkVersion;

  ClaimDailyEntriesRequest({
    String? timezone,
    String? platformOS,
    String? sdkVersion,
  })  : timezone = timezone ?? DateTime.now().timeZoneName,
        platformOS = platformOS ?? WINRRequestDefaults.platformOS,
        sdkVersion = sdkVersion ?? WINRRequestDefaults.sdkVersion;

  @override
  String get endpoint => '/claimDailyEntries';

  @override
  Map<String, dynamic> get body => {
        'timezone': timezone,
        'platformOS': platformOS,
        'sdkVersion': sdkVersion,
      };

  @override
  ClaimDailyEntriesResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return ClaimDailyEntriesResponse.fromJson(data);
  }
}

/// Default request metadata, kept in sync by [WINR.configure]. Lives here so
/// request classes don't import the SDK facade (avoids an import cycle).
class WINRRequestDefaults {
  WINRRequestDefaults._();

  static String platformOS = 'iOS';
  static String sdkVersion = '2.8.2';
}

/// Response from claiming daily entries (mirrors iOS
/// `ClaimDailyEntriesResponse`).
class ClaimDailyEntriesResponse {
  /// Base entries from the daily ladder.
  final int entries;
  final int streakDay;
  final int totalEntries;
  final int? weeklyBonusEntries;
  final int? monthlyBonusEntries;
  final MilestoneAward? milestone;
  final int? monthlyCurrent;
  final int? weeklyCurrent;
  final int? lifetimeCount;
  final MilestoneAward? monthlyMilestone;

  const ClaimDailyEntriesResponse({
    required this.entries,
    required this.streakDay,
    required this.totalEntries,
    this.weeklyBonusEntries,
    this.monthlyBonusEntries,
    this.milestone,
    this.monthlyCurrent,
    this.weeklyCurrent,
    this.lifetimeCount,
    this.monthlyMilestone,
  });

  factory ClaimDailyEntriesResponse.fromJson(Map<String, dynamic> json) {
    return ClaimDailyEntriesResponse(
      entries: json['entries'] ?? json['baseEntries'] ?? 0,
      streakDay: json['streakDay'] ?? json['newStreakDay'] ?? 1,
      totalEntries: json['totalEntries'] ?? 0,
      weeklyBonusEntries: (json['weeklyBonusEntries'] as num?)?.toInt(),
      monthlyBonusEntries: (json['monthlyBonusEntries'] as num?)?.toInt(),
      milestone: json['milestone'] is Map<String, dynamic>
          ? MilestoneAward.fromJson(json['milestone'])
          : null,
      monthlyCurrent: (json['monthlyCurrent'] as num?)?.toInt(),
      weeklyCurrent: (json['weeklyCurrent'] as num?)?.toInt(),
      lifetimeCount: (json['lifetimeCount'] as num?)?.toInt(),
      monthlyMilestone: json['monthlyMilestone'] is Map<String, dynamic>
          ? MilestoneAward.fromJson(json['monthlyMilestone'])
          : null,
    );
  }

  /// Converts to a DailyEntryGrant.
  DailyEntryGrant toEntryGrant() {
    var bonus = 0;
    bonus += weeklyBonusEntries ?? 0;
    bonus += monthlyBonusEntries ?? 0;
    bonus += milestone?.bonusEntries ?? 0;
    bonus += monthlyMilestone?.bonusEntries ?? 0;
    return DailyEntryGrant(baseEntries: entries, bonusEntries: bonus);
  }
}

/// Milestone award returned when a user hits a streak milestone day.
class MilestoneAward {
  final int day;
  final int bonusEntries;
  final String? badge;

  const MilestoneAward({
    required this.day,
    required this.bonusEntries,
    this.badge,
  });

  factory MilestoneAward.fromJson(Map<String, dynamic> json) {
    return MilestoneAward(
      day: (json['day'] as num?)?.toInt() ?? 0,
      bonusEntries: (json['bonusEntries'] as num?)?.toInt() ?? 0,
      badge: json['badge'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Prize Claim (winner flow)
// ---------------------------------------------------------------------------

/// FIXED API contract, mirroring `PrizeClaimBlock` in the backend's types.ts
/// and the iOS SDK's `PrizeClaimBlock` (WINRAPI.swift).
class PrizeClaimBlock {
  /// "pending" | "submitted"
  final String status;
  final String giveawayId;
  final String prizeDescription;
  final double prizeValue;

  /// Display-only masked winning email ("d********r@winr.example.com") for
  /// the claim form's locked field. Absent from older backends.
  final String? maskedEmail;

  /// Present when submitted.
  final String? claimNumber;

  /// ISO date, when submitted.
  final String? submittedAt;

  const PrizeClaimBlock({
    required this.status,
    required this.giveawayId,
    required this.prizeDescription,
    required this.prizeValue,
    this.maskedEmail,
    this.claimNumber,
    this.submittedAt,
  });

  bool get isPending => status == 'pending';

  /// Lenient decode: a malformed block (null/missing prize fields from an
  /// older winner doc) must degrade gracefully, never fail the whole
  /// giveaway response and take the dashboard down with it (mirrors iOS).
  factory PrizeClaimBlock.fromJson(Map<String, dynamic> json) {
    return PrizeClaimBlock(
      status: json['status'] ?? '',
      giveawayId: json['giveawayId'] ?? '',
      prizeDescription: json['prizeDescription'] ?? 'Your prize',
      prizeValue: (json['prizeValue'] as num?)?.toDouble() ?? 0,
      maskedEmail: json['maskedEmail'] as String?,
      claimNumber: json['claimNumber'] as String?,
      submittedAt: json['submittedAt'] as String?,
    );
  }
}

/// Submit prize claim request (mirrors iOS `SubmitPrizeClaimRequest` — the
/// exact backend field names from functions/src/prizeclaim.ts).
class SubmitPrizeClaimRequest extends PostRequest<SubmitPrizeClaimResponse> {
  final String giveawayId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String street;
  final String? apt;
  final String city;
  final String state;
  final String zip;
  final String country;
  final String? photoBase64;
  final String? story;

  /// The (optional) likeness/promo checkbox on the review screen — permission
  /// to use the winner's name/likeness in promotional announcements. 2.9:
  /// the ONLY consent left on the review screen, no longer gates submit, and
  /// always sent so the backend records the actual choice.
  final bool promoConsentGranted;

  SubmitPrizeClaimRequest({
    required this.giveawayId,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.street,
    this.apt,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
    this.photoBase64,
    this.story,
    this.promoConsentGranted = false,
  });

  @override
  String get endpoint => '/submitPrizeClaim';

  @override
  Map<String, dynamic> get body => {
        'giveawayId': giveawayId,
        'firstName': firstName,
        'lastName': lastName,
        'street': street,
        'city': city,
        'state': state,
        'zip': zip,
        'country': country,
        'promoConsentGranted': promoConsentGranted,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (apt != null && apt!.isNotEmpty) 'apt': apt,
        if (photoBase64 != null) 'photoBase64': photoBase64,
        if (story != null && story!.isNotEmpty) 'story': story,
      };

  @override
  SubmitPrizeClaimResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return SubmitPrizeClaimResponse.fromJson(data);
  }
}

/// Response from submitting a prize claim.
class SubmitPrizeClaimResponse {
  final String claimNumber;

  /// ISO date.
  final String submittedAt;

  const SubmitPrizeClaimResponse({
    required this.claimNumber,
    required this.submittedAt,
  });

  factory SubmitPrizeClaimResponse.fromJson(Map<String, dynamic> json) {
    return SubmitPrizeClaimResponse(
      claimNumber: json['claimNumber'] ?? '',
      submittedAt: json['submittedAt'] ?? '',
    );
  }
}

/// Submit email request.
class SubmitEmailRequest extends PostRequest<SubmitEmailResponse> {
  final String email;

  /// The age-gate checkbox state, stored server-side as proof of the 18+
  /// affirmation. The CTA is gated on it, so it is true in practice — but it
  /// is always the REAL checkbox value, never a hardcoded literal.
  ///
  /// ALWAYS sent: the backend keys off the PRESENCE of this field to tell a
  /// 2.4.0+ client from a legacy one, so it must never be omitted.
  final bool ageConfirmed;

  /// The MARKETING consent checkbox state — permission to send the user
  /// promotional email, nothing more. Pre-checked, and the user may clear it
  /// and still enter, so this genuinely varies. Winner contact is operational
  /// and happens regardless of this value.
  final bool marketingConsent;

  final String? publisherUserId;

  SubmitEmailRequest({
    required this.email,
    required this.ageConfirmed,
    required this.marketingConsent,
    this.publisherUserId,
  });

  @override
  String get endpoint => '/submitEmail';

  @override
  Map<String, dynamic> get body => {
        'email': email,
        'ageConfirmed': ageConfirmed,
        'marketingConsent': marketingConsent,
        if (publisherUserId != null) 'publisherUserId': publisherUserId,
      };

  @override
  SubmitEmailResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return SubmitEmailResponse.fromJson(data);
  }
}

/// Response from submitting an email.
///
/// When the email matched an existing account under this publisher (from
/// another device/SDK), the backend adopts that canonical user so the streak
/// follows the person — [adopted] is true and [token]/[refreshToken]/[uuid]
/// carry the canonical user's credentials, which the SDK must switch to.
class SubmitEmailResponse {
  final bool success;
  final bool adopted;

  /// The typed email matches an EXISTING account and the OTP gate is on: no
  /// merge happened; show the 6-digit code screen and call verifyAdoptionCode.
  final bool verificationRequired;
  final String? uuid;
  final String? token;
  final String? refreshToken;

  /// Soft email-verification signal (see [RegisterDeviceResponse.emailVerified]).
  /// Explicit `false` means the person just typed a new, unconfirmed email —
  /// the SDK flips the "Verify your email" nudge on. NEVER gates play.
  final bool? emailVerified;

  /// True when the backend just dispatched a verification code to the typed
  /// inbox as part of this submit.
  final bool? emailVerificationSent;

  const SubmitEmailResponse({
    this.success = true,
    this.adopted = false,
    this.verificationRequired = false,
    this.uuid,
    this.token,
    this.refreshToken,
    this.emailVerified,
    this.emailVerificationSent,
  });

  factory SubmitEmailResponse.fromJson(Map<String, dynamic> json) {
    return SubmitEmailResponse(
      success: json['success'] ?? true,
      adopted: json['adopted'] ?? false,
      verificationRequired: json['verificationRequired'] ?? false,
      uuid: json['uuid'] as String?,
      token: json['token'] as String?,
      refreshToken: json['refreshToken'] as String?,
      emailVerified: json['emailVerified'] as bool?,
      emailVerificationSent: json['emailVerificationSent'] as bool?,
    );
  }
}

/// Completes a verification-gated adoption with the emailed 6-digit code.
/// The response is the same shape as an adopted SubmitEmailResponse.
class VerifyAdoptionCodeRequest extends PostRequest<SubmitEmailResponse> {
  final String code;
  VerifyAdoptionCodeRequest({required this.code});

  @override
  String get endpoint => '/verifyAdoptionCode';

  @override
  Map<String, dynamic> get body => {'code': code};

  @override
  SubmitEmailResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return SubmitEmailResponse.fromJson(data);
  }
}

/// Re-stages an interrupted verification-gated adoption (2.9): the person
/// typed an existing email, the code screen showed, and the app was killed
/// before they entered the 6-digit code. When a later register/status
/// response carries `adoptionPending: true`, the SDK calls this to have the
/// backend send a FRESH code to the email already on the pending adoption
/// (the SDK never persisted the raw address), then re-shows the code screen.
/// Same network-client pattern as [VerifyAdoptionCodeRequest]; the response
/// is `{sent: bool}`.
class RestageAdoptionRequest extends PostRequest<RestageAdoptionResponse> {
  @override
  String get endpoint => '/restageAdoption';

  @override
  Map<String, dynamic> get body => {};

  @override
  RestageAdoptionResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return RestageAdoptionResponse.fromJson(data);
  }
}

/// Response from [RestageAdoptionRequest].
class RestageAdoptionResponse {
  final bool sent;

  const RestageAdoptionResponse({this.sent = false});

  factory RestageAdoptionResponse.fromJson(Map<String, dynamic> json) {
    return RestageAdoptionResponse(sent: json['sent'] ?? false);
  }
}

/// Attaches the optional "please share a little" story to an ALREADY
/// SUBMITTED prize claim (2.9): the share step now runs post-submit, so the
/// story can't ride the submitPrizeClaim payload anymore. Fire-and-forget
/// from the SDK's side — the claim is already banked, so a failure must
/// never block or surface. Request `{story}`, response `{saved}`; same
/// authed client pattern as [RestageAdoptionRequest].
class AttachClaimStoryRequest extends PostRequest<AttachClaimStoryResponse> {
  final String story;

  AttachClaimStoryRequest({required this.story});

  @override
  String get endpoint => '/attachClaimStory';

  @override
  Map<String, dynamic> get body => {'story': story};

  @override
  AttachClaimStoryResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return AttachClaimStoryResponse.fromJson(data);
  }
}

/// Response from [AttachClaimStoryRequest].
class AttachClaimStoryResponse {
  final bool saved;

  const AttachClaimStoryResponse({this.saved = false});

  factory AttachClaimStoryResponse.fromJson(Map<String, dynamic> json) {
    return AttachClaimStoryResponse(saved: json['saved'] ?? false);
  }
}

/// Confirms a soft email verification with the emailed 6-digit code. Same
/// request/response envelope as [VerifyAdoptionCodeRequest]; on success the
/// backend returns `{verified: true}`. Failures throw a [WINRException] whose
/// server message mentions "expired"/"attempts"/mismatch — mapped to the same
/// UI copy the adoption flow uses.
class ConfirmEmailVerificationRequest
    extends PostRequest<EmailVerificationResponse> {
  final String code;
  ConfirmEmailVerificationRequest({required this.code});

  @override
  String get endpoint => '/confirmEmailVerification';

  @override
  Map<String, dynamic> get body => {'code': code};

  @override
  EmailVerificationResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return EmailVerificationResponse.fromJson(data);
  }
}

/// Response from [ConfirmEmailVerificationRequest].
class EmailVerificationResponse {
  final bool verified;

  const EmailVerificationResponse({this.verified = false});

  factory EmailVerificationResponse.fromJson(Map<String, dynamic> json) {
    return EmailVerificationResponse(verified: json['verified'] ?? false);
  }
}

/// Re-sends the soft email-verification code (no arguments). Mirrors the
/// adoption resend contract; returns `{sent: bool}`.
class ResendEmailVerificationRequest
    extends PostRequest<ResendEmailVerificationResponse> {
  @override
  String get endpoint => '/resendEmailVerification';

  @override
  Map<String, dynamic> get body => {};

  @override
  ResendEmailVerificationResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return ResendEmailVerificationResponse.fromJson(data);
  }
}

/// Response from [ResendEmailVerificationRequest].
class ResendEmailVerificationResponse {
  final bool sent;

  const ResendEmailVerificationResponse({this.sent = false});

  factory ResendEmailVerificationResponse.fromJson(Map<String, dynamic> json) {
    return ResendEmailVerificationResponse(sent: json['sent'] ?? false);
  }
}

/// Submit user profile request.
class SubmitUserProfileRequest extends PostRequest<SuccessResponse> {
  final String? firstName;
  final String? lastName;
  final String? phone;
  final bool? smsConsent;
  final String? maidId;
  final String? publisherUserId;

  SubmitUserProfileRequest({
    this.firstName,
    this.lastName,
    this.phone,
    this.smsConsent,
    this.maidId,
    this.publisherUserId,
  });

  @override
  String get endpoint => '/submitUserProfile';

  @override
  Map<String, dynamic> get body => {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phone != null) 'phone': phone,
        if (smsConsent != null) 'smsConsent': smsConsent,
        if (maidId != null) 'maidId': maidId,
        if (publisherUserId != null) 'publisherUserId': publisherUserId,
      };

  @override
  SuccessResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return SuccessResponse.fromJson(data);
  }
}

/// Register push token request.
class RegisterPushTokenRequest extends PostRequest<SuccessResponse> {
  final String pushToken;
  final String platform;

  RegisterPushTokenRequest({
    required this.pushToken,
    required this.platform,
  });

  @override
  String get endpoint => '/registerPushToken';

  @override
  Map<String, dynamic> get body => {
        // Backend contract is {token, platform} — 'pushToken' is rejected.
        'token': pushToken,
        'platform': platform,
      };

  @override
  SuccessResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return SuccessResponse.fromJson(data);
  }
}

/// Delete user data request (GDPR).
/// Opt-out request (RTD — Right To Delete). Tombstones the person on the
/// backend and permanently silences the experience on this device.
class OptOutRequest extends PostRequest<SuccessResponse> {
  @override
  String get endpoint => '/optOut';

  @override
  Map<String, dynamic> get body => {};

  @override
  SuccessResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return SuccessResponse.fromJson(data);
  }
}
