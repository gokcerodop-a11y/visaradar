# VisaRadar (VisaRadar Travel)

Premium global vize / sınır / Schengen kalış takip uygulaması (AI destekli). Telegram botu çalışıyor.

**App Store durumu (2026-07-29):** v1.2.0+6 **APPROVED** (mağaza yayını bekleniyor). v1.3.0+7 — **TÜM 11 TEST TAMAMLANDI** + yeni özellikler (commit 736a68b, telefonda).

**Güvenlik Durumu (2026-07-29 — 30/30 ONAYLANDI):**
- Worker: KVKK consent, 6 güvenlik header, sanitize, Apple JWS doğrulama (ES256 x5c), TTS rate limit, 2 MB body, imageMediaType allowlist, role validation, KV cache temizleme
- Flutter: Keychain txId, premium gate'ler, AppLifecycle ekran gizleme, Random.secure(), jailbreak hard-block, gerçek expiresDate
- Worker deploy: `3497463f-aad2-418a-9408-2a206edeef50` (free-trial bypass + Sonnet 5)

**Fonksiyonel Düzeltmeler (2026-07-29):**
- KRİTİK: `/paywall` → `/subscription` (Tax-Free + Güvenlik Tarayıcı premium butonu)
- KRİTİK: KVKK ConsentGate akışa bağlandı — onboarding → consent → tur → radar
- KRİTİK: LocationProofService.recordCurrentLocation() radar GPS hook'una bağlandı
- YÜKSEK: AI Asistan history kırpma (son 11 mesaj → Worker 12 limit)
- YÜKSEK: SOS sireni arka plan: Info.plist UIBackgroundModes=audio + resume hook
- YÜKSEK: TravelLogService.updateFromPosition() radar GPS hook'una bağlandı
- ORTA: AnthropicProxy timeout 45 sn, TTS nesil sayacı (ghost play engeli)
- DÜŞÜK: Stays Schengen ±1 senkron, sürüm 1.3.0, ölü route sabitleri temizlendi

**Business-Case Düzeltmeleri (2026-07-29 — commit 5d3b65e):**
- KRİTİK: ConsentGate tam bilingual EN/TR + 4 checkbox (KVKK, AI işleme, konum, bildirim-opsiyonel)
- KRİTİK: Paywall "sınırsız soru" → "Günde 40 AI sorusu / 40 AI questions/day"; tam fayda listesi
- YÜKSEK: BG (Bulgaristan) para birimi BGN → EUR (Ocak 2026 değişimi)
- YÜKSEK: EES/ETIAS bilgi banner'ı radar'da (dismiss edilebilir, SharedPrefs ile)
- YÜKSEK: Schengen ülkelerine EES/ETIAS notu country_data'ya eklendi
- YÜKSEK: KKTC ülke kaydı eklendi (CT kodu, vizesiz, Türk vatandaşları)
- YÜKSEK: "Türk standart pasaportu için" vize veri uyarısı country_data'ya eklendi
- YÜKSEK: Radar'da Schengen kartı ilk sıraya taşındı
- YÜKSEK: Sınır modu paywall açıklaması → "Türkiye kara sınırı modu" (dürüst kapsam)
- YÜKSEK: Konum izni pre-permission kart (radar'da bağlamlı, splash'tan kaldırıldı)
- YÜKSEK: İlk seyahat eklendiğinde bildirim izni akışı (SharedPrefs ile tek seferlik)
- YÜKSEK: "Gerçek zamanlı otomatik takip" → "Uygulama açıkken otomatik algılama"
- ORTA: Onboarding 4 adım → 2 adım (dil + vatandaşlık; pasaport/seyahat tipi varsayılan)
- ORTA: Welcome Tour 14 slayt → 5 slayt (Schengen, AI, SOS, Ülke, Premium)
- ORTA: 3 ücretsiz AI sorusu tadımlığı (SharedPrefs 'free_ai_questions_used')
- ORTA: Security Scanner STT/mikrofon izni → sayfa 3'e taşındı (initState'ten çıkarıldı)
- ORTA: Worker chat modeli Opus 4.8 → Sonnet 5 (maliyet optimizasyonu)
- ORTA: nextResetDate metni → kayan 180-gün penceresi açıklaması
- ORTA: Paywall fayda listesi tam: AI Asistan, Güvenlik Tarayıcı, Tax-Free, AI Tur Rehberi, Belge Tarayıcı

