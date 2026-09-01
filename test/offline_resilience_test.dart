// Offline resilience (launch item 15): same-day retry queue for
// registration/claims plus the bounded offline analytics buffer. Mirrors the
// iOS OfflineResilienceTests / Android OfflineResilienceTest.

import 'package:flutter_test/flutter_test.dart';
import 'package:avafli_sdk/src/avafli_error.dart';
import 'package:avafli_sdk/src/offline/offline_resilience.dart';
import 'package:avafli_sdk/src/services/analytics/analytics_adapter.dart';
import 'package:avafli_sdk/src/storage/storage.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory Storage — no SharedPreferences plumbing needed.
class _MemoryStorage implements Storage {
  final Map<String, Object> map = {};

  @override
  Future<void> setString(String key, String value) async => map[key] = value;

  @override
  Future<String?> getString(String key) async => map[key] as String?;

  @override
  Future<void> setInt(String key, int value) async => map[key] = value;

  @override
  Future<int?> getInt(String key) async => map[key] as int?;

  @override
  Future<void> setBool(String key, bool value) async => map[key] = value;

  @override
  Future<bool?> getBool(String key) async => map[key] as bool?;

  @override
  Future<void> remove(String key) async => map.remove(key);

  @override
  Future<void> clear() async => map.clear();

  @override
  Future<bool> containsKey(String key) async => map.containsKey(key);
}

class _SpyAnalyticsAdapter implements AnalyticsAdapter {
  final List<(String, Map<String, dynamic>?)> events = [];

  @override
  void track(String eventName, [Map<String, dynamic>? parameters]) {
    events.add((eventName, parameters));
  }

  @override
  void setUserProperty(String name, String value) {}

  @override
  void identify(String userId) {}
}

