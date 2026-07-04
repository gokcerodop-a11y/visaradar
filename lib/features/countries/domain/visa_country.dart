/// Static, curated travel-intelligence record for a country.
///
/// MVP uses hand-maintained seed data (no network). All free-text fields are
/// bilingual (English + Turkish). Speed/alcohol/visa data is general guidance —
/// the UI shows a "verify before travel" disclaimer.
class VisaCountry {
  const VisaCountry({
    required this.code,
    required this.nameEn,
    required this.nameTr,
    required this.flag,
    required this.currency,
    required this.currencyCode,
    required this.speedUrban,
    required this.speedRural,
    required this.speedHighway,
    required this.alcoholBac,
    required this.emergencyGeneral,
    this.emergencyPolice,
    this.emergencyAmbulance,
    required this.isSchengen,
    required this.requiresVisaForTurkish,
    required this.visaEn,
    required this.visaTr,
    required this.driveEn,
    required this.driveTr,
    this.vignette = false,
    this.capitalEn,
    this.capitalTr,
    this.culturalEn,
    this.culturalTr,
    this.practicalEn,
    this.practicalTr,
    this.bestTimeEn,
    this.bestTimeTr,
    this.officialLanguage,
  });

  final String code; // ISO alpha-2, upper-case
  final String nameEn;
  final String nameTr;
  final String flag; // emoji
  final String currency; // symbol e.g. "€"
  final String currencyCode; // e.g. "EUR"

  /// Default speed limits in km/h (cars). `speedHighway` may be -1 = "no limit".
  final int speedUrban;
  final int speedRural;
  final int speedHighway;

  /// Maximum legal blood alcohol concentration (g/L) for standard drivers.
  final double alcoholBac;

  final String emergencyGeneral; // usually "112"
  final String? emergencyPolice;
  final String? emergencyAmbulance;

  final bool isSchengen;

  /// Whether Turkish citizens require a visa to enter (including visa on arrival / e-visa).
  final bool requiresVisaForTurkish;

  /// Visa guidance for a Turkish passport holder.
  final String visaEn;
  final String visaTr;

  /// Driving / road notes (insurance, vignette, tolls).
  final String driveEn;
  final String driveTr;

  /// Whether a motorway vignette (sticker/e-toll) is required.
  final bool vignette;

  // ── Rich detail fields (optional, for detailed country pages) ──────────────

  /// Capital city name in English/Turkish.
  final String? capitalEn;
  final String? capitalTr;

  /// Official language(s) of the country.
  final String? officialLanguage;

  /// Cultural highlights — history, arts, cuisine overview.
  final String? culturalEn;
  final String? culturalTr;

  /// Practical travel tips beyond driving rules.
  final String? practicalEn;
  final String? practicalTr;

  /// Best time to visit recommendation.
  final String? bestTimeEn;
  final String? bestTimeTr;

  String name(bool tr) => tr ? nameTr : nameEn;
  String visa(bool tr) => tr ? visaTr : visaEn;
  String drive(bool tr) => tr ? driveTr : driveEn;
  String? cultural(bool tr) => tr ? culturalTr : culturalEn;
  String? practical(bool tr) => tr ? practicalTr : practicalEn;
  String? bestTime(bool tr) => tr ? bestTimeTr : bestTimeEn;

  String get highwayLabel =>
      speedHighway < 0 ? '∞' : speedHighway.toString();
}
