// Google Places (New) address autocomplete for the claim address step (2.9).
//
// The backend ships an optional `sdkConfig.placesApiKey`
// (config/integrations.placesApiKey — client-shippable by design). When
// present, the claim form's Street Address field offers suggestions from
// `places.googleapis.com`; when absent, the field is a plain text input.
//
// Design rules (mirrors the platform spec):
// - US-only sweepstakes → `includedRegionCodes: ["us"]` and address-shaped
//   primary types only (street_address / premise / subpremise).
// - EVERY failure — network, non-200, malformed JSON — degrades silently to
//   plain typing. Autocomplete assists entry; it must never block it.
// - Uses the SDK's existing networking stack (`package:http`); no new
//   dependencies and no Places SDK plugin.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One row in the suggestions overlay: the place to resolve on tap plus the
/// display line (`suggestion.placePrediction.text.text`).
@immutable
class WINRPlaceSuggestion {
  final String placeId;
  final String description;

  const WINRPlaceSuggestion({required this.placeId, required this.description});
}

/// A resolved US shipping address mapped onto the claim form's four address
/// fields. Empty strings mean the component was missing — the person types
/// it by hand (all fields stay editable regardless).
@immutable
class WINRPlaceAddress {
  final String street;
  final String city;

  /// `administrative_area_level_1` shortText ("CA") per the platform spec.
  final String state;
  final String zip;

  const WINRPlaceAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
  });

  /// Maps Places (New) `addressComponents` onto the form fields:
  /// - street = `street_number` + `route`
  /// - city   = `locality`, else `sublocality`, else `postal_town`
  /// - state  = `administrative_area_level_1` shortText
  /// - zip    = `postal_code`
  ///
  /// Null-tolerant against partial payloads; anything unrecognized is
  /// ignored.
  factory WINRPlaceAddress.fromComponents(List<dynamic> components) {
    String streetNumber = '';
    String route = '';
    String locality = '';
    String sublocality = '';
    String postalTown = '';
    String state = '';
    String zip = '';

    for (final component in components) {
      if (component is! Map<String, dynamic>) continue;
      final types = component['types'];
      if (types is! List) continue;
      final longText = component['longText'] as String? ?? '';
      final shortText = component['shortText'] as String? ?? '';

      if (types.contains('street_number')) {
        streetNumber = longText;
      } else if (types.contains('route')) {
        route = longText;
      } else if (types.contains('locality')) {
        locality = longText;
      } else if (types.contains('sublocality') ||
          types.contains('sublocality_level_1')) {
        sublocality = longText;
      } else if (types.contains('postal_town')) {
        postalTown = longText;
      } else if (types.contains('administrative_area_level_1')) {
        state = shortText;
      } else if (types.contains('postal_code')) {
        zip = longText;
      }
    }

    final street = [streetNumber, route]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    final city = locality.trim().isNotEmpty
        ? locality
        : (sublocality.trim().isNotEmpty ? sublocality : postalTown);

    return WINRPlaceAddress(
      street: street.trim(),
      city: city.trim(),
      state: state.trim(),
      zip: zip.trim(),
    );
  }
}

/// Thin client over the Places API (New) REST endpoints. Fail-quiet by
/// contract: [autocomplete] returns an empty list and [resolve] returns null
/// on ANY failure — callers never see an exception.
class WINRPlacesClient {
  /// At most this many suggestions are surfaced (the API may return more).
  static const int maxSuggestions = 5;

  static const Duration _timeout = Duration(seconds: 8);
  static const String _baseUrl = 'https://places.googleapis.com/v1';

  final String apiKey;
  final http.Client _http;

  /// Whether [dispose] should close the client (only when we created it —
  /// an injected client belongs to the caller/test).
  final bool _ownsHttp;

