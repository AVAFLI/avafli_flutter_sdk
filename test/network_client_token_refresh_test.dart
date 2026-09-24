// Token-refresh hardening (Sept 24 2026 Skape cold-open failure): a cold open
// after days away fired 2–3 parallel authed calls with a dead token, each
// earned a 401, each kicked off its own refreshToken, and the retry died on a
// flaky link. The network client now (1) refreshes BEFORE sending when the
// cached JWT's `exp` is past, and (2) shares one in-flight refresh between
// concurrent callers.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:avafli_sdk/src/avafli_error.dart';
import 'package:avafli_sdk/src/network/api_request.dart';
import 'package:avafli_sdk/src/network/network_client.dart';

/// Unsigned JWT with the given `exp` (seconds since epoch) — the pre-check
/// reads the payload only, so the signature segment can be anything.
String _jwt({required int expSeconds}) {
  String seg(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${seg({'sub': 'u1', 'exp': expSeconds})}.sig';
}

int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

class _PingRequest extends PostRequest<Map<String, dynamic>> {
  @override
  String get endpoint => '/ping';

  @override
  Map<String, dynamic>? get body => null;

  @override
  Map<String, dynamic> parseResponse(http.Response response) =>
      parseJsonResponse(response);
}

void main() {
  group('isTokenExpiringSoon', () {
    test('past exp is expiring', () {
      expect(
          NetworkClientImpl.isTokenExpiringSoon(
              _jwt(expSeconds: _nowSeconds() - 10)),
          isTrue);
    });

    test('exp inside the 60 s leeway is expiring', () {
      expect(
          NetworkClientImpl.isTokenExpiringSoon(
              _jwt(expSeconds: _nowSeconds() + 30)),
          isTrue);
    });

    test('exp comfortably in the future is not', () {
      expect(
          NetworkClientImpl.isTokenExpiringSoon(
              _jwt(expSeconds: _nowSeconds() + 3600)),
          isFalse);
    });

    test('non-JWT / no-exp tokens are left to the server', () {
      // The pre-check is an optimisation only — it must never block a
      // request on its own; the 401 → refresh path still covers these.
      expect(NetworkClientImpl.isTokenExpiringSoon('opaque-token'), isFalse);
      final noExp = '${base64Url.encode(utf8.encode('{}'))}.'
          '${base64Url.encode(utf8.encode('{"sub":"u1"}'))}.sig';
      expect(NetworkClientImpl.isTokenExpiringSoon(noExp), isFalse);
      expect(NetworkClientImpl.isTokenExpiringSoon('a.!!!.c'), isFalse);
    });
  });

  group('NetworkClientImpl token refresh', () {
    late List<String?> authHeadersSeen;
    late String liveToken;
    late NetworkClientImpl client;

    /// Backend stand-in: 401 unless the Bearer token is [liveToken].
    NetworkClientImpl makeClient() {
      authHeadersSeen = [];
      final mock = MockClient((request) async {
        authHeadersSeen.add(request.headers['Authorization']);
        if (request.headers['Authorization'] != 'Bearer $liveToken') {
          return http.Response(
              jsonEncode({
                'error': {
                  'message': 'Unauthenticated',
                  'status': 'UNAUTHENTICATED'
                }
              }),
              401);
        }
        return http.Response(
            jsonEncode({
              'result': {'ok': true}
            }),
            200);
      });
      return NetworkClientImpl(
        baseURL: 'https://example.test',
        apiKey: 'winr_test_key',
        client: mock,
      );
    }

    setUp(() {
      liveToken = _jwt(expSeconds: _nowSeconds() + 3600);
      client = makeClient();
    });

    test('expired cached token is refreshed BEFORE the request (no 401 trip)',
        () async {
      var refreshes = 0;
      client.setAuthToken(_jwt(expSeconds: _nowSeconds() - 300));
      client.setRefreshHandler(() async {
        refreshes++;
        return liveToken;
      });

      final result = await client.send(_PingRequest());

      expect(result['ok'], isTrue);
      expect(refreshes, 1);
      // Exactly one wire request, and it already carried the fresh token —
      // the dead token never went out.
      expect(authHeadersSeen, ['Bearer $liveToken']);
    });

    test('pre-check refresh that yields no token surfaces authenticationFailed',
        () async {
      client.setAuthToken(_jwt(expSeconds: _nowSeconds() - 300));
      client.setRefreshHandler(() async => null);

      await expectLater(
        client.send(_PingRequest()),
        throwsA(isA<AvafliException>()
            .having((e) => e.error, 'error', AvafliError.authenticationFailed)),
      );
      // Nothing was sent with the dead token.
      expect(authHeadersSeen, isEmpty);
    });

    test(
        'a valid-looking token that the server rejects still refreshes via 401',
        () async {
      var refreshes = 0;
      // Not expired by `exp`, but revoked server-side (a different token
      // from [liveToken], which the mock backend is the only one to accept).
      client.setAuthToken(_jwt(expSeconds: _nowSeconds() + 7200));
      client.setRefreshHandler(() async {
        refreshes++;
        return liveToken;
      });

      final result = await client.send(_PingRequest());

      expect(result['ok'], isTrue);
      expect(refreshes, 1);
      expect(authHeadersSeen.length, 2);
      expect(authHeadersSeen.last, 'Bearer $liveToken');
    });

    test('concurrent callers with a dead token share ONE refresh', () async {
      var refreshes = 0;
      final gate = Completer<void>();
      // Opaque token: no exp pre-check, so every caller has to eat the 401
      // first — the worst case for a refresh stampede.
      client.setAuthToken('dead-opaque-token');
      client.setRefreshHandler(() async {
        refreshes++;
        await gate.future; // hold the refresh open while the others pile in
        return liveToken;
      });

      final inFlight = [
        client.send(_PingRequest()),
        client.send(_PingRequest()),
        client.send(_PingRequest()),
      ];
      // Let all three hit the 401 and reach the refresh.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(refreshes, 1,
          reason: 'only one refreshToken call may be in flight');
      gate.complete();

      final results = await Future.wait(inFlight);
      expect(results.every((r) => r['ok'] == true), isTrue);
      expect(refreshes, 1);
      // Three dead-token requests, three successful retries — no more.
      expect(authHeadersSeen.where((h) => h == 'Bearer $liveToken').length, 3);
    });

    test('concurrent callers with an EXPIRED token share ONE pre-check refresh',
        () async {
      var refreshes = 0;
      final gate = Completer<void>();
      client.setAuthToken(_jwt(expSeconds: _nowSeconds() - 300));
      client.setRefreshHandler(() async {
        refreshes++;
        await gate.future;
        return liveToken;
      });

      final inFlight = [
        client.send(_PingRequest()),
        client.send(_PingRequest()),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(refreshes, 1);
      gate.complete();

      await Future.wait(inFlight);
      expect(refreshes, 1);
      // Neither request went out with the expired token.
      expect(authHeadersSeen, ['Bearer $liveToken', 'Bearer $liveToken']);
    });

    test(
        'a 401 that lands after a sibling already rotated the token retries '
        'with the new token instead of refreshing again', () async {
      // Per-request gates so the two dead-token 401s can be released one at
      // a time: A's 401 → A refreshes → THEN B's 401 arrives.
      final gates = <Completer<void>>[];
      authHeadersSeen = [];
      final mock = MockClient((request) async {
        final auth = request.headers['Authorization'];
        authHeadersSeen.add(auth);
        if (auth != 'Bearer $liveToken') {
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
          return http.Response(
              jsonEncode({
                'error': {'message': 'Unauthenticated'}
              }),
              401);
        }
        return http.Response(
            jsonEncode({
              'result': {'ok': true}
            }),
            200);
      });
      final client = NetworkClientImpl(
        baseURL: 'https://example.test',
        apiKey: 'winr_test_key',
        client: mock,
      );
      var refreshes = 0;
      client.setAuthToken('dead-opaque-token');
      client.setRefreshHandler(() async {
        refreshes++;
        client.setAuthToken(liveToken);
        return liveToken;
      });

      final a = client.send(_PingRequest());
      final b = client.send(_PingRequest());
      await Future<void>.delayed(Duration.zero);
      expect(gates.length, 2, reason: 'both went out with the dead token');

      // A's 401 lands and its refresh completes before B hears anything.
      gates[0].complete();
      await a;
      expect(refreshes, 1);

      gates[1].complete();
      await b;
      expect(refreshes, 1, reason: 'B must reuse the rotated token');
      // dead, dead, then two live retries — no third dead-token request.
      expect(authHeadersSeen.where((h) => h == 'Bearer $liveToken').length, 2);
      expect(
          authHeadersSeen.where((h) => h == 'Bearer dead-opaque-token').length,
          2);
    });

    test('a failed refresh (handler throws) is not retried in a loop',
        () async {
      var refreshes = 0;
      client.setAuthToken('dead-opaque-token');
      client.setRefreshHandler(() async {
        refreshes++;
        return null;
      });

      await expectLater(
        client.send(_PingRequest()),
        throwsA(isA<AvafliException>()
            .having((e) => e.error, 'error', AvafliError.authenticationFailed)),
      );
      expect(refreshes, 1);
      expect(authHeadersSeen, ['Bearer dead-opaque-token']);
    });
  });
}
