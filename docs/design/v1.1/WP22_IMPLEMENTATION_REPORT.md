# BUFÓN v1.1 — WP22 · LOOP STALL ELIMINATION

## IMPLEMENTATION REPORT

> ## ARCHIVAL HEADER
>
> This is the **WP22 implementation report**. It was generated from this execution — every command, count and hash below was run in the session that produced the commit. **No finding was omitted from this archival report**; the terminal summary is a pointer to this document, not a substitute for it.

> | Field | Value |
> |---|---|
> | **Document date** | 2026-09-01 |
> | **Package** | **WP22 — Loop stall elimination** — `MASTER_V1.1_RECONCILIATION.md:990-1002` |
> | **Findings closed** | **R-08** (G-1F) · **R-09** (G-1G, G-1H) · **R-10** *sweep variant* (G-1F voting) · **R-13** (G-2F) · incidentally **G-1J** |
> | **Release blockers cleared** | **R-08** and **R-09** — the last two gameplay blockers of the eleven at `:1250` |
> | **HEAD before** | `6f00a2449c7f27c1976ad63604f5f9d9fae6f3b8` (WP20) |
> | **HEAD after** | one commit ahead; **`HEAD^ == 6f00a24…`**. The commit's own SHA cannot appear inside a file that is part of it; it is reported at the terminal |
> | **Commits** | exactly **1** · **not pushed** |
> | **Production files changed** | 5 |
> | **Test files** | 1 added · 1 extended · 0 weakened |
> | **Tests** | 309 → **324**, all passing |
> | **Goldens** | 10 · **all byte-identical** |
> | **Dependencies / rules / functions** | **unchanged** |

**Evidence discipline.** **[VERIFIED]** = demonstrated by a command run in this session or by a test that passed. **[INFERRED]** = derived from verified evidence, derivation stated. **[UNVERIFIABLE]** = not establishable here.

---

## A · VERDICT

> ## **COMPLETE.**

All four reconciled findings in WP22's scope are closed, with fifteen regression tests that fail against the pre-WP22 code. No stop condition triggered. **One scope item was deliberately not implemented — the 90 s → 60 s round duration — because the authoritative documents exclude it from this package; §D.5 gives the full reasoning and this is flagged rather than silently omitted.**

---

## B · BASELINE

```
HEAD          6f00a2449c7f27c1976ad63604f5f9d9fae6f3b8   (WP20)
HEAD^         9f7d98ee0f7a7b86966d19c443cbcc1e54376653   (WP19, intact)
branch        main
origin/main   2c8337e7d790c79803b7b93f3b0329318cbc2e93   (3 commits behind)
tests         309 passing  ← measured before any edit
analyzer      clean
working tree  no tracked modifications, nothing staged; 11 untracked protected docs
```

**Golden hashes recorded before any edit** — all ten re-verified identical in §J.

---

## C · ROOT CAUSES ADDRESSED

### C.1 · G-1F / **R-08** — completion counted every player document, with no eligibility filter

**Actual root cause. [VERIFIED]** Both predicates iterated the whole subcollection:

```dart
game_screen.dart:244   final allAnswered = room.players.every((p) => p.currentAnswer != null);
voting_screen.dart:194 final allVoted    = room.players.every((p) => p.votedFor != null);
```

`room.players` comes from `watchRoom`'s `playersStream`, which maps **every** document with no filter on `isOnline`, `lastSeen` or `isDisconnected`. And `Player.isDisconnected` — the concept, already modelled at `player.dart:23-27` — had **zero call sites in the entire application**.

**Consequences, both verified by the audit and reproduced in test:**

* **Answering:** one dropped or backgrounded player made `allAnswered` permanently false, so the room burned the entire 90 s clock. The audit names this *"the most likely mechanism behind the testers' actual complaint — they experienced 'waiting for the clock' precisely because someone had dropped, not because early advance is missing."*
* **Voting:** an unbounded hard stall. No clock, and `cleanupDisconnectedPlayers` was never called from voting. *"The game is stuck with no recovery path other than every player leaving the room."*

