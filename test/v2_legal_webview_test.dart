// The in-app legal webview's pure contracts (2.9.4): the privacy URL gains
// `?app=1` (the flag under which sdk.avafli.com/sdk/privacy renders its
// in-app variant with the Delete-my-data section), and the navigation-bridge
// decision that turns `avafli://delete` — and the legacy `winr://delete`
// still emitted by older builds of the hosted privacy page — into the native
// erasure flow. The WebViewWidget itself needs a platform and is exercised
// on-device; the contracts it delegates to are covered here.

import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_legal.dart';

void main() {
  group('privacy URL construction', () {
    test('the canonical policy URL gains app=1', () {
      final uri = avafliV2AppPrivacyUri();
      expect(uri.scheme, 'https');
      expect(uri.host, 'sdk.avafli.com');
      expect(uri.path, '/sdk/privacy');
      expect(uri.queryParameters, {'app': '1'});
      expect(uri.toString(), 'https://sdk.avafli.com/sdk/privacy?app=1');
    });

    test('an existing query string extends instead of corrupting', () {
      final uri =
          avafliV2AppendAppQuery('https://sdk.avafli.com/sdk/privacy?lang=en');
      expect(uri.queryParameters, {'lang': 'en', 'app': '1'});
      // One '?', never two.
      expect('?'.allMatches(uri.toString()).length, 1);
    });

    test('an already-present app param is not duplicated', () {
      final uri =
          avafliV2AppendAppQuery('https://sdk.avafli.com/sdk/privacy?app=1');
      expect(uri.queryParameters, {'app': '1'});
      expect(uri.toString(), 'https://sdk.avafli.com/sdk/privacy?app=1');
    });
  });

  group('avafli:// + winr:// navigation bridge decision', () {
    test('normal web navigations are allowed', () {
      expect(
          avafliV2LegalNavDecision('https://sdk.avafli.com/sdk/privacy?app=1'),
          AvafliV2LegalNav.allow);
      expect(avafliV2LegalNavDecision('https://example.com/rules'),
          AvafliV2LegalNav.allow);
      expect(avafliV2LegalNavDecision('http://example.com/'),
          AvafliV2LegalNav.allow);
      // In-page anchors and redirects stay in the webview too.
      expect(
          avafliV2LegalNavDecision(
              'https://sdk.avafli.com/sdk/privacy?app=1#delete'),
          AvafliV2LegalNav.allow);
    });

    test('avafli://delete raises the delete flow', () {
      expect(
          avafliV2LegalNavDecision('avafli://delete'), AvafliV2LegalNav.delete);
      // Tolerated variants: trailing slash, case, path form.
      expect(avafliV2LegalNavDecision('avafli://delete/'),
          AvafliV2LegalNav.delete);
      expect(
          avafliV2LegalNavDecision('AVAFLI://DELETE'), AvafliV2LegalNav.delete);
      expect(
          avafliV2LegalNavDecision('avafli:/delete'), AvafliV2LegalNav.delete);
    });

    test(
        'legacy winr://delete still raises the delete flow — older builds '
        'of the hosted privacy page emit it', () {
      expect(
          avafliV2LegalNavDecision('winr://delete'), AvafliV2LegalNav.delete);
      // Same tolerated variants as the canonical scheme.
      expect(
          avafliV2LegalNavDecision('winr://delete/'), AvafliV2LegalNav.delete);
      expect(
          avafliV2LegalNavDecision('WINR://DELETE'), AvafliV2LegalNav.delete);
      expect(avafliV2LegalNavDecision('winr:/delete'), AvafliV2LegalNav.delete);
    });

    test(
        'unknown bridge verbs are blocked, never loaded — a newer page '
        'build must degrade to a dead tap, not a webview error', () {
      expect(
          avafliV2LegalNavDecision('avafli://export'), AvafliV2LegalNav.block);
      expect(avafliV2LegalNavDecision('avafli://'), AvafliV2LegalNav.block);
      expect(avafliV2LegalNavDecision('avafli://delete-account'),
          AvafliV2LegalNav.block);
      expect(avafliV2LegalNavDecision('winr://export'), AvafliV2LegalNav.block);
      expect(avafliV2LegalNavDecision('winr://'), AvafliV2LegalNav.block);
      expect(avafliV2LegalNavDecision('winr://delete-account'),
          AvafliV2LegalNav.block);
    });

    test('an unparseable URL is blocked', () {
      expect(avafliV2LegalNavDecision('::not a url::'), AvafliV2LegalNav.block);
    });
  });
}
