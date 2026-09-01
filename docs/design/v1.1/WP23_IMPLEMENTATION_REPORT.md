# BUFÓN v1.1 — WP23 · QUESTION REPETITION + ROUND-TIMER DECISION

## IMPLEMENTATION REPORT

> ## ARCHIVAL HEADER
>
> This is the **WP23 implementation report**, generated from this execution. Every command, count and hash below was run in the session that produced the commit. **No finding was omitted**; the terminal summary points here rather than replacing this document.

> | Field | Value |
> |---|---|
> | **Document date** | 2026-09-01 |
> | **Package** | **WP23 — Question repetition** — `MASTER_V1.1_RECONCILIATION.md:1004-1016`, plus the **PD-1** round-duration decision WP22 unblocked |
> | **Findings closed** | **R-14** (corpus) · **R-18** (used-question history) · audit B **G-2A…G-2G**, **X-3** · **PD-1** decided and implemented |
> | **HEAD before** | `532d3963ac77debe021d6092b618f15e583a2f80` (WP22) |
> | **HEAD after** | one commit ahead; **`HEAD^ == 532d396…`** |
> | **Commits** | exactly **1** · **not pushed** |
> | **Production / asset files changed** | 6 production + 1 asset |
> | **Test files** | 1 added · 1 extended · 0 weakened |
> | **Tests** | 324 → **343**, all passing |
> | **Goldens** | 10 · **all byte-identical** |
> | **`firestore.rules` / Cloud Functions / dependencies** | **unchanged** — X-3 confirmed none was needed |

**Evidence discipline.** **[VERIFIED]** = demonstrated by a command run in this session or by a test that passed. **[INFERRED]** = derived from verified evidence, derivation stated. **[UNVERIFIABLE]** = not establishable here.

---

## A · VERDICT

> ## **COMPLETE.**

Both halves delivered: the corpus restored to the prototype's 100 questions, the used-question history moved off the host device onto the room with a transactional field-level write, and the answering clock set to 60 s per PD-1. Nineteen new tests close a G-2 row that had **zero coverage**. No stop condition triggered.

---

## B · BASELINE

```
HEAD          532d3963ac77debe021d6092b618f15e583a2f80   (WP22)
HEAD^         6f00a2449c7f27c1976ad63604f5f9d9fae6f3b8   (WP20)
HEAD^^        9f7d98ee0f7a7b86966d19c443cbcc1e54376653   (WP19)
branch        main
origin/main   2c8337e7d790c79803b7b93f3b0329318cbc2e93   (live `git ls-remote`; 3 behind)
tests         324 passing  ← measured before any edit
analyzer      clean
working tree  no tracked modifications, nothing staged; 12 untracked protected docs
```

**Golden hashes recorded before any edit** — re-verified identical in §K. The expected chain `… → 9f7d98e → 6f00a24 → 532d396` was confirmed exactly; WP21 produced no commit, as expected.

---

## C · QUESTION-SELECTION RECONSTRUCTION

Traced from HEAD before any edit. All **[VERIFIED]**.

| # | Question | Answer at WP22 HEAD |
|---|---|---|
| 1 | Where the corpus is defined | `bufon_flutter/assets/questions.json` — **20** entries, `{id, text, pack}` |
| 2 | How it loads | `QuestionService.loadQuestions()` → `rootBundle.loadString`, into an instance field `_questions` |
| 3 | How the current question is selected | `QuestionService.getRandomQuestion(usedQuestionIds)` — filters out used ids, then `Random().nextInt` over the remainder |
| 4 | How a question is marked used | It was not, durably. The **caller** appended the id to a Riverpod `StateProvider` |
| 5 | Where used state lived | `usedQuestionIdsProvider` — `StateProvider<List<String>>` in `game_providers.dart:58` |
| 6 | **Scope of that state** | **Host device memory, per `ProviderScope`.** Not the round, not the room, not the backend. Lost on process death |
| 7 | When it reset | **Every game.** `lobby_screen.dart:145` called `getRandomQuestion([])` — a literal empty list — and overwrote the provider |
| 8 | On host change | The promoted host's provider held **its own** list, normally empty. It also held an **unloaded `QuestionService`**, because only the lobby called `loadQuestions()` |
| 9 | On reconnect | The room's `currentQuestionId` persists, so the *displayed* question survives; the *history* did not |
| 10 | At corpus exhaustion | `question_service.dart:24-27` — *"If all questions used, reset and pick any."* An existing, documented rule |
| 11 | Can multiple clients select? | Only the host reaches either selection site (`lobby_screen` start CTA, `round_result_screen` host-only CTA) |
| 12 | Authoritative or client-driven? | **Client-driven selection, room-authoritative display.** The host picks; the room document's `currentQuestionId` / `currentQuestionText` is what every device renders |
| 13 | Can two clients race? | Not two *concurrent* hosts — but a **handover** creates a second selection authority with different state (see 8) |
| 14 | Can a question repeat within a game? | **Yes**, via 8 |
| 15 | Can it repeat in adjacent rounds? | **Yes**, same mechanism |