**Fix.** A `PlayerEligibility` extension on `Iterable<Player>` (`player.dart`) exposing `.eligible`, and both predicates routed through it. R-08's scope asked for *"an explicit eligible-player predicate"* using the concept `player.dart` already defines — this is the call site it never had.

### C.2 · G-1G / **R-09** — the single-answerer voting deadlock

**Actual root cause. [VERIFIED]** `moveToVoting`'s guard rejected only `answeredCount == 0`, so `answeredCount == 1` passed and the room entered `voting`. There, the ballot held exactly one card, and `submitVote` forbids its author from choosing it (`submitVote.ts:49-51` SELF_VOTE_FORBIDDEN) while every other card is absent (`:89-95` VOTED_FOR_HAS_NO_ANSWER). **The sole answerer had no legal vote in existence.** `allVoted` could never become true, `_scheduleAutoResults` never fired, and voting has no clock. Permanently dead.

**Fix.** `moveToVoting` now requires `answeredCount >= 2`. R-09 asks for this *"at the transition guard, not in the UI"* — this is that guard, and the deadlock state is now unreachable rather than recoverable-from.

**The number is derived, not chosen.** Two is what the existing vote rules make the minimum votable ballot: with one answer its author is the one person forbidden from picking it. No product rule was invented and the self-vote rule was not touched.

### C.3 · G-1H / **R-09** — the zero-answer expiry stranded the room

**Actual root cause. [VERIFIED]** At expiry with no answers, `moveToVoting` threw `NO_ANSWERS_SUBMITTED`, `game_screen` caught it and toasted *"Nadie respondió. Denle otra oportunidad al caos."* — *"but there is no retry, no round reset, and no path forward."*

**And it was worse than a stall. [VERIFIED — this pass]** The host's device *looped*: `_scheduleAutoVoting` ran on every build with `shouldAdvance = allAnswered || _remainingSeconds <= 0`, still true at expiry. The timer nulled itself inside its own callback and `_moveToVoting`'s `finally` called `setState`, so the rebuild re-armed it. **An error toast every two seconds, for as long as the room existed.** The audit recorded the stranding; the spin is a detail this pass adds.

**Fix, and why it introduces no new mechanic.** The host no longer attempts a transition the guard is certain to reject: `shouldAdvance` now requires `answeredCount >= 2`. The room stays in `answering` — where the answer field is still rendered and `submitAnswerTransaction` still accepts, because **it checks the phase, not the clock**. A second answer arriving at any time flips `shouldAdvance` true and the round proceeds on its own.

> **The recovery path is the phase the room is already in.**

This matters because R-09's non-goals are explicit: *"do not add a round-retry mechanic (no such path exists and inventing one is a product decision)."* The shipped copy promises *"another chance"*; the round staying open **is** that chance, delivered without inventing a retry. Proven end to end by *"the room recovers: a later answer advances it"* (§H).

### C.4 · G-1F voting half / **R-10** *(sweep variant)* — voting had no disconnect sweep

**Actual root cause. [VERIFIED]** `cleanupDisconnectedPlayers` was called from `lobby_screen.dart:81`, `:135`, `game_screen.dart:145` and `round_result_screen.dart:119` — *"never from `voting_screen.dart`"*. A player who dropped mid-vote left `votedFor` null on a document nothing would ever remove.

**Fix.** `_moveToResults` sweeps before transitioning, the same ordering `_moveToVoting` already used. **Sweep variant only** — no visible voting clock, which needs PD-2 and Blueprint coordination and is excluded by WP22's own scope line.

### C.5 · G-2F / **R-13** — the round-result CTA had no in-flight guard