void main() {
  // -------------------------------------------------------------------------
  // Classifier
  // -------------------------------------------------------------------------

  group('OfflineErrorClassifier', () {
    test('transport-marked networkError is retriable', () {
      const transportFailure =
          AvafliException(AvafliError.networkError, null, true);
      expect(OfflineErrorClassifier.isRetriable(transportFailure), isTrue);
    });

    test('plain networkError (e.g. a mapped HTTP 429) is NOT retriable', () {
      const mapped429 = AvafliException(AvafliError.networkError);
      expect(OfflineErrorClassifier.isRetriable(mapped429), isFalse);
    });

    test('backend rejections are not retriable', () {
      for (final error in [
        AvafliError.ineligibleToday,
        AvafliError.geographyNotAllowed,
        AvafliError.authenticationFailed,
        AvafliError.serviceUnavailable,
        AvafliError.serverError,
        AvafliError.emailRequired,
        AvafliError.unknown,
      ]) {
        expect(
            OfflineErrorClassifier.isRetriable(AvafliException(error)), isFalse,
            reason: '$error must not auto-retry');
      }
      expect(OfflineErrorClassifier.isRetriable(Exception('boom')), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Retry coordinator
  // -------------------------------------------------------------------------

  group('OfflineRetryCoordinator', () {
    late _MemoryStorage storage;

    setUp(() {
      storage = _MemoryStorage();
    });

    OfflineRetryCoordinator makeCoordinator({String? Function()? dayKey}) {
      return OfflineRetryCoordinator(
        storage: storage,
        dayKeyProvider: dayKey ?? () => '2026-09-01',
        // Instant "backoff" so tests never wait on real time — the schedule
        // stays finite (5 slots) either way.
        delayFn: (_) async {},
      );
    }

    test('enqueue persists the intent across coordinator instances', () async {
      final first = makeCoordinator();
      await first.enqueue(PendingIntentKind.claim);
      expect(await first.pendingKinds(), [PendingIntentKind.claim]);
      first.shutdown();

      // A brand-new coordinator over the same storage (≈ app relaunch)
      // still sees the pending intent.
      final second = makeCoordinator();
      expect(await second.pendingKinds(), [PendingIntentKind.claim]);
      second.shutdown();
    });

    test('storage key uses the winr_ namespace', () async {
      final coordinator = makeCoordinator();
      await coordinator.enqueue(PendingIntentKind.claim);
      expect(storage.map.containsKey('winr_offline_pending_intents'), isTrue);
      coordinator.shutdown();
    });

    test('clear removes only that kind', () async {
      final coordinator = makeCoordinator();
      await coordinator.enqueue(PendingIntentKind.claim);
      await coordinator.enqueue(PendingIntentKind.registration);
      await coordinator.clear(PendingIntentKind.claim);
      expect(
          await coordinator.pendingKinds(), [PendingIntentKind.registration]);
      coordinator.shutdown();
    });

    test('re-enqueueing a kind keeps one intent', () async {
      final coordinator = makeCoordinator();
      await coordinator.enqueue(PendingIntentKind.claim);
      await coordinator.enqueue(PendingIntentKind.claim);
      expect((await coordinator.pendingKinds()).length, 1);
      coordinator.shutdown();
    });

    test('same-day guard drops an intent from a previous local day', () async {
      var today = '2026-09-01';
      final coordinator = makeCoordinator(dayKey: () => today);
      await coordinator.enqueue(PendingIntentKind.claim);
      expect(await coordinator.pendingKinds(), [PendingIntentKind.claim]);

      // Cross local midnight — the intent must be dropped, not replayed:
      // server-authoritative day windows make a stale-day claim a NEW-day
      // claim, which is the auto-open engine's decision.
      today = '2026-09-02';
      expect(await coordinator.pendingKinds(), isEmpty);
      // And the drop is persisted.
      expect(storage.map.containsKey('winr_offline_pending_intents'), isFalse);
      coordinator.shutdown();
    });

    test('success clears the intent after one attempt', () async {
      final coordinator = makeCoordinator();
      var attempts = 0;
      coordinator.retryHandler = (_) async {
        attempts++;
        return RetryOutcome.success;
      };
      await coordinator.enqueue(PendingIntentKind.claim);
      // Let the (instant-delay) backoff loop run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(attempts, 1);
      expect(await coordinator.pendingKinds(), isEmpty);
      coordinator.shutdown();
    });

    test('permanent failure drops the intent', () async {
      final coordinator = makeCoordinator();
      var attempts = 0;
      coordinator.retryHandler = (_) async {
        attempts++;
        return RetryOutcome.permanentFailure;
      };
      await coordinator.enqueue(PendingIntentKind.claim);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(attempts, 1);
      expect(await coordinator.pendingKinds(), isEmpty);
      coordinator.shutdown();
    });

    test('retriable failure keeps the intent for a later trigger', () async {
      final coordinator = makeCoordinator();
      coordinator.retryHandler = (_) async => RetryOutcome.retriableFailure;
      await coordinator.enqueue(PendingIntentKind.claim);
      // Drain the finite backoff loop.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(await coordinator.pendingKinds(), [PendingIntentKind.claim]);
      coordinator.shutdown();
    });

    test('attempts are hard-capped per session across all triggers', () async {
      final coordinator = makeCoordinator();
      var attempts = 0;
      coordinator.retryHandler = (_) async {
        attempts++;
        return RetryOutcome.retriableFailure;
      };
      await coordinator.enqueue(PendingIntentKind.claim);
      // Drain the backoff loop, then hammer the triggers well past the cap.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      for (var i = 0; i < 20; i++) {
        coordinator.noteForeground();
        coordinator.noteLaunch();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }

      expect(attempts, OfflineRetryCoordinator.maxAttemptsPerSession);
      expect(coordinator.attemptCount(PendingIntentKind.claim),
          OfflineRetryCoordinator.maxAttemptsPerSession);
      // The intent stays persisted for the NEXT session (fresh cap).
      expect(await coordinator.pendingKinds(), [PendingIntentKind.claim]);
      coordinator.shutdown();
    });

    test('corrupt persisted queue is dropped, not fatal', () async {
      storage.map['winr_offline_pending_intents'] = 'not json {{{';
      final coordinator = makeCoordinator();
      expect(await coordinator.pendingKinds(), isEmpty);
      expect(storage.map.containsKey('winr_offline_pending_intents'), isFalse);
      coordinator.shutdown();
    });
  });

  // -------------------------------------------------------------------------
  // Buffering analytics adapter
  // -------------------------------------------------------------------------

  group('BufferingAnalyticsAdapter', () {
    late _MemoryStorage storage;
    late _SpyAnalyticsAdapter spy;
    late bool online;

    setUp(() {
      storage = _MemoryStorage();
      spy = _SpyAnalyticsAdapter();
      online = true;
    });

    BufferingAnalyticsAdapter makeAdapter({int Function()? nowMs}) {
      return BufferingAnalyticsAdapter(
        inner: spy,
        storage: storage,
        isOnline: () => online,
        nowMs: nowMs,
      );
    }

    test('online events pass straight through', () {
      final adapter = makeAdapter();
      adapter.track('avafli_experience_presented', {'giveaway_id': 'g1'});
      expect(spy.events.length, 1);
      expect(spy.events.single.$1, 'avafli_experience_presented');
      expect(adapter.bufferedCount, 0);
    });

    test('offline events are buffered, not forwarded', () async {
      online = false;
      final adapter = makeAdapter();
      adapter.track('e1', {'a': 1});
      adapter.track('e2');
      await Future<void>.delayed(Duration.zero); // let persistence settle
      expect(spy.events, isEmpty);
      expect(adapter.bufferedCount, 2);
      expect(storage.map.containsKey('winr_offline_analytics_buffer'), isTrue);
    });

    test('buffer persists across adapter instances (next launch)', () async {
      online = false;
      final first = makeAdapter();
      first.track('e1');
      await Future<void>.delayed(Duration.zero);

      // New adapter over the same storage (≈ next launch).
      final secondLaunch = makeAdapter();
      await secondLaunch.loadPersisted();
      expect(secondLaunch.bufferedCount, 1);
      online = true;
      secondLaunch.flush();
      expect(spy.events.map((e) => e.$1).toList(), ['e1']);
      expect(secondLaunch.bufferedCount, 0);
    });

    test('flush preserves order and attaches original timestamps', () {
      online = false;
      var now = 1756600000000;
      final adapter = makeAdapter(nowMs: () => now);
      adapter.track('first', {'n': 1});
      now += 60000;
      adapter.track('second', {'n': 2});

      online = true;
      adapter.flush();

      expect(spy.events.map((e) => e.$1).toList(), ['first', 'second']);
      final firstParams = spy.events[0].$2!;
      expect(firstParams['n'], 1);
      expect(firstParams['original_timestamp_ms'], 1756600000000);
      expect(
        firstParams['original_timestamp'],
        DateTime.fromMillisecondsSinceEpoch(1756600000000, isUtc: true)
            .toIso8601String(),
      );
      expect(spy.events[1].$2!['original_timestamp_ms'], 1756600060000);
    });

    test('ring buffer drops oldest beyond capacity (hard cap 100)', () {
      online = false;
      final adapter = makeAdapter();
      for (var i = 0; i < BufferingAnalyticsAdapter.capacity + 25; i++) {
        adapter.track('e$i');
      }
      expect(adapter.bufferedCount, BufferingAnalyticsAdapter.capacity);

      online = true;
      adapter.flush();
      expect(spy.events.length, BufferingAnalyticsAdapter.capacity);
      // Oldest 25 dropped; the first surviving event is e25.
      expect(spy.events.first.$1, 'e25');
      expect(spy.events.last.$1, 'e${BufferingAnalyticsAdapter.capacity + 24}');
    });

    test('live event after reconnect flushes the backlog first', () {
      online = false;
      final adapter = makeAdapter();
      adapter.track('buffered');

      online = true;
      adapter.track('live');

      // Order preserved: the offline backlog lands before the live event.
      expect(spy.events.map((e) => e.$1).toList(), ['buffered', 'live']);
      expect(adapter.bufferedCount, 0);
    });

    test('flushIfOnline is a no-op while offline', () {
      online = false;
      final adapter = makeAdapter();
      adapter.track('e1');
      adapter.flushIfOnline();
      expect(spy.events, isEmpty);
      expect(adapter.bufferedCount, 1);
    });

    test('flush with an empty buffer is a no-op', () {
      makeAdapter().flush();
      expect(spy.events, isEmpty);
    });
  });
}
