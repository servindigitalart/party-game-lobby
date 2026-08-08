// functions/src/purchases/config.ts
//
// Identifiers the purchase flow validates against. Declared once so the
// backend cannot drift from the app: a mismatch here does not fail loudly,
// it silently rejects every purchase (or, worse, accepts the wrong one).

/** The only product this backend sells. Must match the Flutter client. */
export const NIGHT_PASS_PRODUCT_ID = 'night_pass_12h';

/**
 * App Store Connect bundle id.
 *
 * Matches `PRODUCT_BUNDLE_IDENTIFIER` in Runner.xcodeproj, `BUNDLE_ID` in
 * GoogleService-Info.plist and `iosBundleId` in firebase_options.dart.
 */
export const IOS_BUNDLE_ID = 'com.bufon.bufonFlutter';

/**
 * Google Play package name.
 *
 * Matches `applicationId` and `namespace` in android/app/build.gradle.kts
 * and `package_name` in google-services.json. The backend previously used a
 * hand-typed package that matched nothing, which made every Android
 * purchase unverifiable.
 */
export const ANDROID_PACKAGE_NAME = 'com.bufon.bufon_flutter';

/** Apple's receipt verification endpoints. */
export const APPLE_PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
export const APPLE_SANDBOX_URL =
  'https://sandbox.itunes.apple.com/verifyReceipt';

/**
 * Raised when a required secret is absent.
 *
 * Explicit and typed rather than defaulting to an empty string: an empty
 * shared secret makes Apple reject every receipt with a status code that
 * looks like a bad receipt, so the real cause — nobody configured the
 * secret — stays invisible.
 */
export class MissingSecretError extends Error {
  constructor(readonly secretName: string) {
    super(
      `Secret ${secretName} is not configured. ` +
        `Set it with: firebase functions:secrets:set ${secretName}`
    );
    this.name = 'MissingSecretError';
  }
}
