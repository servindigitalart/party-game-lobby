// functions/src/purchases/purchases.test.mjs
//
// Run with: npm --prefix functions test

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  verifyAppleReceipt,
  APPLE_STATUS,
} from '../../lib/purchases/appleReceipt.js';
import {
  ANDROID_PACKAGE_NAME,
  APPLE_PRODUCTION_URL,
  APPLE_SANDBOX_URL,
  IOS_BUNDLE_ID,
  MissingSecretError,
  NIGHT_PASS_PRODUCT_ID,
} from '../../lib/purchases/config.js';

const SECRET = 'a-shared-secret-that-must-never-be-logged';

/** Records every call and replies with the queued bodies, in order. */
function fakeApple(responses) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url, body: JSON.parse(init.body) });
    const next = responses[calls.length - 1];
    if (next instanceof Error) throw next;
    return { json: async () => next };
  };
  impl.calls = calls;
  return impl;
}

const validBody = (overrides = {}) => ({
  status: APPLE_STATUS.ok,
  receipt: { bundle_id: IOS_BUNDLE_ID },
  latest_receipt_info: [{ product_id: NIGHT_PASS_PRODUCT_ID }],
  ...overrides,
});

const verify = (fetchImpl, overrides = {}) =>
  verifyAppleReceipt({
    receiptData: 'base64-receipt',
    productId: NIGHT_PASS_PRODUCT_ID,
    sharedSecret: SECRET,
    fetchImpl,
    ...overrides,
  });

// ---------------------------------------------------------------------------
// The shared secret
// ---------------------------------------------------------------------------

test('a missing shared secret throws a typed error, not a silent failure', async () => {
  await assert.rejects(
    () =>
      verifyAppleReceipt({
        receiptData: 'r',
        productId: NIGHT_PASS_PRODUCT_ID,
        sharedSecret: '',
        fetchImpl: fakeApple([validBody()]),
      }),
    (error) => {
      assert.ok(error instanceof MissingSecretError);
      assert.equal(error.secretName, 'APPLE_SHARED_SECRET');
      // The message must tell an operator how to fix it...
      assert.match(error.message, /functions:secrets:set APPLE_SHARED_SECRET/);
      return true;
    }
  );
});

test('the secret never reaches an error message', async () => {
  const boom = new Error(`request failed with password=${SECRET}`);
  const result = await verify(fakeApple([boom]));

  // The throw is swallowed precisely because it can carry the request body.
  assert.deepEqual(result, { valid: false, reason: 'network_error' });
});

test('no request is made when the secret is absent', async () => {
  const apple = fakeApple([validBody()]);
  await assert.rejects(() =>
    verifyAppleReceipt({
      receiptData: 'r',
      productId: NIGHT_PASS_PRODUCT_ID,
      sharedSecret: '',
      fetchImpl: apple,
    })
  );
  assert.equal(apple.calls.length, 0);
});

// ---------------------------------------------------------------------------
// The 21007 flow
// ---------------------------------------------------------------------------

test('a production receipt is verified with one request', async () => {
  const apple = fakeApple([validBody()]);
  const result = await verify(apple);

  assert.deepEqual(result, { valid: true, environment: 'production' });
  assert.equal(apple.calls.length, 1);
  assert.equal(apple.calls[0].url, APPLE_PRODUCTION_URL);
});

test('21007 retries sandbox exactly once and succeeds', async () => {
  const apple = fakeApple([
    { status: APPLE_STATUS.sandboxReceiptOnProduction },
    validBody(),
  ]);

  const result = await verify(apple);

  assert.deepEqual(result, { valid: true, environment: 'sandbox' });
  assert.equal(apple.calls.length, 2);
  assert.equal(apple.calls[0].url, APPLE_PRODUCTION_URL);
  assert.equal(apple.calls[1].url, APPLE_SANDBOX_URL);
});

test('REGRESSION: a permanent 21007 cannot loop', async () => {
  // The previous implementation recursed on 21007 while recomputing the
  // same production endpoint, so this scenario never terminated. It is the
  // scenario every TestFlight purchase produces.
  const apple = fakeApple(
    Array.from({ length: 50 }, () => ({
      status: APPLE_STATUS.sandboxReceiptOnProduction,
    }))
  );

  const result = await verify(apple);

  assert.equal(result.valid, false);
  assert.equal(apple.calls.length, 2, 'never more than two requests');
});

test('21008 from sandbox is rejected, not bounced back to production', async () => {
  const apple = fakeApple([
    { status: APPLE_STATUS.sandboxReceiptOnProduction },
    { status: APPLE_STATUS.productionReceiptOnSandbox },
  ]);

  const result = await verify(apple);

  assert.deepEqual(result, {
    valid: false,
    reason: 'invalid_status',
    status: 21008,
  });
  assert.equal(apple.calls.length, 2);
});

test('21008 straight from production is rejected without a retry', async () => {
  const apple = fakeApple([
    { status: APPLE_STATUS.productionReceiptOnSandbox },
  ]);

  const result = await verify(apple);

  assert.equal(result.valid, false);
  assert.equal(result.status, 21008);
  assert.equal(apple.calls.length, 1);
});

// ---------------------------------------------------------------------------
// Failure modes
// ---------------------------------------------------------------------------

test('a network failure is reported, never treated as valid', async () => {
  const result = await verify(fakeApple([new Error('ETIMEDOUT')]));
  assert.deepEqual(result, { valid: false, reason: 'network_error' });
});

