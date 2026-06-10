// rate-limit.ts — KV bazlı günlük + aylık kullanım sayacı.
//
// Key şeması:
//   usage:{originalTransactionId}:{YYYY-MM-DD}  → {chat,vision,questions}
//   usage_month:{originalTransactionId}:{YYYY-MM} → {chat,vision,questions}
//
// Atomicity: Cloudflare KV strict atomic değil. Race condition Refakat
// ölçeğinde tolere edilebilir (1 user aynı saniyede 2 chat çağırması
// nadir + bu sadece +1 ekstra çağrı kaçırır, sistem güvenliği bozmaz).
// Sıkı atomicity gerekirse Durable Objects'e geçilir.

import type { Env } from "./env.js";

export type TaskName = "chat" | "vision" | "questions";

export interface UsageCounter {
  chat: number;
  vision: number;
  questions: number;
}

export interface LimitCheckResult {
  ok: boolean;
  today: UsageCounter;
  month: UsageCounter;
  limits: {
    daily: { chat: number; vision: number; questions: number };
    monthly: { chat: number; vision: number; questions: number };
  };
  reason?: string;
  resetAt?: string;
}

const EMPTY_COUNTER: UsageCounter = { chat: 0, vision: 0, questions: 0 };

/// Uygulanacak günlük + aylık limitler. [isTrial] true ise cap'ler
/// TRIAL_CAP_FACTOR (varsayılan %50) ile kısılır. checkAndIncrementLimit
/// ve /v1/usage aynı kaynağı kullanır → enforcement ve gösterim tutarlı.
export function effectiveLimits(
  env: Env,
  isTrial: boolean,
): {
  daily: UsageCounter;
  monthly: UsageCounter;
} {
  const factor = isTrial ? _trialFactor(env) : 1;
  return {
    daily: {
      chat: _scaled(env.DAILY_LIMIT_CHAT, factor),
      vision: _scaled(env.DAILY_LIMIT_VISION, factor),
      questions: _scaled(env.DAILY_LIMIT_QUESTIONS, factor),
    },
    monthly: {
      chat: _scaled(env.MONTHLY_CAP_CHAT, factor),
      vision: _scaled(env.MONTHLY_CAP_VISION, factor),
      questions: _scaled(env.MONTHLY_CAP_QUESTIONS, factor),
    },
  };
}

export async function checkAndIncrementLimit(
  env: Env,
  userId: string,
  task: TaskName,
  isTrial = false,
): Promise<LimitCheckResult> {
  const dayKey = _dayKey();
  const monthKey = _monthKey();

  // 7-günlük ücretsiz trial sırasında cap'ler kısılır (bkz. effectiveLimits) —
  // ödemeyen kullanıcı maliyetini sınırlar. Pro (ödeyen) tam cap görür.
  const { daily: dailyLimits, monthly: monthlyLimits } =
    effectiveLimits(env, isTrial);

  const dayK = `usage:${userId}:${dayKey}`;
  const monK = `usage_month:${userId}:${monthKey}`;

  const [todayRaw, monthRaw] = await Promise.all([
    env.USAGE.get(dayK, "json"),
    env.USAGE.get(monK, "json"),
  ]);
  const today: UsageCounter = (todayRaw as UsageCounter | null) ?? { ...EMPTY_COUNTER };
  const month: UsageCounter = (monthRaw as UsageCounter | null) ?? { ...EMPTY_COUNTER };

  // Limit check
  if (today[task] >= dailyLimits[task]) {
    return {
      ok: false,
      today,
      month,
      limits: { daily: dailyLimits, monthly: monthlyLimits },
      reason: `daily-${task}-limit-exceeded`,
      resetAt: _nextDayIso(),
    };
  }
  if (month[task] >= monthlyLimits[task]) {
    return {
      ok: false,
      today,
      month,
      limits: { daily: dailyLimits, monthly: monthlyLimits },
      reason: `monthly-${task}-cap-exceeded`,
      resetAt: _nextMonthIso(),
    };
  }

  // Increment + write back
  today[task] = (today[task] ?? 0) + 1;
  month[task] = (month[task] ?? 0) + 1;

  await Promise.all([
    // 36 saat TTL — gün geçince gerçek expire olsun, fakat retry/clock-skew toleransı
    env.USAGE.put(dayK, JSON.stringify(today), { expirationTtl: 36 * 3600 }),
    // 35 gün TTL — ay geçince expire
    env.USAGE.put(monK, JSON.stringify(month), { expirationTtl: 35 * 24 * 3600 }),
  ]);

  return {
    ok: true,
    today,
    month,
    limits: { daily: dailyLimits, monthly: monthlyLimits },
  };
}

export async function readUsage(env: Env, userId: string): Promise<{
  today: UsageCounter;
  month: UsageCounter;
}> {
  const dayK = `usage:${userId}:${_dayKey()}`;
  const monK = `usage_month:${userId}:${_monthKey()}`;
  const [t, m] = await Promise.all([
    env.USAGE.get(dayK, "json"),
    env.USAGE.get(monK, "json"),
  ]);
  return {
    today: (t as UsageCounter | null) ?? { ...EMPTY_COUNTER },
    month: (m as UsageCounter | null) ?? { ...EMPTY_COUNTER },
  };
}

function _dayKey(): string {
  const d = new Date();
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

function _monthKey(): string {
  const d = new Date();
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}`;
}

function _nextDayIso(): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + 1);
  d.setUTCHours(0, 0, 0, 0);
  return d.toISOString();
}

function _nextMonthIso(): string {
  const d = new Date();
  d.setUTCMonth(d.getUTCMonth() + 1, 1);
  d.setUTCHours(0, 0, 0, 0);
  return d.toISOString();
}

function pad(n: number): string {
  return n.toString().padStart(2, "0");
}

/// Trial faktörü: TRIAL_CAP_FACTOR (0<f<=1). Geçersiz/eksikse 0.5.
function _trialFactor(env: Env): number {
  const f = Number(env.TRIAL_CAP_FACTOR);
  return Number.isFinite(f) && f > 0 && f <= 1 ? f : 0.5;
}

/// Taban cap'i faktörle ölçekler. factor>=1 → değişmez; aksi → floor, min 1.
function _scaled(raw: string, factor: number): number {
  const base = Number(raw);
  if (!Number.isFinite(base)) return 0;
  if (factor >= 1) return base;
  return Math.max(1, Math.floor(base * factor));
}