**[VERIFIED]** The audit's description matches HEAD exactly. Stop condition 18 did not trigger.

---

## D · QUESTION REPETITION ROOT CAUSE

**Two independent mechanisms, both verified, neither requiring corruption or a randomness failure.**

### D.1 · Per-game reset — the 80.6 % figure

`lobby_screen.dart:145` passed a **literal empty list** on every game start. A room's second game therefore drew from the full 20-question corpus again, with the first game's five questions fully eligible. The audit computes the consequence: an **80.6 % chance of at least one repeat across two consecutive games**.

### D.2 · Host-local storage — audit B **G-2E**

The history lived in the host device's memory. `cleanupDisconnectedPlayers` (`room_repository.dart`) promotes `activePlayers.first` when the host drops — and that device's `usedQuestionIdsProvider` was normally empty, so the very next draw could re-ask a question the room had already used **inside the same game**.

**[VERIFIED] A second, compounding defect on the same path:** the promoted host's `QuestionService` had never called `loadQuestions()`, because only `lobby_screen` did. `_advanceRound` called `getRandomQuestion` directly, so a promoted host drew from an **empty corpus** and hit `_questions[_random.nextInt(0)]` — an `ArgumentError`. Found while tracing G-2E for this package; closed here as part of the same handover path.

### D.3 · Why the observed duplicate needs no other explanation

**[VERIFIED]** With a 20-question corpus, five rounds per game and a history that resets every game, a repeat across two games is the *expected* outcome, not an anomaly. `Random()` is unseeded and behaving correctly.

---

## E · QUESTION REPETITION FIX

### E.1 · The corpus — R-14

**[VERIFIED]** `assets/questions.json`: **20 → 100**. Restored from the React prototype at `6636976:src/questions.js` via `git show`. **The stash was not applied** — WP23's exclusion and R-14's non-goal both forbid it.

Verified mechanically before writing:

```
prototype strings : 100     unique: 100
existing 20       : exactly the prototype's first 20, text-identical
diff              : 400 insertions, 0 deletions  ← purely additive
```

**The shipped 20 keep their ids, text and packs unchanged.** That is load-bearing: renumbering would orphan the history already written into live room documents.

The restored 80 get ids `q021`–`q100` and a **stated, reproducible pack rule** — a question opening with *"¿Quién"* goes to `ALGUIEN DE AQUÍ` (the pack whose name means exactly that), the rest alternate between `DI LA NETA` and `¿QUÉ PEDO?`. Final distribution 35 / 33 / 32. **[VERIFIED]** `pack` is inert today: pack-selection UI is **BP I11**, deferred and explicitly excluded from WP23, so this cannot change behaviour. It only leaves the field meaningful for I11.

**PD-9** *"shapes the target size but blocks nothing"*. 100 is not an invented target — it is the number the prototype shipped and the number R-14 names.

### E.2 · The history — R-18

`Room` gains `usedQuestionIds: List<String>`, persisted on the room document.

| Was | Is |
|---|---|
| `usedQuestionIdsProvider` — host device memory | `Room.usedQuestionIds` — the room document |
| lost on host handover | one shared list, one owner |
| lost on process death | durable |
| reset to `[]` every game | **accumulates across the games a room plays** |

`usedQuestionIdsProvider` was **removed**, not deprecated — the room stream already carries the value, so nothing replaces it.

### E.3 · The protected scope, and where it comes from

> **Per room, accumulating across games, until exhaustion.**

**Derived from two authoritative statements, not chosen:**

