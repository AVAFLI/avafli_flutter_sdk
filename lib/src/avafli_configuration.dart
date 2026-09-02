import 'avafli_branding.dart';
import 'avafli_options.dart';
import 'avafli_environment.dart';
import 'avafli_user.dart';

/// Required configuration for the Avafli SDK.
///
/// Contains the credentials and settings needed to initialize the SDK.
/// Optional behavior toggles live in [AvafliOptions].
///
/// Example:
/// ```dart
/// final config = AvafliConfiguration(
///   apiKey: 'YOUR_API_KEY',
///   environment: AvafliEnvironment.production,
///   bundleId: 'com.example.myapp',
///   user: AvafliUser(id: 'user_123'),
/// );
///
/// await Avafli.configure(config);
/// ```
class AvafliConfiguration {
  /// Your Avafli API key from the publisher dashboard. Required.
  final String apiKey;

  /// Target environment. Defaults to production.
  final AvafliEnvironment environment;

  /// The authenticated user. Required.
  final AvafliUser user;

  /// Your app's bundle identifier. Must match what's registered in the Avafli dashboard.
  final String bundleId;

  /// Optional behavior toggles (logging, analytics, push).
  final AvafliOptions options;

  /// Creates a new [AvafliConfiguration].
  ///
  /// [apiKey], [bundleId], and [user] are required.
  /// [options] defaults to [AvafliOptions()] if not provided.
  const AvafliConfiguration({
    required this.apiKey,
    this.environment = AvafliEnvironment.production,
    required this.bundleId,
    required this.user,
    this.options = const AvafliOptions(),
  });

  /// Default branding (server-driven overrides are merged at runtime).
  AvafliBranding get branding => AvafliBranding.defaultBranding();

  /// Base URL for the Cloud Functions backend.
  String get baseURL {
    return 'https://us-central1-winr-9c11f.cloudfunctions.net';
  }
}
