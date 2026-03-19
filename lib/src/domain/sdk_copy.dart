/// Server-driven copy configuration for WINR SDK screens.
/// 
/// Provides nested per-screen copy objects with fallback support to flat fields
/// for backward compatibility.
class SdkCopy {
  final EmailCaptureCopy? emailCapture;
  final StreakDashboardCopy? streakDashboard;
  final AlreadyClaimedCopy? alreadyClaimed;
  final BonusEntriesCopy? bonusEntries;
  final MilestoneCopy? milestone;
  final CompletedCopy? completed;
  final ErrorCopy? error;
  final HowItWorksCopy? howItWorks;
  final LoadingCopy? loading;
  final NoActiveGiveawayCopy? noActiveGiveaway;

  // Flat backward compatibility fields
  final String? welcomeTitle;
  final String? welcomeSubtitle;
  final String? dailyClaimButton;
  final String? streakMessage;
  final String? emailConsentText;
  final String? ageGateText;
  final String? rulesLinkText;

  const SdkCopy({
    this.emailCapture,
    this.streakDashboard,
    this.alreadyClaimed,
    this.bonusEntries,
    this.milestone,
    this.completed,
    this.error,
    this.howItWorks,
    this.loading,
    this.noActiveGiveaway,
    this.welcomeTitle,
    this.welcomeSubtitle,
    this.dailyClaimButton,
    this.streakMessage,
    this.emailConsentText,
    this.ageGateText,
    this.rulesLinkText,
  });

  factory SdkCopy.fromJson(Map<String, dynamic> json) {
    return SdkCopy(
      emailCapture: json['emailCapture'] != null
          ? EmailCaptureCopy.fromJson(json['emailCapture'])
          : null,
      streakDashboard: json['streakDashboard'] != null
          ? StreakDashboardCopy.fromJson(json['streakDashboard'])
          : null,
      alreadyClaimed: json['alreadyClaimed'] != null
          ? AlreadyClaimedCopy.fromJson(json['alreadyClaimed'])
          : null,
      bonusEntries: json['bonusEntries'] != null
          ? BonusEntriesCopy.fromJson(json['bonusEntries'])
          : null,
      milestone: json['milestone'] != null
          ? MilestoneCopy.fromJson(json['milestone'])
          : null,
      completed: json['completed'] != null
          ? CompletedCopy.fromJson(json['completed'])
          : null,
      error: json['error'] != null
          ? ErrorCopy.fromJson(json['error'])
          : null,
      howItWorks: json['howItWorks'] != null
          ? HowItWorksCopy.fromJson(json['howItWorks'])
          : null,
      loading: json['loading'] != null
          ? LoadingCopy.fromJson(json['loading'])
          : null,
      noActiveGiveaway: json['noActiveGiveaway'] != null
          ? NoActiveGiveawayCopy.fromJson(json['noActiveGiveaway'])
          : null,
      // Flat backward compatibility fields
      welcomeTitle: json['welcomeTitle'] as String?,
      welcomeSubtitle: json['welcomeSubtitle'] as String?,
      dailyClaimButton: json['dailyClaimButton'] as String?,
      streakMessage: json['streakMessage'] as String?,
      emailConsentText: json['emailConsentText'] as String?,
      ageGateText: json['ageGateText'] as String?,
      rulesLinkText: json['rulesLinkText'] as String?,
    );
  }
}

/// Copy configuration for email capture screen.
class EmailCaptureCopy {
  final String? title;
  final String? subtitle;
  final String? emailLabel;
  final String? emailPlaceholder;
  final String? ageGateText;
  final String? submitButton;
  final String? rulesPrefix;
  final String? rulesLinkText;
  final String? emailConsentText;
  final String? prizeHeadline;

  const EmailCaptureCopy({
    this.title,
    this.subtitle,
    this.emailLabel,
    this.emailPlaceholder,
    this.ageGateText,
    this.submitButton,
    this.rulesPrefix,
    this.rulesLinkText,
    this.emailConsentText,
    this.prizeHeadline,
  });

  factory EmailCaptureCopy.fromJson(Map<String, dynamic> json) {
    return EmailCaptureCopy(
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      emailLabel: json['emailLabel'] as String?,
      emailPlaceholder: json['emailPlaceholder'] as String?,
      ageGateText: json['ageGateText'] as String?,
      submitButton: json['submitButton'] as String?,
      rulesPrefix: json['rulesPrefix'] as String?,
      rulesLinkText: json['rulesLinkText'] as String?,
      emailConsentText: json['emailConsentText'] as String?,
      prizeHeadline: json['prizeHeadline'] as String?,
    );
  }
}

/// Copy configuration for streak dashboard screen.
class StreakDashboardCopy {
  final String? streakMessage;
  final String? upcomingLabel;
  final String? claimButton;
  final String? dayRewardLabel;
  final String? claimDescription;
  final String? entriesLabel;
  final String? bonusProgress;
  final String? weekLabel;
  final String? monthLabel;
  final String? bonusEarned;
  final String? alreadyClaimedTitle;
  final String? alreadyClaimedSubtitle;
  final String? doneButton;
  final String? prizeHeadline;

  const StreakDashboardCopy({
    this.streakMessage,
    this.upcomingLabel,
    this.claimButton,
    this.dayRewardLabel,
    this.claimDescription,
    this.entriesLabel,
    this.bonusProgress,
    this.weekLabel,
    this.monthLabel,
    this.bonusEarned,
    this.alreadyClaimedTitle,
    this.alreadyClaimedSubtitle,
    this.doneButton,
    this.prizeHeadline,
  });

