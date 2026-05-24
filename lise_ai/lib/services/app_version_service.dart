import 'package:flutter/foundation.dart';

/// Provides app version information.
///
/// Version is injected at build time via --dart-define or read from pubspec.
/// Actual package_info_plus integration can be added when the dependency is
/// available; until then, constants serve as source of truth.
class AppVersionService {
  AppVersionService._();

  static const String _version =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const String _buildNumber =
      String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');

  static String get version     => _version;
  static String get buildNumber => _buildNumber;
  static String get fullVersion => '$_version+$_buildNumber';

  static bool get isDebug => kDebugMode;

  /// Human-readable release label, e.g. "v1.0.0 (1)" or "v1.0.0-debug"
  static String get releaseLabel =>
      isDebug ? 'v$_version-debug' : 'v$_version ($buildNumber)';
}