1. WP23's **Objective** — *"Reduce a verified **80.6 %-over-two-games** repeat rate."* The rate it exists to reduce is measured **across games**, so a per-game scope could not satisfy it.
2. WP23's **Scope** — *"move used-question history off the host device **onto the room**."* The room outlives a single game: `gamesPlayedToday`, `lastGameDate` and the Night Pass all exist because a room hosts many games in a night.

This is PD-9's **per-room** option. **[VERIFIED]** PD-9 remains formally open on corpus *size*; if it later prefers a different scope the change is one line in `startFirstRound` (append vs. replace). Recorded in §P.

### E.4 · Exhaustion — **not invented**

**[VERIFIED]** The behaviour already existed and is documented in-source: `question_service.dart:24-27`, *"If all questions used, reset and pick any."* WP23's own test strategy lists *"exhaustion fallback"* as something to **cover**, not to define.

`question_service.dart` was therefore **not modified at all** — its no-replacement filter and its fallback were already correct. **[VERIFIED]** `git diff --name-only` does not list it. Stop condition 2 did not trigger.

**[INFERRED]** Reach: 100 questions ÷ 5 per game = **20 games in one room** before the fallback engages, against a prior figure of 4.

### E.5 · X-3 — the whole-document clobber

The old advance path was `clearRoundData` + `updateRoom(currentRoom.copyWith(...))`, and `updateRoom` writes **`room.toJson()` — the entire document** — built from a snapshot the client read earlier. Two defects:

* **Clobber.** Every field the client did not intend to change was rewritten with a stale value, including `gamesPlayedToday`, `adUnlocksRemaining` and `nightPassExpiresAt` — all server-owned, the last written only by the `verifyNightPass` Cloud Function through the Admin SDK. **[INFERRED]** Worse than silent corruption: `firestore.rules:54-79` guards exactly those fields, so once the server moved one, the client's stale rewrite would appear in `changedKeys()` and **the round advance would be rejected outright**.
* **Not transactional.** `currentRound + 1` was computed on the client from that same stale snapshot.

**Fix:** a new `RoomRepository.advanceToNextRound({roomCode, questionId, questionText})` — one transaction, a `roundResult` phase precondition, and a write of exactly the six fields a round change owns. `currentRound + 1` and the history append both derive from the transaction's **own read**.

**[VERIFIED] `firestore.rules` needed no change**, exactly as X-3 predicted: the update rule constrains only the monetisation and host fields this never touches, and leaves everything else *"as open as it was"*. WP23's verification line requires `firestore.rules` **unchanged**, and it is. Stop conditions 3 and 4 did not trigger, and the *"stop and split"* condition did not either — the clobber was avoidable without a broader repository change.

### E.6 · Host reassignment

Two fixes on that path, both minimal:

1. The history is on the room, so a promoted host reads the same list (§E.2).
2. `_advanceRound` now guards `getAllQuestions().isEmpty → loadQuestions()`, closing the `ArgumentError` at §D.2.

**[VERIFIED]** `cleanupDisconnectedPlayers` and the presence logic WP22 touched were **not modified**. Host reassignment was not redesigned.

---

## F · TIMER RECONSTRUCTION

**[VERIFIED]** `grep -rn "\b90\b" lib` before the change returned six hits. Only **three** were the answering clock:

| Site | Role | Changed? |
|---|---|---|
| `models/room.dart:36` — `this.roundDuration = 90` | **the authoritative default**, written into every new room document | ✅ → 60 |
| `models/room.dart:80` — `json['roundDuration'] as int? ?? 90` | fallback for a document with no field | ✅ → 60 |
| `screens/game_screen.dart:42` — `int _remainingSeconds = 90` | first-frame placeholder before the room snapshot arrives | ✅ → 60 |
| `core/theme/app_elevation.dart:16` | a comment, *"~90 % of components"* | ❌ |
| `screens/final_winner_screen.dart:204` | a comment about confetti | ❌ |
| `presentation/widgets/confetti_widget.dart:29` | `night(count: 90…)` — **particle count** | ❌ |

**No global replacement was performed.** The brief's instruction was explicit and is honoured.

**Early completion path** (WP22, unchanged): `game_screen.dart` computes `allAnswered` over `room.players.eligible`, and `_scheduleAutoVoting` fires on `canOpenBallot && (allAnswered || expired)`.

**Timeout path** (WP22, unchanged): `_remainingSeconds <= 0` sets `expired`; the transition still requires `answeredCount >= 2`.

