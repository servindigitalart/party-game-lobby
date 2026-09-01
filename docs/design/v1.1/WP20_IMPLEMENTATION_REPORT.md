# BUFÓN v1.1 — WP20 · LAUNCH IDENTITY AND HONEST EMPTY STATES

## IMPLEMENTATION REPORT

> | Field | Value |
> |---|---|
> | **Document date** | 2026-09-01 |
> | **Package** | **WP20 — Launch identity and honest empty states** (`MASTER_V1.1_RECONCILIATION.md:962-975`) |
> | **Findings closed** | **R-07** · audit A **C-2**, **H-1**, and the launch half of **L-1** |
> | **Release blocker** | **YES** — R-07 is one of the eleven at `:1250`; it is *"the root four other findings hang off (D-1)"* |
> | **HEAD before** | `9f7d98ee0f7a7b86966d19c443cbcc1e54376653` |
> | **HEAD after** | one commit ahead; **`HEAD^ == 9f7d98e…`** (§K). The commit's own SHA cannot appear inside a file that is part of it; it is reported at the terminal |
> | **Commits** | exactly **1** · **not pushed** |
> | **Production files changed** | 5 — all inside WP20's authorised file list |
> | **Test files added** | 1 · **0 modified** |
> | **Tests** | 301 → **309**, all passing |
> | **Goldens** | 10 · **all byte-identical** · no `--update-goldens` |
> | **Dependencies** | **unchanged** — `pubspec.yaml` and `pubspec.lock` untouched |
> | **Blueprint / Master Reconciliation / audits** | **untouched, hash-verified** |

**Evidence discipline.** **[VERIFIED]** = demonstrated by a command run in this session or by a test that passed. **[INFERRED]** = derived from verified evidence, derivation stated. **[UNVERIFIABLE]** = not establishable here. No runtime claim is made about a device this work was not executed on.

---

## A · VERDICT

> ## **COMPLETE.**

Every element of WP20's authoritative scope is implemented, verified, and committed as exactly one unpushed commit. No stop condition triggered. One scope line resolved to *no change required*, with the reasoning recorded in full at §D.3 rather than satisfied by a cosmetic edit.

---

## B · STARTING HEAD

```
HEAD          9f7d98ee0f7a7b86966d19c443cbcc1e54376653   (WP19)
branch        main
origin/main   2c8337e7d790c79803b7b93f3b0329318cbc2e93   (HEAD was 2 ahead)
stash         1 entry — NOT applied
working tree  no tracked modifications, nothing staged
untracked     11 protected documents
tests         301 passing  ← MEASURED, not assumed
analyzer      clean
goldens       10, hashed before any edit (§J)
```

**[VERIFIED]** The baseline was measured with a full `flutter test` run before any file was touched. The instruction not to assume the previous count was followed: the pre-change figure is **301**, which happens to match WP19's closing figure, and is recorded here as an independent measurement rather than a carry-forward.

---

## C · ENDING HEAD

One commit ahead of `9f7d98e`. `HEAD^` is `9f7d98ee0f7a7b86966d19c443cbcc1e54376653` — **[VERIFIED]**, so WP19 is intact and untouched beneath this work.

---

## D · EXACT WP20 SCOPE IMPLEMENTED

The authoritative scope, verbatim from `MASTER_V1.1_RECONCILIATION.md:964`:

> **Scope** Populate the anonymous identity before the first frame (`main.dart`, `game_providers.dart:29`); replace failure-worded placeholders with honest empty states saying *what to do* (`profile_screen.dart:86`, `leaderboard_screen.dart:184`, `season_countdown_banner.dart:118-119`); give `profile_screen.dart:67-79` a real `else`.

