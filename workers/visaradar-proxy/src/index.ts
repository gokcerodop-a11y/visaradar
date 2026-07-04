// index.ts — visaradar-proxy entry. Hides the Anthropic key, validates the
// Apple receipt, rate-limits, and tunnels to Claude.
//
//   GET  /healthz       liveness
//   POST /v1/chat       { messages, context:{language,systemPrompt} } -> { text }
//   POST /v1/vision     { imageBase64, imageMediaType, userPrompt, context } -> { text }

import type { Env } from "./env.js";
import { validateAppleReceipt } from "./auth.js";
import { runChat, runVision } from "./llm.js";
import { checkAndIncrementLimit } from "./rate-limit.js";
import { jsonResponse, parseJsonBody } from "./utils.js";
import { handleAppleNotify, handleFinTest, sendDailyReport } from "./notify.js";
import { trDay } from "./finance.js";
import { privacyPage, termsPage, supportPage } from "./legal.js";

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
        return new Response(null, { status: 204, headers: CORS });
      }
      if (method === "GET" && path === "/healthz") {
        return jsonResponse({ status: "ok", appleEnv: env.APPLE_ENV });
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
      return _cors(jsonResponse({ error: "internal", message: message.slice(0, 200) }, 500));
    }
  },

  // Daily finance report (cron) — reports the day that just ended (TR time).
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(sendDailyReport(env, trDay(-1)));
  },
};

interface ChatBody {
  messages?: Array<{ role: string; content: string }>;
  context?: { language?: string; systemPrompt?: string };
}

interface VisionBody {
  imageBase64?: string;
  imageMediaType?: string;
  userPrompt?: string;
  context?: { language?: string; systemPrompt?: string };
}

async function handleChat(request: Request, env: Env): Promise<Response> {
  const receipt = await validateAppleReceipt(request, env);
  if (!receipt.active) {
    const status = receipt.reason === "subscription-expired" ? 402 : 401;
    return jsonResponse({ error: "unauthorized", reason: receipt.reason }, status);
  }

  const body = await parseJsonBody<ChatBody>(request);
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

  const limit = await checkAndIncrementLimit(
    env,
    receipt.originalTransactionId,
    "chat",
    receipt.isTrial,
  );
  if (!limit.ok) {
    return jsonResponse(
      { error: "too-many-requests", reason: limit.reason, resetAt: limit.resetAt },
      429,
    );
  }

  try {
    const result = await runChat(env, {
      messages: body.messages,
      systemPrompt: body.context?.systemPrompt,
    });
    return jsonResponse({ text: result.text, model: result.model });
  } catch (e) {
    return jsonResponse({ error: "upstream", message: String(e).slice(0, 200) }, 500);
  }
}

async function handleVision(request: Request, env: Env): Promise<Response> {
  const receipt = await validateAppleReceipt(request, env);
  if (!receipt.active) {
    const status = receipt.reason === "subscription-expired" ? 402 : 401;
    return jsonResponse({ error: "unauthorized", reason: receipt.reason }, status);
  }

  const body = await parseJsonBody<VisionBody>(request);
  if (!body?.imageBase64 || !body.imageMediaType) {
    return jsonResponse({ error: "image-required" }, 400);
  }

  const limit = await checkAndIncrementLimit(
    env,
    receipt.originalTransactionId,
    "vision",
    receipt.isTrial,
  );
  if (!limit.ok) {
    return jsonResponse(
      { error: "too-many-requests", reason: limit.reason, resetAt: limit.resetAt },
      429,
    );
  }

  try {
    const result = await runVision(env, {
      imageBase64: body.imageBase64,
      imageMediaType: body.imageMediaType,
      userPrompt: body.userPrompt ?? "Analyse this travel document.",
      systemPrompt: body.context?.systemPrompt,
    });
    return jsonResponse({ text: result.text, model: result.model });
  } catch (e) {
    return jsonResponse({ error: "upstream", message: String(e).slice(0, 200) }, 500);
  }
}

function _cors(r: Response): Response {
  const headers = new Headers(r.headers);
  headers.set("access-control-allow-origin", "*");
  return new Response(r.body, { status: r.status, headers });
}
