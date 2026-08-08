# RELEASE_PIPELINE.md

> How Bufón is released.
>
> One command runs every check and every backend deploy, in the only order
> that is safe.

---

# Commands

```
npm run verify      Every check. Deploys nothing.
npm run release     Every check, then deploy. Asks for confirmation.
npm run release:ci  Same, without the prompt. For automation only.
```

Individual steps, useful while working:

```
npm run test:flutter
npm run test:functions
npm run test:rules
npm run test:integration
npm run catalog:generate
```

The pipeline lives in `tool/release.mjs`. It is Node rather than a shell
script so it behaves identically on macOS, Linux and Windows.

---

# What the pipeline does

```
Preflight
  ├── Firebase CLI installed?
  ├── Flutter installed?
  ├── Resolve target project from .firebaserc
  ├── Refuse demo-* projects (emulator only)
  └── Refuse projects this account cannot access

Checks                          ← all must pass before anything deploys
  ├── flutter analyze
  ├── flutter test
  ├── functions build (tsc)
  ├── functions tests
  ├── Firestore rules tests      (firestore emulator)
  └── integration tests          (firestore + functions + auth emulators)

Deploy                          ← only with --deploy, after confirmation
  ├── firestore:rules
  ├── firestore:indexes
  └── functions

Summary
```

Any failing step stops the run immediately, prints the summary with that
step marked FAIL, and exits with the step's own exit code. **Nothing is ever
deployed after a failed check.**

---

# Why this deploy order

Rules first, then indexes, then functions.

The hardened rules are compatible with the client already in the field: they
only ever remove permissions the app no longer uses. The reverse order is not
safe — functions that write under new paths would be rejected by the old
rules for as long as the gap lasts.

Indexes go before functions because a function that queries an unbuilt index
fails; index builds are asynchronous and large ones can take minutes.

---

# What the pipeline does *not* do

**It does not build or upload the app.** The Flutter build needs Xcode
signing, a provisioning profile and App Store Connect credentials, none of
which belong in a repo script. After a backend release:

```
cd bufon_flutter
flutter build ipa --release
```

then upload through Xcode Organizer or Transporter.

Backend and app releases are deliberately separate. The backend is
deployed first and must stay compatible with the app version already
installed, because users update on their own schedule.

---

# Staging

**There is no staging project today.** `.firebaserc` has one entry,
`funpartygame18`, and it is production.

This is the single biggest gap in the release process. Every rule change,
every function change and every index goes straight to the project real users
are on, and the only rehearsal is the emulator.

To close it:

1. Create a second Firebase project, e.g. `funpartygame18-staging`.
2. Add it to `.firebaserc`:

```json
{
  "projects": {
    "default": "funpartygame18",
    "staging": "funpartygame18-staging"
  }
}
```

3. Release to it first:

```
npm run release -- --project=funpartygame18-staging
```

The pipeline already accepts `--project=` and warns when the target differs
from the `.firebaserc` default, so no script changes are needed.

---

# Rollback

There is no single "undo deploy" button. Each artefact rolls back differently.

## Rules and indexes

They are files in git. Roll back by checking out the previous commit and
redeploying only that artefact:

```
git checkout <previous-sha> -- firestore.rules
firebase deploy --only firestore:rules --project funpartygame18
git checkout HEAD -- firestore.rules
```

Rules take effect within seconds. Deleting an index is safe; adding one back
requires a rebuild.

## Cloud Functions

The Firebase console keeps previous versions, but the reliable path is to
redeploy from the previous tag:

```
git checkout <previous-tag>
npm --prefix functions run build
firebase deploy --only functions --project funpartygame18
```

**Watch out for `matchCompletions`.** Rolling back `onMatchCompleted` does not
undo awards it already granted. The claim documents are the audit trail: each
one records `status` and the exact `awards` per player, so a bad release can
be reconciled by reading them rather than guessing.

## The app

There is no rollback for a build already on TestFlight. Expire the build in
App Store Connect and ship a new one. This is why the backend must stay
compatible with the previous app version.

---

# Before a production release

- [ ] `npm run verify` is green
- [ ] Working tree is clean and tagged
- [ ] `pubspec.yaml` build number incremented
- [ ] The change is compatible with the app version already installed
- [ ] Someone is available to watch Crashlytics for the next hour

---

# Known gaps

- **No staging project.** See above; this is the top priority.
- **No CI.** The pipeline runs on a developer machine. `npm run release:ci`
  exists so it can be wired to GitHub Actions later without changes.
- **`firebase deploy` is not transactional.** Rules can succeed and functions
  fail, leaving a mixed state. The order above is chosen so that mixed state
  is the safe one.
- **The pipeline does not verify the deployed result.** After a release,
  confirm manually that `onMatchCompleted` and `submitVote` appear in the
  Firebase console with the expected revision.
