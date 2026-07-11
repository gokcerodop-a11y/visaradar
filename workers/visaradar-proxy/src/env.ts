// env.ts — Cloudflare Worker env bindings type for visaradar-proxy.

export interface Env {
  // KV namespaces
  USAGE: KVNamespace;
  RECEIPTS: KVNamespace;

  // Public vars
  APPLE_BUNDLE_ID: string;
  APPLE_ENV: "sandbox" | "production";
  CLAUDE_MODEL: string; // vision model
  CHAT_MODEL: string; // chat model
  DAILY_LIMIT_CHAT: string;
  DAILY_LIMIT_VISION: string;
  DAILY_LIMIT_QUESTIONS: string;
  MONTHLY_CAP_CHAT: string;
  MONTHLY_CAP_VISION: string;
  MONTHLY_CAP_QUESTIONS: string;
  TRIAL_CAP_FACTOR?: string;

  // Finance / Telegram report
  APP_LABEL?: string;
  USD_TRY?: string;
  APPLE_COMMISSION?: string;

  // ElevenLabs TTS (optional — 503 when absent, client falls back to silent)
  ELEVENLABS_API_KEY?: string;
  ELEVENLABS_VOICE_ID?: string;
  ELEVENLABS_MODEL_ID?: string;

  // Secrets
  ANTHROPIC_API_KEY: string;
  APPLE_API_KEY_P8: string;
  APPLE_API_KEY_ID: string;
  APPLE_API_ISSUER_ID: string;
  TELEGRAM_BOT_TOKEN?: string;
  TELEGRAM_CHAT_ID?: string;
}