**Actual root cause. [VERIFIED]** `_nextRound` (`round_result_screen.dart:99`) had no `_isAdvancing` flag, though both siblings did. A double tap ran `_advanceRound` twice: two question draws — one discarded, silently consuming a question from the round's history without ever showing it — and two `currentRound + 1` writes off the same stale snapshot. The phase transitions are transaction-guarded, but `_advanceRound`'s non-final branch is a whole-document `updateRoom`, which is not.

**Fix.** The flag its siblings have, plus a disabled/loading CTA — two layers, both exercised by the regression test.

### C.6 · G-1J — client and server disagreed on "answered" *(incidental, in-scope)*

**[VERIFIED]** The screens tested `currentAnswer != null`; the repository (`:395-401`) and the ballot builder (`voting_screen.dart:199-203`) both required non-empty after trimming. Recorded by the audit as *latent* — unreachable because the rules and `submitAnswerTransaction` both reject empty answers.

**Fix.** `Player.hasAnswered` states the server's definition once, and the screens use it. Closed as a by-product of routing the predicates through a named concept rather than as separate work.

---

## D · ANSWERING FLOW

### D.1 · Eligibility definition

```dart
extension PlayerEligibility on Iterable<Player> {
  Iterable<Player> get eligible => where((player) => !player.isDisconnected);
}
```

**[VERIFIED]** `Player.isDisconnected` is a 20 s `lastSeen` threshold, matched to the 10 s heartbeat — two missed beats — and identical to the threshold `cleanupDisconnectedPlayers` already uses (`room_repository.dart:727`). WP22 introduces no new presence concept and no new timing constant.

**Deliberately narrow.** Eligibility is **presence**, not participation. A disconnected player is still in the room, still owns their score, and is still removed only by the sweep. This narrows exactly one thing: *who a phase is allowed to wait for*. The brief asked these predicates to be kept apart, and they are:

| Predicate | Meaning | Used for |
|---|---|---|
| present in room | has a player document | the roster, scoring, standings |
| **eligible** | present **and** heartbeat fresh | **who a phase waits for** |
| `hasAnswered` | non-empty answer after trim | completion count, ballot membership |
| allowed to vote | any player; target must have an answer and not be self | `submitVote` (unchanged) |
| host | `room.hostId == userId` | who may trigger a transition |

### D.2 · Early completion

```dart
final eligible       = room.players.eligible.toList();
final answeredCount  = eligible.where((p) => p.hasAnswered).length;
final allAnswered    = eligibleCount > 0 && answeredCount == eligibleCount;
final canOpenBallot  = answeredCount >= 2;

shouldAdvance: canOpenBallot && (allAnswered || expired)
```

All eligible players answered → the existing 2 s beat → advance. **The 2 s value is untouched** (conflict K-1: BP G16 owns it).

The `eligibleCount > 0` clause matters: `every` on an empty list is `true`, so without it a room whose entire roster had gone stale would report "everyone answered".

### D.3 · Timeout

**[VERIFIED] Unchanged in mechanism and in value.** The clock is still local, still derived from `roundStartTime` and `roundDuration`, still host-driven for the transition. WP22 changed *what the fallback is allowed to do*, not how long it runs: at expiry the room now advances only if the ballot is votable.

### D.4 · Disconnect handling

A dropped player stops being counted immediately (eligibility), and is removed from the room by the sweep `_moveToVoting` already ran before transitioning. **[VERIFIED]** by *"answering advances when the only non-answerer has dropped"* — the test the audit said did not exist.

### D.5 · Round duration — **NOT CHANGED**, and why

The brief states a product requirement: *"answering rounds should not unnecessarily last 90 seconds; target maximum is 60 seconds"*, while also instructing: *"Do NOT blindly replace 90 with 60… **If the authoritative documents specify a different exact timing contract, follow them and document the difference.**"*

**They do, in three places. [VERIFIED]**

