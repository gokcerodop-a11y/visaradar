// 03_data_safety.mjs — Veri Güvenliği formunu Play Console'a gönderir.
//
// Google'ın CSV biçimi: "Response value" kolonuna TRUE/FALSE yazılır; seçilmeyen
// seçenekler ve isteğe bağlı sorular boş bırakılır. Şablon konsoldan
// "CSV'ye aktar" ile indirilir (kolon düzeni uydurulamaz).
//
// Kullanım: node tool/play/03_data_safety.mjs [dosya.csv]
import fs from "node:fs";
import { api, PKG, oz } from "./api.mjs";

const dosya = process.argv[2] ?? "tool/play/data_safety_dolu.csv";
const csv = fs.readFileSync(dosya, "utf8");
const satir = csv.trimEnd().split(/\r?\n/).length - 1;
console.log(`CSV: ${dosya} (${satir} satır, ${csv.length} bayt)`);

const r = await api("POST", `/applications/${PKG}/dataSafety`, { safetyLabels: csv });
console.log("dataSafety:", oz(r));
if (!r.ok) {
  console.log(JSON.stringify(r.json).slice(0, 1200));
  process.exit(1);
}
console.log("✓ Veri Güvenliği formu gönderildi.");