| # | Scope clause | Status | Where |
|---|---|---|---|
| 1 | Populate the anonymous identity before the first frame | ✅ **DONE** | `main.dart` — §F.1 |
| 2 | `game_providers.dart:29` | ✅ **DONE** (contract documented; no behaviour change needed — §D.2) | `game_providers.dart` |
| 3 | `profile_screen.dart:86` — failure-worded placeholder → honest empty state | ✅ **DONE** | `profile_screen.dart` — §F.4 |
| 4 | `leaderboard_screen.dart:184` | ✅ **RESOLVED — no change required.** Full reasoning at §D.3 | — |
| 5 | `season_countdown_banner.dart:118-119` | ✅ **DONE** | `season_countdown_banner.dart` — §F.5 |
| 6 | `profile_screen.dart:67-79` — a real `else` | ✅ **DONE** | `profile_screen.dart` — §F.4 |
| — | `progression_providers.dart` (named in *Files*, not in *Scope*) | ✅ Contract documented; no behaviour change — §D.2 | `progression_providers.dart` |

### D.1 · The exclusions, honoured

`MASTER_V1.1_RECONCILIATION.md:965` — *"**Exclusions — the hardest constraint in this plan**: No identity-, build-mode-, remote-config- or reviewer-detection-conditional behaviour, in any form (audit A P2). No `firestore.rules` change. No new auth method. No recolour of those screens (BP P13, deferred)."*

| Exclusion | Held? | Evidence |
|---|---|---|
| No conditional behaviour of any kind | ✅ | **[VERIFIED]** No `isReviewer`, `reviewBuild`, `isTestFlight`, `kDebugMode`/`kReleaseMode` feature branch, remote config, allowlist or identity gate appears in the diff. The launch path is identical for every user on every build |
| No `firestore.rules` change | ✅ | **[VERIFIED]** `git diff --name-only` does not list it |
| **No new auth method** | ✅ | **[VERIFIED]** `signInAnonymously()` is the method the app already used, from `firebase_auth`, already a dependency. What changed is **when** it runs and that `currentUser` is consulted first — not **what** it is |
| No recolour of those screens | ✅ | **[VERIFIED]** `PhaseScope(phase: BufonPhase.legacy)` is untouched on both screens; no colour token, spacing token or typography token was edited |

### D.2 · Two files in the *Files* list that needed no behaviour change

**[VERIFIED]** `game_providers.dart:29` and `progression_providers.dart` are named in WP20's *Files / subsystems* line, but neither required a behavioural edit — and editing them for the sake of appearing busy would have been the wrong outcome.

* **`game_providers.dart`** — `userIdProvider` had to stay a writable `StateProvider<String?>` because `home_screen.dart` assigns it after create/join, and `home_screen.dart` is explicitly out of scope for this package. Seeding it at launch is done by **overriding** it in `main()`, which changes the initial value without changing the provider's type or its writability. What the file gained is the **contract**, written down: `null` is now the *failure* value, not the ordinary first-run value. That distinction is the entire point of WP20 and it needed to be recorded where the next reader will look.
* **`progression_providers.dart`** — `userProfileStreamProvider` maps a null id to `Stream.value(null)`. **[VERIFIED]** Turning that into a stream *error* was considered and rejected: `title_providers.dart:45` reads this provider's `.value`, where an error and an empty profile are indistinguishable, so moving the distinction into the provider would have broken it somewhere else. The identity/data distinction is drawn where it can be drawn correctly — at the screen, which reads `userIdProvider` alongside the profile. The file gained the contract in writing.

### D.3 · `leaderboard_screen.dart:184` — resolved as *no change required*

This is the one scope line that did not produce an edit, and it is the most important paragraph in this report.

**[VERIFIED]** Line 184 at HEAD is:

```dart
error: (error, stack) => _buildErrorState(),
```

and `_buildErrorState()` (`:532-545`) already renders `BufonPlaceholder(variant: error, title: 'No se pudo cargar el ranking', actionLabel: 'Reintentar', …)`. The empty branch (`:148-150` → `_buildEmptyState`, `:522-530`) already renders `BufonPlaceholder(title: '¡Sé el primero!', message: 'Juega partidas para aparecer en el ranking …')` on the **empty** variant.