| Source | Says |
|---|---|
| `MASTER_V1.1_RECONCILIATION.md:994` — WP22 **Exclusions** | *"**No round-duration change (that is WP23, and O-2 requires this package first).**"* |
| **PD-1**, `:1268-1271` | Round duration is an **open product decision** — *"the repository holds three values and no authority — 90 (current), 30 (React prototype), 60 (the players' request)"*. *"RECOMMENDATION: **decide, but only after WP22.**"* |
| audit B **X-1**, a hard ordering constraint | *"a shorter clock **without** fixing G-1G/G-1H increases exposure to a hard stall"* |

**The requirement is real and this package is its prerequisite, not its owner.** X-1 is the substantive point: shortening the clock multiplies the chance of reaching expiry with fewer than two answers, which is precisely the deadlock WP22 exists to close. Changing 90 → 60 *before* this package landed would have made the product worse.

**[VERIFIED] WP22 delivers most of the felt improvement anyway, without touching the number.** The audit is explicit that early advance already existed and that the reason players sat through the clock was G-1F — a dropped player pinning `allAnswered` false. That is fixed. A room where everyone is present and answers has never waited 90 s; a room where someone dropped no longer does either.

**Recorded as a finding for WP23 / PD-1 (§O), not implemented here.**

### D.6 · Zero-answer handling

See §C.3. At expiry with fewer than two answers the host attempts nothing, the room stays in `answering`, the answer field stays live, and a later answer advances it. **No new phase, no new rule, no retry mechanic.**

---

## E · VOTING FLOW

### E.1 · Eligible voters

Connected players. **Every one of them can now cast a legal vote**, because §C.2 guarantees at least two answers on the ballot: a non-answerer has ≥ 2 legal targets, an answerer has ≥ 1. The condition that made a required vote impossible is gone at its source.

### E.2 · Completion predicate

```dart
final votedCount = eligible.where((p) => p.votedFor != null).length;
final allVoted   = eligibleCount > 0 && votedCount == eligibleCount;
```

### E.3 · The ballot is deliberately *not* filtered the same way

**[VERIFIED]** `shuffledPlayers` still offers every answer, including one from a player who has since dropped. `submitVote` accepts any target with an answer, so narrowing who we *wait on* must not narrow what is *on offer* — removing a dropped player's answer mid-vote would change the ballot under voters who had already read it. Two predicates, two jobs.

### E.4 · Sole-answerer case

**Unreachable.** The guard in §C.2 refuses to open that ballot. **[VERIFIED]** by *"ONE answer is rejected — this is the deadlock"*, which asserts both the exception code and that the room stays in `answering`.

### E.5 · Timeout

**No visible clock was added** — excluded by WP22's scope, needs PD-2. The bound is the **sweep**: a player who stops heart-beating stops blocking completion (eligibility) and is then removed (cleanup), so the phase can complete. **[VERIFIED]** by *"voting advances when the only non-voter has dropped"* and *"the sweep runs, and runs before the transition"*.

**[VERIFIED] Honest limit:** a player who is *present and connected but simply does not vote* still holds the phase open. That is a human waiting for a human, not a stall, and bounding it is exactly the visible-clock decision PD-2 owns. Recorded in §O.

### E.6 · Disconnect handling

The sweep, ordered before the transition so client and server read the same roster: `moveToRoundResult` requires every **remaining** document to have voted, so sweeping first is what makes the eligible-player predicate and that guard agree.

---

## F · RACE / IDEMPOTENCY SAFETY

The brief names four possible triggers. Each is accounted for, and **no new locking mechanism was invented** — the existing ones were reused.

| Trigger | Guard | Layer |
|---|---|---|
| **A** last eligible answer/vote arrives | `_isAdvancing` + `_autoAdvanceTimer` + `_advanceRequested` | client |
| **B** timeout | same path — the timeout only changes `shouldAdvance`, not the trigger | client |
| **C** disconnect cleanup | its own transaction; deletes documents, never changes phase | server |
| **D** host lifecycle | a new host re-evaluates the same predicate; the transaction rejects a duplicate | both |

### F.1 · The existing mechanism, reused

