import 'dart:async';
import 'dart:convert';

import '../avafli_error.dart';
import '../services/analytics/analytics_adapter.dart';
import '../services/logger.dart';
import '../storage/storage.dart';

/// Offline resilience (launch item 15): transient network drops must not
/// cause lost streaks or distorted DAU. Scope is deliberately SAME-DAY only —
/// a pending intent is dropped when its local calendar day ends.
/// Cross-midnight backdated replay is explicitly out of scope: the backend's
/// day windows are server-authoritative (a governed anti-fraud contract; the
/// claim transaction keys dedup + streak math off `todayDateString(userTz)` /
/// `current_entry_date`), so a client replaying yesterday's claim after
/// midnight would simply be re-windowed into the new day. Whether the NEW
/// day's claim happens is the auto-open engine's decision, not a stale
/// queue's.
///
/// Duplicate-retry safety (verified against the backend claim transaction):
/// claimDailyEntries dedups server-side by the canonical user's local-day
/// entry window and `daily_last_claimed === today`, throwing an
/// `already-exists` callable error ("Already claimed…" / "You've already
/// entered today…" — reaching this SDK as [AvafliError.ineligibleToday]). A
/// duplicate retry therefore can never double-grant; an already-claimed
/// rejection is treated as SUCCESS by the retry handler.
///
/// Mirrors the iOS reference implementation
/// (AvafliSDK/Services/Offline/OfflineResilience.swift).

// ── Network error classification ──

/// Splits NETWORK-class failures (the request never completed: offline,
/// timeout, connection dropped) from backend rejections. Only the former are
/// safe to retry automatically — a rejection would just be rejected again.
///
/// Relies on the `transport` flag [NetworkClientImpl] stamps on
/// SocketException / HttpException / TimeoutException failures: a PLAIN
/// [AvafliError.networkError] can also be a mapped HTTP 429 or an unknown
/// response, which must NOT auto-retry (matching iOS: transport-only).
class OfflineErrorClassifier {
  OfflineErrorClassifier._();

  static bool isRetriable(Object error) {
    return error is AvafliException &&
        error.error == AvafliError.networkError &&
        error.transport;
  }
}

// ── Online-state heuristic ──

/// Best-effort online flag. Flutter cannot observe connectivity without a new
/// plugin dependency (connectivity_plus is deliberately NOT added), so this
/// is a heuristic the SDK's own network paths maintain: a transport-class
/// failure flips it false, any successful round-trip flips it true. `true`
/// until told otherwise (assume-online default keeps analytics passthrough
/// unbuffered when nothing is known yet).
class OfflineState {
  OfflineState._();

  static bool isOnline = true;
}

// ── Pending intent ──

enum PendingIntentKind { registration, claim }

/// A registration or claim the user meant to happen but the network dropped.
class PendingIntent {
  const PendingIntent({
    required this.kind,
    required this.dayKey,
    required this.createdAtMs,
  });

  final PendingIntentKind kind;

  /// Local calendar day (yyyy-MM-dd, device zone) the intent was created.
  /// The same-day guard drops the intent once this day ends.
  final String dayKey;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'dayKey': dayKey,
        'createdAtMs': createdAtMs,
      };

  static PendingIntent? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final kindName = raw['kind'];
    final dayKey = raw['dayKey'];
    final createdAtMs = raw['createdAtMs'];
    if (kindName is! String || dayKey is! String || createdAtMs is! int) {
      return null;
    }
    for (final kind in PendingIntentKind.values) {
      if (kind.name == kindName) {
        return PendingIntent(
            kind: kind, dayKey: dayKey, createdAtMs: createdAtMs);
      }
    }
    return null;
  }
}

/// Result of one retry attempt, as reported by the retry handler.
enum RetryOutcome {
  /// The call succeeded — or the server said "already claimed", which the
  /// idempotent backend dedup makes equivalent to success.
  success,