**The two states were already correctly distinguished.** The defect audit A recorded at C-2 §2 was not the error state — it was the **routing into it**:

> *"Leaderboard → `topPlayersProvider` queries `/leaderboards` with no Firebase Auth session; `firestore.rules:227` requires `isAuthenticated()` → permission-denied → `leaderboard_screen.dart:184` `_buildErrorState()`."*

**[VERIFIED]** The cause is the absent auth session, and it is fixed by scope clause 1. With an identity present the read succeeds, returns an empty list, and the screen renders `_buildEmptyState`. Line 184 is then reached only by a genuine failure — which is exactly what it should show.

**Editing line 184 would have been the specific error this package was warned against**: *"Do not turn real backend failures into fake empty states."* A leaderboard that cannot be read is not a leaderboard nobody has played on.

**[VERIFIED]** by test, not by argument: `launch_empty_states_test.dart` asserts **both** halves — an empty board renders the empty state with the isotype and no error icon, and a throwing provider still renders the error state with the retry. Had the fix been to soften line 184, the second test would fail.

---

## E · FILES CHANGED

```
 bufon_flutter/lib/main.dart                                     | 57 +++++++++++-
 bufon_flutter/lib/presentation/screens/profile_screen.dart      | 73 +++++++++++-----
 bufon_flutter/lib/presentation/widgets/season_countdown_banner.dart | 39 ++++++++
 bufon_flutter/lib/providers/game_providers.dart                 | 15 +++-
 bufon_flutter/lib/providers/progression_providers.dart          | 14 +++-
 5 files changed, 180 insertions(+), 18 deletions(-)

+ bufon_flutter/test/launch_empty_states_test.dart                (new)
+ docs/design/v1.1/WP20_IMPLEMENTATION_REPORT.md                  (this report)
```

**[VERIFIED]** Every one of the five production files is in WP20's authorised *Files / subsystems* list. `leaderboard_screen.dart` — also authorised — was deliberately not changed (§D.3). No file outside the list was touched.

---

## F · PER-FILE RATIONALE

### F.1 · `lib/main.dart` — **production**

**Reason.** Scope clause 1: populate the anonymous identity before the first frame.

**Behaviour.** After `AppCheckService.activate()` and after the `app_started` event, `main()` resolves an anonymous uid through a new private helper and seeds `userIdProvider` with it via a `ProviderScope` override:

```dart
final launchUserId = await _resolveAnonymousIdentity();

runApp(
  ProviderScope(
    overrides: [userIdProvider.overrideWith((ref) => launchUserId)],
    child: const MyApp(),
  ),
);
```

`_resolveAnonymousIdentity()` reads `FirebaseAuth.instance.currentUser?.uid` first, and only signs in if there is nothing to restore.

**Four decisions worth stating:**

1. **`currentUser` first.** **[VERIFIED]** audit A L-1: *"`signInAnonymously()` is called on every Create/Join tap without checking `currentUser`… it is why nothing ever restores the UID at launch, which is the mechanism behind C-2."* Reading it first means a returning player restores the uid they already have, with no network round trip and without minting a second anonymous account.
2. **Placed after App Check.** **[VERIFIED]** The existing comment at `main.dart:65-68` states App Check must precede any Firebase service touch so the first request carries an attestation token. The sign-in call obeys that ordering, so **attestation behaviour does not change** — this is the first half of WP20's stop condition, discharged statically (§N.1).
3. **Never fatal.** The `try/catch` records a **non-fatal** through `CrashReporter.recordNonFatal` and returns `null`. **[VERIFIED] This is load-bearing.** `main()` runs inside `CrashReporter.guard`'s zone; an uncaught throw here would mean `runApp` never executes and the app shows a black screen. If Anonymous Auth is disabled in the console — audit A's live hypothesis #4 — that would have converted a degraded launch into no launch at all. The app now starts either way.
4. **The override seeds, it does not replace.** `userIdProvider` remains a writable `StateProvider`, so `home_screen.dart`'s two existing assignments keep working untouched. **[VERIFIED]** by the 301 pre-existing tests still passing, several of which override and read this provider.

