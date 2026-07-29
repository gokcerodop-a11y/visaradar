// index.ts — visaradar-proxy entry. Hides the Anthropic key, validates the
// Apple receipt, rate-limits, and tunnels to Claude.
//
//   GET  /healthz       liveness
//   POST /v1/chat       { messages, context:{language,systemPrompt} } -> { text }
//   POST /v1/vision     { imageBase64, imageMediaType, userPrompt, context } -> { text }

import type { Env } from "./env.js";
import { validateAppleReceipt } from "./auth.js";
import { runChat, runVision } from "./llm.js";
import { checkAndIncrementLimit, checkLimitOnly, incrementUsage } from "./rate-limit.js";
import { jsonResponse, parseJsonBody, sanitizeMessages, sanitizeString, SECURITY_HEADERS } from "./utils.js";
import { handleAppleNotify, handleFinTest, sendDailyReport } from "./notify.js";
import { trDay } from "./finance.js";
import { privacyPage, termsPage, supportPage } from "./legal.js";
import { handleTts } from "./tts.js";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-allow-headers":
    "authorization, content-type, x-client-version",
  "access-control-max-age": "86400",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    try {
      if (method === "OPTIONS") {
        return new Response(null, { status: 204, headers: { ...CORS, ...SECURITY_HEADERS } });
      }
      if (method === "GET" && path === "/healthz") {
        return jsonResponse({ status: "ok" });
      }
      // Public legal pages — App Store metadata links to these (Guideline 3.1.2).
      if (method === "GET" && (path === "/privacy" || path === "/privacy/")) {
        return privacyPage();
      }
      if (method === "GET" && (path === "/terms" || path === "/terms/")) {
        return termsPage();
      }
      if (method === "GET" && (path === "/support" || path === "/support/")) {
        return supportPage();
      }
      if (method === "POST" && path === "/v1/chat") {
        return _cors(await handleChat(request, env));
      }
      if (method === "POST" && path === "/v1/vision") {
        return _cors(await handleVision(request, env));
      }
      if (method === "POST" && path === "/v1/tts") {
        return _cors(await handleTts(request, env));
      }
      if (method === "POST" && path === "/v1/apple-notify") {
        return handleAppleNotify(request, env);
      }
      if (method === "GET" && path === "/v1/fin-test") {
        return handleFinTest(request, env);
      }
      return jsonResponse({ error: "not-found", path }, 404);
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      console.error("[fetch:unhandled]", message);
      return _cors(jsonResponse({ error: "internal" }, 500));
    }
  },

  // Daily finance report (cron) — reports the day that just ended (TR time).
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(sendDailyReport(env, trDay(-1)));
  },
};

interface ChatBody {
  messages?: Array<{ role: string; content: string }>;
  context?: { language?: string; systemPrompt?: string; kvkkConsent?: boolean };
}

interface VisionBody {
  imageBase64?: string;
  imageMediaType?: string;
  userPrompt?: string;
  context?: { language?: string; systemPrompt?: string; kvkkConsent?: boolean };
}

// Free-trial sentinel — no Apple subscription yet; max 3 total questions per device.
const FREE_TRIAL_SENTINEL = "free-trial";
const FREE_TRIAL_LIMIT = 3;

