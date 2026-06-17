import 'package:flutter/widgets.dart';
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

  group('WINR.present', () {
    tearDown(WINR.resetForTesting);

    test('throws notConfigured before configuration', () async {
      WINR.resetForTesting();
      expect(
        () => WINR.present(_FakeBuildContext()),
        throwsA(
          isA<WINRException>()
              .having((e) => e.error, 'error', WINRError.notConfigured),
        ),
      );
    });
  });
}

/// Minimal stand-in: present() short-circuits on the null-configuration check
/// before ever touching the context, so a never-used placeholder is sufficient.
class _FakeBuildContext extends Fake implements BuildContext {}