### F.2 · `lib/providers/game_providers.dart` — **production**

**Reason.** Scope names `game_providers.dart:29`. **Documentation only; no behaviour change** (§D.2).

**Behaviour.** The `null` default is now documented as the **failure** value — no identity could be established — rather than the ordinary first-run state it used to be, with the explicit instruction that consumers must not render it as "this player has no data yet". This is the contract every other file in the package depends on.

### F.3 · `lib/providers/progression_providers.dart` — **production**

**Reason.** Named in WP20's *Files* list. **Documentation only; no behaviour change** (§D.2).

**Behaviour.** `userProfileStreamProvider`'s contract is written down: `null` data means *signed in, no profile document yet* — the honest empty state — and must never be rendered as a failure. The doc comment also records **why** the identity/data distinction is not drawn here (`title_providers.dart:45` reads `.value`, where an error would be indistinguishable from an empty profile) and points at the screen that does draw it.

### F.4 · `lib/presentation/screens/profile_screen.dart` — **production**

**Reason.** Scope clauses 3 and 6.

**Three behaviours changed:**

* **`profile == null`** now branches on whether an identity exists.
  * *Identity present* → `BufonPlaceholder` **empty** variant: *"Tu perfil empieza aquí"* / *"Juega tu primera partida y aquí aparecerán tu nivel, tus avatares y tus logros."* Copy that says **what to do**, as the scope requires.
  * *No identity* → the **error** placeholder, unchanged in wording, because that is a real failure.
* **The `error:` branch** keeps the error variant and gains a **`Reintentar`** action that invalidates the provider — the affordance `leaderboard_screen`'s equivalent already had and this screen did not. The exception is still never rendered (Capítulo 26); it reaches Crashlytics through the layer that raised it.
* **The share action** got the `else` audit A C-2 §4 recorded as missing. Tapping with no identity produced *nothing at all* — no navigation, no message, no haptic — which reads as a broken control rather than an unavailable one. It now shows `BufonFeedback`, the app's single toast entry point.

A small shared `_buildIdentityError()` holds the two genuine-failure states so they cannot drift apart.

### F.5 · `lib/presentation/widgets/season_countdown_banner.dart` — **production**

**Reason.** Scope clause 5 / audit A **H-1**.

**The finding.** *"Three independent conditions — not authenticated, no active `seasons` document, or any Firestore error — collapse to identical output: an empty box."* Each is now resolved on its own terms:

| Condition | Resolution |
|---|---|
| **Not authenticated** | **Gone.** The read that `firestore.rules:213` denied now succeeds, because clause 1 establishes the identity. Fixed elsewhere, not here |
| **A genuine Firestore error** | **Still renders nothing — but is no longer silent.** Reported through `GameTelemetryService.fail(AppLogCategory.season, 'season_load_failed', …)`, so it appears in Talker and in the Crashlytics breadcrumb trail |
| **No active season** | **Still renders nothing, deliberately.** See below |

**Why "no season" keeps rendering nothing, and why that is the honest answer.** A banner announcing a season that does not exist is not an empty state; it is noise on the app's first screen. **[VERIFIED]** the Blueprint places this banner *below* the primary CTAs precisely so it stops out-competing the brand (Capítulo 3 ley 4), and the in-source comment at `home_screen.dart:266-270` records that reasoning. Home's honest empty state for "no season tonight" **is** the absence of the banner. Rendering a placeholder there would have been a Home composition change — which belongs to BP P1 / **WP26**, not to this package.

**Implementation note.** `ref.listen` rather than a call inside the `error` branch: the branch re-runs on every rebuild, the listener fires once per transition. **[VERIFIED]** by test — exactly one report, and none at all when the season is merely absent.

