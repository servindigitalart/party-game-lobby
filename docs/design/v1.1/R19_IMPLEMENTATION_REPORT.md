# R-19 Implementation Report

**Ceremony `votesReceived` — the night's total, not the last round's.**

---

## 1. Executive summary

The final ceremony congratulated the winner on the wrong number. It counted `votedFor == winner.id` across the room, and `clearRoundData` nulls `votedFor` at the end of every round — so what reached the screen was **the final round's votes**, while `onMatchCompleted` awarded XP on **the night's total**. A player who earned five votes across five rounds was told they earned one.

**The fix is one expression.** `votesReceived` is now `winners.first.score ~/ 100` — the same quantity the server publishes at `onMatchCompleted.ts:168` (`Math.floor(score / 100)`). One concept, one definition, on both sides.

**This also closes the last open clause of WP24's own acceptance gate.** Gate **A7** has three clauses; WP24 satisfied two and left *"displayed `votesReceived == score / 100`"* unasserted, because fixing it would have changed the single-winner display that package was required to hold byte-identical. A dedicated test table now asserts it across four scores.

**The tests were proven to catch the defect, not merely to pass.** With the fix temporarily reverted, **7 of 10 fail**. The 3 that survive are the multi-winner and zero-winner cases, which already used the correct branch — exactly the expected split.

**424 tests pass. All 10 goldens byte-identical. `flutter analyze` clean.** One production file changed; `functions/` and `firestore.rules` untouched.

---

## 2. Exact bug at HEAD before the fix

`lib/screens/round_result_screen.dart`, in the `GamePhase.finalWinner` branch:

```dart
final votesReceived = winners.isEmpty
    ? 0
    : winners.length == 1
        ? room.players
              .where((player) => player.votedFor == winners.first.id)
              .length          // ← the final round only
        : winners.first.score ~/ 100;
```

The multi-winner branch was already correct. **The single-winner branch — the ordinary case — was the defect**, and it is the one almost every real game hits.

Origin: audit B **G-3G**, `[VERIFIED]`. Roadmap: **R-19**, `SEV MEDIUM`, `v1.1 YES`, `BLOCK NO`, `DEPS none (independent of R-17)`.

---

## 3. Why final-round `votedFor` is not the correct source

`votedFor` is **round-local state**, cleared between rounds. `RoomRepository.clearRoundData` nulls it for every player at the end of each round, so at the moment the ceremony renders it describes at most the last round — and after a clear, nothing at all.

Three consequences, all now covered by tests:

1. **It undercounts.** Three votes across the night with one in the final round displayed `1`.
2. **It can read zero.** If `clearRoundData` has run, no player has a `votedFor`, so the winner is congratulated on nothing.
3. **It contradicted the backend.** The server derives the same-named quantity from `score`, so screen and XP disagreed on the same word.

`score` is the durable record. It accumulates across the night, is server-authoritative, and is exactly `100 × votes` — so `score ~/ 100` reconstructs the vote count **without** persisting a field, querying history, or touching the data model.

---

## 4. Exact production change

**One file, one expression** (`bufon_flutter/lib/screens/round_result_screen.dart`, +21/−15, of which the great majority is the explanatory comment):

```dart
final votesReceived =
    winners.isEmpty ? 0 : winners.first.score ~/ 100;
```

Semantics: **no winner → `0`; winner(s) → `score ~/ 100`.** The single-winner special case is gone rather than corrected in place — with both branches computing the same thing, there was no reason for two.

**Not done, deliberately:** no new stored field, no persisted state, no reconstruction from historical round documents, no Firestore query, no `Player` model change.

---

## 5. Scoring untouched

No scoring code was modified. `score` is still incremented atomically in `submitVoteTransaction`, still `100 × votes received`, still server-authoritative. This package **reads** a score that already existed; it does not compute one.

**D-5 is untouched and, if anything, more visible.** `Math.floor(score / 100)` remains the server's contract, and the new comment states outright that this line now shares the divisor with XP, achievements, titles and the leaderboards — so a future `score` change breaks them together rather than silently splitting them.

---

## 6. PD-4 winner semantics untouched

The winner set is computed before this line runs and was not touched:

```dart
final standings = room.players.finalRanking;
final winners = standings.where((s) => s.isWinner).map((s) => s.player).toList();
```

`isWinner` is still `score > 0 && score == max(score)`, still identical to `onMatchCompleted.ts:167`. Final ranking, competition ranking (1/1/1/4), the ranking population and tie semantics are all unchanged. **This package only corrects a number displayed after the winners were already decided.**

Three tests pin it: tied winners still both crowned and sharing the total; a strict winner still the only one crowned; an all-zero room still crowning nobody.

---

## 7. XP, achievements, titles and leaderboards untouched

None were modified. All four are awarded server-side by `onMatchCompleted`, which this package did not touch. **The change moves the *display* into agreement with the awards that were already being made** — it does not alter an award.

---

## 8. Test cases added

New file: `bufon_flutter/test/ceremony_votes_test.dart` — **10 tests**.

