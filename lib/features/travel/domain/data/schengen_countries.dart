/// ISO 3166-1 alpha-2 codes of all Schengen Area member and associated states.
/// Includes Bulgaria, Romania, and Croatia which joined in 2024.
const Set<String> kSchengenCountryCodes = {
  'AT', // Austria
  'BE', // Belgium
  'BG', // Bulgaria
  'HR', // Croatia
  'CZ', // Czech Republic
  'DK', // Denmark
  'EE', // Estonia
  'FI', // Finland
  'FR', // France
  'DE', // Germany
  'GR', // Greece
  'HU', // Hungary
  'IS', // Iceland
  'IT', // Italy
  'LV', // Latvia
  'LI', // Liechtenstein
  'LT', // Lithuania
  'LU', // Luxembourg
  'MT', // Malta
  'NL', // Netherlands
  'NO', // Norway
  'PL', // Poland
  'PT', // Portugal
  'RO', // Romania
  'SK', // Slovakia
  'SI', // Slovenia
  'ES', // Spain
  'SE', // Sweden
  'CH', // Switzerland
};

/// Returns true if [countryCode] is a Schengen Area member or associated state.
bool isSchengenCountry(String countryCode) =>
    kSchengenCountryCodes.contains(countryCode.toUpperCase());