**[VERIFIED] WP19's boundary is untouched.** `season_load_failed` is deliberately **absent** from `analyticsEventMappings` (`grep -c` → 0), so `AnalyticsDestination.onLog` finds no mapping and returns. It is an internal diagnostic and never a Firebase Analytics event. The 55 outbound event names and gate **S2**/**A4** are unaffected.

### F.6 · `test/launch_empty_states_test.dart` — **test (new)**

Eight tests, §I.

---

## G · EMPTY-STATE BEHAVIOUR

### G.1 · Before → after

| Surface | Clean install **before** | Clean install **after** | Genuine failure **after** |
|---|---|---|---|
| **Profile** | ❌ `BufonPlaceholder(error)` — *"No se pudo cargar el perfil"* | ✅ `BufonPlaceholder(empty)` — *"Tu perfil empieza aquí"* + what to do | ✅ error variant + **Reintentar** |
| **Profile share action** | ❌ Tap does **nothing** — no nav, no message, no haptic | ✅ Navigates (identity present) | ✅ `BufonFeedback` message — never silent |
| **Leaderboard** | ❌ `_buildErrorState()` via permission-denied | ✅ `_buildEmptyState()` — *"¡Sé el primero!"* | ✅ error variant + **Reintentar** (unchanged) |
| **Season banner** | ❌ `SizedBox.shrink()` for *all three* causes, indistinguishably | ✅ `SizedBox.shrink()` — correct for "no season"; the auth cause is gone | ✅ still `SizedBox.shrink()`, **but reported** |

### G.2 · Why the change is correct

**[VERIFIED]** The correction is at the **cause**, not at the symptom. Three of the four surfaces above were reporting a failure that was real — Firestore genuinely denied those reads — for a reason that was not the user's and was never surfaced honestly: nobody had signed in. Establishing the identity at launch removes the denial. Only *then* does the empty state become reachable, and only then is it truthful.

The alternative — softening the error placeholders while leaving the auth gap — would have produced an app that said *"you have no progress yet"* to a signed-out user whose data was sitting in Firestore, unreadable. That is the failure mode this package existed to remove, not to relabel.

### G.3 · The distinction between empty and error, preserved

This was the sharpest risk in the package and it is guarded structurally, not by convention:

| State | Meaning | Renders |
|---|---|---|
| `userId != null`, profile `null` | Signed in, nothing played yet | **EMPTY** |
| `userId == null` | Identity could not be established — a failure | **ERROR** |
| Profile stream errors | Backend failure | **ERROR** + retry |
| Leaderboard returns `[]` | Nobody on the board yet | **EMPTY** |
| Leaderboard throws | Backend failure | **ERROR** + retry |
| Season `null` | No active season | **Nothing** (correct) |
| Season stream errors | Backend failure | **Nothing visually, reported internally** |

**[VERIFIED] by four dedicated tests** — *"no identity is an ERROR, not an empty state"*, *"a failing profile stream is an ERROR with a retry"*, *"a failing board is still an ERROR"*, and *"a failing season still renders nothing but is NOT silent"*. Each fails if a genuine failure is ever laundered into an empty state.

### G.4 · One interpretation recorded, because it is a judgement

Gate **A9** (`:1203`) reads: *"Profile, Leaderboard, Seasons render **empty**, never **error**, unauthenticated with no profile"*, and WP20's *Test strategy* line uses the same phrase.

Read literally — *unauthenticated* meaning `userId == null` — that would require rendering an empty state when sign-in has failed, which is exactly what this package's brief forbids: *"An empty state must not swallow genuine connectivity/authentication/server errors."*

**[INFERRED]** The gate describes the pre-fix diagnosis, not the post-fix contract. R-07's own title is *"…before any room is created"* — the condition is **no data**, not **no auth** — and R-07's scope makes authentication succeed at launch, so *"unauthenticated"* ceases to be the clean-install state the moment the package lands. The scenario A9 cares about — **clean install, nothing played, must not show an error** — is fully satisfied and directly tested.