**Voting:** **[VERIFIED] untouched.** WP22 bounded voting with the disconnect sweep, not a clock, and WP23 adds none — a visible voting clock remains **PD-2**'s.

---

## G · PD-1 IMPLEMENTATION

### G.1 · The decision

**PD-1** (`:1268-1271`) lists *"keep 90 · adopt 60 · adopt 30 · differ per stage · host-configurable · scale with player count"*, records that *"the repository holds three values and no authority"*, and recommends *"decide, but only after WP22."*

**The owner has decided: 60 s.** That is the product decision PD-1 says is theirs, and it matches *"the players' request"* PD-1 itself records as the origin of the 60 option.

**[VERIFIED] The ordering constraint is satisfied.** Audit B **X-1**: *"a shorter clock **without** fixing G-1G/G-1H increases exposure to a hard stall."* WP22 (`532d396`) closed both. WP23 is the first package permitted to shorten the clock, and the reconciliation's *"WP22 before any round-duration change"* is honoured by construction.

### G.2 · Resulting behaviour

* A **new** room runs a **60 s** answering round.
* All eligible players answering early still advances immediately after the existing 2 s beat — **60 s is a maximum, not a wait**.
* At expiry the WP22 fallback is unchanged: advance if the ballot is votable, otherwise stay in `answering` with the field live.

### G.3 · The migration note PD-1 asked to settle

PD-1: *"settle the existing-rooms migration — `Room.fromJson` falls back to 90, so a default change affects new rooms only."*

**Settled and tested. [VERIFIED]** A room document written before WP23 carries its own `roundDuration: 90` and **keeps it for its lifetime** — `fromJson` reads the stored value and the fallback fires only for a document that never had the field. A game in progress is not retroactively shortened mid-round. Three tests pin all three cases: new room → 60, missing field → 60, stored 90 → **90**.

**[VERIFIED]** No migration or backfill was written, and none is needed — rooms are ephemeral and deleted when they fall below two active players.

---

## H · WP22 PRESERVATION

Every WP22 invariant re-verified. **[VERIFIED]** by the 15 tests in `loop_stall_test.dart` passing unchanged in the final suite.

| WP22 invariant | Intact? | Evidence |
|---|---|---|
| Disconnected/ineligible players cannot pin **answering** | ✅ | *answering advances when the only non-answerer has dropped* |
| Voting has safe completion over eligible players | ✅ | *voting advances when the only non-voter has dropped* |
| Voting sweeps disconnected players, before the transition | ✅ | *the sweep runs, and runs before the transition* |
| Sole-answerer cannot deadlock | ✅ | *ONE answer is rejected — this is the deadlock* |
| Zero-answer cannot strand the room | ✅ | *the room recovers: a later answer advances it* |
| An expired round with < 2 answers attempts nothing | ✅ | two tests, unchanged |
| Timeout cannot duplicate a transition | ✅ | *the answering auto-advance fires once, not repeatedly* |
| A stale timer cannot act on a later phase | ✅ | transaction phase preconditions, unchanged — and **strengthened**, §H.2 |
| R-13 double-tap advances one round | ✅ | assertion followed to the new method, §J.3 |
| The 2 s beat (conflict K-1, BP G16) | ✅ | untouched |
| `Player.eligible` / `hasAnswered` | ✅ | untouched |
| `_advanceRequested` fire-once latch | ✅ | untouched |

### H.1 · WP22 files touched, and why that was acceptable

Two of WP23's changes land in files WP22 modified. Both are tightly scoped, as the brief requires:

* **`room_repository.dart`** — in WP23's own file list. WP23 **adds** `advanceToNextRound` and appends one line to `startFirstRound`'s transaction. WP22's `_minimumBallotAnswers` guard, `moveToVoting` and `moveToRoundResult` are **byte-unchanged**.
* **`round_result_screen.dart`** — in WP23's own file list. WP23 changes only the tail of `_advanceRound`. WP22's `_isAdvancing` flag, its `finally`, and the disabled/loading CTA are **unchanged**.
* **`game_screen.dart`** — *not* in WP23's file list, but PD-1's timer placeholder lives there. **One field plus a comment.** No WP22 predicate, guard or latch was touched.

### H.2 · WP22 was strengthened, not weakened

**[VERIFIED]** `advanceToNextRound`'s `roundResult` phase precondition is the **server-side half** of R-13. WP22's `_isAdvancing` flag stops the double *tap* on one device; this stops the double *write*, at the only layer that can guarantee it across devices. Tested by *advanceToNextRound refuses from the wrong phase*.

