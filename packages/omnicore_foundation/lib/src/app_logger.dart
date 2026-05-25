import 'package:flutter/foundation.dart';
import 'crash_reporter.dart';

// ── Log level ─────────────────────────────────────────────────────────────────

enum LogLevel { info, warn, error, critical }

// ── AppLogger ─────────────────────────────────────────────────────────────────

/// Centralized structured logger.
///
/// Log levels:
/// - [info]     : debug-only. Stripped in release.
/// - [warn]     : debug-only. Stripped in release.
/// - [error]    : always printed. Forwarded to CrashReporter as non-fatal.
/// - [critical] : always printed. Forwarded to CrashReporter as fatal breadcrumb.
///
/// Sensitive data (prompts, API keys) is redacted when [redactSensitive] is true
/// (default: true in release, false in debug).
class AppLogger {
  AppLogger._();

  /// When true, long AI prompt strings and API-key-shaped tokens are redacted.
  static bool redactSensitive = !kDebugMode;

  // ── Public API ─────────────────────────────────────────────────────────────

  static void info(String tag, String message) {
    if (!kDebugMode) return;
    debugPrint(_format(LogLevel.info, tag, message));
  }

  static void warn(String tag, String message) {
    if (!kDebugMode) return;
    debugPrint(_format(LogLevel.warn, tag, message));
  }

  static void error(
    String tag,
    String message, [
    Object? err,
    StackTrace? stack,
  ]) {
    final msg = _format(LogLevel.error, tag,
        err != null ? '$message: $err' : message);
    debugPrint(msg);
    if (stack != null && kDebugMode) {
      debugPrintStack(stackTrace: stack, maxFrames: 8);
    }
    // Forward to crash reporter (non-fatal).
    CrashReporter.instance.recordError(
      tag: tag,
      message: message,
      error: err,
      stackTrace: stack,
      fatal: false,
    );
  }

  static void critical(
    String tag,
    String message, [
    Object? err,
    StackTrace? stack,
  ]) {
    final msg = _format(LogLevel.critical, tag,
        err != null ? '$message: $err' : message);
    // Critical always prints, even in release.
    // ignore: avoid_print
    print(msg);
    if (stack != null) {
      debugPrintStack(stackTrace: stack, maxFrames: 16);
    }
    CrashReporter.instance.recordError(
      tag: tag,
      message: message,
      error: err,
      stackTrace: stack,
      fatal: true,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _format(LogLevel level, String tag, String message) {
    final prefix = switch (level) {
      LogLevel.info     => '[$tag]',
      LogLevel.warn     => '[WARN/$tag]',
      LogLevel.error    => '[ERROR/$tag]',
      LogLevel.critical => '[CRITICAL/$tag]',
    };
    final safe = redactSensitive ? _redact(message) : message;
    return '$prefix $safe';
  }

  /// Redact strings that look like API keys or long AI prompts.
  static String _redact(String input) {
    // Redact sk-ant-... or similar API key patterns.
    var out = input.replaceAllMapped(
      RegExp(r'(sk-ant-[A-Za-z0-9\-_]{10,}|Bearer\s+[A-Za-z0-9\-_.]{20,})'),
      (_) => '[REDACTED_KEY]',
    );
    // Truncate very long strings (likely AI prompts / chat history).
    if (out.length > 300) {
      out = '${out.substring(0, 297)}…';
    }
    return out;
  }
}
