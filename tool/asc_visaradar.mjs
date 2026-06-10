// asc_visaradar.mjs — App Store Connect automation for VisaRadar.
// Reuses the account-level ASC API key (SDUZJJP88A). Commands:
//   status   : show app + existing IAP products
//   iap      : create monthly + annual subscriptions (price + trial on annual)
//   lifetime : create the lifetime non-consumable IAP (+ price)
import fs from "node:fs";
import crypto from "node:crypto";
import { SignJWT, importPKCS8 } from "/Users/bahiko/Projects/apps/kanunlar_cebimde/workers/kanunlar-proxy/node_modules/jose/dist/node/esm/index.js";

const SHOT = "/Users/bahiko/Projects/apps/visaradar/docs/iap_review_shot.png";

const KID = process.env.ASC_KID || "SDUZJJP88A";
const ISS = process.env.ASC_ISS || "a8b3e068-98a4-4929-af96-52e370a38db7";
const P8 = process.env.ASC_P8 || "/Users/bahiko/Downloads/AuthKey_SDUZJJP88A.p8";
const BUNDLE = "com.visaradar.visaradar";
const BASE = "https://api.appstoreconnect.apple.com";

// USD targets (Apple localizes to other territories automatically).
const TERRITORY = "USA";
const SUBS = [
  { productId: "com.visaradar.premium.monthly", period: "ONE_MONTH",
    refName: "VisaRadar Premium Monthly", display: "Monthly Premium", target: 4.99, trial: null },
  { productId: "com.visaradar.premium.annual", period: "ONE_YEAR",
    refName: "VisaRadar Premium Annual", display: "Annual Premium", target: 34.99, trial: "THREE_DAYS" },
];
const LIFETIME = { productId: "com.visaradar.premium.lifetime",
  refName: "VisaRadar Premium Lifetime", display: "Lifetime Premium", target: 59.99 };

