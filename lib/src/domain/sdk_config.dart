/// Typed view over the server-driven `sdkConfig` payload (mirrors the iOS
/// SDK's `SDKConfigResponse` / `ExperienceConfig` in WINRAPI.swift).
///
/// V2 hardcodes the design; publishers can customize ONLY their logo, prize
/// image, and primary color — so this parses just what V2 needs plus the
/// experience behavior flags.
class WinrSdkConfig {
  /// Publisher branding (primary color + logo).
  final WinrSdkBranding? branding;

  /// Publisher-level official-rules URL fallback.
  final String? rulesUrl;

  /// OPTIONAL (2.9, arriving in sdkConfig): the publisher's share landing
  /// URL, appended to the winner-share text (X intent) and used as the
  /// Facebook sharer target. Absent from current prod → the share actions
  /// degrade gracefully (text-only tweet, clipboard fallback for Facebook).
  final String? shareUrl;

  /// OPTIONAL publisher display name for the winner-share line
  /// ("I just won {prize} in {appName}!"). Absent → the "in {appName}"
  /// clause is dropped rather than interpolating a guess.
  final String? appName;

  /// OPTIONAL Google Places (New) API key
  /// (config/integrations.placesApiKey, client-shippable by design).
  /// Present → the claim address step's street field offers address
  /// autocomplete; absent → the field is a plain text input (exactly the
  /// pre-2.9 behavior).
  final String? placesApiKey;

  /// Experience behavior (V2 auto-open flow). Absent → SDK defaults apply.
  final WinrExperienceConfig? experience;

  /// Server-driven copy overrides. V2 uses only the email-consent line.
  final WinrSdkCopy? copy;

  /// Whether the capture-screen age gate is shown (top-level config, mirrors
  /// the web SDK's `SDKConfig.ageGateEnabled`). Absent → SDK default (true).
  final bool? ageGateEnabled;

  /// Publisher's configured minimum age. Drives the age-gate fallback
  /// sentence when the server sends no explicit `ageGateText`. Absent → 18.
  final int? ageGateMinAge;

  const WinrSdkConfig({
    this.branding,
    this.rulesUrl,
    this.shareUrl,
    this.appName,
    this.placesApiKey,
    this.experience,
    this.copy,
    this.ageGateEnabled,
    this.ageGateMinAge,
  });

  factory WinrSdkConfig.fromJson(Map<String, dynamic> json) {
    return WinrSdkConfig(
      branding: json['branding'] is Map<String, dynamic>
          ? WinrSdkBranding.fromJson(json['branding'])
          : null,
      rulesUrl: json['rulesUrl'] as String?,
      shareUrl: json['shareUrl'] as String?,
      appName: json['appName'] as String?,
      placesApiKey: json['placesApiKey'] as String?,
      experience: json['experience'] is Map<String, dynamic>
          ? WinrExperienceConfig.fromJson(json['experience'])
          : null,
      copy: json['copy'] is Map<String, dynamic>
          ? WinrSdkCopy.fromJson(json['copy'])
          : null,
      ageGateEnabled: json['ageGateEnabled'] as bool?,
      ageGateMinAge: (json['ageGateMinAge'] as num?)?.toInt(),
    );
  }

  /// Resolved AGE-GATE label for the capture screen. A COMPLIANCE string, so
  /// it must never contradict the publisher's configured minimum age: the
  /// server-provided `ageGateText` wins verbatim (nested per-screen, then flat
  /// legacy); only when absent is the sentence BUILT from [ageGateMinAge]
  /// (default 18) — never a hardcoded "18". Mirrors the web SDK's
  /// `WINRV2Controller.ageGateText`.
  String get resolvedAgeGateText {
    final serverText = copy?.resolvedAgeGateText;
    if (serverText != null) return serverText;
    final minAge = ageGateMinAge ?? 18;
    return 'I confirm I am $minAge years of age or older';
  }

  /// Null-tolerant convenience parser.
  static WinrSdkConfig? tryParse(Map<String, dynamic>? json) =>
      json == null ? null : WinrSdkConfig.fromJson(json);
}

/// Server-driven copy overrides (mirrors the iOS SDK's `SDKCopyConfig`).
///
/// The backend emits per-screen nested objects; older payloads carried a few
/// flat fields instead. Both shapes are parsed so the SDK reads whichever the
/// publisher's dashboard happens to send.
class WinrSdkCopy {
  /// Nested per-screen copy (current backend format).
  final WinrEmailCaptureCopy? emailCapture;

