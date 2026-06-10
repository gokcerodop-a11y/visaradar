// finance.ts — daily cost/revenue tracking + net-profit Telegram report.
// Dedicated VisaRadar Travel bot. Reusable pattern across apps.

import type { Env } from "./env.js";
import { sendTelegram } from "./notify.js";

// Claude Opus 4.8 pricing (USD / 1M tokens).
const PRICE_IN = 15;
const PRICE_OUT = 75;
const PRICE_CACHE_READ = 1.5;
const PRICE_CACHE_WRITE = 18.75;

/** Turkey day (UTC+3) key: YYYY-MM-DD. */
export function trDay(offsetDays = 0): string {
  const d = new Date(Date.now() + 3 * 3600_000 + offsetDays * 86400_000);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}
function pad(n: number): string {
  return n.toString().padStart(2, "0");
}

async function _add(env: Env, key: string, amount: number): Promise<void> {
  const cur = parseFloat((await env.USAGE.get(key)) || "0");
  await env.USAGE.put(key, String(cur + amount), { expirationTtl: 40 * 24 * 3600 });
}

interface ClaudeUsage {
  input_tokens?: number;
  output_tokens?: number;
  cache_read_input_tokens?: number;
  cache_creation_input_tokens?: number;
}

export async function recordClaudeUsage(env: Env, u: ClaudeUsage): Promise<void> {
  const inp = u.input_tokens || 0;
  const out = u.output_tokens || 0;
  const cr = u.cache_read_input_tokens || 0;
  const cw = u.cache_creation_input_tokens || 0;
  const usd =
    (inp * PRICE_IN + out * PRICE_OUT + cr * PRICE_CACHE_READ + cw * PRICE_CACHE_WRITE) /
    1_000_000;
  const day = trDay();
  await _add(env, `fin:cost:${day}`, usd);
  await _add(env, `fin:ans:${day}`, 1);
}

export async function recordRevenue(
  env: Env,
  tx: { price?: number; currency?: string; offerType?: number },
  notificationType?: string,
): Promise<void> {
  const day = trDay();
  if (notificationType === "SUBSCRIBED") await _add(env, `fin:newsub:${day}`, 1);
  if (notificationType === "DID_RENEW") await _add(env, `fin:renew:${day}`, 1);
  const price = tx.price || 0;
  if (price > 0 && tx.offerType !== 1) {
    await _add(env, `fin:rev:${day}`, price / 1000);
  }
}

async function _get(env: Env, key: string): Promise<number> {
  return parseFloat((await env.USAGE.get(key)) || "0");
}

export async function buildReport(env: Env, day: string): Promise<string> {
  const cost = await _get(env, `fin:cost:${day}`); // USD
  const rev = await _get(env, `fin:rev:${day}`); // TRY (territory currency)
  const ans = await _get(env, `fin:ans:${day}`);
  const newsub = await _get(env, `fin:newsub:${day}`);
  const renew = await _get(env, `fin:renew:${day}`);

  const fx = Number(env.USD_TRY) || 43;
  const commission = Number(env.APPLE_COMMISSION) || 0.15;
  const app = env.APP_LABEL || "VisaRadar Travel";

  const costTry = cost * fx;
  const appleCut = rev * commission;
  const net = rev - appleCut - costTry;
  const f = (n: number) => n.toLocaleString("tr-TR", { maximumFractionDigits: 2 });

  return (
    `<b>📊 ${app} — Günlük Özet (${day})</b>\n\n` +
    `💬 Soru: <b>${f(ans)}</b>  ·  🟢 Yeni abone: <b>${f(newsub)}</b>  ·  🔁 Yenileme: <b>${f(renew)}</b>\n\n` +
    `💰 Gelir (brüt): <b>${f(rev)} ₺</b>\n\n` +
    `🍎 Apple kesintisi (%${f(commission * 100)}): <b>-${f(appleCut)} ₺</b>\n` +
    `🤖 Claude maliyeti: <b>${f(cost)} $ ≈ ${f(costTry)} ₺</b>\n` +
    `🧾 <b>TOPLAM GİDER: -${f(appleCut + costTry)} ₺</b>\n` +
    `━━━━━━━━━━━━━━\n` +
    `📈 <b>NET KÂR: ${f(net)} ₺</b>` +
    (net < 0 ? "  ⚠️ (zarar)" : "")
  );
}

export function isBillingError(status: number, body: string): boolean {
  const b = body.toLowerCase();
  return (
    status === 402 ||
    b.includes("credit balance") ||
    b.includes("billing") ||
    b.includes("insufficient") ||
    b.includes("quota")
  );
}

export async function maybeAlertBilling(env: Env, status: number, body: string): Promise<void> {
  if (!isBillingError(status, body)) return;
  const flag = "fin:billing-alert";
  if (await env.USAGE.get(flag)) return; // once per hour
  await env.USAGE.put(flag, "1", { expirationTtl: 3600 });
  const app = env.APP_LABEL || "VisaRadar Travel";
  await sendTelegram(
    env,
    `⚠️ <b>${app} — ACİL</b>\nClaude (Anthropic) çağrısı ödeme/limit hatası veriyor; ` +
      `kullanıcılar cevap alamıyor olabilir. Anthropic Console → Billing bakiyesini kontrol edin.`,
  );
}
