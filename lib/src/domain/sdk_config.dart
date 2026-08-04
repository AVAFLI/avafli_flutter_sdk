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

  const WinrSdkConfig({this.branding, this.rulesUrl, this.experience});

  factory WinrSdkConfig.fromJson(Map<String, dynamic> json) {
    return WinrSdkConfig(
      branding: json['branding'] is Map<String, dynamic>
          ? WinrSdkBranding.fromJson(json['branding'])
          : null,
      rulesUrl: json['rulesUrl'] as String?,
      experience: json['experience'] is Map<String, dynamic>
          ? WinrExperienceConfig.fromJson(json['experience'])
          : null,
    );
  }

  /// Null-tolerant convenience parser.
  static WinrSdkConfig? tryParse(Map<String, dynamic>? json) =>
      json == null ? null : WinrSdkConfig.fromJson(json);
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