**[VERIFIED]** Every phase transition already runs inside `runTransaction` with an explicit phase precondition, throwing `INVALID_PHASE` — the audit: *"a duplicate transition is rejected rather than applied twice."* `finishGame` returns `false` rather than throwing when already in `finalWinner`, so completion counters cannot double-increment. **WP22 adds nothing here and relies on it.**

### F.2 · The one gap found and closed — `_advanceRequested`

**[VERIFIED — this pass]**, and it was found by a test the audit's §9.3 demanded (*"auto-advance fires once, not repeatedly"*) rather than by reading.

`_autoAdvanceTimer` alone did not make the client fire once. The timer nulls itself inside its own callback, and `_moveToVoting`'s `finally` calls `setState`; the rebuild that follows a **successful** advance therefore re-armed the timer and fired a second transition two seconds later. The server rejected it with `INVALID_PHASE`, so the room was never harmed — but the client was asking again for something it had already achieved, and on a slow phase change it would keep asking.

`_advanceRequested` latches the attempt. **Cleared only on failure**, so a genuine transient error can still be retried by the next trigger, while a success stays latched and the screen is replaced by the phase change anyway. Added symmetrically to answering and voting.

### F.3 · Stale timers and delayed callbacks

**[VERIFIED]** `_autoAdvanceTimer` is cancelled in `dispose`. A callback that survives to fire against a changed phase reaches `moveToVoting`/`moveToRoundResult`, whose transactions reject it with `INVALID_PHASE`, which the screen catches. **A stale timer cannot advance a later phase**; it can only produce one rejected call.

### F.4 · Duplicate round advancement

R-13's flag (§C.5) closes the one path that was **not** transaction-guarded — `_advanceRound`'s whole-document `updateRoom`. **[VERIFIED]** by a double tap inside the first request's flight time producing exactly one `updateRoom`.

---

## G · FILES CHANGED

| # | Path | Kind | Reason |
|---|---|---|---|
| 1 | `lib/models/player.dart` | production | The eligible-player predicate R-08 asks for, beside the `isDisconnected` concept it activates; plus `hasAnswered`, which states the server's definition once (G-1J) |
| 2 | `lib/data/repositories/room_repository.dart` | production | The ≥ 2-answer transition guard (G-1G). **This is the "at the transition guard, not in the UI" half of R-09** |
| 3 | `lib/screens/game_screen.dart` | production | Answering completion over eligible players; `shouldAdvance` requires a votable ballot (ends the G-1H spin); the fire-once latch; friendly copy for the new code; status-panel denominator |
| 4 | `lib/screens/voting_screen.dart` | production | Voting completion over eligible players; **the disconnect sweep voting was missing** (R-10); the fire-once latch; status-panel denominator |
| 5 | `lib/screens/round_result_screen.dart` | production | R-13's in-flight guard and a disabled/loading CTA |
| 6 | `test/loop_stall_test.dart` | **test (new)** | 15 regression tests, §H |
| 7 | `test/voting_feedback_adoption_test.dart` | test (extended) | **Not weakened** — §I.2 |

**[VERIFIED] Not changed:** `firestore.rules` · `functions/` · `pubspec.yaml`/`pubspec.lock` · `lib/analytics/**` · `lib/core/**` · `home_screen.dart` · `lobby_screen.dart` · `final_winner_screen.dart` · every model but `player.dart` · every design token · every golden.

---

## H · TESTS ADDED

`test/loop_stall_test.dart` — 15 tests. Each asserts an invariant of the loop, and each fails against the pre-WP22 code.

