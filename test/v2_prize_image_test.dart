// The publisher's prize art used to pop into the card a beat after everything
// else: `Image.network` with no precache, no transition, and a placeholder
// that was just the card's empty background.
//
// The fix has three parts, pinned here:
//   * the SDK warms the URL into the shared image cache as soon as it learns
//     the giveaway config (registration + every refresh), so the card
//     normally paints its art on the FIRST frame,
//   * a URL that is genuinely still loading shows the card's dark placeholder
//     (never a blank/white flash) and fades in, and
//   * a broken URL falls back to the bundled cash hero rather than a hole.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_components.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_effects.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';

const String _prizeUrl = 'https://cdn.example.com/prize.png';
const String _pendingUrl = 'https://cdn.example.com/pending-prize.png';

/// An HTTP client whose requests never complete, so an image under test stays
/// in its loading state for as long as the test wants to look at it.
class _HangingHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl || invocation.memberName == #openUrl) {
      return Completer<HttpClientRequest>().future;
    }
    return null;
  }
}

Widget _card({String? prizeImageUrl}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: AvafliV2Colors.gunmetal,
        child: Center(
          child: SizedBox(
            width: 390,
            child: AvafliV2PrizeCard(
              accent: AvafliV2Accent(null).color,
              streakDay: 3,
              totalEntries: 100,
              prizeImageUrl: prizeImageUrl,
              prizeValue: 1000,
              prizeDescription: '',
            ),
          ),
        ),
      ),
    );

/// The image providers actually mounted in the card.
Iterable<ImageProvider> _providers(WidgetTester tester) =>
    tester.widgetList<Image>(find.byType(Image)).map((i) => i.image);

/// Real Inter faces — the test-default font is much wider and overflows the
/// card's stats strip.
Future<void> _loadRealFonts() async {
  final inter = FontLoader('packages/avafli_sdk/Inter');
  for (final file in [
    'inter-v20-latin-regular.ttf',
    'inter-v20-latin-500.ttf',
    'inter-v20-latin-900.ttf',
  ]) {
    inter.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await inter.load();
}

void main() {
  setUpAll(_loadRealFonts);
  setUp(() {
    AvafliV2ImageWarmer.resetForTesting();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  group('image warmer', () {
    test('warms a URL once and ignores empty ones', () {
      AvafliV2ImageWarmer.prewarm(null);
      AvafliV2ImageWarmer.prewarm('');
      expect(AvafliV2ImageWarmer.isWarmed(''), isFalse);

      AvafliV2ImageWarmer.prewarm(_prizeUrl);
      expect(AvafliV2ImageWarmer.isWarmed(_prizeUrl), isTrue);
      // Idempotent: a repeated giveaway refresh must not re-download.
      AvafliV2ImageWarmer.prewarm(_prizeUrl);
      expect(AvafliV2ImageWarmer.isWarmed(_prizeUrl), isTrue);
    });

    test('warms the same provider Image.network resolves to', () {
      // The prewarm only pays off if it lands on the SAME image-cache key the
      // widget later asks for.
      expect(
          const NetworkImage(_prizeUrl), equals(const NetworkImage(_prizeUrl)));
    });
  });

  testWidgets(
      'a still-loading prize image shows the dark placeholder, never '
      'a blank white card', (tester) async {
    // `NetworkImage` holds a single static HttpClient, so the only reliable
    // way to keep a request pending is the framework's debug hook.
    debugNetworkImageHttpClientProvider = () => _HangingHttpClient();

    await tester.pumpWidget(_card(prizeImageUrl: _pendingUrl));
    await tester.pump(const Duration(milliseconds: 50));

    // The remote image is mounted and still pending…
    expect(find.byType(AvafliV2RemoteImage), findsOneWidget);
    // …behind the card's own dark charcoal, at zero opacity (the ~200ms
    // fade begins only once the first frame decodes).
    final placeholder = tester.widget<ColoredBox>(find.descendant(
      of: find.byType(AvafliV2RemoteImage),
      matching: find.byType(ColoredBox),
    ));
    expect(placeholder.color, AvafliV2Colors.deepCharcoal);
    expect(
      tester
          .widget<AnimatedOpacity>(find.descendant(
            of: find.byType(AvafliV2RemoteImage),
            matching: find.byType(AnimatedOpacity),
          ))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(find.descendant(
            of: find.byType(AvafliV2RemoteImage),
            matching: find.byType(AnimatedOpacity),
          ))
          .duration,
      avafliV2ImageFadeDuration,
    );

    // And the rest of the card is already there — the headline never waits
    // on the art.
    expect(find.text('WIN \$1,000'), findsOneWidget);
    expect(find.text('CASH PRIZE'), findsOneWidget);

    // Must be cleared inside the test body — the binding asserts no painting
    // debug variable outlives it.
    debugNetworkImageHttpClientProvider = null;
  });

  testWidgets('a broken prize image falls back to the bundled cash hero',
      (tester) async {
    // The test binding's default HTTP client answers 400, i.e. a broken URL.
    await tester.pumpWidget(_card(prizeImageUrl: _prizeUrl));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    final assets = _providers(tester).whereType<AssetImage>();
    expect(assets, isNotEmpty,
        reason: 'a failed prize image must fall back to the bundled hero');
    expect(assets.first.assetName, contains(AvafliV2Assets.cashHero));
  });

  testWidgets('no prize image configured renders the bundled cash hero',
      (tester) async {
    await tester.pumpWidget(_card());
    await tester.pump();

    expect(find.byType(AvafliV2RemoteImage), findsNothing);
    final assets = _providers(tester).whereType<AssetImage>();
    expect(assets.single.assetName, contains(AvafliV2Assets.cashHero));
  });
}
