/// Centralized app constants. Import this file anywhere instead of
/// scattering magic strings and numbers throughout the codebase.
library;

class AppConstants {
  AppConstants._();

  // ── Identity ──────────────────────────────────────────────────────────────
  static const String appName        = 'Lise AI';
  static const String appBundleId    = 'com.example.liseAi';
  static const String supportEmail   = 'destek@liseai.app';
  static const String privacyUrl     = 'https://liseai.app/gizlilik';
  static const String termsUrl       = 'https://liseai.app/kullanim';

  // ── Storage keys ──────────────────────────────────────────────────────────
  static const String keyOnboardingDone  = 'onboarding_done';
  static const String keyStudentLevel    = 'student_level';
  static const String keyTargetExam      = 'target_exam';
  static const String keyTeacherStyle    = 'teacher_style';
  static const String keyDailyGoalMins   = 'daily_goal_minutes';
  static const String keyApiKey          = 'api_key_override';

  // ── Limits ────────────────────────────────────────────────────────────────
  static const int maxHistoryTurns    = 40;   // Claude context window guard
  static const int maxSubtitleItems   = 8;    // visible subtitle lines
  static const int sessionTimeoutMins = 120;  // session auto-save threshold

  // ── Timing ────────────────────────────────────────────────────────────────
  static const Duration ambientTickInterval = Duration(milliseconds: 200);
  static const Duration silenceCheckIn      = Duration(seconds: 32);
  static const Duration silenceDeepPrompt   = Duration(seconds: 90);

  // ── Analytics ─────────────────────────────────────────────────────────────
  static const int analyticsWindowDays = 14;  // lookback for insights

  // ── Thresholds ────────────────────────────────────────────────────────────
  static const double successHighThreshold = 0.70;
  static const double successLowThreshold  = 0.42;
  static const double masteryThreshold     = 0.80;
}