**Performans Düzeltmeleri (2026-07-29):**
- ORTA: Splash bekleme 1500ms → 800ms (~0.7 sn açılış kazancı)
- ORTA: TTS statik bellek cache (20 giriş, <5 MB/giriş) — aynı metin tekrar ElevenLabs'a gitmez
- DÜŞÜK: Magnetometre 50 Hz (gameInterval) → 10 Hz (100ms) — tarama sırasında CPU/pil tasarrufu
- DÜŞÜK: STT `listenFor` 1 saat → 15 dakika, `pauseFor` 30 dk → 5 dk
- DÜŞÜK: Countries screen `ListView(children:)` → `ListView.builder` (lazy)
- DÜŞÜK: `pubspec.yaml` `assets/icons/` bundle'dan çıkarıldı (~300 KB IPA tasarrufu)
- DÜŞÜK: Saved Places `ListView(children:)` → `ListView.builder` (lazy)
- DÜŞÜK: TTS cache-hit playback try/catch ile sarıldı (_playing sızıntısı engellendi)
- DÜŞÜK: Splash yorum "~1.5s" → "~0.8s" (doğru değer)

**Re-test Düzeltmeleri (2026-07-29 — commit sonrası):**
- KRİTİK: Worker free-trial bypass — `Bearer free-trial` → IP tabanlı 3 soru limiti (KV); Apple doğrulama atlanır
- YÜKSEK: Splash'tan konum izni isteği kaldırıldı (geolocator import temizlendi); izin artık radar'da pre-permission kart ile isteniyor
- ORTA: assistant_screen.dart "unlimited AI assistant" → "40 questions/day" (2 yer)
- ORTA: Welcome Tour slayt 1 "gerçek zamanlı" → "uygulama açıkken otomatik"
- ORTA: EES/ETIAS içerik düzeltmesi: doğru tarih (Ekim 2024), doğru URL (travel-europe.europa.eu/etias), "vizesi" → "seyahat izni", BG+HR ülkelerine eklendi
- ORTA: Country detail ekranında "Türk standart pasaportu için" disclaimer eklendi

