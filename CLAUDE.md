# VisaRadar (VisaRadar Travel)

Premium global vize / sınır / Schengen kalış takip uygulaması (AI destekli). Telegram botu çalışıyor.

**App Store durumu (2026-07-12):** v1.2.0+6 **WAITING_FOR_REVIEW** — submission `a76d0c61-dcfe-40bf-ad5c-9c7b3713864f`. Apple onayı bekleniyor.

**Sonraki build için hazırlanan değişiklikler (telefonda test edildi, GitHub'da hazır):**
1. ElevenLabs TTS "Dinle" butonu — AI Asistan + AI Tur Rehberi
2. 14 slaytlı Karşılama Turu (8→14 slayt)
3. Asistan metin güncellemesi ("Soracaklarınızdan Bazıları")
4. Şehir Keşfi bug fix (subscription hatası doğru mesaj)
5. KVKK tile Ayarlar'a eklendi; kapsamlı legal.ts (TR+EN)
6. **Derin Bilgi** — SHA-256 hash zincirli konum kanıtı
7. **Seyahat Takvimi** — günlük km/adım/şehir/ülke/not; pedometer
8. **Güvenlik Tarayıcı** — 3 kaydırmalı sayfa; gizli kamera / ses böceği / gaz alarm

## Mevcut Özellikler (tüm liste)

| # | Özellik | Dosya | Rota |
|---|---------|-------|------|
| 1 | Schengen / Radar | `features/radar/` | `/main/radar` |
| 2 | 42 Ülke Rehberi | `features/countries/` | `/main/countries` |
| 3 | AI Asistan + TTS | `features/assistant/` | `/main/assistant` |
| 4 | Acil SOS | `features/sos/` | `/sos` |
| 5 | Tax-Free Rehberi | `features/tax_free/` | `/tax-free` |
| 6 | AI Tur Rehberi + TTS | `features/tourist_guide/` | `/tourist-guide` |
| 7 | Şehir Keşfi | `features/location/presentation/screens/location_detail_screen.dart` | — |
| 8 | Kayıtlı Yerler | `features/location/presentation/screens/saved_places_screen.dart` | `/profile/saved-places` |
| 9 | Belge Tarayıcı | `features/scanner/document_scanner_screen.dart` | Navigator.push |
| 10 | Seyahat Takvimi | `features/travel_calendar/` | `/travel-calendar` |
| 11 | Derin Bilgi | `features/location_proof/` | `/location-proof` |
| 12 | Güvenlik Tarayıcı | `features/security_scanner/` | `/security-scanner` |
| 13 | Karşılama Turu | `features/welcome_tour/` | `/welcome-tour` |

**Güvenlik Tarayıcı detayı:**
- Sayfa 1: Gizli Kamera — magnetometre (>75 µT şüpheli, >105 µT alarm)
- Sayfa 2: Ses Dinleme Cihazı — magnetometre RF (>80 µT şüpheli, >115 µT alarm)
- Sayfa 3: Gaz/Alarm — mikrofon ses seviyesi (dBFS); alarm seslerini dinler; kimyasal tespit etmez

## Teknoloji & Mimari
- **İstemci:** Flutter (iOS birincil). Ana app `lib/`. i18n yok — `L.isTr` / `isTurkishProvider` ile TR/EN.
- **Backend:** Cloudflare Worker `workers/visaradar-proxy` (TS). Endpoint'ler: `/v1/chat`, `/v1/vision`, `/v1/tts`.
- Claude proxy + rate-limit + KV + Apple receipt doğrulama + Telegram bildirim.

## Önemli Sabitler
- Bundle id: `com.visaradar.visaradar` · App id: `6761065257` · Team: `V8CC8CQG3W`
- Worker: `visaradar-proxy.gokcerodop.workers.dev`
- ASC key: `~/Downloads/AuthKey_SDUZJJP88A.p8` (KID `SDUZJJP88A`, ISS `a8b3e068-98a4-4929-af96-52e370a38db7`)
- ASC otomasyonu: `tool/asc_visaradar.mjs` (status/verify/shots/builds)
- IAP: `com.visaradar.premium.{monthly $4.99, annual $34.99 +3g deneme, lifetime $59.99}`
- Yasal (canlı, worker): `…workers.dev/privacy` ve `…workers.dev/terms` · Kaynak: `workers/visaradar-proxy/src/legal.ts`
- ElevenLabs: voice `JBFqnCBsd6RMkjVDRZzb`, model `eleven_multilingual_v2` (wrangler.toml [vars])

## Pubspec — Eklenen Bağımlılıklar
```
audioplayers: ^6.7.1       # ElevenLabs TTS oynatma
crypto: ^3.0.3             # SHA-256 konum kanıtı zinciri
pedometer: ^3.0.0          # Seyahat Takvimi adım sayacı
share_plus: ^10.0.0        # Derin Bilgi dışa aktarma
sensors_plus: ^4.0.2       # Güvenlik Tarayıcı magnetometre
```

## Tema Kuralları
- Renk kullanma: `AppColors.brandNavy/brandTeal/surfaceCard/divider/textPrimary/textSecondary/textMuted`
- `withOpacity()` KULLANMA → `withValues(alpha: x)` veya `withAlpha(x)` kullan
- Metin: `AppTextStyles.displayLarge/displayMedium/headlineMedium/titleLarge/bodyLarge/bodyMedium/bodySmall/labelLarge/caption`
- Yerelleştirme: `L.isTr` (static, ref gerektirmez) veya `ref.watch(isTurkishProvider)`

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
