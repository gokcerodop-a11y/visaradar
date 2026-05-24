/// Environment configuration — dev vs staging vs prod.
///
/// Selected at build time via --dart-define=APP_ENV=prod
/// Defaults to 'dev' so local runs always work without extra flags.
library;

enum AppEnvironment { dev, staging, prod }

class EnvironmentConfig {
  EnvironmentConfig._();

  static const String _envName =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static AppEnvironment get environment => switch (_envName) {
        'prod'    => AppEnvironment.prod,
        'staging' => AppEnvironment.staging,
        _         => AppEnvironment.dev,
      };

  static bool get isDev     => environment == AppEnvironment.dev;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProd    => environment == AppEnvironment.prod;

  // ── Per-environment settings ──────────────────────────────────────────────

  /// Maximum tokens for Claude API calls. Prod uses lower limit to control cost.
  static int get maxTokens => isProd ? 1200 : 2000;

  /// Anthropic API base URL (useful for staging proxy).
  static String get anthropicBaseUrl => 'https://api.anthropic.com';

  /// Enable verbose AppLogger output.
  static bool get verboseLogging => !isProd;

  /// Whether to show developer-only UI elements.
  static bool get showDevUI => isDev;

  /// Crash reporting DSN / endpoint (placeholder).
  static String get crashReportingDsn =>
      isProd ? 'https://crash.liseai.app/ingest' : '';
}
