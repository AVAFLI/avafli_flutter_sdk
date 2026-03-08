import 'winr_options.dart';
import 'winr_environment.dart';
import 'winr_branding.dart';

/// Internal configuration state for the WINR SDK.
/// 
/// This class holds the processed configuration after [WINR.configure] is called.
/// It includes resolved values like the actual bundle ID and other computed settings.
class WINRConfiguration {
  /// The WINR API key
  final String apiKey;
  
  /// Target environment
  final WINREnvironment environment;
  
  /// Resolved bundle identifier
  final String bundleId;
  
  /// Visual branding configuration
  final WINRBranding branding;
  
  /// Original options passed to configure
  final WINROptions options;
  
  /// Creates a new configuration instance.
  const WINRConfiguration({
    required this.apiKey,
    required this.environment,
    required this.bundleId,
    required this.branding,
    required this.options,
  });
  
  /// Creates a configuration from [WINROptions], resolving any missing values.
  factory WINRConfiguration.fromOptions(WINROptions options, String bundleId) {
    return WINRConfiguration(
      apiKey: options.apiKey,
      environment: options.environment,
      bundleId: bundleId,
      branding: options.branding,
      options: options,
    );
  }
  
  /// Base URL for the Cloud Functions backend based on environment.
  String get baseURL {
    // All environments currently point to the same project
    // This can be split later if needed for staging
    return 'https://us-central1-winr-9c11f.cloudfunctions.net';
  }
}