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
    required this.visaEn,
    required this.visaTr,
    required this.driveEn,
    required this.driveTr,
    this.vignette = false,
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

  /// Visa guidance for a Turkish passport holder.
  final String visaEn;
  final String visaTr;

  /// Driving / road notes (insurance, vignette, tolls).
  final String driveEn;
  final String driveTr;

  /// Whether a motorway vignette (sticker/e-toll) is required.
  final bool vignette;

  String name(bool tr) => tr ? nameTr : nameEn;
  String visa(bool tr) => tr ? visaTr : visaEn;
  String drive(bool tr) => tr ? driveTr : driveEn;

  String get highwayLabel =>
      speedHighway < 0 ? '∞' : speedHighway.toString();
}