  /// A backend rejection. Retrying would only repeat it — drop the intent.
  permanentFailure,

  /// Another transport failure — keep the intent for a later trigger.
  retriableFailure,
}

// ── Retry coordinator ──

/// Persists pending register/claim intents and retries them on app resume,
/// launch, and a capped exponential backoff while the app runs. (Flutter has
/// no connectivity listener without a new dependency — resume/backoff stand
/// in for the connectivity-regain trigger the other SDKs have.)
///
/// HARD caps everywhere: at most [maxAttemptsPerSession] attempts per intent
/// kind per session, and the backoff loop runs a finite schedule then exits —
/// nothing unbounded, and the loop ends early the moment the queue is empty.
class OfflineRetryCoordinator {
  OfflineRetryCoordinator({
    required Storage storage,
    String? Function()? dayKeyProvider,
    int Function()? nowMs,
    List<Duration>? backoffDelays,
    Future<void> Function(Duration)? delayFn,
  })  : _storage = storage,
        _dayKeyProvider = dayKeyProvider ?? _localDayKey,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _backoffDelays = backoffDelays ?? defaultBackoffDelays,
        _delayFn = delayFn ?? ((d) => Future<void>.delayed(d));

  static const int maxAttemptsPerSession = 5;

  /// Finite backoff schedule — 5 slots, the session attempt cap.
  static const List<Duration> defaultBackoffDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
  ];

  final Storage _storage;
  final String? Function() _dayKeyProvider;
  final int Function() _nowMs;
  final List<Duration> _backoffDelays;
  final Future<void> Function(Duration) _delayFn;

  /// Performs the actual retry for a kind. Set once at wiring time.
  Future<RetryOutcome> Function(PendingIntentKind kind)? retryHandler;

  final Map<PendingIntentKind, int> _attemptsThisSession = {};
  bool _passInFlight = false;
  bool _backoffRunning = false;
  bool _shutDown = false;

  static String _localDayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ── Queue ──

  /// Records a pending intent (one per kind — re-enqueueing refreshes the
  /// day key) and arms the in-session backoff retry loop.
  Future<void> enqueue(PendingIntentKind kind) async {
    final intents = await _loadIntents();
    intents.removeWhere((i) => i.kind == kind);
    intents.add(PendingIntent(
      kind: kind,
      dayKey: _dayKeyProvider() ?? _localDayKey(),
      createdAtMs: _nowMs(),
    ));
    await _saveIntents(intents);
    Logger.instance.info('Offline retry queued: ${kind.name}');
    unawaited(_runBackoffIfNeeded());
  }

  Future<void> clear(PendingIntentKind kind) async {
    final intents = await _loadIntents();
    intents.removeWhere((i) => i.kind == kind);
    await _saveIntents(intents);
  }

  /// Currently pending kinds, after the same-day guard pruned stale ones.
  Future<List<PendingIntentKind>> pendingKinds() async {
    final intents = await _prune();
    return intents.map((i) => i.kind).toList();
  }

  int attemptCount(PendingIntentKind kind) => _attemptsThisSession[kind] ?? 0;

  // ── Triggers ──

  /// App came to the foreground — retry immediately.
  void noteForeground() => unawaited(_attemptNow());

  /// App launch — prune stale intents, then retry whatever survived.
  void noteLaunch() => unawaited(_attemptNow());

  /// Stops the backoff loop (configure-time rebuilds and tests).
  void shutdown() {
    _shutDown = true;
  }

  // ── Internals ──

  Future<void> _attemptNow() async {
    if (_shutDown || _passInFlight) return;
    if ((await pendingKinds()).isEmpty) return;
    await _performPass();
  }

  /// One retry pass over the pending kinds. Every attempt counts toward the
  /// hard per-session cap regardless of which trigger fired it.
  Future<void> _performPass() async {
    final handler = retryHandler;
    if (handler == null || _passInFlight) return;
    _passInFlight = true;
    try {
      for (final kind in await pendingKinds()) {
        final attempts = _attemptsThisSession[kind] ?? 0;
        if (attempts >= maxAttemptsPerSession) continue;
        _attemptsThisSession[kind] = attempts + 1;

        final outcome = await handler(kind);
        switch (outcome) {
          case RetryOutcome.success:
            Logger.instance.info('Offline retry succeeded: ${kind.name}');
            await clear(kind);
          case RetryOutcome.permanentFailure:
            Logger.instance
                .info('Offline retry permanently rejected: ${kind.name}');
            await clear(kind);
          case RetryOutcome.retriableFailure:
            Logger.instance.debug('Offline retry still failing: ${kind.name}');
        }
      }
    } finally {
      _passInFlight = false;
    }
  }

  /// Runs the capped exponential-backoff retry loop. The schedule is finite
  /// (5 slots, ~62s total) and the loop exits the moment the queue empties,
  /// the session cap is reached, or [shutdown] is called — never an unbounded
  /// watcher.
  Future<void> _runBackoffIfNeeded() async {
    if (_backoffRunning || _shutDown) return;
    _backoffRunning = true;
    try {
      for (final delay in _backoffDelays) {
        await _delayFn(delay);
        if (_shutDown) break;
        if ((await pendingKinds()).isEmpty) break;
        if (_allKindsCapped()) break;
        await _performPass();
      }
    } finally {
      _backoffRunning = false;
    }
  }

  bool _allKindsCapped() => PendingIntentKind.values.every(
      (kind) => (_attemptsThisSession[kind] ?? 0) >= maxAttemptsPerSession);

  // ── Persistence ──

  Future<List<PendingIntent>> _loadIntents() async {
    final raw = await _storage.getString(StorageKeys.offlinePendingIntents);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('not a list');
      return decoded
          .map(PendingIntent.tryParse)
          .whereType<PendingIntent>()
          .toList();
    } catch (_) {
      // Corrupt value — drop it rather than crash forever.
      await _storage.remove(StorageKeys.offlinePendingIntents);
      return [];
    }
  }

  Future<void> _saveIntents(List<PendingIntent> intents) async {
    if (intents.isEmpty) {
      await _storage.remove(StorageKeys.offlinePendingIntents);
    } else {
      await _storage.setString(StorageKeys.offlinePendingIntents,
          jsonEncode(intents.map((i) => i.toJson()).toList()));
    }
  }

  /// SAME-DAY GUARD: drops any intent whose local calendar day has ended.
  /// The server would re-window a stale claim into the new day anyway
  /// (server-authoritative day windows — governed anti-fraud contract), and
  /// initiating a NEW day's claim is the auto-open engine's job, not ours.
  Future<List<PendingIntent>> _prune() async {
    final today = _dayKeyProvider() ?? _localDayKey();
    final intents = await _loadIntents();
    final fresh = intents.where((i) => i.dayKey == today).toList();
    if (fresh.length != intents.length) {
      Logger.instance.info('Offline retry: dropped '
          '${intents.length - fresh.length} stale (previous-day) intent(s)');
      await _saveIntents(fresh);
    }
    return fresh;
  }
}

