# BUFÓN v1.1 — WP25 · EXIT PATHS, PRESENCE, AND REVIEWER LEGIBILITY

## IMPLEMENTATION REPORT

> ## ARCHIVAL HEADER
>
> This is the **WP25 implementation report**, generated from this execution. Every command, count and hash below was run in the session that produced the commit. **No finding was omitted**, including the two sub-items deliberately not implemented (§C.2).

> | Field | Value |
> |---|---|
> | **Document date** | 2026-09-01 |
> | **Package** | **WP25 — Exit paths, presence, and reviewer legibility** — `MASTER_V1.1_RECONCILIATION.md:1032-1044` |
> | **Findings closed** | **R-11** (audit A **S-5** ≡ BP **P7**, duplicate work **D-2**) · **R-37** (BP **P4**) · **R-12** *partially* · **R-23** *partially* |
> | **HEAD before** | `196412c8fc673f44da285bb871cae5e964b2827b` (WP23) |
> | **HEAD after** | one commit ahead; **`HEAD^ == 196412c…`** |
> | **Commits** | exactly **1** · **not pushed** |
> | **Production files** | 7 changed · 2 added |
> | **Test files** | 1 added · 1 extended · 0 weakened |
> | **Tests** | 343 → **356**, all passing |
> | **Goldens** | 10 · **all byte-identical** |
> | **`firestore.rules` / Cloud Functions / dependencies** | **unchanged** |

**Evidence discipline.** **[VERIFIED]** = demonstrated by a command run in this session or by a test that passed. **[INFERRED]** = derived from verified evidence, derivation stated. **[UNVERIFIABLE]** = not establishable here.

---

## A · VERDICT

> ## **PARTIAL — deliberately, and precisely delimited.**

**R-11 and R-37 are closed in full.** **R-12** and **R-23** are each closed in part, and in both cases the omitted half is gated by the authoritative documents themselves, not by effort or time:

* **R-12's below-2-active room-deletion policy** — WP25's own line reads *"**Design decision first?** Partly — **R-12's eviction policy is a product judgement**; the exit paths are not."* Deciding it here would be inventing a product rule. **STOP conditions 10 and 18 territory; not touched.**
* **R-23's legal surface** — WP25's prerequisite is *"**WP18** for R-23's legal scope"*, and R-23's own `BLOCK` field reads *"a required privacy link is an ASC fact (R-15)"*. **WP21 verified that all twelve WP18 facts remain uncollected.** Not touched.

Calling this COMPLETE would misrepresent two named sub-items. Everything WP25 could decide from its own documents is implemented and tested.

---

## B · BASELINE

```
HEAD          196412c8fc673f44da285bb871cae5e964b2827b   (WP23)
HEAD^         532d3963ac77debe021d6092b618f15e583a2f80   (WP22)
HEAD^^        6f00a2449c7f27c1976ad63604f5f9d9fae6f3b8   (WP20)
HEAD^^^       9f7d98ee0f7a7b86966d19c443cbcc1e54376653   (WP19)
branch        main
origin/main   2c8337e7d790c79803b7b93f3b0329318cbc2e93   (4 behind)
stash         1 entry — untouched
tests         343 passing  ← measured before any edit
analyzer      clean
working tree  no tracked modifications, nothing staged; 13 untracked protected docs
```

Golden hashes recorded before any edit; re-verified identical in §N. The expected chain `… → 9f7d98e → 6f00a24 → 532d396 → 196412c` was confirmed exactly. WP21 produced no commit, as expected.

---

## C · WP25 SCOPE

### C.1 · The authoritative text

