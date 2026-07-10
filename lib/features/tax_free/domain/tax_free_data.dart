/// Static Tax-Free shopping guide data for popular European destinations.
///
/// Pure Dart — no Flutter imports — so it can be unit-tested and reused by
/// the Telegram bot / AI prompt builders if needed.
library;

/// Tax-free (VAT refund) rules and step-by-step guide for one country.
class TaxFreeCountryInfo {
  const TaxFreeCountryInfo({
    required this.countryCode,
    required this.flag,
    required this.nameEn,
    required this.nameTr,
    required this.minimumPurchaseEur,
    required this.minimumLabel,
    required this.refundRangeEn,
    required this.refundRangeTr,
    required this.companies,
    required this.stepsEn,
    required this.stepsTr,
    this.notesEn,
    this.notesTr,
  });

  /// ISO 3166-1 alpha-2 code, uppercase (e.g. 'FR').
  final String countryCode;

  /// Emoji flag.
  final String flag;

  final String nameEn;
  final String nameTr;

  /// Minimum purchase amount expressed in EUR (approximate for non-EUR
  /// countries such as Switzerland).
  final double minimumPurchaseEur;

  /// Human-readable minimum purchase label in the local currency.
  final String minimumLabel;

  /// Typical net refund range, e.g. '~12–17%'.
  final String refundRangeEn;
  final String refundRangeTr;

  /// Pipe-separated refund operator names, e.g. 'Global Blue|Planet'.
  final String companies;

  /// Numbered step-by-step guide, one step per line.
  final String stepsEn;
  final String stepsTr;

  /// Optional country-specific notes.
  final String? notesEn;
  final String? notesTr;

  /// Company names split into a list.
  List<String> get companyList =>
      companies.split('|').map((s) => s.trim()).toList();

