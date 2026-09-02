# WP24 Implementation Report

**PD-4(a) — client/server winner-set reconciliation and the multi-winner ceremony.**

---

## 1. Scope

Implement **PD-4(a)** exactly: the client ceremony adopts the server's existing *"everyone tied wins"* policy, so the winner set the room sees is the winner set the backend already credits. Produce the night's final ranking **once**, from one comparator (R-17), and display competition ranking.

**Not in scope, and not touched:** PD-5, PD-6, time-based scoring, any scoring formula, any new tie-break dimension, XP, Cloud Functions, Firestore rules, the round-result path's own ranking, and R-19.

---

## 2. PD-4 Decision Implemented

From `PD4_DECISION_RECORD.md` §7:

> **PD-4 → Option (a).** The ceremony adopts the server's *"everyone tied wins"* policy. The client's winner set becomes identical to the server's `isWinner` set. No tie-breaker is introduced, and `score` is not touched.

Implemented literally. The client's rule is now the server's rule, transcribed:

```
isWinner  ⇔  score > 0  AND  score == max(score over all players)
```

**No tie-breaker was added.** PD-4 established there is nothing to break a tie *with*: no `answeredAt`, no `votedAt`, no `serverTimestamp` in the round-timing path, and `score` *is* `100 × votes`, so votes are not an independent axis. A tie is reported, never resolved.

---

## 3. Current Bug

**Verified at HEAD before any edit.**

| Layer | Behaviour |
|---|---|
| **Server** — `functions/src/progression/onMatchCompleted.ts:160-167` | `topScore = Math.max(...)`; `isWinner: p.score > 0 && p.score === topScore`. Comment: *"Ties award the win to everyone tied, rather than to whichever document Firestore happened to return first."* **Crowns all tied players.** |
| **Client** — `round_result_screen.dart:223-225` | `[...room.players]..sort((a, b) => b.score.compareTo(a.score))` then `.first`. **No tie-break.** |

Dart's `List.sort` is documented as **not guaranteed stable**; at ≤ 32 elements the SDK uses insertion sort, so the order was the input order — which is `playersSnapshot.docs`, an unordered Firestore query returning **document-ID lexicographic order**, and document IDs are anonymous Firebase UIDs.

**Net: the crowned player was whichever tied player's anonymous UID sorted first.** In the historical three-way tie the room saw one name while the backend credited three players with `+25` win XP and `+1 totalWins` each.

A second, smaller defect: `_FinalStandings` rendered `i + 1` (ordinal ranking) and tinted `i == 0`, so three tied players printed as 1 / 2 / 3 with one row highlighted.

---

## 4. Implementation Changes

Four production files. **No server file, no rule, no configuration.**

### `lib/models/player.dart` — the single ranking (+92 lines)

New `FinalStanding` value type (`player`, `rank`, `isWinner`) and `extension FinalRanking on Iterable<Player>` exposing `finalRanking`. This follows the file's established idiom — WP22 put `PlayerEligibility` here for the same reason — so no new file was created.

`finalRanking` orders by score descending, assigns competition rank, and computes `isWinner` from score alone. **`isWinner` never reads position**, which is what makes the ordering guarantee structural rather than incidental.

### `lib/screens/round_result_screen.dart` — the ceremony call site (+49/−13)

The bare sort and `.first` are gone. The ranking is produced **once** and both the winner set and the standings read from it:

```dart
final standings = room.players.finalRanking;
final winners = standings
    .where((standing) => standing.isWinner)
    .map((standing) => standing.player)
    .toList();
```

`isCurrentUserWinner` became set membership (`winners.any(...)`) rather than identity with one chosen player.

### `lib/screens/final_winner_screen.dart` — the ceremony (+158/−~40)

* `final String winnerName` → **`final List<String> winnerNames`**. This was the API that *forced* the caller to pick one player out of a tied set.
* `final List<Player> standings` → **`final List<FinalStanding> standings`**, so rows carry their own rank and winner flag.
* `_WinnerReveal` gained `_revealed(context)` with three branches: **one name** (byte-identical to before), **several names at equal prominence** plus the tie line, and **no name** with an honest line.
* `_FinalStandings` reads `standing.rank` and `standing.isWinner` instead of `i + 1` and `i == 0`.
* With an empty winner set the stats block, the share action and the off-screen share card are withheld — there is no winner for them to describe.

