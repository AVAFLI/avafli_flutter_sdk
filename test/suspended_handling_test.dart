import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/avafli_sdk.dart';

void main() {
  group('AvafliError.serviceUnavailable', () {
    test('exists and has a publisher-facing message', () {
      const error = AvafliError.serviceUnavailable;
      expect(error.message, isNotEmpty);
      expect(error.toString(), contains('serviceUnavailable'));
    });

    test('can be wrapped and caught as a AvafliException', () {
      AvafliError? caught;
      try {
        throw const AvafliException(AvafliError.serviceUnavailable);
      } on AvafliException catch (e) {
        caught = e.error;
      }
      expect(caught, AvafliError.serviceUnavailable);
    });
  });

  group('Avafli.isAvailable', () {
    tearDown(Avafli.resetForTesting);

    test('is false before configuration', () {
      Avafli.resetForTesting();
      expect(Avafli.isAvailable, isFalse);
    });
  });
}
