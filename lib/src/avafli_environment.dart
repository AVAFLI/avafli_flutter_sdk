/// Defines the target environment for the Avafli SDK.
///
/// There is one backend. Use an `avafli_test_…` API key for an isolated
/// sandbox tenant in debug builds and CI, and your `avafli_live_…` key in
/// release builds.
enum AvafliEnvironment {
  /// The Avafli production backend (the only environment).
  production,
}