| Group | Test | Invariant · pre-WP22 behaviour |
|---|---|---|
| G-1F | a stale heartbeat makes a player ineligible | the predicate itself · concept existed, had no call sites |
| G-1F | `hasAnswered` matches the server definition, not `!= null` | G-1J's divergence |
| G-1F | **answering advances when the only non-answerer has dropped** | *burned the full 90 s clock* |
| G-1F | **voting advances when the only non-voter has dropped** | *stalled permanently, no recovery* |
| R-10 | **the sweep runs, and runs before the transition** | *cleanup was never called from voting*. Asserts order, not just presence |
| G-1G | zero answers rejected, room stays in `answering` | preserved: `NO_ANSWERS_SUBMITTED` still the code for 0 |
| G-1G | **ONE answer is rejected — this is the deadlock** | *succeeded, and the room died in voting* |
| G-1G | two answers open the ballot | the fallback remains a fallback |
| G-1G | a whitespace answer does not count toward the ballot | G-1J at the guard |
| G-1H | **the room recovers: a later answer advances it** | *no retry, no reset, no path forward*. End to end through the real repository |
| G-1H | an expired round with **no** answers attempts nothing | *threw and toasted every 2 s, forever* |
| G-1H | an expired round with **one** answer attempts nothing | *opened the deadlocked ballot* |
| G-1H | an expired round with **two** answers still advances | the fallback is not over-tightened |
| idempotency | **the answering auto-advance fires once, not repeatedly** | *fired twice; second rejected by the server* |
| idempotency | **R-13 · a round-result double tap advances one round** | *two question draws, two round writes* |

### Coverage of the brief's scenarios A–K

| | Scenario | Covered by |
|---|---|---|
| A | 3 players, all answer | *fires once, not repeatedly* |
| B | 3 players, one disconnects | *answering advances when the only non-answerer has dropped* |
| C | 3 players, one never answers | *an expired round with two answers still advances* |
| D | 3 players, one answer only | *ONE answer is rejected*; *an expired round with one answer attempts nothing* |
| E | 3 players, zero answers | *zero answers rejected*; *attempts nothing*; *the room recovers* |
| F | voting completes early | *voting advances when the only non-voter has dropped* |
| G | voting reaches timeout | **partial** — the bound is the sweep, not a clock (§E.5). A present-but-silent voter is PD-2's |
| H | player disconnects during voting | *the sweep runs, and runs before the transition* |
| I | host backgrounds during answering | **[INFERRED]** — a backgrounded host stops heart-beating and becomes ineligible; **not directly tested**, because it needs a live lifecycle and a second device (§O) |
| J | host backgrounds during voting | same |
| K | player rejoins / presence changes | **[VERIFIED] not applicable** — `joinRoom` rejects any phase other than `lobby` |

### Test infrastructure added