async function token() {
  const key = await importPKCS8(fs.readFileSync(P8, "utf8"), "ES256");
  return new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: KID, typ: "JWT" })
    .setIssuer(ISS).setIssuedAt().setExpirationTime("18m")
    .setAudience("appstoreconnect-v1").sign(key);
}
let _tok;
async function api(method, path, body) {
  _tok ||= await token();
  const r = await fetch(BASE + path, {
    method, headers: { Authorization: `Bearer ${_tok}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  let json; try { json = text ? JSON.parse(text) : {}; } catch { json = { raw: text }; }
  return { status: r.status, ok: r.ok, json };
}
async function findApp() {
  const r = await api("GET", `/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE)}&limit=200`);
  return (r.json.data || [])[0] || null;
}
async function ensureSubGroup(appId) {
  const g = await api("GET", `/v1/apps/${appId}/subscriptionGroups?limit=10`);
  let grp = (g.json.data || [])[0];
  if (grp) { console.log("sub group exists:", grp.id); return grp.id; }
  const c = await api("POST", "/v1/subscriptionGroups", {
    data: { type: "subscriptionGroups", attributes: { referenceName: "VisaRadar Premium" },
      relationships: { app: { data: { type: "apps", id: appId } } } } });
  if (!c.ok) { console.error("group err:", c.status, JSON.stringify(c.json).slice(0,300)); process.exit(1); }
  console.log("sub group created:", c.json.data.id);
  return c.json.data.id;
}
let _territories;
async function allTerritories() {
  if (_territories) return _territories;
  const r = await api("GET", "/v1/territories?limit=200");
  _territories = (r.json.data || []).map((t) => ({ type: "territories", id: t.id }));
  return _territories;
}
async function ensureSubAvailability(subId) {
  const cur = await api("GET", `/v1/subscriptions/${subId}/subscriptionAvailability`);
  if (cur.ok && cur.json.data) { console.log("  availability exists"); return; }
  const terr = await allTerritories();
  const r = await api("POST", "/v1/subscriptionAvailabilities", {
    data: { type: "subscriptionAvailabilities",
      attributes: { availableInNewTerritories: true },
      relationships: {
        subscription: { data: { type: "subscriptions", id: subId } },
        availableTerritories: { data: terr },
      } } });
  console.log("  availability:", r.ok ? `OK (${terr.length} terr)` : `err ${r.status} ${JSON.stringify(r.json).slice(0,200)}`);
}
async function setupIap(appId) {
  const groupId = await ensureSubGroup(appId);
  const existing = await api("GET", `/v1/subscriptionGroups/${groupId}/subscriptions?limit=50`);
  const have = {};
  for (const s of (existing.json.data || [])) have[s.attributes?.productId] = s;
  for (const sub of SUBS) {
    let subObj = have[sub.productId];
    if (subObj) console.log(`\n[${sub.productId}] exists:`, subObj.id);
    else {
      const c = await api("POST", "/v1/subscriptions", {
        data: { type: "subscriptions", attributes: {
          name: sub.refName, productId: sub.productId, subscriptionPeriod: sub.period,
          familySharable: false, groupLevel: 1,
        }, relationships: { group: { data: { type: "subscriptionGroups", id: groupId } } } } });
      if (!c.ok) { console.error(`[${sub.productId}] create failed:`, c.status, JSON.stringify(c.json).slice(0,400)); continue; }
      subObj = c.json.data; console.log(`\n[${sub.productId}] created:`, subObj.id);
    }
    const subId = subObj.id;
    // localization
    const locs = await api("GET", `/v1/subscriptions/${subId}/subscriptionLocalizations?limit=50`);
    if (!(locs.json.data || []).some((l) => (l.attributes?.locale||"").startsWith("en"))) {
      const lc = await api("POST", "/v1/subscriptionLocalizations", {
        data: { type: "subscriptionLocalizations", attributes: { locale: "en-US", name: sub.display,
          description: "AI assistant, scanner, border mode" },
          relationships: { subscription: { data: { type: "subscriptions", id: subId } } } } });
      console.log("  en loc:", lc.ok ? "OK" : `err ${lc.status} ${JSON.stringify(lc.json).slice(0,150)}`);
    }
    // tr localization too
    if (!(locs.json.data || []).some((l) => (l.attributes?.locale||"").startsWith("tr"))) {
      const lc2 = await api("POST", "/v1/subscriptionLocalizations", {
        data: { type: "subscriptionLocalizations", attributes: { locale: "tr", name: sub.display === "Monthly Premium" ? "Aylık Premium" : "Yıllık Premium",
          description: "AI asistan, belge tarayıcı ve sınır modunun kilidini aç" },
          relationships: { subscription: { data: { type: "subscriptions", id: subId } } } } });
      console.log("  tr loc:", lc2.ok ? "OK" : `err ${lc2.status} ${JSON.stringify(lc2.json).slice(0,150)}`);
    }
    // availability (required before price + trial)
    await ensureSubAvailability(subId);
    // price
    const prices = await api("GET", `/v1/subscriptions/${subId}/prices?limit=10`);
    if ((prices.json.data || []).length === 0) {
      const pp = await api("GET", `/v1/subscriptions/${subId}/pricePoints?filter[territory]=${TERRITORY}&limit=8000`);
      let best = null, bestDiff = 1e9;
      for (const p of (pp.json.data || [])) {
        const cp = parseFloat(p.attributes?.customerPrice || "0");
        const d = Math.abs(cp - sub.target);
        if (d < bestDiff) { bestDiff = d; best = p; }
      }
      if (best) {
        console.log(`  price point: $${best.attributes.customerPrice} (target ${sub.target})`);
        const pr = await api("POST", "/v1/subscriptionPrices", {
          data: { type: "subscriptionPrices", attributes: { preserveCurrentPrice: false },
            relationships: { subscription: { data: { type: "subscriptions", id: subId } },
              subscriptionPricePoint: { data: { type: "subscriptionPricePoints", id: best.id } } } } });
        console.log("  price:", pr.ok ? "OK" : `err ${pr.status} ${JSON.stringify(pr.json).slice(0,400)}`);
      } else console.log("  no price point found");
    } else console.log("  price exists");
    // trial
    if (sub.trial) {
      const io = await api("GET", `/v1/subscriptions/${subId}/introductoryOffers?limit=10`);
      if ((io.json.data || []).length === 0) {
        const off = await api("POST", "/v1/subscriptionIntroductoryOffers", {
          data: { type: "subscriptionIntroductoryOffers", attributes: {
            duration: sub.trial, numberOfPeriods: 1, offerMode: "FREE_TRIAL",
          }, relationships: {
            subscription: { data: { type: "subscriptions", id: subId } },
            territory: { data: { type: "territories", id: TERRITORY } },
          } } });
        console.log(`  ${sub.trial} trial:`, off.ok ? "OK" : `err ${off.status} ${JSON.stringify(off.json).slice(0,400)}`);
      } else console.log("  trial exists");
    }
  }
}
async function setupLifetime(appId) {
  const existing = await api("GET", `/v1/apps/${appId}/inAppPurchasesV2?limit=200`);
  let iap = (existing.json.data || []).find((p) => p.attributes?.productId === LIFETIME.productId);
  if (iap) console.log("[lifetime] exists:", iap.id);
  else {
    const c = await api("POST", "/v2/inAppPurchases", {
      data: { type: "inAppPurchases", attributes: {
        name: LIFETIME.refName, productId: LIFETIME.productId,
        inAppPurchaseType: "NON_CONSUMABLE", reviewNote: "Unlocks all Premium features permanently.",
      }, relationships: { app: { data: { type: "apps", id: appId } } } } });
    if (!c.ok) { console.error("[lifetime] create failed:", c.status, JSON.stringify(c.json).slice(0,500)); return; }
    iap = c.json.data; console.log("[lifetime] created:", iap.id);
  }
  // localization
  const locs = await api("GET", `/v2/inAppPurchases/${iap.id}/inAppPurchaseLocalizations?limit=50`);
  if (!(locs.json.data || []).some((l) => (l.attributes?.locale||"").startsWith("en"))) {
    const lc = await api("POST", "/v1/inAppPurchaseLocalizations", {
      data: { type: "inAppPurchaseLocalizations", attributes: { locale: "en-US",
        name: LIFETIME.display, description: "Lifetime access to all Premium features" },
        relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: iap.id } } } } });
    console.log("  en loc:", lc.ok ? "OK" : `err ${lc.status} ${JSON.stringify(lc.json).slice(0,200)}`);
  }
  // price
  const sched = await api("GET", `/v2/inAppPurchases/${iap.id}/iapPriceSchedule`);
  if (!sched.ok || !sched.json.data) {
    const pp = await api("GET", `/v2/inAppPurchases/${iap.id}/pricePoints?filter[territory]=${TERRITORY}&limit=8000`);
    let best = null, bestDiff = 1e9;
    for (const p of (pp.json.data || [])) {
      const cp = parseFloat(p.attributes?.customerPrice || "0");
      const d = Math.abs(cp - LIFETIME.target);
      if (d < bestDiff) { bestDiff = d; best = p; }
    }
    if (best) {
      console.log(`  price point: $${best.attributes.customerPrice} (target ${LIFETIME.target})`);
      const pr = await api("POST", "/v1/inAppPurchasePriceSchedules", {
        data: { type: "inAppPurchasePriceSchedules",
          relationships: {
            inAppPurchase: { data: { type: "inAppPurchases", id: iap.id } },
            manualPrices: { data: [{ type: "inAppPurchasePrices", id: "${price}" }] },
            baseTerritory: { data: { type: "territories", id: TERRITORY } },
          } },
        included: [{ type: "inAppPurchasePrices", id: "${price}",
          attributes: { startDate: null },
          relationships: {
            inAppPurchaseV2: { data: { type: "inAppPurchases", id: iap.id } },
            inAppPurchasePricePoint: { data: { type: "inAppPurchasePricePoints", id: best.id } } } }] });
      console.log("  price:", pr.ok ? "OK" : `err ${pr.status} ${JSON.stringify(pr.json).slice(0,500)}`);
    } else console.log("  no price point found");
  } else console.log("  price schedule exists");
}

async function verify(appId) {
  // App base price (free?)
  const aps = await api("GET", `/v1/apps/${appId}/appPriceSchedule?include=manualPrices,baseTerritory`);
  console.log("APP price schedule:", aps.ok && aps.json.data ? "set" : "NOT SET");
  if (aps.json.included) {
    for (const inc of aps.json.included) {
      if (inc.type === "appPrices") console.log("  app price point id:", inc.relationships?.appPricePoint?.data?.id || "(see schedule)");
    }
  }
  // Subscriptions
  const groups = await api("GET", `/v1/apps/${appId}/subscriptionGroups?limit=10`);
  for (const g of (groups.json.data || [])) {
    const subs = await api("GET", `/v1/subscriptionGroups/${g.id}/subscriptions?limit=50`);
    for (const s of (subs.json.data || [])) {
      const id = s.id, a = s.attributes;
      const pr = await api("GET", `/v1/subscriptions/${id}/prices?include=subscriptionPricePoint&limit=10`);
      let priceStr = "NO PRICE";
      const pts = (pr.json.included || []).filter((i) => i.type === "subscriptionPricePoints");
      if (pts.length) priceStr = "$" + pts.map((p) => p.attributes?.customerPrice).join(",");
      const io = await api("GET", `/v1/subscriptions/${id}/introductoryOffers?limit=10`);
      const offers = (io.json.data || []).map((o) => `${o.attributes?.offerMode}/${o.attributes?.duration}`);
      console.log(`SUB ${a.productId} [${a.state}] ${priceStr} trial=[${offers.join(";") || "none"}]`);
    }
  }
  // Non-consumables
  const iaps = await api("GET", `/v1/apps/${appId}/inAppPurchasesV2?limit=50`);
  for (const p of (iaps.json.data || [])) {
    const sched = await api("GET", `/v2/inAppPurchases/${p.id}/iapPriceSchedule?include=manualPrices`);
    const pts = (sched.json.included || []).filter((i) => i.type === "inAppPurchasePricePoints");
    const priceStr = pts.length ? "$" + pts.map((x) => x.attributes?.customerPrice).join(",") : "price set (point not expanded)";
    console.log(`IAP ${p.attributes?.productId} [${p.attributes?.state}] ${sched.ok ? priceStr : "NO PRICE"}`);
  }
}
async function appFree(appId) {
  const cur = await api("GET", `/v1/apps/${appId}/appPriceSchedule`);
  if (cur.ok && cur.json.data) { console.log("app price schedule already set"); return; }
  const pp = await api("GET", `/v1/apps/${appId}/appPricePoints?filter[territory]=${TERRITORY}&limit=8000`);
  const free = (pp.json.data || []).find((p) => parseFloat(p.attributes?.customerPrice || "1") === 0);
  if (!free) { console.log("free price point not found"); return; }
  const r = await api("POST", "/v1/appPriceSchedules", {
    data: { type: "appPriceSchedules",
      relationships: {
        app: { data: { type: "apps", id: appId } },
        baseTerritory: { data: { type: "territories", id: TERRITORY } },
        manualPrices: { data: [{ type: "appPrices", id: "${p}" }] },
      } },
    included: [{ type: "appPrices", id: "${p}", attributes: { startDate: null },
      relationships: { app: { data: { type: "apps", id: appId } },
        appPricePoint: { data: { type: "appPricePoints", id: free.id } } } }] });
  console.log("app free price:", r.ok ? "OK" : `err ${r.status} ${JSON.stringify(r.json).slice(0,400)}`);
}

// Upload one review screenshot to a subscription or non-consumable IAP.
async function uploadReviewShot(kind, id, label) {
  const relType = kind === "sub" ? "subscriptions" : "inAppPurchases";
  const relName = kind === "sub" ? "subscription" : "inAppPurchaseV2";
  const resource = kind === "sub"
    ? "subscriptionAppStoreReviewScreenshots"
    : "inAppPurchaseAppStoreReviewScreenshots";
  const relPath = kind === "sub"
    ? `/v1/subscriptions/${id}/appStoreReviewScreenshot`
    : `/v2/inAppPurchases/${id}/appStoreReviewScreenshot`;

  const cur = await api("GET", relPath);
  if (cur.ok && cur.json.data) { console.log(`${label}: screenshot exists`); return; }

  const bytes = fs.readFileSync(SHOT);
  const res = await api("POST", `/v1/${resource}`, {
    data: { type: resource, attributes: { fileName: "paywall.png", fileSize: bytes.length },
      relationships: { [relName]: { data: { type: relType, id } } } } });
  if (!res.ok) { console.error(`${label}: reserve err ${res.status} ${JSON.stringify(res.json).slice(0,250)}`); return; }
  const shot = res.json.data;
  for (const op of (shot.attributes.uploadOperations || [])) {
    const headers = {};
    for (const h of (op.requestHeaders || [])) headers[h.name] = h.value;
    const chunk = bytes.subarray(op.offset, op.offset + op.length);
    const up = await fetch(op.url, { method: op.method, headers, body: chunk });
    if (!up.ok) console.error(`${label}: upload op ${up.status}`);
  }
  const md5 = crypto.createHash("md5").update(bytes).digest("hex");
  const commit = await api("PATCH", `/v1/${resource}/${shot.id}`, {
    data: { type: resource, id: shot.id, attributes: { uploaded: true, sourceFileChecksum: md5 } } });
  console.log(`${label}:`, commit.ok ? "screenshot OK" : `commit err ${commit.status} ${JSON.stringify(commit.json).slice(0,200)}`);
}

async function ensureGroupLoc(appId) {
  const groups = await api("GET", `/v1/apps/${appId}/subscriptionGroups?limit=10`);
  for (const g of (groups.json.data || [])) {
    const locs = await api("GET", `/v1/subscriptionGroups/${g.id}/subscriptionGroupLocalizations?limit=20`);
    const have = new Set((locs.json.data || []).map((l) => l.attributes?.locale));
    for (const [loc, name] of [["en-US", "VisaRadar Premium"], ["tr", "VisaRadar Premium"]]) {
      if (have.has(loc)) { console.log(`group loc ${loc} exists`); continue; }
      const r = await api("POST", "/v1/subscriptionGroupLocalizations", {
        data: { type: "subscriptionGroupLocalizations", attributes: { name, locale: loc },
          relationships: { subscriptionGroup: { data: { type: "subscriptionGroups", id: g.id } } } } });
      console.log(`group loc ${loc}:`, r.ok ? "OK" : `err ${r.status} ${JSON.stringify(r.json).slice(0,200)}`);
    }
  }
}

async function uploadAllShots(appId) {
  const groups = await api("GET", `/v1/apps/${appId}/subscriptionGroups?limit=10`);
  for (const g of (groups.json.data || [])) {
    const subs = await api("GET", `/v1/subscriptionGroups/${g.id}/subscriptions?limit=50`);
    for (const s of (subs.json.data || []))
      await uploadReviewShot("sub", s.id, s.attributes?.productId);
  }
  const iaps = await api("GET", `/v1/apps/${appId}/inAppPurchasesV2?limit=50`);
  for (const p of (iaps.json.data || []))
    await uploadReviewShot("iap", p.id, p.attributes?.productId);
}

async function listBuilds(appId) {
  const r = await api("GET", `/v1/builds?filter[app]=${appId}&sort=-uploadedDate&limit=8&include=preReleaseVersion`);
  const vers = {};
  for (const inc of (r.json.included || [])) if (inc.type === "preReleaseVersions") vers[inc.id] = inc.attributes?.version;
  const out = [];
  for (const b of (r.json.data || [])) {
    const vId = b.relationships?.preReleaseVersion?.data?.id;
    out.push({ id: b.id, version: vers[vId] || "?", build: b.attributes?.version,
      state: b.attributes?.processingState, expired: b.attributes?.expired,
      uploaded: b.attributes?.uploadedDate });
  }
  return out;
}

async function tfInspect(appId) {
  const g = await api("GET", `/v1/apps/${appId}/betaGroups?include=betaTesters&limit=50`);
  for (const grp of (g.json.data || [])) {
    const a = grp.attributes;
    const testers = grp.relationships?.betaTesters?.data?.length ?? 0;
    console.log(`group "${a.name}" internal=${a.isInternalGroup} id=${grp.id} testers=${testers}`);
  }
  const builds = await listBuilds(appId);
  const target = builds.find((b) => b.version === "1.0.0" && b.build === "2");
  if (target) {
    const bd = await api("GET", `/v1/builds/${target.id}?fields[builds]=usesNonExemptEncryption`);
    console.log("build 1.0.0(2) usesNonExemptEncryption:", bd.json.data?.attributes?.usesNonExemptEncryption);
  }
  // Account-holder users
  const users = await api("GET", `/v1/users?limit=20`);
  for (const u of (users.json.data || []))
    console.log(`user ${u.attributes?.username} roles=${(u.attributes?.roles||[]).join(",")} id=${u.id}`);
}

async function tfSend(appId) {
  // 1. internal beta group
  const g = await api("GET", `/v1/apps/${appId}/betaGroups?limit=50`);
  let grp = (g.json.data || []).find((x) => x.attributes?.isInternalGroup);
  if (!grp) {
    const c = await api("POST", "/v1/betaGroups", {
      data: { type: "betaGroups",
        attributes: { name: "Internal Testers", isInternalGroup: true },
        relationships: { app: { data: { type: "apps", id: appId } } } } });
    if (!c.ok) { console.error("group create err:", c.status, JSON.stringify(c.json).slice(0,400)); return; }
    grp = c.json.data;
    console.log("internal group created:", grp.id, "isInternal=", grp.attributes?.isInternalGroup);
  } else console.log("internal group exists:", grp.id);

  // 2. add account holder as internal tester
  const t = await api("POST", "/v1/betaTesters", {
    data: { type: "betaTesters",
      attributes: { email: "gokcerodop@gmail.com", firstName: "Gokce", lastName: "Rodop" },
      relationships: { betaGroups: { data: [{ type: "betaGroups", id: grp.id }] } } } });
  console.log("tester:", t.ok ? "added" : `(${t.status} ${JSON.stringify(t.json).slice(0,160)})`);

  // 3. attach build 1.0.0(2) to the group
  const builds = await listBuilds(appId);
  const target = builds.find((b) => b.version === "1.0.0" && b.build === "2");
  if (!target) { console.error("build 1.0.0(2) not found"); return; }
  const ab = await api("POST", `/v1/betaGroups/${grp.id}/relationships/builds`, {
    data: [{ type: "builds", id: target.id }] });
  console.log("attach build:", ab.ok ? "OK" : `(${ab.status} ${JSON.stringify(ab.json).slice(0,200)})`);
}

// Equalize a subscription's price across ALL territories from its base price
// point (the USA point already set). Without this, a sub available in 175
// territories but priced in 1 stays MISSING_METADATA.
async function fixPrices(appId) {
  const groups = await api("GET", `/v1/apps/${appId}/subscriptionGroups?limit=10`);
  for (const g of (groups.json.data || [])) {
    const subs = await api("GET", `/v1/subscriptionGroups/${g.id}/subscriptions?limit=50`);
    for (const s of (subs.json.data || [])) {
      const subId = s.id;
      const cur = await api("GET",
        `/v1/subscriptions/${subId}/prices?include=subscriptionPricePoint&limit=200`);
      const existing = cur.json.data || [];
      if (existing.length > 5) {
        console.log(`${s.attributes.productId}: ${existing.length} prices already — skip`);
        continue;
      }
      const basePointId =
        existing[0]?.relationships?.subscriptionPricePoint?.data?.id;
      if (!basePointId) { console.log(`${s.attributes.productId}: no base price`); continue; }
      // All equalized price points (one per territory) for the base point.
      const eq = await api("GET",
        `/v1/subscriptionPricePoints/${basePointId}/equalizations?limit=200`);
      const points = eq.json.data || [];
      let ok = 0, skip = 0;
      for (const p of points) {
        const r = await api("POST", "/v1/subscriptionPrices", {
          data: { type: "subscriptionPrices", attributes: { preserveCurrentPrice: false },
            relationships: {
              subscription: { data: { type: "subscriptions", id: subId } },
              subscriptionPricePoint: { data: { type: "subscriptionPricePoints", id: p.id } },
            } } });
        if (r.ok) ok++; else skip++;
      }
      console.log(`${s.attributes.productId}: +${ok} territory prices (${skip} skipped), base point had ${points.length} equalizations`);
    }
  }
}

async function submitForReview(appId) {
  // 1. Target version (the rejected / prepare-for-submission one).
  const vers = await api("GET", `/v1/apps/${appId}/appStoreVersions?limit=5`);
  const ver = (vers.json.data || [])[0];
  if (!ver) { console.error("no app store version"); return; }
  console.log(`version ${ver.attributes.versionString} state=${ver.attributes.appStoreState} id=${ver.id}`);

  // 2. Latest build (1.0.0 build 3).
  const builds = await listBuilds(appId);
  const b = builds.find((x) => x.version === "1.0.0" && x.build === "3") ||
            builds.find((x) => !x.expired);
  console.log(`using build ${b.version}(${b.build}) id=${b.id}`);

  // 3. Align versionString to the build + attach the build.
  const pv = await api("PATCH", `/v1/appStoreVersions/${ver.id}`, {
    data: { type: "appStoreVersions", id: ver.id,
      attributes: { versionString: "1.0.0" } } });
  console.log("set versionString 1.0.0:", pv.ok ? "OK" : `(${pv.status} ${JSON.stringify(pv.json.errors?.[0]?.detail||pv.json).slice(0,160)})`);
  const ab = await api("PATCH", `/v1/appStoreVersions/${ver.id}`, {
    data: { type: "appStoreVersions", id: ver.id,
      relationships: { build: { data: { type: "builds", id: b.id } } } } });
  console.log("attach build:", ab.ok ? "OK" : `(${ab.status} ${JSON.stringify(ab.json.errors?.[0]?.detail||ab.json).slice(0,160)})`);

  // 4. Collect IAP items (2 subscriptions + lifetime non-consumable).
  const grp = await api("GET", `/v1/apps/${appId}/subscriptionGroups?limit=10`);
  const subItems = [];
  for (const g of (grp.json.data || [])) {
    const subs = await api("GET", `/v1/subscriptionGroups/${g.id}/subscriptions?limit=50`);
    for (const s of (subs.json.data || [])) subItems.push(["subscription", "subscriptions", s.id, s.attributes.productId]);
  }
  const iaps = await api("GET", `/v1/apps/${appId}/inAppPurchasesV2?limit=50`);
  for (const p of (iaps.json.data || [])) subItems.push(["inAppPurchaseV2", "inAppPurchases", p.id, p.attributes.productId]);

  // 5. Create a review submission.
  const create = await api("POST", "/v1/reviewSubmissions", {
    data: { type: "reviewSubmissions", attributes: { platform: "IOS" },
      relationships: { app: { data: { type: "apps", id: appId } } } } });
  if (!create.ok) { console.error("create submission FAILED:", create.status, JSON.stringify(create.json.errors?.[0]||create.json).slice(0,300)); return; }
  const rsId = create.json.data.id;
  console.log("review submission:", rsId);

  // 6. Add the app version item.
  const vi = await api("POST", "/v1/reviewSubmissionItems", {
    data: { type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { type: "reviewSubmissions", id: rsId } },
        appStoreVersion: { data: { type: "appStoreVersions", id: ver.id } } } } });
  console.log("add version item:", vi.ok ? "OK" : `(${vi.status} ${JSON.stringify(vi.json.errors?.[0]?.detail||vi.json).slice(0,200)})`);

  // 7. Add each IAP item.
  for (const [relName, relType, id, productId] of subItems) {
    const it = await api("POST", "/v1/reviewSubmissionItems", {
      data: { type: "reviewSubmissionItems",
        relationships: {
          reviewSubmission: { data: { type: "reviewSubmissions", id: rsId } },
          [relName]: { data: { type: relType, id } } } } });
    console.log(`add ${productId}:`, it.ok ? "OK" : `(${it.status} ${JSON.stringify(it.json.errors?.[0]?.detail||it.json).slice(0,160)})`);
  }

  // 8. Submit.
  const submit = await api("PATCH", `/v1/reviewSubmissions/${rsId}`, {
    data: { type: "reviewSubmissions", id: rsId, attributes: { submitted: true } } });
  console.log("SUBMIT:", submit.ok ? "OK — sent for review" : `(${submit.status} ${JSON.stringify(submit.json.errors?.[0]?.detail||submit.json).slice(0,400)})`);
}

const cmd = process.argv[2] || "status";
const ap = await findApp();
if (cmd === "status") {
  console.log("app:", ap ? `${ap.id} / ${ap.attributes?.name}` : "NOT FOUND");
  if (ap) {
    const subs = await api("GET", `/v1/apps/${ap.id}/subscriptionGroups?include=subscriptions&limit=10`);
    console.log("sub groups:", JSON.stringify((subs.json.data||[]).map(g=>g.id)));
    const iaps = await api("GET", `/v1/apps/${ap.id}/inAppPurchasesV2?limit=50`);
    for (const p of (iaps.json.data||[])) console.log("  IAP:", p.attributes?.productId, p.attributes?.state);
  }
} else if (cmd === "iap") {
  if (!ap) { console.error("app NOT FOUND — register it in App Store Connect first."); process.exit(1); }
  await setupIap(ap.id);
} else if (cmd === "lifetime") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  await setupLifetime(ap.id);
} else if (cmd === "verify") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  await verify(ap.id);
} else if (cmd === "appfree") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  await appFree(ap.id);
} else if (cmd === "shots") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  await uploadAllShots(ap.id);
} else if (cmd === "grouploc") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  await ensureGroupLoc(ap.id);
} else if (cmd === "builds") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  for (const b of await listBuilds(ap.id))
    console.log(`build ${b.version}(${b.build}) [${b.state}]${b.expired ? " EXPIRED" : ""} id=${b.id} ${b.uploaded || ""}`);
} else if (cmd === "tfstatus") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  await tfInspect(ap.id);
} else if (cmd === "tfsend") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  await tfSend(ap.id);
} else if (cmd === "fixprices") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  await fixPrices(ap.id);
} else if (cmd === "submit") {
  if (!ap) { console.error("app NOT FOUND"); process.exit(1); }
  await submitForReview(ap.id);
} else { console.error("unknown:", cmd); process.exit(1); }
