// api.mjs — Play Developer API ortak yardımcı (servis hesabı + istek).
import fs from "node:fs";
import { SignJWT, importPKCS8 } from "/Users/bahiko/Projects/apps/avukat_ai/workers/avukat-proxy/node_modules/jose/dist/node/esm/index.js";

export const PKG = "com.visaradar";
const ANAHTAR = process.env.HOME + "/.private_keys/play-publisher-avukat-ai-91a3c.json";
const BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3";

let _tok;
export async function token() {
  if (_tok && _tok.exp > Date.now() + 60_000) return _tok.t;
  const d = JSON.parse(fs.readFileSync(ANAHTAR, "utf8"));
  const key = await importPKCS8(d.private_key.replace(/\\n/g, "\n"), "RS256");
  const a = await new SignJWT({ scope: "https://www.googleapis.com/auth/androidpublisher" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(d.client_email).setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt().setExpirationTime("45m").sign(key);
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: a }),
  });
  if (!r.ok) throw new Error("OAuth: " + r.status + " " + (await r.text()).slice(0, 200));
  const j = await r.json();
  _tok = { t: j.access_token, exp: Date.now() + (j.expires_in ?? 3600) * 1000 };
  return _tok.t;
}

/** JSON istek. yol BASE'e göre ya da tam URL. */
export async function api(method, yol, body, ekBaslik = {}) {
  const tok = await token();
  const url = yol.startsWith("http") ? yol : BASE + yol;
  const r = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${tok}`, "content-type": "application/json", ...ekBaslik },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const t = await r.text();
  let j; try { j = t ? JSON.parse(t) : {}; } catch { j = { raw: t }; }
  return { ok: r.ok, status: r.status, json: j };
}

/** İkili (binary) yükleme — görsel/AAB. */
export async function upload(yol, dosya, contentType) {
  const tok = await token();
  const r = await fetch("https://androidpublisher.googleapis.com" + yol, {
    method: "POST",
    headers: { Authorization: `Bearer ${tok}`, "content-type": contentType },
    body: fs.readFileSync(dosya),
  });
  const t = await r.text();
  let j; try { j = t ? JSON.parse(t) : {}; } catch { j = { raw: t }; }
  return { ok: r.ok, status: r.status, json: j };
}

export const oz = (r) => r.ok ? "✓" : `✗ ${r.status} ${(r.json?.error?.message ?? JSON.stringify(r.json)).slice(0, 140)}`;
