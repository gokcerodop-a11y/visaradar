// llm.ts — direct Anthropic Messages API calls (no provider SDK).
// The system prompt is supplied by the client (context.systemPrompt), which
// composes the traveller's passport + Schengen context.

import type { Env } from "./env.js";
import { recordClaudeUsage, maybeAlertBilling } from "./finance.js";

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

const DEFAULT_SYSTEM =
  "You are VisaRadar Assistant, an expert AI travel companion for border " +
  "crossings, visa rules and the Schengen 90/180 rule. Be concise and " +
  "practical. Reply in the user's language.";

interface ContentBlock {
  type: string;
  text?: string;
}

async function callAnthropic(
  env: Env,
  model: string,
  system: string,
  messages: unknown[],
  maxTokens: number,
): Promise<string> {
  const r = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": ANTHROPIC_VERSION,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: maxTokens,
      system,
      messages,
    }),
  });
  if (!r.ok) {
    const errText = await r.text().catch(() => "");
    await maybeAlertBilling(env, r.status, errText).catch(() => {});
    throw new Error(`anthropic-${r.status}: ${errText.slice(0, 200)}`);
  }
  const data = (await r.json()) as {
    content?: ContentBlock[];
    usage?: Record<string, number>;
  };
  // Track cost for the daily finance report (non-critical).
  if (data.usage) await recordClaudeUsage(env, data.usage).catch(() => {});
  const text = (data.content ?? [])
    .filter((b) => b.type === "text" && typeof b.text === "string")
    .map((b) => b.text)
    .join("");
  return text.trim();
}

export async function runChat(
  env: Env,
  opts: {
    messages: Array<{ role: string; content: string }>;
    systemPrompt?: string;
  },
): Promise<{ text: string; model: string }> {
  const model = env.CHAT_MODEL;
  const text = await callAnthropic(
    env,
    model,
    opts.systemPrompt || DEFAULT_SYSTEM,
    opts.messages,
    1024,
  );
  return { text, model };
}

export async function runVision(
  env: Env,
  opts: {
    imageBase64: string;
    imageMediaType: string;
    userPrompt: string;
    systemPrompt?: string;
  },
): Promise<{ text: string; model: string }> {
  const model = env.CLAUDE_MODEL;
  const isPdf = opts.imageMediaType === "application/pdf";
  const messages = [
    {
      role: "user",
      content: [
        isPdf
          ? {
              type: "document",
              source: {
                type: "base64",
                media_type: "application/pdf",
                data: opts.imageBase64,
              },
            }
          : {
              type: "image",
              source: {
                type: "base64",
                media_type: opts.imageMediaType,
                data: opts.imageBase64,
              },
            },
        { type: "text", text: opts.userPrompt },
      ],
    },
  ];
  const text = await callAnthropic(
    env,
    model,
    opts.systemPrompt || DEFAULT_SYSTEM,
    messages,
    768,
  );
  return { text, model };
}
