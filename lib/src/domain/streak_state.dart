/// Represents the current state of a user's engagement streaks.
///
/// This includes the daily streak (1-6 days), weekly streak tracking,
/// and monthly streak tracking for the three-tier streak system.
class StreakState {
  /// Current daily streak day (1-6, resets weekly)
  final int currentDay;

  /// Date when entries were last claimed
  final DateTime? lastClaimedDate;

  /// Total entries earned all-time
  final int totalEntriesEarned;

  /// Current week's consecutive days
  final int weeklyCurrent;

  /// Start date of current week (YYYY-MM-DD format)
  final String? weeklyStart;

  /// Current month's total days
  final int monthlyCurrent;

  /// Start date of current month (YYYY-MM-DD format)
  final String? monthlyStart;

  /// Creates a new streak state.
  const StreakState({
    this.currentDay = 1,
    this.lastClaimedDate,
    this.totalEntriesEarned = 0,
    this.weeklyCurrent = 0,
    this.weeklyStart,
    this.monthlyCurrent = 0,
    this.monthlyStart,
  });

  /// Creates a copy with updated values
  StreakState copyWith({
    int? currentDay,
    DateTime? lastClaimedDate,
    int? totalEntriesEarned,
    int? weeklyCurrent,
    String? weeklyStart,
    int? monthlyCurrent,
    String? monthlyStart,
  }) {
    return StreakState(
      currentDay: currentDay ?? this.currentDay,
      lastClaimedDate: lastClaimedDate ?? this.lastClaimedDate,
      totalEntriesEarned: totalEntriesEarned ?? this.totalEntriesEarned,
      weeklyCurrent: weeklyCurrent ?? this.weeklyCurrent,
      weeklyStart: weeklyStart ?? this.weeklyStart,
      monthlyCurrent: monthlyCurrent ?? this.monthlyCurrent,
      monthlyStart: monthlyStart ?? this.monthlyStart,
    );
  }

  /// Converts to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'currentDay': currentDay,
      'lastClaimedDate': lastClaimedDate?.toIso8601String(),
      'totalEntriesEarned': totalEntriesEarned,
      'weeklyCurrent': weeklyCurrent,
      'weeklyStart': weeklyStart,
      'monthlyCurrent': monthlyCurrent,
      'monthlyStart': monthlyStart,
    };
  }

  /// Creates from JSON data
  factory StreakState.fromJson(Map<String, dynamic> json) {
    return StreakState(
      currentDay: json['currentDay'] ?? 1,
      lastClaimedDate: json['lastClaimedDate'] != null
          ? DateTime.parse(json['lastClaimedDate'])
          : null,
      totalEntriesEarned: json['totalEntriesEarned'] ?? 0,
      weeklyCurrent: json['weeklyCurrent'] ?? 0,
      weeklyStart: json['weeklyStart'],
      monthlyCurrent: json['monthlyCurrent'] ?? 0,
      monthlyStart: json['monthlyStart'],
    );
  }

  @override
  String toString() {
    return 'StreakState(day: $currentDay, weekly: $weeklyCurrent, monthly: $monthlyCurrent)';
  }
}
