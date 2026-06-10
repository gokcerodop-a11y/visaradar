# VisaRadar (VisaRadar Travel)

Premium global vize / sınır / Schengen kalış takip uygulaması (AI destekli). Telegram botu çalışıyor.

**App Store durumu (2026-06-10):** v1.0.0 build 3 incelemede. Red turları aşıldı: 2.1(a) ikon (gerçek ikon kondu), 2.1(b) IAP-not-submitted (3 IAP versiyona bağlanıp gönderildi — ilk IAP yalnızca web arayüzünden, versiyon sayfası → "In-App Purchases and Subscriptions" bölümünden eklenir, .p8 API ile YAPILAMAZ). Son tur: 3.1.2(c) (abonelik metadata'sına EULA+gizlilik linki gerekti) + 2.1(b) Information Needed (reviewer IAP'leri bulamadı; muhtemelen paywall'daki Lifetime 3 gün gizli). 3.1.2(c) için worker'da `/privacy` + `/terms` sayfaları yayınlandı, ASC metadata güncellendi; 2.1(b) için "Reply to App Review"a IAP erişim adımları yazıldı (Information Needed = reply ile inceleme devam eder, resubmit gerekmez). Apple cevabı bekleniyor.

## Teknoloji & Mimari
- **İstemci:** Flutter (iOS + Android + web + masaüstü). **Melos monorepo** — `melos.yaml`, `packages/` (paylaşılan paketler), `lise_ai/`, omnicore workspace. Ana app `lib/`. i18n `l10n.yaml`.
- **Backend:** Cloudflare Worker `workers/visaradar-proxy` (TS). Claude proxy + rate-limit + KV + Apple receipt + Telegram bildirim.
- `tool/` (yardımcı scriptler, App Store), `docs/`, `assets/`.

## Önemli Sabitler
- Bundle id: `com.visaradar.visaradar` · App id: `6761065257` · Worker: `visaradar-proxy.gokcerodop.workers.dev`
- ASC key: ortak `~/Downloads/AuthKey_SDUZJJP88A.p8` (KID `SDUZJJP88A`, ISS `a8b3e068-98a4-4929-af96-52e370a38db7`). ASC otomasyonu: `tool/asc_visaradar.mjs` (status/verify/shots/builds).
- IAP ürünleri: `com.visaradar.premium.{monthly $4.99, annual $34.99 +3g deneme, lifetime $59.99}`.
- Yasal sayfalar (canlı, worker): `…workers.dev/privacy` ve `…workers.dev/terms` (EULA). Kaynak `workers/visaradar-proxy/src/legal.ts`. Not: `visaradar.app` alan adı yayında DEĞİL.

## Komutlar
- Monorepo: `melos bootstrap` (ilk kurulum) · `flutter pub get`
- `flutter analyze lib/`
- Cihazda test (profile): `flutter build ios --profile` → `xcrun devicectl device install app ...`
- Worker deploy: `cd workers/visaradar-proxy && npx wrangler@latest deploy`
- App Store: `tool/` scriptleri + ortak hafıza `appstore-upload-runbook`.

## Çalışma Kuralları
- Bir göreve başlamadan önce tüm projeyi tarama; sadece görevle ilgili dosyaları oku.
- Proje yapısı ve mimari kararlar bu dosyada özetlidir; dosya keşfi yerine önce burayı referans al.
