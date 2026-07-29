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

// Apple Root CA G3 — the anchor cert at the end of every App Store Server
// Notifications V2 x5c chain. Verifying against this fingerprint prevents
// an attacker from forging notifications with their own self-signed chain.
// Source: https://www.apple.com/certificateauthority/
const APPLE_ROOT_CA_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f5b00f6db1e0c53efb3d0f3";

async function _sha256Hex(data: ArrayBuffer): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Apple ES256 JWS imzasını doğrular: leaf imza + Apple Root CA G3 parmak izi. */
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

    // Verify JWS signature with leaf cert public key
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
