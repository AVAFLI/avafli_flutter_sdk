// Resilience to infrastructure refusals (RESILIENCE_SPEC, Oct 15 2026): when
// a traffic step outruns warm Cloud Run instances the platform refuses the
// overflow at once with HTTP 429/500 and a plain-text body ("The request was
// aborted because there was no available instance.") — no callable JSON.
// Instances arrive within ~10–30 s. The network client tells that apart from
// a backend ANSWER (a callable error body) and retries only the former on a
// bounded, jittered schedule.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:avafli_sdk/src/avafli_error.dart';
import 'package:avafli_sdk/src/avafli_options.dart';
import 'package:avafli_sdk/src/network/api_request.dart';
import 'package:avafli_sdk/src/network/network_client.dart';
import 'package:avafli_sdk/src/offline/offline_resilience.dart';
import 'package:avafli_sdk/src/services/logger.dart';

const _noInstance =
    'The request was aborted because there was no available instance.';
const _html = '<html><body><h1>503 Service Unavailable</h1></body></html>';

class _PingRequest extends PostRequest<Map<String, dynamic>> {
  @override
  String get endpoint => '/ping';

  @override
  Map<String, dynamic>? get body => null;

  @override
  Map<String, dynamic> parseResponse(http.Response response) =>
      parseJsonResponse(response);
}

http.Response _ok() => http.Response(
    jsonEncode({
      'result': {'ok': true}
    }),
    200);

http.Response _callable(int status, String grpcStatus, String message) =>
    http.Response(
        jsonEncode({
          'error': {'message': message, 'status': grpcStatus}
        }),
        status);

