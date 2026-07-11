// tts.ts — POST /v1/tts (ElevenLabs doğal ses; audio/mpeg döner)

import type { Env } from "./env.js";
import { validateAppleReceipt } from "./auth.js";
import { jsonResponse, parseJsonBody } from "./utils.js";

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

  const body = await parseJsonBody<{ text?: string }>(request);
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
    const t = await r.text().catch(() => "");
    return jsonResponse({ error: "tts-upstream", message: t.slice(0, 200) }, 502);
  }

  return new Response(r.body, {
    headers: {
      "content-type": "audio/mpeg",
      "cache-control": "no-store",
    },
  });
}