// ── Offline analytics buffering ──

/// One buffered publisher-facing analytics event, with its ORIGINAL
/// timestamp so a flush after reconnect doesn't shift the publisher's
/// timeline.
class BufferedAnalyticsEvent {
  const BufferedAnalyticsEvent({
    required this.name,
    this.parameters,
    required this.timestampMs,
  });

  final String name;
  final Map<String, dynamic>? parameters;
  final int timestampMs;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (parameters != null) 'parameters': parameters,
        'timestampMs': timestampMs,
      };

  static BufferedAnalyticsEvent? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final name = raw['name'];
    final timestampMs = raw['timestampMs'];
    if (name is! String || timestampMs is! int) return null;
    final params = raw['parameters'];
    return BufferedAnalyticsEvent(
      name: name,
      parameters: params is Map<String, dynamic> ? params : null,
      timestampMs: timestampMs,
    );
  }
}

/// Wraps the publisher's [AnalyticsAdapter]. While offline, `track`
/// emissions land in a bounded, persisted ring buffer (capacity 100 — oldest
/// dropped first) and are replayed in order once back online / on next
/// launch, each carrying `original_timestamp` (ISO-8601) and
/// `original_timestamp_ms`. `setUserProperty` / `identify` pass through
/// unbuffered (they are state, not events).
///
/// The working buffer is in memory (Dart is single-threaded, so ordering is
/// deterministic) and mirrored to storage after each mutation so it survives
/// a kill; [loadPersisted] merges a previous run's events in at launch.
class BufferingAnalyticsAdapter implements AnalyticsAdapter {
  BufferingAnalyticsAdapter({
    required this.inner,
    required Storage storage,
    bool Function()? isOnline,
    int Function()? nowMs,
  })  : _storage = storage,
        _isOnline = isOnline ?? (() => OfflineState.isOnline),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const int capacity = 100;

