import '../models/country_profile.dart';

/// Static seed data keyed by ISO 3166-1 alpha-2 code.
///
/// Extension pattern: add a new key/value pair here. When a remote API is
/// ready, replace [findCountryProfile] to fetch remotely and fall back to
/// this map for offline use.
const Map<String, CountryProfile> kCountrySeedData = {
  // ── Germany ────────────────────────────────────────────────────────────────
  'DE': CountryProfile(
    isoCode: 'DE',
    name: 'Germany',
    isSchengen: true,
    currencies: ['Euro (EUR)'],
    entryNotes: [
      'EU/EEA/Swiss citizens: free movement, no time limit.',
      'Non-EU nationals: 90-day limit in any 180-day rolling Schengen window.',
      'No passport stamp required when crossing within Schengen.',
      'Non-Schengen arrivals: present passport at border control.',
    ],
    transportNotes: [
      'Autobahn (motorway): free for passenger cars, no vignette needed.',
      'Truck tolls apply on federal roads via HGS system.',
      'Umweltzone (green zone) sticker required in most city centres.',
      'Excellent rail network: Deutsche Bahn and regional trains cover the country.',
    ],
    moneyNotes: [
      'Euro is universal; contactless cards widely accepted.',
      'Some small restaurants and markets remain cash-only.',
      'Tipping: round up or add 5–10% at restaurants.',
      'ATMs (Geldautomat) widely available at banks and supermarkets.',
    ],
    connectivityNotes: [
      'Major networks: Telekom, Vodafone, O2.',
      'eSIM widely supported on most post-2020 devices.',
      '4G/5G coverage excellent in cities; rural gaps exist.',
      'EU roaming rules apply — EU SIMs work at no extra cost.',
    ],
    safetyNotes: [
      'Emergency: 112 (EU standard — police, fire, ambulance).',
      'Police non-emergency: 110.',
      'Hospitals: high-quality public system; EHIC/GHIC valid for EU residents.',
      'Crime: generally low; watch for pickpockets at major train stations.',
    ],
    localTips: [
      'Shops are closed on Sundays — stock up on Saturday.',
      'Pfand system: return bottles and cans for a deposit refund.',
      'Quiet hours (Ruhezeit): 22:00–06:00 and all day Sunday.',
      'Jaywalking is culturally frowned upon — use crossings.',
    ],
  ),

  // ── United States ──────────────────────────────────────────────────────────
  'US': CountryProfile(
    isoCode: 'US',
    name: 'United States',
    isSchengen: false,
    currencies: ['US Dollar (USD)'],
    entryNotes: [
      'VWP nationals: ESTA required before travel; max 90 days, no extensions.',
      'Non-VWP nationals: B-2 tourist visa required; apply well in advance.',
      'Complete CBP declaration form (or CBP One app) on arrival.',
      'Customs limits: \$800 duty-free; 1L alcohol; no fresh fruits/meats.',
    ],
    transportNotes: [
      'Driving on the right; highways mostly free (toll roads in northeast/midwest).',
      'Car is essential outside NYC, Chicago, and San Francisco.',
      'Uber/Lyft available in most cities; taxis in major hubs.',
      'Domestic flights often cheaper and faster than long-haul bus/train.',
    ],
    moneyNotes: [
      'Cards (Visa/Mastercard) accepted almost everywhere.',
      'Tipping 18–20% is standard at restaurants, bars, and taxis.',
      'Sales tax is NOT included on price tags — added at checkout.',
      'Dynamic currency conversion: always pay in USD to avoid extra fees.',
    ],
    connectivityNotes: [
      'Major networks: T-Mobile, AT&T, Verizon.',
      'eSIM widely supported; most US carriers sell eSIM tourist plans.',
      'Coverage strong in cities; rural and national park dead zones common.',
      'Prepaid SIMs available at airports, carrier stores, and Target/Walmart.',
    ],
    safetyNotes: [
      'Emergency: 911 (police, fire, ambulance).',
      'Medical costs are extremely high — comprehensive travel insurance is essential.',
      'Keep digital and physical copies of passport and ESTA.',
      'Tap water is drinkable in all states.',
    ],
    localTips: [
      'Portions are large — sharing dishes is normal and accepted.',
      'Free refills on soft drinks are standard at most restaurants.',
      'Tipping is part of service workers\' compensation — not optional.',
      'Left turn on red is illegal (unlike right turn, which is often allowed).',
    ],
  ),

  // ── Greece ─────────────────────────────────────────────────────────────────
  'GR': CountryProfile(
    isoCode: 'GR',
    name: 'Greece',
    isSchengen: true,
    currencies: ['Euro (EUR)'],
    entryNotes: [
      'EU/EEA/Swiss citizens: free movement, no time limit.',
      'Non-EU nationals: 90/180-day Schengen rule applies.',
      'Golden Visa programme: residency via qualifying real estate investment.',
      'Digital Nomad Visa available for remote workers meeting income thresholds.',
    ],
    transportNotes: [
      'Toll roads on major motorways (Egnatia Odos, Athens–Thessaloniki).',
      'Ferries are essential for island travel; major operators: Hellenic Seaways, ANEK, Minoan.',
      'No vignette required — tolls paid cash or card at booths.',
      'Driving in Athens: heavy traffic, limited parking, ZEP emission zones.',
    ],
    moneyNotes: [
      'Euro is universal; cards accepted in cities and tourist resorts.',
      'Cash preferred at smaller tavernas, markets, and island villages.',
      'Tipping: 5–10% appreciated; round up at cafés.',
      'ATMs widely available but some impose foreign card fees.',
    ],
    connectivityNotes: [
      'Major networks: Cosmote, Vodafone Greece, Wind Hellas.',
      'eSIM support growing on newer devices; check carrier compatibility.',
      'Coverage strong on mainland; can be patchy on smaller, remote islands.',
      'EU roaming rules apply — EU SIMs work without extra cost.',
    ],
    safetyNotes: [
      'Emergency: 112 (EU standard).',
      'Police: 100 | Ambulance: 166 | Fire: 199 | Coastguard: 108.',
      'EHIC/GHIC valid for EU residents at public hospitals.',
      'Pickpocketing occurs in crowded Athens markets and tourist areas.',
    ],
    localTips: [
      'Siesta hours (14:00–17:00): avoid noise and expect shops to close.',
      'Most state museums are free on the first Sunday of the month (Oct–Mar).',
      'Tipping: leave coins on the table, not on the card machine.',
      'Water taxis operate between beaches on larger islands — useful and cheap.',
    ],
  ),

  // ── Bulgaria ───────────────────────────────────────────────────────────────
  'BG': CountryProfile(
    isoCode: 'BG',
    name: 'Bulgaria',
    isSchengen: true,
    currencies: ['Bulgarian lev (BGN)'],
    entryNotes: [
      'Schengen member: air/sea borders since March 2024; land borders since Jan 2025.',
      'EU/EEA/Swiss citizens: free movement.',
      'Non-EU nationals: 90/180-day Schengen rule now applies at all borders.',
      'BGN is pegged 1:1 to the Euro basket — exchange rate is fixed.',
    ],
    transportNotes: [
      'E-vignette mandatory for all vehicles on Bulgarian roads.',
      'Purchase online at bgtoll.bg or at border crossings before driving.',
      'Speed cameras are common; limits strictly enforced.',
      'No cash toll booths on most motorways — e-vignette only.',
    ],
    moneyNotes: [
      'Bulgarian lev (BGN); Euro not legal tender but accepted at tourist venues.',
      'Cards accepted in cities; cash strongly preferred in villages and rural areas.',
      'ATMs widely available in Sofia and larger towns.',
      'Exchange offices in city centres offer better rates than airport kiosks.',
    ],
    connectivityNotes: [
      'Major networks: A1 Bulgaria, Vivacom, Yettel.',
      'eSIM support limited — confirm with your device and home carrier before travel.',
      '4G coverage good in Sofia and cities; patchy in mountain and rural areas.',
      'EU roaming rules apply — EU SIMs work without extra charges.',
    ],
    safetyNotes: [
      'Emergency: 112 (EU standard).',
      'Mountain rescue: 1410 (important for hikers in Rila, Pirin, Rhodopes).',
      'Road conditions: variable; some rural roads are poorly maintained.',
      'EHIC/GHIC valid for EU residents at public hospitals.',
    ],
    localTips: [
      'Head shake = yes; nod = no — opposite of most Western countries.',
      'Cyrillic script is used everywhere — download offline maps before arrival.',
      'Rakia (fruit brandy) is a national tradition; often offered as a welcome drink.',
      'Bargaining is acceptable at open markets but not in shops.',
    ],
  ),

  // ── Italy ──────────────────────────────────────────────────────────────────
  'IT': CountryProfile(
    isoCode: 'IT',
    name: 'Italy',
    isSchengen: true,
    currencies: ['Euro (EUR)'],
    entryNotes: [
      'EU/EEA/Swiss citizens: free movement, no time limit.',
      'Non-EU nationals: 90/180-day Schengen rule applies.',
      'Digital Nomad Visa available for remote workers.',
      'Elective Residency Visa for those with sufficient passive income.',
    ],
    transportNotes: [
      'Toll autostrade: pay by distance at exit booths, or use Telepass tag.',
      'ZTL (Zona Traffico Limitato): restricted zones in historic city centres.',
      'Rental cars frequently fined for inadvertent ZTL entry — check maps carefully.',
      'Excellent rail: Trenitalia and Italo connect major cities at high speed.',
    ],
    moneyNotes: [
      'Euro is universal; cards widely accepted in cities and tourist areas.',
      'Cash still important — some trattorias and small businesses are cash-only.',
      'Coperto (cover charge): standard at sit-down restaurants, listed on menu.',
      'Tipping not mandatory; 1–2 EUR per person is appreciated for good service.',
    ],
    connectivityNotes: [
      'Major networks: TIM, Vodafone Italy, WindTre, Iliad.',
      'eSIM widely supported across all major carriers.',
      'Excellent 4G/5G in cities; patchy in Alpine valleys and rural south.',
      'EU roaming rules apply — EU SIMs work without extra charges.',
    ],
    safetyNotes: [
      'Emergency: 112 (EU standard).',
      'Carabinieri (police): 112 | Ambulance: 118 | Fire: 115.',
      'Pickpocketing common in Rome (Colosseum, Vatican), Florence, Naples.',
      'EHIC/GHIC valid at public hospitals for EU residents.',
    ],
    localTips: [
      'Cappuccino after 11:00 is a tourist tell — Italians drink it at breakfast.',
      'Lunch (12:30–14:30) and dinner (after 19:30) follow strict rhythms.',
      'Vatican and major museums: book tickets online to skip queues.',
      'Tap water is safe and drinkable everywhere — ask for acqua del rubinetto.',
    ],
  ),
};

/// Returns the [CountryProfile] for the given ISO code, or null if unsupported.
///
/// When a remote API is integrated, replace this function body to fetch from
/// the network and fall back to [kCountrySeedData] for offline use.
CountryProfile? findCountryProfile(String isoCode) =>
    kCountrySeedData[isoCode.toUpperCase()];
