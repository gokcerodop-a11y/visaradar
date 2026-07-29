# VisaRadar (VisaRadar Travel)

Premium global vize / sınır / Schengen kalış takip uygulaması (AI destekli). Telegram botu çalışıyor.

**App Store durumu (2026-07-29):** v1.2.0+6 **APPROVED** (mağaza yayını bekleniyor). v1.3.0+7 güvenlik + fonksiyonel + business-case tam yama + telefonda.

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

**Re-test Düzeltmeleri (2026-07-29 — commit sonrası):**
- KRİTİK: Worker free-trial bypass — `Bearer free-trial` → IP tabanlı 3 soru limiti (KV); Apple doğrulama atlanır
- YÜKSEK: Splash'tan konum izni isteği kaldırıldı (geolocator import temizlendi); izin artık radar'da pre-permission kart ile isteniyor
- ORTA: assistant_screen.dart "unlimited AI assistant" → "40 questions/day" (2 yer)
- ORTA: Welcome Tour slayt 1 "gerçek zamanlı" → "uygulama açıkken otomatik"
- ORTA: EES/ETIAS içerik düzeltmesi: doğru tarih (Ekim 2024), doğru URL (travel-europe.europa.eu/etias), "vizesi" → "seyahat izni", BG+HR ülkelerine eklendi
- ORTA: Country detail ekranında "Türk standart pasaportu için" disclaimer eklendi

**Backlog (kapsam dışı, sonraki sürüm):**
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
| 13 | Karşılama Turu (5 slayt) | `features/welcome_tour/` | `/welcome-tour` |
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
- **Premium gate:** Tax-Free + Güvenlik Tarayıcı `isPremiumProvider` ile korumalı.
- **AI Asistan:** 3 ücretsiz soru (SharedPrefs 'free_ai_questions_used') → sonra paywall.

## Önemli Sabitler
- Bundle id: `com.visaradar.visaradar` · App id: `6761065257` · Team: `V8CC8CQG3W`
- Worker: `visaradar-proxy.gokcerodop.workers.dev`
- Worker chat modeli: `claude-sonnet-5` (Opus 4.8'den düşürüldü — maliyet optimizasyonu)
- ASC key: `~/Downloads/AuthKey_SDUZJJP88A.p8` (KID `SDUZJJP88A`, ISS `a8b3e068-98a4-4929-af96-52e370a38db7`)
- ASC otomasyonu: `tool/asc_visaradar.mjs` (status/verify/shots/builds)
- IAP: `com.visaradar.premium.{monthly $4.99, annual $34.99 +3g deneme, lifetime $59.99}`
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
3. **KVKK ConsentGate** (bilingual, 4 checkbox: KVKK, AI işleme, konum, bildirim[opsiyonel])
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
