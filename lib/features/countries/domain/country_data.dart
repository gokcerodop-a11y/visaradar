import 'visa_country.dart';

final List<VisaCountry> kVisaCountries = [
  // ── Home country ────────────────────────────────────────────────────────────
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
    emergencyPolice: '155',
    emergencyAmbulance: '112',
    isSchengen: false,
    requiresVisaForTurkish: false,
    capitalEn: 'Ankara',
    capitalTr: 'Ankara',
    officialLanguage: 'Turkish',
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
    culturalEn:
        'Turkey bridges two continents — Europe and Asia — with a civilisational '
        'depth spanning Hittites, Greeks, Romans, Byzantines, Seljuks and Ottomans. '
        'Istanbul\'s Hagia Sophia, Topkapı Palace and the Grand Bazaar sit alongside '
        'Cappadocia\'s fairy chimneys, Ephesus\'s Roman ruins and the travertine '
        'terraces of Pamukkale. Turkish cuisine — köfte, kebab, mezes, baklava — '
        'is recognised as one of the world\'s great culinary traditions.',
    culturalTr:
        'Türkiye, Hitit, Yunan, Roma, Bizans, Selçuklu ve Osmanlı medeniyetlerinin '
        'izlerini taşıyan iki kıtayı birleştiren eşsiz bir ülkedir. İstanbul\'un '
        'Ayasofyası, Topkapı Sarayı ve Kapalıçarşı; Kapadokya\'nın peri bacaları, '
        'Efes\'in Roma kalıntıları ve Pamukkale\'nin travertenlerle birlikte '
        'dünyanın en zengin kültür coğrafyalarından birini oluşturur.',
    practicalEn:
        'Currency: Turkish Lira (TRY). ATMs widely available. Tipping 10–15 % '
        'is customary in restaurants. Bargaining is expected in bazaars. '
        'Istanbul\'s traffic is notorious — allow extra travel time.',
    practicalTr:
        'Para birimi: Türk Lirası (TRY). ATM yaygın. Restoranlarda %10–15 bahşiş '
        'yerleşik gelenektir. Çarşılarda pazarlık yapılır. '
        'İstanbul trafiği ünlüdür — seyahat süresi için pay bırakın.',
    bestTimeEn: 'April–June and September–October for mild weather. July–August is hot and crowded on the coasts.',
    bestTimeTr: 'Nisan–Haziran ve Eylül–Ekim ılıman hava için idealdir. Temmuz–Ağustos kıyılarda sıcak ve kalabalıktır.',
  ),

  // ── Core Schengen neighbours ─────────────────────────────────────────────
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
    emergencyPolice: '100',
    emergencyAmbulance: '166',
    isSchengen: true,
    requiresVisaForTurkish: true,
    capitalEn: 'Athens',
    capitalTr: 'Atina',
    officialLanguage: 'Greek',
    visaEn:
        'Schengen visa required for Turkish citizens. A simplified "express" '
        'island visa is available on arrival for 10 designated Aegean islands '
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
    culturalEn:
        'Greece is the cradle of Western civilisation, democracy and philosophy. '
        'The Acropolis, Delphi, Olympia and Mycenae are among the world\'s most '
        'significant archaeological sites. Greek cuisine — fresh seafood, feta, '
        'olives, moussaka — reflects the Mediterranean diet in its purest form. '
        'The 6,000-island archipelago offers some of Europe\'s most spectacular scenery.',
    culturalTr:
        'Yunanistan Batı medeniyetinin, demokrasinin ve felsefenin beşiğidir. '
        'Akropolis, Delphi, Olympia ve Miken dünyanın en önemli arkeolojik alanlarındandır. '
        'Taze deniz ürünleri, beyaz peynir, zeytin ve musakalı Yunan mutfağı '
        'Akdeniz diyetinin özüdür. 6.000 adalık takımada Avrupa\'nın en '
        'muhteşem manzaralarına ev sahipliği yapar.',
    practicalEn:
        'Summer (June–Sept) is peak season — book ferries and accommodation well in advance. '
        'Tipping is appreciated (5–10 %). Many shops close for afternoon siesta. '
        'EU plug sockets (Type C/F).',
    practicalTr:
        'Yaz (Haziran–Eylül) yoğun sezon — feribot ve konaklama rezervasyonlarını '
        'önceden yapın. %5–10 bahşiş takdirle karşılanır. Pek çok dükkan '
        'öğleden sonra siesta için kapanır.',
    bestTimeEn: 'May–June and September for ideal weather without peak crowds. July–August is extremely hot and busy.',
    bestTimeTr: 'Mayıs–Haziran ve Eylül kalabalık olmadan ideal hava sunar. Temmuz–Ağustos çok sıcak ve kalabalıktır.',
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
    requiresVisaForTurkish: true,
    capitalEn: 'Sofia',
    capitalTr: 'Sofya',
    officialLanguage: 'Bulgarian',
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
    culturalEn:
        'Bulgaria\'s history spans Thracian, Roman, Byzantine, Ottoman and Slavic '
        'cultures. The Rila Monastery (UNESCO), Plovdiv\'s Roman amphitheatre and '
        'the Valley of Roses are national treasures. Bulgaria has one of Europe\'s '
        'most affordable costs of living and stunning Black Sea coastal resorts.',
    culturalTr:
        'Bulgaristan\'ın tarihi Trak, Roma, Bizans, Osmanlı ve Slav kültürlerini kapsar. '
        'Rila Manastırı (UNESCO), Plovdiv\'in Roma amfitiyatrosu ve Gül Vadisi '
        'ulusal hazinelerdir. Bulgaristan, Avrupa\'nın en uygun fiyatlı '
        'yaşam maliyetlerinden birine ve muhteşem Karadeniz tatil beldelerine sahiptir.',
    bestTimeEn: 'May–September for beach and hiking. December–March for ski resorts (Bansko).',
    bestTimeTr: 'Mayıs–Eylül plaj ve yürüyüş için. Aralık–Mart kayak tesisleri (Bansko) için.',
  ),

  // ── Major Schengen countries ─────────────────────────────────────────────
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
    emergencyPolice: '113',
    emergencyAmbulance: '118',
    isSchengen: true,
    requiresVisaForTurkish: true,
    capitalEn: 'Rome',
    capitalTr: 'Roma',
    officialLanguage: 'Italian',
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
    culturalEn:
        'Italy holds the world\'s greatest concentration of UNESCO World Heritage Sites. '
        'Rome\'s Colosseum, Vatican Museums, Florence\'s Uffizi Gallery, Venice\'s canals '
        'and the Amalfi Coast define Western art and architecture. Italian cuisine — '
        'pasta, pizza, risotto, gelato, espresso — is a global cultural export. '
        'The Italian Renaissance reshaped all of European civilisation.',
    culturalTr:
        'İtalya, dünyanın en yoğun UNESCO Dünya Mirası alanlarına ev sahipliği yapar. '
        'Roma\'nın Kolezyumu, Vatikan Müzeleri, Floransa\'nın Uffizi Galerisi, '
        'Venedik\'in kanalları ve Amalfi Kıyısı Batı sanat ve mimarisini tanımlar. '
        'Makarna, pizza, risotto, dondurma ve espresso ile İtalyan mutfağı '
        'küresel bir kültürel ihracattır.',
    bestTimeEn: 'April–June and September–October. Avoid August — cities empty, coasts overcrowded.',
    bestTimeTr: 'Nisan–Haziran ve Eylül–Ekim. Ağustos\'tan kaçının — şehirler boş, kıyılar aşırı kalabalık.',
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
    emergencyPolice: '17',
    emergencyAmbulance: '15',
    isSchengen: true,
    requiresVisaForTurkish: true,
    capitalEn: 'Paris',
    capitalTr: 'Paris',
    officialLanguage: 'French',
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
    culturalEn:
        'France is the world\'s most visited country, a global centre of art, '
        'fashion, gastronomy and philosophy. The Louvre, Eiffel Tower, Versailles '
        'and the châteaux of the Loire Valley represent centuries of royal and '
        'artistic ambition. French cuisine and wine are recognised by UNESCO as '
        'Intangible Cultural Heritage. From the Alps to the Riviera, the Normandy '
        'beaches to Provence\'s lavender fields, France offers extraordinary diversity.',
    culturalTr:
        'Fransa dünyanın en çok ziyaret edilen ülkesi; sanat, moda, gastronomi '
        've felsefenin küresel merkezidir. Louvre, Eyfel Kulesi, Versailles '
        've Loire Vadisi şatoları asırlık kraliyet ve sanatsal tutkuyu yansıtır. '
        'Fransız mutfağı ve şarabı UNESCO tarafından somut olmayan kültürel '
        'miras olarak tanınmaktadır.',
    bestTimeEn: 'June–August for beaches and festivals. April–May and September for Paris (fewer crowds).',
    bestTimeTr: 'Haziran–Ağustos plajlar ve festivaller için. Nisan–Mayıs ve Eylül Paris için (daha az kalabalık).',
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
    speedHighway: -1,
    alcoholBac: 0.05,
    emergencyGeneral: '112',
    emergencyPolice: '110',
    isSchengen: true,
    requiresVisaForTurkish: true,
    capitalEn: 'Berlin',
    capitalTr: 'Berlin',
    officialLanguage: 'German',
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
    culturalEn:
        'Germany is Europe\'s largest economy and a cultural powerhouse. Berlin\'s '
        'vibrant arts scene, Munich\'s Oktoberfest, the Rhine Valley\'s castles, '
        'Cologne\'s Gothic cathedral and the Romantic Road define the country\'s '
        'rich heritage. Germany produced Goethe, Beethoven, Bach, Einstein and '
        'Kant — intellectual giants who shaped modern thought. The Christmas '
        'markets (Weihnachtsmärkte) are among Europe\'s most magical experiences.',
    culturalTr:
        'Almanya Avrupa\'nın en büyük ekonomisi ve kültürel bir güç merkezidir. '
        'Berlin\'in dinamik sanat sahnesi, Münih\'in Oktoberfest\'i, Ren '
        'Vadisi\'nin şatoları, Köln Katedrali ve Romantik Yol ülkenin zengin '
        'mirasını tanımlar. Goethe, Beethoven, Bach, Einstein ve Kant modern '
        'düşünceyi şekillendiren Alman dehaları arasındadır.',
    bestTimeEn: 'May–September for outdoor activities. December for Christmas markets.',
    bestTimeTr: 'Mayıs–Eylül açık hava etkinlikleri için. Aralık Noel pazarları için.',
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
    requiresVisaForTurkish: true,
    capitalEn: 'Madrid',
    capitalTr: 'Madrid',
    officialLanguage: 'Spanish',
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
    culturalEn:
        'Spain is a land of extraordinary cultural contrasts — from the Moorish '
        'splendour of Granada\'s Alhambra and Córdoba\'s Mezquita to Gaudí\'s '
        'surreal Barcelona and Picasso\'s native Málaga. Flamenco, bullfighting, '
        'tapas culture, La Tomatina and La Feria de Abril reflect a passionate '
        'national character. Spain\'s 47 UNESCO sites make it one of the most '
        'heritage-rich nations on earth.',
    culturalTr:
        'İspanya olağanüstü kültürel zıtlıkların ülkesidir: Granada\'nın Elhamra\'sı '
        've Kurtuba\'nın Mezquitası\'nın Endülüs ihtişamından Gaudí\'nin '
        'sürreal Barselonası\'na ve Picasso\'nun doğduğu Malaga\'ya uzanır. '
        'Flamenko, boğa güreşi ve tapas kültürü İspanyol ruhunu yansıtır.',
    bestTimeEn: 'March–May and September–November. Avoid August on the coasts — extremely crowded.',
    bestTimeTr: 'Mart–Mayıs ve Eylül–Kasım. Ağustos\'ta kıyılardan kaçının — aşırı kalabalık.',
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
    requiresVisaForTurkish: true,
    capitalEn: 'Zagreb',
    capitalTr: 'Zagreb',
    officialLanguage: 'Croatian',
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
    culturalEn:
        'Croatia\'s Adriatic coastline — with the walled city of Dubrovnik, '
        'the Plitvice Lakes (UNESCO) and the Dalmatian islands — is among Europe\'s '
        'most breathtaking. The country served as a filming location for Game of '
        'Thrones. Roman Diocletian\'s Palace in Split remains one of the world\'s '
        'best-preserved ancient monuments.',
    culturalTr:
        'Hırvatistan\'ın Adriyatik kıyısı — surlarla çevrili Dubrovnik şehri, '
        'Plitvice Gölleri (UNESCO) ve Dalmaçya adaları — Avrupa\'nın en nefes kesen '
        'manzaralarından birini sunar. Ülke Game of Thrones\'un çekim mekanı oldu. '
        'Split\'teki Roma İmparatoru Diocletianus Sarayı dünyanın en iyi korunmuş '
        'antik anıtlarından biri olmaya devam ediyor.',
    bestTimeEn: 'May–June and September for pleasant weather without peak summer crowds.',
    bestTimeTr: 'Mayıs–Haziran ve Eylül, yoğun yaz kalabalığı olmadan keyifli hava sunar.',
  ),

  // ── Non-Schengen visa-free ──────────────────────────────────────────────
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
    requiresVisaForTurkish: false,
    capitalEn: 'Podgorica',
    capitalTr: 'Podgorica',
    officialLanguage: 'Montenegrin',
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
    culturalEn:
        'Montenegro\'s dramatic landscape — the Bay of Kotor (UNESCO), Lake Skadar '
        'and Durmitor National Park — makes it one of Europe\'s most scenic '
        'small countries. The medieval old town of Kotor is a UNESCO World '
        'Heritage Site. Strong cultural ties with Serbia and Orthodox Christianity.',
    culturalTr:
        'Karadağ\'ın dramatik manzarası — Kotor Körfezi (UNESCO), İşkodra Gölü ve '
        'Durmitor Milli Parkı — onu Avrupa\'nın en güzel küçük ülkelerinden '
        'biri yapar. Kotor\'un ortaçağ eski şehri UNESCO Dünya Mirası\'dır.',
    bestTimeEn: 'May–September for coast. December–March for skiing in Kolašin.',
    bestTimeTr: 'Mayıs–Eylül kıyı için. Aralık–Mart Kolašin\'de kayak için.',
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
    requiresVisaForTurkish: false,
    capitalEn: 'Tirana',
    capitalTr: 'Tiran',
    officialLanguage: 'Albanian',
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
    culturalEn:
        'Albania is emerging as one of Europe\'s most exciting undiscovered destinations. '
        'Butrint (UNESCO), the ancient city of Berat ("City of a Thousand Windows"), '
        'and the Riviera\'s turquoise beaches offer remarkable value. Albania has '
        'strong historical and cultural ties with Turkey from the Ottoman period.',
    culturalTr:
        'Arnavutluk, Avrupa\'nın en heyecan verici keşfedilmemiş destinasyonlarından '
        'biri olarak öne çıkmaktadır. Butrint (UNESCO), "Bin Pencereli Şehir" '
        'Berat ve Riviera\'nın turkuaz plajları olağanüstü değer sunar. '
        'Osmanlı döneminden kalan Türkiye ile güçlü tarihi ve kültürel bağları vardır.',
    bestTimeEn: 'June–September for the Riviera. April–May for cooler exploration of Berat and Gjirokastër.',
    bestTimeTr: 'Haziran–Eylül Riviera için. Nisan–Mayıs Berat ve Gjirokastra keşfi için serin.',
  ),

  // ── Rest of Schengen Area (EU) ──────────────────────────────────────────
  _schengen('AT', 'Austria', 'Avusturya', '🇦🇹', '€', 'EUR', 50, 100, 130, 0.05,
      capital: 'Vienna', capitalTr: 'Viyana', lang: 'German',
      vignette: true,
      cultural: 'Vienna — imperial capital of the Habsburg empire — is the birthplace of '
          'Mozart, Beethoven, Freud and Klimt. The Kunsthistorisches Museum, '
          'Schönbrunn Palace and the Vienna State Opera define European high culture. '
          'Austrian cuisine (Wiener Schnitzel, Sachertorte, Apfelstrudel) and '
          'coffee-house culture are UNESCO-recognised traditions.',
      culturalTr: 'Viyana — Habsburg imparatorluğunun başkenti — Mozart, Beethoven, '
          'Freud ve Klimt\'in doğduğu şehirdir. Güzel Sanatlar Müzesi, Schönbrunn '
          'Sarayı ve Viyana Devlet Operası Avrupa yüksek kültürünü tanımlar. '
          'Avusturya mutfağı (Viyana Şnitzel, Sachertorte) UNESCO tarafından tanınmaktadır.',
      practical: 'Excellent public transport. Museum Pass recommended for Vienna. '
          'Tips: round up the bill in restaurants.',
      practicalTr: 'Mükemmel toplu taşıma. Viyana için Müze Kartı önerilir. '
          'Restoranlarda faturayı yuvarlayarak bahşiş bırakın.',
      bestTime: 'April–October for sightseeing; December for Christmas markets; '
          'January–March for ski resorts.',
      bestTimeTr: 'Nisan–Ekim geziler için; Aralık Noel pazarları; Ocak–Mart kayak.'),
  _schengen('BE', 'Belgium', 'Belçika', '🇧🇪', '€', 'EUR', 50, 90, 120, 0.05,
      capital: 'Brussels', capitalTr: 'Brüksel', lang: 'French/Dutch/German'),
  _schengen('NL', 'Netherlands', 'Hollanda', '🇳🇱', '€', 'EUR', 50, 80, 100, 0.05,
      capital: 'Amsterdam', capitalTr: 'Amsterdam', lang: 'Dutch'),
  _schengen('LU', 'Luxembourg', 'Lüksemburg', '🇱🇺', '€', 'EUR', 50, 90, 130, 0.05,
      capital: 'Luxembourg City', capitalTr: 'Lüksemburg Şehri', lang: 'Luxembourgish/French/German'),
  _schengen('PT', 'Portugal', 'Portekiz', '🇵🇹', '€', 'EUR', 50, 90, 120, 0.05,
      capital: 'Lisbon', capitalTr: 'Lizbon', lang: 'Portuguese'),
  _schengen('DK', 'Denmark', 'Danimarka', '🇩🇰', 'kr', 'DKK', 50, 80, 130, 0.05,
      capital: 'Copenhagen', capitalTr: 'Kopenhag', lang: 'Danish'),
  _schengen('SE', 'Sweden', 'İsveç', '🇸🇪', 'kr', 'SEK', 50, 70, 110, 0.02,
      capital: 'Stockholm', capitalTr: 'Stockholm', lang: 'Swedish'),
  _schengen('FI', 'Finland', 'Finlandiya', '🇫🇮', '€', 'EUR', 50, 80, 120, 0.05,
      capital: 'Helsinki', capitalTr: 'Helsinki', lang: 'Finnish/Swedish'),
  _schengen('PL', 'Poland', 'Polonya', '🇵🇱', 'zł', 'PLN', 50, 90, 140, 0.02,
      capital: 'Warsaw', capitalTr: 'Varşova', lang: 'Polish'),
  _schengen('CZ', 'Czechia', 'Çekya', '🇨🇿', 'Kč', 'CZK', 50, 90, 130, 0.00,
      capital: 'Prague', capitalTr: 'Prag', lang: 'Czech', vignette: true),
  _schengen('SK', 'Slovakia', 'Slovakya', '🇸🇰', '€', 'EUR', 50, 90, 130, 0.00,
      capital: 'Bratislava', capitalTr: 'Bratislava', lang: 'Slovak', vignette: true),
  _schengen('HU', 'Hungary', 'Macaristan', '🇭🇺', 'Ft', 'HUF', 50, 90, 130, 0.00,
      capital: 'Budapest', capitalTr: 'Budapeşte', lang: 'Hungarian', vignette: true),
  _schengen('SI', 'Slovenia', 'Slovenya', '🇸🇮', '€', 'EUR', 50, 90, 130, 0.05,
      capital: 'Ljubljana', capitalTr: 'Ljubljana', lang: 'Slovenian', vignette: true),
  _schengen('RO', 'Romania', 'Romanya', '🇷🇴', 'lei', 'RON', 50, 90, 130, 0.00,
      capital: 'Bucharest', capitalTr: 'Bükreş', lang: 'Romanian',
      vignette: true, note2025: true),
  _schengen('EE', 'Estonia', 'Estonya', '🇪🇪', '€', 'EUR', 50, 90, 110, 0.02,
      capital: 'Tallinn', capitalTr: 'Tallinn', lang: 'Estonian'),
  _schengen('LV', 'Latvia', 'Letonya', '🇱🇻', '€', 'EUR', 50, 90, 110, 0.05,
      capital: 'Riga', capitalTr: 'Riga', lang: 'Latvian'),
  _schengen('LT', 'Lithuania', 'Litvanya', '🇱🇹', '€', 'EUR', 50, 90, 130, 0.04,
      capital: 'Vilnius', capitalTr: 'Vilnius', lang: 'Lithuanian'),
  _schengen('MT', 'Malta', 'Malta', '🇲🇹', '€', 'EUR', 50, 80, 80, 0.05,
      capital: 'Valletta', capitalTr: 'Valletta', lang: 'Maltese/English', left: true),

  // ── Schengen non-EU ─────────────────────────────────────────────────────
  _schengen('CH', 'Switzerland', 'İsviçre', '🇨🇭', 'CHF', 'CHF', 50, 80, 120, 0.05,
      capital: 'Bern', capitalTr: 'Bern', lang: 'German/French/Italian/Romansh', vignette: true,
      cultural: 'Switzerland is the home of precision watchmaking, direct democracy, '
          'Alpine grandeur and international diplomacy. Geneva hosts the UN and Red Cross; '
          'Zurich is a global financial hub. Swiss cuisine (fondue, raclette, Rösti) '
          'and chocolate are world-renowned. The Matterhorn, Jungfraujoch and Lake Geneva '
          'are among the world\'s most iconic landscapes.',
      culturalTr: 'İsviçre hassas saat yapımcılığının, doğrudan demokrasinin, '
          'Alp ihtişamının ve uluslararası diplomasinin evidir. Cenevre BM\'ye '
          've Kızılhaç\'a ev sahipliği yapar; Zürih küresel bir finans merkezidir. '
          'Fondue, raclette ve Swiss çikolatası dünyaca ünlüdür.',
      practical: 'Extremely expensive — budget carefully. Swiss Travel Pass offers unlimited '
          'rail, bus and boat travel. Tip: use post buses (PostBus) for scenic routes.',
      practicalTr: 'Son derece pahalı — bütçenizi dikkatli planlayın. Swiss Travel Pass '
          'sınırsız tren, otobüs ve tekne seyahati sunar.',
      bestTime: 'June–September for hiking and Alpine scenery. December–March for skiing.',
      bestTimeTr: 'Haziran–Eylül yürüyüş ve Alp manzarası için. Aralık–Mart kayak için.'),
  _schengen('NO', 'Norway', 'Norveç', '🇳🇴', 'kr', 'NOK', 50, 80, 100, 0.02,
      capital: 'Oslo', capitalTr: 'Oslo', lang: 'Norwegian'),
  _schengen('IS', 'Iceland', 'İzlanda', '🇮🇸', 'kr', 'ISK', 50, 80, 90, 0.05,
      capital: 'Reykjavik', capitalTr: 'Reykjavik', lang: 'Icelandic'),
  _schengen('LI', 'Liechtenstein', 'Lihtenştayn', '🇱🇮', 'CHF', 'CHF', 50, 80, 100, 0.08,
      capital: 'Vaduz', capitalTr: 'Vaduz', lang: 'German'),

  // ── EU but NOT Schengen — visa required for Turkish citizens ─────────────
  _euNonSchengen('IE', 'Ireland', 'İrlanda', '🇮🇪', '€', 'EUR', 50, 100, 120, 0.05,
      capital: 'Dublin', capitalTr: 'Dublin', lang: 'Irish/English', left: true),
  _euNonSchengen('CY', 'Cyprus', 'Kıbrıs (GKRY)', '🇨🇾', '€', 'EUR', 50, 80, 100, 0.05,
      capital: 'Nicosia', capitalTr: 'Lefkoşa', lang: 'Greek/Turkish', left: true),

  // ── Non-Schengen Europe — visa-free for Turkish citizens (90 days) ──────
  _visaFree('RS', 'Serbia', 'Sırbistan', '🇷🇸', 'дин', 'RSD', 50, 80, 130, 0.03,
      capital: 'Belgrade', capitalTr: 'Belgrad', lang: 'Serbian'),
  _visaFree('BA', 'Bosnia & Herzegovina', 'Bosna-Hersek', '🇧🇦', 'KM', 'BAM', 50, 80, 130, 0.03,
      capital: 'Sarajevo', capitalTr: 'Saraybosna', lang: 'Bosnian/Serbian/Croatian'),
  _visaFree('MK', 'North Macedonia', 'Kuzey Makedonya', '🇲🇰', 'ден', 'MKD', 50, 80, 130, 0.05,
      capital: 'Skopje', capitalTr: 'Üsküp', lang: 'Macedonian'),
  _visaFree('XK', 'Kosovo', 'Kosova', '🇽🇰', '€', 'EUR', 50, 80, 130, 0.05,
      capital: 'Pristina', capitalTr: 'Priştine', lang: 'Albanian/Serbian'),
  _visaFree('MD', 'Moldova', 'Moldova', '🇲🇩', 'L', 'MDL', 50, 90, 110, 0.03,
      capital: 'Chișinău', capitalTr: 'Kişinev', lang: 'Romanian'),
  _visaFree('UA', 'Ukraine', 'Ukrayna', '🇺🇦', '₴', 'UAH', 50, 90, 130, 0.00,
      capital: 'Kyiv', capitalTr: 'Kyiv', lang: 'Ukrainian'),

  // Georgia — 1 YEAR (365 days) visa-free for Turkish citizens
  VisaCountry(
    code: 'GE',
    nameEn: 'Georgia',
    nameTr: 'Gürcistan',
    flag: '🇬🇪',
    currency: '₾',
    currencyCode: 'GEL',
    speedUrban: 50,
    speedRural: 90,
    speedHighway: 110,
    alcoholBac: 0.03,
    emergencyGeneral: '112',
    isSchengen: false,
    requiresVisaForTurkish: false,
    capitalEn: 'Tbilisi',
    capitalTr: 'Tiflis',
    officialLanguage: 'Georgian',
    visaEn:
        'Exceptional visa freedom: Turkish citizens may stay in Georgia for up to '
        '1 year (365 days) without a visa. NOT in Schengen — time here does not '
        'count toward your Schengen 90/180.',
    visaTr:
        'İstisnaî vize serbestisi: Türk vatandaşları Gürcistan\'da vize olmaksızın '
        '1 yıla (365 güne) kadar kalabilir. Schengen DEĞİL — buradaki süre '
        'Schengen 90/180 hesabınıza sayılmaz.',
    driveEn: 'Drive on the right. Green Card insurance recommended. Road quality '
        'varies widely outside major cities.',
    driveTr: 'Sağdan trafik. Yeşil Kart sigortası önerilir. Büyük şehirlerin dışında '
        'yol kalitesi büyük farklılıklar gösterir.',
    culturalEn:
        'Georgia is the cradle of wine (8,000-year winemaking tradition), '
        'home to ancient cave cities (Vardzia), the Caucasus mountain scenery '
        'of Kazbegi, and Tbilisi\'s vibrant old town of cobblestone streets and '
        'balconied houses. Georgian cuisine — khinkali dumplings, khachapuri '
        'cheese bread — is among the Caucasus region\'s finest. Strong historical '
        'ties with Turkey through shared Ottoman and Caucasian heritage.',
    culturalTr:
        'Gürcistan şarabın beşiğidir (8.000 yıllık şarapçılık geleneği). '
        'Antik mağara şehri Vardzia, Kazbegi\'nin Kafkas dağ manzarası ve '
        'Tiflis\'in arnavut kaldırımlı sokakları ve balkonlu evleriyle canlı '
        'tarihi şehir merkezi benzersizdir. Hinkali köfte ve hacapuri peynirli ekmek '
        'Kafkasya\'nın en iyi mutfaklarındandır.',
    practicalEn:
        'Very affordable destination. Lari (GEL) is easily exchanged. '
        'Wine is extremely inexpensive. Tipping 10 % is standard. '
        'Tbilisi to Istanbul flights are regular and affordable.',
    practicalTr:
        'Çok uygun fiyatlı destinasyon. Lari (GEL) kolayca bozdurulur. '
        'Şarap son derece ucuzdur. %10 bahşiş standarttır. '
        'Tiflis–İstanbul uçuşları düzenli ve uygundur.',
    bestTimeEn: 'May–June and September–October for pleasant weather. July–August is hot in Tbilisi.',
    bestTimeTr: 'Mayıs–Haziran ve Eylül–Ekim ideal havalar için. Temmuz–Ağustos Tiflis\'te çok sıcaktır.',
  ),

  // ── UK + European microstates ────────────────────────────────────────────
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
    requiresVisaForTurkish: true,
    capitalEn: 'London',
    capitalTr: 'Londra',
    officialLanguage: 'English',
    visaEn:
        'NOT in the EU or Schengen. A Standard Visitor visa is required for '
        'Turkish citizens — apply online via UKVI (gov.uk/apply-uk-visa). '
        'Time here does not count toward the Schengen 90/180.',
    visaTr:
        'AB veya Schengen DEĞİL. Türk vatandaşları için Standart Ziyaretçi vizesi '
        'gerekir — UKVI üzerinden online başvurun (gov.uk/apply-uk-visa). '
        'Buradaki süre Schengen 90/180\'e sayılmaz.',
    driveEn:
        'Drive on the LEFT. Speed limits are in mph (30 mph ≈ 48 km/h city; '
        '60 mph ≈ 96 km/h rural; 70 mph ≈ 112 km/h motorway). '
        'Congestion Charge and ULEZ apply in central London.',
    driveTr:
        'SOLDAN trafik. Hız limitleri mil/saat cinsindendir (şehir 30 mph ≈ 48 km/s; '
        'taşra 60 mph ≈ 96 km/s; otoyol 70 mph ≈ 112 km/s). '
        'Merkez Londra\'da Sıkışıklık Ücreti ve ULEZ uygulanır.',
    culturalEn:
        'The United Kingdom\'s cultural influence is global and unparalleled. '
        'London is one of the world\'s great cosmopolitan capitals: the British Museum, '
        'National Gallery, Tower of London, Buckingham Palace and West End theatre '
        'are world-class. Shakespeare, Newton, Darwin, Churchill and the Beatles '
        'are among history\'s most transformative British figures. Scotland\'s '
        'Highlands, Wales\'s castles and Northern Ireland\'s Giant\'s Causeway '
        'add natural and historical grandeur.',
    culturalTr:
        'Birleşik Krallık\'ın kültürel etkisi küresel ve eşsizdir. Londra '
        'dünyanın büyük kozmopolit başkentlerinden biridir: British Museum, '
        'Ulusal Galeri, Londra Kulesi, Buckingham Sarayı ve West End tiyatrosu '
        'dünya standartlarındadır. Shakespeare, Newton, Darwin, Churchill '
        've Beatles tarihin en dönüştürücü İngiliz isimleri arasındadır.',
    practicalEn:
        'Currency: GBP (£). Tipping 10–15 % is standard in restaurants. '
        'Oyster Card or contactless payment for London transport. '
        'Drive on the left — be especially careful at roundabouts.',
    practicalTr:
        'Para birimi: GBP (£). Restoranlarda %10–15 bahşiş standarttır. '
        'Londra toplu taşıması için Oyster Kart veya temassız ödeme. '
        'Soldan trafiğe özellikle döner kavşaklarda dikkat edin.',
    bestTimeEn: 'May–September for the best weather. December for festive atmosphere in London.',
    bestTimeTr: 'Mayıs–Eylül en iyi hava için. Aralık Londra\'da şenlikli atmosfer için.',
  ),

  _visaFree('AD', 'Andorra', 'Andorra', '🇦🇩', '€', 'EUR', 50, 90, 90, 0.05,
      capital: 'Andorra la Vella', capitalTr: 'Andorra la Vella', lang: 'Catalan'),
  _schengen('MC', 'Monaco', 'Monako', '🇲🇨', '€', 'EUR', 50, 90, 130, 0.05,
      capital: 'Monaco', capitalTr: 'Monako', lang: 'French'),
  _schengen('SM', 'San Marino', 'San Marino', '🇸🇲', '€', 'EUR', 50, 90, 130, 0.05,
      capital: 'San Marino', capitalTr: 'San Marino', lang: 'Italian'),

  // ── New countries (v1.1) ──────────────────────────────────────────────────

  // Azerbaijan — visa-free 90 days
  VisaCountry(
    code: 'AZ',
    nameEn: 'Azerbaijan',
    nameTr: 'Azerbaycan',
    flag: '🇦🇿',
    currency: '₼',
    currencyCode: 'AZN',
    speedUrban: 60,
    speedRural: 90,
    speedHighway: 120,
    alcoholBac: 0.00,
    emergencyGeneral: '112',
    emergencyPolice: '102',
    emergencyAmbulance: '103',
    isSchengen: false,
    requiresVisaForTurkish: false,
    capitalEn: 'Baku',
    capitalTr: 'Bakü',
    officialLanguage: 'Azerbaijani',
    visaEn:
        'Visa-free for Turkish citizens for up to 90 days under the bilateral '
        'visa exemption agreement. NOT in Schengen — days here do not count '
        'toward your Schengen 90/180.',
    visaTr:
        'Türk vatandaşları için ikili vize muafiyet anlaşması kapsamında 90 güne '
        'kadar vizesiz. Schengen DEĞİL — buradaki günler 90/180 sayılmaz.',
    driveEn:
        'Drive on the right. Zero alcohol limit strictly enforced. '
        'International Driving Permit recommended. '
        'Road quality is good in Baku and on main highways.',
    driveTr:
        'Sağdan trafik. Sıfır alkol sınırı kesinlikle uygulanır. '
        'Uluslararası sürücü belgesi önerilir. '
        'Bakü\'de ve ana karayollarında yol kalitesi iyidir.',
    culturalEn:
        'Azerbaijan blends Caspian modernity with ancient Silk Road heritage. '
        'Baku\'s UNESCO-listed Old City (İçərişəhər) with its medieval Maiden Tower '
        'sits beside futuristic Flame Towers and the Heydar Aliyev Cultural Centre '
        '(designed by Zaha Hadid). Strong linguistic and cultural kinship with Turkey '
        '— "one nation, two states" is the official motto of Turkish-Azerbaijani relations. '
        'The fire-worshipping Zoroastrian temple Ateshgah and the mud volcanoes '
        'of the Absheron Peninsula are unique natural wonders.',
    culturalTr:
        'Azerbaycan, Hazar modernliğini antik İpek Yolu mirasıyla harmanlıyor. '
        'Bakü\'nün UNESCO\'dan korunan eski şehri (İçərişəhər) ve Ortaçağ Kız Kulesi, '
        'fütüristik Alev Kuleleri ve Zaha Hadid tasarımlı Heydər Əliyev Kültür Merkezi '
        'ile iç içedir. Türkiye ile "tek millet, iki devlet" ilişkisi güçlüdür. '
        'Ateşgah ateş tapınağı ve çamur volkanları eşsiz doğal meraklardır.',
    practicalEn:
        'Azerbaijani Manat (AZN) is not freely convertible outside Azerbaijan. '
        'Exchange on arrival. Tipping 10 % in restaurants. '
        'Baku has excellent metro and taxi services (Bolt/Uber available).',
    practicalTr:
        'Azerbaycan Manatı (AZN) Azerbaycan dışında serbestçe dönüştürülmez. '
        'Varışta değiştirin. Restoranlarda %10 bahşiş. '
        'Bakü\'de metro ve taksi (Bolt/Uber) hizmetleri mükemmeldir.',
    bestTimeEn: 'April–June and September–October for pleasant temperatures. Summer is very hot.',
    bestTimeTr: 'Nisan–Haziran ve Eylül–Ekim için keyifli sıcaklıklar. Yaz çok sıcaktır.',
  ),

  // Iran — visa required (on arrival available at some airports)
  VisaCountry(
    code: 'IR',
    nameEn: 'Iran',
    nameTr: 'İran',
    flag: '🇮🇷',
    currency: 'ریال',
    currencyCode: 'IRR',
    speedUrban: 50,
    speedRural: 90,
    speedHighway: 110,
    alcoholBac: 0.00,
    emergencyGeneral: '115',
    emergencyPolice: '110',
    isSchengen: false,
    requiresVisaForTurkish: true,
    capitalEn: 'Tehran',
    capitalTr: 'Tahran',
    officialLanguage: 'Persian (Farsi)',
    visaEn:
        'Turkish citizens require a visa for Iran. A visa on arrival (VOA) is '
        'available at major international airports (Tehran IKA, Isfahan, Mashhad, Shiraz) '
        'for a 30-day stay, extendable once. Pre-arranged visas are recommended '
        'for overland crossings. Alcohol is strictly prohibited in Iran.',
    visaTr:
        'Türk vatandaşları İran için vize gerektirir. Büyük uluslararası havalimanlarında '
        '(Tahran İKA, İsfahan, Meşhed, Şiraz) 30 günlük kapıda vize (VOA) mevcuttur; '
        'bir kez uzatılabilir. Kara sınır geçişleri için önceden vize alınması önerilir. '
        'İran\'da alkol kesinlikle yasaktır.',
    driveEn:
        'Drive on the right. International Driving Permit required. '
        'Speed cameras are widespread. Fuel is very inexpensive. '
        'Women must wear the hijab (headscarf) in all public areas including in vehicles.',
    driveTr:
        'Sağdan trafik. Uluslararası sürücü belgesi zorunludur. '
        'Hız kameraları yaygındır. Yakıt çok ucuzdur. '
        'Kadınlar araçlar dahil tüm kamuya açık alanlarda başörtüsü takmak zorundadır.',
    culturalEn:
        'Iran is heir to one of the world\'s oldest and most sophisticated civilisations — '
        'the Persian Empire. UNESCO-listed Persepolis, Isfahan\'s Imam Square (Naqsh-e Jahan), '
        'Shiraz\'s Hafez Tomb and Yazd\'s ancient desert city are extraordinary. '
        'Persian poetry (Rumi, Hafez, Omar Khayyam), carpet weaving, miniature painting '
        'and architecture rank among humanity\'s greatest cultural achievements. '
        'Iranian hospitality (ta\'arof) is legendary.',
    culturalTr:
        'İran, dünyanın en eski ve en sofistike medeniyetlerinden birinin — '
        'Pers İmparatorluğu\'nun — varisidir. UNESCO listesindeki Persepolis, '
        'İsfahan\'ın İmam Meydanı, Şiraz\'ın Hafız Türbesi ve Yezd\'in antik çöl şehri '
        'olağanüstüdür. Farsça şiir (Rumi, Hafız, Ömer Hayyam), halı dokumacılığı, '
        'minyatür resim ve mimari insanlığın en büyük kültürel başarıları arasındadır. '
        'İran misafirperverliği (ta\'arof) efsanevidir.',
    practicalEn:
        'International credit cards do NOT work in Iran (US sanctions). '
        'Bring sufficient Euros or USD to exchange. '
        'The Iranian Rial is subject to official vs. market exchange rate discrepancies. '
        'Dress modestly — women must cover hair and wear long sleeves/trousers.',
    practicalTr:
        'Uluslararası kredi kartları İran\'da ÇALIŞMAZ (ABD yaptırımları). '
        'Bozdurma için yeterli Euro veya Dolar getirin. '
        'Mütevazı giyim zorunludur — kadınlar saçlarını örtmeli, uzun kollu '
        've uzun pantolon giymelidir.',
    bestTimeEn: 'October–April for most regions. Avoid midsummer heat (45°C+ in Isfahan).',
    bestTimeTr: 'Çoğu bölge için Ekim–Nisan. Yaz ortası sıcağından kaçının (İsfahan\'da 45°C+).',
  ),

  // USA — visa required (B-1/B-2)
  VisaCountry(
    code: 'US',
    nameEn: 'United States',
    nameTr: 'Amerika Birleşik Devletleri',
    flag: '🇺🇸',
    currency: '\$',
    currencyCode: 'USD',
    speedUrban: 72,
    speedRural: 104,
    speedHighway: 113,
    alcoholBac: 0.08,
    emergencyGeneral: '911',
    isSchengen: false,
    requiresVisaForTurkish: true,
    capitalEn: 'Washington D.C.',
    capitalTr: 'Washington D.C.',
    officialLanguage: 'English',
    visaEn:
        'Turkish citizens require a B-1/B-2 Tourist/Business visa — ESTA is not '
        'available for Turkish passport holders. Apply at the U.S. Embassy or '
        'Consulate well in advance (processing can take several weeks). '
        'A visa interview is mandatory.',
    visaTr:
        'Türk vatandaşları B-1/B-2 Turist/İş vizesi gerektirir — ESTA Türk pasaport '
        'sahiplerine açık değildir. ABD Büyükelçiliği veya Konsolosluğu\'na önceden '
        'başvurun (işlem birkaç hafta sürebilir). Vize mülakatı zorunludur.',
    driveEn:
        'Drive on the right. Speed limits are in mph (shown on signs). '
        'Each state has its own traffic laws. '
        'Turning right on a red light is generally permitted unless signed. '
        'School buses with flashing lights require ALL traffic to stop.',
    driveTr:
        'Sağdan trafik. Hız limitleri mph cinsindendir (tabelada gösterilir). '
        'Her eyalet kendi trafik yasalarına sahiptir. '
        'Kırmızı ışıkta sağa dönüş (yasaklanmadıkça) genellikle serbesttir. '
        'Yanıp sönen ışıklı okul otobüsleri için TÜM trafik durmalıdır.',
    culturalEn:
        'The United States is the world\'s dominant cultural superpower — from '
        'Hollywood and jazz to Silicon Valley and NASA. New York\'s skyline, '
        'the Grand Canyon, Yellowstone, the Smithsonian museums, and the national '
        'parks of the American West are iconic. American cuisine reflects a vast '
        'melting pot — BBQ, Tex-Mex, New England seafood, Southern soul food. '
        'The country\'s democratic ideals, expressed through the Declaration of '
        'Independence and Constitution, shaped the modern world.',
    culturalTr:
        'Amerika Birleşik Devletleri, Hollywood ve caz\'dan Silikon Vadisi ve '
        'NASA\'ya uzanan dünyanın baskın kültürel süper gücüdür. New York\'un '
        'ufuk çizgisi, Grand Canyon, Yellowstone, Smithsonian müzeleri ve '
        'Amerikan Batısı\'nın milli parkları efsanevidir. ABD mutfağı dev bir '
        'eritme potasını yansıtır: BBQ, Tex-Mex, New England deniz ürünleri, '
        'Güney soul food.',
    practicalEn:
        'USD accepted everywhere. Tipping is essential — 18–20 % at restaurants, '
        '15 % taxis, \$1–2 per bag at hotels. Sales tax is added at checkout (varies by state). '
        'Health insurance is critical — medical costs are extremely high.',
    practicalTr:
        'USD her yerde kabul edilir. Bahşiş zorunludur — restoranlarda %18–20, '
        'taksilerde %15, otellerde çanta başına 1–2 \$. '
        'Satış vergisi kasada eklenir (eyalete göre değişir). '
        'Sağlık sigortası kritik — tıbbi masraflar aşırı yüksektir.',
    bestTimeEn: 'Varies hugely by region. New York/East Coast: May–June and Sept. Florida: Nov–Apr. West Coast: year-round.',
    bestTimeTr: 'Bölgeye göre çok farklılık gösterir. New York: Mayıs–Haziran ve Eylül. Florida: Kasım–Nisan.',
  ),

  // UAE — visa-free 30 days
  VisaCountry(
    code: 'AE',
    nameEn: 'United Arab Emirates',
    nameTr: 'Birleşik Arap Emirlikleri',
    flag: '🇦🇪',
    currency: 'د.إ',
    currencyCode: 'AED',
    speedUrban: 80,
    speedRural: 110,
    speedHighway: 140,
    alcoholBac: 0.00,
    emergencyGeneral: '999',
    emergencyPolice: '999',
    emergencyAmbulance: '998',
    isSchengen: false,
    requiresVisaForTurkish: false,
    capitalEn: 'Abu Dhabi',
    capitalTr: 'Abu Dabi',
    officialLanguage: 'Arabic',
    visaEn:
        'Visa-free for Turkish citizens for 30 days under the bilateral agreement. '
        'Extension possible through the General Directorate of Residency and '
        'Foreigners Affairs. NOT in Schengen — days here do not count toward 90/180.',
    visaTr:
        'Türk vatandaşları için ikili anlaşma kapsamında 30 günlük vizesiz giriş. '
        'İkamet ve Yabancılar İdaresi aracılığıyla uzatma mümkündür. '
        'Schengen DEĞİL — buradaki günler 90/180\'e sayılmaz.',
    driveEn:
        'Drive on the right. Zero alcohol limit — strictly enforced. '
        'Speed cameras are ubiquitous and fines are severe. '
        'Salik toll system on Dubai roads (electronic, registered automatically). '
        'Fines for parking violations are heavy.',
    driveTr:
        'Sağdan trafik. Sıfır alkol sınırı — katı biçimde uygulanır. '
        'Hız kameraları her yerde ve para cezaları ağırdır. '
        'Dubai yollarında Salik sistemi (elektronik, otomatik kayıt). '
        'Park ihlali cezaları ağırdır.',
    culturalEn:
        'The UAE — particularly Dubai and Abu Dhabi — represents the ultimate '
        'expression of 21st-century ambition: the Burj Khalifa (world\'s tallest building), '
        'Palm Jumeirah, the Louvre Abu Dhabi and the Sheikh Zayed Grand Mosque '
        'are modern architectural wonders. The UAE has transformed itself from a '
        'pearl-diving backwater to a global hub for finance, tourism and aviation '
        'in just 50 years. Dubai\'s Souks, the gold and spice markets, connect '
        'this futuristic state to its traditional Bedouin roots.',
    culturalTr:
        'BAE — özellikle Dubai ve Abu Dabi — 21. yüzyılın tutkusunun en '
        'yoğun ifadesini temsil eder: Burj Halife (dünyanın en yüksek binası), '
        'Palm Jumeirah, Abu Dabi Louvre\'u ve Şeyh Zayed Büyük Camii modern '
        'mimari harikalar olarak öne çıkar. BAE, 50 yılda inci avcılığı yapılan '
        'küçük bir körfez bölgesinden küresel bir finans, turizm ve havacılık merkezine '
        'dönüşmüştür.',
    practicalEn:
        'AED pegged to USD (1 USD ≈ 3.67 AED). Avoid public displays of affection. '
        'Dress modestly outside hotels and malls. Ramadan: no eating or drinking '
        'in public during daylight. English is widely spoken.',
    practicalTr:
        'AED, USD\'ye sabitlenmiştir (1 USD ≈ 3.67 AED). Kamuya açık alanlarda '
        'sevgi gösterilerinden kaçının. Otel ve AVM dışında mütevazı giyim. '
        'Ramazan: gündüzleri kamuya açık yerlerde yeme içme yasaktır. '
        'İngilizce yaygın olarak konuşulur.',
    bestTimeEn: 'November–March for outdoor activities. Summer (June–Sept) is extremely hot (45°C+).',
    bestTimeTr: 'Kasım–Mart açık hava etkinlikleri için. Yaz (Haziran–Eylül) son derece sıcak (45°C+).',
  ),

  // Egypt — e-visa or visa on arrival
  VisaCountry(
    code: 'EG',
    nameEn: 'Egypt',
    nameTr: 'Mısır',
    flag: '🇪🇬',
    currency: '£',
    currencyCode: 'EGP',
    speedUrban: 60,
    speedRural: 90,
    speedHighway: 120,
    alcoholBac: 0.00,
    emergencyGeneral: '123',
    isSchengen: false,
    requiresVisaForTurkish: true,
    capitalEn: 'Cairo',
    capitalTr: 'Kahire',
    officialLanguage: 'Arabic',
    visaEn:
        'Turkish citizens require a visa for Egypt. An e-Visa is available online '
        '(evisa.visa.gov.eg) for 30 days, or a visa on arrival (US\$25) is available '
        'at major international airports (Cairo, Hurghada, Sharm el-Sheikh). '
        'NOT in Schengen — days here do not count toward 90/180.',
    visaTr:
        'Türk vatandaşları Mısır için vize gerektirir. Online e-Vize '
        '(evisa.visa.gov.eg) 30 günlük olarak mevcuttur; büyük uluslararası '
        'havalimanlarında (Kahire, Hurgada, Şarm el-Şeyh) kapıda vize (25 \$) '
        'alınabilir. Schengen DEĞİL — buradaki günler 90/180\'e sayılmaz.',
    driveEn:
        'Drive on the right. Avoid driving at night outside cities — '
        'road conditions and lighting are unreliable. '
        'Keep car doors locked in traffic. Carry cash for tolls.',
    driveTr:
        'Sağdan trafik. Şehir dışında gece sürüşünden kaçının — '
        'yol koşulları ve aydınlatma güvenilir değildir. '
        'Trafikte araç kapılarını kilitli tutun. Geçiş ücretleri için nakit bulundurun.',
    culturalEn:
        'Egypt is the cradle of one of humanity\'s first and most enduring civilisations, '
        'spanning 5,000 years of recorded history. The Great Pyramids of Giza — the '
        'sole surviving Wonder of the Ancient World — stand alongside the Sphinx, '
        'the Karnak Temple complex, Luxor\'s Valley of the Kings and the '
        'Egyptian Museum\'s 120,000 artefacts. The Nile, the world\'s longest river, '
        'nurtured this extraordinary civilisation. Cairo is the Arab world\'s '
        'largest and most vibrant city.',
    culturalTr:
        'Mısır, 5.000 yıllık kayıtlı tarihiyle insanlığın ilk ve en kalıcı '
        'uygarlıklarından birinin beşiğidir. Antik Dünyanın Yedi Harikası\'ndan '
        'günümüze ulaşan tek yapı olan Giza Büyük Piramitleri, Sfenks, Karnak '
        'Tapınak Kompleksi, Luksor\'un Krallar Vadisi ve Mısır Müzesi\'nin '
        '120.000 eseriyle birlikte durur. Nil — dünyanın en uzun nehri — '
        'bu olağanüstü medeniyeti besledi.',
    practicalEn:
        'Egyptian Pound (EGP) — exchange at official bureaux for best rates. '
        'Haggling is expected in bazaars. Tipping (baksheesh) is a social norm. '
        'Cairo traffic is chaotic — use ride-hailing apps (Uber, Careem). '
        'Red Sea resorts (Hurghada, Sharm) are tourist-friendly all-inclusive zones.',
    practicalTr:
        'Mısır Poundu (EGP) — en iyi kur için resmi bürolarda değiştirin. '
        'Çarşılarda pazarlık beklenmektedir. Bahşiş (baksheesh) sosyal bir normdur. '
        'Kahire trafiği kaotiktir — Uber veya Careem kullanın. '
        'Kızıldeniz tatil beldeleri (Hurgada, Şarm) turist dostu her şey dahil bölgelerdir.',
    bestTimeEn: 'October–April for sightseeing. May–September is extremely hot inland (45°C+).',
    bestTimeTr: 'Ekim–Nisan geziler için. Mayıs–Eylül iç bölgelerde son derece sıcak (45°C+).',
  ),

  // Thailand — visa-free 30 days
  VisaCountry(
    code: 'TH',
    nameEn: 'Thailand',
    nameTr: 'Tayland',
    flag: '🇹🇭',
    currency: '฿',
    currencyCode: 'THB',
    speedUrban: 80,
    speedRural: 90,
    speedHighway: 120,
    alcoholBac: 0.05,
    emergencyGeneral: '191',
    emergencyAmbulance: '1669',
    isSchengen: false,
    requiresVisaForTurkish: false,
    capitalEn: 'Bangkok',
    capitalTr: 'Bangkok',
    officialLanguage: 'Thai',
    visaEn:
        'Visa-free for Turkish citizens for 30 days. NOT in Schengen — days '
        'here do not count toward your Schengen 90/180.',
    visaTr:
        'Türk vatandaşları için 30 günlük vizesiz giriş. Schengen DEĞİL — '
        'buradaki günler 90/180\'e sayılmaz.',
    driveEn:
        'Drive on the LEFT. International Driving Permit required. '
        'Traffic can be chaotic in Bangkok. Motorcycles ubiquitous — be alert. '
        'Tolls on expressways in Bangkok.',
    driveTr:
        'SOLDAN trafik. Uluslararası sürücü belgesi zorunludur. '
        'Bangkok\'ta trafik kaotik olabilir. Motosikletler her yerde — dikkatli olun. '
        'Bangkok\'taki ekspres yollarda ücret var.',
    culturalEn:
        'Thailand — "Land of Smiles" — is Southeast Asia\'s most-visited nation. '
        'Bangkok\'s ornate Wat Pho and Wat Arun temples, Chiang Mai\'s ancient walled '
        'city, Ayutthaya\'s ruined Kingdom (UNESCO) and the turquoise waters of '
        'Koh Samui and Phi Phi Islands define the country\'s extraordinary appeal. '
        'Thai cuisine — pad thai, green curry, tom yum, mango sticky rice — '
        'is among the world\'s most beloved. The Thai royal family is deeply revered '
        '— treat all royal imagery with utmost respect.',
    culturalTr:
        '"Gülümsemeler Ülkesi" Tayland, Güneydoğu Asya\'nın en çok ziyaret edilen '
        'ülkesidir. Bangkok\'un görkemli Wat Pho ve Wat Arun tapınakları, Chiang '
        'Mai\'nin antik surlu şehri, Ayutthaya\'nın harabe Krallığı (UNESCO) ve '
        'Ko Samui\'nin turkuaz suları ülkenin olağanüstü cazibesini tanımlar. '
        'Pad thai, yeşil köri, tom yum ve mango yapışkan pirinci ile Tayland mutfağı '
        'dünyanın en sevilen yemek kültürlerinden biridir.',
    practicalEn:
        'Thai Baht (THB). Bargaining in markets is expected. Dress modestly at temples '
        '(cover shoulders and knees). Remove shoes before entering temples and '
        'some shops. ATMs are widely available; international fees apply.',
    practicalTr:
        'Tayland Bahtı (THB). Pazarlarda pazarlık beklenmektedir. Tapınaklarda '
        'örtünün (omuzlar ve dizler kapalı). Tapınaklara ve bazı dükkânlara '
        'girerken ayakkabıları çıkarın.',
    bestTimeEn: 'November–February (cool season). Avoid May–October (heavy monsoon rains).',
    bestTimeTr: 'Kasım–Şubat (serin sezon). Mayıs–Ekim\'den kaçının (yoğun muson yağmurları).',
  ),

  // Russia — visa required
  VisaCountry(
    code: 'RU',
    nameEn: 'Russia',
    nameTr: 'Rusya',
    flag: '🇷🇺',
    currency: '₽',
    currencyCode: 'RUB',
    speedUrban: 60,
    speedRural: 90,
    speedHighway: 110,
    alcoholBac: 0.03,
    emergencyGeneral: '112',
    emergencyPolice: '102',
    emergencyAmbulance: '103',
    isSchengen: false,
    requiresVisaForTurkish: true,
    capitalEn: 'Moscow',
    capitalTr: 'Moskova',
    officialLanguage: 'Russian',
    visaEn:
        'Turkish citizens require a Russian visa. As of 2024, e-Visa is available '
        'for 16-day stays for Turkish citizens (apply at evisa.kdmid.ru). '
        'Note: the geopolitical situation following the 2022 Ukraine conflict '
        'has significantly affected international banking and travel logistics. '
        'Verify current visa requirements and travel advisories before planning.',
    visaTr:
        'Türk vatandaşları Rusya vizesi gerektirir. 2024 itibarıyla e-Vize '
        '(evisa.kdmid.ru) 16 günlük kalış için Türk vatandaşlarına açıktır. '
        'Not: 2022 Ukrayna çatışmasının ardından uluslararası bankacılık '
        've seyahat lojistiği önemli ölçüde etkilenmiştir. '
        'Seyahat planlamadan önce güncel vize şartlarını ve seyahat uyarılarını doğrulayın.',
    driveEn:
        'Drive on the right. International Driving Permit required. '
        'Winter driving conditions can be severe — winter tyres mandatory Nov–Mar. '
        'Note: many Western navigation apps and payment systems may not function normally.',
    driveTr:
        'Sağdan trafik. Uluslararası sürücü belgesi zorunludur. '
        'Kış sürüş koşulları ağır olabilir — Kasım–Mart kış lastiği zorunludur. '
        'Not: Pek çok Batılı navigasyon uygulaması ve ödeme sistemi normal çalışmayabilir.',
    culturalEn:
        'Russia\'s cultural legacy is among the world\'s deepest: Tchaikovsky, '
        'Dostoevsky, Tolstoy, Chekhov, Pushkin, Stravinsky, Kandinsky and '
        'the Bolshoi Ballet represent the pinnacle of European artistic achievement. '
        'Moscow\'s Red Square, St. Basil\'s Cathedral, the Kremlin, '
        'St. Petersburg\'s Hermitage Museum (world\'s largest art museum) '
        'and the Trans-Siberian Railway are iconic. The Russian Orthodox Church '
        'and its magnificent cathedral architecture are central to national identity.',
    culturalTr:
        'Rusya\'nın kültürel mirası dünyanın en derinlerindendir: Çaykovski, '
        'Dostoyevski, Tolstoy, Çehov, Puşkin, Stravinski, Kandinski ve '
        'Bolşoy Balesi Avrupa sanatsal başarısının zirvesini temsil eder. '
        'Moskova\'nın Kızıl Meydanı, Aziz Basil Katedrali, Kremlin, '
        'St. Petersburg\'un Hermitage Müzesi (dünyanın en büyük sanat müzesi) '
        've Trans-Sibirya Demiryolu efsanevidir.',
    practicalEn:
        'Russian Ruble (RUB). International credit cards largely non-functional '
        'due to sanctions. Bring cash (USD/EUR). MIR cards available locally. '
        'Check your government\'s travel advisory before booking.',
    practicalTr:
        'Rus Rublesi (RUB). Yaptırımlar nedeniyle uluslararası kredi kartları büyük '
        'ölçüde çalışmamaktadır. Nakit (USD/EUR) getirin. MIR kartı yerel olarak '
        'mevcuttur. Rezervasyon yapmadan önce hükümetinizin seyahat tavsiyesini kontrol edin.',
    bestTimeEn: 'May–August for Moscow/St. Petersburg. December–February for winter landscapes.',
    bestTimeTr: 'Mayıs–Ağustos Moskova/St. Petersburg için. Aralık–Şubat kış manzaraları için.',
  ),

  // Japan — visa required
  VisaCountry(
    code: 'JP',
    nameEn: 'Japan',
    nameTr: 'Japonya',
    flag: '🇯🇵',
    currency: '¥',
    currencyCode: 'JPY',
    speedUrban: 60,
    speedRural: 60,
    speedHighway: 100,
    alcoholBac: 0.03,
    emergencyGeneral: '110',
    emergencyAmbulance: '119',
    isSchengen: false,
    requiresVisaForTurkish: true,
    capitalEn: 'Tokyo',
    capitalTr: 'Tokyo',
    officialLanguage: 'Japanese',
    visaEn:
        'Turkish citizens require a tourist visa for Japan — apply at the Japanese '
        'Consulate or Embassy (typically 15-day single-entry or 90-day multiple-entry). '
        'Processing takes approximately 5 business days. Provide proof of financial '
        'means, accommodation bookings and a detailed itinerary.',
    visaTr:
        'Türk vatandaşları Japonya için turist vizesi gerektirir — Japon Konsolosluğu '
        'veya Büyükelçiliği\'ne başvurun (genellikle 15 günlük tek giriş veya '
        '90 günlük çoklu giriş). İşlem yaklaşık 5 iş günü sürer. '
        'Mali kaynak kanıtı, konaklama rezervasyonu ve ayrıntılı güzergah sunun.',
    driveEn:
        'Drive on the LEFT. International Driving Permit (IDP) mandatory — '
        'Japanese driving licence is required after 1 year. '
        'Expressways are toll-based. Speed cameras are common. '
        'All motorists must carry compulsory insurance (jibaiseki).',
    driveTr:
        'SOLDAN trafik. Uluslararası Sürücü Belgesi (ISB) zorunlu — '
        '1 yıldan sonra Japon sürücü belgesi gerekir. '
        'Ekspres yollar ücretlidir. Hız kameraları yaygındır. '
        'Tüm sürücüler zorunlu sigorta (jibaiseki) taşımalıdır.',
    culturalEn:
        'Japan is a civilisation of breathtaking contrasts — ancient Shinto shrines '
        'and Buddhist temples alongside the hypermodern neon-lit streets of Shibuya '
        'and Akihabara. Kyoto\'s 17 UNESCO World Heritage Sites, Mount Fuji, '
        'the Hiroshima Peace Memorial, and cherry blossom (sakura) season '
        'are among the world\'s most profound travel experiences. Japanese aesthetics '
        '— ikebana, zen gardens, origami, ceramics, calligraphy — and cuisine '
        '(sushi, ramen, tempura, wagyu beef) have had an outsized global influence. '
        'Japan has the world\'s highest density of Michelin-starred restaurants.',
    culturalTr:
        'Japonya, antik Şinto tapınakları ve Budist manastırlarının Shibuya ve '
        'Akihabara\'nın hiper modern neon aydınlatmalı sokakları ile iç içe '
        'geçtiği nefes kesen zıtlıkların medeniyetidir. Kyoto\'nun 17 UNESCO Dünya '
        'Mirası, Fuji Dağı, Hiroşima Barış Anıtı ve kiraz çiçeği (sakura) sezonu '
        'dünyanın en derin seyahat deneyimleri arasındadır. '
        'Ikebana, zen bahçeleri, origami, seramik ve hat sanatıyla Japon estetiği '
        've sushi, ramen, tempura, wagyu bifteği ile Japon mutfağı küresel etkisini sürdürür.',
    practicalEn:
        'Japan is predominantly cash-based — carry Yen (JPY). 7-Eleven ATMs accept '
        'international cards. Tipping is NOT customary and can be considered rude. '
        'IC cards (Suica/Pasmo) for public transport are essential in Tokyo. '
        'JR Pass offers unlimited bullet train (Shinkansen) travel.',
    practicalTr:
        'Japonya büyük ölçüde nakit bazlıdır — Yen (JPY) taşıyın. '
        '7-Eleven ATM\'leri uluslararası kartları kabul eder. '
        'Bahşiş teamülde YOKTUR ve kaba sayılabilir. '
        'Tokyo\'da toplu taşıma için IC kartlar (Suica/Pasmo) şarttır. '
        'JR Pass sınırsız Shinkansen seyahati sunar.',
    bestTimeEn: 'March–May (cherry blossoms) and October–November (autumn foliage). Avoid July–August (hot, humid, typhoon season).',
    bestTimeTr: 'Mart–Mayıs (kiraz çiçekleri) ve Ekim–Kasım (sonbahar yaprakları). Temmuz–Ağustos\'tan kaçının (sıcak, nemli, tayfun sezonu).',
  ),

  // Indonesia — visa-free 30 days
  VisaCountry(
    code: 'ID',
    nameEn: 'Indonesia',
    nameTr: 'Endonezya',
    flag: '🇮🇩',
    currency: 'Rp',
    currencyCode: 'IDR',
    speedUrban: 50,
    speedRural: 80,
    speedHighway: 100,
    alcoholBac: 0.00,
    emergencyGeneral: '112',
    emergencyPolice: '110',
    emergencyAmbulance: '118',
    isSchengen: false,
    requiresVisaForTurkish: false,
    capitalEn: 'Jakarta',
    capitalTr: 'Cakarta',
    officialLanguage: 'Indonesian (Bahasa Indonesia)',
    visaEn:
        'Visa-free for Turkish citizens for up to 30 days under the bilateral '
        'visa exemption agreement. NOT in Schengen — days here do not count '
        'toward your Schengen 90/180.',
    visaTr:
        'Türk vatandaşları için ikili anlaşma kapsamında 30 güne kadar vizesiz. '
        'Schengen DEĞİL — buradaki günler 90/180\'e sayılmaz.',
    driveEn:
        'Drive on the LEFT. International Driving Permit required. '
        'Traffic in Jakarta and Bali is extremely congested. '
        'Motorbike taxis (ojek) via apps (Gojek, Grab) are often fastest in cities.',
    driveTr:
        'SOLDAN trafik. Uluslararası sürücü belgesi zorunludur. '
        'Cakarta ve Bali\'de trafik son derece yoğundur. '
        'Şehirlerde uygulama üzerinden motosiklet taksiler (Gojek, Grab) '
        'genellikle en hızlısıdır.',
    culturalEn:
        'Indonesia is the world\'s largest archipelago (17,000+ islands) and '
        'home to the world\'s 4th largest population. Bali\'s Hindu temples, '
        'rice terraces and surf beaches; Yogyakarta\'s Borobudur (world\'s largest '
        'Buddhist monument, UNESCO) and Prambanan temples; Komodo National Park\'s '
        'ancient dragons — Indonesia\'s diversity is staggering. '
        'Indonesian cuisine (nasi goreng, satay, rendang) reflects the spice-trade '
        'heritage that once made the archipelago the centre of the world.',
    culturalTr:
        'Endonezya dünyanın en büyük takımadası (17.000+ ada) ve dünyanın '
        '4. en büyük nüfusuna ev sahipliğidir. Bali\'nin Hindu tapınakları, '
        'pirinç tarım sekileri ve sörf plajları; Yogyakarta\'nın Borobudur\'u '
        '(dünyanın en büyük Budist anıtı, UNESCO) ve Prambanan tapınakları; '
        'Komodo Milli Parkı\'nın kadim ejderhaları — Endonezya\'nın çeşitliliği '
        'şaşırtıcıdır. Nasi goreng, satay ve rendang ile Endonezya mutfağı '
        'takımadayı zamanında dünyanın merkezi yapan baharat ticaret mirasını yansıtır.',
    practicalEn:
        'Indonesian Rupiah (IDR) — small denominations useful for local markets. '
        'Bargaining expected in markets. Respect local customs at temples '
        '(cover legs and shoulders). Avoid tap water — drink bottled or filtered.',
    practicalTr:
        'Endonezya Rupisi (IDR) — yerel pazarlar için küçük kupürler kullanışlıdır. '
        'Pazarlık beklenmektedir. Tapınaklarda yerel törenlere saygı gösterin '
        '(bacakları ve omuzları örtün). Musluk suyundan kaçının — şişe veya '
        'filtre edilmiş su için.',
    bestTimeEn: 'May–September for Bali and most islands. Borneo and Papua are year-round.',
    bestTimeTr: 'Mayıs–Eylül Bali ve çoğu ada için. Borneo ve Papua yıl boyu.',
  ),

  // Australia — visa required
  VisaCountry(
    code: 'AU',
    nameEn: 'Australia',
    nameTr: 'Avustralya',
    flag: '🇦🇺',
    currency: 'A\$',
    currencyCode: 'AUD',
    speedUrban: 50,
    speedRural: 100,
    speedHighway: 110,
    alcoholBac: 0.05,
    emergencyGeneral: '000',
    isSchengen: false,
    requiresVisaForTurkish: true,
    capitalEn: 'Canberra',
    capitalTr: 'Kanberra',
    officialLanguage: 'English',
    visaEn:
        'Turkish citizens require an Australian tourist visa (Visitor Visa subclass 600). '
        'Apply online via the ImmiAccount portal (immi.homeaffairs.gov.au). '
        'Processing typically takes 20–30 days; longer during peak periods. '
        'ETA (Electronic Travel Authority) is not available for Turkish passport holders.',
    visaTr:
        'Türk vatandaşları Avustralya turist vizesi (Ziyaretçi Vizesi alt sınıfı 600) '
        'gerektirir. ImmiAccount portalı üzerinden online başvurun '
        '(immi.homeaffairs.gov.au). İşlem genellikle 20–30 gün; yoğun dönemlerde uzun. '
        'ETA (Elektronik Seyahat Yetkisi) Türk pasaport sahiplerine açık değildir.',
    driveEn:
        'Drive on the LEFT. Speed limits strictly enforced with heavy fines. '
        'Kangaroos and other wildlife on roads at dawn/dusk — drive cautiously. '
        'Distances are vast — plan fuel stops carefully in outback regions.',
    driveTr:
        'SOLDAN trafik. Hız sınırları ağır para cezalarıyla sıkı biçimde uygulanır. '
        'Şafak/alacakaranlıkta yolda kanguru ve yaban hayvanı — dikkatli sürün. '
        'Mesafeler çok geniş — İç bölgelerde yakıt molalarını dikkatli planlayın.',
    culturalEn:
        'Australia\'s Aboriginal and Torres Strait Islander peoples maintain the '
        'world\'s oldest continuous culture — over 65,000 years old. '
        'The Sydney Opera House, the Great Barrier Reef (UNESCO), Uluru-Kata Tjuta '
        '(UNESCO), the Daintree Rainforest and the Kimberley\'s ancient rock art '
        'make Australia one of the world\'s most naturally and culturally diverse nations. '
        'Australian cuisine reflects a vibrant multicultural society. '
        'The country\'s outdoor lifestyle, wildlife (kangaroos, koalas, platypus) '
        'and "no worries" national character are globally recognised.',
    culturalTr:
        'Avustralya\'nın Aborijin ve Torres Strait Adalı halkları 65.000 yılı '
        'aşkın en eski sürekli kültürü sürdürmektedir. Sydney Opera Binası, '
        'Büyük Bariyer Resifi (UNESCO), Uluru-Kata Tjuta (UNESCO), Daintree '
        'Yağmur Ormanı ve Kimberley\'in antik kaya sanatı Avustralya\'yı '
        'dünyanın en çeşitli ülkelerinden biri yapar. '
        'Kangurular, koalalar ve plaipuslarla Avustralya\'nın açık hava yaşam tarzı '
        've "no worries" ulusal karakteri dünyaca tanınmaktadır.',
    practicalEn:
        'Australian Dollar (AUD). Tipping not mandatory but appreciated (10 % at restaurants). '
        'Sun protection essential — UV index is extremely high. '
        'Travel insurance strongly recommended. Health care is excellent but expensive for visitors.',
    practicalTr:
        'Avustralya Doları (AUD). Bahşiş zorunlu değil ama takdirle karşılanır '
        '(%10 restoranlarda). Güneş koruması şart — UV indeksi son derece yüksek. '
        'Seyahat sigortası şiddetle önerilir. Sağlık hizmetleri ziyaretçiler için pahalıdır.',
    bestTimeEn: 'September–November (spring) and March–May (autumn) for most of Australia. Avoid December–February (extreme heat in interior).',
    bestTimeTr: 'Eylül–Kasım (ilkbahar) ve Mart–Mayıs (sonbahar) çoğu bölge için. Aralık–Şubat\'tan kaçının (iç bölgelerde aşırı sıcak).',
  ),

  // New Zealand — NZeTA required
  VisaCountry(
    code: 'NZ',
    nameEn: 'New Zealand',
    nameTr: 'Yeni Zelanda',
    flag: '🇳🇿',
    currency: 'NZ\$',
    currencyCode: 'NZD',
    speedUrban: 50,
    speedRural: 100,
    speedHighway: 100,
    alcoholBac: 0.05,
    emergencyGeneral: '111',
    isSchengen: false,
    requiresVisaForTurkish: true,
    capitalEn: 'Wellington',
    capitalTr: 'Wellington',
    officialLanguage: 'English/Māori/NZ Sign Language',
    visaEn:
        'Turkish citizens require a New Zealand Electronic Travel Authority (NZeTA) '
        'or a tourist visa (Visitor Visa). Apply for NZeTA online (immigration.govt.nz) — '
        'costs NZ\$17 plus International Visitor Conservation and Tourism Levy (NZ\$35). '
        'Processing usually within 72 hours but can take longer.',
    visaTr:
        'Türk vatandaşları Yeni Zelanda Elektronik Seyahat Yetkisi (NZeTA) '
        'veya turist vizesi (Ziyaretçi Vizesi) gerektirir. '
        'NZeTA için online başvurun (immigration.govt.nz) — NZ\$17 artı '
        'Uluslararası Ziyaretçi Koruma ve Turizm Katkı Payı (NZ\$35). '
        'İşlem genellikle 72 saat içinde; bazen daha uzun sürebilir.',
    driveEn:
        'Drive on the LEFT. Seat belts compulsory for all. '
        'Speed cameras widespread. Roads are narrow and winding in rural areas — '
        'drive to conditions. Livestock on roads is common in rural New Zealand.',
    driveTr:
        'SOLDAN trafik. Tüm yolcular için emniyet kemeri zorunludur. '
        'Hız kameraları yaygındır. Kırsal alanlarda yollar dar ve virajlıdır — '
        'koşullara göre sürün. Kırsal Yeni Zelanda\'da yolda hayvan sürülerine dikkat.',
    culturalEn:
        'New Zealand\'s Māori culture is a living, vibrant civilisation — the haka, '
        'wharenui (meeting houses) and tā moko (tattoo) are world-recognised. '
        'The country\'s landscapes (used as Middle-Earth in the Lord of the Rings films), '
        'geothermal wonders of Rotorua, fjords of Milford Sound, and '
        'Tongariro National Park (UNESCO, dual World Heritage) are spectacular. '
        'New Zealand was the first country to give women the right to vote (1893). '
        'Adventure tourism (bungy jumping, skydiving, heli-skiing) was pioneered here.',
    culturalTr:
        'Yeni Zelanda\'nın Maori kültürü canlı, dinamik bir uygarlıktır — haka dansı, '
        'wharenui (toplantı evleri) ve tā moko (dövme) dünyaca tanınır. '
        'Yüzüklerin Efendisi filmlerinde Orta Dünya olarak kullanılan manzaralar, '
        'Rotorua\'nın jeotermal harikaları, Milford Sound\'un fiyortları ve '
        'Tongariro Milli Parkı (UNESCO) görkemlidir. '
        'Yeni Zelanda kadınlara oy hakkı veren ilk ülkedir (1893).',
    practicalEn:
        'New Zealand Dollar (NZD). Tipping not customary but appreciated. '
        'Biosecurity is extremely strict — declare ALL food, plant and animal products. '
        'Fines for biosecurity violations are severe. Sun protection essential (thin ozone layer).',
    practicalTr:
        'Yeni Zelanda Doları (NZD). Bahşiş geleneksel değil ama takdir görür. '
        'Biyogüvenlik son derece sıkıdır — TÜM gıda, bitki ve hayvan ürünlerini beyan edin. '
        'Biyogüvenlik ihlalleri için para cezaları ağırdır. Güneş koruması şart (ince ozon tabakası).',
    bestTimeEn: 'December–February (southern hemisphere summer) for beaches. June–August for skiing (Queenstown, Wānaka).',
    bestTimeTr: 'Aralık–Şubat (güney yarımküre yazı) plajlar için. Haziran–Ağustos kayak için (Queenstown, Wānaka).',
  ),
];

