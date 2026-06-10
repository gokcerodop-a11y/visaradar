import fs from "node:fs";
import { SignJWT, importPKCS8 } from "/Users/bahiko/Projects/apps/kanunlar_cebimde/workers/kanunlar-proxy/node_modules/jose/dist/node/esm/index.js";
const B = "https://api.appstoreconnect.apple.com";
async function tok() {
  const key = await importPKCS8(fs.readFileSync("/Users/bahiko/Downloads/AuthKey_SDUZJJP88A.p8", "utf8"), "ES256");
  return new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: "SDUZJJP88A", typ: "JWT" })
    .setIssuer("a8b3e068-98a4-4929-af96-52e370a38db7").setIssuedAt().setExpirationTime("18m")
    .setAudience("appstoreconnect-v1").sign(key);
}
async function states() {
  const t = await tok(); const H = { Authorization: "Bearer " + t };
  const g = async (p) => (await (await fetch(B + p, { headers: H })).json());
  const ap = await g("/v1/apps?filter[bundleId]=com.visaradar.visaradar");
  const grp = await g(`/v1/apps/${ap.data[0].id}/subscriptionGroups`);
  const subs = await g(`/v1/subscriptionGroups/${grp.data[0].id}/subscriptions`);
  const iaps = await g(`/v1/apps/${ap.data[0].id}/inAppPurchasesV2?limit=50`);
  const out = {};
  for (const s of (subs.data || [])) out[s.attributes.productId] = s.attributes.state;
  for (const p of (iaps.data || [])) out[p.attributes.productId] = p.attributes.state;
  return out;
}
const maxTries = 20; // ~10 min at 30s
for (let i = 0; i < maxTries; i++) {
  const st = await states();
  const allReady = Object.values(st).every((s) => s !== "MISSING_METADATA");
  const line = Object.entries(st).map(([k, v]) => `${k.split(".").pop()}=${v}`).join(" ");
  if (allReady) { console.log("READY: " + line); process.exit(0); }
  if (i === maxTries - 1) { console.log("STILL: " + line); process.exit(0); }
  await new Promise((r) => setTimeout(r, 30000));
}
