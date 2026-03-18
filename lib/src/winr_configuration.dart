import 'winr_branding.dart';
import 'winr_options.dart';
import 'winr_environment.dart';

/// Required configuration for the WINR SDK.
///
/// Contains the credentials and settings needed to initialize the SDK.
/// Optional behavior toggles live in [WINROptions].
///
/// Example:
/// ```dart
/// final config = WINRConfiguration(
///   apiKey: 'winr_live_xxxxxxxxxx',
///   environment: WINREnvironment.production,
/// );
///
/// await WINR.configure(config);
/// ```
class WINRConfiguration {
  /// Your WINR API key from the publisher dashboard. Required.
  final String apiKey;

  /// Target environment (production or staging). Required.
  final WINREnvironment environment;

  /// Your app's bundle identifier. Auto-detected if not provided.
  final String? bundleId;

  /// Optional behavior toggles (logging, analytics, push, rewarded video).
  final WINROptions options;

  /// Creates a new [WINRConfiguration].
  ///
  /// [apiKey] and [environment] are required.
  /// [options] defaults to [WINROptions()] if not provided.
  const WINRConfiguration({
    required this.apiKey,
    this.environment = WINREnvironment.production,
    this.bundleId,
    this.options = const WINROptions(),
  });

  /// Default branding (server-driven overrides are merged at runtime).
  WINRBranding get branding => WINRBranding.defaultBranding();

  /// Base URL for the Cloud Functions backend based on environment.
  String get baseURL {
    return 'https://us-central1-winr-9c11f.cloudfunctions.net';
  }
}