// ── Builders ─────────────────────────────────────────────────────────────────

VisaCountry _schengen(
  String code,
  String en,
  String tr,
  String flag,
  String cur,
  String curCode,
  int u,
  int r,
  int h,
  double bac, {
  bool vignette = false,
  bool left = false,
  bool note2025 = false,
  String? capital,
  String? capitalTr,
  String? lang,
  String? cultural,
  String? culturalTr,
  String? practical,
  String? practicalTr,
  String? bestTime,
  String? bestTimeTr,
}) {
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
    requiresVisaForTurkish: true,
    capitalEn: capital,
    capitalTr: capitalTr,
    officialLanguage: lang,
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
    culturalEn: cultural,
    culturalTr: culturalTr,
    practicalEn: practical,
    practicalTr: practicalTr,
    bestTimeEn: bestTime,
    bestTimeTr: bestTimeTr,
  );
}

VisaCountry _euNonSchengen(
  String code,
  String en,
  String tr,
  String flag,
  String cur,
  String curCode,
  int u,
  int r,
  int h,
  double bac, {
  bool left = false,
  String? capital,
  String? capitalTr,
  String? lang,
}) {
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
    requiresVisaForTurkish: true,
    capitalEn: capital,
    capitalTr: capitalTr,
    officialLanguage: lang,
    visaEn:
        'EU member but NOT in the Schengen Area. Turkish citizens must obtain a '
        'separate national visa — days here do NOT count toward the Schengen 90/180. '
        'Apply at the embassy or consulate well in advance.',
    visaTr:
        'AB üyesi ancak Schengen DEĞİL. Türk vatandaşları ayrı bir ulusal vize '
        'almalıdır — buradaki günler Schengen 90/180\'e SAYILMAZ. '
        'Büyükelçilik veya konsolosluğa önceden başvurun.',
    driveEn: left ? 'Drive on the LEFT. Carry Green Card vehicle insurance.' : 'Drive on the right. Carry Green Card vehicle insurance.',
    driveTr: left ? 'SOLDAN trafik. Yeşil Kart araç sigortası bulundurun.' : 'Sağdan trafik. Yeşil Kart araç sigortası bulundurun.',
  );
}

VisaCountry _visaFree(
  String code,
  String en,
  String tr,
  String flag,
  String cur,
  String curCode,
  int u,
  int r,
  int h,
  double bac, {
  String? capital,
  String? capitalTr,
  String? lang,
}) {
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
    requiresVisaForTurkish: false,
    capitalEn: capital,
    capitalTr: capitalTr,
    officialLanguage: lang,
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
