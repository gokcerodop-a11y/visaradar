// tts.ts — POST /v1/tts (ElevenLabs doğal ses; audio/mpeg döner)

import type { Env } from "./env.js";
import { validateAppleReceipt } from "./auth.js";
import { jsonResponse, parseJsonBody, SECURITY_HEADERS } from "./utils.js";
import { checkLimitOnly, incrementUsage } from "./rate-limit.js";

export async function handleTts(request: Request, env: Env): Promise<Response> {
  const receipt = await validateAppleReceipt(request, env);
  if (!receipt.active) {
    const status = receipt.reason === "subscription-expired" ? 402 : 401;
    return jsonResponse(
      { error: "unauthorized", reason: receipt.reason ?? "invalid-receipt" },
      status,
    );
  }

  // Anahtar yoksa kapalı → istemci sessiz kalır.
  if (!env.ELEVENLABS_API_KEY) {
    return jsonResponse({ error: "tts-disabled" }, 503);
  }

  const body = await parseJsonBody<{ text?: string; context?: { kvkkConsent?: boolean } }>(request);
  if (!body?.context?.kvkkConsent) {
    return jsonResponse({ error: "kvkk-consent-required" }, 403);
  }

  const preCheck = await checkLimitOnly(
    env,
    receipt.originalTransactionId,
    "questions",
    receipt.isTrial,
  );
  if (!preCheck.ok) {
    return jsonResponse(
      { error: "too-many-requests", reason: preCheck.reason, resetAt: preCheck.resetAt },
      429,
    );
  }

  const text = (body?.text ?? "").trim();
  if (!text) return jsonResponse({ error: "text-required" }, 400);
  // Maliyet tavanı: tek seferde en fazla ~5000 karakter seslendir.
  const clipped = text.slice(0, 5000);

  const voice = env.ELEVENLABS_VOICE_ID || "JBFqnCBsd6RMkjVDRZzb";
  const model = env.ELEVENLABS_MODEL_ID || "eleven_multilingual_v2";

  const r = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voice}?output_format=mp3_44100_128`,
    {
      method: "POST",
      headers: {
        "xi-api-key": env.ELEVENLABS_API_KEY,
        "content-type": "application/json",
        accept: "audio/mpeg",
      },
      body: JSON.stringify({
        text: clipped,
        model_id: model,
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.75,
          style: 0.0,
          use_speaker_boost: true,
        },
      }),
    },
  );

  if (!r.ok || !r.body) {
    return jsonResponse({ error: "tts-upstream" }, 502);
  }

  // Increment only after ElevenLabs delivered audio — failed fetches don't burn quota.
  await incrementUsage(env, receipt.originalTransactionId, "questions");

  return new Response(r.body, {
    headers: {
      "content-type": "audio/mpeg",
      "cache-control": "no-store",
      ...SECURITY_HEADERS,
    },
  });
}
