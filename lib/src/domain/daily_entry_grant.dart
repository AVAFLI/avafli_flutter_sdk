/// Represents the entries granted to a user for a daily claim.
/// 
/// Contains both base entries (from the daily streak) and any bonus entries
/// (from streak milestones and other bonus sources).
class DailyEntryGrant {
  /// Base entries earned from the daily streak
  final int baseEntries;
  
  /// Bonus entries earned from various sources
  final int bonusEntries;
  
  /// Creates a new daily entry grant.
  const DailyEntryGrant({
    required this.baseEntries,
    this.bonusEntries = 0,
  });
  
  /// Total entries granted (base + bonus)
  int get total => baseEntries + bonusEntries;
  
  /// Creates a copy with updated values
  DailyEntryGrant copyWith({
    int? baseEntries,
    int? bonusEntries,
  }) {
    return DailyEntryGrant(
      baseEntries: baseEntries ?? this.baseEntries,
      bonusEntries: bonusEntries ?? this.bonusEntries,
    );
  }
  
  @override
  String toString() => 'DailyEntryGrant(base: $baseEntries, bonus: $bonusEntries, total: $total)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyEntryGrant &&
          runtimeType == other.runtimeType &&
          baseEntries == other.baseEntries &&
          bonusEntries == other.bonusEntries;
  
  @override
  int get hashCode => baseEntries.hashCode ^ bonusEntries.hashCode;
}