### `lib/core/game_copy.dart` — copy (+33/−6)

`nightWinnersTied`, `nightNoWinner`, `winnerNames(...)` joiner, and `shareVictory` gained an optional `winnerCount` (default `1`). **The single-winner strings are unchanged, character for character.**

---

## 5. Winner-Set Semantics

Implemented exactly as specified:

| Scores | Winner set |
|---|---|
| 500 / 400 / 300 | **{A}** |
| 500 / 500 / 400 | **{A, B}** |
| 500 / 500 / 500 | **{A, B, C}** |
| 0 / 0 / 0 | **empty** — no zero-score player is crowned |
| *(empty room)* | **empty** |

**Population.** Every player, with **no** eligibility filter. This is the trap the brief flagged, and it is guarded by a test: the server ranks every document in `rooms/{code}/players` and applies no disconnection filter, so filtering here with `PlayerEligibility.eligible` would drop a player the backend still credits — precisely when a tied player's heartbeat lapses at the end of the night. The code comment states this so it is not "tidied" later.

**No new persisted field.** The winner set is derived from scores that already exist. Nothing was added to Firestore, and no authoritative server state is duplicated.

---

## 6. Competition Ranking

Rank is assigned from score alone: equal scores share a rank, and the next rank skips accordingly.

| Scores | Ranks |
|---|---|
| 500 / 500 / 500 / 400 | **1 / 1 / 1 / 4** |
| 500 / 500 / 400 / 300 | **1 / 1 / 3 / 4** |
| 500 / 400 / 300 | **1 / 2 / 3** |

Explicitly **not** dense (1/1/1/2) and **not** ordinal (1/2/3/4) — both are asserted against by name in the tests.

**Display order within an equal-score group** is by name, ascending. It is presentation only, cannot affect `isWinner`, and is documented as carrying no rank. Two players sharing a score *and* a name render identically, so the observable output is deterministic even though their relative order is not observable. **No UID, no `lastSeen`, no arrival order, no timestamp is used anywhere.**

---

## 7. Multi-Winner Ceremony

Using the Blueprint's own licence for this screen — *"the one place the ceremonial layer is licensed to break the system's own rules"* — and only for what PD-4(a) requires:

* **`GameCopy.nightWinnersTied`** — *"¡EMPATE! Todos son BUFÓN de la Noche"* — states the outcome before the names, so no reader has to infer it.
* **Every name in the same `AppTypography.displayButter`**, stacked. No name is larger, first-styled, or otherwise marked. A test asserts the three `TextStyle`s are equal, which is the machine-checkable form of *"does not falsely identify one player as sole winner"*.
* **Stats stay singular and correct** — tied winners share a score, so votes and points describe all of them.
* **Share text pluralises** via `winnerCount`.

**Empty winner set:** the reveal states *"Nadie se llevó la corona esta noche"*, the stats block and share action are withheld, and the standings still render. The exit remains, so the screen is never a dead end.

**The ceremony was not otherwise redesigned.** Staging, timers, confetti tier, keyhole transition, crest, gradient and register are untouched.

---

## 8. Single-Winner Regression Preservation

**Structurally identical, not merely visually similar.** With `winnerNames.length == 1`:

* `_revealed` returns the same single `Text(name, style: AppTypography.displayButter, textAlign: TextAlign.center)`, inside the same `Padding` → `KeyholeRevealTransition` → `ClipRRect`.
* Every new conditional (`if (widget.winnerNames.isNotEmpty)`) is **true**, and each wraps the same widgets in the same order — including the `SizedBox` spacers, which were moved inside the guards rather than duplicated.
* Layout, hierarchy, animations, text, timing and asset treatment are unchanged.
* `votesReceived` for a single winner uses **the original expression, unmodified**.

**Evidence:** the three pre-existing ceremony test files (`final_winner_test.dart`, `final_winner_share_feedback_test.dart`, `retreat_transition_test.dart`) exercise the single-winner path and pass unchanged in substance — the only edit was migrating the constructor call. `share_victory_card_test.dart` and `accessibility_test.dart` also pass. **38 tests across those five files, all green.**

---

