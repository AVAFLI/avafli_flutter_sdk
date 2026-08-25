import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_components.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';
import 'package:avafli_sdk/avafli_sdk.dart';

void main() {
  group('AvafliV2Ladder.entries (mirrors iOS AvafliV2Ladder + backend)', () {
    const ladder = [10, 30, 60, 130, 240, 300, 500];

    test('empty ladder falls back to 10', () {
      expect(AvafliV2Ladder.entries(day: 3, ladder: const []), 10);
    });

    test('within ladder: entries(day) = ladder[day-1]', () {
      for (var day = 1; day <= ladder.length; day++) {
        expect(
          AvafliV2Ladder.entries(day: day, ladder: ladder),
          ladder[day - 1],
        );
      }
    });

    test('beyond ladder with no milestones: flat at the ladder top', () {
      expect(AvafliV2Ladder.entries(day: 8, ladder: ladder), 500);
      expect(AvafliV2Ladder.entries(day: 31, ladder: ladder), 500);
    });

    test('beyond ladder: adds per-day bonus of the latest passed milestone',
        () {
      const milestones = [
        MilestoneConfig(day: 7, bonusEntries: 25),
        MilestoneConfig(day: 14, bonusEntries: 50),
      ];
      // Day 8: milestone day 7 passed (7 < 8) → 500 + 25.
      expect(
        AvafliV2Ladder.entries(day: 8, ladder: ladder, milestones: milestones),
        525,
      );
      // Day 14: +25/day for days 8..14 → 500 + 7*25.
      expect(
        AvafliV2Ladder.entries(day: 14, ladder: ladder, milestones: milestones),
        675,
      );
      // Day 15: day-14 milestone now passed → previous + 50.
      expect(
        AvafliV2Ladder.entries(day: 15, ladder: ladder, milestones: milestones),
        725,
      );
      // Day 16: +50 again.
      expect(
        AvafliV2Ladder.entries(day: 16, ladder: ladder, milestones: milestones),
        775,
      );
    });

    test('milestone on the last ladder day starts the day after', () {
      const short = [10, 20];
      const milestones = [MilestoneConfig(day: 2, bonusEntries: 5)];
      expect(
        AvafliV2Ladder.entries(day: 2, ladder: short, milestones: milestones),
        20,
      );
      expect(
        AvafliV2Ladder.entries(day: 3, ladder: short, milestones: milestones),
        25,
      );
      expect(
        AvafliV2Ladder.entries(day: 5, ladder: short, milestones: milestones),
        35,
      );
    });
  });

  group('V2 prize copy helpers (mirror iOS)', () {
    test('cash detection', () {
      expect(avafliV2IsCashPrize(''), isTrue);
      expect(avafliV2IsCashPrize('Cash Prize'), isTrue);
      expect(avafliV2IsCashPrize('\$500 Amazon Gift Card'), isFalse);
    });

    test('leading-character article rule', () {
      expect(avafliV2Article('Amazon Gift Card'), 'an');
      expect(avafliV2Article('iPhone'), 'an');
      expect(avafliV2Article('PlayStation 5'), 'a');
      expect(avafliV2Article('\$500 Amazon Gift Card'), 'a');
      expect(avafliV2Article(''), 'a');
    });

    test('value line only when the description lacks the amount', () {
      expect(avafliV2ShowsValueLine('Amazon Gift Card', 500), isTrue);
      expect(avafliV2ShowsValueLine('\$500 Amazon Gift Card', 500), isFalse);
      expect(avafliV2ShowsValueLine('\$1,000 Cash', 1000), isFalse);
      expect(avafliV2ShowsValueLine('Amazon Gift Card', 0), isFalse);
    });
  });

  group('avafliV2FormatInt', () {
    test('groups thousands with commas', () {
      expect(avafliV2FormatInt(0), '0');
      expect(avafliV2FormatInt(999), '999');
      expect(avafliV2FormatInt(1000), '1,000');
      expect(avafliV2FormatInt(1234567), '1,234,567');
    });
  });

  group('Giveaway V2 model fields', () {
    test('parses prizeImageUrl, streakMode, milestones, latestWinner', () {
      final giveaway = Giveaway.fromJson({
        'id': 'g1',
        'title': 'Test',
        'streakLadder': [10, 30, 60],
        'prizeDescription': 'Amazon Gift Card',
        'prizeValue': 500,
        'rulesUrl': 'https://example.com/rules',
        'prizeImageUrl': 'https://example.com/prize.png',
        'streakMode': 'visit',
        'milestones': [
          {'day': 7, 'bonusEntries': 25},
        ],
        'latestWinner': {
          'name': 'Catherine C.',
          'location': 'Brooklyn, New York',
          'awardedAt': '2026-08-20',
        },
      });

      expect(giveaway.streakLadder, [10, 30, 60]);
      expect(giveaway.prizeImageUrl, 'https://example.com/prize.png');
      expect(giveaway.isVisitMode, isTrue);
      expect(giveaway.milestones.single.day, 7);
      expect(giveaway.milestones.single.bonusEntries, 25);
      expect(giveaway.latestWinner!.name, 'Catherine C.');
      expect(giveaway.latestWinner!.awardedAtDisplay, 'August 20, 2026');

      // Round-trips through the cache format.
      final cached = Giveaway.fromJson(giveaway.toJson());
      expect(cached.streakLadder, giveaway.streakLadder);
      expect(cached.latestWinner!.name, 'Catherine C.');
      expect(cached.streakMode, 'visit');
    });

    test('awardedAtDisplay falls back to raw string when not yyyy-MM-dd', () {
      const winner = GiveawayWinner(name: 'A', awardedAt: 'last week');
      expect(winner.awardedAtDisplay, 'last week');
    });
  });
}
