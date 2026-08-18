import 'dart:developer' as developer;
import '../winr_options.dart';

/// Internal logging utility for the WINR SDK.
///
/// Provides leveled logging that can be controlled via [WINROptions.logging]
/// to help with development and debugging.
class Logger {
  static final Logger _instance = Logger._internal();
  static Logger get instance => _instance;

  Logger._internal();

  /// Current logging level
  LoggingLevel level = LoggingLevel.error;

  /// Logs a message at the error level.
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_shouldLog(LoggingLevel.error)) {
      developer.log(
        message,
        name: 'WINR SDK',
        level: 1000, // Error level
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Logs a message at the info level.
  void info(String message) {
    if (_shouldLog(LoggingLevel.info)) {
      developer.log(
        message,
        name: 'WINR SDK',
        level: 800, // Info level
      );
    }
  }

  /// Logs a message at the debug level.
  void debug(String message) {
    if (_shouldLog(LoggingLevel.debug)) {
      developer.log(
        message,
        name: 'WINR SDK',
        level: 700, // Debug level
      );
    }
  }

  /// Logs a message with an explicit level.
  void log(String message, {LoggingLevel level = LoggingLevel.info}) {
    switch (level) {
      case LoggingLevel.none:
        break;
      case LoggingLevel.error:
        error(message);
        break;
      case LoggingLevel.info:
        info(message);
        break;
      case LoggingLevel.debug:
        debug(message);
        break;
    }
  }

  /// Checks if a message should be logged based on current level.
  bool _shouldLog(LoggingLevel messageLevel) {
    if (level == LoggingLevel.none) return false;

    final currentLevelValue = _getLevelValue(level);
    final messageLevelValue = _getLevelValue(messageLevel);

    return messageLevelValue >= currentLevelValue;
  }

  /// Gets numeric value for logging level comparison.
  int _getLevelValue(LoggingLevel level) {
    switch (level) {
      case LoggingLevel.none:
        return 0;
      case LoggingLevel.error:
        return 1;
      case LoggingLevel.info:
        return 2;
      case LoggingLevel.debug:
        return 3;
    }
  }
}
