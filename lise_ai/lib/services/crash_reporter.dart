import 'package:flutter/foundation.dart';

// ── CrashBackend (interface) ──────────────────────────────────────────────────

/// Implement this to wire a real crash SDK (Firebase Crashlytics, Sentry, etc.)
abstract class CrashBackend {
  /// Record a non-fatal or fatal error.
  Future<void> recordError({
    required String tag,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    required bool fatal,
  });

  /// Record a breadcrumb / custom log message.
  Future<void> log(String message);

  /// Set a custom key-value pair for the next crash report.
  Future<void> setCustomKey(String key, Object value);

  /// Associate the current user identity with crash reports.
  Future<void> setUserId(String? userId);
}

// ── Stub backends (no-ops — replace with real SDKs) ───────────────────────────

class _FirebaseCrashlyticsBackend implements CrashBackend {
  // TODO: add firebase_crashlytics dependency and uncomment:
  // import 'package:firebase_crashlytics/firebase_crashlytics.dart';
  @override Future<void> recordError({required String tag, required String message, Object? error, StackTrace? stackTrace, required bool fatal}) async {
    // await FirebaseCrashlytics.instance.recordError(error ?? message, stackTrace, fatal: fatal);
  }
  @override Future<void> log(String message) async {
    // await FirebaseCrashlytics.instance.log(message);
  }
  @override Future<void> setCustomKey(String key, Object value) async {
    // await FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
  }
  @override Future<void> setUserId(String? userId) async {
    // await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
  }
}

class _SentryBackend implements CrashBackend {
  // TODO: add sentry_flutter dependency and uncomment:
  // import 'package:sentry_flutter/sentry_flutter.dart';
  @override Future<void> recordError({required String tag, required String message, Object? error, StackTrace? stackTrace, required bool fatal}) async {
    // await Sentry.captureException(error ?? message, stackTrace: stackTrace);
  }
  @override Future<void> log(String message) async {
    // Sentry.addBreadcrumb(Breadcrumb(message: message));
  }
  @override Future<void> setCustomKey(String key, Object value) async {}
  @override Future<void> setUserId(String? userId) async {
    // Sentry.configureScope((scope) => scope.setUser(SentryUser(id: userId)));
  }
}

class _NoOpBackend implements CrashBackend {
  @override Future<void> recordError({required String tag, required String message, Object? error, StackTrace? stackTrace, required bool fatal}) async {}
  @override Future<void> log(String message) async {}
  @override Future<void> setCustomKey(String key, Object value) async {}
  @override Future<void> setUserId(String? userId) async {}
}

// ── CrashReporter ─────────────────────────────────────────────────────────────

/// Singleton crash reporting hub.
///
/// By default uses [_NoOpBackend] (safe no-op).
/// Attach a real backend before the app starts:
///
/// ```dart
/// CrashReporter.instance.attachBackend(_FirebaseCrashlyticsBackend());
/// ```
class CrashReporter {
  CrashReporter._();
  static final CrashReporter instance = CrashReporter._();

  CrashBackend _backend = _NoOpBackend();
  String? _userId;

  // ── Configuration ─────────────────────────────────────────────────────────

  void attachBackend(CrashBackend backend) {
    _backend = backend;
    if (_userId != null) _backend.setUserId(_userId);
  }

  Future<void> setUserId(String? userId) async {
    _userId = userId;
    await _backend.setUserId(userId);
  }

  // ── Error reporting ────────────────────────────────────────────────────────

  Future<void> recordError({
    required String tag,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) async {
    // Debug: suppress non-fatal to keep logcat clean.
    if (!fatal && kDebugMode) return;
    await _backend.recordError(
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      fatal: fatal,
    );
  }

  Future<void> log(String message) => _backend.log(message);

  Future<void> setKey(String key, Object value) =>
      _backend.setCustomKey(key, value);

  // ── Flutter error hook ────────────────────────────────────────────────────

  /// Install as [FlutterError.onError] to catch framework errors.
  void handleFlutterError(FlutterErrorDetails details) {
    debugPrint('[CrashReporter] Flutter error: ${details.exceptionAsString()}');
    recordError(
      tag: 'Flutter',
      message: details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
      fatal: false,
    );
  }

  /// Install as [PlatformDispatcher.instance.onError] to catch zone errors.
  bool handlePlatformError(Object error, StackTrace stack) {
    debugPrint('[CrashReporter] Platform error: $error');
    recordError(
      tag: 'Platform',
      message: error.toString(),
      error: error,
      stackTrace: stack,
      fatal: false,
    );
    return true;
  }
}
