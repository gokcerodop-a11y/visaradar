// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'VisaRadar';

  @override
  String get navRadar => 'Radar';

  @override
  String get navTrips => 'Trips';

  @override
  String get navCountry => 'Country';

  @override
  String get navSettings => 'Settings';

  @override
  String get onboardingWelcome => 'Welcome to VisaRadar';

  @override
  String get onboardingWelcomeSubtitle => 'Your intelligent travel companion';

  @override
  String get onboardingNationality => 'What is your nationality?';

  @override
  String get onboardingPassportType => 'Passport type';

  @override
  String get onboardingResidencePermit => 'Do you have a residence permit?';

  @override
  String get onboardingTravelMode => 'How do you mostly travel?';

  @override
  String get onboardingLanguage => 'Choose your language';

  @override
  String get onboardingPermissions => 'Allow permissions';

  @override
  String get onboardingPermissionsLocation =>
      'Location – required for border detection';

  @override
  String get onboardingPermissionsNotification =>
      'Notifications – for stay limit alerts';

  @override
  String get onboardingLegal => 'Legal';

  @override
  String get onboardingLegalAcknowledge =>
      'I agree to the Terms & Privacy Policy';

  @override
  String get buttonNext => 'Next';

  @override
  String get buttonDone => 'Done';

  @override
  String get buttonAllow => 'Allow';

  @override
  String get buttonSkip => 'Skip';

  @override
  String get radarTitle => 'Radar';

  @override
  String get radarCurrentCountry => 'Current Country';

  @override
  String get radarCurrentCity => 'Current City';

  @override
  String get radarUnknownLocation => 'Detecting location…';

  @override
  String get radarSchengenCard => 'Schengen Status';

  @override
  String radarDaysUsed(int days) {
    return '$days days used';
  }

  @override
  String radarDaysRemaining(int days) {
    return '$days days remaining';
  }

  @override
  String get radarSchengenWindowLabel => '90 / 180-day window';

  @override
  String get radarRiskSafe => 'Safe';

  @override
  String get radarRiskWarning => 'Warning';

  @override
  String get radarRiskCritical => 'Critical';

  @override
  String get radarAlertsCard => 'Alerts';

  @override
  String get radarNoAlerts => 'No active alerts';

  @override
  String get countryInfoTitle => 'Country Info';

  @override
  String get countryInfoWeather => 'Weather';

  @override
  String get countryInfoFeelsLike => 'Feels like';

  @override
  String get countryInfoHumidity => 'Humidity';

  @override
  String get countryInfoWind => 'Wind';

  @override
  String get countryInfoVisibility => 'Visibility';

  @override
  String get countryInfoUV => 'UV Index';

  @override
  String get countryInfoAirQuality => 'Air Quality';

  @override
  String get countryInfoCurrency => 'Currency';

  @override
  String get countryInfoConsulate => 'Consulate';

  @override
  String get countryInfoPolice => 'Police';

  @override
  String get countryInfoHospital => 'Hospital';

  @override
  String get placeholderComingSoon => 'Coming soon';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsProfile => 'Profile';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsSubscription => 'Subscription';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get settingsAbout => 'About VisaRadar';

  @override
  String get subscriptionTitle => 'VisaRadar Premium';

  @override
  String get subscriptionTrialInfo => '7-day free trial';

  @override
  String get subscriptionPriceEur => '€4.99 / month';

  @override
  String get subscriptionPriceTry => '₺200 / month';

  @override
  String get subscriptionStartTrial => 'Start Free Trial';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorLocationUnavailable => 'Location unavailable';

  @override
  String get errorNetworkUnavailable => 'No internet connection';
}