## 9. XP / Server Behavior

**Both unchanged.**

* **No Cloud Function was modified.** `git status -- functions/ firestore.rules` is empty.
* No scoring code was touched: score calculation, vote weighting, points per vote, accumulation and persistence are all untouched. The client reads scores it already received.
* **XP, `totalWins`, achievements, titles and leaderboards are untouched.** The server already awarded every tied player; WP24 makes the ceremony stop contradicting awards that were already being made.
* **D-5 is untouched** — `Math.floor(score / 100)` is still the server's `votesReceived` contract, and nothing on the client changes what `score` means.

No server/client contradiction was found that required a server change, so no stop-and-escalate was triggered.

---

## 10. Tests

**New:** `bufon_flutter/test/final_ranking_test.dart` — **24 tests**.

The winner-set tests do not compare the implementation with itself. `_serverIsWinner` transcribes `onMatchCompleted.ts:160-167` independently, and the client set is asserted equal to it — including across a table of eleven score shapes.

| Group | Tests | Covers |
|---|---|---|
| winner set — the PD-4(a) invariant | 6 | single, 2-way, 3-way, zero-score, empty room, server-agreement table |
| independent of ordering | 3 | UID ordering, all six document orderings, presentation order carries no rank |
| competition ranking | 5 | 1/1/1/4, 1/1/3/4, not-dense/not-ordinal, strict 1/2/3, rank from score not position |
| ranking population | 2 | late disconnect stays a winner; `finalRanking` does not apply `eligible` |
| ceremony copy | 3 | name joining, single-winner text unchanged, plural tie text |
| ceremony renders the winner set | 5 | all winners named, tie stated + equal styles, ranks on screen, single-winner unchanged, empty set |

**Migrated:** the three existing `FinalWinnerScreen` call sites — `winnerName: 'Sofía'` → `winnerNames: const ['Sofía']`, `standings: standings` → `standings: standings.finalRanking`. Each fixture's sole top scorer is Sofía, so the single-winner path is exercised exactly as before. **No assertion was weakened and no test was skipped.**

**Call-site audit:** `grep -rn "FinalWinnerScreen"` found one production caller and three test callers. All four migrated; no other path exists.

---

## 11. Goldens

**All 10 goldens pass and are byte-identical.** `git status -- bufon_flutter/test/golden/` is empty. `--update-goldens` was never run.

```
flutter test test/golden/component_golden_test.dart  →  +10: All tests passed!
```

**No golden was added, and that is a deliberate call worth stating.** The golden suite is **component-scoped** — buttons, cards, timer, round indicator, progress bar. **No screen-level golden exists anywhere in the project, and `FinalWinnerScreen` has never had one.** Adding the project's first screen golden for a screen carrying confetti, two staged timers, an elastic entrance and a keyhole mask would be fragile and is a testing-convention change rather than PD-4 work. The multi-winner state is covered instead by **five widget tests**, which assert its behaviour more precisely than a bitmap would.

---

## 12. Verification Results

Commands run from `bufon_flutter/`.

```
$ flutter analyze
No issues found! (ran in 4.7s)

$ flutter test test/final_ranking_test.dart
00:06 +24: All tests passed!

$ flutter test test/final_winner_test.dart test/final_winner_share_feedback_test.dart \
             test/retreat_transition_test.dart test/share_victory_card_test.dart \
             test/accessibility_test.dart
00:13 +38: All tests passed!

$ flutter test test/golden/component_golden_test.dart
00:06 +10: All tests passed!

$ flutter test
00:57 +381: All tests passed!
```

**381 tests, zero failures, zero skips.** No pre-existing failures were encountered, so no failure needed to be distinguished from a WP24 regression.

---

## 13. Out-of-Scope Findings

Recorded, **not modified**.

1. **R-19 — `votesReceived` shows the last round, not the night.** `clearRoundData` nulls `votedFor` every round, so the single-winner ceremony displays the final round's votes rather than `score / 100`. **Left in place deliberately:** fixing it would visibly change the single-winner path, which this brief requires to remain unchanged (criteria 4 and 10, and the mandatory *SINGLE-WINNER REGRESSION* section). The tie branch necessarily uses the night total, because the last-round expression has no defined meaning across a set — the code comment records the inconsistency and names R-19 as the item that retires both branches. **R-19 remains open.**

