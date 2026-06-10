// auth.ts — Apple App Store Server API V2 receipt validation.
// Bearer <originalTransactionId> → validated against Apple, cached in KV.

import { SignJWT, importPKCS8 } from "jose";

import type { Env } from "./env.js";

export interface ValidatedReceipt {
  active: boolean;
  originalTransactionId: string;
  productId: string;
  expiresDate: number; // epoch ms (0 for lifetime / non-expiring)
  revocationDate?: number;
  isTrial: boolean;
  reason?: string;
}

const PRODUCT_MONTHLY = "com.visaradar.premium.monthly";
const PRODUCT_ANNUAL = "com.visaradar.premium.annual";
const PRODUCT_LIFETIME = "com.visaradar.premium.lifetime";
const VALID_PRODUCT_IDS = new Set([
  PRODUCT_MONTHLY,
  PRODUCT_ANNUAL,
  PRODUCT_LIFETIME,
]);

const APPLE_API_BASE_PROD = "https://api.storekit.itunes.apple.com";
const APPLE_API_BASE_SANDBOX = "https://api.storekit-sandbox.itunes.apple.com";

export async function validateAppleReceipt(
  request: Request,
  env: Env,
): Promise<ValidatedReceipt> {
  const authHeader = request.headers.get("Authorization") ?? "";
  const match = authHeader.match(/^Bearer\s+(.+)$/);
  if (!match) {
    return _fail("", "missing-authorization-header");
  }
  const transactionId = match[1]!.trim();

  const cacheKey = `receipt:${transactionId}`;
  const cached = await env.RECEIPTS.get(cacheKey, "json");
  if (cached) return cached as ValidatedReceipt;

  const jwt = await _signAppleJWT(env);

  // A transaction lives in exactly one environment; try the preferred one
  // first, fall back to the other so we never have to flip APPLE_ENV at submit.
  const preferProd = env.APPLE_ENV === "production";
  const bases = preferProd
    ? [APPLE_API_BASE_PROD, APPLE_API_BASE_SANDBOX]
    : [APPLE_API_BASE_SANDBOX, APPLE_API_BASE_PROD];

  let resp: Response | undefined;
  let lastStatus = 0;
  let lastErrText = "";
  for (const base of bases) {
    const url = `${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`;
    const r = await fetch(url, { headers: { Authorization: `Bearer ${jwt}` } });
    if (r.ok) {
      resp = r;
      break;
    }
    lastStatus = r.status;
    lastErrText = await r.text().catch(() => "");
  }

  if (!resp) {
    return _fail(
      transactionId,
      `apple-api-${lastStatus}: ${lastErrText.slice(0, 100)}`,
    );
  }

  const data = (await resp.json()) as { signedTransactionInfo: string };
  const tx = _decodeJwsPayload<AppleTransactionPayload>(
    data.signedTransactionInfo,
  );
  const result = _interpretTransaction(tx, env);

  const cacheTtlSec = result.expiresDate
    ? Math.min(3600, Math.max(60, Math.floor((result.expiresDate - Date.now()) / 1000)))
    : 3600;
  await env.RECEIPTS.put(cacheKey, JSON.stringify(result), {
    expirationTtl: cacheTtlSec,
  });

  return result;
}

interface AppleTransactionPayload {
  transactionId: string;
  originalTransactionId: string;
  productId: string;
  expiresDate?: number;
  revocationDate?: number;
  offerType?: number; // 1 = introductory (trial)
  bundleId: string;
}

function _interpretTransaction(
  tx: AppleTransactionPayload,
  env: Env,
): ValidatedReceipt {
  if (tx.bundleId !== env.APPLE_BUNDLE_ID) {
    return _fail(
      tx.originalTransactionId,
      `bundle-id-mismatch: got ${tx.bundleId}`,
    );
  }
  if (!VALID_PRODUCT_IDS.has(tx.productId)) {
    return _fail(tx.originalTransactionId, `unknown-product-id: ${tx.productId}`);
  }
  if (tx.revocationDate && tx.revocationDate > 0) {
    return {
      active: false,
      originalTransactionId: tx.originalTransactionId,
      productId: tx.productId,
      expiresDate: tx.expiresDate ?? 0,
      revocationDate: tx.revocationDate,
      isTrial: false,
      reason: "subscription-revoked",
    };
  }

  // Lifetime (non-consumable) has no expiry — active unless revoked.
  if (tx.productId === PRODUCT_LIFETIME) {
    return {
      active: true,
      originalTransactionId: tx.originalTransactionId,
      productId: tx.productId,
      expiresDate: 0,
      isTrial: false,
    };
  }

  const now = Date.now();
  const expiresDate = tx.expiresDate ?? 0;
  if (expiresDate <= now) {
    return {
      active: false,
      originalTransactionId: tx.originalTransactionId,
      productId: tx.productId,
      expiresDate,
      isTrial: false,
      reason: "subscription-expired",
    };
  }

  return {
    active: true,
    originalTransactionId: tx.originalTransactionId,
    productId: tx.productId,
    expiresDate,
    isTrial: tx.offerType === 1,
  };
}

function _fail(originalTransactionId: string, reason: string): ValidatedReceipt {
  return {
    active: false,
    originalTransactionId,
    productId: "",
    expiresDate: 0,
    isTrial: false,
    reason,
  };
}

async function _signAppleJWT(env: Env): Promise<string> {
  const pem = env.APPLE_API_KEY_P8.replace(/\\n/g, "\n")
    .replace(/\r\n/g, "\n")
    .trim();
  const privateKey = await importPKCS8(pem, "ES256");
  return await new SignJWT({ bid: env.APPLE_BUNDLE_ID })
    .setProtectedHeader({ alg: "ES256", kid: env.APPLE_API_KEY_ID, typ: "JWT" })
    .setIssuer(env.APPLE_API_ISSUER_ID)
    .setIssuedAt()
    .setExpirationTime("50m")
    .setAudience("appstoreconnect-v1")
    .sign(privateKey);
}

function _decodeJwsPayload<T = unknown>(jws: string): T {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("invalid JWS format");
  const payload = parts[1]!;
  const padded = payload + "===".slice((payload.length + 3) % 4);
  const base64 = padded.replace(/-/g, "+").replace(/_/g, "/");
  const json = atob(base64);
  return JSON.parse(json) as T;
}
