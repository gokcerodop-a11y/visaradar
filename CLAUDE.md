# VisaRadar (VisaRadar Travel)

Premium global vize / sınır / Schengen kalış takip uygulaması (AI destekli). Telegram botu çalışıyor.

**App Store durumu (2026-07-12):** v1.2.0+6 **WAITING_FOR_REVIEW** — submission a76d0c61-dcfe-40bf-ad5c-9c7b3713864f. Bir sonraki güncellemede: 13 slaytlı karşılama turu, ElevenLabs TTS Dinle butonu (asistan+tur rehberi), Şehir keşfi bug fix, KVKK Ayarlar sayfası, kapsamlı legal.ts, **Derin Bilgi** (SHA-256 zincirli konum kanıtı), **Seyahat Takvimi** (günlük km/adım/şehir/not).

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
