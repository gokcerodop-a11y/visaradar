// asc_submit_1_2_0.mjs — create v1.2.0, attach build 6, submit for review
import fs from "node:fs";
import crypto from "node:crypto";
import { SignJWT, importPKCS8 } from "/Users/bahiko/Projects/apps/kanunlar_cebimde/workers/kanunlar-proxy/node_modules/jose/dist/node/esm/index.js";

const KID = "SDUZJJP88A";
const ISS = "a8b3e068-98a4-4929-af96-52e370a38db7";
const P8  = "/Users/bahiko/.private_keys/AuthKey_SDUZJJP88A.p8";
const BUNDLE = "com.visaradar.visaradar";
const BASE   = "https://api.appstoreconnect.apple.com";
const TARGET_VERSION = "1.2.0";
const TARGET_BUILD   = "6";

let _tok;
async function token() {
  if (_tok) return _tok;
  const key = await importPKCS8(fs.readFileSync(P8, "utf8"), "ES256");
  _tok = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: KID, typ: "JWT" })
    .setIssuer(ISS).setIssuedAt().setExpirationTime("18m")
    .setAudience("appstoreconnect-v1").sign(key);
  return _tok;
}

async function api(method, path, body) {
  const tok = await token();
  const r = await fetch(BASE + path, {
    method,
    headers: { Authorization: `Bearer ${tok}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  let json; try { json = text ? JSON.parse(text) : {}; } catch { json = { raw: text }; }
  if (!r.ok && r.status !== 409) {
    console.error(`[${method} ${path}] ${r.status}:`, JSON.stringify(json).slice(0, 400));
  }
  return { status: r.status, ok: r.ok, json };
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  // 1. Find app
  const appR = await api("GET", `/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE)}&limit=5`);
  const app  = (appR.json.data || [])[0];
  if (!app) { console.error("App not found"); process.exit(1); }
  const appId = app.id;
  console.log("App ID:", appId, app.attributes?.name);

  // 2. Find or create iOS version 1.2.0
  let versionId;
  const versR = await api("GET", `/v1/apps/${appId}/appStoreVersions?filter[versionString]=${TARGET_VERSION}&filter[platform]=IOS&limit=10`);
  const existing = (versR.json.data || []).find(v => v.attributes?.versionString === TARGET_VERSION);
  if (existing) {
    versionId = existing.id;
    console.log("Existing version found:", versionId, "state:", existing.attributes?.appVersionState || existing.attributes?.appStoreState);
  } else {
    console.log("Creating new version", TARGET_VERSION, "...");
    const createR = await api("POST", "/v1/appStoreVersions", {
      data: {
        type: "appStoreVersions",
        attributes: { platform: "IOS", versionString: TARGET_VERSION },
        relationships: { app: { data: { type: "apps", id: appId } } },
      },
    });
    if (!createR.ok) { console.error("Failed to create version"); process.exit(1); }
    versionId = createR.json.data.id;
    console.log("Created version:", versionId);
  }

  // 3. Wait for build 6 to become valid (up to 10 min)
  console.log("\nWaiting for build", TARGET_BUILD, "to be VALID...");
  let buildId = null;
  for (let attempt = 0; attempt < 20; attempt++) {
    const bR = await api("GET",
      `/v1/builds?filter[app]=${appId}&filter[version]=${TARGET_BUILD}&filter[preReleaseVersion.version]=${TARGET_VERSION}&sort=-uploadedDate&limit=10`);
    const builds = bR.json.data || [];
    const valid = builds.find(b => b.attributes?.processingState === "VALID");
    if (valid) { buildId = valid.id; break; }
    const any = builds[0];
    if (any) {
      console.log(`  build ${any.attributes?.version}+${any.attributes?.buildNumber || ''} state: ${any.attributes?.processingState} — waiting...`);
    } else {
      console.log(`  no builds found yet — waiting...`);
    }
    await sleep(30_000);
  }
  if (!buildId) { console.error("Build never became VALID after 10 min. Check ASC manually."); process.exit(1); }
  console.log("Build valid:", buildId);

  // 4. Attach build to version
  console.log("Attaching build to version...");
  const attachR = await api("PATCH", `/v1/appStoreVersions/${versionId}`, {
    data: {
      type: "appStoreVersions",
      id: versionId,
      relationships: { build: { data: { type: "builds", id: buildId } } },
    },
  });
  if (!attachR.ok) {
    console.error("Attach failed — checking state:", attachR.status);
  } else {
    console.log("Build attached.");
  }

  // 5. Set release notes (English + Turkish localizations)
  const notesEn = "What's New in 1.2.0:\n• Emergency SOS: loud alarm + SOS Morse torch + GPS location SMS to 2 contacts\n• 8-page feature tour on first launch\n• Tax-Free Guide: step-by-step refund process for 10 countries\n• AI Tour Guide: photograph a landmark to get tour guide info\n• Enhanced country data: daytime running lights, winter tyres, safety vest\n• AI Assistant: 12 example travel queries\n• Bug fixes and performance improvements";
  const notesTr = "1.2.0 Sürümündeki Yenilikler:\n• Acil SOS: yüksek sesli alarm + SOS Morse ışık sinyali + 2 acil kişiye GPS konum SMS\n• İlk açılışta 8 sayfalık özellik turu\n• Tax-Free Rehberi: 10 ülkede adım adım vergi iadesi\n• AI Tur Rehberi: anıt fotoğrafla tur rehberi bilgisi\n• Gelişmiş ülke verisi: yansıyan farlar, kış lastikleri, güvenlik yeleği\n• AI Asistan: 12 örnek seyahat sorusu\n• Hata düzeltmeleri ve performans iyileştirmeleri";

  const locR = await api("GET", `/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=10`);
  const locs = locR.json.data || [];
  for (const loc of locs) {
    const locale = loc.attributes?.locale;
    const notes  = locale === "tr" ? notesTr : notesEn;
    await api("PATCH", `/v1/appStoreVersionLocalizations/${loc.id}`, {
      data: { type: "appStoreVersionLocalizations", id: loc.id,
              attributes: { whatsNew: notes } },
    });
    console.log("Release notes set for locale:", locale);
  }

  // 6. Cancel any open review submission for this version
  const openSubR = await api("GET",
    `/v1/reviewSubmissions?filter[app]=${appId}&filter[platform]=IOS&limit=10`);
  for (const sub of (openSubR.json.data || [])) {
    const state = sub.attributes?.state;
    if (state === "READY_FOR_REVIEW" || state === "WAITING_FOR_REVIEW" || state === "IN_REVIEW") {
      console.log("Cancelling open submission:", sub.id, state);
      await api("PATCH", `/v1/reviewSubmissions/${sub.id}`, {
        data: { type: "reviewSubmissions", id: sub.id, attributes: { canceled: true } },
      });
    }
  }

  // 7. Create new review submission
  console.log("Creating review submission...");
  const subR = await api("POST", "/v1/reviewSubmissions", {
    data: {
      type: "reviewSubmissions",
      attributes: { platform: "IOS" },
      relationships: { app: { data: { type: "apps", id: appId } } },
    },
  });
  if (!subR.ok) { console.error("Create submission failed"); process.exit(1); }
  const subId = subR.json.data.id;
  console.log("Submission created:", subId);

  // 8. Add version to submission
  const itemR = await api("POST", "/v1/reviewSubmissionItems", {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { type: "reviewSubmissions", id: subId } },
        appStoreVersion:  { data: { type: "appStoreVersions",  id: versionId } },
      },
    },
  });
  if (!itemR.ok) { console.error("Add item failed"); process.exit(1); }
  console.log("Version added to submission.");

  // 9. Submit
  const finalR = await api("PATCH", `/v1/reviewSubmissions/${subId}`, {
    data: { type: "reviewSubmissions", id: subId, attributes: { submitted: true } },
  });
  if (!finalR.ok) { console.error("Submit failed:", finalR.status); process.exit(1); }
  console.log("\n✅ SUBMITTED FOR REVIEW — WAITING_FOR_REVIEW");
  console.log("Submission ID:", subId);
  console.log("Version:", TARGET_VERSION, "| Build:", TARGET_BUILD);
}

main().catch(e => { console.error(e); process.exit(1); });
