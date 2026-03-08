/// Defines the target environment for the WINR SDK.
/// 
/// Different environments may point to different backend infrastructure
/// and have different security configurations.
enum WINREnvironment {
  /// Production environment for live applications
  production,
  
  /// Staging environment for testing and development
  staging,
}