  final AnalyticsAdapter inner;
  final Storage _storage;
  final bool Function() _isOnline;
  final int Function() _nowMs;

  final List<BufferedAnalyticsEvent> _buffer = [];

  int get bufferedCount => _buffer.length;

  /// Merges events persisted by a previous run (they predate everything in
  /// this session, so they go to the FRONT). Call once at configure.
  Future<void> loadPersisted() async {
    final raw = await _storage.getString(StorageKeys.offlineAnalyticsBuffer);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('not a list');
      final events = decoded
          .map(BufferedAnalyticsEvent.tryParse)
          .whereType<BufferedAnalyticsEvent>()
          .toList();
      _buffer.insertAll(0, events);
      _capBuffer();
    } catch (_) {
      await _storage.remove(StorageKeys.offlineAnalyticsBuffer);
    }
  }

  @override
  void track(String eventName, [Map<String, dynamic>? parameters]) {
    if (_isOnline()) {
      // Preserve ordering: anything buffered from an offline stretch flushes
      // BEFORE the live event goes through.
      flush();
      inner.track(eventName, parameters);
    } else {
      _buffer.add(BufferedAnalyticsEvent(
        name: eventName,
        parameters: parameters,
        timestampMs: _nowMs(),
      ));
      _capBuffer();
      unawaited(_persist());
    }
  }

  @override
  void setUserProperty(String name, String value) =>
      inner.setUserProperty(name, value);

  @override
  void identify(String userId) => inner.identify(userId);

  /// Replays the buffered events to the wrapped adapter, oldest first.
  /// Called when back online (foreground/launch) and before any live event.
  void flush() {
    if (_buffer.isEmpty) return;
    final events = List<BufferedAnalyticsEvent>.from(_buffer);
    _buffer.clear();
    unawaited(_persist());
    for (final event in events) {
      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(event.timestampMs, isUtc: true);
      inner.track(event.name, {
        ...?event.parameters,
        'original_timestamp': timestamp.toIso8601String(),
        'original_timestamp_ms': event.timestampMs,
      });
    }
  }

  /// Flush only when the online heuristic says the network is back.
  void flushIfOnline() {
    if (_isOnline()) flush();
  }

  void _capBuffer() {
    // Bounded ring buffer — drop oldest beyond capacity. HARD cap.
    if (_buffer.length > capacity) {
      _buffer.removeRange(0, _buffer.length - capacity);
    }
  }

  Future<void> _persist() async {
    if (_buffer.isEmpty) {
      await _storage.remove(StorageKeys.offlineAnalyticsBuffer);
    } else {
      await _storage.setString(StorageKeys.offlineAnalyticsBuffer,
          jsonEncode(_buffer.map((e) => e.toJson()).toList()));
    }
  }
}
