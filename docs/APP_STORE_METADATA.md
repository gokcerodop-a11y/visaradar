# VisaRadar — App Store Metadata

Preparation document for App Store (iOS) and Google Play (Android) submissions.

**Son güncelleme / Last updated: 29 Temmuz 2026 / 29 July 2026**
**Mevcut sürüm / Current version: 1.3.0+7**

---

## App Identity

| Field | Value |
|---|---|
| **App Name** | VisaRadar Travel |
| **Bundle ID (iOS)** | com.visaradar.visaradar |
| **Package Name (Android)** | com.visaradar.visaradar |
| **Version** | 1.3.0 |
| **Build Number** | 7 |
| **Category** | Travel |
| **Age Rating** | **9+** (matureOrSuggestiveThemes: INFREQUENT_OR_MILD — ASC'de ayarlandı) |
| **Platforms** | iOS 16.0+ |

---

## URLs (canlı, tüm 200 dönüyor)

| Sayfa | URL |
|---|---|
| Privacy Policy | `https://visaradar-proxy.gokcerodop.workers.dev/privacy` |
| Terms of Use | `https://visaradar-proxy.gokcerodop.workers.dev/terms` |
| Support | `https://visaradar-proxy.gokcerodop.workers.dev/support` |

**ASC'de doldurulması gereken URL alanları (web UI'dan):**
- App Information → Support URL → `https://visaradar-proxy.gokcerodop.workers.dev/support`
- App Information → Privacy Policy URL → `https://visaradar-proxy.gokcerodop.workers.dev/privacy`

---

## App Store (iOS) — Listing Copy

### App Name
`VisaRadar Travel`

### Subtitle *(30 chars max)*
`Track Stays. Stay Legal.`

### Promotional Text *(170 chars max)*
`Know exactly how many Schengen days you've used. AI travel assistant, Security Scanner, Tax-Free Guide and more — all in one app.`

### Description *(4000 chars max)*

```
VisaRadar Travel is your AI-powered travel companion for the Schengen zone and beyond.

SCHENGEN 90/180 TRACKER
See exactly how many days you've used in the rolling 90/180-day window. Get risk indicators (Safe / Warning / Critical) and alerts at 30, 15, 7, 3 and 1 days remaining. Auto country detection when the app is open.

AI TRAVEL ASSISTANT
Ask anything — visas, customs, currency, tax-free shopping, local tips. Powered by Claude AI. 3 free questions included; 40 questions/day with Premium.

23+ COUNTRY GUIDE
Entry rules, speed limits, emergency numbers, currency, visa requirements and practical tips for every destination. Covers Schengen, Turkey, UK, UAE and more.

EMERGENCY SOS
Loud alarm siren + SOS torch signal. Instantly message 2 emergency contacts with your GPS location.

PREMIUM FEATURES
• Tax-Free Guide — step-by-step VAT refund instructions
• AI Tour Guide — photo-based cultural narration with audio
• Document Scanner — keep all travel documents in one place
• Security Scanner — hidden camera and listening device detection
• Turkey Land Border Mode — Bulgaria & Greece crossing checklist (5 gates)
• 40 AI questions/day

IMPORTANT
VisaRadar Travel is not an official visa advisory service. AI responses may be out of date due to changing regulations. Always verify visa and entry rules with official government sources before travelling. Visa data applies to Turkish standard passport holders.

PRICING
VisaRadar Premium: Monthly $4.99 · Annual $34.99. Manage or cancel anytime in Settings → Your Name → Subscriptions.
```

### Keywords *(100 chars max)*
`schengen,visa tracker,travel days,border crossing,eu travel,90 day rule,tax free,travel assistant`

---

## Google Play — Listing Copy

**Not: Google Play gönderimi henüz yapılmadı. Gönderim öncesi yapılacaklar:**
- [ ] Generative AI questionnaire doldur (Play Data Safety)
- [ ] Data Safety form: Konum (device only), Mikrofon (AI asistan + Güvenlik Tarayıcı)
- [ ] Age rating: IARC anketinde AI içerik işaretle → 12+ sonucu bekleniyor
- [ ] Android adaptive icon mevcut (`mipmap-anydpi-v26/` oluşturuldu — flutter_launcher_icons)

