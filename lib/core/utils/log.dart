import 'package:flutter/foundation.dart';

/// Lightweight leveled logger. In debug builds output goes to the console;
/// release builds stay silent unless [force] is set.
abstract final class Log {
  static bool force = false;

  static void _emit(String level, String tag, Object message) {
    if (!kDebugMode && !force) return;
    // ignore: avoid_print
    print('[$level] $tag: $message');
  }

  static void debug(String tag, Object message) => _emit('DEBUG', tag, message);
  static void info(String tag, Object message) => _emit('INFO ', tag, message);
  static void warn(String tag, Object message) => _emit('WARN ', tag, message);
  static void error(String tag, Object message, [Object? error]) =>
      _emit('ERROR', tag, error == null ? message : '$message — $error');
}