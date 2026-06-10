import 'visa_country.dart';

/// The ten launch countries, focused on Turkey ↔ Greece / Bulgaria overland
/// travel and the surrounding Schengen + Balkan region.
final List<VisaCountry> kVisaCountries = [
  VisaCountry(
    code: 'TR',
    nameEn: 'Turkey',
    nameTr: 'Türkiye',
    flag: '🇹🇷',
    currency: '₺',
    currencyCode: 'TRY',
    speedUrban: 50,
    speedRural: 90,
    speedHighway: 120,
    alcoholBac: 0.05,
    emergencyGeneral: '112',
    isSchengen: false,
    visaEn:
        'Home country for Turkish citizens — no visa needed. Foreign visitors '
        'should check the e-Visa portal (evisa.gov.tr).',
    visaTr:
        'Türk vatandaşları için anavatan — vize gerekmez. Yabancı ziyaretçiler '
        'e-Vize portalını (evisa.gov.tr) kontrol etmeli.',
    driveEn:
        'Drive on the right. Headlights and seatbelts mandatory. HGS/OGS '
        'electronic tag required for motorways and bridges.',
    driveTr:
        'Sağdan trafik. Far ve emniyet kemeri zorunlu. Otoyol ve köprüler için '
        'HGS/OGS elektronik geçiş etiketi gerekir.',
  ),
  VisaCountry(
    code: 'GR',
    nameEn: 'Greece',
    nameTr: 'Yunanistan',
    flag: '🇬🇷',
    currency: '€',
    currencyCode: 'EUR',
    speedUrban: 50,
    speedRural: 90,
    speedHighway: 130,
    alcoholBac: 0.05,
    emergencyGeneral: '112',
    isSchengen: true,
    visaEn:
        'Schengen visa required for Turkish citizens. A simplified "express" '
        'door visa is available on arrival for 10 designated Aegean islands '
        '(e.g. Lesbos, Chios, Kos, Rhodes) for stays up to 7 days.',
    visaTr:
        'Türk vatandaşları için Schengen vizesi gerekir. 10 Ege adası için '
        '(Midilli, Sakız, İstanköy, Rodos vb.) kapıda alınabilen 7 güne kadar '
        'basitleştirilmiş "ekspres" ada vizesi mevcuttur.',
    driveEn:
        'Drive on the right. Green Card insurance strongly recommended. Tolls '
        'on major motorways, paid at booths.',
    driveTr:
        'Sağdan trafik. Yeşil Kart sigortası şiddetle önerilir. Ana otoyollarda '
        'gişe ile ödenen ücretler vardır.',
  ),
  VisaCountry(
    code: 'BG',
    nameEn: 'Bulgaria',
    nameTr: 'Bulgaristan',
    flag: '🇧🇬',
    currency: 'лв',
    currencyCode: 'BGN',
    speedUrban: 50,
    speedRural: 90,
    speedHighway: 140,
    alcoholBac: 0.05,
    emergencyGeneral: '112',
    isSchengen: true,
    visaEn:
        'Full Schengen member since 2025 — a Schengen visa is required for '
        'Turkish citizens. Days here count toward your 90/180 Schengen total.',
    visaTr:
        '2025\'ten beri tam Schengen üyesi — Türk vatandaşları için Schengen '
        'vizesi gerekir. Buradaki günler 90/180 Schengen toplamınıza sayılır.',
    driveEn:
        'Motorways require an electronic vignette (toll sticker), purchasable '
        'online or at borders. Drive on the right.',
    driveTr:
        'Otoyollar için elektronik vinyet (geçiş etiketi) gerekir; online veya '
        'sınırda alınabilir. Sağdan trafik.',
    vignette: true,
  ),
  VisaCountry(
    code: 'IT',
    nameEn: 'Italy',
    nameTr: 'İtalya',
    flag: '🇮🇹',
    currency: '€',
    currencyCode: 'EUR',
    speedUrban: 50,
    speedRural: 90,
    speedHighway: 130,
    alcoholBac: 0.05,
    emergencyGeneral: '112',
    isSchengen: true,
    visaEn:
        'Schengen visa required for Turkish citizens. Counts toward 90/180.',
    visaTr:
        'Türk vatandaşları için Schengen vizesi gerekir. 90/180 hesabına sayılır.',
    driveEn:
        'Drive on the right. Many city centres are restricted ZTL zones — '
        'entering without a permit triggers automatic fines. Tolls on autostrade.',
    driveTr:
        'Sağdan trafik. Birçok şehir merkezi ZTL kısıtlı bölgedir — izinsiz '
        'girişte otomatik ceza kesilir. Otoyollarda (autostrade) ücret vardır.',
  ),
  VisaCountry(
    code: 'FR',
    nameEn: 'France',
    nameTr: 'Fransa',
    flag: '🇫🇷',
    currency: '€',
    currencyCode: 'EUR',
    speedUrban: 50,
    speedRural: 80,
    speedHighway: 130,
    alcoholBac: 0.05,
    emergencyGeneral: '112',
    isSchengen: true,
    visaEn:
        'Schengen visa required for Turkish citizens. Counts toward 90/180.',
    visaTr:
        'Türk vatandaşları için Schengen vizesi gerekir. 90/180 hesabına sayılır.',
    driveEn:
        'Drive on the right. Carrying a hi-vis vest and warning triangle is '
        'mandatory. Tolls (péage) on most motorways.',
    driveTr:
        'Sağdan trafik. Reflektörlü yelek ve uyarı üçgeni bulundurmak zorunlu. '
        'Çoğu otoyolda ücret (péage) vardır.',
  ),
  VisaCountry(
    code: 'DE',
    nameEn: 'Germany',
    nameTr: 'Almanya',
    flag: '🇩🇪',
    currency: '€',
    currencyCode: 'EUR',
    speedUrban: 50,
    speedRural: 100,
    speedHighway: -1, // Autobahn — no general limit (130 recommended)
    alcoholBac: 0.05,
    emergencyGeneral: '112',
    emergencyPolice: '110',
    isSchengen: true,
    visaEn:
        'Schengen visa required for Turkish citizens. Counts toward 90/180.',
    visaTr:
        'Türk vatandaşları için Schengen vizesi gerekir. 90/180 hesabına sayılır.',
    driveEn:
        'Drive on the right. Many Autobahn sections have no speed limit '
        '(130 km/h advisory). Low-emission "Umweltzone" stickers required in cities.',
    driveTr:
        'Sağdan trafik. Birçok Otoban kesiminde hız sınırı yoktur (tavsiye 130 '
        'km/s). Şehirlerde düşük emisyon "Umweltzone" etiketi gerekir.',
  ),
  VisaCountry(
    code: 'ES',
    nameEn: 'Spain',
    nameTr: 'İspanya',
    flag: '🇪🇸',
    currency: '€',
    currencyCode: 'EUR',
    speedUrban: 50,
    speedRural: 90,
    speedHighway: 120,
    alcoholBac: 0.05,
    emergencyGeneral: '112',
    isSchengen: true,
    visaEn:
        'Schengen visa required for Turkish citizens. Counts toward 90/180.',
    visaTr:
        'Türk vatandaşları için Schengen vizesi gerekir. 90/180 hesabına sayılır.',
    driveEn:
        'Drive on the right. A reflective vest and two warning triangles are '
        'required. Some motorways (AP) are tolled.',
    driveTr:
        'Sağdan trafik. Reflektörlü yelek ve iki uyarı üçgeni zorunludur. Bazı '
        'otoyollar (AP) ücretlidir.',
  ),
  VisaCountry(
    code: 'HR',
    nameEn: 'Croatia',
    nameTr: 'Hırvatistan',
    flag: '🇭🇷',
    currency: '€',
    currencyCode: 'EUR',
    speedUrban: 50,
    speedRural: 90,
    speedHighway: 130,
    alcoholBac: 0.05,
    emergencyGeneral: '112',
    isSchengen: true,
    visaEn:
        'Schengen member since 2023 and uses the euro. Schengen visa required '
        'for Turkish citizens. Counts toward 90/180.',
    visaTr:
        '2023\'ten beri Schengen üyesi ve euro kullanıyor. Türk vatandaşları '
        'için Schengen vizesi gerekir. 90/180 hesabına sayılır.',
    driveEn:
        'Drive on the right. Motorway tolls paid at booths (no vignette). '
        'Daytime headlights required in winter.',
    driveTr:
        'Sağdan trafik. Otoyol ücretleri gişede ödenir (vinyet yok). Kışın '
        'gündüz farları açık olmalı.',
  ),
  VisaCountry(
    code: 'ME',
    nameEn: 'Montenegro',
    nameTr: 'Karadağ',
    flag: '🇲🇪',
    currency: '€',
    currencyCode: 'EUR',
    speedUrban: 50,
    speedRural: 80,
    speedHighway: 100,
    alcoholBac: 0.03,
    emergencyGeneral: '112',
    isSchengen: false,
    visaEn:
        'Visa-free for Turkish citizens for up to 90 days. NOT in Schengen — '
        'time here does not count toward your Schengen 90/180.',
    visaTr:
        'Türk vatandaşları için 90 güne kadar vizesiz. Schengen DEĞİL — buradaki '
        'süre Schengen 90/180 hesabınıza sayılmaz.',
    driveEn:
        'Drive on the right. Green Card insurance recommended. Single long '
        'tunnel toll (Sozina). Mountain roads are narrow — drive cautiously.',
    driveTr:
        'Sağdan trafik. Yeşil Kart sigortası önerilir. Tek uzun tünel ücreti '
        '(Sozina) vardır. Dağ yolları dardır — dikkatli sürün.',
  ),
  VisaCountry(
    code: 'AL',
    nameEn: 'Albania',
    nameTr: 'Arnavutluk',
    flag: '🇦🇱',
    currency: 'L',
    currencyCode: 'ALL',
    speedUrban: 40,
    speedRural: 80,
    speedHighway: 110,
    alcoholBac: 0.01,
    emergencyGeneral: '112',
    isSchengen: false,
    visaEn:
        'Visa-free for Turkish citizens for up to 90 days. NOT in Schengen — '
        'time here does not count toward your Schengen 90/180.',
    visaTr:
        'Türk vatandaşları için 90 güne kadar vizesiz. Schengen DEĞİL — buradaki '
        'süre Schengen 90/180 hesabınıza sayılmaz.',
    driveEn:
        'Drive on the right. Very strict 0.01 alcohol limit — effectively zero. '
        'Carry Green Card insurance; some require a local border policy.',
    driveTr:
        'Sağdan trafik. Çok katı 0.01 alkol sınırı — pratikte sıfır. Yeşil Kart '
        'bulundurun; bazıları sınırda yerel poliçe ister.',
  ),

  // ── Rest of the Schengen Area (EU) ──────────────────────────────────
  _schengen('AT', 'Austria', 'Avusturya', '🇦🇹', '€', 'EUR', 50, 100, 130, 0.05,
      vignette: true),
  _schengen('BE', 'Belgium', 'Belçika', '🇧🇪', '€', 'EUR', 50, 90, 120, 0.05),
  _schengen('NL', 'Netherlands', 'Hollanda', '🇳🇱', '€', 'EUR', 50, 80, 100, 0.05),
  _schengen('LU', 'Luxembourg', 'Lüksemburg', '🇱🇺', '€', 'EUR', 50, 90, 130, 0.05),
  _schengen('PT', 'Portugal', 'Portekiz', '🇵🇹', '€', 'EUR', 50, 90, 120, 0.05),
  _schengen('DK', 'Denmark', 'Danimarka', '🇩🇰', 'kr', 'DKK', 50, 80, 130, 0.05),
  _schengen('SE', 'Sweden', 'İsveç', '🇸🇪', 'kr', 'SEK', 50, 70, 110, 0.02),
  _schengen('FI', 'Finland', 'Finlandiya', '🇫🇮', '€', 'EUR', 50, 80, 120, 0.05),
  _schengen('PL', 'Poland', 'Polonya', '🇵🇱', 'zł', 'PLN', 50, 90, 140, 0.02),
  _schengen('CZ', 'Czechia', 'Çekya', '🇨🇿', 'Kč', 'CZK', 50, 90, 130, 0.00,
      vignette: true),
  _schengen('SK', 'Slovakia', 'Slovakya', '🇸🇰', '€', 'EUR', 50, 90, 130, 0.00,
      vignette: true),
  _schengen('HU', 'Hungary', 'Macaristan', '🇭🇺', 'Ft', 'HUF', 50, 90, 130, 0.00,
      vignette: true),
  _schengen('SI', 'Slovenia', 'Slovenya', '🇸🇮', '€', 'EUR', 50, 90, 130, 0.05,
      vignette: true),
  _schengen('RO', 'Romania', 'Romanya', '🇷🇴', 'lei', 'RON', 50, 90, 130, 0.00,
      vignette: true, note2025: true),
  _schengen('EE', 'Estonia', 'Estonya', '🇪🇪', '€', 'EUR', 50, 90, 110, 0.02),
  _schengen('LV', 'Latvia', 'Letonya', '🇱🇻', '€', 'EUR', 50, 90, 110, 0.05),
  _schengen('LT', 'Lithuania', 'Litvanya', '🇱🇹', '€', 'EUR', 50, 90, 130, 0.04),
  _schengen('MT', 'Malta', 'Malta', '🇲🇹', '€', 'EUR', 50, 80, 80, 0.05,
      left: true),
  // ── Schengen but non-EU ─────────────────────────────────────────────
  _schengen('CH', 'Switzerland', 'İsviçre', '🇨🇭', 'CHF', 'CHF', 50, 80, 120, 0.05,
      vignette: true),
  _schengen('NO', 'Norway', 'Norveç', '🇳🇴', 'kr', 'NOK', 50, 80, 100, 0.02),
  _schengen('IS', 'Iceland', 'İzlanda', '🇮🇸', 'kr', 'ISK', 50, 80, 90, 0.05),
  _schengen('LI', 'Liechtenstein', 'Lihtenştayn', '🇱🇮', 'CHF', 'CHF', 50, 80, 100, 0.08),

  // ── EU but NOT Schengen ─────────────────────────────────────────────
  _euNonSchengen('IE', 'Ireland', 'İrlanda', '🇮🇪', '€', 'EUR', 50, 100, 120, 0.05,
      left: true),
  _euNonSchengen('CY', 'Cyprus', 'Kıbrıs (GKRY)', '🇨🇾', '€', 'EUR', 50, 80, 100, 0.05,
      left: true),

  // ── Non-Schengen Europe — visa-free for Turkish citizens (90 days) ──
  _visaFree('RS', 'Serbia', 'Sırbistan', '🇷🇸', 'дин', 'RSD', 50, 80, 130, 0.03),
  _visaFree('BA', 'Bosnia & Herzegovina', 'Bosna-Hersek', '🇧🇦', 'KM', 'BAM', 50, 80, 130, 0.03),
  _visaFree('MK', 'North Macedonia', 'Kuzey Makedonya', '🇲🇰', 'ден', 'MKD', 50, 80, 130, 0.05),
  _visaFree('XK', 'Kosovo', 'Kosova', '🇽🇰', '€', 'EUR', 50, 80, 130, 0.05),
  _visaFree('MD', 'Moldova', 'Moldova', '🇲🇩', 'L', 'MDL', 50, 90, 110, 0.03),
  _visaFree('UA', 'Ukraine', 'Ukrayna', '🇺🇦', '₴', 'UAH', 50, 90, 130, 0.00),
  _visaFree('GE', 'Georgia', 'Gürcistan', '🇬🇪', '₾', 'GEL', 50, 90, 110, 0.03),

  // ── UK + European microstates ───────────────────────────────────────
  VisaCountry(
    code: 'GB',
    nameEn: 'United Kingdom',
    nameTr: 'Birleşik Krallık',
    flag: '🇬🇧',
    currency: '£',
    currencyCode: 'GBP',
    speedUrban: 48,
    speedRural: 96,
    speedHighway: 112,
    alcoholBac: 0.08,
    emergencyGeneral: '999',
    emergencyPolice: '112',
    isSchengen: false,
    visaEn:
        'Not in the EU or Schengen. A UK visa is required for Turkish citizens. '
        'Time here does not count toward the Schengen 90/180.',
    visaTr:
        'AB veya Schengen değil. Türk vatandaşları için Birleşik Krallık vizesi '
        'gerekir. Buradaki süre Schengen 90/180\'e sayılmaz.',
    driveEn:
        'Drive on the LEFT. Speed limits are in mph. Congestion/ULEZ charges '
        'apply in central London.',
    driveTr:
        'SOLDAN trafik. Hız limitleri mil/saat (mph). Merkez Londra\'da '
        'tıkanıklık/ULEZ ücreti uygulanır.',
  ),
  _visaFree('AD', 'Andorra', 'Andorra', '🇦🇩', '€', 'EUR', 50, 90, 90, 0.05),
  _schengen('MC', 'Monaco', 'Monako', '🇲🇨', '€', 'EUR', 50, 90, 130, 0.05),
  _schengen('SM', 'San Marino', 'San Marino', '🇸🇲', '€', 'EUR', 50, 90, 130, 0.05),
];