---

## I · FILES CHANGED

| # | Path | Kind | Reason |
|---|---|---|---|
| 1 | `assets/questions.json` | **asset** | R-14 — corpus 20 → 100, purely additive |
| 2 | `lib/models/room.dart` | production | `usedQuestionIds` (R-18); `roundDuration` 90 → 60 (PD-1) |
| 3 | `lib/data/repositories/room_repository.dart` | production | `advanceToNextRound` (X-3); `startFirstRound` appends the history |
| 4 | `lib/screens/lobby_screen.dart` | production | Draw against the room's history instead of a literal `[]` |
| 5 | `lib/screens/round_result_screen.dart` | production | Draw against the room's history; call `advanceToNextRound`; load the corpus on a promoted host |
| 6 | `lib/providers/game_providers.dart` | production | Remove `usedQuestionIdsProvider` |
| 7 | `lib/screens/game_screen.dart` | production | PD-1 first-frame placeholder — one field |
| 8 | `test/question_repetition_test.dart` | **test (new)** | 19 tests, §J |
| 9 | `test/loop_stall_test.dart` | test (extended) | **Not weakened** — §J.3 |

**[VERIFIED] `lib/services/question_service.dart` was NOT changed** although WP23's file list permits it: its no-replacement filter and exhaustion fallback were already correct, and editing it would have been change for its own sake.

---

## J · TESTS

| | |
|---|---|
| **Baseline (measured)** | **324** passing |
| **Final** | **343** passing, 0 failed, 0 skipped |
| **Added** | **19**, in 1 new file |
| **`flutter analyze`** | **No issues found!** |
| **`git diff --check`** | clean |

### J.1 · `test/question_repetition_test.dart` — 19 tests

Closes audit B §9.3's G-2 row, which was at **zero coverage**.

| Group | Test | Fails pre-WP23 because |
|---|---|---|
| R-14 | holds the prototype's 100 questions | corpus was 20 |
| R-14 | every id is unique | — (guard) |
| R-14 | every text is unique | — (guard; two ids with one text would defeat de-dup) |
| R-14 | every question is complete and packed | — (guard) |
| R-14 | the shipped 20 keep their ids and text | — (guards against renumbering orphaning live history) |
| R-14 | **selection never replaces while anything remains** | exercised across all 100 draws, not asserted from code shape |
| R-14 | exhaustion falls back rather than failing | — (pins the existing documented rule) |
| PD-1 | a new room runs 60 seconds | was 90 |
| PD-1 | a document with no duration falls back to 60 | was 90 |
| PD-1 | **an existing 90-second room keeps its own value** | the migration note, pinned |
| R-18 | history round-trips through the document | the field did not exist |
| R-18 | a pre-WP23 document reads as an empty history | forward-compatibility |
| R-18 | `startFirstRound` records the question it opened with | wrote no history |
| R-18 | **a second game APPENDS — it does not reset** | **the 80.6 % rate, at its source** |
| R-18 | `advanceToNextRound` appends and counts from its own read | the method did not exist |
| R-18 | `advanceToNextRound` refuses from the wrong phase | R-13's server-side half |
| X-3 | **it does not rewrite the fields the server owns** | `updateRoom` rewrote the whole document |
| G-2 | **a five-round game asks five distinct questions** | audit B named this exact missing test |
| G-2E | **a host handover preserves the history** | history was host-local memory |

### J.2 · The tests exercise the real path

**[VERIFIED]** The corpus tests load the **real** `assets/questions.json` through `QuestionService.loadQuestions()`. The durability tests drive the **real** `RoomRepository` against `FakeFirebaseFirestore` and assert on the **document**, not on a return value. No test inspects a constant list.

The host-handover test constructs a **second `RoomRepository` instance** sharing no Dart state with the first — standing in for the second device — and asserts it reads the history and draws around it.

**One piece of scaffolding, declared:** `reachRoundResult()` sets the room's phase directly, standing in for the two WP22-owned transitions that need players and votes and have their own coverage in `loop_stall_test.dart`. The code under test — `advanceToNextRound` — is the real implementation throughout.

### J.3 · The one existing test touched, and why it is not a weakening

`loop_stall_test.dart`'s R-13 double-tap test asserted on `updateRoom`. WP23 moved the round advance onto `advanceToNextRound`, so the assertion follows the call to where it now lives.

