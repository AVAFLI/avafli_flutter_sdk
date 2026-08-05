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

  /// Experience behavior (V2 auto-open flow). Absent → SDK defaults apply.
  final WinrExperienceConfig? experience;

  /// Server-driven copy overrides. V2 uses only the email-consent line.
  final WinrSdkCopy? copy;

  const WinrSdkConfig({
    this.branding,
    this.rulesUrl,
    this.experience,
    this.copy,
  });

  factory WinrSdkConfig.fromJson(Map<String, dynamic> json) {
    return WinrSdkConfig(
      branding: json['branding'] is Map<String, dynamic>
          ? WinrSdkBranding.fromJson(json['branding'])
          : null,
      rulesUrl: json['rulesUrl'] as String?,
      experience: json['experience'] is Map<String, dynamic>
          ? WinrExperienceConfig.fromJson(json['experience'])
          : null,
      copy: json['copy'] is Map<String, dynamic>
          ? WinrSdkCopy.fromJson(json['copy'])
          : null,
    );
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

  const WinrSdkCopy({this.emailCapture, this.emailConsentText});

  factory WinrSdkCopy.fromJson(Map<String, dynamic> json) {
    return WinrSdkCopy(
      emailCapture: json['emailCapture'] is Map<String, dynamic>
          ? WinrEmailCaptureCopy.fromJson(json['emailCapture'])
          : null,
      emailConsentText: json['emailConsentText'] as String?,
    );
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

  const WinrEmailCaptureCopy({this.emailConsentText});

  factory WinrEmailCaptureCopy.fromJson(Map<String, dynamic> json) {
    return WinrEmailCaptureCopy(
      emailConsentText: json['emailConsentText'] as String?,
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
