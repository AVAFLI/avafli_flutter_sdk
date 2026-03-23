import 'package:http/http.dart' as http;
import 'api_request.dart';
import '../domain/giveaway.dart';
import '../domain/daily_entry_grant.dart';

/// Device registration request.
class RegisterDeviceRequest extends PostRequest<RegisterDeviceResponse> {
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
  final Map<String, dynamic>? sdkConfig;
  
  const RegisterDeviceResponse({
    required this.token,
    required this.refreshToken,
    required this.uuid,
    this.giveaway,
    this.claimedToday = false,
    this.streakDay = 1,
    this.sdkConfig,
  });
  
  factory RegisterDeviceResponse.fromJson(Map<String, dynamic> json) {
    return RegisterDeviceResponse(
      token: json['token'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      uuid: json['uuid'] ?? '',
      giveaway: json['giveaway'] != null
          ? Giveaway.fromJson(json['giveaway'])
          : null,
      claimedToday: json['claimedToday'] ?? false,
      streakDay: json['streakDay'] ?? 1,
      sdkConfig: json['sdkConfig'] as Map<String, dynamic>?,
    );
  }
}

/// Token refresh request.
class RefreshTokenRequest extends PostRequest<RefreshTokenResponse> {
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
  final Map<String, dynamic>? sdkConfig;
  
  const GetActiveGiveawayResponse({
    this.giveaway,
    this.claimedToday = false,
    this.streakDay = 1,
    this.sdkConfig,
  });
  
  factory GetActiveGiveawayResponse.fromJson(Map<String, dynamic> json) {
    return GetActiveGiveawayResponse(
      giveaway: json['giveaway'] != null
          ? Giveaway.fromJson(json['giveaway'])
          : null,
      claimedToday: json['claimedToday'] ?? false,
      streakDay: json['streakDay'] ?? 1,
      sdkConfig: json['sdkConfig'] as Map<String, dynamic>?,
    );
  }
}

/// Claim daily entries request.
class ClaimDailyEntriesRequest extends PostRequest<ClaimDailyEntriesResponse> {
  @override
  String get endpoint => '/claimDailyEntries';
  
  @override
  Map<String, dynamic> get body => {};
  
  @override
  ClaimDailyEntriesResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return ClaimDailyEntriesResponse.fromJson(data);
  }
}

/// Response from claiming daily entries.
class ClaimDailyEntriesResponse {
  final int baseEntries;
  final int bonusEntries;
  final int newStreakDay;
  final bool weeklyBonusEarned;
  final bool monthlyBonusEarned;
  
  const ClaimDailyEntriesResponse({
    required this.baseEntries,
    this.bonusEntries = 0,
    required this.newStreakDay,
    this.weeklyBonusEarned = false,
    this.monthlyBonusEarned = false,
  });
  
  factory ClaimDailyEntriesResponse.fromJson(Map<String, dynamic> json) {
    return ClaimDailyEntriesResponse(
      baseEntries: json['baseEntries'] ?? 0,
      bonusEntries: json['bonusEntries'] ?? 0,
      newStreakDay: json['newStreakDay'] ?? 1,
      weeklyBonusEarned: json['weeklyBonusEarned'] ?? false,
      monthlyBonusEarned: json['monthlyBonusEarned'] ?? false,
    );
  }
  
  /// Converts to a DailyEntryGrant.
  DailyEntryGrant toEntryGrant() {
    return DailyEntryGrant(
      baseEntries: baseEntries,
      bonusEntries: bonusEntries,
    );
  }
}

/// Claim bonus entries (from rewarded video) request.
class ClaimBonusEntriesRequest extends PostRequest<ClaimBonusEntriesResponse> {
  @override
  String get endpoint => '/claimBonusEntries';
  
  @override
  Map<String, dynamic> get body => {};
  
  @override
  ClaimBonusEntriesResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return ClaimBonusEntriesResponse.fromJson(data);
  }
}

/// Response from claiming bonus entries.
class ClaimBonusEntriesResponse {
  final int bonusEntries;
  
  const ClaimBonusEntriesResponse({required this.bonusEntries});
  
  factory ClaimBonusEntriesResponse.fromJson(Map<String, dynamic> json) {
    return ClaimBonusEntriesResponse(
      bonusEntries: json['bonusEntries'] ?? 0,
    );
  }
}

/// Submit email request.
class SubmitEmailRequest extends PostRequest<SuccessResponse> {
  final String email;
  final bool hasConsent;
  final String? publisherUserId;
  
  SubmitEmailRequest({
    required this.email,
    required this.hasConsent,
    this.publisherUserId,
  });
  
  @override
  String get endpoint => '/submitEmail';
  
  @override
  Map<String, dynamic> get body => {
    'email': email,
    'marketingConsent': hasConsent,
    if (publisherUserId != null) 'publisherUserId': publisherUserId,
  };
  
  @override
  SuccessResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return SuccessResponse.fromJson(data);
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
    'pushToken': pushToken,
    'platform': platform,
  };
  
  @override
  SuccessResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return SuccessResponse.fromJson(data);
  }
}

/// Delete user data request (GDPR).
class DeleteUserDataRequest extends PostRequest<SuccessResponse> {
  @override
  String get endpoint => '/deleteUserData';
  
  @override
  Map<String, dynamic> get body => {};
  
  @override
  SuccessResponse parseResponse(http.Response response) {
    final data = parseJsonResponse(response);
    return SuccessResponse.fromJson(data);
  }
}