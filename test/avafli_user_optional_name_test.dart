import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/avafli_sdk.dart';

/// firstName/lastName are optional on AvafliUser (2.6.3). A publisher can build a
/// user from whatever identity data they have — even just an id — and the SDK
/// captures the rest (email via its capture screen, name at prize-claim). These
/// pin that the id-only user constructs, is NOT a guest, and that the guest
/// sentinel semantics (guest is id-empty) are unaffected.
void main() {
  group('AvafliUser optional names', () {
    test('id-only user constructs with empty names', () {
      const user = AvafliUser(id: 'user_123');
      expect(user.id, 'user_123');
      expect(user.firstName, '');
      expect(user.lastName, '');
      expect(user.phone, isNull);
      expect(user.email, isNull);
    });

    test('id-only user is not a guest', () {
      // A non-empty id but absent names must NOT be treated as a guest —
      // guest is defined solely by an empty id.
      expect(const AvafliUser(id: 'user_123').isGuest, isFalse);
    });

    test('guest sentinel is still a guest', () {
      expect(AvafliUser.guest.isGuest, isTrue);
      expect(const AvafliUser(id: '').isGuest, isTrue);
    });

    test('configuration accepts an id-only user', () {
      const config = AvafliConfiguration(
        apiKey: 'winr_live_test',
        bundleId: 'com.example.myapp',
        user: AvafliUser(id: 'user_123'),
      );
      expect(config.user.id, 'user_123');
      expect(config.user.isGuest, isFalse);
    });
  });
}