  /// Steps split into a list of lines (empty lines removed).
  List<String> stepList(bool isTr) => (isTr ? stepsTr : stepsEn)
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Tax-free guide data for the most-shopped European destinations.
const List<TaxFreeCountryInfo> kTaxFreeCountries = [
  TaxFreeCountryInfo(
    countryCode: 'FR',
    flag: '🇫🇷',
    nameEn: 'France',
    nameTr: 'Fransa',
    minimumPurchaseEur: 100.01,
    minimumLabel: '€100.01',
    refundRangeEn: '~12–17%',
    refundRangeTr: '~%12–17',
    companies: 'Global Blue|Planet',
    stepsEn: '1. Spend at least €100.01 in one shop on the same day.\n'
        '2. Ask the cashier for a tax-free form (bordereau) and show your passport.\n'
        '3. Check that your passport details are filled in correctly on the form.\n'
        '4. At the airport, scan the form at a PABLO kiosk or get a customs stamp BEFORE check-in if goods go in checked luggage.\n'
        '5. Submit the validated form at the Global Blue / Planet refund desk, or mail it in the prepaid envelope.\n'
        '6. Receive your refund in cash on the spot or on your card within a few weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az €100.01 alışveriş yapın.\n'
        '2. Kasadan tax-free formu (bordereau) isteyin ve pasaportunuzu gösterin.\n'
        '3. Formda pasaport bilgilerinizin doğru yazıldığını kontrol edin.\n'
        '4. Havalimanında formu PABLO kioskunda okutun; ürünler bavula girecekse check-in ÖNCESİ gümrük onayı alın.\n'
        '5. Onaylı formu Global Blue / Planet iade gişesine verin veya ön ödemeli zarfla postalayın.\n'
        '6. İadenizi gişede nakit ya da birkaç hafta içinde kartınıza alın.',
    notesEn:
        'France uses the electronic PABLO kiosks at major airports — a green screen means your form is validated, no manual stamp needed.',
    notesTr:
        'Fransa büyük havalimanlarında elektronik PABLO kioskları kullanır — yeşil ekran formunuzun onaylandığı anlamına gelir, ayrıca kaşe gerekmez.',
  ),
  TaxFreeCountryInfo(
    countryCode: 'DE',
    flag: '🇩🇪',
    nameEn: 'Germany',
    nameTr: 'Almanya',
    minimumPurchaseEur: 50.01,
    minimumLabel: '€50.01',
    refundRangeEn: '~14%',
    refundRangeTr: '~%14',
    companies: 'Global Blue|Planet',
    stepsEn: '1. Spend at least €50.01 in one shop on the same day.\n'
        '2. Ask the shop for a tax-free form and show your passport.\n'
        '3. Fill in the form with your passport and home address details.\n'
        '4. Get a customs stamp at the airport BEFORE check-in — customs may ask to see the unused goods.\n'
        '5. Hand the stamped form to the Global Blue / Planet desk, or post it in the prepaid envelope.\n'
        '6. The refund is paid in cash or credited to your card within a few weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az €50.01 alışveriş yapın.\n'
        '2. Mağazadan tax-free formu isteyin ve pasaportunuzu gösterin.\n'
        '3. Formu pasaport ve ev adresi bilgilerinizle doldurun.\n'
        '4. Havalimanında check-in ÖNCESİ gümrük kaşesi alın — gümrük, kullanılmamış ürünleri görmek isteyebilir.\n'
        '5. Kaşeli formu Global Blue / Planet gişesine verin veya ön ödemeli zarfla postalayın.\n'
        '6. İade nakit ödenir ya da birkaç hafta içinde kartınıza geçer.',
    notesEn:
        'Germany has one of the lowest minimum purchase thresholds in the EU, making it great for smaller purchases.',
    notesTr:
        'Almanya, AB içindeki en düşük minimum alışveriş limitlerinden birine sahiptir — küçük alışverişler için idealdir.',
  ),
  TaxFreeCountryInfo(
    countryCode: 'IT',
    flag: '🇮🇹',
    nameEn: 'Italy',
    nameTr: 'İtalya',
    minimumPurchaseEur: 154.95,
    minimumLabel: '€154.95',
    refundRangeEn: '~15%',
    refundRangeTr: '~%15',
    companies: 'Global Blue|Planet',
    stepsEn: '1. Spend at least €154.95 in one shop on the same day.\n'
        '2. Request a tax-free form at the till and show your passport.\n'
        '3. Verify your passport number and address are correct on the form.\n'
        '4. At the airport, validate the form at an OTELLO kiosk or customs desk BEFORE check-in.\n'
        '5. Take the validated form to the refund desk, or drop it in the mailbox with the prepaid envelope.\n'
        '6. Get your refund in cash immediately or on your card within a few weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az €154.95 alışveriş yapın.\n'
        '2. Kasadan tax-free formu isteyin ve pasaportunuzu gösterin.\n'
        '3. Formdaki pasaport numarası ve adres bilgilerinizi kontrol edin.\n'
        '4. Havalimanında check-in ÖNCESİ formu OTELLO kioskunda veya gümrük gişesinde onaylatın.\n'
        '5. Onaylı formu iade gişesine götürün ya da ön ödemeli zarfla posta kutusuna atın.\n'
        '6. İadenizi hemen nakit veya birkaç hafta içinde kartınıza alın.',
    notesEn:
        'Italy uses the digital OTELLO system at major airports. Luxury purchases in Milan and Rome often qualify for higher effective refunds.',
    notesTr:
        'İtalya büyük havalimanlarında dijital OTELLO sistemini kullanır. Milano ve Roma\'daki lüks alışverişlerde efektif iade oranı genelde daha yüksektir.',
  ),
  TaxFreeCountryInfo(
    countryCode: 'ES',
    flag: '🇪🇸',
    nameEn: 'Spain',
    nameTr: 'İspanya',
    minimumPurchaseEur: 90.16,
    minimumLabel: '€90.16',
    refundRangeEn: '~15%',
    refundRangeTr: '~%15',
    companies: 'Global Blue|Planet',
    stepsEn: '1. Spend at least €90.16 in one shop on the same day.\n'
        '2. Ask for a tax-free form (DER) at the till and show your passport.\n'
        '3. Make sure your passport details are entered correctly on the form.\n'
        '4. At the airport, scan the form at a DIVA kiosk BEFORE check-in — most forms are validated electronically.\n'
        '5. Present the validated form at the Global Blue / Planet desk, or mail it in the prepaid envelope.\n'
        '6. Receive the refund in cash or on your card within a few weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az €90.16 alışveriş yapın.\n'
        '2. Kasadan tax-free formu (DER) isteyin ve pasaportunuzu gösterin.\n'
        '3. Formda pasaport bilgilerinizin doğru girildiğinden emin olun.\n'
        '4. Havalimanında check-in ÖNCESİ formu DIVA kioskunda okutun — çoğu form elektronik onaylanır.\n'
        '5. Onaylı formu Global Blue / Planet gişesine sunun veya ön ödemeli zarfla postalayın.\n'
        '6. İadeyi nakit ya da birkaç hafta içinde kartınıza alın.',
    notesEn:
        'Spain validates tax-free forms electronically via the DIVA system — scan the barcode at the kiosk; a green light means no customs stamp is needed.',
    notesTr:
        'İspanya tax-free formlarını DIVA sistemiyle elektronik onaylar — kioskta barkodu okutun; yeşil ışık gümrük kaşesine gerek olmadığını gösterir.',
  ),
  TaxFreeCountryInfo(
    countryCode: 'AT',
    flag: '🇦🇹',
    nameEn: 'Austria',
    nameTr: 'Avusturya',
    minimumPurchaseEur: 75.01,
    minimumLabel: '€75.01',
    refundRangeEn: '~14–17%',
    refundRangeTr: '~%14–17',
    companies: 'Global Blue|Planet',
    stepsEn: '1. Spend at least €75.01 in one shop on the same day.\n'
        '2. Ask the shop for a tax-free form and show your passport.\n'
        '3. Complete the form with your passport and address details.\n'
        '4. Get the form stamped by customs at the airport BEFORE check-in.\n'
        '5. Submit the stamped form at the refund desk, or send it in the prepaid envelope.\n'
        '6. The refund arrives in cash or on your card within a few weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az €75.01 alışveriş yapın.\n'
        '2. Mağazadan tax-free formu isteyin ve pasaportunuzu gösterin.\n'
        '3. Formu pasaport ve adres bilgilerinizle doldurun.\n'
        '4. Havalimanında check-in ÖNCESİ forma gümrük kaşesi vurdurun.\n'
        '5. Kaşeli formu iade gişesine verin veya ön ödemeli zarfla gönderin.\n'
        '6. İade nakit ya da birkaç hafta içinde kartınıza geçer.',
    notesEn:
        'Vienna airport has refund desks in both terminals; allow extra time during peak season.',
    notesTr:
        'Viyana havalimanında her iki terminalde de iade gişesi vardır; yoğun sezonda ek süre ayırın.',
  ),
  TaxFreeCountryInfo(
    countryCode: 'NL',
    flag: '🇳🇱',
    nameEn: 'Netherlands',
    nameTr: 'Hollanda',
    minimumPurchaseEur: 50.01,
    minimumLabel: '€50.01',
    refundRangeEn: '~14%',
    refundRangeTr: '~%14',
    companies: 'Global Blue|Planet',
    stepsEn: '1. Spend at least €50.01 in one shop on the same day.\n'
        '2. Ask for a tax-free form at the till and show your passport.\n'
        '3. Check your passport details on the form before leaving the shop.\n'
        '4. At Schiphol, get a customs stamp or digital validation BEFORE check-in.\n'
        '5. Bring the validated form to the refund desk, or use the prepaid mail envelope.\n'
        '6. Refund is paid in cash at the desk or credited to your card within weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az €50.01 alışveriş yapın.\n'
        '2. Kasadan tax-free formu isteyin ve pasaportunuzu gösterin.\n'
        '3. Mağazadan ayrılmadan formdaki pasaport bilgilerinizi kontrol edin.\n'
        '4. Schiphol\'de check-in ÖNCESİ gümrük kaşesi veya dijital onay alın.\n'
        '5. Onaylı formu iade gişesine götürün ya da ön ödemeli zarfla postalayın.\n'
        '6. İade gişede nakit ödenir veya birkaç hafta içinde kartınıza geçer.',
    notesEn:
        'At Schiphol the customs desk is in Departure Hall 3 — go there before dropping off your luggage.',
    notesTr:
        'Schiphol\'de gümrük gişesi Kalkış Salonu 3\'tedir — bavulunuzu teslim etmeden önce oraya gidin.',
  ),
  TaxFreeCountryInfo(
    countryCode: 'BE',
    flag: '🇧🇪',
    nameEn: 'Belgium',
    nameTr: 'Belçika',
    minimumPurchaseEur: 125.01,
    minimumLabel: '€125.01',
    refundRangeEn: '~15%',
    refundRangeTr: '~%15',
    companies: 'Global Blue|Planet',
    stepsEn: '1. Spend at least €125.01 in one shop on the same day.\n'
        '2. Request a tax-free form at the cashier and show your passport.\n'
        '3. Fill in the form with your passport number and home address.\n'
        '4. Get a customs stamp at Brussels airport BEFORE check-in.\n'
        '5. Present the stamped form at the refund desk, or mail it in the prepaid envelope.\n'
        '6. Receive your refund in cash or on your card within a few weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az €125.01 alışveriş yapın.\n'
        '2. Kasadan tax-free formu isteyin ve pasaportunuzu gösterin.\n'
        '3. Formu pasaport numaranız ve ev adresinizle doldurun.\n'
        '4. Brüksel havalimanında check-in ÖNCESİ gümrük kaşesi alın.\n'
        '5. Kaşeli formu iade gişesine sunun veya ön ödemeli zarfla postalayın.\n'
        '6. İadenizi nakit ya da birkaç hafta içinde kartınıza alın.',
    notesEn:
        'Chocolates and other consumables usually do not qualify — the refund applies to goods exported unused.',
    notesTr:
        'Çikolata gibi tüketim ürünleri genelde kapsam dışıdır — iade, kullanılmadan yurt dışına çıkarılan ürünler için geçerlidir.',
  ),
  TaxFreeCountryInfo(
    countryCode: 'CH',
    flag: '🇨🇭',
    nameEn: 'Switzerland',
    nameTr: 'İsviçre',
    minimumPurchaseEur: 310,
    minimumLabel: 'CHF 300',
    refundRangeEn: '~7–7.7%',
    refundRangeTr: '~%7–7,7',
    companies: 'Global Blue',
    stepsEn: '1. Spend at least CHF 300 in one shop on the same day.\n'
        '2. Ask the shop for a Global Blue tax-free form and show your passport.\n'
        '3. Complete the form with your passport details.\n'
        '4. Get a Swiss customs stamp when leaving the country BEFORE check-in (Switzerland is NOT in the EU).\n'
        '5. Submit the stamped form at a Global Blue desk, or post it in the prepaid envelope.\n'
        '6. The refund is paid in cash or credited to your card within a few weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az 300 CHF alışveriş yapın.\n'
        '2. Mağazadan Global Blue tax-free formu isteyin ve pasaportunuzu gösterin.\n'
        '3. Formu pasaport bilgilerinizle doldurun.\n'
        '4. Ülkeden çıkarken check-in ÖNCESİ İsviçre gümrük kaşesi alın (İsviçre AB üyesi DEĞİLDİR).\n'
        '5. Kaşeli formu Global Blue gişesine verin veya ön ödemeli zarfla postalayın.\n'
        '6. İade nakit ödenir ya da birkaç hafta içinde kartınıza geçer.',
    notesEn:
        'Swiss VAT is only 8.1%, so refunds are smaller than in EU countries. EU tax-free forms cannot be stamped in Switzerland and vice versa.',
    notesTr:
        'İsviçre KDV\'si yalnızca %8,1 olduğundan iadeler AB ülkelerine göre daha düşüktür. AB tax-free formları İsviçre\'de kaşelenemez (tersi de geçerli).',
  ),
  TaxFreeCountryInfo(
    countryCode: 'GR',
    flag: '🇬🇷',
    nameEn: 'Greece',
    nameTr: 'Yunanistan',
    minimumPurchaseEur: 50,
    minimumLabel: '€50',
    refundRangeEn: '~15%',
    refundRangeTr: '~%15',
    companies: 'Global Blue|Planet',
    stepsEn: '1. Spend at least €50 in one shop on the same day.\n'
        '2. Ask for a tax-free form at the till and show your passport.\n'
        '3. Verify your passport details on the form before leaving.\n'
        '4. Get a customs stamp at the airport BEFORE check-in; keep goods accessible for inspection.\n'
        '5. Hand the stamped form to the refund desk, or mail it in the prepaid envelope.\n'
        '6. Receive the refund in cash or on your card within a few weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az €50 alışveriş yapın.\n'
        '2. Kasadan tax-free formu isteyin ve pasaportunuzu gösterin.\n'
        '3. Ayrılmadan önce formdaki pasaport bilgilerinizi kontrol edin.\n'
        '4. Havalimanında check-in ÖNCESİ gümrük kaşesi alın; ürünleri kontrol için el altında tutun.\n'
        '5. Kaşeli formu iade gişesine verin veya ön ödemeli zarfla postalayın.\n'
        '6. İadeyi nakit ya da birkaç hafta içinde kartınıza alın.',
    notesEn:
        'On the islands, refund desks may be seasonal — validating the form at customs is the critical step; you can always mail the envelope.',
    notesTr:
        'Adalarda iade gişeleri sezonluk olabilir — kritik adım formun gümrükte onaylanmasıdır; zarfı her zaman postalayabilirsiniz.',
  ),
  TaxFreeCountryInfo(
    countryCode: 'PT',
    flag: '🇵🇹',
    nameEn: 'Portugal',
    nameTr: 'Portekiz',
    minimumPurchaseEur: 61.35,
    minimumLabel: '€61.35',
    refundRangeEn: '~13%',
    refundRangeTr: '~%13',
    companies: 'Global Blue|Planet',
    stepsEn: '1. Spend at least €61.35 in one shop on the same day.\n'
        '2. Ask the cashier for a tax-free form and show your passport.\n'
        '3. Fill in the form with your passport and address details.\n'
        '4. At the airport, validate the form at an e-Taxfree Portugal kiosk or customs desk BEFORE check-in.\n'
        '5. Take the validated form to the refund desk, or send it in the prepaid envelope.\n'
        '6. Refund is paid in cash or credited to your card within a few weeks.',
    stepsTr: '1. Aynı gün, aynı mağazadan en az €61.35 alışveriş yapın.\n'
        '2. Kasadan tax-free formu isteyin ve pasaportunuzu gösterin.\n'
        '3. Formu pasaport ve adres bilgilerinizle doldurun.\n'
        '4. Havalimanında check-in ÖNCESİ formu e-Taxfree Portugal kioskunda veya gümrük gişesinde onaylatın.\n'
        '5. Onaylı formu iade gişesine götürün ya da ön ödemeli zarfla gönderin.\n'
        '6. İade nakit ödenir veya birkaç hafta içinde kartınıza geçer.',
    notesEn:
        'Portugal uses the electronic e-Taxfree system at Lisbon and Porto airports — a green screen means your form is validated.',
    notesTr:
        'Portekiz, Lizbon ve Porto havalimanlarında elektronik e-Taxfree sistemini kullanır — yeşil ekran formunuzun onaylandığını gösterir.',
  ),
];

/// Returns the tax-free info for [countryCode] (case-insensitive),
/// or null if the country is not covered.
TaxFreeCountryInfo? taxFreeInfoFor(String countryCode) {
  final code = countryCode.toUpperCase();
  for (final info in kTaxFreeCountries) {
    if (info.countryCode == code) return info;
  }
  return null;
}