  /// Flat legacy field, kept as a fallback for older payloads.
  final String? emailConsentText;

  /// Flat legacy age-gate label, kept as a fallback for older payloads.
  final String? ageGateText;

  const WinrSdkCopy({
    this.emailCapture,
    this.emailConsentText,
    this.ageGateText,
  });

  factory WinrSdkCopy.fromJson(Map<String, dynamic> json) {
    return WinrSdkCopy(
      emailCapture: json['emailCapture'] is Map<String, dynamic>
          ? WinrEmailCaptureCopy.fromJson(json['emailCapture'])
          : null,
      emailConsentText: json['emailConsentText'] as String?,
      ageGateText: json['ageGateText'] as String?,
    );
  }

  /// The publisher's explicit AGE-GATE label, if any. Nested per-screen value
  /// wins; the flat legacy field is the fallback. Null when the server said
  /// nothing, so the caller BUILDS the sentence from the minimum age instead.
  String? get resolvedAgeGateText {
    final nested = emailCapture?.ageGateText;
    if (nested != null && nested.isNotEmpty) return nested;
    final flat = ageGateText;
    if (flat != null && flat.isNotEmpty) return flat;
    return null;
  }

  /// The MARKETING consent line for the capture screen. The wire key is
  /// historically named `emailConsentText`; it carries a publisher-named
  /// string ("I agree to receive marketing emails from {PublisherName}")
  /// interpolated SERVER-side.
  ///
  /// Nested value wins; the flat legacy field is the fallback. Null when the
  /// server said nothing, so the caller applies the SDK default literal.
  String? get resolvedEmailConsentText {
    final nested = emailCapture?.emailConsentText;
    if (nested != null && nested.isNotEmpty) return nested;
    final flat = emailConsentText;
    if (flat != null && flat.isNotEmpty) return flat;
    return null;
  }
}

/// Email-capture screen copy. V2 hardcodes the design and only honors the
/// consent line, but the field is namespaced with the rest of the screen's
/// copy so the backend contract matches the other WINR SDKs.
class WinrEmailCaptureCopy {
  /// Marketing-consent line, e.g. "I agree to receive marketing emails from
  /// {PublisherName}" with the name already substituted by the backend.
  final String? emailConsentText;

  /// Publisher-authored AGE-GATE label, e.g. "I confirm I am 21 years of age
  /// or older". Rendered verbatim; overrides the SDK's built sentence.
  final String? ageGateText;

  const WinrEmailCaptureCopy({this.emailConsentText, this.ageGateText});

  factory WinrEmailCaptureCopy.fromJson(Map<String, dynamic> json) {
    return WinrEmailCaptureCopy(
      emailConsentText: json['emailConsentText'] as String?,
      ageGateText: json['ageGateText'] as String?,
    );
  }
}

/// Publisher branding config — only the V2 publisher-configurable bits.
class WinrSdkBranding {
  /// Hex string like "#268FFF"; drives the accent color.
  final String? primaryColor;

  /// URL of the publisher logo shown in the drawer header.
  final String? logoUrl;

  const WinrSdkBranding({this.primaryColor, this.logoUrl});

  factory WinrSdkBranding.fromJson(Map<String, dynamic> json) {
    return WinrSdkBranding(
      primaryColor: json['primaryColor'] as String?,
      logoUrl: json['logoUrl'] as String?,
    );
  }
}

/// Server-driven experience behavior flags (mirrors iOS `ExperienceConfig`).
class WinrExperienceConfig {
  /// Auto-present the experience on the first app-open of the day
  /// (default true).
  final bool? autoOpenEnabled;

  /// How many times an unregistered (no-email) user sees the auto-presented
  /// experience before it goes quiet (default 3 — MVP decision).
  final int? unregisteredImpressionCap;

  /// Dismissal requires an explicit tap; never auto-fade (default true).
  final bool? requireDismissClick;

  const WinrExperienceConfig({
    this.autoOpenEnabled,
    this.unregisteredImpressionCap,
    this.requireDismissClick,
  });

  factory WinrExperienceConfig.fromJson(Map<String, dynamic> json) {
    return WinrExperienceConfig(
      autoOpenEnabled: json['autoOpenEnabled'] as bool?,
      unregisteredImpressionCap:
          (json['unregisteredImpressionCap'] as num?)?.toInt(),
      requireDismissClick: json['requireDismissClick'] as bool?,
    );
  }
}
