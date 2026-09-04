// 01_listing.mjs — Mağaza kaydı + görseller + AAB'yi tek edit içinde yükle.
// Sürüm TASLAK olarak bırakılır (internal track); hiçbir şey yayına çıkmaz.
// ÖN KOŞUL: uygulama Play Console'da zaten oluşturulmuş olmalı (applications.create API'de yok).
import fs from "node:fs";
import { PKG, api, upload, oz } from "./api.mjs";

const LANG = "tr-TR";
const AAB = "build/app/outputs/bundle/release/app-release.aab";
const ASSETS = "tool/play/assets";
const SHOTS = "tool/play/screenshots";
const metin = JSON.parse(fs.readFileSync("tool/play/listing-tr.json", "utf8"));

console.log("▸ edit açılıyor");
let r = await api("POST", `/applications/${PKG}/edits`, {});
if (!r.ok) { console.log("✗ edit açılamadı:", oz(r)); process.exit(1); }
const E = r.json.id;
console.log("  edit:", E);
const yol = `/applications/${PKG}/edits/${E}`;

// ── Uygulama ayrıntıları (iletişim + varsayılan dil) ──
r = await api("PATCH", `${yol}/details`, {
  defaultLanguage: LANG,
  contactEmail: "gokcerodop@gmail.com",
  contactWebsite: "https://visaradar-proxy.gokcerodop.workers.dev",
});
console.log("▸ iletişim/dil:", oz(r));

// ── Mağaza kaydı metinleri ──
r = await api("PUT", `${yol}/listings/${LANG}`, {
  language: LANG,
  title: metin.title,
  shortDescription: metin.shortDescription,
  fullDescription: metin.fullDescription,
});
console.log("▸ mağaza metinleri:", oz(r));

// ── Görseller ──
const gorseller = [
  ["icon",              `${ASSETS}/icon-512.png`],
  ["featureGraphic",   `${ASSETS}/feature-graphic-1024x500.png`],
  ["phoneScreenshots", `${SHOTS}/01_radar.png`],
  ["phoneScreenshots", `${SHOTS}/02_countries.png`],
  ["phoneScreenshots", `${SHOTS}/03_assistant.png`],
  ["phoneScreenshots", `${SHOTS}/04_schengen_tour.png`],
];
const temizlendi = new Set();
for (const [tur, dosya] of gorseller) {
  if (!fs.existsSync(dosya)) { console.log(`▸ ${tur}: dosya yok — ${dosya}`); continue; }
  if (!temizlendi.has(tur)) {
    await api("DELETE", `${yol}/listings/${LANG}/${tur}`);
    temizlendi.add(tur);
  }
  const u = await upload(
    `/upload/androidpublisher/v3/applications/${PKG}/edits/${E}/listings/${LANG}/${tur}?uploadType=media`,
    dosya, "image/png");
  console.log(`▸ ${tur} ← ${dosya.split("/").pop()}: ${oz(u)}`);
}

// ── AAB ──
console.log(`▸ AAB yükleniyor (${(fs.statSync(AAB).size / 1048576).toFixed(1)} MB) — sürebilir`);
const b = await upload(
  `/upload/androidpublisher/v3/applications/${PKG}/edits/${E}/bundles?uploadType=media`,
  AAB, "application/octet-stream");
console.log("  AAB:", oz(b));
if (!b.ok) { console.log("  edit iptal ediliyor"); await api("DELETE", yol); process.exit(1); }
const vc = b.json.versionCode;
console.log("  versionCode:", vc);

// ── İç test kanalı — TASLAK sürüm (yayına çıkmaz). PRODUCTION'a HİÇ dokunma. ──
r = await api("PUT", `${yol}/tracks/internal`, {
  track: "internal",
  releases: [{
    versionCodes: [String(vc)],
    status: "draft",
    releaseNotes: [{ language: LANG, text:
      "İlk Android sürümü. Yapay zekâ seyahat asistanı, Güvenlik Tarayıcı, Acil SOS, " +
      "Schengen 90/180 sayacı ve 23+ ülke rehberi." }],
  }],
});
console.log("▸ iç test kanalı (taslak):", oz(r));

// ── Doğrula ve commit ──
const d = await api("GET", `${yol}/listings/${LANG}`);
console.log("▸ kayıt doğrulama:", d.ok ? `başlık="${d.json.title}" kısa=${d.json.shortDescription?.length}k tam=${d.json.fullDescription?.length}k` : oz(d));

r = await api("POST", `${yol}:commit`);
console.log("▸ COMMIT:", oz(r));
if (!r.ok) { console.log("  → commit başarısız, edit duruyor:", E); process.exit(1); }
console.log("\n✓ Mağaza kaydı, görseller ve AAB yüklendi. Sürüm TASLAK (iç test) — yayına çıkmadı.");