`_RecordingRepository` (records the call *sequence*, so ordering can be asserted), `_FixedQuestionService` (keeps `_advanceRound` testable without asserting anything about question selection, which is WP23's), and `_roomStream` — which emits twice because `_startTimer` assigns `_remainingSeconds` **outside** `setState` (audit B **G-1I**), so an expired clock only reaches `build` on the next rebuild. In production every Firestore snapshot supplies one. **G-1I was not fixed** — it is LOW severity, outside WP22's four findings, and recorded in §O.

---

## I · TEST VERIFICATION

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found!** |
| `flutter test` | **324 passed**, 0 failed, 0 skipped |
| `git diff --check` | clean |
| Baseline | 309 → **324** (+15) |

### I.1 · No test was weakened, skipped, or suppressed

**[VERIFIED]** No `skip:`, no `try/catch` around an assertion, no loosened matcher anywhere in the diff.

### I.2 · The one existing test touched — and why it is not a weakening

`voting_feedback_adoption_test.dart` failed after the sweep was added: its `_StubRepository` overrode `submitVoteTransaction` and `moveToRoundResult`, but not `cleanupDisconnectedPlayers`. The new call therefore fell through to the **real** Firestore implementation against an empty `FakeFirebaseFirestore`, which threw `ROOM_NOT_FOUND` **before** `moveToRoundResult` was reached — masking the advance failure the test exists to assert.

The fix adds a no-op `cleanupDisconnectedPlayers` override to that stub. **Every assertion in the file is unchanged.** The stub was extended to cover a method the screen now calls — the same shape as its existing overrides, and exactly what `room_exit_feedback_test.dart`'s stub already does for its own path. The test is strictly *more* faithful to the screen's call graph than before.

---

## J · GOLDENS

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

**[VERIFIED] All ten byte-identical.** No golden-regeneration command of any form was run. Gate **A3** holds; stop condition 10 did not trigger. **[INFERRED]** expected — WP22 changes predicates and guards, not rendered primitives.

---

## K · SCOPE AUDIT

| Item | Changed? | Evidence |
|---|---|---|
| Scoring semantics | **NO** | `VOTE_POINTS`, `submitVote.ts` and every `score` write untouched |
| XP semantics | **NO** | `onMatchCompleted.ts` untouched |
| Ranking / tie-break | **NO** | `round_result_screen`'s sort and `finishGame` untouched — R-17/PD-4 |
| Question selection | **NO** | `QuestionService` untouched. The test's fixed corpus is test-local — WP23 |
| Practice Mode | **NO** | not implemented, not referenced |
| Username limit | **NO** | `home_screen.dart` untouched — PD-13 |
| UGC / moderation | **NO** | R-20 untouched |
| **Analytics / WP19** | **NO** | `lib/analytics/**` untouched; no new event name; `analyticsEventMappings`'s 55 outbound names unchanged; gates **A4/T-A** and **S2** unaffected |
| Firebase Rules | **NO** | `firestore.rules` untouched — gate **S4** |
| Cloud Functions | **NO** | `functions/` untouched |
| **Production player minimum (3)** | **NO** | `room_repository.dart:345-352` untouched |
| **Production player maximum (8)** | **NO** | `room_repository.dart:663-666` untouched |
| Self-vote rule | **NO** | `submitVote.ts:49-51` untouched — the guard works *around* it, not against it |
| The 2 s advance beat | **NO** | conflict K-1, BP G16 |
| Round duration (90 s) | **NO** | §D.5 |
| Dependencies | **NO** | `pubspec.yaml`/`pubspec.lock` unchanged — gate **S6** |
| Design tokens / goldens | **NO** | §J |

**[VERIFIED] No stop condition triggered.** In particular: no product rule was undefined at the point of decision (§C.3 shows the zero-answer transition is derivable without inventing one); no minimum/maximum, self-vote, scoring, rules or function change was required; every race was made idempotent with mechanisms the architecture already had.

---

## L · GIT

```
message : fix: eliminate gameplay loop stalls
HEAD^   : 6f00a2449c7f27c1976ad63604f5f9d9fae6f3b8   ← the pre-WP22 HEAD (WP20)
```

**Files in the commit:**

```
bufon_flutter/lib/data/repositories/room_repository.dart
bufon_flutter/lib/models/player.dart
bufon_flutter/lib/screens/game_screen.dart
bufon_flutter/lib/screens/round_result_screen.dart
bufon_flutter/lib/screens/voting_screen.dart
bufon_flutter/test/loop_stall_test.dart
bufon_flutter/test/voting_feedback_adoption_test.dart
docs/design/v1.1/WP22_IMPLEMENTATION_REPORT.md
```

The commit's own SHA is deliberately absent: this report is **inside** that commit, so quoting it would either be fabricated or require an amend. `HEAD^` is the verifiable anchor.

**[VERIFIED]** Exactly one commit. **No amend, no rebase, no squash, no reset, no stash, no clean, no force push.** No history was rewritten; `HEAD^` still resolves to WP20 and `HEAD^^` to WP19.

---

## M · PUSH

> ## **NOT PUSHED.**

**[VERIFIED]** `origin/main` remains `2c8337e7d790c79803b7b93f3b0329318cbc2e93`. Four commits are now local-only: `15824db`, `9f7d98e`, `6f00a24`, and this one.

---

## N · PROTECTED FILES

**[VERIFIED]** Untouched, byte-identical, none staged or committed:

`docs/design/Archive.zip` · `FORENSIC_ANALYSIS_OUTPUT.md` · `GAMEPLAY_AUDIT_OUTPUT.md` · `CRASHLYTICS_TELEMETRY_AUDIT.md` · `MASTER_V1.1_RECONCILIATION.md` · `WP18_CONSOLE_FACT_FINDING.md` · `WP4_RECOVERY_REPORT.md` · `WP5_RECOVERY_REPORT.md` · `BUFON_V1.1_VISUAL_BLUEPRINT.md` · `WP19_IMPLEMENTATION_REPORT.md` · `WP20_IMPLEMENTATION_REPORT.md` · `WP21_CLEAN_STATE_REPRODUCIBILITY_REPORT.md` · `LONG_USERNAME_*` · `PRACTICE_MODE_DECISION_GATE.md`

`Archive.zip` was **not extracted**. The stash (1 entry) is untouched.

---

## O · REMAINING FINDINGS — LATER PACKAGES ONLY

| # | Finding | Owner |
|---|---|---|
| 1 | **Round duration 90 s** — the players asked for 60 s | **PD-1 + WP23.** X-1's ordering constraint (WP22 first) is now satisfied, so PD-1 can be decided |
| 2 | **A present-but-silent voter still holds voting open.** The sweep bounds *disconnection*, not *inaction* | **PD-2** — the visible-clock decision, which needs Blueprint coordination |
| 3 | **G-1I** — the countdown timer is cancelled and recreated on every frame, and `_remainingSeconds` is assigned outside `setState`. Churn, not drift; the test harness had to emit twice because of it | LOW severity, outside WP22's four findings |
| 4 | **G-1E / PD-3** — the round-result stage has no completion logic at all. Deliberate host-paced design; the copy says so | **PD-3**, recommended to keep |
| 5 | **R-45 / audit B X-5** — client-owned match progression is the shared root cause; WP22 fixes the symptoms at the transition guards, as R-09 asked | **R-45**, post-v1.1 |
| 6 | **R-12** — heartbeat pauses on `inactive`; the lobby destroys the room below 2 active players | **R-12 / WP25** |
| 7 | **R-11** — no route out of a failed room stream | **R-11 / WP25** |
| 8 | Host backgrounding mid-phase (scenarios I/J) is **[INFERRED]** safe via the eligibility path but **not directly tested** — it needs a live lifecycle and a second device | **WP21** manual gate **M5** |

**None of these was fixed.** Each is recorded so a later package can decide, and none was allowed to expand this one.

---

## P · NEXT WORK PACKAGE

Per `MASTER_V1.1_RECONCILIATION.md` §9.3 (`:1060-1092`), WP22 gates two packages, and both are now unblocked:

```
WP22 ── Loop stall elimination ──┬──> WP23 ── Question repetition
                                 └──> WP25 ── Exit paths + presence   (D-3, shared eviction machinery)
```

> ### **WP23 — Question repetition.**

**[VERIFIED]** *"Reduce a verified 80.6 %-over-two-games repeat rate, and make the guarantee durable."* Sources **R-14** (corpus is 20 for a 5-round game; the React prototype's **100 questions** exist at `6636976:src/questions.js`) and **R-18** (used-question history is host-local, in-memory, and reset every game). Its ordering constraint — *"**WP22 before WP23**"*, audit B **X-1** — is satisfied by this commit.

**[VERIFIED]** **WP25 — Exit paths + presence** (R-11, R-12) is equally unblocked by **D-3**, the shared eviction machinery this package touched.

**Also actionable now, no code:** decide **PD-1** (round duration — finding 1 above, and the players' 60 s request), **PD-2** (visible voting clock — finding 2), **R-20**'s posture and **PD-13**; and execute **WP18**'s console protocol, which WP21 identified as the harder of its two blockers.

**Not started:** WP23, WP24, WP25, WP26. Practice Mode not implemented. PD-1, PD-2, PD-13 and R-20 not decided.

---

*WP22 COMPLETE — ONE COMMIT — NOT PUSHED*
