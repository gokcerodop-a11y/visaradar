// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'VisaRadar';

  @override
  String get navRadar => 'Radar';

  @override
  String get navTrips => 'Seyahatler';

  @override
  String get navCountry => 'Ülke';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get onboardingWelcome => 'VisaRadar\'a Hoş Geldiniz';

  @override
  String get onboardingWelcomeSubtitle => 'Akıllı seyahat yoldaşınız';

  @override
  String get onboardingNationality => 'Uyruğunuz nedir?';

  @override
  String get onboardingPassportType => 'Pasaport türü';

  @override
  String get onboardingResidencePermit => 'Oturma izniniz var mı?';

  @override
  String get onboardingTravelMode => 'Genellikle nasıl seyahat edersiniz?';

  @override
  String get onboardingLanguage => 'Dilinizi seçin';

  @override
  String get onboardingPermissions => 'İzinleri ver';

  @override
  String get onboardingPermissionsLocation =>
      'Konum – sınır tespiti için gereklidir';

  @override
  String get onboardingPermissionsNotification =>
      'Bildirimler – kalış süresi uyarıları için';

  @override
  String get onboardingLegal => 'Yasal';

  @override
  String get onboardingLegalAcknowledge =>
      'Kullanım Koşulları ve Gizlilik Politikasını kabul ediyorum';

  @override
  String get buttonNext => 'İleri';

  @override
  String get buttonDone => 'Tamam';

  @override
  String get buttonAllow => 'İzin Ver';

  @override
  String get buttonSkip => 'Geç';

  @override
  String get radarTitle => 'Radar';

  @override
  String get radarCurrentCountry => 'Bulunduğunuz Ülke';

  @override
  String get radarCurrentCity => 'Bulunduğunuz Şehir';

  @override
  String get radarUnknownLocation => 'Konum algılanıyor…';

  @override
  String get radarSchengenCard => 'Schengen Durumu';

  @override
  String radarDaysUsed(int days) {
    return '$days gün kullanıldı';
  }

  @override
  String radarDaysRemaining(int days) {
    return '$days gün kaldı';
  }

  @override
  String get radarSchengenWindowLabel => '90 / 180 günlük pencere';

  @override
  String get radarRiskSafe => 'Güvenli';

  @override
  String get radarRiskWarning => 'Uyarı';

  @override
  String get radarRiskCritical => 'Kritik';

  @override
  String get radarAlertsCard => 'Uyarılar';

  @override
  String get radarNoAlerts => 'Aktif uyarı yok';

  @override
  String get countryInfoTitle => 'Ülke Bilgisi';

  @override
  String get countryInfoWeather => 'Hava Durumu';

  @override
  String get countryInfoFeelsLike => 'Hissedilen';

  @override
  String get countryInfoHumidity => 'Nem';

  @override
  String get countryInfoWind => 'Rüzgar';

  @override
  String get countryInfoVisibility => 'Görüş Mesafesi';

  @override
  String get countryInfoUV => 'UV İndeksi';

  @override
  String get countryInfoAirQuality => 'Hava Kalitesi';

  @override
  String get countryInfoCurrency => 'Para Birimi';

  @override
  String get countryInfoConsulate => 'Konsolosluk';

  @override
  String get countryInfoPolice => 'Polis';

  @override
  String get countryInfoHospital => 'Hastane';

  @override
  String get placeholderComingSoon => 'Yakında';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsProfile => 'Profil';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsNotifications => 'Bildirimler';

  @override
  String get settingsSubscription => 'Abonelik';

  @override
  String get settingsLegal => 'Yasal';

  @override
  String get settingsPrivacyPolicy => 'Gizlilik Politikası';

  @override
  String get settingsTerms => 'Kullanım Koşulları';

  @override
  String get settingsAbout => 'VisaRadar Hakkında';

  @override
  String get subscriptionTitle => 'VisaRadar Premium';

  @override
  String get subscriptionTrialInfo => '7 günlük ücretsiz deneme';

  @override
  String get subscriptionPriceEur => '€4,99 / ay';

  @override
  String get subscriptionPriceTry => '₺200 / ay';

  @override
  String get subscriptionStartTrial => 'Ücretsiz Denemeyi Başlat';

  @override
  String get errorGeneric => 'Bir şeyler ters gitti. Lütfen tekrar deneyin.';

  @override
  String get errorLocationUnavailable => 'Konum kullanılamıyor';

  @override
  String get errorNetworkUnavailable => 'İnternet bağlantısı yok';
}