**The invariant is identical — one advance per double tap — and the assertion is not loosened.** The stub also gains an `advanceToNextRound` override, which is required for *correctness*: without it the real implementation would reach the empty fake, throw `ROOM_NOT_FOUND`, and the test would pass by recording nothing. Every other assertion in the file is unchanged, and all 15 WP22 tests pass.

**[VERIFIED]** No test was deleted, weakened, skipped or exception-suppressed. No `skip:`, no loosened matcher, no `try/catch` around an assertion appears in the diff.

---

## K · GOLDENS

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

**[VERIFIED] All ten byte-identical.** No golden-regeneration command of any form was run. Stop condition 13 did not trigger.

**[INFERRED]** Worth noting given PD-1: `timer_widget_normal` and `timer_widget_urgent` are golden-tested with **explicit** `remainingSeconds`/`totalSeconds` props, so a change to the room's *default* duration cannot reach them.

---

## L · SCOPE AUDIT

| Item | Changed? | Evidence |
|---|---|---|
| Scoring | **NO** | `submitVote.ts`, `VOTE_POINTS`, every `score` write untouched |
| XP | **NO** | `onMatchCompleted.ts` untouched |
| Ranking | **NO** | R-17/PD-4 untouched |
| Tie-breaking | **NO** | untouched |
| Winner selection | **NO** | `round_result_screen`'s sort untouched |
| "El más aburrido" | **NO** | R-43, not implemented |
| Username limits | **NO** | PD-13, `home_screen.dart` untouched |
| UGC / moderation | **NO** | R-20 untouched |
| Practice Mode | **NO** | not implemented, not referenced |
| **Analytics / WP19** | **NO** | `lib/analytics/**` untouched; no new event name; the 55 outbound names unchanged; gates **A4/T-A** and **S2** unaffected |
| **Launch identity / WP20** | **NO** | `main.dart`, `progression_providers.dart`, `profile_screen.dart`, `leaderboard_screen.dart`, `season_countdown_banner.dart` untouched |
| **WP22 stall logic** | **NO** | §H — every invariant re-verified; the eligibility, ballot-guard and latch code is unchanged |
| **Firestore Rules** | **NO** | `firestore.rules` untouched — X-3 confirmed none needed; WP23's own verification line requires this |
| **Cloud Functions** | **NO** | `functions/` untouched |
| **3-player minimum** | **NO** | `startFirstRound`'s `playerCount < 3` guard untouched |
| **8-player maximum** | **NO** | `joinRoom`'s `playerCount >= 8` guard untouched |
| Dependencies | **NO** | `pubspec.yaml`/`pubspec.lock` unchanged — gate **S6** |
| Pack-selection UI | **NO** | BP I11, excluded |
| Seeded `Random()` | **NO** | excluded; selection remains unseeded |
| The stash | **NOT APPLIED** | `git show` only; stash list still 1 entry |

**[VERIFIED] No stop condition triggered.** The protected scope was derivable (§E.3); exhaustion was already defined (§E.4); no rules or function change was needed; question authority was preserved with the existing architecture; host reassignment needed no redesign; PD-1 was consistent across documents; 90 → 60 violated no WP22 invariant.

---

## M · GIT

```
message : fix: prevent question repetition and shorten round timer
HEAD^   : 532d3963ac77debe021d6092b618f15e583a2f80   ← the pre-WP23 HEAD (WP22)
```

**Files in the commit:**

```
bufon_flutter/assets/questions.json
bufon_flutter/lib/data/repositories/room_repository.dart
bufon_flutter/lib/models/room.dart
bufon_flutter/lib/providers/game_providers.dart
bufon_flutter/lib/screens/game_screen.dart
bufon_flutter/lib/screens/lobby_screen.dart
bufon_flutter/lib/screens/round_result_screen.dart
bufon_flutter/test/loop_stall_test.dart
bufon_flutter/test/question_repetition_test.dart
docs/design/v1.1/WP23_IMPLEMENTATION_REPORT.md
```

The commit's own SHA is deliberately absent: this report is **inside** that commit, so quoting it would either be fabricated or require an amend. `HEAD^` is the verifiable anchor.

**[VERIFIED]** Exactly one commit. **No amend, no rebase, no squash, no reset, no stash, no clean, no force push.** No history rewritten: `HEAD^` resolves to WP22, `HEAD^^` to WP20, `HEAD^^^` to WP19.