**Store Uyumluluk Düzeltmeleri (2026-07-29 — commit sonrası):**
- ORTA: ConsentGate 1. checkbox → Gizlilik Politikası + Kullanım Koşulları tıklanabilir RichText linkleri
- DÜŞÜK: `subscription_screen.dart` silindi (ölü kod — sahte fiyat/trialDays + "Google Play" metni)
- DÜŞÜK: `AppConstants` sahte fiyat sabitleri kaldırıldı (`priceEurMonthly`, `priceTryMonthly`, `trialDays`)
- DÜŞÜK: Welcome Tour slayt 4 "Anlık hava ve UV endeksi" → "Acil numaralar ve para birimi" (country_info "Coming Soon" tutarsızlık giderildi)
- DÜŞÜK: `legal.ts` terms → Tax-Free Rehberi + Güvenlik Tarayıcı premium listesine eklendi
- DÜŞÜK: `docs/APP_STORE_METADATA.md` tamamen güncellendi (v0.1.0 → v1.3.0, gerçek URL'ler, **9+ yaş**, Google Play todo listesi)
- DÜŞÜK: Android adaptive icon — `pubspec.yaml` + flutter_launcher_icons → `mipmap-anydpi-v26/ic_launcher.xml`
- Worker deploy: `a09e9656` (legal.ts güncellemesi)
- **ASC API ile tamamlandı (2026-07-29):** Privacy URL ✅ zaten doğru; Support URL ✅ zaten doğru; Age rating 4+ → **9+ (NINE_PLUS)** — `matureOrSuggestiveThemes: INFREQUENT_OR_MILD` (travel AI app için 9+ dürüst, 12+ yersiz); v1.3.0 PREPARE_FOR_SUBMISSION appInfo oluşturuldu (`b6c38b9e`)

**Store Uyumluluk RE-TEST Düzeltmeleri (2026-07-29):**
- DÜŞÜK: `AppConstants.appVersion` '1.0.0' → '1.3.0' (settings/legal/diagnostics doğru versiyon)
- DÜŞÜK: ConsentGate `TapGestureRecognizer` — State'e field olarak taşındı (initState + dispose ile bellek sızıntısı engellendi)
- DÜŞÜK: `country_detail_screen.dart:366` string concatenation → interpolation (lint temizlendi)
- DÜŞÜK: `docs/APP_STORE_METADATA.md` 3 yerde "12+" → "9+" (ASC gerçek değeriyle uyumlu)

**Erişilebilirlik Düzeltmeleri (2026-07-29 — Test #6, 26 bulgu, 16 dosya):**
- KRİTİK: SOS `_HoldSosButton` → `Semantics(button:true, label:, onLongPress:)` sarmalayıcı (VoiceOver acil SOS aktive edilebilir)
- YÜKSEK: `AppColors.textMuted` `#4A607A` → `#7D9BB8` (surfaceCard 2.23:1 → **4.57:1** WCAG AA; 111 kullanım)
- YÜKSEK: Welcome Tour `_SlidePage` → `SingleChildScrollView` (büyük yazı taşmasını önler)
- YÜKSEK: ConsentGate `RichText` → `textScaler: MediaQuery.textScalerOf(context)` (hukuki metin ölçekleniyor)
- YÜKSEK: `radar_screen.dart` — 3 başlık+EES+LocationAction+Schengen link: `BoxConstraints(min 44×44)` + `Semantics(button:)` + bildirim tooltip
- YÜKSEK: SOS FAB + paywall kapat + onboarding dil kartları — `tooltip`/`Semantics(button:, selected:)` eklendi
- ORTA: Paywall plan kartları `Semantics(selected:, label:)` + `Flexible` fiyat/başlık sarmalayıcı
- ORTA: `country_detail_screen.dart` AppBar + `_statRow` + `_callRow` `Flexible` + ellipsis
- ORTA: Stays silme 20pt → min 44pt; kalan gün eşik uyarı ikonu eklendi
- ORTA: SecurityScanner nokta dokunma 10pt → 44pt; CrossingCard butonlar 38pt → 44pt
- DÜŞÜK: Countries chip ikonları (check/assignment), 6 TextField `labelText`, sayfa göstergeleri `Semantics(label:)`

**Erişilebilirlik RE-TEST Düzeltmeleri (2026-07-29):**
- ORTA: Countries Schengen chip metin `#3B82F6` (3.3:1) → `#93C5FD` (6.8:1, WCAG AA)
- DÜŞÜK: Stays silme IconButton `tooltip: 'Kaydı sil'/'Delete record'` eklendi
- DÜŞÜK: SecurityScanner nokta `horizontal:5→17` (44pt yatay hedef) + `Semantics(button, label)`

**Cihaz/Sürüm Uyumluluk Düzeltmeleri (2026-07-29 — Test #7, 11 bulgu):**
- YÜKSEK: Paywall alt link satırı `Row` → `Wrap` — 320pt (iPhone SE 1. nesil) RenderFlex taşması engellendi
- YÜKSEK: `LocationProofService.getEntries()` + `_save()` + `verifyChain()` → `compute()` (isolate) — 5000 kayıt JSON decode/encode artık main thread'i kilitlemez
- YÜKSEK: `location_proof_screen.dart` `ListView(children:)` → `ListView.builder` + `_groupByDay()` — 5000 kayıt eager render yerine günlük gruplar lazy
- ORTA: `AnthropicProxy.vision()` `base64Encode(image.bytes)` → `compute(_base64Isolate, ...)` — belge tarayıcı base64 artık isolate'te
- ORTA: `NaturalTts._cacheMax` 20 → 5 (teorik tavan 100 MB → 25 MB, düşük RAM cihazlar için)
- DÜŞÜK: `NaturalTts.dispose()` → `_generation++; _finish(); _player.dispose()` — bekleyen completer artık tamamlanır
- DÜŞÜK: `ios/Podfile` platform satırı yorumdan çıkarıldı (`platform :ios, '15.0'`) — pod derleme uyarıları giderildi
- DÜŞÜK: `assistant_screen.dart _initSpeech()` → try/catch sarmalayıcı (STT PlatformException yakalandı)
- DÜŞÜK: `security_scanner_screen.dart`, `country_detail_screen.dart`, `stays_screen.dart` (×2) — alt padding `+ MediaQuery.paddingOf(context).bottom` (home indicator örtüşmesi engellendi)
- DÜŞÜK: `WeatherService.close()` metodu eklendi (http.Client kaynak serbest bırakma)

**Cihaz/Sürüm Uyumluluk RE-TEST Düzeltmeleri (2026-07-29):**
- DÜŞÜK: `travel_log_service.dart` `_writeStore()` → 730-gün kayan cap eklendi (sınırsız büyüme engellendi)
- DÜŞÜK: `natural_tts.dart` yorum "20 entries" → "5 entries" (gerçek değerle uyumlu)
- DÜŞÜK: 6 push ekran daha alt padding + home indicator inset: `sos_setup`, `document_scanner`, `add_trip`, `trips`, `location_detail`, `border_mode_widgets`

**Ödeme/Abonelik Düzeltmeleri (2026-07-29 — Test #8, 15 bulgu):**
- **ASC API:** Apple Server Notifications V2 webhook `https://visaradar-proxy.gokcerodop.workers.dev/v1/apple-notify` üretim + sandbox kayıtlı (2026-07-29)
- KRİTİK: `_activate()` — monthly/annual restore için `_expiresAt.isAfter(now)` kontrolü eklendi (süresi dolmuş abonelik premium vermiyor)
- YÜKSEK: Satın alma hatası kullanıcıya gösteriliyor — `_purchaseError` getter + `clearError()` + paywall SnackBar (`PurchaseStatus.error`)
- YÜKSEK: Lifetime iade + 5.2 Worker 401 revocation → `revokeEntitlement()` — assistant/tourist_guide/location_detail `on ProxySubscriptionRequiredException catch (e)` + `e.reason == 'subscription-revoked'` → Keychain/SharedPrefs temizleniyor
- ORTA: `buy()` — `_purchaseInFlight` double-tap guard (reentrancy) + false return'da reset
- ORTA: `resumed` lifecycle → `SubscriptionService.instance.refreshExpiry()` (`app.dart`)
- ORTA: `_scheduleExpiryTimer()` — abonelik bitiminde kesin zamanlayıcı (tek-atışlık) otomatik premium iptali
- ORTA: `restore()` → `Future<bool>` döndürür (found/empty); paywall `_handleRestore()` ile "geri yüklenecek satın alım bulunamadı" SnackBar
- ORTA: Paywall "3 gün ücretsiz dene · en avantajlı" → "Ücretsiz deneme · en avantajlı" (hardcoded gün sayısı kaldırıldı)
- DÜŞÜK: `restore()` — `_purchaseInFlight = true` busy guard eklendi
- DÜŞÜK: Ölü l10n stringleri silindi: `subscriptionTitle`, `subscriptionTrialInfo`, `subscriptionPriceEur`, `subscriptionPriceTry`, `subscriptionStartTrial` (app_en.arb + app_tr.arb + app_localizations*.dart)

**Ödeme/Abonelik RE-TEST Düzeltmeleri (2026-07-29):**
- ORTA: `_activate()` → `_extractRevocationDateFromJws()` kontrolü — iade edilmiş lifetime cold-launch restore'da yeniden aktive olamaz (5.2 döngüsel açık kapatıldı)
- ORTA: `_restoreInFlight` flag ayrıldı — restore 800ms penceresi içinde `buy()` başlatılamaz; `purchaseInFlight` getter `_purchaseInFlight || _restoreInFlight`
- DÜŞÜK: `buy()` false/exception'da `_purchaseError = 'purchase-failed'` → paywall SnackBar tetikleniyor
- DÜŞÜK: `document_scanner_screen.dart` revoke kontrolü eklendi (4. ProxySubscriptionRequiredException noktası)
- DÜŞÜK: `debugReset()` → `_expiryTimer?.cancel()` + doc yorumu güncellendi

**Offline / Zayıf Bağlantı Düzeltmeleri (2026-07-29 — Test #9, 18 bulgu):**
- YÜKSEK: Worker kota artışı LLM/TTS çağrısından sonraya taşındı — `checkLimitOnly()` + `incrementUsage()` (timeout/bağlantı hatalarında kota yanmıyor); `rate-limit.ts`, `index.ts`, `tts.ts`
- YÜKSEK: Paywall ürün listesi boş kaldığında (`subs.available && products.empty`) "Tekrar Dene" butonu eklendi — `_unavailableNotice(subs, isTr)` refactor
- YÜKSEK: Offline GPS-only proof chain kaydı — ülke algılama `failed` fazına geçtiğinde `_recordGpsOnlyCapture()` çağrılır (geocode olmadan SHA-256 zinciri devam eder)
- ORTA: Radar `LocationDetectionPhase.failed` → turuncu uyarı UI + "İnternet veya GPS bağlantısını kontrol edin" + "Tekrar Dene" butonu (önceden "Konum aktif" gösteriliyordu)
- ORTA: `ProxyNetworkException` — `anthropic_proxy.dart`'a yeni exception; `SocketException` + `TimeoutException` → typed exception (dart:io import eklendi)
- ORTA: Assistant controller + assistant screen, tourist guide, document scanner — `ProxyNetworkException` catch + "İnternet bağlantısı yok" mesajı (generic catch'den ayrıldı)
- ORTA: `LocationProofService.recordCurrentLocation()` → statik `_writeChain` mutex (dart:async Completer); concurrent write yarışı önlendi
- ORTA: `TravelLogService._writeStore()` → statik `_writeChain` mutex; GPS + pedometer eşzamanlı yazma önlendi
- Worker deploy: `a8bb5116` (2026-07-29)

**Yerelleştirme Düzeltmeleri (2026-07-29 — Test #10, commit c647b49):**
- K-1: `crossing_suggestion_card.dart` tam bilingual — başlık, açıklama, buton (isTr), "Şimdi değil"
- Y-1: `app.dart` — `Intl.defaultLocale = localeCode == 'tr' ? 'tr_TR' : 'en_US'` (DateFormat otomatik TR/EN)
- O-1: Ölü ARB/l10n sistemi silindi — `lib/l10n/`, `l10n.yaml`, `pubspec.yaml` `generate: true`
- D-1: `location_proof_screen.dart` "Visa başvuruları" → "Vize başvuruları" (TR yazım)
- D-2: `security_scanner_screen.dart` "sigara yaklamayın" → "sigara yakmayın" (TR yazım)
- D-3: `onboarding_screen.dart` "Hoşgeldiniz" → "Hoş Geldiniz" (TDK imla kuralı)
- D-5: `app_router.dart` errorBuilder route-not-found bilingual (L.isTr)
- D-6: `lib/core/errors/failures.dart` silindi (ölü kod)

**Hukuki / KVKK Düzeltmeleri (2026-07-29 — Test #11, commit c647b49):**
- K1: `legal_screen.dart` "Data Storage" düzeltildi — AI/Open-Meteo iletim dürüstçe belirtildi
- K2: `legal.ts` terms — yıllık plan "3 günlük deneme" ibaresi kaldırıldı (App Store 3.1.2(c))
- Y1: `legal.ts` — Veri Sorumlusu bölümü eklendi (Gökçe Rodop, e-posta)
- Y2: `legal.ts` — Veri Saklama Süresi bölümü eklendi (cihaz: app silinene dek; Anthropic: max 30 gün)
- Y3: `legal.ts §1.1` — Open-Meteo anonim koordinat iletimi eklendi (önceki mutlak "cihazda kalır" iddiası düzeltildi)
- Y4: `radar_screen.dart` — "Never overstay again" → "Stay informed and avoid overstays" (mutlak garanti kaldırıldı)
- Y5: `radar_screen.dart` Schengen kartı — "Hesaplama referans amaçlıdır; resmi kayıtlar esas alınır" eklendi
- O1: `consent_gate_screen.dart` — işlevsiz `_tipsOptIn` checkbox kaldırıldı
- O4: `consent_gate_screen.dart` — "İşlenen veriler" listesine fotoğraf (belge tarayıcı), TTS metin, Open-Meteo anonim konum eklendi
- O6: `legal_screen.dart` tarih "May 2026" → "July 2026" güncellendi
- D2: `consent_gate_screen.dart` `_consentVersion` 2 → 3 (metin değişti; güncelleme sonrası yeniden onay)
- D3: `legal.ts` supportPage FAQ — TR sorulara EN yanıtlar eklendi (bilingual)
- Worker deploy: `aa975c0a` (2026-07-29)

**Yerelleştirme RE-TEST Düzeltmeleri (2026-07-29 — commit d43c772):**
- YÜKSEK: `assistant_screen.dart:594-608` — 12 TR örnek soru tam Türkçe karakter + kesme işareti (Yakınımdaki, döviz bürosu, Hırvatistan gümrüğü, Madrid'te, Roma'da, Almanya'da vb.)
- YÜKSEK: `country_detail_screen.dart:402-446` — Sürüş Kuralları etiketleri: "Gunduz Fari"→"Gündüz Farı", "Guvenlik Yelegi"→"Güvenlik Yeleği", "Zorunlu degil"→"Zorunlu değil", "Aracta"→"Araçta", "Surus"→"Sürüş"
- ORTA: `radar/stays/trips/add_trip` `final _dateFmt` → `DateFormat _dateFmt()` fonksiyon (oturum içi dil değişiminde locale güncellenir)
- ORTA: `countries.dart` — 116 ülkeye `nameTr` eklendi; onboarding arama TR'de `nameTr` tarıyor; `_CountryRow` TR modda Türkçe ad gösteriyor
- ORTA: `radar_screen.dart:866-872` EES/ETIAS banner — "ETIAS vizesi"→"ETIAS seyahat izni"; "zorunlu"→"yakında zorunlu olacak"
- DÜŞÜK: `country_enrichment.dart` "Iskender"→"İskender"; `country_detail` alkol "0.50"→"0,50" TR; `_SummaryRow` Flexible+ellipsis; `consent_gate` "yapay zeka"→"yapay zekâ"

**Hukuki / KVKK RE-TEST Düzeltmeleri (2026-07-29 — commit 310582c):**
- ORTA: `legal.ts §1.2` — "sunucuya gönderilmez" mutlak iddiası kaldırıldı; AI asistanında pasaport türü + Schengen bakiyesinin Anthropic'e iletildiği bilingual belirtildi
- DÜŞÜK: `legal.ts terms` — "ücretsiz denemenin kullanılmamış kısmı iptal edilir" kaldırıldı (intro offer yok; proje trial-ban kuralı)
- DÜŞÜK: `paywall_screen.dart:179` — yıllık plan "Free trial included · best value" → "Best value · annual" (hardcoded trial claim temizlendi)
- Worker deploy: `bbb3f0f3` (2026-07-29)

**Hukuki / KVKK Test #11 RE-TEST (2026-07-29): 10/10 GEÇTI — kalan bulgu yok.**

**Hukuki / KVKK Test #11 Tam Düzeltmeleri (2026-07-29 — commit 2a0d1d1):**
- YÜKSEK: `consent_gate_screen.dart` — `_accept()` içine `prefs.setString('visaradar.consent.date', DateTime.now().toIso8601String())` eklendi (onay tarihi audit trail)
- YÜKSEK: `consent_gate_screen.dart` — `resetConsent()` public fonksiyon eklendi (SharedPrefs siler)
- YÜKSEK: `settings_screen.dart` — "Rızamı Geri Çek / Withdraw Consent" tile: onay dialog → `resetConsent()` → `context.go(AppRoutes.consentGate)`
- YÜKSEK: `settings_screen.dart` — "Verilerimi Sil / Request Data Deletion" tile: KVKK konu+gövde doldurulmuş `mailto:` linki
- ORTA: `legal_screen.dart:76` — Privacy Overview "All travel data is stored locally" yanıltıcı cümle → AI iletimi doğrudan belirtildi
- ORTA: `legal.ts §5` — Cloudflare üçüncü taraf listesine eklendi (onay metninde vardı ama §5'te eksikti)
- ORTA: `settings_screen.dart` — `_SettingsTile`'a opsiyonel `iconColor` parametresi; tehlikeli tile'lara `AppColors.warning/danger`
- Worker deploy: `655db2d1` (LAST_UPDATED → 29 Temmuz 2026)

**Yerelleştirme RE-TEST #2 Düzeltmeleri (2026-07-29 — commit 9bf5b92):**
- DÜŞÜK: `country_enrichment.dart:44` TR `foodHighlightsTr` — "Iskender"→"İskender" (EN doğruydu, TR'de gözden kaçmıştı)
- DÜŞÜK: `countries_stay_screen.dart:33` + `cities_stay_screen.dart:12` — `final _dateFmt` → `DateFormat _dateFmt()` fonksiyon (ilk re-test'te gözden kaçan iki dosya)
- DÜŞÜK: `onboarding_screen.dart:631` — `onSelect(country.code, country.name)` → `onSelect(country.code, _isTr ? (country.nameTr ?? country.name) : country.name)` (settings/profil ekranı TR modda "Türkiye" yerine "Turkey" gösteriyordu)

**Yeni Özellikler (2026-07-29 — commit 736a68b, telefonda):**
- `welcome_tour_screen.dart`: Her açılışta tur göster; "Bir daha gösterme" → `markTourSeen()` (kalıcı), "Atla" / "Hadi Başlayalım!" → sadece navigate (markTourSeen çağrılmaz). Settings'ten push ile açılırsa `context.pop()` geri döner.
- 6. slayt eklendi: Seyahat Profili Setup (orange, `Icons.manage_accounts_outlined`) — uygulama için zorunlu profil kurulumunu vurgular. Slayt sırası: Schengen → Profili → AI → SOS → 23+ Ülke → Premium.
- Slayt 1 (Schengen) auto-location metni güncellendi: GPS ile otomatik kayıt, "uygulama kapalıyken takip yok" açıkça belirtildi.
- `settings_screen.dart` Tercihler bölümü: "Uygulama Turu" tile eklendi (`Icons.slideshow_outlined`) — `?from=profile` ile `showDismiss:true` turu açar.
- `location_proof_screen.dart`: `isPremiumProvider` gate eklendi — premium değilse `_buildPremiumGate()` gösterilir, bottomBar gizlenir.
- `assistant_screen.dart:594-621`: "Yakınımdaki döviz bürosu nerede?" + "Find a currency exchange office nearby" kaldırıldı → gerçekçi sorular eklendi.
- `assistant_controller.dart` system prompt: `NEARBY SEARCHES` bölümü eklendi — yakın yer sorularına `maps://?q=SEARCH_TERM` Apple Maps linki döndürülür.
- `saved_places_screen.dart`: Maps icon `Icons.navigation_outlined` → `Icons.map_outlined`, tooltip "Git"→"Haritada Aç" / "Navigate"→"Open in Maps".

**Özellik Düzeltmeleri — Batch 3 (2026-07-29):**
- `profile_screen.dart`: Derin Bilgi tile "Yerlerim" bölümünden kaldırıldı (yalnızca Settings > Premium Araçlar'da olmalı)
- `legal.ts` privacy: KVKK haklar maddesinden "gokcerodop@gmail.com adresine başvurabilirsiniz" kaldırıldı — genel yönlendirme bırakıldı
- `legal.ts` terms: "Ömür Boyu Premium — 59,99 USD" satırı kaldırıldı; support FAQ'tan da lifetime planı silindi
- `welcome_tour_screen.dart`: Güvenlik Tarayıcı slaydı eklendi (8. slayt, 23+ Ülke ile Premium arasında) — 3 özellik + kesin güvenilmemesi uyarısı
- Worker deploy: `37577b66` (2026-07-29)

**Backlog (kapsam dışı, sonraki sürüm):**
- **⚠️ ASC API v2 geçişi (Apple resmi email 2026-07-29):** `tool/asc_visaradar.mjs` setupIap() içindeki `subscriptionLocalizations`/`subscriptionSubmissions` çağrıları deprecated → `SubscriptionVersion` v2'ye geçilmeli. Mevcut abonelikler çalışıyor; kaldırılmadan önce bir sonraki `asc.mjs` yenilemesinde v2 yoluna geçilecek.
- Ömür boyu $59.99 → $89.99 (App Store Connect'te yapılır)
- Vize süre takibi özelliği (yeni büyük özellik)
- Çoklu vatandaşlık veri modeli (mimari değişiklik)
- Arka plan konum / Significant Location Change (Background mode)
- IR-lens görsel kamera taraması (yeni sensör)
- Vize kuralları Worker/KV'den servis (hardcoded → API)

## Mevcut Özellikler (tüm liste)

| # | Özellik | Dosya | Rota |
|---|---------|-------|------|
| 1 | Schengen / Radar | `features/radar/` | `/main/radar` |
| 2 | 23+ Ülke Rehberi | `features/countries/` | `/main/countries` |
| 3 | AI Asistan + TTS (3 ücretsiz soru) | `features/assistant/` | `/main/assistant` |
| 4 | Acil SOS | `features/sos/` | `/sos` |
| 5 | Tax-Free Rehberi | `features/tax_free/` | `/tax-free` |
| 6 | AI Tur Rehberi + TTS | `features/tourist_guide/` | `/tourist-guide` |
| 7 | Şehir Keşfi | `features/location/presentation/screens/location_detail_screen.dart` | — |
| 8 | Kayıtlı Yerler | `features/location/presentation/screens/saved_places_screen.dart` | `/profile/saved-places` |
| 9 | Belge Tarayıcı | `features/scanner/document_scanner_screen.dart` | Navigator.push |
| 10 | Seyahat Takvimi | `features/travel_calendar/` | `/travel-calendar` |
| 11 | Derin Bilgi | `features/location_proof/` | `/location-proof` |
| 12 | Güvenlik Tarayıcı | `features/security_scanner/` | `/security-scanner` |
| 13 | Karşılama Turu (6 slayt; her açılışta) | `features/welcome_tour/` | `/welcome-tour` |
| 14 | KVKK Onay (4 checkbox, bilingual) | `screens/consent_gate_screen.dart` | `/consent-gate` |

**Güvenlik Tarayıcı detayı:**
- Sayfa 1: Gizli Kamera — magnetometre (>75 µT şüpheli, >105 µT alarm)
- Sayfa 2: Ses Dinleme Cihazı — magnetometre RF (>80 µT şüpheli, >115 µT alarm)
- Sayfa 3: Gaz/Alarm — mikrofon ses seviyesi (dBFS); alarm seslerini dinler; kimyasal tespit etmez
- STT/mikrofon izni yalnızca sayfa 3'e gelindiğinde istenir

## Teknoloji & Mimari
- **İstemci:** Flutter (iOS birincil). Ana app `lib/`. i18n yok — `L.isTr` / `isTurkishProvider` ile TR/EN.
- **Backend:** Cloudflare Worker `workers/visaradar-proxy` (TS). Endpoint'ler: `/v1/chat`, `/v1/vision`, `/v1/tts`.
- Claude proxy + rate-limit + KV + Apple receipt doğrulama + Telegram bildirim.
- **İstemci → Worker context:** Her istekte `context.kvkkConsent: true` zorunlu. Worker 403 döner yoksa.
- **Hassas veri:** Premium txId `flutter_secure_storage` → iOS Keychain.
- **Premium gate:** Tax-Free + Güvenlik Tarayıcı + **Derin Bilgi** `isPremiumProvider` ile korumalı.
- **AI Asistan:** 3 ücretsiz soru (SharedPrefs 'free_ai_questions_used') → sonra paywall.

## Önemli Sabitler
- Bundle id: `com.visaradar.visaradar` · App id: `6761065257` · Team: `V8CC8CQG3W`
- Worker: `visaradar-proxy.gokcerodop.workers.dev`
- Worker chat modeli: `claude-sonnet-5` (deploy: `3497463f`, 2026-07-29 — Opus 4.8'den düşürüldü)
- ASC key: `~/.private_keys/AuthKey_SDUZJJP88A.p8` (KID `SDUZJJP88A`, ISS `a8b3e068-98a4-4929-af96-52e370a38db7`)
- ASC otomasyonu: `tool/asc_visaradar.mjs` (status/verify/shots/builds)
- IAP: `com.visaradar.premium.{monthly $4.99, annual $34.99, lifetime $59.99}`
- Yasal (canlı, worker): `…workers.dev/privacy` ve `…workers.dev/terms` · Kaynak: `workers/visaradar-proxy/src/legal.ts`
- ElevenLabs: voice `JBFqnCBsd6RMkjVDRZzb`, model `eleven_multilingual_v2` (wrangler.toml [vars])

## Pubspec — Eklenen Bağımlılıklar
```
audioplayers: ^6.7.1          # ElevenLabs TTS oynatma
crypto: ^3.0.3                # SHA-256 konum kanıtı zinciri
pedometer: ^3.0.0             # Seyahat Takvimi adım sayacı
share_plus: ^10.0.0           # Derin Bilgi dışa aktarma
sensors_plus: ^4.0.2          # Güvenlik Tarayıcı magnetometre
flutter_jailbreak_detection: ^1.10.0  # Jailbreak hard-block
permission_handler: ^11.3.1   # Konum + bildirim izni
flutter_local_notifications: ^18.0.1  # Schengen uyarı bildirimleri
```

## Tema Kuralları
- Renk kullanma: `AppColors.brandNavy/brandTeal/surfaceCard/divider/textPrimary/textSecondary/textMuted`
- `withOpacity()` KULLANMA → `withValues(alpha: x)` veya `withAlpha(x)` kullan
- Metin: `AppTextStyles.displayLarge/displayMedium/headlineMedium/titleLarge/bodyLarge/bodyMedium/bodySmall/labelLarge/caption`
- Yerelleştirme: `L.isTr` (static, ref gerektirmez) veya `ref.watch(isTurkishProvider)`

## Onboarding Akışı (2026-07-29 güncel)
1. **Splash** → jailbreak check → `isOnboardingDone`?
2. **Onboarding** (2 adım): Adım 1 = Dil, Adım 2 = Vatandaşlık
   - Pasaport türü ve seyahat şekli artık onboarding'de YOK; varsayılanlar (ordinary, plane) otomatik
   - Ayarlar > Seyahat Profili'nden değiştirilebilir
3. **KVKK ConsentGate** (bilingual, 3 zorunlu checkbox: KVKK, AI işleme, konum; `consentVersion=3`)
4. **Welcome Tour** (5 slayt; "Atla" + "Bir daha gösterme" mevcut)
5. **Radar** (ana ekran)

## Komutlar
- `flutter pub get`
- `flutter analyze lib/`
- Telefona yükle: `flutter run --release --device-id 00008120-001C60661463C01E`
- Worker deploy: `cd workers/visaradar-proxy && npx wrangler@latest deploy`
- App Store: `tool/asc_visaradar.mjs` + ortak hafıza `appstore-upload-runbook`

## Çalışma Kuralları
- Bir göreve başlamadan önce bu dosyayı referans al; ayrıca dosya keşfi yapma.
- `withOpacity` yasak; her zaman `withValues(alpha:)` kullan.
- Yeni ekran eklerken: `AppRoutes` sabiti → `GoRoute` → profil tile → tur slaytı sırası.
- Commit sonrası GitHub'a push et ve hafızayı güncelle.
- Worker model değişikliği sonrası `npx wrangler@latest deploy` çalıştır.
