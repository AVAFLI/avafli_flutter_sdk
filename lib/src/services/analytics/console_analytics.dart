import 'dart:developer' as developer;

import 'analytics_adapter.dart';

/// Simple console-based analytics adapter for development and debugging.
///
/// Logs all analytics events to the console using Flutter's developer log.
/// This is useful for development and can serve as a reference implementation
/// for custom analytics adapters.
class ConsoleAnalyticsAdapter implements AnalyticsAdapter {
  /// Whether to include timestamps in log output
  final bool includeTimestamp;

  /// Creates a new console analytics adapter.
  const ConsoleAnalyticsAdapter({
    this.includeTimestamp = true,
  });

  @override
  void track(String eventName, [Map<String, dynamic>? parameters]) {
    final timestamp =
        includeTimestamp ? '[${DateTime.now().toIso8601String()}] ' : '';

    if (parameters != null && parameters.isNotEmpty) {
      final paramsStr =
          parameters.entries.map((e) => '${e.key}: ${e.value}').join(', ');

      developer.log(
        '$timestamp📊 $eventName | $paramsStr',
        name: 'WINR Analytics',
      );
    } else {
      developer.log(
        '$timestamp📊 $eventName',
        name: 'WINR Analytics',
      );
    }
  }

  @override
  void setUserProperty(String name, String value) {
    final timestamp =
        includeTimestamp ? '[${DateTime.now().toIso8601String()}] ' : '';

    developer.log(
      '$timestamp👤 User Property: $name = $value',
      name: 'WINR Analytics',
    );
  }

  @override
  void identify(String userId) {
    final timestamp =
        includeTimestamp ? '[${DateTime.now().toIso8601String()}] ' : '';

    developer.log(
      '$timestamp🆔 User Identified: ${_redact(userId)}',
      name: 'WINR Analytics',
    );
  }

  /// Redacts a user id for console logging — keeps only the last 4 chars so the
  /// raw identifier (PII correlation key) is not leaked to logs.
  static String _redact(String id) =>
      id.length <= 4 ? '****' : '****${id.substring(id.length - 4)}';
}

/// Silent analytics adapter that does nothing.
///
/// Can be used to completely disable analytics tracking.
class NoOpAnalyticsAdapter implements AnalyticsAdapter {
  const NoOpAnalyticsAdapter();

  @override
  void track(String eventName, [Map<String, dynamic>? parameters]) {
    // Do nothing
  }

  @override
  void setUserProperty(String name, String value) {
    // Do nothing
  }

  @override
  void identify(String userId) {
    // Do nothing
  }
}