---

## N · PUSH

> ## **NOT PUSHED.**

**[VERIFIED]** `origin/main` remains `2c8337e7d790c79803b7b93f3b0329318cbc2e93`. Five commits are now local-only: `15824db`, `9f7d98e`, `6f00a24`, `532d396`, and this one.

---

## O · PROTECTED FILES

**[VERIFIED]** Untouched, none staged or committed:

`docs/design/Archive.zip` · `FORENSIC_ANALYSIS_OUTPUT.md` · `GAMEPLAY_AUDIT_OUTPUT.md` · `CRASHLYTICS_TELEMETRY_AUDIT.md` · `MASTER_V1.1_RECONCILIATION.md` · `WP18_CONSOLE_FACT_FINDING.md` · `WP4_RECOVERY_REPORT.md` · `WP5_RECOVERY_REPORT.md` · `BUFON_V1.1_VISUAL_BLUEPRINT.md` · `WP19_IMPLEMENTATION_REPORT.md` · `WP20_IMPLEMENTATION_REPORT.md` · `WP21_CLEAN_STATE_REPRODUCIBILITY_REPORT.md` · `WP22_IMPLEMENTATION_REPORT.md` · `LONG_USERNAME_*` · `PRACTICE_MODE_DECISION_GATE.md`

`Archive.zip` was **not extracted**. The stash (1 entry) is untouched — WP23's exclusion honoured.

---

## P · REMAINING FINDINGS — LATER PACKAGES ONLY

| # | Finding | Owner |
|---|---|---|
| 1 | **PD-9 remains formally open on corpus size.** WP23 restored the prototype's 100 as R-14 names; a different target is a data change | **PD-9** |
| 2 | **The de-duplication scope is per-room.** Derived from WP23's objective and storage location (§E.3). If PD-9 later prefers per-session or per-device, it is one line in `startFirstRound` | **PD-9** |
| 3 | **Selection is still client-driven.** The host picks; the room is authoritative for *display*. A server-side draw is **R-45**'s general fix | **R-45**, post-v1.1 |
| 4 | **`Random()` is unseeded.** A seeded draw is *"a new capability, not a restoration"* and is excluded | excluded by WP23 |
| 5 | **Pack-selection UI** — `pack` is populated and inert | **BP I11**, gated on exactly this corpus expansion, now satisfied |
| 6 | **PD-2** — a present-but-silent voter still holds voting open; the sweep bounds disconnection, not inaction | **PD-2** |
| 7 | **G-1I** — the countdown timer is recreated every frame; `_remainingSeconds` is assigned outside `setState`, so the first painted frame can be one value stale | LOW, unclaimed |
| 8 | **R-11 / R-12** — exit paths and presence | **WP25** |
| 9 | **A manual two-consecutive-game repeat check** is WP23's own verification line and **[UNVERIFIABLE]** here — it needs three devices | **WP21**'s device gates |

**None of these was fixed.**

---

## Q · NEXT WORK PACKAGE

Per `MASTER_V1.1_RECONCILIATION.md` §9.3 (`:1060-1092`):

```
WP22 ──┬──> WP23  ✅ complete
       └──> WP25 ── Exit paths + presence      (D-3, shared eviction machinery)
PD-4 ──────> WP24 ── Final ranking
WP26 ── Blueprint completion sweep             (last)
```

> ### **WP25 — Exit paths, presence, and reviewer legibility.**

**[VERIFIED]** Its prerequisite — *"WP22 before WP25"*, dependency **D-3**, shared eviction machinery — is satisfied, and WP23 did not touch that machinery. It carries **R-11** (no route out of a failed room stream; no leave-room affordance) and **R-12** (the lobby destroys the room after a ~20 s app switch; the heartbeat pauses on `inactive`), both `SEV HIGH`.

**[VERIFIED] WP24 remains blocked** on **PD-4** — *"PD-4 before WP24"* — which is undecided.

**Also actionable now, no code:** decide **PD-2**, **PD-4**, **PD-9**, **PD-13** and **R-20**'s posture; and execute **WP18**'s console protocol, which WP21 identified as the harder of its two blockers.

**Not started:** WP24, WP25, WP26. Practice Mode not implemented.

---

*WP23 COMPLETE — ONE COMMIT — NOT PUSHED*
