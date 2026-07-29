// notify.ts — Telegram notifications + Apple Server Notifications V2 webhook.
//
//   POST /v1/apple-notify   Apple subscription events → Telegram + revenue counters
//   GET  /v1/fin-test?t=<chatId>   send today's finance report now (test)

import { importX509, flattenedVerify } from "jose";
import type { Env } from "./env.js";
import { jsonResponse, parseJsonBody } from "./utils.js";
import { recordRevenue, buildReport, trDay } from "./finance.js";

export async function sendTelegram(env: Env, text: string): Promise<boolean> {
  const token = env.TELEGRAM_BOT_TOKEN;
  const chatId = env.TELEGRAM_CHAT_ID;
  if (!token || !chatId) return false;
  try {
    const r = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        parse_mode: "HTML",
        disable_web_page_preview: true,
      }),
    });
    return r.ok;
  } catch {
    return false;
  }
}

function _decodeJws<T>(jws: string): T | null {
  try {
    const parts = jws.split(".");
    if (parts.length !== 3) return null;
    const json = atob(parts[1]!.replace(/-/g, "+").replace(/_/g, "/"));
    return JSON.parse(json) as T;
  } catch {
    return null;
  }
}

// Apple Root CA G3 SHA-256 fingerprint — anchor for all App Store Server
// Notification V2 x5c chains. Source: https://www.apple.com/certificateauthority/
const APPLE_ROOT_CA_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f5b00f6db1e0c53efb3d0f3";

async function _sha256Hex(data: ArrayBuffer): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// ── Minimal DER helpers for X.509 chain verification ──────────────────────

function _derReadLen(buf: Uint8Array, off: number): { len: number; next: number } {
  const b = buf[off]!;
  if (b < 0x80) return { len: b, next: off + 1 };
  const n = b & 0x7f;
  let len = 0;
  for (let i = 0; i < n; i++) len = (len << 8) | buf[off + 1 + i]!;
  return { len, next: off + 1 + n };
}

/** Extract the TBSCertificate bytes and the raw signature from a DER X.509 cert. */
function _parseCertDer(der: Uint8Array): { tbs: Uint8Array; sig: Uint8Array } | null {
  try {
    if (der[0] !== 0x30) return null;
    let { next: p } = _derReadLen(der, 1);
    // TBSCertificate SEQUENCE — signed data includes the full encoding (tag+len+content)
    if (der[p] !== 0x30) return null;
    const tbsStart = p;
    const { len: tbsLen, next: tbsCnt } = _derReadLen(der, p + 1);
    const tbs = der.slice(tbsStart, tbsCnt + tbsLen);
    p = tbsCnt + tbsLen;
    // signatureAlgorithm SEQUENCE — skip
    if (der[p] !== 0x30) return null;
    const { len: algLen, next: algCnt } = _derReadLen(der, p + 1);
    p = algCnt + algLen;
    // signatureValue BIT STRING — first byte is unused-bits count (0x00)
    if (der[p] !== 0x03) return null;
    const { len: sigLen, next: sigCnt } = _derReadLen(der, p + 1);
    const sig = der.slice(sigCnt + 1, sigCnt + sigLen); // skip unused-bits byte
    return { tbs, sig };
  } catch { return null; }
}

/** Convert a DER-encoded ECDSA signature (SEQUENCE { INTEGER r, INTEGER s }) to raw r‖s (64 bytes). */
function _ecdsaDerToRaw(sig: Uint8Array): Uint8Array | null {
  try {
    if (sig[0] !== 0x30) return null;
    const p0 = sig[1]! < 0x80 ? 2 : 2 + (sig[1]! & 0x7f);
    if (sig[p0] !== 0x02) return null;
    const rLen = sig[p0 + 1]!;
    let r = sig.slice(p0 + 2, p0 + 2 + rLen);
    if (r[0] === 0x00) r = r.slice(1);
    const p1 = p0 + 2 + rLen;
    if (sig[p1] !== 0x02) return null;
    const sLen = sig[p1 + 1]!;
    let s = sig.slice(p1 + 2, p1 + 2 + sLen);
    if (s[0] === 0x00) s = s.slice(1);
    const raw = new Uint8Array(64);
    raw.set(r, 32 - r.length);
    raw.set(s, 64 - s.length);
    return raw;
  } catch { return null; }
}

/** Verify that the DER cert at `certBase64` was signed by the cert at `issuerBase64`. */
async function _verifyCertLink(certBase64: string, issuerBase64: string): Promise<boolean> {
  try {
    const certDer = Uint8Array.from(atob(certBase64), (c) => c.charCodeAt(0));
    const parsed = _parseCertDer(certDer);
    if (!parsed) return false;
    const rawSig = _ecdsaDerToRaw(parsed.sig);
    if (!rawSig) return false;
    const issuerLines = issuerBase64.match(/.{1,64}/g) ?? [issuerBase64];
    const issuerPem = `-----BEGIN CERTIFICATE-----\n${issuerLines.join("\n")}\n-----END CERTIFICATE-----`;
    const issuerKey = await importX509(issuerPem, "ES256");
    return await crypto.subtle.verify(
      { name: "ECDSA", hash: { name: "SHA-256" } },
      issuerKey,
      rawSig,
      parsed.tbs,
    );
  } catch { return false; }
}

// ── JWS verification ───────────────────────────────────────────────────────

