import 'package:flutter_test/flutter_test.dart';
import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';

void main() {
  late StreakEngine engine;

  setUp(() {
    engine = StreakEngine();
  });

  group('StreakEngine', () {
    test('first claim returns day 1', () {
      final result = engine.nextState(null, DateTime.utc(2026, 3, 1));
      expect(result.isSuccess, isTrue);
      expect(result.value.currentDay, 1);
      expect(result.value.lastClaimedDate, DateTime.utc(2026, 3, 1));
    });

    test('consecutive day increments streak', () {
      final day1 = engine.nextState(null, DateTime.utc(2026, 3, 1));
      final day2 = engine.nextState(day1.value, DateTime.utc(2026, 3, 2));
      expect(day2.isSuccess, isTrue);
      expect(day2.value.currentDay, 2);
    });

    test('streak caps at 7', () {
      var state = engine.nextState(null, DateTime.utc(2026, 3, 1)).value;
      for (int i = 2; i <= 10; i++) {
        final result = engine.nextState(state, DateTime.utc(2026, 3, i));
        expect(result.isSuccess, isTrue);
        state = result.value;
      }
      expect(state.currentDay, 7);
    });

    test('gap resets streak to 1', () {
      final day1 = engine.nextState(null, DateTime.utc(2026, 3, 1));
      final day2 = engine.nextState(day1.value, DateTime.utc(2026, 3, 2));
      // Skip a day
      final day4 = engine.nextState(day2.value, DateTime.utc(2026, 3, 4));
      expect(day4.isSuccess, isTrue);
      expect(day4.value.currentDay, 1);
    });

    test('same day claim returns error', () {
      final day1 = engine.nextState(null, DateTime.utc(2026, 3, 1));
      final duplicate = engine.nextState(day1.value, DateTime.utc(2026, 3, 1));
      expect(duplicate.isError, isTrue);
      expect(duplicate.error, WINRError.ineligibleToday);
    });

    test('baseEntries follows streak ladder', () {
      expect(engine.baseEntries(1), 10);
      expect(engine.baseEntries(2), 30);
      expect(engine.baseEntries(3), 60);
      expect(engine.baseEntries(4), 130);
      expect(engine.baseEntries(5), 240);
      expect(engine.baseEntries(6), 300);
      expect(engine.baseEntries(7), 500); // 7-rung ladder, top rung
    });

    test('baseEntries clamps for out of range', () {
      expect(engine.baseEntries(0), 10);
      expect(engine.baseEntries(8), 500); // clamps to top rung (day 7)
    });

    test('weekly progress increments in same week', () {
      final day1 = engine.nextState(null, DateTime.utc(2026, 3, 2)); // Monday
      final day2 =
          engine.nextState(day1.value, DateTime.utc(2026, 3, 3)); // Tuesday
      expect(day2.value.weeklyCurrent, 2);
    });

    test('weekly progress resets on new week', () {
      final day1 = engine.nextState(null, DateTime.utc(2026, 3, 7)); // Saturday
      final day2 = engine.nextState(
          day1.value, DateTime.utc(2026, 3, 8)); // Sunday (new week)
      expect(day2.value.weeklyCurrent, 1);
    });

    test('monthly progress increments in same month', () {
      final day1 = engine.nextState(null, DateTime.utc(2026, 3, 1));
      final day2 = engine.nextState(day1.value, DateTime.utc(2026, 3, 2));
      expect(day2.value.monthlyCurrent, 2);
    });

    test('monthly progress resets on new month', () {
      final day1 = engine.nextState(null, DateTime.utc(2026, 3, 31));
      final day2 = engine.nextState(day1.value, DateTime.utc(2026, 4, 1));
      expect(day2.value.monthlyCurrent, 1);
    });

    test('null lastClaimedDate creates initial state', () {
      const state = StreakState(
        currentDay: 3,
        lastClaimedDate: null,
        totalEntriesEarned: 100,
      );
      final result = engine.nextState(state, DateTime.utc(2026, 3, 5));
      expect(result.isSuccess, isTrue);
      expect(result.value.currentDay, 1);
      expect(result.value.totalEntriesEarned, 100);
    });

    test('weekly bonus detected at threshold', () {
      const config =
          StreakConfig(weeklyBonusThreshold: 5, weeklyBonusEntries: 50);
      final state = StreakState(
        currentDay: 5,
        lastClaimedDate: DateTime.utc(2026, 3, 5),
        weeklyCurrent: 5,
      );
      expect(engine.checkWeeklyBonus(state, config), 50);
    });

    test('weekly bonus null when below threshold', () {
      const config =
          StreakConfig(weeklyBonusThreshold: 5, weeklyBonusEntries: 50);
      final state = StreakState(
        currentDay: 3,
        lastClaimedDate: DateTime.utc(2026, 3, 3),
        weeklyCurrent: 3,
      );
      expect(engine.checkWeeklyBonus(state, config), isNull);
    });

    test('monthly bonus detected at threshold', () {
      const config =
          StreakConfig(monthlyBonusThreshold: 20, monthlyBonusEntries: 200);
      final state = StreakState(
        currentDay: 6,
        lastClaimedDate: DateTime.utc(2026, 3, 20),
        monthlyCurrent: 20,
      );
      expect(engine.checkMonthlyBonus(state, config), 200);
    });
  });

  group('Result', () {
    test('success result holds value', () {
      final result = Result<int, String>.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.value, 42);
    });

    test('error result holds error', () {
      final result = Result<int, String>.error('fail');
      expect(result.isError, isTrue);
      expect(result.error, 'fail');
    });

    test('map transforms success value', () {
      final result = Result<int, String>.success(2);
      final mapped = result.map((v) => v * 3);
      expect(mapped.value, 6);
    });

    test('mapError transforms error', () {
      final result = Result<int, String>.error('fail');
      final mapped = result.mapError((e) => e.length);
      expect(mapped.error, 4);
    });
  });
}
