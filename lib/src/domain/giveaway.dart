/// Represents a giveaway configuration from the backend.
///
/// Contains all the settings and rules for a specific sweepstakes giveaway,
/// including streak configuration and entry limits. Mirrors the iOS SDK's
/// `GiveawayConfig` (WINRAPI.swift).
class Giveaway {
  /// Unique giveaway identifier
  final String id;

  /// Display title for the giveaway
  final String title;

  /// Giveaway duration type
  final GiveawayPeriod period;

  /// Maximum daily base entries allowed
  final int maxDailyBaseEntries;

  /// Whether entry doubling is enabled (legacy — bonus flow is parked)
  final bool doublingEnabled;

  /// Prize description for display
  final String? prizeDescription;

  /// Prize value in dollars
  final double? prizeValue;

  /// The daily reward ladder — entries granted on streak day N (1-indexed).
  final List<int> streakLadder;

  /// Streak system configuration
  final StreakConfig streakConfig;

  /// Streak milestone accelerators ("+25 EVERY DAY!" tiles).
  final List<MilestoneConfig> milestones;

  /// Official rules URL for this giveaway.
  final String? rulesUrl;

  /// Publisher-configurable prize art for the V2 prize card. Absent → the SDK
  /// renders the bundled default cash hero with "WIN $X" overlay.
  final String? prizeImageUrl;

  /// "daily" (default) = consecutive-day streak that resets on a miss.
  /// "visit" = visit-count streak for low-frequency apps; never resets.
  final String? streakMode;

  /// Most recent drawn winner for this giveaway chain — drives the
  /// "WE HAVE A WINNER!" banner + winners dialog. Absent → no banner.
  final GiveawayWinner? latestWinner;

  /// Whether this giveaway runs in visit mode (streak never resets).
  bool get isVisitMode => streakMode == 'visit';

  /// Creates a new giveaway instance.
  const Giveaway({
    required this.id,
    required this.title,
    required this.period,
    required this.maxDailyBaseEntries,
    required this.doublingEnabled,
    required this.streakConfig,
    this.streakLadder = const [],
    this.milestones = const [],
    this.prizeDescription,
    this.prizeValue,
    this.rulesUrl,
    this.prizeImageUrl,
    this.streakMode,
    this.latestWinner,
  });

  /// Creates from JSON data received from the backend.
  factory Giveaway.fromJson(Map<String, dynamic> json) {
    return Giveaway(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      period: GiveawayPeriod.fromString(json['period'] ?? 'monthly'),
      maxDailyBaseEntries: json['maxDailyBaseEntries'] ?? 300,
      doublingEnabled: json['doublingEnabled'] ?? false,
      streakConfig: StreakConfig.fromJson(json['streakConfig'] ?? {}),
      streakLadder: (json['streakLadder'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      milestones: (json['milestones'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MilestoneConfig.fromJson)
              .toList() ??
          const [],
      prizeDescription: json['prizeDescription'] as String?,
      prizeValue: (json['prizeValue'] as num?)?.toDouble(),
      rulesUrl: json['rulesUrl'] as String?,
      prizeImageUrl: json['prizeImageUrl'] as String?,
      streakMode: json['streakMode'] as String?,
      latestWinner: json['latestWinner'] is Map<String, dynamic>
          ? GiveawayWinner.fromJson(json['latestWinner'])
          : null,
    );
  }

  /// Converts to JSON for transmission/caching.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'period': period.value,
      'maxDailyBaseEntries': maxDailyBaseEntries,
      'doublingEnabled': doublingEnabled,
      'streakConfig': streakConfig.toJson(),
      'streakLadder': streakLadder,
      'milestones': milestones.map((m) => m.toJson()).toList(),
      if (prizeDescription != null) 'prizeDescription': prizeDescription,
      if (prizeValue != null) 'prizeValue': prizeValue,
      if (rulesUrl != null) 'rulesUrl': rulesUrl,
      if (prizeImageUrl != null) 'prizeImageUrl': prizeImageUrl,
      if (streakMode != null) 'streakMode': streakMode,
      if (latestWinner != null) 'latestWinner': latestWinner!.toJson(),
    };
  }

  @override
  String toString() => 'Giveaway(id: $id, title: $title)';
}

/// Milestone accelerator configuration from the giveaway (mirrors iOS
/// `MilestoneConfigAPI`): after [day], every subsequent day earns an extra
/// [bonusEntries] per day.
class MilestoneConfig {
  final int day;
  final int bonusEntries;
  final String? badge;

  const MilestoneConfig({
    required this.day,
    required this.bonusEntries,
    this.badge,
  });

  factory MilestoneConfig.fromJson(Map<String, dynamic> json) {
    return MilestoneConfig(
      day: (json['day'] as num?)?.toInt() ?? 0,
      bonusEntries: (json['bonusEntries'] as num?)?.toInt() ?? 0,
      badge: json['badge'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'bonusEntries': bonusEntries,
        if (badge != null) 'badge': badge,
      };
}

/// The most recent drawn winner for a giveaway chain (mirrors iOS
/// `GiveawayWinner`). Drives the "WE HAVE A WINNER!" banner + modal.
class GiveawayWinner {
  /// Display name, e.g. "Catherine C."
  final String name;

  /// e.g. "Brooklyn, New York"
  final String? location;

  final String? avatarUrl;

  /// "yyyy-MM-dd"
  final String? awardedAt;

  const GiveawayWinner({
    required this.name,
    this.location,
    this.avatarUrl,
    this.awardedAt,
  });

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// "August 20, 2026" — falls back to the raw string if not yyyy-MM-dd.
  String? get awardedAtDisplay {
    final raw = awardedAt;
    if (raw == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (match == null) return raw;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12) return raw;
    return '${_months[month - 1]} $day, $year';
  }

  factory GiveawayWinner.fromJson(Map<String, dynamic> json) {
    return GiveawayWinner(
      name: json['name'] ?? '',
      location: json['location'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      awardedAt: json['awardedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (location != null) 'location': location,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (awardedAt != null) 'awardedAt': awardedAt,
      };
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

/// Available giveaway duration types.
enum GiveawayPeriod {
  /// Monthly giveaway
  monthly('monthly');

  const GiveawayPeriod(this.value);
  final String value;

  /// Creates from string value.
  static GiveawayPeriod fromString(String value) {
    switch (value) {
      case 'monthly':
        return GiveawayPeriod.monthly;
      default:
        return GiveawayPeriod.monthly;
    }
  }
}