### App Name
`VisaRadar Travel`

### Short Description *(80 chars max)*
`Track Schengen days, AI travel assistant, Security Scanner & more.`

### Full Description
*(App Store açıklaması ile aynı metin)*

---

## Screenshots & Preview

| Platform | Minimum | Boyut |
|---|---|---|
| iPhone 6.7" | 3 | 1290 × 2796 |
| iPhone 6.5" | 3 | 1284 × 2778 |

**Önerilen ekran görüntüsü sırası:**
1. Radar ekranı — Schengen kartı + EES/ETIAS banner
2. AI Asistan — gerçek soru/yanıt
3. Ülke listesi — 23+ ülke kartları
4. Paywall — fiyat ve özellik listesi
5. Security Scanner — tarama ekranı

---

## App Icon

- [x] iOS: Gerçek ikon, 1024×1024 RGB, alpha yok. Tüm boyutlar mevcut.
- [x] Android: Adaptive icon yapılandırıldı (`pubspec.yaml` → flutter_launcher_icons).
  - Background: `#0B1120` (brandNavy)
  - Foreground: `assets/icons/app_icon.png`

---

## Age Rating

**iOS App Store:** 9+ (NINE_PLUS) — ASC'de `matureOrSuggestiveThemes: INFREQUENT_OR_MILD` ile ayarlandı (2026-07-29)
**Google Play:** IARC anketinde AI içeriği işaretle → beklenen sonuç 9+ veya 12+ (IARC bağımsız sistem)

---

## Pre-Submission Checklist

### App Store (iOS)
- [x] Gerçek uygulama ikonu (teal-navy gradyan + radar)
- [x] Privacy Policy URL canlı
- [x] Support URL canlı
- [x] Terms of Use URL canlı
- [x] IAP ürünleri: monthly $4.99, annual $34.99 (trial yok, lifetime yok)
- [x] Jailbreak detection (güvenlik)
- [x] KVKK ConsentGate (3 checkbox, bilingual)
- [ ] ASC → App Information → Support URL: `.../support` olduğunu teyit et
- [ ] ASC → App Information → Privacy Policy URL: `.../privacy` olduğunu teyit et
- [x] ASC → Age Rating: 9+ (API ile ayarlandı 2026-07-29)
- [ ] App Privacy (Data collection questionnaire) doldur

### Google Play (henüz gönderilmedi)
- [x] Android adaptive icon hazır
- [ ] Play Console'da uygulama kaydı oluştur
- [ ] Generative AI beyanı doldur
- [ ] Data Safety formu: Location, Microphone
- [ ] IARC yaş anketi → 12+
- [ ] Signed AAB: `flutter build appbundle --release`

---

## Legal & Compliance

| Madde | Durum |
|---|---|
| Privacy Policy | ✅ Canlı: `.../privacy` |
| Terms of Use | ✅ Canlı: `.../terms` |
| KVKK | ✅ ConsentGate 3 checkbox, bilingual |
| GDPR | ✅ Veri cihaz-yerel; AI sorular Anthropic'e iletilir (açıklandı) |
| Hesap silme | ✅ Muaf (hesap sistemi yok) |
| IAP doğrulama | ✅ Apple JWS ES256 gerçek doğrulama |
| AI beyanı | ⚠️ ASC + Play'de form doldurulmalı |

---

## Version History

### 1.3.0+7 (2026-07-29) — Güvenlik + Fonksiyonel + Business-Case + Performans
- Güvenlik: Worker KVKK consent, JWS doğrulama, jailbreak hard-block, Keychain txId
- Fonksiyonel: LocationProof+TravelLog radar hook, AI history kırpma, SOS arka plan
- Business-Case: ConsentGate bilingual, paywall dürüst dil, KKTC+BG EUR, EES/ETIAS
- Performans: Splash 800ms, TTS cache, magnetometre 10Hz, lazy lists

### 1.2.0+6 (2026-07) — APPROVED App Store
- İlk onaylanan sürüm

### 1.0.0 — İlk sürüm (eski)
- Temel Schengen takip
