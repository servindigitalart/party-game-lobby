// functions/src/purchases/appleReceipt.ts

import {
  APPLE_PRODUCTION_URL,
  APPLE_SANDBOX_URL,
  IOS_BUNDLE_ID,
  MissingSecretError,
} from './config';

/** Apple status codes this flow reacts to by name. */
export const APPLE_STATUS = {
  ok: 0,
  /** A sandbox receipt was sent to production. Retry against sandbox. */
  sandboxReceiptOnProduction: 21007,
  /** A production receipt was sent to sandbox. */
  productionReceiptOnSandbox: 21008,
} as const;

export type ReceiptRejection =
  | 'invalid_status'
  | 'bundle_mismatch'
  | 'product_mismatch'
  | 'no_transaction'
  | 'network_error';

export type ReceiptResult =
  | { valid: true; environment: 'production' | 'sandbox' }
  | { valid: false; reason: ReceiptRejection; status?: number };

/** Injectable so tests can drive Apple's responses without a network. */
export type FetchLike = (
  url: string,
  init: { method: string; headers: Record<string, string>; body: string }
) => Promise<{ json: () => Promise<any> }>;

export interface VerifyOptions {
  receiptData: string;
  productId: string;
  sharedSecret: string;
  fetchImpl?: FetchLike;
}

/**
 * Verifies an App Store receipt.
 *
 * ## The 21007 flow
 *
 * Apple's documented procedure is: always post to **production** first; if
 * it answers `21007` the receipt came from sandbox, so post it **once** to
 * the sandbox endpoint. That is exactly two requests, maximum.
 *
 * The previous implementation chose its endpoint from
 * `process.env.FUNCTIONS_EMULATOR`, which is unset in deployed functions, so
 * it always used production — and handled `21007` by calling itself again,
 * which recomputed the same endpoint and got the same `21007`. Unbounded
 * recursion. It triggered on every TestFlight purchase, because TestFlight
 * always issues sandbox receipts.
 *
 * ## What is checked
 *
 * status, then `receipt.bundle_id`, then the product id. The bundle check
 * was missing: without it a valid receipt from *any other app* selling a
 * product with the same identifier would have been accepted.
 *
 * The shared secret is never logged, never returned and never included in
 * an error message.
 */
export async function verifyAppleReceipt(
  options: VerifyOptions
): Promise<ReceiptResult> {
  const { receiptData, productId, sharedSecret } = options;

  if (!sharedSecret) {
    // Typed rather than a silent empty password: Apple would answer 21004
    // and the real cause would look like a malformed receipt.
    throw new MissingSecretError('APPLE_SHARED_SECRET');
  }

  const post = options.fetchImpl ?? (globalThis.fetch as unknown as FetchLike);

  // 1. Production, always.
  const production = await callApple(post, APPLE_PRODUCTION_URL, {
    receiptData,
    sharedSecret,
  });

  if (production === null) {
    return { valid: false, reason: 'network_error' };
  }

  if (production.status === APPLE_STATUS.sandboxReceiptOnProduction) {
    // 2. Sandbox, exactly once. No recursion, no loop.
    const sandbox = await callApple(post, APPLE_SANDBOX_URL, {
      receiptData,
      sharedSecret,
    });

    if (sandbox === null) {
      return { valid: false, reason: 'network_error' };
    }

    // 21008 here would mean Apple contradicted itself; treat it as a
    // rejection rather than bouncing back to production.
    return evaluate(sandbox, productId, 'sandbox');
  }

  return evaluate(production, productId, 'production');
}

function evaluate(
  body: any,
  productId: string,
  environment: 'production' | 'sandbox'
): ReceiptResult {
  if (body?.status !== APPLE_STATUS.ok) {
    return { valid: false, reason: 'invalid_status', status: body?.status };
  }

  // The bundle id Apple echoes back is the receipt's own. A receipt minted
  // for another app must never unlock this one.
  const bundleId = body?.receipt?.bundle_id;
  if (bundleId !== IOS_BUNDLE_ID) {
    return { valid: false, reason: 'bundle_mismatch' };
  }

  const transactions: any[] = body?.latest_receipt_info ?? [];
  if (transactions.length === 0) {
    return { valid: false, reason: 'no_transaction' };
  }

  const matches = transactions.some((t) => t?.product_id === productId);
  if (!matches) {
    return { valid: false, reason: 'product_mismatch' };
  }

  return { valid: true, environment };
}

async function callApple(
  post: FetchLike,
  url: string,
  args: { receiptData: string; sharedSecret: string }
): Promise<any | null> {
  try {
    const response = await post(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        'receipt-data': args.receiptData,
        // Apple's field name. Never logged.
        password: args.sharedSecret,
        'exclude-old-transactions': true,
      }),
    });
    return await response.json();
  } catch {
    // Swallowed deliberately: the thrown value can carry the request body,
    // and the request body carries the shared secret.
    return null;
  }
}
