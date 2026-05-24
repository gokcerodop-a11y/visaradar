/// Feature flags — compile-time toggles.
///
/// Set to [true] to enable a feature in this build.
/// In CI/CD, override via dart-define: --dart-define=FF_NEW_ONBOARDING=true
library;

class FeatureFlags {
  FeatureFlags._();

  // ── Retention ─────────────────────────────────────────────────────────────
  /// Show streak banner in top bar.
  static const bool streakBanner = bool.fromEnvironment('FF_STREAK_BANNER', defaultValue: true);

  /// Show achievement toast on unlock.
  static const bool achievementToasts = bool.fromEnvironment('FF_ACHIEVEMENT_TOASTS', defaultValue: true);

  /// Session recovery prompt on launch if previous session was interrupted.
  static const bool sessionRecovery = bool.fromEnvironment('FF_SESSION_RECOVERY', defaultValue: true);

  // ── UI ────────────────────────────────────────────────────────────────────
  /// Premium glassmorphism cards.
  static const bool glassmorphism = bool.fromEnvironment('FF_GLASSMORPHISM', defaultValue: true);

  /// Animated gradient in app header.
  static const bool animatedGradient = bool.fromEnvironment('FF_ANIMATED_GRADIENT', defaultValue: true);

  // ── Analytics ─────────────────────────────────────────────────────────────
  /// Local analytics insights computation.
  static const bool localAnalytics = bool.fromEnvironment('FF_LOCAL_ANALYTICS', defaultValue: true);

  // ── Experimental ──────────────────────────────────────────────────────────
  /// Developer diagnostics screen accessible via long-press.
  static const bool diagnosticsScreen = bool.fromEnvironment('FF_DIAGNOSTICS', defaultValue: true);

  /// Demo mode when API key is absent.
  static const bool demoMode = bool.fromEnvironment('FF_DEMO_MODE', defaultValue: true);
}