  WINRPlacesClient({required this.apiKey, http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null;

  /// POST `places:autocomplete` — US-only, address-shaped results, capped at
  /// [maxSuggestions]. Empty list on any failure.
  Future<List<WINRPlaceSuggestion>> autocomplete(String input) async {
    try {
      final response = await _http
          .post(
            Uri.parse('$_baseUrl/places:autocomplete'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
            },
            body: jsonEncode({
              'input': input,
              'includedRegionCodes': ['us'],
              'includedPrimaryTypes': [
                'street_address',
                'premise',
                'subpremise',
              ],
            }),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return const [];
      final raw = data['suggestions'];
      if (raw is! List) return const [];

      final out = <WINRPlaceSuggestion>[];
      for (final item in raw) {
        if (out.length >= maxSuggestions) break;
        if (item is! Map<String, dynamic>) continue;
        final prediction = item['placePrediction'];
        if (prediction is! Map<String, dynamic>) continue;
        final placeId = prediction['placeId'] as String?;
        final text = prediction['text'];
        final description =
            text is Map<String, dynamic> ? text['text'] as String? : null;
        if (placeId == null || placeId.isEmpty) continue;
        if (description == null || description.isEmpty) continue;
        out.add(WINRPlaceSuggestion(placeId: placeId, description: description));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// GET `places/{placeId}` with a field mask of only `addressComponents`
  /// (the smallest — and cheapest — details request that fills the form).
  /// Null on any failure.
  Future<WINRPlaceAddress?> resolve(String placeId) async {
    try {
      final response = await _http.get(
        Uri.parse('$_baseUrl/places/${Uri.encodeComponent(placeId)}'),
        headers: {
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'addressComponents',
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final components = data['addressComponents'];
      if (components is! List) return null;
      return WINRPlaceAddress.fromComponents(components);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    if (_ownsHttp) _http.close();
  }
}

/// Debounced query → suggestions state machine for the street field.
///
/// Widget-independent (a [ChangeNotifier]) so the debounce and min-chars
/// rules are unit-testable without any widget machinery, matching the SDK's
/// form-model style.
class WINRAddressAutocomplete extends ChangeNotifier {
  /// Queries shorter than this (trimmed) never hit the network.
  static const int minChars = 3;

  /// Keystroke debounce — one request per typing pause, not per character.
  final Duration debounce;

  final WINRPlacesClient _client;

  Timer? _timer;

  /// Monotonic guard: every query/dismiss bumps it, and an in-flight
  /// response is applied only if it still matches — stale results (slow
  /// responses racing fresh keystrokes, or arriving after a dismiss) are
  /// dropped on the floor.
  int _generation = 0;

  bool _disposed = false;

  List<WINRPlaceSuggestion> _suggestions = const [];
  List<WINRPlaceSuggestion> get suggestions => _suggestions;

  WINRAddressAutocomplete({
    required WINRPlacesClient client,
    this.debounce = const Duration(milliseconds: 300),
  }) : _client = client;

  /// Feed every user keystroke of the street field here (wire it to
  /// `TextField.onChanged` so programmatic fills after a selection don't
  /// re-trigger a query).
  void onQueryChanged(String text) {
    final query = text.trim();
    _timer?.cancel();
    _timer = null;
    final generation = ++_generation;

    if (query.length < minChars) {
      _setSuggestions(const []);
      return;
    }

    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(_fetch(query, generation));
    });
  }

  Future<void> _fetch(String query, int generation) async {
    final results = await _client.autocomplete(query);
    if (_disposed || generation != _generation) return;
    _setSuggestions(results);
  }

  /// Hides the suggestions (outside tap, back, focus loss, step change) and
  /// invalidates anything in flight.
  void dismiss() {
    _timer?.cancel();
    _timer = null;
    _generation++;
    _setSuggestions(const []);
  }

  /// Resolves a tapped suggestion to a full address (dismissing the list
  /// immediately). Null → the resolution failed; the caller leaves the form
  /// exactly as typed (silent degradation).
  Future<WINRPlaceAddress?> select(WINRPlaceSuggestion suggestion) {
    dismiss();
    return _client.resolve(suggestion.placeId);
  }

  void _setSuggestions(List<WINRPlaceSuggestion> value) {
    if (_suggestions.isEmpty && value.isEmpty) return;
    _suggestions = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