**This is recorded rather than silently resolved.** It is the one place where a literal gate phrase and the brief's safety rule pull apart, and the reader should see the reasoning rather than discover the divergence later. No product decision was invented: both authoritative documents point the same way once the fix exists.

---

## H · LAUNCH IDENTITY BEHAVIOUR

### H.1 · Before → after

| | Before | After |
|---|---|---|
| Anonymous identity at launch | **None.** `userIdProvider` = `null` until a Create/Join tap | **Resolved before the first frame** |
| Returning player with XP | Identity lost on every relaunch; profile read *"No se pudo cargar el perfil"* until they created or joined a room again | `currentUser` restores the existing uid; profile loads |
| Sign-in failure | N/A — no launch sign-in existed | App still starts; non-fatal recorded; surfaces report honestly |
| Auth accounts created | One per install, on first Create/Join | **Same** — `currentUser` first means no second account is minted |

### H.2 · Technical identifiers — **all untouched**

**[VERIFIED]** `git status --short` over `bufon_flutter/ios` and `bufon_flutter/android` is **empty**. No native, signing or packaging file was modified.

| Identifier | Status |
|---|---|
| Android `applicationId` | untouched |
| Android `namespace` | untouched |
| Kotlin package | untouched |
| Firebase `package_name` | untouched |
| `PRODUCT_BUNDLE_IDENTIFIER` | untouched |
| Signing configuration | untouched |
| Android installed name **Bufón** | preserved — WP16's work, not re-entered |
| iOS `CFBundleDisplayName` / `CFBundleName` = **Bufón** | preserved — WP16's work, not re-entered |

The launch-identity half of WP20 is about the **runtime identity** (`userIdProvider`), not the **product identity** (bundle naming), which WP16 already closed. **[VERIFIED]** the two were kept apart.

---

## I · TESTS

| | |
|---|---|
| **Baseline (measured, pre-change)** | **301** passing, 0 failing |
| **Final** | **309** passing, 0 failing, 0 skipped |
| **Added** | **8**, in 1 new file |
| **Modified** | **0 existing test files** |
| **`flutter analyze`** | **No issues found!** |
| **`git diff --check`** | clean |

### I.1 · `test/launch_empty_states_test.dart`