/** Verify Apple ES256 JWS: root CA fingerprint + full chain + leaf signature. */
async function _verifyAppleJws(jws: string): Promise<boolean> {
  try {
    const parts = jws.split(".");
    if (parts.length !== 3) return false;
    const headerJson = atob(parts[0]!.replace(/-/g, "+").replace(/_/g, "/"));
    const header = JSON.parse(headerJson) as { alg?: string; x5c?: string[] };
    // Require full 3-cert chain: leaf → intermediate → Apple Root CA G3
    if (header.alg !== "ES256" || !header.x5c || header.x5c.length < 3) return false;

    // Verify that the root cert is the known Apple Root CA G3
    const rootBase64 = header.x5c[header.x5c.length - 1]!;
    const rootDer = Uint8Array.from(atob(rootBase64), (c) => c.charCodeAt(0));
    const rootFingerprint = await _sha256Hex(rootDer.buffer);
    if (rootFingerprint !== APPLE_ROOT_CA_G3_SHA256) return false;

    // Verify full chain: each cert must be signed by the next (leaf→intermediate→root).
    for (let i = 0; i < header.x5c.length - 1; i++) {
      if (!(await _verifyCertLink(header.x5c[i]!, header.x5c[i + 1]!))) return false;
    }

    // Verify JWS payload signature with leaf cert public key
    const lines = header.x5c[0]!.match(/.{1,64}/g) ?? [header.x5c[0]!];
    const leafPem = `-----BEGIN CERTIFICATE-----\n${lines.join("\n")}\n-----END CERTIFICATE-----`;
    const publicKey = await importX509(leafPem, "ES256");
    await flattenedVerify(
      { protected: parts[0]!, payload: parts[1]!, signature: parts[2]! },
      publicKey,
    );
    return true;
  } catch {
    return false;
  }
}

const TYPE_TR: Record<string, string> = {
  SUBSCRIBED: "🟢 Yeni abonelik",
  DID_RENEW: "🔁 Abonelik yenilendi",
  DID_CHANGE_RENEWAL_STATUS: "⚙️ Yenileme durumu değişti",
  DID_FAIL_TO_RENEW: "⚠️ Yenileme başarısız",
  EXPIRED: "🔚 Abonelik sona erdi",
  GRACE_PERIOD_EXPIRED: "🔚 Ödemesiz dönem bitti",
  REFUND: "💸 İade yapıldı",
  REVOKE: "🚫 Erişim iptal",
  OFFER_REDEEMED: "🎁 Teklif kullanıldı",
  ONE_TIME_CHARGE: "💎 Tek seferlik satın alma",
};

export async function handleAppleNotify(request: Request, env: Env): Promise<Response> {
  const body = await parseJsonBody<{ signedPayload?: string }>(request);
  if (!body?.signedPayload) return jsonResponse({ error: "signedPayload-missing" }, 400);

  // Apple ES256 JWS imzası doğrula
  if (!(await _verifyAppleJws(body.signedPayload))) {
    return jsonResponse({ error: "invalid-signature" }, 401);
  }

  const payload = _decodeJws<{
    notificationType?: string;
    subtype?: string;
    data?: { signedTransactionInfo?: string; environment?: string; bundleId?: string };
  }>(body.signedPayload);
  if (!payload) return jsonResponse({ error: "decode-failed" }, 400);

  // BundleId sanity check — reject notifications meant for a different app.
  if (env.APPLE_BUNDLE_ID && payload.data?.bundleId && payload.data.bundleId !== env.APPLE_BUNDLE_ID) {
    return jsonResponse({ error: "invalid-bundle-id" }, 401);
  }

  const tx = payload.data?.signedTransactionInfo
    ? _decodeJws<{
        productId?: string;
        originalTransactionId?: string;
        price?: number;
        currency?: string;
        offerType?: number;
      }>(payload.data.signedTransactionInfo)
    : null;

  if (tx) {
    try {
      await recordRevenue(env, tx, payload.notificationType);
    } catch {
      /* finance non-critical */
    }
    // İptal/iade durumunda receipt cache'i temizle
    if (
      tx?.originalTransactionId &&
      (payload.notificationType === "REVOKE" || payload.notificationType === "REFUND" || payload.notificationType === "EXPIRED")
    ) {
      await env.RECEIPTS.delete(`receipt:${tx.originalTransactionId}`).catch(() => {});
    }
  }

  const app = env.APP_LABEL || "VisaRadar Travel";
  const baslik =
    TYPE_TR[payload.notificationType ?? ""] ?? `ℹ️ ${payload.notificationType ?? "Bildirim"}`;
  const urun = tx?.productId ?? "-";
  const ortam = payload.data?.environment ?? "-";
  const altTip = payload.subtype ? `\nAlt tür: ${payload.subtype}` : "";

  await sendTelegram(
    env,
    `<b>${app}</b>\n${baslik}\nÜrün: <code>${urun}</code>\nOrtam: ${ortam}${altTip}`,
  );
  return jsonResponse({ ok: true });
}

export async function sendDailyReport(env: Env, day: string): Promise<boolean> {
  return sendTelegram(env, await buildReport(env, day));
}

/** Test: GET /v1/fin-test?t=<chatId> → send today's report immediately. */
export async function handleFinTest(request: Request, env: Env): Promise<Response> {
  const u = new URL(request.url);
  if (!env.TELEGRAM_CHAT_ID || u.searchParams.get("t") !== env.TELEGRAM_CHAT_ID) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }
  return jsonResponse({ sent: await sendDailyReport(env, trDay()) });
}
