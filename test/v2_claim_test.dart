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
        ..photoBase64 = null
        ..story = '';
      expect(form.isValid, isTrue);
      expect((_validForm()..story = 'So excited!').isValid, isTrue);
    });

    test(
        'promo consent is optional, unchecked by default, and never gates '
        'submit (2.9)', () {
      // 14 Aug 2026 team decision: the review screen keeps ONLY the
      // likeness/promo checkbox, OPTIONAL — consent must be an affirmative
      // act, so it starts unchecked, and SUBMIT is enabled either way.
      final fresh = WINRPrizeClaimForm();
      expect(fresh.promoConsentGranted, isFalse);
      expect((_validForm()..promoConsentGranted = false).isValid, isTrue);
      expect((_validForm()..promoConsentGranted = true).isValid, isTrue);
    });

    test('per-step validity', () {
      // Step 1: first + last name only.
      expect(
        WINRPrizeClaimForm(firstName: 'Sam', lastName: 'W').isStep1Valid,
        isTrue,
      );
      expect(WINRPrizeClaimForm(firstName: 'Sam').isStep1Valid, isFalse);
      expect(
        WINRPrizeClaimForm(firstName: ' ', lastName: 'W').isStep1Valid,
        isFalse,
      );
      // Step 2: full US shipping address (apartment optional).
      expect(_validForm().isStep2Valid, isTrue);
      expect((_validForm()..street = ' ').isStep2Valid, isFalse);
      expect((_validForm()..city = '').isStep2Valid, isFalse);
      expect((_validForm()..state = '').isStep2Valid, isFalse);
      expect((_validForm()..zip = '117').isStep2Valid, isFalse);
      expect((_validForm()..apt = '').isStep2Valid, isTrue);
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

    test('fifty states plus the District of Columbia', () {
      // The official rules promise "50 states and the District of Columbia".
      expect(WINRPrizeClaimForm.usStates.length, 51);
      expect(WINRPrizeClaimForm.usStates.toSet().length, 51);
      expect(WINRPrizeClaimForm.usStates, contains('District of Columbia'));
      // Alphabetical placement: between Delaware and Florida.
      final sorted = [...WINRPrizeClaimForm.usStates]..sort();
      expect(WINRPrizeClaimForm.usStates, sorted);
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
      // maskedEmail is absent from older backends — decodes to null.
      expect(block.maskedEmail, isNull);
    });

    test('decodes the masked winning email', () {
      final block = PrizeClaimBlock.fromJson(const {
        'status': 'pending',
        'giveawayId': 'gw_123',
        'prizeDescription': 'Cash Prize',
        'prizeValue': 1000,
        'maskedEmail': 'd********r@winr.example.com',
      });
      expect(block.maskedEmail, 'd********r@winr.example.com');
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

    test('adoptionPending decodes optionally on both responses (2.9)', () {
      // Absent from current prod → null → normal flow.
      expect(
        GetActiveGiveawayResponse.fromJson(const {}).adoptionPending,
        isNull,
      );
      expect(
        GetActiveGiveawayResponse.fromJson(const {'adoptionPending': true})
            .adoptionPending,
        isTrue,
      );
      final register = RegisterDeviceResponse.fromJson(const {
        'token': 't',
        'refreshToken': 'r',
        'uuid': 'u',
        'adoptionPending': true,
      });
      expect(register.adoptionPending, isTrue);
      expect(
        RegisterDeviceResponse.fromJson(
          const {'token': 't', 'refreshToken': 'r', 'uuid': 'u'},
        ).adoptionPending,
        isNull,
      );
    });

    test('restageAdoption request/response contract (2.9)', () {
      expect(RestageAdoptionRequest().endpoint, '/restageAdoption');
      expect(RestageAdoptionRequest().body, isEmpty);
      expect(
          RestageAdoptionResponse.fromJson(const {'sent': true}).sent, isTrue);
      expect(RestageAdoptionResponse.fromJson(const {}).sent, isFalse);
    });

    test('attachClaimStory request/response contract (2.9)', () {
      final request = AttachClaimStoryRequest(story: 'So excited!');
      expect(request.endpoint, '/attachClaimStory');
      expect(request.body, {'story': 'So excited!'});
      expect(AttachClaimStoryResponse.fromJson(const {'saved': true}).saved,
          isTrue);
      expect(AttachClaimStoryResponse.fromJson(const {}).saved, isFalse);
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
      // 2.9: the promo consent is ALWAYS sent (the backend records the
      // actual choice), defaulting to false.
      expect(body['promoConsentGranted'], isFalse);
      expect(body.containsKey('phone'), isFalse);
      expect(body.containsKey('apt'), isFalse);
      expect(body.containsKey('photoBase64'), isFalse);
      expect(body.containsKey('story'), isFalse);
    });

    test('body carries an affirmed promo consent', () {
      final request = SubmitPrizeClaimRequest(
        giveawayId: 'gw_123',
        firstName: 'Catherine',
        lastName: 'Cinosta',
        street: '5 Haide Pl.',
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
        country: 'United States',
        promoConsentGranted: true,
      );
      expect(request.body['promoConsentGranted'], isTrue);
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

    test('body includes the story when provided', () {
      final request = SubmitPrizeClaimRequest(
        giveawayId: 'gw_123',
        firstName: 'Catherine',
        lastName: 'Cinosta',
        street: '5 Haide Pl.',
        city: 'Brooklyn',
        state: 'New York',
        zip: '11737',
        country: 'United States',
        story: 'Buying my mom dinner.',
      );
      expect(request.body['story'], 'Buying my mom dinner.');
    });
  });
}