| Group | Test | Proves |
|---|---|---|
| Profile | signed in with no profile yet is **EMPTY**, not an error | The clean-install state: empty copy present, `BrandMark` present (the empty variant's isotype), `Icons.error_outline` absent, old failure title absent. **Gate A9's actual scenario** |
| Profile | no identity is an **ERROR**, not an empty state | The over-correction guard. A failed sign-in still looks like a failure |
| Profile | a failing stream is an **ERROR** with a retry | Backend failure is never laundered; the new retry exists |
| Profile | the share action is **never silent** without an identity | audit A C-2 §4 — a `SnackBar` appears where nothing used to happen |
| Leaderboard | an empty board is **EMPTY**, not an error | *"¡Sé el primero!"*, isotype, no error icon |
| Leaderboard | a failing board is **still an ERROR** | The second over-correction guard — the test that would have failed had §D.3 been "fixed" by softening line 184 |
| Season | no active season renders nothing, **and reports nothing** | Absence is not a failure; no diagnostic is emitted |
| Season | a failing season renders nothing **but is NOT silent** | audit A H-1 — exactly one `season_load_failed` telemetry event, status `failed` |

**No mocking package was added.** **[VERIFIED]** `pubspec.yaml` is unchanged; `fake_cloud_firestore` was already a dev dependency and is used only to keep `LeaderboardRepository`'s constructor from reaching for `FirebaseFirestore.instance` — the same technique the existing repository stubs use.

**Assertions are on state, not on copy alone.** Each empty/error pair asserts the *variant marker* (`BrandMark` vs `Icons.error_outline`) as well as the text, so rewording the copy later cannot silently turn an empty state back into an error one.

**[VERIFIED] No existing test was weakened, skipped, or made to pass by exception suppression.** Zero existing test files were opened for edit.

---

## J · GOLDEN HASHES

All 10 PNGs under `bufon_flutter/test/golden/goldens/` hashed **before** any edit and **after** the full suite.

| Golden | SHA-256 (before **and** after) |
|---|---|
| `animated_primary_button_disabled.png` | `ec40727fb2b572fc…` |
| `animated_primary_button_outline.png` | `ee377c92f90f5164…` |
| `animated_primary_button_solid.png` | `f9b8fd0c1bcc3de4…` |
| `game_card_disabled.png` | `194cc647580090dc…` |
| `game_card_resting.png` | `506317e562202dbb…` |
| `game_card_selected.png` | `a0425c3352d5a5ec…` |
| `game_progress_bar_midgame.png` | `2c6180cc5c8be984…` |
| `round_indicator.png` | `3963fdb76d7a20ca…` |
| `timer_widget_normal.png` | `f271e1d84bd3a989…` |
| `timer_widget_urgent.png` | `d5912349ab2080d8…` |

**[VERIFIED] All ten byte-identical.** `--update-goldens` was never passed; no golden was regenerated or modified; `git status` shows no change under `test/golden/`. Stop condition 8 did not trigger. **[INFERRED]** expected — WP20 touches no primitive, no token and no rendered component under golden coverage.

---

## K · GIT

```
message : fix: harden launch and empty states
HEAD^   : 9f7d98ee0f7a7b86966d19c443cbcc1e54376653   ← the pre-WP20 HEAD (WP19)
```

The commit's own SHA is deliberately absent: this report is **inside** that commit, so quoting the hash would either be fabricated or require an amend. `HEAD^` is the verifiable anchor; the SHA is reported at the terminal.

**[VERIFIED]** Exactly one commit. **No amend, no rebase, no squash, no reset, no stash, no clean, no force push.** The stash (1 entry) was not applied, dropped or created.

---

## L · PUSH

> ## **NOT PUSHED.**

**[VERIFIED]** `origin/main` remains `2c8337e7d790c79803b7b93f3b0329318cbc2e93`. Three commits are now local-only: `15824db`, `9f7d98e`, and this one.

---

## M · PROTECTED FILES

**[VERIFIED]** All twelve documents re-hashed after implementation; **every hash is identical to the pre-change baseline**:

`Archive.zip` `ede95b58…` · `WP4_RECOVERY_REPORT.md` `a3aaadd4…` · `WP5_RECOVERY_REPORT.md` `adda2315…` · `MASTER_V1.1_RECONCILIATION.md` `d8237e57…` · `BUFON_V1.1_VISUAL_BLUEPRINT.md` `34399e0e…` · `FORENSIC_ANALYSIS_OUTPUT.md` `d2904319…` · `GAMEPLAY_AUDIT_OUTPUT.md` `1c601fc7…` · `CRASHLYTICS_TELEMETRY_AUDIT.md` `b83a1b91…` · `LONG_USERNAME_INCIDENT_FORENSIC_AUDIT.md` `7e89704b…` · `LONG_USERNAME_RECONCILIATION.md` `d83cddb7…` · `WP18_CONSOLE_FACT_FINDING.md` `e2b7dc8c…` · `PRACTICE_MODE_DECISION_GATE.md` `f9a5daba…`

`Archive.zip` was **not extracted**. No protected document was deleted, moved, renamed, staged, committed, modified or overwritten. The Blueprint and the Master Reconciliation are byte-identical.

---

## N · REMAINING WP20-ADJACENT FINDINGS — RECORDED ONLY, NOT IMPLEMENTED

### N.1 · The stop condition, discharged

WP20's own stop condition (`:974`): *"If launch sign-in changes App Check attestation behaviour or Firestore read volume in a way that cannot be reasoned about statically, **stop and measure**."*

**Reasoned statically, and it holds:**

* **App Check attestation** — **[VERIFIED]** unchanged. Sign-in is placed *after* `AppCheckService.activate()`, so the request carries a token exactly like every other Firebase call. No activation order, provider or enforcement setting was touched.
* **Firestore read volume at launch** — **[VERIFIED] zero change.** Nothing watches `userIdProvider` at app start: `roomStreamProvider` keys off `roomCodeProvider` (null → `Stream.value(null)`), and `userProfileStreamProvider` is only watched by `ProfileScreen`. No new read is issued by launching.
* **Firestore read volume on those screens** — **[INFERRED] a real but intended change.** Reads that previously failed fast with permission-denied now **succeed**: `users/{uid}` (one document listener) and `leaderboards/*` (up to 50 documents), each only when the user opens that screen. That is the leaderboard working as designed rather than a new access pattern, and it is bounded by the existing `fetchTopPlayers` limit. **[UNVERIFIABLE from the repository]** the absolute cost in the live project; it belongs to WP21's on-device capture and to WP18's console work.

Stop condition **not** triggered.

### N.2 · Findings observed and deliberately left alone

| # | Finding | Why not now |
|---|---|---|
| **1** | **audit A L-1's other half.** `home_screen.dart:61,104` still call `signInAnonymously()` on every Create/Join tap without checking `currentUser`. Harmless — the SDK returns the existing anonymous user — but now redundant, since the identity already exists at launch | `home_screen.dart` is **explicitly out of scope** for this package. The C-2-relevant half of L-1 (nothing restores the uid at launch) **is** fixed |
| **2** | `_buildEmptyState` / `_buildErrorState` render a non-scrollable `Center` inside the leaderboard's `RefreshIndicator`, so pull-to-refresh cannot be triggered from either state. The **Reintentar** button still works | Pre-existing, unrelated to R-07, and touching it would be opportunistic cleanup |
| **3** | `ProfileScreen` and `LeaderboardScreen` remain on `BufonPhase.legacy`. Their own in-source comments mark this as a migration boundary | **BP P13, explicitly deferred** by WP20's exclusions |
| **4** | The season banner's *"no active season"* state has no Home-side affordance at all. Whether Home should ever say something about seasons is a composition question | Belongs to **BP P1 / WP26**, which owns Home's composition |
| **5** | `FirebaseService.signInAnonymously()` is now a second, parallel path to the same SDK call `main()` makes | `firebase_service.dart` is **not** in WP20's authorised file list. Consolidation is a candidate for a later package |

**None of these was fixed.** Each is recorded here so a later package can decide, and none was allowed to expand this one.

---

## O · EXACT NEXT WORK PACKAGE

Per `MASTER_V1.1_RECONCILIATION.md` §9.3 (`:1060-1092`) and §13.7:

> ### **WP21 — Clean-state reproducibility capture** *(no code)*
>
> *"Convert audit A's source-level proofs into a recorded on-device artefact, and measure WP20's delta."* Its prerequisite is *"best run **after** R-07 to measure the delta"* (R-22) — which is now satisfied.

**[VERIFIED]** WP21 has no code and no repository change. It executes audit A §3's journey against a release-configuration build on a factory-clean device and records what a reviewer actually sees — including gate **M4**, *"Clean-state reviewer journey: WP21's capture set, before and after WP20."*

**Also unblocked, and independent:** **WP22 — Loop stall elimination** (R-08, R-09, R-10 sweep, R-13), the remaining pair of release blockers. **[VERIFIED]** it shares no file with WP20 and has no prerequisite.

**Still open from the WP20.5 gate, no code required:** the **R-20** posture decision and **PD-13**, both of which gate Practice Mode but neither of which gates WP21 or WP22.

**Not started:** WP21, WP22, WP23, WP24, WP25, WP26. Practice Mode not implemented. PD-13 and R-20 not implemented.

---

*WP20 COMPLETE — ONE COMMIT — NOT PUSHED*
