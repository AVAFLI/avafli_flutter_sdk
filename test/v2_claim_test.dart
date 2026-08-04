// Fast tests for the winner prize-claim helpers: form validation, the shared
// prize-text derivation, the award-date display, and the PrizeClaimBlock
// decode contract (mirrors functions/src/types.ts and the iOS suite exactly).

import 'package:flutter_test/flutter_test.dart';
import 'package:winr_flutter_sdk/src/network/winr_api.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_claim.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_components.dart';

WINRPrizeClaimForm _validForm() => WINRPrizeClaimForm(
      firstName: 'Catherine',
      lastName: 'Cinosta',
      street: '5 Haide Pl.',
      city: 'Brooklyn',
      state: 'New York',
      zip: '11737',
    );

void main() {
  group('form validation', () {
    test('valid form passes', () {
      expect(_validForm().isValid, isTrue);
    });

    test('optional fields are not required', () {
      final form = _validForm()
        ..phone = ''
        ..apt = ''
        ..photoBase64 = null;
      expect(form.isValid, isTrue);
    });

    test('missing required fields fail', () {
      expect((_validForm()..firstName = '   ').isValid, isFalse);
      expect((_validForm()..lastName = '   ').isValid, isFalse);
      expect((_validForm()..street = '   ').isValid, isFalse);
      expect((_validForm()..city = '   ').isValid, isFalse);
      expect((_validForm()..state = '   ').isValid, isFalse);
    });

    test('zip validation', () {
      expect(WINRPrizeClaimForm.isValidZip('11737'), isTrue);
      expect(WINRPrizeClaimForm.isValidZip(' 11737 '), isTrue); // trimmed
      expect(WINRPrizeClaimForm.isValidZip('1173'), isFalse); // too short
      expect(WINRPrizeClaimForm.isValidZip('117378'), isFalse); // too long
      expect(WINRPrizeClaimForm.isValidZip('1173a'), isFalse); // non-digit
      expect(WINRPrizeClaimForm.isValidZip(''), isFalse);
    });

    test('display name is first name plus last initial', () {
      expect(_validForm().displayName, 'Catherine C.');
      final form = _validForm()
        ..firstName = 'Sam'
        ..lastName = '';
      expect(form.displayName, 'Sam');
    });

    test('fifty states', () {
      expect(WINRPrizeClaimForm.usStates.length, 50);
      expect(WINRPrizeClaimForm.usStates.toSet().length, 50);
    });
  });

  group('prize text derivation', () {
    test('cash prize strip headline', () {
      expect(winrV2StripHeadline('Cash Prize', 1000), r'$1,000.00 CASH PRIZE');
      // Empty description defaults to cash.
      expect(winrV2StripHeadline('', 500), r'$500.00 CASH PRIZE');
    });

    test('non-cash strip headline uses article', () {
      expect(
        winrV2StripHeadline('Apple Watch Ultra 3', 799),
        'Win an Apple Watch Ultra 3',
      );
      expect(winrV2StripHeadline('PlayStation 5', 500), 'Win a PlayStation 5');
      // Leading non-letter ("$500 …" reads "a five-hundred…") takes "a".
      expect(
        winrV2StripHeadline(r'$500 Amazon Gift Card', 500),
        r'Win a $500 Amazon Gift Card',
      );
    });

    test('value line suppressed when description states amount', () {
      expect(winrV2ShowsValueLine(r'$500 Amazon Gift Card', 500), isFalse);
      expect(winrV2ShowsValueLine('Apple Watch Ultra 3', 799), isTrue);
      expect(winrV2ShowsValueLine('Apple Watch', 0), isFalse);
    });
  });

  group('award date display', () {
    test('month year display from ISO', () {
      expect(
        WINRClaimDates.monthYearDisplay('2026-08-04T12:34:56Z'),
        'AUGUST, 2026',
      );
      expect(
        WINRClaimDates.monthYearDisplay('2026-08-04T12:34:56.789Z'),
        'AUGUST, 2026',
      );
      expect(WINRClaimDates.monthYearDisplay('2026-12-31'), 'DECEMBER, 2026');
    });

    test('month year display falls back to now', () {
      final now = DateTime(2026, 8, 4);
      expect(WINRClaimDates.monthYearDisplay(null, now: now), 'AUGUST, 2026');
      expect(
        WINRClaimDates.monthYearDisplay('garbage', now: now),
        'AUGUST, 2026',
      );
    });
  });

  group('PrizeClaimBlock decode contract', () {
    test('decodes pending', () {
      final block = PrizeClaimBlock.fromJson(const {
        'status': 'pending',
        'giveawayId': 'gw_123',
        'prizeDescription': 'Cash Prize',
        'prizeValue': 1000,
      });
      expect(block.isPending, isTrue);
      expect(block.giveawayId, 'gw_123');
      expect(block.prizeValue, 1000);
      expect(block.claimNumber, isNull);
      expect(block.submittedAt, isNull);
    });

    test('decodes submitted', () {
      final block = PrizeClaimBlock.fromJson(const {
        'status': 'submitted',
        'giveawayId': 'gw_123',
        'prizeDescription': 'Cash Prize',
        'prizeValue': 1000,
        'claimNumber': '9823457758',
        'submittedAt': '2026-08-04T12:00:00Z',
      });
      expect(block.isPending, isFalse);
      expect(block.claimNumber, '9823457758');
    });

    test('lenient decode tolerates a malformed block', () {
      // A bad winner doc (missing prize fields) must degrade gracefully,
      // never fail the whole giveaway response (mirrors iOS 2.3.0).
      final block = PrizeClaimBlock.fromJson(const {'status': 'pending'});
      expect(block.isPending, isTrue);
      expect(block.giveawayId, '');
      expect(block.prizeDescription, 'Your prize');
      expect(block.prizeValue, 0);
    });

    test('giveaway response decodes with and without the block', () {
      // The block is optional — existing responses must keep decoding.
      final without = GetActiveGiveawayResponse.fromJson(const {
        'giveaway': null,
        'claimedToday': false,
      });
      expect(without.prizeClaim, isNull);

      final with_ = GetActiveGiveawayResponse.fromJson(const {
        'giveaway': null,
        'claimedToday': false,
        'prizeClaim': {
          'status': 'pending',
          'giveawayId': 'gw_123',
          'prizeDescription': 'Cash Prize',
          'prizeValue': 1000,
        },
      });
      expect(with_.prizeClaim?.isPending, isTrue);
    });
  });

  group('SubmitPrizeClaimRequest', () {
    test('body omits empty optionals', () {
      final request = SubmitPrizeClaimRequest(
        giveawayId: 'gw_123',
        firstName: 'Catherine',
        lastName: 'Cinosta',
        phone: null,
        street: '5 Haide Pl.',
        apt: null,
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
        country: 'United States',
        photoBase64: null,
        story: null,
      );
      expect(request.endpoint, '/submitPrizeClaim');
      final body = request.body;
      expect(body['giveawayId'], 'gw_123');
      expect(body['country'], 'United States');
      expect(body.containsKey('phone'), isFalse);
      expect(body.containsKey('apt'), isFalse);
      expect(body.containsKey('photoBase64'), isFalse);
      expect(body.containsKey('story'), isFalse);
    });

    test('body includes provided optionals', () {
      final request = SubmitPrizeClaimRequest(
        giveawayId: 'gw_123',
        firstName: 'Catherine',
        lastName: 'Cinosta',
        phone: '+15555550123',
        street: '5 Haide Pl.',
        apt: 'Apt 4B',
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
        country: 'United States',
      );
      expect(request.body['phone'], '+15555550123');
      expect(request.body['apt'], 'Apt 4B');
    });
  });
}
