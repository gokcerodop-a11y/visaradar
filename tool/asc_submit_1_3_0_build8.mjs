// asc_submit_1_3_0_build8.mjs — attach build 8 (Xcode 26.6), cancel old sub, resubmit
import fs from "node:fs";
import { SignJWT, importPKCS8 } from "/Users/bahiko/Projects/apps/kanunlar_cebimde/workers/kanunlar-proxy/node_modules/jose/dist/node/esm/index.js";

const KID = "SDUZJJP88A";
const ISS = "a8b3e068-98a4-4929-af96-52e370a38db7";
const P8  = "/Users/bahiko/.private_keys/AuthKey_SDUZJJP88A.p8";
const BUNDLE = "com.visaradar.visaradar";
const BASE   = "https://api.appstoreconnect.apple.com";
const TARGET_VERSION = "1.3.0";
const TARGET_BUILD   = "8";

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

  // 2. Find existing iOS version 1.3.0
  const versR = await api("GET", `/v1/apps/${appId}/appStoreVersions?filter[versionString]=${TARGET_VERSION}&filter[platform]=IOS&limit=10`);
  const existing = (versR.json.data || []).find(v => v.attributes?.versionString === TARGET_VERSION);
  if (!existing) { console.error("Version 1.3.0 not found in ASC"); process.exit(1); }
  const versionId = existing.id;
  console.log("Version:", versionId, "state:", existing.attributes?.appVersionState || existing.attributes?.appStoreState);

  // 3. Wait for build 8 to become VALID (up to 30 min, poll every 30s)
  console.log("\nWaiting for build", TARGET_BUILD, "to be VALID...");
  let buildId = null;
  for (let attempt = 0; attempt < 60; attempt++) {
    const bR = await api("GET",
      `/v1/builds?filter[app]=${appId}&filter[version]=${TARGET_BUILD}&sort=-uploadedDate&limit=10`);
    const builds = bR.json.data || [];
    const valid = builds.find(b => b.attributes?.processingState === "VALID");
    if (valid) { buildId = valid.id; break; }
    const any = builds[0];
    if (any) {
      console.log(`  build ${any.attributes?.version} (${any.id}) state: ${any.attributes?.processingState} — waiting...`);
    } else {
      console.log(`  no build ${TARGET_BUILD} found yet — waiting...`);
    }
    await sleep(30_000);
  }
  if (!buildId) { console.error("Build never became VALID after 30 min. Check ASC manually."); process.exit(1); }
  console.log("Build VALID:", buildId);

  // 4. Set usesNonExemptEncryption:false (required before attaching)
  console.log("Setting usesNonExemptEncryption:false...");
  const encR = await api("PATCH", `/v1/builds/${buildId}`, {
    data: { id: buildId, type: "builds", attributes: { usesNonExemptEncryption: false } },
  });
  console.log("Encryption flag:", encR.ok ? "OK" : `err ${encR.status}`);

  // 5. Cancel any open review submissions
  const openSubR = await api("GET",
    `/v1/reviewSubmissions?filter[app]=${appId}&filter[platform]=IOS&limit=10`);
  for (const sub of (openSubR.json.data || [])) {
    const state = sub.attributes?.state;
    if (["READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"].includes(state)) {
      console.log("Cancelling submission:", sub.id, state);
      await api("PATCH", `/v1/reviewSubmissions/${sub.id}`, {
        data: { type: "reviewSubmissions", id: sub.id, attributes: { canceled: true } },
      });
      // Wait a bit for ASC to recompute version state
      await sleep(5_000);
    }
  }

  // 6. Attach build to version
  console.log("Attaching build", buildId, "to version", versionId, "...");
  const attachR = await api("PATCH", `/v1/appStoreVersions/${versionId}`, {
    data: {
      type: "appStoreVersions",
      id: versionId,
      relationships: { build: { data: { type: "builds", id: buildId } } },
    },
  });
  console.log("Attach:", attachR.ok ? "OK" : `err ${attachR.status}`, JSON.stringify(attachR.json).slice(0, 200));

  // 7. Create new review submission
  console.log("Creating review submission...");
  let subId;
  for (let attempt = 0; attempt < 5; attempt++) {
    const subR = await api("POST", "/v1/reviewSubmissions", {
      data: {
        type: "reviewSubmissions",
        attributes: { platform: "IOS" },
        relationships: { app: { data: { type: "apps", id: appId } } },
      },
    });
    if (subR.ok) { subId = subR.json.data.id; break; }
    console.log(`  submission create attempt ${attempt+1} failed (${subR.status}), retrying...`);
    await sleep(5_000);
  }
  if (!subId) { console.error("Could not create review submission"); process.exit(1); }
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
  if (!itemR.ok) {
    console.error("Add item failed:", itemR.status, JSON.stringify(itemR.json).slice(0, 300));
    process.exit(1);
  }
  console.log("Version added to submission.");

  // 9. Submit
  const finalR = await api("PATCH", `/v1/reviewSubmissions/${subId}`, {
    data: { type: "reviewSubmissions", id: subId, attributes: { submitted: true } },
  });
  if (!finalR.ok) {
    console.error("Submit failed:", finalR.status, JSON.stringify(finalR.json).slice(0, 300));
    process.exit(1);
  }
  console.log("\n✅ SUBMITTED FOR REVIEW — WAITING_FOR_REVIEW");
  console.log("Submission ID:", subId);
  console.log("Version:", TARGET_VERSION, "| Build:", TARGET_BUILD, "(Xcode 26.6)");
}

main().catch(e => { console.error(e); process.exit(1); });