> **Scope** A route out of every stream-error placeholder plus a deliberate leave-room affordance with `PopScope` (**R-11**); reconsider pausing the heartbeat on **`inactive`**, the below-2-active room deletion, and the accusatory copy (**R-12**); surface the existing `ConnectionService` as a connectivity banner (**R-37**); a legal surface and an explicit three-player statement on Home (**R-23**, subject to WP18's findings).

### C.2 · How each sub-item resolved

| Source | Sub-item | Status | Basis |
|---|---|---|---|
| **R-11** | Route out of all four stream-error placeholders | ✅ **DONE** | *"the exit paths are not"* a design decision |
| **R-11** | Deliberate leave-room affordance with `PopScope` | ✅ **DONE** | same |
| **R-12** | `inactive` no longer pauses the heartbeat | ✅ **DONE** | §F.2 — an internal inconsistency, not a policy choice |
| **R-12** | Below-2-active room deletion | ❌ **NOT DONE — product judgement** | WP25: *"R-12's eviction policy is a product judgement"* |
| **R-12** | The accusatory copy | ✅ **DONE** | copy, not policy |
| **R-37** | Connectivity banner | ✅ **DONE** | `BLOCK NO`; *"no new dependency; no new service"* |
| **R-23** | Explicit three-player statement on Home | ✅ **DONE** | needs no external fact |
| **R-23** | Legal / privacy surface | ❌ **NOT DONE — evidence-gated** | prerequisite *"WP18 for R-23's legal scope"*; R-23 `DEPS R-15`; WP21 verified all WP18 facts uncollected |

### C.3 · No scope conflict was found between documents

**[VERIFIED — this pass]** The Blueprint (P7, P4), the Master Reconciliation (WP25, R-11, R-12, R-23, R-37) and the Gameplay Audit agree on ownership. The one place they could have collided — BP P7's *"Overflow menu with leave-room"*, a Lobby composition change — is resolved by R-11's own non-goal (*"not a navigation-architecture change"*) and by that composition belonging to **WP26**. No visible leave control was added to any screen; the affordance is the system-back interception (§G.2).

---

## D · EXIT-PATH RECONSTRUCTION — before

Traced from HEAD before any edit. All **[VERIFIED]**.

| # | Path | Before |
|---|---|---|
| 1 | Leaving a room deliberately | **Did not exist.** `grep 'PopScope\|WillPopScope\|leaveRoom'` → **0 hits**, exactly as R-11 recorded |
| 2 | Exiting from lobby / answering / voting / round result | No control on any of them |
| 3 | Returning Home | Only as a *consequence* — room deleted, or player no longer in the roster |
| 4 | Returning to Lobby | No path; `joinRoom` rejects any phase but `lobby` |
| 5 | Android system back | **The only exit — and a broken one.** Every room screen is the root of its stack (`replaceFadeSlide` / `pushAndRemoveAllFade`), so back popped the **application** while the player's document, heartbeat and room membership all stayed alive. The room then waited 20 s for someone who was not coming back |
| 6 | Stream-error placeholders | `lobby_screen`, `voting_screen`, `round_result_screen`: `BufonPlaceholder` with **no `actionLabel`, no `onAction`** — the widget renders no button at all. `game_screen` alone had one |
| 7 | The exit sequence itself | Duplicated privately as `_navigateToHomeWithMessage` in `lobby_screen` and `game_screen`; absent from the other two |

**Audit A S-5, quoted in the reconciliation:** *"Once a room stream fails, **no route out exists**: no back arrow, no retry, no home button. The reviewer must force-quit."*

---

## E · PRESENCE RECONSTRUCTION — before

**[VERIFIED]** The architecture distinguishes more states than one word suggests, and WP25 kept them distinct:

| Concept | Where it lives | Meaning |
|---|---|---|
| **Physically disconnected** | `Player.isDisconnected` — `lastSeen` older than 20 s | Two missed beats. WP22's eligibility predicate |
| **Heartbeat lost** | `ConnectionService._isConnectionLost` — 2 consecutive failures | The *client's* view; deliberately matched to the same 20 s window *"so the two views of 'disconnected' agree"* |
| **App backgrounded** | `_AppLifecycleObserver` → `pauseHeartbeat` | Writes `isOnline: false`, cancels the timer |
| **Explicitly leaving** | **Did not exist** | — |
| **Timed-out / stale** | `cleanupDisconnectedPlayers` | Deletes the player document; reassigns host; deletes the room below 2 active |
| **Removed by host** | Does not exist | No kick feature |
| **Room completed** | `finishGame` → `finalWinner` | Room persists |

**The defect. [VERIFIED]** `_AppLifecycleObserver` treated `AppLifecycleState.inactive` as a pause. On iOS `inactive` fires for Control Centre, the app switcher and a notification banner — transient interruptions where the app is still foreground and the player has gone nowhere. Pausing there stopped the beats, and two missed beats is precisely the eviction window.

**[VERIFIED] The codebase already disagreed with itself about this.** `AppSessionObserver` — shipped, and untouched by WP19 on audit C's instruction — handles the same event and says so in its own words:

> *"`inactive` fires for transient interruptions — a notification shade, an incoming call, the app switcher — and closing a session there would shred the metric into fragments."*

Two observers, one lifecycle event, opposite conclusions.

---

## F · ROOT CAUSES

### F.1 · R-11 — no route out, and no way to leave

Two distinct absences with one consequence. The placeholders had no action because `BufonPlaceholder` renders its button only when both `actionLabel` and `onAction` are non-null, and three call sites passed neither. Separately, nothing anywhere implemented "leave" — so the only exit was a system gesture that abandoned the app without releasing anything.

**Why it needed one implementation, not four.** R-11's non-goal is that *"leaving must not be able to corrupt room state"*. Four screens leaving four different ways cannot guarantee that; the sequence was already duplicated twice and would have become four copies.

### F.2 · R-12 — `inactive` treated as backgrounding

§E. **[VERIFIED]** This is an internal inconsistency with a documented in-repo precedent, not an open product judgement — which is why it was implemented while the eviction *policy* was not.

### F.3 · R-37 — a service with no UI

**[VERIFIED]** `ConnectionService` has beaten every 10 s since launch, escalated a lost connection to telemetry, and had **no UI at all** — the Blueprint's own component table records it as *"Heartbeat only, no UI"*. A player whose beats were failing had no way to know, and audit A H-2's confusion had no explanation on screen.

### F.4 · R-23 — the requirement was never stated

**[VERIFIED]** audit A M-4: *"nothing tells the reviewer the game needs 3 people"*, recorded in audit A §3 as a block point on the app's first screen.

### F.5 · One defect found while implementing, and fixed at its source

**[VERIFIED — this pass]** `ConnectionService` resolved `FirebaseFirestore.instance` **eagerly in its constructor**. The connectivity banner reads `connectionServiceProvider` to watch the notifier, and that construction threw `[core/no-app]` in every widget test that had not overridden the provider — **45 failures**.

The fix is at the cause, not the call sites: the handle is now lazy, mirroring `RoomRepository`'s existing, documented treatment of `FirebaseFunctions` — *"`FirebaseFunctions.instance` throws until `Firebase.initializeApp` has run, and this repository is constructed by a provider that may be read earlier — and by tests that never start Firebase at all."* **No test was edited to accommodate it.** Production is unaffected: `Firebase.initializeApp` runs in `main` long before any room screen builds.

---

## G · IMPLEMENTATION

### G.1 · `RoomExit.toHome` — one exit contract

A new `lib/presentation/navigation/room_exit.dart`. The order is deliberate and documented in-source:

1. **Stop the heartbeat first** — writes `isOnline: false`, cancels the timer. Navigating first would leave a timer beating against a room the player has left.
2. **Clear `roomCodeProvider`** — `roomStreamProvider` watches it and collapses to `Stream.value(null)`, so the listener detaches instead of feeding a disposed screen.
3. **Hand the message over before navigating** — `BufonFeedback` uses the root messenger `MaterialApp` owns, which lives *above* the Navigator, so the message survives the retreat. This is WP12's finding, reused rather than rediscovered.
4. **Retreat** — `pushAndRemoveAllFade` (Capítulo 23), clearing the stack so back cannot walk into a room the player has left.

**The player document is deliberately not deleted.** Removal is `cleanupDisconnectedPlayers`' job on the 20 s window WP22's eligibility filtering depends on; deleting here would create a second, competing eviction path. `isOnline: false` plus a stopped heartbeat makes the player ineligible immediately and evicted shortly after — the existing contract, unchanged. **Asserted by test.**

### G.2 · `RoomPopScope` — the deliberate affordance

`PopScope(canPop: false)` on all four room screens → a confirm dialog → the same `RoomExit.toHome`. System back becomes a deliberate leave instead of an app-kill with live membership.

**No visible leave control was added.** That is a composition change BP owns (P7's overflow menu), and R-11's non-goal forbids a navigation-architecture change. No router package was introduced — BP line 1037.

### G.3 · The four placeholders

Each now carries `actionLabel: GameCopy.backToHome` and `onAction: () => RoomExit.toHome(context, ref)`. `game_screen`'s pre-existing exit was left in place and is covered by the same test.

### G.4 · `inactive` no longer pauses

`_AppLifecycleObserver` drops `inactive` from the pause branch. `paused`, `detached` and `hidden` still pause. **Eviction is untouched**: the 20 s window, the sweep and WP22's eligibility filtering are unchanged, and a real backgrounding still delivers `paused`. **Both halves asserted by test.**

### G.5 · The connectivity banner

`ConnectionService` gains `ValueNotifier<bool> connectionLost`, mirroring the existing `_isConnectionLost` through a single `_setConnectionLost` setter so the two cannot drift — no second opinion about what "disconnected" means. `ConnectionBanner` listens and **renders `SizedBox.shrink()` while connected**, so every existing layout, including WP4/WP5's viewport and text-scale matrices, is unchanged in the normal case. It carries a `liveRegion` semantics label.

**[VERIFIED]** No new dependency, no new service — R-37's non-goals.

**One disposal bug found and fixed in the same file:** `dispose()` called `stopHeartbeat()` (async) and then disposed the notifier immediately, so `stopHeartbeat`'s tail wrote to a dead notifier. Now `stopHeartbeat().whenComplete(connectionLost.dispose)`. Caught by an existing test, not by inspection.

### G.6 · Copy and the three-player statement

`GameCopy` gains `backToHome`, the four leave-dialog strings, `roomClosedTooFewPlayers`, `connectionLost` and `playersRequired`. The accusatory `'La sala se cerró por desconexión'` is gone from `lib/` — it blamed the player's connection for a room deleted because fewer than two active players remained.

Home now states the requirement above the name field and below the tagline, as a caption in `inkMuted` — no composition change, one line.

---

## H · EXIT SCENARIOS

| Scenario | Before | After |
|---|---|---|
| Stream error on **lobby** | Dead end — no button at all | Route out via `RoomExit` ✅ |
| Stream error on **answering** | Had an exit | Unchanged, same contract ✅ |
| Stream error on **voting** | Dead end | Route out ✅ |
| Stream error on **round result** | Dead end | Route out ✅ |
| **Android back**, any room screen | Popped the app; membership, heartbeat and document all left alive | Confirm dialog → real exit, or stay ✅ |
| Declining the dialog | n/a | Stays in the room; `roomCodeProvider` untouched ✅ |
| Leaving mid-phase | n/a | Heartbeat stopped, `isOnline: false`, room code cleared, document **preserved** for the sweep ✅ |
| Leaving with no network | n/a | `_markOffline` is best-effort and already catches; the 20 s sweep evicts anyway. Navigation still completes **[INFERRED]** |
| Leaving while already disconnected | n/a | Same path; idempotent ✅ |
| **Exit after the game ends** | `FinalWinnerScreen` already had a *"Salir"* CTA | **Unchanged** — §J |

**[VERIFIED] Navigation safety.** `RoomExit.toHome` guards `context.mounted` after its `await`, and `pushAndRemoveAllFade` clears the stack, so there is no dead screen to pop into, no stale room to return to, and no double navigation. `ref` is read **before** the first await, never across the gap.

---

## I · PRESENCE / HOST SCENARIOS

| Scenario | Before | After |
|---|---|---|
| Control Centre / app switcher / notification banner (**`inactive`**) | Heartbeat paused; `isOnline: false`; two missed beats ⇒ **eviction**, and for a solo host, **the room deleted** | Heartbeat keeps beating; player stays online ✅ |
| Genuine backgrounding (**`paused`** / `hidden` / `detached`) | Paused | **Unchanged — still pauses** ✅ |
| Non-host disconnects | Evicted by the 20 s sweep | Unchanged |
| Host disconnects | Sweep promotes `activePlayers.first` | **Unchanged — host election not redesigned** |
| Host explicitly leaves | No such path | Leaves like anyone else; the sweep promotes a new host on its existing rule ✅ |
| Player reconnects | The document survives until the sweep removes it | Unchanged |
| Room falls below 2 active | **Deleted** | **Unchanged — product judgement, not decided here** (§C.2) |
| Copy when that happens | *"La sala se cerró por desconexión"* — accusatory and wrong | *"La sala se cerró: quedaron muy pocos jugadores."* ✅ |

**[VERIFIED] Explicit leave and disconnect remain separate concepts.** Leaving stops the heartbeat and writes presence deliberately; a transient interruption now does neither. Backgrounding is not turned into a permanent leave, and network instability is not either — the banner reports it and the beat keeps trying.

---

## J · FINAL CEREMONY

**What WP25 changed: nothing.**

**[VERIFIED]** `FinalWinnerScreen` already offers a terminal exit — a *"Salir"* CTA calling `_exitToHome` — so the chain *final result → ceremony → available exit → valid destination* was already complete. R-11's scope names four stream-error placeholders and the ceremony is not among them.

**What WP25 deliberately did NOT change, and why:**

* **"El más aburrido"** — **[VERIFIED]** the Master Reconciliation assigns it to **R-43**, which is `v1.1: NO — post-v1.1`, `DEPS: PD-7, PD-8; R-17`. It appears **nowhere** in WP25's scope, sources or files. Implementing it would require deciding what "most boring" means mathematically (**PD-7**) and the tie/tone policy (**PD-8**), both undecided — **STOP condition 17**, avoided by not starting.
* **Winner or loser selection** — WP24's, blocked on **PD-4**.
* **The ceremony's data contract** — `standings`, `votesReceived`, `totalScore` and `isCurrentUserWinner` are passed exactly as before.

---

## K · SCORING BOUNDARY

**[VERIFIED] Untouched, by inspection of the complete diff:**

| Item | Changed? |
|---|---|
| Score calculation | **NO** — `submitVote.ts`, `VOTE_POINTS`, every `score` write |
| XP | **NO** — `onMatchCompleted.ts` |
| Ranking | **NO** |
| Tie-breaking | **NO** — **PD-4 not decided, not consumed, not required** |
| Winner selection | **NO** |
| Loser selection | **NO** — does not exist |
| Reward calculation | **NO** |

No WP25 change reads or writes a score. **STOP conditions 1, 2 and 3 did not trigger.**

---

## L · WP22 / WP23 PRESERVATION

**[VERIFIED]** by the full suite: all 15 `loop_stall_test.dart` tests (WP22) and all 19 `question_repetition_test.dart` tests (WP23) pass unchanged.

| WP22 guarantee | Intact? | Note |
|---|---|---|
| Eligibility filtering (`Player.eligible`) | ✅ | `player.dart` untouched |
| Disconnected players do not pin answering | ✅ | predicate untouched |
| Voting completion + disconnect sweep | ✅ | untouched |
| Sole-answerer cannot deadlock (`>= 2` ballot guard) | ✅ | untouched |
| Zero-answer recovery | ✅ | untouched |
| Timeout idempotency (`_advanceRequested`) | ✅ | untouched |
| Stale timer cannot act on a later phase | ✅ | transaction preconditions untouched |
| **Disconnect eviction still works** | ✅ | **`paused` still pauses — asserted by a dedicated test.** WP25's own stop condition |

| WP23 guarantee | Intact? |
|---|---|
| Question history room-scoped | ✅ `room.dart`, `room_repository.dart` untouched |
| Host reassignment preserves history | ✅ |
| New rooms use 60 s | ✅ |
| Legacy 90 s rooms respected | ✅ |
| Corpus loading guard on a promoted host | ✅ |
| Transactional `advanceToNextRound` | ✅ |

**[VERIFIED]** WP25 **consumes** these systems and rewrites none. Neither `room_repository.dart` nor `player.dart` nor `room.dart` appears in the diff. **STOP condition 8 did not trigger.**

---

## M · TESTS

| | |
|---|---|
| **Baseline (measured)** | **343** |
| **Final** | **356** passing, 0 failed, 0 skipped |
| **Added** | **13**, in 1 new file |
| **`flutter analyze`** | **No issues found!** |
| **`git diff --check`** | clean |

### M.1 · `test/room_exit_test.dart` — 13 tests

| Group | Test | Fails pre-WP25 because |
|---|---|---|
| R-11 | lobby / answering / voting / round result **offer a route out** (4 tests) | three placeholders had `onAction: null` — asserted on the **widget's action**, not a label, because a null action renders no button at all |
| R-11 | **it stops the heartbeat, clears the room, and lands Home** | no exit existed. Asserts four states: room code cleared · `isOnline: false` written · **document still exists** · landed on Home |
| R-11 | **system back asks first, and staying does not leave** | back popped the app |
| R-11 | confirming the dialog performs the real exit | — |
| R-12 | **`inactive` does NOT pause the heartbeat** | it did. Asserts a beat still *lands* after the interruption — `lastSeen` advances — not merely that a flag is set |
| R-12 | **`paused` still does — eviction is unchanged** | the guard on WP25's own stop condition |
| R-12 | the accusatory copy is gone | — |
| R-37 | renders nothing while connected (`Size.zero`) | the banner did not exist; this is what keeps every existing layout unchanged |
| R-37 | appears when the heartbeat is lost, with a live-region label | — |
| R-23 | Home states the three-player requirement | it did not |

### M.2 · Test quality

**[VERIFIED]** Assertions are on **state**, not labels: `roomCodeProvider`'s value, the player document's `isOnline` and `lastSeen`, the document's existence, the placeholder widget's `onAction`, and the rendered size of the banner. No broad mock stands between the test and the behaviour — `ConnectionService` is the **real** service against `FakeFirebaseFirestore`, so `stopHeartbeat`'s write actually runs.

**No `tester.takeException()`** and no exception suppression appears anywhere in the file.

### M.3 · The one existing test touched, and why it is not a weakening

`room_exit_feedback_test.dart` asserted the literal `'La sala se cerró por desconexión'` in three places. R-12 changed that copy, so the assertions now read `GameCopy.roomClosedTooFewPlayers` — **from the production constant**, so they cannot drift. The behaviour under test — that the message survives the navigation, WP12's finding — is unchanged, and a header comment records why the literal became a constant.

---

## N · GOLDENS

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

**[VERIFIED] All ten byte-identical.** No golden-regeneration command of any form was run. **STOP condition 12 did not trigger.**

**[INFERRED]** Expected: the goldens cover primitives with explicit props, and the one new visual element renders zero-sized in the state those tests exercise.

---

## O · SCOPE AUDIT

| Item | Changed? | Evidence |
|---|---|---|
| Scoring · XP · ranking · tie-breaking | **NO** | §K |
| Question selection · corpus | **NO** | `question_service.dart`, `assets/questions.json` untouched |
| 60-second timer | **NO** | `room.dart` untouched |
| **WP22 stall logic** | **NO** | §L — no file WP22 owns appears in the diff |
| **WP19 telemetry boundary** | **NO** | `lib/analytics/**` untouched; no new event name; the 55 outbound names unchanged; gates **A4/T-A** and **S2** unaffected |
| **WP20 launch identity** | **NO** | `main.dart`, `progression_providers.dart`, `profile_screen.dart`, `leaderboard_screen.dart`, `season_countdown_banner.dart` untouched |
| Practice Mode | **NO** | not implemented, not referenced |
| Username limits | **NO** | PD-13 |
| UGC / moderation | **NO** | R-20 |
| **Firestore Rules** | **NO** | `firestore.rules` untouched — gate **S4** |
| **Cloud Functions** | **NO** | `functions/` untouched |
| **3-player minimum** | **NO** | guard untouched |
| **8-player maximum** | **NO** | guard untouched |
| Dependencies | **NO** | `pubspec.yaml`/`pubspec.lock` unchanged — gate **S6** |
| "El más aburrido" | **NO** | §J — R-43, post-v1.1 |

**[VERIFIED] No stop condition triggered.** Two sub-items were *not attempted* precisely because they would have (10) required a product decision on host/eviction policy and (9) required an external fact for the legal surface — both recorded rather than guessed.

### O.1 · Two new files, declared

WP25's *Files / subsystems* line names eight existing files, all of which were touched. Two files were **added**:

* `lib/presentation/navigation/room_exit.dart` — the single exit contract. R-11's non-goal (*"leaving must not be able to corrupt room state"*) is only guaranteeable if all four screens leave identically; the alternative was four copies of a sequence that was already duplicated twice.
* `lib/presentation/widgets/connection_banner.dart` — R-37 requires a UI surface and `lib/presentation/widgets/` is where every other Bufón primitive lives. Inlining it four times would have been worse.

Neither adds a dependency, a service, or a navigation architecture.

---

## P · GIT

```
message : fix: harden exit paths and presence
HEAD^   : 196412c8fc673f44da285bb871cae5e964b2827b   ← the pre-WP25 HEAD (WP23)
```

**Files in the commit:**

```
bufon_flutter/lib/core/game_copy.dart
bufon_flutter/lib/presentation/navigation/room_exit.dart          (new)
bufon_flutter/lib/presentation/widgets/connection_banner.dart     (new)
bufon_flutter/lib/screens/game_screen.dart
bufon_flutter/lib/screens/home_screen.dart
bufon_flutter/lib/screens/lobby_screen.dart
bufon_flutter/lib/screens/round_result_screen.dart
bufon_flutter/lib/screens/voting_screen.dart
bufon_flutter/lib/services/connection_service.dart
bufon_flutter/test/room_exit_feedback_test.dart
bufon_flutter/test/room_exit_test.dart                            (new)
docs/design/v1.1/WP25_IMPLEMENTATION_REPORT.md
```

The commit's own SHA is deliberately absent: this report is inside that commit.

**[VERIFIED]** Exactly one commit. **No amend, no rebase, no squash, no reset, no stash, no clean, no force push.** History intact: `HEAD^` → WP23, `HEAD^^` → WP22, `HEAD^^^` → WP20, `HEAD^^^^` → WP19.

---

## Q · PUSH

> ## **NOT PUSHED.**

**[VERIFIED]** `origin/main` remains `2c8337e7d790c79803b7b93f3b0329318cbc2e93`. Six commits are local-only: `15824db`, `9f7d98e`, `6f00a24`, `532d396`, `196412c`, and this one.

---

## R · PROTECTED FILES

**[VERIFIED]** Untouched, none staged or committed:

`docs/design/Archive.zip` · `FORENSIC_ANALYSIS_OUTPUT.md` · `GAMEPLAY_AUDIT_OUTPUT.md` · `CRASHLYTICS_TELEMETRY_AUDIT.md` · `MASTER_V1.1_RECONCILIATION.md` · `WP18_CONSOLE_FACT_FINDING.md` · `WP4_RECOVERY_REPORT.md` · `WP5_RECOVERY_REPORT.md` · `BUFON_V1.1_VISUAL_BLUEPRINT.md` · `WP19_IMPLEMENTATION_REPORT.md` · `WP20_IMPLEMENTATION_REPORT.md` · `WP21_CLEAN_STATE_REPRODUCIBILITY_REPORT.md` · `WP22_IMPLEMENTATION_REPORT.md` · `WP23_IMPLEMENTATION_REPORT.md` · `LONG_USERNAME_*` · `PRACTICE_MODE_DECISION_GATE.md`

`Archive.zip` was **not extracted**. The stash (1 entry) is untouched.

---

## S · REMAINING FINDINGS — LATER PACKAGES ONLY

| # | Finding | Owner |
|---|---|---|
| 1 | **R-12's below-2-active room deletion** — a solo host who genuinely backgrounds for >20 s still loses the room. **`inactive` no longer triggers it**, which removes the common accidental path, but the policy stands | **Product decision** — WP25: *"R-12's eviction policy is a product judgement"* |
| 2 | **R-23's legal / privacy surface** | **WP18 → R-15**; all twelve facts uncollected per WP21 |
| 3 | **BP P7's visible leave affordance** (overflow menu on the Lobby) — system back is covered; a visible control is a composition change | **WP26** (BP P1/P7 composition) |
| 4 | **R-43 "El más aburrido"** | post-v1.1; **PD-7**, **PD-8**, **R-17** |
| 5 | **R-19** — ceremony `votesReceived` shows the last round, not the night | unclaimed; independent of PD-4 |
| 6 | **PD-2** — a present-but-silent voter still holds voting open | **PD-2** |
| 7 | **WP21's device gates** — `M4`, `M5`, `M8` (*"Exit path from every stream-error screen"*) still need a real device. **WP25 makes M8 testable; it does not discharge it** | **WP21**, re-run |

**None of these was fixed.**

---

## T · NEXT WORK PACKAGE

Per `MASTER_V1.1_RECONCILIATION.md` §9.3 (`:1060-1092`), with WP25 complete the sequence has one code package left:

```
WP18 ∥ WP19 ✅ → WP20 ✅ → WP21 (blocked, no code)
WP22 ✅ ─┬→ WP23 ✅
         └→ WP25 ✅
PD-4 ────→ WP24  (blocked)
WP26 ── Blueprint completion sweep   (last; no blocking content)
```

> ### **WP26 — Blueprint completion sweep.**

**[VERIFIED]** *"Close the remaining in-scope Blueprint roadmap items that need no product decision."* It carries **R-24**, **R-26**, **R-29 … R-40** — `wakelock_plus`, the paywall migration, legacy-palette deprecation, the `SeasonAccent` enum, the icon sweep, navigation completion, reduce-motion, `PhaseBanner`, field-level validation (**R-38**), duration tokens, opacity/icon scales, ATS, dead-file removal. Its prerequisites are *"none technically; sequenced last because it is the only package with **no** release-blocking content"*, and **golden integrity is its primary gate**.

**[VERIFIED] WP24 remains blocked** on **PD-4**, which is undecided.

**Also actionable now, no code:** decide **PD-2**, **PD-4**, **PD-9**, **PD-13**, **R-20**'s posture and **R-12**'s eviction policy; and execute **WP18**'s console protocol, which WP21 identified as the harder of its two blockers and which now also gates R-23's remaining half.

**Not started:** WP24, WP26. Practice Mode not implemented.

---

*WP25 PARTIAL — TWO SUB-ITEMS DECISION- AND EVIDENCE-GATED — ONE COMMIT — NOT PUSHED*
