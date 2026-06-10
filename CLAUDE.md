# VisaRadar (VisaRadar Travel)

Premium global vize / sınır / Schengen kalış takip uygulaması (AI destekli). İncelemeye gönderildi; Telegram botu çalışıyor.

## Teknoloji & Mimari
- **İstemci:** Flutter (iOS + Android + web + masaüstü). **Melos monorepo** — `melos.yaml`, `packages/` (paylaşılan paketler), `lise_ai/`, omnicore workspace. Ana app `lib/`. i18n `l10n.yaml`.
- **Backend:** Cloudflare Worker `workers/visaradar-proxy` (TS). Claude proxy + rate-limit + KV + Apple receipt + Telegram bildirim.
- `tool/` (yardımcı scriptler, App Store), `docs/`, `assets/`.

## Önemli Sabitler
- Bundle id: `com.visaradar.visaradar` · App id: `6761065257` · Worker: `visaradar-proxy.gokcerodop.workers.dev`
- ASC key: ortak `~/Downloads/AuthKey_SDUZJJP88A.p8`.

## Komutlar
- Monorepo: `melos bootstrap` (ilk kurulum) · `flutter pub get`
- `flutter analyze lib/`
- Cihazda test (profile): `flutter build ios --profile` → `xcrun devicectl device install app ...`
- Worker deploy: `cd workers/visaradar-proxy && npx wrangler@latest deploy`
- App Store: `tool/` scriptleri + ortak hafıza `appstore-upload-runbook`.

## Çalışma Kuralları
- Bir göreve başlamadan önce tüm projeyi tarama; sadece görevle ilgili dosyaları oku.
- Proje yapısı ve mimari kararlar bu dosyada özetlidir; dosya keşfi yerine önce burayı referans al.
