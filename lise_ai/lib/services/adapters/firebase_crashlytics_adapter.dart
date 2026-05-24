// firebase_crashlytics_adapter.dart
// Firebase Crashlytics adapter — PLACEHOLDER (no SDK connected yet).
//
// To activate:
//   1. Add to pubspec.yaml:
//        firebase_crashlytics: ^4.x.x
//   2. In main(), after Firebase.initializeApp():
//        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
//   3. Attach this adapter to CrashReporter:
//        CrashReporter.instance.attachBackend(FirebaseCrashlyticsAdapter());
//   4. Uncomment all TODO blocks below

// ignore_for_file: unused_import
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'backend_adapters.dart';

class FirebaseCrashlyticsAdapter implements CrashAdapter {
  // TODO: FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  @override
  Future<void> recordError(Object error, StackTrace? stack,
      {bool fatal = false}) async {
    // TODO:
    // await _crashlytics.recordError(error, stack, fatal: fatal);
  }

  @override
  Future<void> log(String message) async {
    // TODO: _crashlytics.log(message);
  }

  @override
  Future<void> setUserId(String? userId) async {
    // TODO:
    // if (userId != null) {
    //   await _crashlytics.setUserIdentifier(userId);
    // }
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    // TODO: await _crashlytics.setCustomKey(key, value.toString());
  }
}
