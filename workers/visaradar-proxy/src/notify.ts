// notify.ts — Telegram notifications + Apple Server Notifications V2 webhook.
//
//   POST /v1/apple-notify   Apple subscription events → Telegram + revenue counters
//   GET  /v1/fin-test?t=<chatId>   send today's finance report now (test)

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
