/// Media configuration for WINR SDK screens.
/// 
/// Provides per-screen media URLs including both image and Lottie animation support.
class SdkMedia {
  final ScreenMedia? emailCapture;
  final ScreenMedia? streakDashboard;
  final ScreenMedia? bonusEntries;
  final ScreenMedia? milestone;
  final ScreenMedia? completed;
  final ScreenMedia? howItWorks;

  const SdkMedia({
    this.emailCapture,
    this.streakDashboard,
    this.bonusEntries,
    this.milestone,
    this.completed,
    this.howItWorks,
  });

  factory SdkMedia.fromJson(Map<String, dynamic> json) {
    return SdkMedia(
      emailCapture: json['emailCapture'] != null
          ? ScreenMedia.fromJson(json['emailCapture'])
          : null,
      streakDashboard: json['streakDashboard'] != null
          ? ScreenMedia.fromJson(json['streakDashboard'])
          : null,
      bonusEntries: json['bonusEntries'] != null
          ? ScreenMedia.fromJson(json['bonusEntries'])
          : null,
      milestone: json['milestone'] != null
          ? ScreenMedia.fromJson(json['milestone'])
          : null,
      completed: json['completed'] != null
          ? ScreenMedia.fromJson(json['completed'])
          : null,
      howItWorks: json['howItWorks'] != null
          ? ScreenMedia.fromJson(json['howItWorks'])
          : null,
    );
  }
}

/// Media configuration for a specific screen.
class ScreenMedia {
  final String? imageUrl;
  final String? lottieUrl;

  const ScreenMedia({
    this.imageUrl,
    this.lottieUrl,
  });

  factory ScreenMedia.fromJson(Map<String, dynamic> json) => ScreenMedia(
    imageUrl: json['imageUrl'] as String?,
    lottieUrl: json['lottieUrl'] as String?,
  );
}