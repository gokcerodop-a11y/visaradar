// utils.ts — JSON response + body parse + sanitization helpers.

/** Tüm API yanıtlarına eklenen güvenlik header'ları */
export const SECURITY_HEADERS: Record<string, string> = {
  "x-content-type-options": "nosniff",
  "x-frame-options": "DENY",
  "strict-transport-security": "max-age=31536000; includeSubDomains; preload",
  "referrer-policy": "no-referrer",
  "permissions-policy": "geolocation=(), microphone=(), camera=()",
  "content-security-policy": "default-src 'none'; frame-ancestors 'none'",
};

/** Maximum request body size: 2 MB */
export const MAX_BODY_BYTES = 2 * 1024 * 1024;

export function jsonResponse(
  body: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...SECURITY_HEADERS,
      ...extraHeaders,
    },
  });
}

export async function parseJsonBody<T = unknown>(
  request: Request,
): Promise<T | null> {
  const contentLength = request.headers.get("content-length");
  if (contentLength && parseInt(contentLength, 10) > MAX_BODY_BYTES) {
    return null;
  }
  try {
    const text = await request.text();
    if (text.length > MAX_BODY_BYTES) return null;
    return JSON.parse(text) as T;
  } catch {
    return null;
  }
}

const ALLOWED_ROLES = new Set(["user", "assistant"]);

/** Null byte ve kontrol karakterlerini temizler, uzunluk keser. */
export function sanitizeString(s: string, maxLen = 8000): string {
  return s
    .replace(/\x00/g, "")
    // eslint-disable-next-line no-control-regex
    .replace(/[\x01-\x08\x0b\x0c\x0e-\x1f\x7f]/g, "")
    .slice(0, maxLen);
}

/** Rol whitelist + içerik temizleme. Geçersiz rol içeren mesajlar kaldırılır. */
export function sanitizeMessages(
  messages: Array<{ role: string; content: string }>,
): Array<{ role: string; content: string }> {
  return messages
    .filter((m) => ALLOWED_ROLES.has(m.role))
    .map((m) => ({ role: m.role, content: sanitizeString(m.content) }));
}
