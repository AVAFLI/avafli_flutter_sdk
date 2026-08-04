import 'package:flutter_test/flutter_test.dart';
import 'package:winr_flutter_sdk/winr_flutter_sdk.dart';

void main() {
  group('WINRError.serviceUnavailable', () {
    test('exists and has a publisher-facing message', () {
      const error = WINRError.serviceUnavailable;
      expect(error.message, isNotEmpty);
      expect(error.toString(), contains('serviceUnavailable'));
    });

    test('can be wrapped and caught as a WINRException', () {
      WINRError? caught;
      try {
        throw const WINRException(WINRError.serviceUnavailable);
      } on WINRException catch (e) {
        caught = e.error;
      }
      expect(caught, WINRError.serviceUnavailable);
    });
  });

  group('WINR.isAvailable', () {
    tearDown(WINR.resetForTesting);

    test('is false before configuration', () {
      WINR.resetForTesting();
      expect(WINR.isAvailable, isFalse);
    });
  });

}
