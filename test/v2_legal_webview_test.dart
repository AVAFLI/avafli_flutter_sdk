// The in-app legal webview's pure contracts (2.9.4): the privacy URL gains
// `?app=1` (the flag under which winrmedia.com/sdk/privacy renders its
// in-app variant with the Delete-my-data section), and the navigation-bridge
// decision that turns `winr://delete` into the native erasure flow. The
// WebViewWidget itself needs a platform and is exercised on-device; the
// contracts it delegates to are covered here.

import 'package:flutter_test/flutter_test.dart';
import 'package:winr_flutter_sdk/src/ui/v2/winr_v2_legal.dart';

void main() {
  group('privacy URL construction', () {
    test('the canonical policy URL gains app=1', () {
      final uri = winrV2AppPrivacyUri();
      expect(uri.scheme, 'https');
      expect(uri.host, 'winrmedia.com');
      expect(uri.path, '/sdk/privacy');
      expect(uri.queryParameters, {'app': '1'});
      expect(uri.toString(), 'https://winrmedia.com/sdk/privacy?app=1');
    });

    test('an existing query string extends instead of corrupting', () {
      final uri =
          winrV2AppendAppQuery('https://winrmedia.com/sdk/privacy?lang=en');
      expect(uri.queryParameters, {'lang': 'en', 'app': '1'});
      // One '?', never two.
      expect('?'.allMatches(uri.toString()).length, 1);
    });

    test('an already-present app param is not duplicated', () {
      final uri =
          winrV2AppendAppQuery('https://winrmedia.com/sdk/privacy?app=1');
      expect(uri.queryParameters, {'app': '1'});
      expect(uri.toString(), 'https://winrmedia.com/sdk/privacy?app=1');
    });
  });

  group('winr:// navigation bridge decision', () {
    test('normal web navigations are allowed', () {
      expect(winrV2LegalNavDecision('https://winrmedia.com/sdk/privacy?app=1'),
          WINRV2LegalNav.allow);
      expect(winrV2LegalNavDecision('https://example.com/rules'),
          WINRV2LegalNav.allow);
      expect(
          winrV2LegalNavDecision('http://example.com/'), WINRV2LegalNav.allow);
      // In-page anchors and redirects stay in the webview too.
      expect(
          winrV2LegalNavDecision(
              'https://winrmedia.com/sdk/privacy?app=1#delete'),
          WINRV2LegalNav.allow);
    });

    test('winr://delete raises the delete flow', () {
      expect(winrV2LegalNavDecision('winr://delete'), WINRV2LegalNav.delete);
      // Tolerated variants: trailing slash, case, path form.
      expect(winrV2LegalNavDecision('winr://delete/'), WINRV2LegalNav.delete);
      expect(winrV2LegalNavDecision('WINR://DELETE'), WINRV2LegalNav.delete);
      expect(winrV2LegalNavDecision('winr:/delete'), WINRV2LegalNav.delete);
    });

    test(
        'unknown winr:// verbs are blocked, never loaded — a newer page '
        'build must degrade to a dead tap, not a webview error', () {
      expect(winrV2LegalNavDecision('winr://export'), WINRV2LegalNav.block);
      expect(winrV2LegalNavDecision('winr://'), WINRV2LegalNav.block);
      expect(winrV2LegalNavDecision('winr://delete-account'),
          WINRV2LegalNav.block);
    });

    test('an unparseable URL is blocked', () {
      expect(winrV2LegalNavDecision('::not a url::'), WINRV2LegalNav.block);
    });
  });
}
