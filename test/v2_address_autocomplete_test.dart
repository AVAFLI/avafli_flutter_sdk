// Google Places address autocomplete on the claim address step (2.9):
// - component → form-field mapping (incl. missing zip and city fallbacks)
// - debounce + min-chars gating of the autocomplete requests
// - suggestion tap fills street/city/state/zip (all still editable)
// - no `placesApiKey` → the street field is a plain text input (no
//   suggestions machinery at all).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:avafli_sdk/src/network/places_autocomplete.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_claim.dart';
import 'package:avafli_sdk/src/ui/v2/avafli_v2_theme.dart';

// ── Fixtures ──

Map<String, dynamic> component(String type, String long, [String? short]) => {
      'longText': long,
      'shortText': short ?? long,
      'types': [type],
    };

List<Map<String, dynamic>> googleplexComponents({bool withZip = true}) => [
      component('street_number', '1600'),
      component('route', 'Amphitheatre Parkway', 'Amphitheatre Pkwy'),
      component('locality', 'Mountain View'),
      component('administrative_area_level_1', 'California', 'CA'),
      if (withZip) component('postal_code', '94043'),
      component('country', 'United States', 'US'),
    ];

String autocompleteBody(List<Map<String, String>> predictions) => jsonEncode({
      'suggestions': [
        for (final p in predictions)
          {
            'placePrediction': {
              'placeId': p['placeId'],
              'text': {'text': p['text']},
            },
          },
      ],
    });

/// A recording Places backend: captures every request and serves canned
/// autocomplete + details responses.
class _FakePlaces {
  final List<http.Request> requests = [];
  final List<Map<String, String>> predictions;
  final List<Map<String, dynamic>> detailsComponents;

  _FakePlaces({
    this.predictions = const [
      {
        'placeId': 'place-googleplex',
        'text': '1600 Amphitheatre Pkwy, Mountain View, CA, USA'
      },
    ],
    List<Map<String, dynamic>>? detailsComponents,
  }) : detailsComponents = detailsComponents ?? googleplexComponents();

  List<http.Request> get autocompleteRequests => requests
      .where((r) => r.url.path.endsWith('places:autocomplete'))
      .toList();

  List<http.Request> get detailsRequests =>
      requests.where((r) => r.url.path.contains('/v1/places/')).toList();

  AvafliPlacesClient client({String apiKey = 'AIza-test-key'}) {
    return AvafliPlacesClient(
      apiKey: apiKey,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('places:autocomplete')) {
          return http.Response(autocompleteBody(predictions), 200);
        }
        return http.Response(
          jsonEncode({'addressComponents': detailsComponents}),
          200,
        );
      }),
    );
  }
}

// ── Widget host (mirrors v2_claim_widgets_test.dart) ──

Widget _host(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(child: child),
  );
}

Widget stepsFlow({AvafliPlacesClient? placesClient, String? placesApiKey}) {
  return _host(AvafliV2ClaimStepsFlow(
    accent: AvafliV2Accent(null).color,
    logoUrl: null,
    maskedEmail: 'c******a@avafli.example.com',
    initialForm:
        AvafliPrizeClaimForm(firstName: 'Catherine', lastName: 'Cinosta'),
    placesApiKey: placesApiKey,
    placesClient: placesClient,
    isSubmitting: false,
    submitError: null,
    onSubmit: (_) {},
    onClose: () {},
  ));
}

/// Advances the prefilled step 1 onto the address step.
Future<void> gotoAddressStep(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.ensureVisible(find.text('CONTINUE'));
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();
  expect(find.text('STEP 2 OF 2'), findsOneWidget);
}

