import 'package:flutter/foundation.dart';

/// Centralized app logger.
///
/// - [info] / [warn]: only printed in debug builds (stripped in release).
/// - [error]: always printed (important for crash diagnosis).
class AppLogger {
  AppLogger._();

  static void info(String tag, String message) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  static void warn(String tag, String message) {
    if (kDebugMode) debugPrint('[WARN/$tag] $message');
  }

  static void error(String tag, String message,
      [Object? err, StackTrace? stack]) {
    // Errors printed in all modes for crash triage.
    debugPrint('[ERROR/$tag] $message${err != null ? ': $err' : ''}');
    if (stack != null && kDebugMode) {
      debugPrintStack(stackTrace: stack, maxFrames: 8);
    }
  }
}