test('a sandbox timeout after 21007 is reported', async () => {
  const apple = fakeApple([
    { status: APPLE_STATUS.sandboxReceiptOnProduction },
    new Error('socket hang up'),
  ]);

  const result = await verify(apple);
  assert.deepEqual(result, { valid: false, reason: 'network_error' });
  assert.equal(apple.calls.length, 2);
});

test('an Apple error status is rejected', async () => {
  // 21002 = malformed receipt data, 21004 = wrong shared secret.
  for (const status of [21002, 21003, 21004, 21010]) {
    const result = await verify(fakeApple([{ status }]));
    assert.equal(result.valid, false, `status ${status}`);
    assert.equal(result.reason, 'invalid_status');
    assert.equal(result.status, status);
  }
});

test('a malformed response is rejected rather than trusted', async () => {
  for (const body of [null, {}, { status: undefined }]) {
    const result = await verify(fakeApple([body]));
    assert.equal(result.valid, false);
  }
});

// ---------------------------------------------------------------------------
// bundle_id
// ---------------------------------------------------------------------------

test('a receipt from another app is rejected', async () => {
  const apple = fakeApple([
    validBody({ receipt: { bundle_id: 'com.someone.else' } }),
  ]);

  const result = await verify(apple);
  assert.deepEqual(result, { valid: false, reason: 'bundle_mismatch' });
});

test('a receipt with no bundle_id is rejected', async () => {
  const result = await verify(fakeApple([validBody({ receipt: {} })]));
  assert.deepEqual(result, { valid: false, reason: 'bundle_mismatch' });
});

test('the bundle id must match exactly, not by prefix or case', async () => {
  for (const bundleId of [
    'com.bufon.bufonflutter',
    'com.bufon.bufonFlutter.RunnerTests',
    'com.bufon.bufon_flutter',
    ' com.bufon.bufonFlutter',
  ]) {
    const result = await verify(
      fakeApple([validBody({ receipt: { bundle_id: bundleId } })])
    );
    assert.equal(result.valid, false, bundleId);
    assert.equal(result.reason, 'bundle_mismatch', bundleId);
  }
});

test('the accepted bundle id is the App Store Connect one', () => {
  assert.equal(IOS_BUNDLE_ID, 'com.bufon.bufonFlutter');
});

// ---------------------------------------------------------------------------
// product_id
// ---------------------------------------------------------------------------

test('a receipt for another product is rejected', async () => {
  const apple = fakeApple([
    validBody({ latest_receipt_info: [{ product_id: 'some_other_product' }] }),
  ]);

  const result = await verify(apple);
  assert.deepEqual(result, { valid: false, reason: 'product_mismatch' });
});

test('a receipt with no transactions is rejected', async () => {
  const result = await verify(
    fakeApple([validBody({ latest_receipt_info: [] })])
  );
  assert.deepEqual(result, { valid: false, reason: 'no_transaction' });
});

test('the product is found among several transactions', async () => {
  const apple = fakeApple([
    validBody({
      latest_receipt_info: [
        { product_id: 'something_old' },
        { product_id: NIGHT_PASS_PRODUCT_ID },
      ],
    }),
  ]);

  assert.equal((await verify(apple)).valid, true);
});

// ---------------------------------------------------------------------------
// Identifiers agree with the projects they validate
// ---------------------------------------------------------------------------

const read = (p) => readFileSync(new URL(p, import.meta.url), 'utf8');

test('the Android package matches android/app/build.gradle.kts', () => {
  const gradle = read('../../../bufon_flutter/android/app/build.gradle.kts');
  assert.match(gradle, new RegExp(`applicationId = "${ANDROID_PACKAGE_NAME}"`));
  assert.match(gradle, new RegExp(`namespace = "${ANDROID_PACKAGE_NAME}"`));
});

test('the Android package matches google-services.json', () => {
  const json = JSON.parse(
    read('../../../bufon_flutter/android/app/google-services.json')
  );
  const packages = json.client.map(
    (c) => c.client_info.android_client_info.package_name
  );
  assert.ok(packages.includes(ANDROID_PACKAGE_NAME), packages.join(', '));
});

test('the retired com.bufon.flutter package appears nowhere in functions', () => {
  const index = read('../index.ts');
  assert.ok(
    !index.includes("'com.bufon.flutter'"),
    'the old package name is still referenced'
  );
});

test('the iOS bundle id matches the Xcode project', () => {
  const pbxproj = read(
    '../../../bufon_flutter/ios/Runner.xcodeproj/project.pbxproj'
  );
  assert.match(
    pbxproj,
    new RegExp(`PRODUCT_BUNDLE_IDENTIFIER = ${IOS_BUNDLE_ID};`)
  );
});

test('the iOS bundle id matches GoogleService-Info.plist', () => {
  const plist = read(
    '../../../bufon_flutter/ios/Runner/GoogleService-Info.plist'
  );
  assert.ok(plist.includes(`<string>${IOS_BUNDLE_ID}</string>`));
});

test('the product id matches the Flutter client', () => {
  const dart = read('../../../bufon_flutter/lib/services/iap_service.dart');
  assert.match(
    dart,
    new RegExp(`nightPassProductId = '${NIGHT_PASS_PRODUCT_ID}'`)
  );
});

test('no secret value is hardcoded anywhere in the purchase flow', () => {
  for (const file of ['../index.ts', './appleReceipt.ts', './config.ts']) {
    const source = read(file);
    // The name may appear; a literal value must not.
    assert.ok(
      !/APPLE_SHARED_SECRET\s*=\s*['"][^'"]+['"]/.test(source),
      `${file} assigns a literal to APPLE_SHARED_SECRET`
    );
    assert.ok(
      !source.includes(SECRET),
      `${file} contains a secret-looking literal`
    );
  }
});
