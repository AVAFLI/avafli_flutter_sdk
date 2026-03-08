/// Represents a campaign configuration from the backend.
/// 
/// Contains all the settings and rules for a specific sweepstakes campaign,
/// including streak configuration and entry limits.
class Campaign {
  /// Unique campaign identifier
  final String id;
  
  /// Display title for the campaign
  final String title;
  
  /// Campaign duration type
  final CampaignPeriod period;
  
  /// Maximum daily base entries allowed
  final int maxDailyBaseEntries;
  
  /// Whether entry doubling is enabled
  final bool doublingEnabled;
  
  /// Prize description for display
  final String? prizeDescription;
  
  /// Prize value in dollars
  final double? prizeValue;
  
  /// Streak system configuration
  final StreakConfig streakConfig;
  
  /// Creates a new campaign instance.
  const Campaign({
    required this.id,
    required this.title,
    required this.period,
    required this.maxDailyBaseEntries,
    required this.doublingEnabled,
    required this.streakConfig,
    this.prizeDescription,
    this.prizeValue,
  });
  
  /// Creates from JSON data received from the backend.
  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      period: CampaignPeriod.fromString(json['period'] ?? 'monthly'),
      maxDailyBaseEntries: json['maxDailyBaseEntries'] ?? 300,
      doublingEnabled: json['doublingEnabled'] ?? false,
      streakConfig: StreakConfig.fromJson(json['streakConfig'] ?? {}),
      prizeDescription: json['prizeDescription'] as String?,
      prizeValue: (json['prizeValue'] as num?)?.toDouble(),
    );
  }
  
  /// Converts to JSON for transmission.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'period': period.value,
      'maxDailyBaseEntries': maxDailyBaseEntries,
      'doublingEnabled': doublingEnabled,
      'streakConfig': streakConfig.toJson(),
    };
  }
  
  @override
  String toString() => 'Campaign(id: $id, title: $title)';
}

/// Configuration for the three-tier streak system.
/// 
/// Defines thresholds and rewards for weekly and monthly bonuses.
class StreakConfig {
  /// Day of week when weekly streaks reset (0 = Sunday)
  final int weeklyResetDay;
  
  /// Day of month when monthly streaks reset
  final int monthlyResetDay;
  
  /// Number of weekly days needed for bonus
  final int weeklyBonusThreshold;
  
  /// Entries awarded for weekly bonus
  final int weeklyBonusEntries;
  
  /// Number of monthly days needed for bonus
  final int monthlyBonusThreshold;
  
  /// Entries awarded for monthly bonus
  final int monthlyBonusEntries;
  
  /// Creates a new streak configuration.
  const StreakConfig({
    this.weeklyResetDay = 0,
    this.monthlyResetDay = 1,
    this.weeklyBonusThreshold = 5,
    this.weeklyBonusEntries = 50,
    this.monthlyBonusThreshold = 20,
    this.monthlyBonusEntries = 200,
  });
  
  /// Creates from JSON data.
  factory StreakConfig.fromJson(Map<String, dynamic> json) {
    return StreakConfig(
      weeklyResetDay: json['weeklyResetDay'] ?? 0,
      monthlyResetDay: json['monthlyResetDay'] ?? 1,
      weeklyBonusThreshold: json['weeklyBonusThreshold'] ?? 5,
      weeklyBonusEntries: json['weeklyBonusEntries'] ?? 50,
      monthlyBonusThreshold: json['monthlyBonusThreshold'] ?? 20,
      monthlyBonusEntries: json['monthlyBonusEntries'] ?? 200,
    );
  }
  
  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'weeklyResetDay': weeklyResetDay,
      'monthlyResetDay': monthlyResetDay,
      'weeklyBonusThreshold': weeklyBonusThreshold,
      'weeklyBonusEntries': weeklyBonusEntries,
      'monthlyBonusThreshold': monthlyBonusThreshold,
      'monthlyBonusEntries': monthlyBonusEntries,
    };
  }
}

/// Available campaign duration types.
enum CampaignPeriod {
  /// Monthly campaign
  monthly('monthly');
  
  const CampaignPeriod(this.value);
  final String value;
  
  /// Creates from string value.
  static CampaignPeriod fromString(String value) {
    switch (value) {
      case 'monthly':
        return CampaignPeriod.monthly;
      default:
        return CampaignPeriod.monthly;
    }
  }
}