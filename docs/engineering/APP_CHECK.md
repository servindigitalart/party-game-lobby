# APP_CHECK.md

> Attestation for Bufón's Firebase backend.
>
> App Check proves a request came from a genuine build of this app. It is the
> answer to a problem the rules cannot solve on their own: the Firebase API
> key ships inside the app, so anyone can extract it and talk to Firestore
> with a script.

---

# What it protects

Firestore, Cloud Functions and Storage. Rules still decide *what* an
authenticated user may do; App Check decides *whether the caller is the app
at all*.

The two are complementary. Rules stopped the score-inflation exploit for
players using the app; App Check is what stops someone skipping the app
entirely.

---

# Implementation

`lib/core/security/app_check_service.dart` is the only place that touches
App Check. It is activated once, from `main.dart`, immediately after
`Firebase.initializeApp()` and **before** Crashlytics, Analytics, Firestore
or Functions are used — so the very first backend request already carries a
token.

```dart
await Firebase.initializeApp(options: ...);
await AppCheckService.instance.activate();   // ← here
await CrashReporter.instance.attachBackend(...);
```

Activation is idempotent (activating twice throws inside the plugin on some
platforms, and a hot restart reaches this path twice) and never throws. A
device that cannot attest still starts the game; the failure is recorded as
`app_check_activation_failed` at warning severity.

---

# Providers

| Build             | iOS                                 | Android        |
|-------------------|-------------------------------------|----------------|
| Debug             | Debug provider                      | Debug provider |
| Profile / Release | App Attest → DeviceCheck fallback   | Play Integrity |

Profile is grouped with release deliberately: a profile build is what gets
handed round before a release and has to behave like the real thing.

## Why the Apple fallback variant

`appAttestWithDeviceCheckFallback`, not plain `appAttest`.

App Attest requires **iOS 14**; this app's deployment target is **iOS 13**.
With plain App Attest, an iOS 13 device could not mint a token at all, and
once enforcement is on those users would be locked out of the game entirely.
The fallback variant hands those devices to DeviceCheck, which is weaker but
functional.

## Why Play Integrity

SafetyNet is retired. The plugin still exposes the value; a test asserts the
non-debug Android provider is `playIntegrity` so an old snippet cannot creep
back in.

---

# Enforcement — the manual console steps

**Nothing in the code enables enforcement.** These are yours to do, in this
order, after the release is deployed and the app is in testers' hands.

## 1. Register the apps (required before anything works)

Firebase console → **App Check** → Apps.

- **iOS** (`com.bufon.bufonFlutter`): register **App Attest**. Requires the
  App Attest capability on the App ID in the Apple Developer portal and in
  Xcode → Signing & Capabilities.
- **Android** (`com.bufon.bufon_flutter`): register **Play Integrity**.
  Requires the app to exist in Google Play Console and the SHA-256 of the
  signing key to be linked to the Firebase project.

## 2. Register a debug token for each machine that runs a debug build

A debug build prints a token on first launch:

```
Firebase App Check Debug Token: 01234567-89AB-...
```

Console → App Check → Apps → ⋮ → **Manage debug tokens** → add it.

Without this, debug builds appear as unverified traffic once enforcement is
on. Every developer machine and every CI runner needs its own.

## 3. Watch Monitor mode for at least 48 hours

Console → App Check → APIs. Each of Firestore / Cloud Functions / Storage
shows the share of verified vs unverified requests.

**Do not enforce anything until verified requests are ~100%.** Enforcing
early locks out real players — iOS 13 devices, Android devices without Play
Services, anyone on an older build that predates this change.

## 4. Enforce, one service at a time

Console → App Check → APIs → select the API → **Enforce**.

Recommended order: **Storage → Firestore → Cloud Functions**, leaving days
between each and watching Crashlytics for `permission-denied`.

Enforcement for Firestore and Storage needs **no code change and no
redeploy**. The client already sends tokens in both modes.

## 5. Cloud Functions callables — read this carefully

Callable functions are the exception. The console's Enforce toggle covers
non-callable HTTP traffic; for **callables**, rejection is controlled by an
option in the function definition:

```ts
export const submitVote = onCall({ enforceAppCheck: true }, async (req) => {
```

It is currently **unset** (default `false`), which means a request with a
missing or invalid token still runs, with `request.app` undefined. That is
the backwards-compatible state and the right one today.

Turning it on is a **code change plus a deploy**, and should happen only
after Firestore has been enforced cleanly for several days. The three
callables are `submitVote`, `verifyNightPass` and `manualFinalizeSeason`.

---

# Backend compatibility

Verified against the versions in this repo:

| Package                   | Version  | App Check |
|---------------------------|----------|-----------|
| firebase_core (Flutter)   | 3.15.2   | supported |
| firebase_app_check        | 0.3.2+10 | —         |
| firebase-functions        | 6.6.0    | `enforceAppCheck` available on v2 `onCall` |
| firebase-admin            | 13.6.1   | supported |

No Cloud Function reads or verifies an App Check token itself, and no Admin
SDK call depends on one. The Admin SDK authenticates with service
credentials and bypasses App Check by design — which is why the
`onMatchCompleted` trigger keeps working regardless of enforcement.

---

# Emulators and tests

**Nothing is broken.** Verified by running both emulator suites with App
Check in the dependency tree:

```
{"verifications":{"app":"MISSING","auth":"VALID"} ...
 "message":"Callable request verification passed"}
```

The Functions emulator reports the token as `MISSING` and lets the request
through, because `enforceAppCheck` is unset. Rules tests never involve App
Check at all — the rules-unit-testing harness talks to the Firestore
emulator directly.

If `enforceAppCheck: true` is ever added, `functions/integration.test.mjs`
will start failing on every callable test. That is the signal to add a debug
token to the harness, not to weaken the function.

---

# Rollback

If enforcement locks users out:

Console → App Check → APIs → select the API → **Unenforce**. It takes effect
within minutes and needs no deploy.

If a callable was enforced in code, roll back by deploying with
`enforceAppCheck` removed — see `docs/releases/RELEASE_PIPELINE.md`.