  factory StreakDashboardCopy.fromJson(Map<String, dynamic> json) {
    return StreakDashboardCopy(
      streakMessage: json['streakMessage'] as String?,
      upcomingLabel: json['upcomingLabel'] as String?,
      claimButton: json['claimButton'] as String?,
      dayRewardLabel: json['dayRewardLabel'] as String?,
      claimDescription: json['claimDescription'] as String?,
      entriesLabel: json['entriesLabel'] as String?,
      bonusProgress: json['bonusProgress'] as String?,
      weekLabel: json['weekLabel'] as String?,
      monthLabel: json['monthLabel'] as String?,
      bonusEarned: json['bonusEarned'] as String?,
      alreadyClaimedTitle: json['alreadyClaimedTitle'] as String?,
      alreadyClaimedSubtitle: json['alreadyClaimedSubtitle'] as String?,
      doneButton: json['doneButton'] as String?,
      prizeHeadline: json['prizeHeadline'] as String?,
    );
  }
}

/// Copy configuration for already claimed state.
class AlreadyClaimedCopy {
  final String? title;
  final String? subtitle;
  final String? doneButton;

  const AlreadyClaimedCopy({
    this.title,
    this.subtitle,
    this.doneButton,
  });

  factory AlreadyClaimedCopy.fromJson(Map<String, dynamic> json) {
    return AlreadyClaimedCopy(
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      doneButton: json['doneButton'] as String?,
    );
  }
}

/// Copy configuration for bonus entries screen.
class BonusEntriesCopy {
  final String? title;
  final String? subtitle;
  final String? watchButton;
  final String? skipText;

  const BonusEntriesCopy({
    this.title,
    this.subtitle,
    this.watchButton,
    this.skipText,
  });

  factory BonusEntriesCopy.fromJson(Map<String, dynamic> json) {
    return BonusEntriesCopy(
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      watchButton: json['watchButton'] as String?,
      skipText: json['skipText'] as String?,
    );
  }
}

/// Copy configuration for milestone screen.
class MilestoneCopy {
  final String? title;
  final String? subtitle;
  final String? continueButton;

  const MilestoneCopy({
    this.title,
    this.subtitle,
    this.continueButton,
  });

  factory MilestoneCopy.fromJson(Map<String, dynamic> json) {
    return MilestoneCopy(
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      continueButton: json['continueButton'] as String?,
    );
  }
}

/// Copy configuration for completed screen.
class CompletedCopy {
  final String? title;
  final String? subtitle;
  final String? closeButton;

  const CompletedCopy({
    this.title,
    this.subtitle,
    this.closeButton,
  });

  factory CompletedCopy.fromJson(Map<String, dynamic> json) {
    return CompletedCopy(
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      closeButton: json['closeButton'] as String?,
    );
  }
}

/// Copy configuration for error screen.
class ErrorCopy {
  final String? title;
  final String? subtitle;
  final String? closeButton;

  const ErrorCopy({
    this.title,
    this.subtitle,
    this.closeButton,
  });

  factory ErrorCopy.fromJson(Map<String, dynamic> json) {
    return ErrorCopy(
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      closeButton: json['closeButton'] as String?,
    );
  }
}

/// Copy configuration for how it works screen.
class HowItWorksCopy {
  final String? title;
  final String? subtitle;
  final String? step1Title;
  final String? step1Description;
  final String? step2Title;
  final String? step2Description;
  final String? step3Title;
  final String? step3Description;
  final String? step4Title;
  final String? step4Description;
  final String? tip;
  final String? gotItButton;

  const HowItWorksCopy({
    this.title,
    this.subtitle,
    this.step1Title,
    this.step1Description,
    this.step2Title,
    this.step2Description,
    this.step3Title,
    this.step3Description,
    this.step4Title,
    this.step4Description,
    this.tip,
    this.gotItButton,
  });

  factory HowItWorksCopy.fromJson(Map<String, dynamic> json) {
    return HowItWorksCopy(
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      step1Title: json['step1Title'] as String?,
      step1Description: json['step1Description'] as String?,
      step2Title: json['step2Title'] as String?,
      step2Description: json['step2Description'] as String?,
      step3Title: json['step3Title'] as String?,
      step3Description: json['step3Description'] as String?,
      step4Title: json['step4Title'] as String?,
      step4Description: json['step4Description'] as String?,
      tip: json['tip'] as String?,
      gotItButton: json['gotItButton'] as String?,
    );
  }
}

/// Copy configuration for loading screen.
class LoadingCopy {
  final String? text;

  const LoadingCopy({
    this.text,
  });

  factory LoadingCopy.fromJson(Map<String, dynamic> json) {
    return LoadingCopy(
      text: json['text'] as String?,
    );
  }
}

/// Copy configuration for no active giveaway screen.
class NoActiveGiveawayCopy {
  final String? title;
  final String? subtitle;
  final String? closeButton;

  const NoActiveGiveawayCopy({
    this.title,
    this.subtitle,
    this.closeButton,
  });

  factory NoActiveGiveawayCopy.fromJson(Map<String, dynamic> json) {
    return NoActiveGiveawayCopy(
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      closeButton: json['closeButton'] as String?,
    );
  }
}