2. **Three sort sites remain in `round_result_screen.dart`.** The **round** path still sorts twice (`:302` scoreboard, `:305` round winner). R-17's *"produce the ranking once"* was applied to the **final** ranking, which is PD-4's subject; the round-level ranking is explicitly out of scope per `PD4_DECISION_RECORD.md` §11 E11.

3. **`GameController.calculateRoundScores` is an empty no-op** (audit B G-3H, `game_controller.dart:165-167`). Dead abstraction. Untouched.

4. **Every winner still shows the `'default'` avatar.** `firestore.rules` restricts `/users/{uid}` reads to the owner, so a non-winner cannot resolve it. Pre-existing, documented at the call site, needs a product decision. Untouched — and it is why one crest still serves a multi-winner ceremony without implying a specific person.

---

## 14. Acceptance Criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | PD-4(a) implemented | **PASS** | §2, §4 |
| 2 | Client winner set == server winner set | **PASS** | `_serverIsWinner` transcribed independently; equality asserted in 5 tests incl. an 11-shape table |
| 3 | Zero-score players not crowned | **PASS** | `score > 0` in the rule; *"zero scores crown nobody"* |
| 4 | One-winner behaviour unchanged | **PASS** | §8; 38 tests across 5 pre-existing files green |
| 5 | Two-way ties produce two winners | **PASS** | *"two-way tie: 500 / 500 / 400 crowns both"* |
| 6 | Three-way ties produce three winners | **PASS** | *"three-way tie: 500 / 500 / 500 crowns all three"* |
| 7 | Competition ranking implemented | **PASS** | §6; 1/1/1/4 and 1/1/3/4 asserted, dense and ordinal asserted against |
| 8 | No arbitrary tie-break introduced | **PASS** | `isWinner` reads score only; no UID/`lastSeen`/timestamp/order anywhere |
| 9 | UID ordering cannot affect winner semantics | **PASS** | *"UID ordering cannot change the winner set"* |
| 10 | Firestore document ordering cannot affect winner semantics | **PASS** | all six permutations asserted |
| 11 | `PlayerEligibility.eligible` does not remove a server winner | **PASS** | two tests, incl. one proving the filter *would* have dropped them |
| 12 | XP behaviour unchanged | **PASS** | §9; no XP code touched |
| 13 | Server scoring behaviour unchanged | **PASS** | §9; no scoring code touched |
| 14 | No Cloud Function changes required | **PASS** | `git status -- functions/` empty |
| 15 | Multi-winner ceremony represents all winners | **PASS** | §7; *"a three-way tie names every winner"* |
| 16 | `FinalWinnerScreen` supports multiple winners | **PASS** | `List<String> winnerNames` |
| 17 | Relevant tests pass | **PASS** | 24 new + 38 regression |
| 18 | Relevant goldens pass | **PASS** | 10/10, byte-identical |
| 19 | Full `flutter test` passes | **PASS** | **381 passed** |
| 20 | `flutter analyze` passes | **PASS** | *No issues found!* — no pre-existing issues to document |
| 21 | No unrelated scope modified | **PASS** | 4 production + 3 test files migrated + 1 test file added; §13 lists findings left alone |

**21 of 21 PASS.**

---

## 15. Final Status

> ## **WP24 — COMPLETE**

PD-4(a) is implemented at the layer PD-4 named. The client no longer invents a single winner: it reports the winner set the server already computed, whether that is nobody, one player, or every player in the room. The historical three-way tie now crowns three players on screen, matching the three the backend has been crediting all along.

**`score` is unchanged. XP is unchanged. No Cloud Function was touched. No tie-breaker was introduced.**

**Ties are not rarer** — that is Cause 2, which PD-4 explicitly left to PD-5 and PD-6, both still open. **R-19 also remains open**, for the reason recorded in §13.

**Not closed by this package:** PD-5, PD-6, R-19, R-43 (still blocked on PD-7/PD-8), WP21, R-23. No roadmap file was edited.

---

*WP24 — PD-4(a) IMPLEMENTATION — 381 TESTS GREEN — 10/10 GOLDENS BYTE-IDENTICAL — ANALYZE CLEAN*
