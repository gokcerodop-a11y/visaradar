// asc_visaradar_meta.mjs — ASC metadata updater:
//   1. Privacy URL teyidi (appInfoLocalizations) — zaten doğru
//   2. Support URL → appStoreVersionLocalizations (en-US + tr)
//   3. Age Rating 12+ → ageRatingDeclarations
import fs from "node:fs";
import { SignJWT, importPKCS8 } from "/Users/bahiko/Projects/apps/kanunlar_cebimde/workers/kanunlar-proxy/node_modules/jose/dist/node/esm/index.js";

const KID = "SDUZJJP88A";
const ISS = "a8b3e068-98a4-4929-af96-52e370a38db7";
const P8  = "/Users/bahiko/Downloads/AuthKey_SDUZJJP88A.p8";
const APP_ID = "6761065257";
const BASE   = "https://api.appstoreconnect.apple.com";

const SUPPORT_URL = "https://visaradar-proxy.gokcerodop.workers.dev/support";
const PRIVACY_URL = "https://visaradar-proxy.gokcerodop.workers.dev/privacy";

async function token() {
  const key = await importPKCS8(fs.readFileSync(P8, "utf8"), "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: KID, typ: "JWT" })
    .setIssuer(ISS).setIssuedAt().setExpirationTime("18m")
    .setAudience("appstoreconnect-v1").sign(key);
}
let _tok;
async function api(method, path, body) {
  _tok ||= await token();
  const r = await fetch(BASE + path, {
    method,
    headers: { Authorization: `Bearer ${_tok}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  let json; try { json = text ? JSON.parse(text) : {}; } catch { json = { raw: text }; }
  return { status: r.status, ok: r.ok, json };
}

// ── 1. Privacy URL teyidi ─────────────────────────────────────────────────────
async function checkPrivacyUrls() {
  console.log("\n── Privacy URL teyidi ──");
  const infos = await api("GET", `/v1/apps/${APP_ID}/appInfos?limit=10`);
  const info = (infos.json.data || [])[0];
  if (!info) { console.error("appInfo bulunamadı"); return; }
  const locs = await api("GET", `/v1/appInfos/${info.id}/appInfoLocalizations?limit=20`);
  for (const loc of (locs.json.data || [])) {
    const a = loc.attributes;
    const ok = a?.privacyPolicyUrl === PRIVACY_URL;
    console.log(`  [${a?.locale}] privacyPolicyUrl: ${ok ? "✅" : "❌"} ${a?.privacyPolicyUrl || "(none)"}`);
    if (!ok) {
      const r = await api("PATCH", `/v1/appInfoLocalizations/${loc.id}`, {
        data: { type: "appInfoLocalizations", id: loc.id,
          attributes: { privacyPolicyUrl: PRIVACY_URL } },
      });
      console.log(`    → ${r.ok ? "✅ güncellendi" : `❌ ${r.status} ${JSON.stringify(r.json).slice(0,200)}`}`);
    }
  }
}

// ── 2. Support URL (appStoreVersionLocalizations) ─────────────────────────────
async function updateSupportUrl() {
  console.log("\n── Support URL güncelleniyor ──");
  // No sort param — filter+sort combo breaks ASC API
  const vers = await api("GET", `/v1/apps/${APP_ID}/appStoreVersions?limit=5`);
  console.log("Versiyonlar:");
  for (const v of (vers.json.data || []))
    console.log(`  ${v.attributes?.versionString} [${v.attributes?.appStoreState}] id=${v.id}`);

  // Update the latest version's localizations
  const ver = (vers.json.data || [])[0];
  if (!ver) { console.error("Versiyon bulunamadı"); return; }
  console.log(`\n  → ${ver.attributes?.versionString} güncelleniyor...`);

  const vlocs = await api("GET", `/v1/appStoreVersions/${ver.id}/appStoreVersionLocalizations?limit=20`);
  for (const vloc of (vlocs.json.data || [])) {
    const a = vloc.attributes;
    const ok = a?.supportUrl === SUPPORT_URL;
    console.log(`  [${a?.locale}] supportUrl: ${ok ? "✅ zaten doğru" : (a?.supportUrl || "(none)")}`);
    if (!ok) {
      const r = await api("PATCH", `/v1/appStoreVersionLocalizations/${vloc.id}`, {
        data: { type: "appStoreVersionLocalizations", id: vloc.id,
          attributes: { supportUrl: SUPPORT_URL } },
      });
      console.log(`    → ${r.ok ? `✅ → ${r.json.data?.attributes?.supportUrl}` : `❌ ${r.status} ${JSON.stringify(r.json).slice(0,300)}`}`);
    }
  }
}

// ── 3. Age Rating 12+ ─────────────────────────────────────────────────────────
async function updateAgeRating() {
  console.log("\n── Age Rating 12+ güncelleniyor ──");
  const vers = await api("GET", `/v1/apps/${APP_ID}/appStoreVersions?limit=5`);
  const ver = (vers.json.data || [])[0];
  if (!ver) { console.error("Versiyon bulunamadı"); return; }
  console.log(`Versiyon: ${ver.attributes?.versionString} [${ver.attributes?.appStoreState}]`);

  const ardResp = await api("GET", `/v1/appStoreVersions/${ver.id}/ageRatingDeclaration`);
  if (!ardResp.ok) {
    console.error("ageRatingDeclaration alınamadı:", ardResp.status, JSON.stringify(ardResp.json).slice(0,200));
    return;
  }
  const ard = ardResp.json.data;
  const attrs = ard?.attributes || {};
  console.log("Declaration id:", ard?.id);
  console.log("Mevcut matureOrSuggestiveThemes:", attrs.matureOrSuggestiveThemes || "NONE");

  if (attrs.matureOrSuggestiveThemes === "INFREQUENT_OR_MILD") {
    console.log("✅ Zaten INFREQUENT_OR_MILD (12+)"); return;
  }

  const r = await api("PATCH", `/v1/ageRatingDeclarations/${ard.id}`, {
    data: { type: "ageRatingDeclarations", id: ard.id,
      attributes: { matureOrSuggestiveThemes: "INFREQUENT_OR_MILD" } },
  });
  if (r.ok) {
    console.log("✅ matureOrSuggestiveThemes →", r.json.data?.attributes?.matureOrSuggestiveThemes, "(12+)");
  } else {
    console.error("❌", r.status, JSON.stringify(r.json).slice(0, 400));
    // If READY_FOR_SALE is locked, try creating a new version record
    if (r.status === 409 || r.status === 422) {
      console.log("  → READY_FOR_SALE kilitli. v1.3.0 sürümü ASC'ye eklenirken ayarlanacak.");
    }
  }
}

await checkPrivacyUrls();
await updateSupportUrl();
await updateAgeRating();
console.log("\n✅ Tamamlandı.");
