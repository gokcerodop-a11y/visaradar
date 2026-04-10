import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'VisaRadar'**
  String get appName;

  /// No description provided for @navRadar.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get navRadar;

  /// No description provided for @navTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get navTrips;

  /// No description provided for @navCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get navCountry;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VisaRadar'**
  String get onboardingWelcome;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your intelligent travel companion'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingNationality.
  ///
  /// In en, this message translates to:
  /// **'What is your nationality?'**
  String get onboardingNationality;

  /// No description provided for @onboardingPassportType.
  ///
  /// In en, this message translates to:
  /// **'Passport type'**
  String get onboardingPassportType;

  /// No description provided for @onboardingResidencePermit.
  ///
  /// In en, this message translates to:
  /// **'Do you have a residence permit?'**
  String get onboardingResidencePermit;

  /// No description provided for @onboardingTravelMode.
  ///
  /// In en, this message translates to:
  /// **'How do you mostly travel?'**
  String get onboardingTravelMode;

  /// No description provided for @onboardingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onboardingLanguage;

  /// No description provided for @onboardingPermissions.
  ///
  /// In en, this message translates to:
  /// **'Allow permissions'**
  String get onboardingPermissions;

  /// No description provided for @onboardingPermissionsLocation.
  ///
  /// In en, this message translates to:
  /// **'Location – required for border detection'**
  String get onboardingPermissionsLocation;

  /// No description provided for @onboardingPermissionsNotification.
  ///
  /// In en, this message translates to:
  /// **'Notifications – for stay limit alerts'**
  String get onboardingPermissionsNotification;

  /// No description provided for @onboardingLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get onboardingLegal;

  /// No description provided for @onboardingLegalAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms & Privacy Policy'**
  String get onboardingLegalAcknowledge;

  /// No description provided for @buttonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get buttonNext;

  /// No description provided for @buttonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get buttonDone;

  /// No description provided for @buttonAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get buttonAllow;

  /// No description provided for @buttonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get buttonSkip;

  /// No description provided for @radarTitle.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get radarTitle;

  /// No description provided for @radarCurrentCountry.
  ///
  /// In en, this message translates to:
  /// **'Current Country'**
  String get radarCurrentCountry;

  /// No description provided for @radarCurrentCity.
  ///
  /// In en, this message translates to:
  /// **'Current City'**
  String get radarCurrentCity;

  /// No description provided for @radarUnknownLocation.
  ///
  /// In en, this message translates to:
  /// **'Detecting location…'**
  String get radarUnknownLocation;

  /// No description provided for @radarSchengenCard.
  ///
  /// In en, this message translates to:
  /// **'Schengen Status'**
  String get radarSchengenCard;

  /// No description provided for @radarDaysUsed.
  ///
  /// In en, this message translates to:
  /// **'{days} days used'**
  String radarDaysUsed(int days);

  /// No description provided for @radarDaysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{days} days remaining'**
  String radarDaysRemaining(int days);

  /// No description provided for @radarSchengenWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'90 / 180-day window'**
  String get radarSchengenWindowLabel;

  /// No description provided for @radarRiskSafe.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get radarRiskSafe;

  /// No description provided for @radarRiskWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get radarRiskWarning;

  /// No description provided for @radarRiskCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get radarRiskCritical;

  /// No description provided for @radarAlertsCard.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get radarAlertsCard;

  /// No description provided for @radarNoAlerts.
  ///
  /// In en, this message translates to:
  /// **'No active alerts'**
  String get radarNoAlerts;

  /// No description provided for @countryInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Country Info'**
  String get countryInfoTitle;

  /// No description provided for @countryInfoWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get countryInfoWeather;

  /// No description provided for @countryInfoFeelsLike.
  ///
  /// In en, this message translates to:
  /// **'Feels like'**
  String get countryInfoFeelsLike;

  /// No description provided for @countryInfoHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get countryInfoHumidity;

  /// No description provided for @countryInfoWind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get countryInfoWind;

  /// No description provided for @countryInfoVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get countryInfoVisibility;

  /// No description provided for @countryInfoUV.
  ///
  /// In en, this message translates to:
  /// **'UV Index'**
  String get countryInfoUV;

  /// No description provided for @countryInfoAirQuality.
  ///
  /// In en, this message translates to:
  /// **'Air Quality'**
  String get countryInfoAirQuality;

  /// No description provided for @countryInfoCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get countryInfoCurrency;

  /// No description provided for @countryInfoConsulate.
  ///
  /// In en, this message translates to:
  /// **'Consulate'**
  String get countryInfoConsulate;

  /// No description provided for @countryInfoPolice.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get countryInfoPolice;

  /// No description provided for @countryInfoHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get countryInfoHospital;

  /// No description provided for @placeholderComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get placeholderComingSoon;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get settingsSubscription;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegal;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTerms;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About VisaRadar'**
  String get settingsAbout;

  /// No description provided for @subscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'VisaRadar Premium'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionTrialInfo.
  ///
  /// In en, this message translates to:
  /// **'7-day free trial'**
  String get subscriptionTrialInfo;

  /// No description provided for @subscriptionPriceEur.
  ///
  /// In en, this message translates to:
  /// **'€4.99 / month'**
  String get subscriptionPriceEur;

  /// No description provided for @subscriptionPriceTry.
  ///
  /// In en, this message translates to:
  /// **'₺200 / month'**
  String get subscriptionPriceTry;

  /// No description provided for @subscriptionStartTrial.
  ///
  /// In en, this message translates to:
  /// **'Start Free Trial'**
  String get subscriptionStartTrial;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get errorLocationUnavailable;

  /// No description provided for @errorNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNetworkUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
