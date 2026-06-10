/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'VisaRadar Travel';
  static const String appVersion = '1.0.0';

  // Legal URLs — set to non-empty strings once the pages are live.
  // When empty, the app falls back to showing the in-app legal screen.
  static const String privacyPolicyUrl = ''; // e.g. 'https://visaradar.app/privacy'
  static const String termsUrl = '';         // e.g. 'https://visaradar.app/terms'
  static const String supportUrl = '';       // e.g. 'https://visaradar.app/support'

  // Schengen rule
  static const int schengenMaxDays = 90;
  static const int schengenWindowDays = 180;

  // Subscription placeholders
  static const double priceEurMonthly = 4.99;
  static const double priceTryMonthly = 200.0;
  static const int trialDays = 7;

  // SharedPreferences keys
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyInstallDate = 'install_date_v1'; // ISO8601, first run
  static const String keySelectedLocale = 'selected_locale';
  static const String keyUserProfile = 'user_profile_v1';
  static const String keyTrips = 'trips_v1';
  static const String keyLastKnownCountry = 'last_known_country_v1';
  static const String keyPendingCrossingSuggestion =
      'pending_crossing_suggestion_v1';

  // Risk thresholds (days remaining in Schengen window)
  static const int schengenRiskWarningDays = 15;
  static const int schengenRiskCriticalDays = 5;

  // Notification preferences
  static const String keyNotificationPreferences = 'notification_prefs_v1';
  static const String keyLastDismissedSuggestionAt = 'last_dismissed_suggestion_at';

  // Notification IDs — fixed per category to allow targeted cancel/replace
  static const int notifIdSchengen30 = 1001;
  static const int notifIdSchengen15 = 1002;
  static const int notifIdSchengen7  = 1003;
  static const int notifIdSchengen3  = 1004;
  static const int notifIdSchengen1  = 1005;
  static const int notifIdOngoingStay         = 2001;
  static const int notifIdDismissedCrossing   = 2002;
  static const int notifIdLocationInactive    = 2003;
  static const int notifIdDebugTest           = 9999;
}
