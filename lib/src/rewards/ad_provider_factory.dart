import 'rewarded_video_provider.dart';

/// Factory class for creating ad provider instances.
/// 
/// Handles the creation of different rewarded video providers based on
/// configuration from the backend or SDK options.
class AdProviderFactory {
  /// Creates an ad provider based on the giveaway configuration.
  /// 
  /// [adNetwork] - The ad network identifier ('admob', 'unity', 'applovin', etc.)
  /// [adUnitId] - The ad unit ID for the specific network
  /// [testMode] - Whether to use test ads
  /// 
  /// Returns null if the ad network is not supported or not configured.
  static RewardedVideoProvider? create({
    String? adNetwork,
    String? adUnitId,
    bool testMode = false,
  }) {
    if (adNetwork == null || adUnitId == null) {
      return null;
    }
    
    switch (adNetwork.toLowerCase()) {
      case 'admob':
        return _createAdMobProvider(adUnitId, testMode);
      case 'unity':
        return _createUnityProvider(adUnitId, testMode);
      case 'applovin':
        return _createAppLovinProvider(adUnitId, testMode);
      case 'mock':
        return MockRewardedVideoProvider();
      default:
        return null;
    }
  }
  
  /// Creates an AdMob rewarded video provider.
  /// 
  /// Note: This requires the google_mobile_ads package to be added
  /// to your pubspec.yaml and proper AdMob configuration.
  static RewardedVideoProvider? _createAdMobProvider(String adUnitId, bool testMode) {
    // In a real implementation, this would return:
    // return AdMobRewardedVideoProvider(
    //   adUnitId: testMode ? 'ca-app-pub-3940256099942544/5224354917' : adUnitId,
    // );
    
    // For now, return mock provider
    return MockRewardedVideoProvider();
  }
  
  /// Creates a Unity Ads rewarded video provider.
  /// 
  /// Note: This requires the unity_ads_plugin package to be added
  /// to your pubspec.yaml and proper Unity Ads configuration.
  static RewardedVideoProvider? _createUnityProvider(String adUnitId, bool testMode) {
    // In a real implementation, this would return:
    // return UnityRewardedVideoProvider(
    //   adUnitId: adUnitId,
    //   testMode: testMode,
    // );
    
    // For now, return mock provider
    return MockRewardedVideoProvider();
  }
  
  /// Creates an AppLovin rewarded video provider.
  /// 
  /// Note: This requires the AppLovin MAX SDK to be added
  /// to your project and proper AppLovin configuration.
  static RewardedVideoProvider? _createAppLovinProvider(String adUnitId, bool testMode) {
    // In a real implementation, this would return:
    // return AppLovinRewardedVideoProvider(
    //   adUnitId: adUnitId,
    //   testMode: testMode,
    // );
    
    // For now, return mock provider
    return MockRewardedVideoProvider();
  }
  
  /// Gets the test ad unit ID for a given ad network.
  /// 
  /// These are safe test IDs provided by the ad networks that won't
  /// affect your production metrics.
  static String? getTestAdUnitId(String adNetwork) {
    switch (adNetwork.toLowerCase()) {
      case 'admob':
        return 'ca-app-pub-3940256099942544/5224354917'; // AdMob test rewarded ad unit
      case 'unity':
        return 'rewardedVideo'; // Unity default test placement
      case 'applovin':
        return 'YOUR_APPLOVIN_TEST_AD_UNIT_ID'; // Replace with actual AppLovin test ID
      default:
        return null;
    }
  }
}