void main() {
  group('AvafliPlaceAddress.fromComponents', () {
    test('maps street/city/state/zip from a full component set', () {
      final address = AvafliPlaceAddress.fromComponents(googleplexComponents());
      expect(address.street, '1600 Amphitheatre Parkway');
      expect(address.city, 'Mountain View');
      // administrative_area_level_1 maps from shortText per the spec.
      expect(address.state, 'CA');
      expect(address.zip, '94043');
    });

    test('missing zip maps to an empty string (hand-typed later)', () {
      final address = AvafliPlaceAddress.fromComponents(
          googleplexComponents(withZip: false));
      expect(address.street, '1600 Amphitheatre Parkway');
      expect(address.zip, '');
    });

    test('city falls back to sublocality, then postal_town', () {
      final viaSublocality = AvafliPlaceAddress.fromComponents([
        component('sublocality', 'Brooklyn'),
        component('administrative_area_level_1', 'New York', 'NY'),
      ]);
      expect(viaSublocality.city, 'Brooklyn');

      final viaPostalTown = AvafliPlaceAddress.fromComponents([
        component('postal_town', 'Springfield'),
      ]);
      expect(viaPostalTown.city, 'Springfield');
    });

    test('route without a street_number still yields a street', () {
      final address = AvafliPlaceAddress.fromComponents([
        component('route', 'Amphitheatre Parkway'),
      ]);
      expect(address.street, 'Amphitheatre Parkway');
    });

    test('empty/garbage components map to all-empty fields', () {
      final address =
          AvafliPlaceAddress.fromComponents(const ['nope', 42, null]);
      expect(address.street, '');
      expect(address.city, '');
      expect(address.state, '');
      expect(address.zip, '');
    });
  });

  group('AvafliPlacesClient', () {
    test('caps suggestions at 5 and reads placePrediction.text.text', () async {
      final fake = _FakePlaces(predictions: [
        for (var i = 0; i < 7; i++)
          {'placeId': 'place-$i', 'text': '$i Main St, Springfield, IL, USA'},
      ]);
      final results = await fake.client().autocomplete('Main St');
      expect(results.length, AvafliPlacesClient.maxSuggestions);
      expect(results.first.placeId, 'place-0');
      expect(results.first.description, '0 Main St, Springfield, IL, USA');
    });

    test('sends the spec body and key header', () async {
      final fake = _FakePlaces();
      await fake.client(apiKey: 'AIza-abc').autocomplete('123 Main');
      final request = fake.autocompleteRequests.single;
      expect(request.method, 'POST');
      expect(request.headers['X-Goog-Api-Key'], 'AIza-abc');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['input'], '123 Main');
      expect(body['includedRegionCodes'], ['us']);
      expect(
        body['includedPrimaryTypes'],
        ['street_address', 'premise', 'subpremise'],
      );
    });

    test('failures degrade silently: non-200 and garbage → empty/null',
        () async {
      final broken = AvafliPlacesClient(
        apiKey: 'k',
        httpClient: MockClient((_) async => http.Response('nope', 500)),
      );
      expect(await broken.autocomplete('123 Main'), isEmpty);
      expect(await broken.resolve('place-x'), isNull);

      final garbage = AvafliPlacesClient(
        apiKey: 'k',
        httpClient: MockClient((_) async => http.Response('not json', 200)),
      );
      expect(await garbage.autocomplete('123 Main'), isEmpty);
      expect(await garbage.resolve('place-x'), isNull);
    });

    test('resolve requests only the addressComponents field mask', () async {
      final fake = _FakePlaces();
      final address = await fake.client().resolve('place-googleplex');
      final request = fake.detailsRequests.single;
      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/v1/places/place-googleplex'));
      expect(request.headers['X-Goog-FieldMask'], 'addressComponents');
      expect(address?.zip, '94043');
    });
  });

  group('AvafliAddressAutocomplete debounce/min-chars', () {
    testWidgets('under 3 chars never queries; 3+ queries after the debounce',
        (tester) async {
      final fake = _FakePlaces();
      final auto = AvafliAddressAutocomplete(client: fake.client());

      auto.onQueryChanged('12');
      await tester.pump(const Duration(milliseconds: 400));
      expect(fake.requests, isEmpty);

      auto.onQueryChanged('123 Main');
      await tester.pump(const Duration(milliseconds: 200));
      expect(fake.requests, isEmpty, reason: 'debounce still pending');
      await tester.pump(const Duration(milliseconds: 150));
      expect(fake.autocompleteRequests.length, 1);
      expect(auto.suggestions.length, 1);

      auto.dispose();
    });

    testWidgets('rapid typing coalesces to one request with the latest input',
        (tester) async {
      final fake = _FakePlaces();
      final auto = AvafliAddressAutocomplete(client: fake.client());

      auto.onQueryChanged('160');
      await tester.pump(const Duration(milliseconds: 100));
      auto.onQueryChanged('1600 A');
      await tester.pump(const Duration(milliseconds: 100));
      auto.onQueryChanged('1600 Amph');
      await tester.pump(const Duration(milliseconds: 350));

      final request = fake.autocompleteRequests.single;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['input'], '1600 Amph');

      auto.dispose();
    });

    testWidgets('shrinking below 3 chars clears suggestions and cancels',
        (tester) async {
      final fake = _FakePlaces();
      final auto = AvafliAddressAutocomplete(client: fake.client());

      auto.onQueryChanged('1600 Amph');
      await tester.pump(const Duration(milliseconds: 350));
      expect(auto.suggestions, isNotEmpty);

      auto.onQueryChanged('16');
      expect(auto.suggestions, isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(fake.autocompleteRequests.length, 1, reason: 'no second request');

      auto.dispose();
    });

    testWidgets('dismiss() drops an in-flight response', (tester) async {
      final fake = _FakePlaces();
      final auto = AvafliAddressAutocomplete(client: fake.client());

      auto.onQueryChanged('1600 Amph');
      await tester.pump(const Duration(milliseconds: 300));
      auto.dismiss();
      await tester.pump(const Duration(milliseconds: 100));
      expect(auto.suggestions, isEmpty);

      auto.dispose();
    });
  });

  group('claim street field', () {
    testWidgets('absent key → plain field: typing shows no suggestions UI',
        (tester) async {
      await tester.pumpWidget(stepsFlow());
      await gotoAddressStep(tester);

      await tester.enterText(find.byType(TextField).first, '1600 Amph');
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('powered by Google'), findsNothing);
      expect(
        find.textContaining('Mountain View, CA, USA'),
        findsNothing,
      );
    });

    testWidgets(
        'typing surfaces suggestions with attribution; tap fills all four '
        'fields (state code mapped to the picker name), still editable',
        (tester) async {
      final fake = _FakePlaces();
      await tester.pumpWidget(stepsFlow(placesClient: fake.client()));
      await gotoAddressStep(tester);

      final street = find.byType(TextField).first;
      await tester.enterText(street, '1600 Amph');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(
        find.text('1600 Amphitheatre Pkwy, Mountain View, CA, USA'),
        findsOneWidget,
      );
      expect(find.text('powered by Google'), findsOneWidget);

      await tester
          .tap(find.text('1600 Amphitheatre Pkwy, Mountain View, CA, USA'));
      await tester.pumpAndSettle();

      // The list is gone, the four fields are filled — and the state code
      // landed as the picker's canonical full name.
      expect(find.text('powered by Google'), findsNothing);
      expect(find.text('1600 Amphitheatre Parkway'), findsOneWidget);
      expect(find.text('Mountain View'), findsOneWidget);
      expect(find.text('California'), findsOneWidget);
      expect(find.text('94043'), findsOneWidget);
      expect(fake.detailsRequests.length, 1);

      // Everything stays hand-editable.
      await tester.enterText(street, '1 Edited St');
      expect(find.text('1 Edited St'), findsOneWidget);
    });

    testWidgets('failed details resolution leaves the form as typed',
        (tester) async {
      var calls = 0;
      final client = AvafliPlacesClient(
        apiKey: 'k',
        httpClient: MockClient((request) async {
          calls++;
          if (request.url.path.endsWith('places:autocomplete')) {
            return http.Response(
              autocompleteBody(const [
                {'placeId': 'p1', 'text': '5 Haide Pl, Brooklyn, NY, USA'},
              ]),
              200,
            );
          }
          return http.Response('boom', 500);
        }),
      );
      await tester.pumpWidget(stepsFlow(placesClient: client));
      await gotoAddressStep(tester);

      await tester.enterText(find.byType(TextField).first, '5 Haide');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 Haide Pl, Brooklyn, NY, USA'));
      await tester.pumpAndSettle();

      // List dismissed, nothing filled, typed text untouched — degrade
      // silently to plain typing.
      expect(find.text('powered by Google'), findsNothing);
      expect(find.text('5 Haide'), findsOneWidget);
      expect(find.text('Brooklyn'), findsNothing);
      expect(calls, 2);
    });

    testWidgets('tapping outside the field dismisses the suggestions',
        (tester) async {
      final fake = _FakePlaces();
      await tester.pumpWidget(stepsFlow(placesClient: fake.client()));
      await gotoAddressStep(tester);

      await tester.enterText(find.byType(TextField).first, '1600 Amph');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('powered by Google'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('powered by Google'), findsNothing);
    });
  });
}