void main() {
  late int httpCalls;
  late List<Duration> delays;
  late List<String> retryLogs;

  /// Backend stand-in: answers from [responses] in order, repeating the last.
  NetworkClientImpl makeClient(List<http.Response> responses) {
    httpCalls = 0;
    delays = [];
    final mock = MockClient((request) async {
      final i = httpCalls++;
      return responses[i < responses.length ? i : responses.length - 1];
    });
    return NetworkClientImpl(
      baseURL: 'https://example.test',
      apiKey: 'winr_test_key',
      client: mock,
      delayFn: (d) async => delays.add(d),
    );
  }

  setUp(() {
    retryLogs = [];
    Logger.instance.listener = (level, message) {
      if (level == LoggingLevel.debug &&
          message.startsWith('Infrastructure refusal')) {
        retryLogs.add(message);
      }
    };
  });

  tearDown(() {
    Logger.instance.listener = null;
  });

  /// Each jittered delay is `random(0, base)` + the 250 ms floor.
  void expectWithinSchedule(List<Duration> actual) {
    const floor = NetworkClientImpl.infraRetryFloor;
    for (var i = 0; i < actual.length; i++) {
      final base = NetworkClientImpl.infraRetryBaseDelays[i];
      expect(actual[i], greaterThanOrEqualTo(floor),
          reason: 'retry ${i + 1} must respect the jitter floor');
      expect(actual[i], lessThanOrEqualTo(base + floor),
          reason: 'retry ${i + 1} must not exceed its base + floor');
    }
  }

  test('1. 429 with a plain-text body is retried and succeeds on attempt 3',
      () async {
    final client = makeClient([
      http.Response(_noInstance, 429),
      http.Response(_noInstance, 429),
      _ok(),
    ]);

    final result = await client.send(_PingRequest());

    expect(result['ok'], isTrue);
    expect(httpCalls, 3);
    expect(delays.length, 2);
    expectWithinSchedule(delays);
    final total = delays.fold(Duration.zero, (a, b) => a + b);
    expect(total, lessThanOrEqualTo(const Duration(milliseconds: 3500)),
        reason: 'two retries: at most (1 s + 250 ms) + (2 s + 250 ms)');
    // One debug line per retry, each naming status, attempt and delay.
    expect(retryLogs.length, 2);
    expect(retryLogs[0], contains('HTTP 429'));
    expect(retryLogs[0], contains('retry 1/4'));
    expect(retryLogs[0], contains('${delays[0].inMilliseconds} ms'));
    expect(retryLogs[1], contains('retry 2/4'));
    expect(retryLogs[1], contains('${delays[1].inMilliseconds} ms'));
  });

  test('2. 503 with an HTML body is retried and succeeds on attempt 3',
      () async {
    final client = makeClient([
      http.Response(_html, 503),
      http.Response(_html, 503),
      _ok(),
    ]);

    final result = await client.send(_PingRequest());

    expect(result['ok'], isTrue);
    expect(httpCalls, 3);
    expect(delays.length, 2);
    expectWithinSchedule(delays);
    expect(retryLogs.length, 2);
    expect(retryLogs.every((l) => l.contains('HTTP 503')), isTrue);
  });

  test('3. 429 with a callable RESOURCE_EXHAUSTED body is NOT retried',
      () async {
    final client = makeClient([
      _callable(429, 'RESOURCE_EXHAUSTED',
          'Too many requests. Please try again later.'),
      _ok(),
    ]);

    await expectLater(
      client.send(_PingRequest()),
      throwsA(isA<AvafliException>()
          .having((e) => e.retryable, 'retryable', isFalse)
          .having((e) => e.error, 'error', isNot(AvafliError.networkError))
          .having((e) => e.serverMessage, 'serverMessage',
              'Too many requests. Please try again later.')),
    );
    expect(httpCalls, 1, reason: 'surfaced at once — the app error it is');
    expect(delays, isEmpty);
    expect(retryLogs, isEmpty);
  });

  test('4. a 400 callable error is NOT retried', () async {
    final client = makeClient([
      _callable(400, 'INVALID_ARGUMENT', 'Missing giveaway id.'),
      _ok(),
    ]);

    await expectLater(
      client.send(_PingRequest()),
      throwsA(isA<AvafliException>()
          .having((e) => e.retryable, 'retryable', isFalse)
          .having((e) => e.error, 'error', AvafliError.unknown)
          .having(
              (e) => e.serverMessage, 'serverMessage', 'Missing giveaway id.')),
    );
    expect(httpCalls, 1);
    expect(delays, isEmpty);
  });

  test(
      '5. exhausted after 4 retries → serverError, and the offline queue '
      'does NOT enqueue it', () async {
    final client = makeClient([http.Response(_noInstance, 500)]);

    Object? caught;
    try {
      await client.send(_PingRequest());
    } catch (e) {
      caught = e;
    }

    expect(caught, isA<AvafliException>());
    final e = caught! as AvafliException;
    expect(e.error, AvafliError.serverError);
    expect(e.statusCode, 500);
    expect(e.transport, isFalse);
    expect(httpCalls, 5, reason: 'the first attempt plus four retries');
    expect(delays.length, 4);
    expectWithinSchedule(delays);
    final total = delays.fold(Duration.zero, (a, b) => a + b);
    expect(total, lessThanOrEqualTo(const Duration(seconds: 16)),
        reason: '1+2+4+8 s base + 4 × 250 ms floor');
    expect(retryLogs.length, 4);
    // The server answered — it was just busy. Transport-only queue stays out.
    expect(OfflineErrorClassifier.isRetriable(e), isFalse);
  });

  test('6. Retry-After: 3 makes the first delay 3 s', () async {
    final client = makeClient([
      http.Response(_noInstance, 429, headers: {'retry-after': '3'}),
      _ok(),
    ]);

    final result = await client.send(_PingRequest());

    expect(result['ok'], isTrue);
    expect(delays, [const Duration(seconds: 3)]);
  });

  test('Retry-After is clamped to the floor and the 10 s cap', () async {
    expect(NetworkClientImpl.parseRetryAfter('0'), Duration.zero);
    expect(NetworkClientImpl.parseRetryAfter('120'),
        const Duration(seconds: 120));
    expect(NetworkClientImpl.parseRetryAfter(null), isNull);
    expect(NetworkClientImpl.parseRetryAfter('Wed, 21 Oct 2026 07:28:00 GMT'),
        isNull);

    final capped = makeClient([
      http.Response(_noInstance, 503, headers: {'retry-after': '120'}),
      _ok(),
    ]);
    await capped.send(_PingRequest());
    expect(delays, [NetworkClientImpl.infraRetryAfterCap]);

    final floored = makeClient([
      http.Response(_noInstance, 503, headers: {'retry-after': '0'}),
      _ok(),
    ]);
    await floored.send(_PingRequest());
    expect(delays, [NetworkClientImpl.infraRetryFloor]);
  });

  test('a callable 5xx (the function ran and failed) is NOT retried',
      () async {
    final client = makeClient([
      _callable(500, 'INTERNAL', 'Something broke.'),
      _ok(),
    ]);

    await expectLater(
      client.send(_PingRequest()),
      throwsA(isA<AvafliException>()
          .having((e) => e.error, 'error', AvafliError.serverError)
          .having((e) => e.retryable, 'retryable', isFalse)),
    );
    expect(httpCalls, 1);
    expect(delays, isEmpty);
  });
}