// ── Builders to keep the large European list concise + consistent ──────

VisaCountry _schengen(String code, String en, String tr, String flag,
    String cur, String curCode, int u, int r, int h, double bac,
    {bool vignette = false, bool left = false, bool note2025 = false}) {
  return VisaCountry(
    code: code,
    nameEn: en,
    nameTr: tr,
    flag: flag,
    currency: cur,
    currencyCode: curCode,
    speedUrban: u,
    speedRural: r,
    speedHighway: h,
    alcoholBac: bac,
    emergencyGeneral: '112',
    isSchengen: true,
    visaEn: note2025
        ? 'Full Schengen member since 2025. A Schengen visa is required for '
            'Turkish citizens; days here count toward your 90/180.'
        : 'Schengen member. A Schengen visa is required for Turkish citizens; '
            'days here count toward your 90/180.',
    visaTr: note2025
        ? '2025\'ten beri tam Schengen üyesi. Türk vatandaşları için Schengen '
            'vizesi gerekir; buradaki günler 90/180\'e sayılır.'
        : 'Schengen üyesi. Türk vatandaşları için Schengen vizesi gerekir; '
            'buradaki günler 90/180\'e sayılır.',
    driveEn: (left ? 'Drive on the LEFT. ' : 'Drive on the right. ') +
        (vignette
            ? 'A motorway vignette (toll sticker) is required.'
            : 'Carry Green Card vehicle insurance.'),
    driveTr: (left ? 'SOLDAN trafik. ' : 'Sağdan trafik. ') +
        (vignette
            ? 'Otoyol için vinyet (geçiş etiketi) gerekir.'
            : 'Yeşil Kart araç sigortası bulundurun.'),
    vignette: vignette,
  );
}

