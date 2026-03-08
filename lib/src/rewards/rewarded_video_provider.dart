import 'dart:ui' show VoidCallback;

/// Abstract interface for rewarded video ad providers.
/// 
/// This allows the WINR SDK to integrate with any ad network
/// (AdMob, Unity Ads, AppLovin, etc.) through a common interface.
abstract class RewardedVideoProvider {
  /// Checks if a rewarded video ad is available to show.
  Future<bool> isAdAvailable();
  
  /// Loads a rewarded video ad.
  /// 
  /// Should be called proactively to ensure ads are ready when needed.
  Future<void> loadAd();
  
  /// Shows a rewarded video ad and returns whether it was completed.
  /// 
  /// Returns `true` if the user watched the ad to completion and should
  /// receive the reward, `false` otherwise.
  Future<bool> showAd();
  
  /// Sets a callback to be notified when ads are loaded.
  void setOnAdLoadedCallback(VoidCallback callback);
  
  /// Sets a callback to be notified when ad loading fails.
  void setOnAdFailedCallback(Function(String error) callback);
}

/// Example implementation for testing/demo purposes.
/// 
/// This provider simulates ad behavior without actually showing ads.
/// Use this for development and testing when you don't have ads configured.
class MockRewardedVideoProvider implements RewardedVideoProvider {
  bool _isLoaded = false;
  VoidCallback? _onAdLoaded;
  Function(String)? _onAdFailed;
  
  /// Duration to simulate ad loading time
  final Duration loadingDelay;
  
  /// Duration to simulate ad watching time
  final Duration watchingDelay;
  
  /// Whether to simulate ad loading failures
  final bool shouldFail;
  
  /// Creates a mock ad provider with configurable behavior.
  MockRewardedVideoProvider({
    this.loadingDelay = const Duration(seconds: 2),
    this.watchingDelay = const Duration(seconds: 15),
    this.shouldFail = false,
  });
  
  @override
  Future<bool> isAdAvailable() async {
    return _isLoaded;
  }
  
  @override
  Future<void> loadAd() async {
    _isLoaded = false;
    
    await Future.delayed(loadingDelay);
    
    if (shouldFail) {
      _onAdFailed?.call('Simulated ad loading failure');
      return;
    }
    
    _isLoaded = true;
    _onAdLoaded?.call();
  }
  
  @override
  Future<bool> showAd() async {
    if (!_isLoaded) {
      return false;
    }
    
    await Future.delayed(watchingDelay);
    _isLoaded = false;
    return true;
  }
  
  @override
  void setOnAdLoadedCallback(VoidCallback callback) {
    _onAdLoaded = callback;
  }
  
  @override
  void setOnAdFailedCallback(Function(String error) callback) {
    _onAdFailed = callback;
  }
}
