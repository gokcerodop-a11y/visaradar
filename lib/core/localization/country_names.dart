import 'locale.dart';

/// Turkish display names by ISO 3166-1 alpha-2 code. Covers all of Europe plus
/// common world destinations; anything missing falls back to the English name.
const Map<String, String> _trCountryNames = {
  'TR': 'Türkiye', 'GR': 'Yunanistan', 'BG': 'Bulgaristan', 'IT': 'İtalya',
  'FR': 'Fransa', 'DE': 'Almanya', 'ES': 'İspanya', 'HR': 'Hırvatistan',
  'ME': 'Karadağ', 'AL': 'Arnavutluk', 'AT': 'Avusturya', 'BE': 'Belçika',
  'NL': 'Hollanda', 'LU': 'Lüksemburg', 'PT': 'Portekiz', 'IE': 'İrlanda',
  'DK': 'Danimarka', 'SE': 'İsveç', 'FI': 'Finlandiya', 'NO': 'Norveç',
  'IS': 'İzlanda', 'CH': 'İsviçre', 'LI': 'Lihtenştayn', 'PL': 'Polonya',
  'CZ': 'Çekya', 'SK': 'Slovakya', 'HU': 'Macaristan', 'SI': 'Slovenya',
  'RO': 'Romanya', 'EE': 'Estonya', 'LV': 'Letonya', 'LT': 'Litvanya',
  'MT': 'Malta', 'CY': 'Kıbrıs', 'RS': 'Sırbistan', 'BA': 'Bosna-Hersek',
  'MK': 'Kuzey Makedonya', 'XK': 'Kosova', 'MD': 'Moldova', 'UA': 'Ukrayna',
  'BY': 'Belarus', 'RU': 'Rusya', 'GB': 'Birleşik Krallık', 'MC': 'Monako',
  'SM': 'San Marino', 'VA': 'Vatikan', 'AD': 'Andorra', 'GE': 'Gürcistan',
  'AM': 'Ermenistan', 'AZ': 'Azerbaycan',
  // Common non-European destinations
  'US': 'ABD', 'CA': 'Kanada', 'MX': 'Meksika', 'BR': 'Brezilya',
  'AR': 'Arjantin', 'GB_UK': 'Birleşik Krallık', 'AE': 'Birleşik Arap Emirlikleri',
  'SA': 'Suudi Arabistan', 'QA': 'Katar', 'EG': 'Mısır', 'MA': 'Fas',
  'TN': 'Tunus', 'DZ': 'Cezayir', 'IL': 'İsrail', 'JO': 'Ürdün',
  'LB': 'Lübnan', 'IR': 'İran', 'IQ': 'Irak', 'IN': 'Hindistan',
  'PK': 'Pakistan', 'CN': 'Çin', 'JP': 'Japonya', 'KR': 'Güney Kore',
  'TH': 'Tayland', 'VN': 'Vietnam', 'ID': 'Endonezya', 'MY': 'Malezya',
  'SG': 'Singapur', 'PH': 'Filipinler', 'AU': 'Avustralya', 'NZ': 'Yeni Zelanda',
  'ZA': 'Güney Afrika', 'KE': 'Kenya', 'NG': 'Nijerya',
};

/// Returns the country name in the active UI language. When Turkish is active
/// and a translation exists, returns it; otherwise returns [englishName].
String countryNameLocalized(String? code, String englishName) {
  if (L.isTr && code != null) {
    final tr = _trCountryNames[code.toUpperCase()];
    if (tr != null) return tr;
  }
  return englishName;
}
