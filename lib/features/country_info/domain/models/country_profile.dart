/// Represents a country's static profile data for display in the Country tab.
///
/// All list fields default to empty — when empty they trigger the
/// "coming soon" treatment on the matching card.
///
/// Architecture note: swap [findCountryProfile] in country_seed_data.dart to
/// fetch from a remote API; this model stays stable regardless of data source.
class CountryProfile {
  const CountryProfile({
    required this.isoCode,
    required this.name,
    required this.isSchengen,
    required this.currencies,
    this.entryNotes = const [],
    this.transportNotes = const [],
    this.moneyNotes = const [],
    this.connectivityNotes = const [],
    this.safetyNotes = const [],
    this.localTips = const [],
  });

  /// ISO 3166-1 alpha-2 code, e.g. "DE".
  final String isoCode;

  /// English country name.
  final String name;

  /// Whether this country is part of the Schengen Area.
  final bool isSchengen;

  /// One or more currencies, e.g. ["Euro"] or ["Bulgarian lev"].
  final List<String> currencies;

  /// Entry, visa & stay rules — shown in Entry & Stay card.
  final List<String> entryNotes;

  /// Transport & border practical notes.
  final List<String> transportNotes;

  /// Money, payments & tipping notes.
  final List<String> moneyNotes;

  /// Mobile internet, eSIM & roaming notes.
  final List<String> connectivityNotes;

  /// Safety, emergency contacts & general advisories.
  final List<String> safetyNotes;

  /// Concise practical traveler tips.
  final List<String> localTips;

  /// Human-readable currency string, e.g. "Euro" or "Euro, Bulgarian lev".
  String get currencyDisplay => currencies.join(', ');
}
