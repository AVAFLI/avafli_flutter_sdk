import '../winr_error.dart';
import 'campaign.dart';
import 'streak_state.dart';

/// Protocol for streak calculation logic.
///
/// Defines the interface for computing streak progression and bonus awards
/// in the three-tier streak system (daily, weekly, monthly).
abstract class StreakEngineProtocol {
  /// Calculates the next streak state based on current state and claim date.
  ///
  /// Returns an error if the user is ineligible to claim today.
  Result<StreakState, WINRError> nextState(
      StreakState? currentState, DateTime claimDate);

  /// Gets base entries for a given day in the streak.
  int baseEntries(int day);

  /// Checks if weekly bonus should be awarded.
  int? checkWeeklyBonus(StreakState state, StreakConfig config);

  /// Checks if monthly bonus should be awarded.
  int? checkMonthlyBonus(StreakState state, StreakConfig config);
}

/// Implementation of the three-tier streak system.
///
/// Handles daily streak progression (1-6 days), weekly bonus tracking,
/// and monthly bonus tracking with proper UTC date handling.
class StreakEngine implements StreakEngineProtocol {
  /// Default streak ladder values (can be overridden by campaign config).
  static const List<int> defaultStreakLadder = [10, 30, 60, 130, 240, 300];

  @override
  Result<StreakState, WINRError> nextState(
      StreakState? currentState, DateTime claimDate) {
    // Convert claim date to UTC for consistent calculations
    final utcDate = DateTime.utc(
      claimDate.year,
      claimDate.month,
      claimDate.day,
    );

    // First time claiming
    if (currentState == null) {
      return _createInitialState(utcDate);
    }

    // Handle case where lastClaimedDate is null
    if (currentState.lastClaimedDate == null) {
      return _createInitialState(utcDate, currentState.totalEntriesEarned);
    }

    final lastClaimed = DateTime.utc(
      currentState.lastClaimedDate!.year,
      currentState.lastClaimedDate!.month,
      currentState.lastClaimedDate!.day,
    );

    // Check if already claimed today
    if (utcDate.isAtSameMomentAs(lastClaimed)) {
      return Result.error(WINRError.ineligibleToday);
    }

    final daysDifference = utcDate.difference(lastClaimed).inDays;

    // Calculate new daily streak
    final newDailyStreak =
        _calculateDailyStreak(currentState.currentDay, daysDifference);

    // Calculate weekly and monthly progress
    final currentWeekStart = _getSundayOfWeek(utcDate);
    final currentMonthFirst = _getFirstOfMonth(utcDate);

    final (weeklyCurrent, weeklyStart) = _calculateWeeklyProgress(
      currentState,
      currentWeekStart,
    );

    final (monthlyCurrent, monthlyStart) = _calculateMonthlyProgress(
      currentState,
      currentMonthFirst,
    );

    return Result.success(StreakState(
      currentDay: newDailyStreak,
      lastClaimedDate: utcDate,
      totalEntriesEarned: currentState.totalEntriesEarned,
      weeklyCurrent: weeklyCurrent,
      weeklyStart: weeklyStart,
      monthlyCurrent: monthlyCurrent,
      monthlyStart: monthlyStart,
    ));
  }

  @override
  int baseEntries(int day) {
    final index = (day - 1).clamp(0, defaultStreakLadder.length - 1);
    return defaultStreakLadder[index];
  }

  @override
  int? checkWeeklyBonus(StreakState state, StreakConfig config) {
    if (state.weeklyCurrent == config.weeklyBonusThreshold) {
      return config.weeklyBonusEntries;
    }
    return null;
  }

  @override
  int? checkMonthlyBonus(StreakState state, StreakConfig config) {
    if (state.monthlyCurrent == config.monthlyBonusThreshold) {
      return config.monthlyBonusEntries;
    }
    return null;
  }

  // MARK: - Private Helper Methods

  Result<StreakState, WINRError> _createInitialState(DateTime utcDate,
      [int totalEntries = 0]) {
    final weekStart = _getSundayOfWeek(utcDate);
    final monthFirst = _getFirstOfMonth(utcDate);

    return Result.success(StreakState(
      currentDay: 1,
      lastClaimedDate: utcDate,
      totalEntriesEarned: totalEntries,
      weeklyCurrent: 1,
      weeklyStart: weekStart,
      monthlyCurrent: 1,
      monthlyStart: monthFirst,
    ));
  }

  int _calculateDailyStreak(int currentDay, int daysDifference) {
    if (daysDifference == 1) {
      // Consecutive day - advance streak but cap at 6
      return (currentDay + 1).clamp(1, 6);
    } else {
      // Streak broken or gap - reset to 1
      return 1;
    }
  }

  (int, String) _calculateWeeklyProgress(
      StreakState currentState, String currentWeekStart) {
    if (currentState.weeklyStart == currentWeekStart) {
      // Same week - increment
      return (currentState.weeklyCurrent + 1, currentWeekStart);
    } else {
      // New week - reset
      return (1, currentWeekStart);
    }
  }

  (int, String) _calculateMonthlyProgress(
      StreakState currentState, String currentMonthFirst) {
    if (currentState.monthlyStart == currentMonthFirst) {
      // Same month - increment
      return (currentState.monthlyCurrent + 1, currentMonthFirst);
    } else {
      // New month - reset
      return (1, currentMonthFirst);
    }
  }

  String _getSundayOfWeek(DateTime date) {
    final dayOfWeek = date.weekday; // 1 = Monday, 7 = Sunday
    final daysFromSunday = dayOfWeek == 7 ? 0 : dayOfWeek;
    final sunday = date.subtract(Duration(days: daysFromSunday));
    return _formatDate(sunday);
  }

  String _getFirstOfMonth(DateTime date) {
    final firstOfMonth = DateTime.utc(date.year, date.month, 1);
    return _formatDate(firstOfMonth);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

/// Simple Result type for error handling.
///
/// Used to represent operations that can either succeed with a value
/// or fail with an error, without using exceptions.
class Result<T, E> {
  final T? _value;
  final E? _error;
  final bool _isSuccess;

  const Result._(this._value, this._error, this._isSuccess);

  /// Creates a successful result with the given value.
  factory Result.success(T value) => Result._(value, null, true);

  /// Creates an error result with the given error.
  factory Result.error(E error) => Result._(null, error, false);

  /// Whether this result represents a success.
  bool get isSuccess => _isSuccess;

  /// Whether this result represents an error.
  bool get isError => !_isSuccess;

  /// Gets the success value, throwing if this is an error.
  T get value {
    if (_isSuccess) return _value!;
    throw StateError('Tried to get value from error result: $_error');
  }

  /// Gets the error, throwing if this is a success.
  E get error {
    if (!_isSuccess) return _error!;
    throw StateError('Tried to get error from success result: $_value');
  }

  /// Maps the success value to a new type.
  Result<U, E> map<U>(U Function(T) fn) {
    return _isSuccess
        ? Result.success(fn(_value as T))
        : Result.error(_error as E);
  }

  /// Maps the error to a new type.
  Result<T, F> mapError<F>(F Function(E) fn) {
    return _isSuccess
        ? Result.success(_value as T)
        : Result.error(fn(_error as E));
  }
}