Every test renders the production `RoundResultScreen` in `finalWinner` phase, lets it navigate to the production `FinalWinnerScreen`, and reads the ceremony's `Votos` stat through its semantics label. **None asserts the fixed expression against itself:** each fixture supplies a score together with a deliberately *contradictory* set of final-round votes, so only a score-derived value can pass.

| Group | Test | What it proves |
|---|---|---|
| R-19 | single winner credited with the whole night | score 300, **one** final-round vote → displays **3**, and `1 Votos` is asserted absent |
| R-19 | survives `clearRoundData` | every `votedFor` null, score 500 → displays **5**, not 0 |
| R-19 | winner with nothing in the final round | no final-round vote for the winner, score 400 → displays **4** |
| A7 ×4 | scores 100 / 300 / 500 / 800 | displayed == `score ~/ 100` in every case, with final-round votes fixed and wrong throughout |
| PD-4 | tied winners | both crowned, shared total **5** |
| PD-4 | zero winners | no stat rendered; nobody crowned |
| PD-4 | strict winner | **3 Votos** *and* **300 Puntos** — points untouched |

**Nothing existing was weakened, skipped, or edited.**

### The tests were verified to fail without the fix

The production expression was temporarily reverted, the suite re-run, and the file restored from a scratchpad copy:

```
pre-fix:   00:07 +3 -7: Some tests failed.
post-fix:  00:06 +10: All tests passed!
```

**7 of 10 fail against the old code.** The 3 that pass are the multi-winner and zero-winner cases, which never used the defective branch.

---

## 9. Exact test results

```
$ flutter analyze
No issues found! (ran in 5.0s)

$ flutter test test/ceremony_votes_test.dart
00:06 +10: All tests passed!

$ flutter test
00:59 +424: All tests passed!
```

Baseline was **414**; now **424** — +10, none removed.

---

## 10. Golden results

```
$ flutter test test/golden/component_golden_test.dart
00:05 +10: All tests passed!

$ git status --short -- bufon_flutter/test/golden/
(empty)
```

**All 10 byte-identical. `--update-goldens` was never run.** Expected: this package changes a computed integer, not styling or layout, and the golden suite is component-scoped and does not cover the ceremony screen at all.

---

## 11. Manual verification

> **NOT PERFORMED.** No device or booted simulator was available.

The behaviour is nonetheless exercised end-to-end in the widget layer: the production `RoundResultScreen` renders, navigates to the production `FinalWinnerScreen`, and the assertions read the text a player would see. **The value's correctness does not depend on hardware** — it is a pure function of a score already present in the room snapshot.

WP21's device gate remains blocked for its own reasons and is not a prerequisite here.

---

## 12. Scope audit

**Changed:** `round_result_screen.dart` (one expression) and one new test file.

**Not touched:** score calculation · D-5 divisor · XP · `totalWins` · achievements · titles · leaderboards · PD-4 winner set · final ranking · competition ranking · tie semantics · round-level voting (`round_result_screen.dart:322` still uses `voteCounts[winner.id]`, correct for a *round*) · vote submission · vote values · self-vote rules · question selection · round duration · Practice Mode · telemetry · Cloud Functions · `firestore.rules` · Home · WP22 stall guards · WP23 · WP25 exits.

Confirmed by `git status`: `functions/` and `firestore.rules` are empty.

---

## 13. Git status before / after

**Before**
```
HEAD 88277b5 docs: correct Practice Mode report commit hash
 M docs/testing/TESTFLIGHT_CHECKLIST.md     (R-25, unrelated)
?? 16 untracked design documents            (unrelated)
```

**After — added by this package**
```
 M bufon_flutter/lib/screens/round_result_screen.dart
?? bufon_flutter/test/ceremony_votes_test.dart
?? docs/design/v1.1/R19_IMPLEMENTATION_REPORT.md
```

The unrelated modification and all untracked documents were **preserved untouched** — not staged, reverted, stashed or cleaned.

---

## 14. Commit

**`fix: show night-total votes in ceremony`** — three files: one production, one test, one report.

The commit hash cannot be written inside the commit that creates it. It is
`git log -1` at the time of writing, and is reported alongside this document
rather than guessed here — a placeholder written ahead of the commit is how
the Practice Mode report ended up naming a hash that never existed.

---

## 15. Limitations

1. **Manual on-device verification not performed** (§11).
2. **The `100` divisor is a literal in two places** — here and in `PracticeRoomRepository.pointsPerVote`, which mirrors the server's award. Extracting a shared constant would touch the scoring surface D-5 guards and was out of scope; the comment ties both to `onMatchCompleted` instead.
3. **Gate A7 clause 3 is now asserted in the client only.** The client/server agreement is by construction — the same divisor over the same score — not by an integration test against the deployed function, which would need the emulator suite this package does not touch.
4. **The round-level `votesReceived` at `:322` was deliberately left alone.** It reads `voteCounts[winner.id]` for the *round* winner, which is the correct source at that scope. R-19 concerns the ceremony only.

---

*R-19 — CEREMONY NIGHT-TOTAL VOTES — 424 TESTS GREEN — 10/10 GOLDENS BYTE-IDENTICAL — ANALYZE CLEAN*