VisaCountry _euNonSchengen(String code, String en, String tr, String flag,
    String cur, String curCode, int u, int r, int h, double bac,
    {bool left = false}) {
  return VisaCountry(
    code: code,
    nameEn: en,
    nameTr: tr,
    flag: flag,
    currency: cur,
    currencyCode: curCode,
    speedUrban: u,
    speedRural: r,
    speedHighway: h,
    alcoholBac: bac,
    emergencyGeneral: '112',
    isSchengen: false,
    visaEn:
        'EU member but NOT in the Schengen Area — it needs its own visa for '
        'Turkish citizens, and days here do NOT count toward the Schengen 90/180.',
    visaTr:
        'AB üyesi ama Schengen DEĞİL — Türk vatandaşları için ayrı vize gerekir '
        've buradaki günler Schengen 90/180\'e SAYILMAZ.',
    driveEn: left ? 'Drive on the LEFT.' : 'Drive on the right.',
    driveTr: left ? 'SOLDAN trafik.' : 'Sağdan trafik.',
  );
}

VisaCountry _visaFree(String code, String en, String tr, String flag,
    String cur, String curCode, int u, int r, int h, double bac) {
  return VisaCountry(
    code: code,
    nameEn: en,
    nameTr: tr,
    flag: flag,
    currency: cur,
    currencyCode: curCode,
    speedUrban: u,
    speedRural: r,
    speedHighway: h,
    alcoholBac: bac,
    emergencyGeneral: '112',
    isSchengen: false,
    visaEn:
        'Visa-free for Turkish citizens for up to 90 days. NOT in Schengen — '
        'time here does not count toward your Schengen 90/180.',
    visaTr:
        'Türk vatandaşları için 90 güne kadar vizesiz. Schengen DEĞİL — buradaki '
        'süre Schengen 90/180\'e sayılmaz.',
    driveEn: 'Drive on the right. Green Card insurance recommended.',
    driveTr: 'Sağdan trafik. Yeşil Kart sigortası önerilir.',
  );
}

VisaCountry? visaCountryByCode(String? code) {
  if (code == null) return null;
  final c = code.toUpperCase();
  for (final v in kVisaCountries) {
    if (v.code == c) return v;
  }
  return null;
}