async function handleChat(request: Request, env: Env): Promise<Response> {
  const authHeader = request.headers.get("Authorization") ?? "";
  const tokenMatch = authHeader.match(/^Bearer\s+(.+)$/);
  const token = tokenMatch?.[1]?.trim() ?? "";

  // ── Free-trial path (no Apple subscription yet) ───────────────────────────
  if (token === FREE_TRIAL_SENTINEL) {
    const deviceId = request.headers.get("x-device-id")?.trim() ?? "";
    const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";

    // Determine rate-limit key. Device UUID is preferred to avoid shared-IP
    // exhaustion. To prevent infinite UUID generation from one IP, new devices
    // are counted per-IP per-day; once the cap is reached the IP key is used.
    let freeKey: string;
    let usedStr: string;
    if (deviceId.length >= 16) {
      const devKey = `freetrial:chat:dev:${deviceId}`;
      const devUsed = await env.USAGE.get(devKey);
      if (devUsed === null) {
        // First request from this device — check IP daily new-device cap.
        const ipCapKey = `freetrial:ipcap:${trDay()}:${ip}`;
        const ipCap = parseInt((await env.USAGE.get(ipCapKey)) ?? "0", 10);
        if (ipCap >= 5) {
          freeKey = `freetrial:chat:ip:${ip}`;
          usedStr = (await env.USAGE.get(freeKey)) ?? "0";
        } else {
          await env.USAGE.put(ipCapKey, String(ipCap + 1), { expirationTtl: 48 * 3600 });
          freeKey = devKey;
          usedStr = "0";
        }
      } else {
        freeKey = devKey;
        usedStr = devUsed;
      }
    } else {
      freeKey = `freetrial:chat:ip:${ip}`;
      usedStr = (await env.USAGE.get(freeKey)) ?? "0";
    }

    const used = parseInt(usedStr, 10);
    if (used >= FREE_TRIAL_LIMIT) {
      return jsonResponse({ error: "unauthorized", reason: "free-trial-exhausted" }, 402);
    }

    const body = await parseJsonBody<ChatBody>(request);
    if (body?.context?.kvkkConsent !== true) {
      return jsonResponse({ error: "kvkk-consent-required" }, 403);
    }
    if (!body?.messages || !Array.isArray(body.messages) || body.messages.length === 0) {
      return jsonResponse({ error: "messages-required" }, 400);
    }
    if (body.messages.length > 12) {
      return jsonResponse({ error: "messages-too-many" }, 400);
    }
    const last = body.messages[body.messages.length - 1];
    if (!last?.content || last.content.length > 4000) {
      return jsonResponse({ error: "message-content-invalid" }, 400);
    }
    const sanitized = sanitizeMessages(body.messages);
    if (sanitized.length === 0) {
      return jsonResponse({ error: "messages-required" }, 400);
    }
    try {
      const result = await runChat(env, {
        messages: sanitized,
        systemPrompt: body.context?.systemPrompt ? sanitizeString(body.context.systemPrompt, 6000) : undefined,
      });
      // Increment on success only — failed requests don't consume trial quota.
      await env.USAGE.put(freeKey, String(used + 1), { expirationTtl: 30 * 24 * 3600 });
      return jsonResponse({ text: result.text, model: result.model });
    } catch (e) {
      return jsonResponse({ error: "internal" }, 500);
    }
  }

  // ── Premium path (Apple-validated subscription) ───────────────────────────
  const receipt = await validateAppleReceipt(request, env);
  if (!receipt.active) {
    const status = receipt.reason === "subscription-expired" ? 402 : 401;
    return jsonResponse({ error: "unauthorized", reason: receipt.reason }, status);
  }

  // KVKK consent zorunlu (CLAUDE.md §4)
  const body = await parseJsonBody<ChatBody>(request);
  if (body?.context?.kvkkConsent !== true) {
    return jsonResponse({ error: "kvkk-consent-required" }, 403);
  }

  if (!body?.messages || !Array.isArray(body.messages) || body.messages.length === 0) {
    return jsonResponse({ error: "messages-required" }, 400);
  }
  if (body.messages.length > 12) {
    return jsonResponse({ error: "messages-too-many" }, 400);
  }
  const last = body.messages[body.messages.length - 1];
  if (!last?.content || last.content.length > 4000) {
    return jsonResponse({ error: "message-content-invalid" }, 400);
  }

  const sanitized = sanitizeMessages(body.messages);
  if (sanitized.length === 0) {
    return jsonResponse({ error: "messages-required" }, 400);
  }

  // Pre-flight: reject if already at limit — saves an LLM call.
  const preCheck = await checkLimitOnly(
    env,
    receipt.originalTransactionId,
    "chat",
    receipt.isTrial,
  );
  if (!preCheck.ok) {
    return jsonResponse(
      { error: "too-many-requests", reason: preCheck.reason, resetAt: preCheck.resetAt },
      429,
    );
  }

  try {
    const result = await runChat(env, {
      messages: sanitized,
      systemPrompt: body.context?.systemPrompt ? sanitizeString(body.context.systemPrompt, 6000) : undefined,
    });
    // Increment only after a successful response — timeouts/errors don't burn quota.
    await incrementUsage(env, receipt.originalTransactionId, "chat");
    return jsonResponse({ text: result.text, model: result.model });
  } catch (e) {
    return jsonResponse({ error: "internal" }, 500);
  }
}

async function handleVision(request: Request, env: Env): Promise<Response> {
  const receipt = await validateAppleReceipt(request, env);
  if (!receipt.active) {
    const status = receipt.reason === "subscription-expired" ? 402 : 401;
    return jsonResponse({ error: "unauthorized", reason: receipt.reason }, status);
  }

  const body = await parseJsonBody<VisionBody>(request);
  if (body?.context?.kvkkConsent !== true) {
    return jsonResponse({ error: "kvkk-consent-required" }, 403);
  }
  if (!body?.imageBase64 || !body.imageMediaType) {
    return jsonResponse({ error: "image-required" }, 400);
  }
  const ALLOWED_MEDIA = new Set(["image/jpeg", "image/png", "image/gif", "image/webp", "application/pdf"]);
  if (!ALLOWED_MEDIA.has(body.imageMediaType)) {
    return jsonResponse({ error: "unsupported-media-type" }, 400);
  }

  const preCheckVision = await checkLimitOnly(
    env,
    receipt.originalTransactionId,
    "vision",
    receipt.isTrial,
  );
  if (!preCheckVision.ok) {
    return jsonResponse(
      { error: "too-many-requests", reason: preCheckVision.reason, resetAt: preCheckVision.resetAt },
      429,
    );
  }

  if (body.userPrompt && body.userPrompt.length > 4000) {
    return jsonResponse({ error: "prompt-too-long" }, 400);
  }

  try {
    const result = await runVision(env, {
      imageBase64: body.imageBase64,
      imageMediaType: body.imageMediaType,
      userPrompt: body.userPrompt ? sanitizeString(body.userPrompt, 4000) : "Analyse this travel document.",
      systemPrompt: body.context?.systemPrompt ? sanitizeString(body.context.systemPrompt, 6000) : undefined,
    });
    await incrementUsage(env, receipt.originalTransactionId, "vision");
    return jsonResponse({ text: result.text, model: result.model });
  } catch (e) {
    return jsonResponse({ error: "internal" }, 500);
  }
}

function _cors(r: Response): Response {
  const headers = new Headers(r.headers);
  headers.set("access-control-allow-origin", "*");
  for (const [k, v] of Object.entries(SECURITY_HEADERS)) {
    headers.set(k, v);
  }
  return new Response(r.body, { status: r.status, headers });
}
