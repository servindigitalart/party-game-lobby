# R-20 Package 1 Implementation Report

**Narrow objectionable-content filter.**

---

## 1. Scope

Implemented: the filtering half of R-20/R-23 Package 1 — a policy surface, a deterministic matcher, integration at both persistence boundaries, user-facing copy, and tests.

**Not implemented, and not claimed:** reporting · report persistence · host removal (shipped separately in `ea9eb2e`) · legal/contact/community-standards screens · account identity · PD-13 · profanity sanitisation.

---

## 2. Policy Implemented

Exactly `R20_CONTENT_POLICY_DECISION.md` §17 — no more, no less.

## 3. Ordinary profanity is allowed. Deliberately.

**Bufón is a comedy game for adults among friends, and this package does not make it family-friendly.** Ordinary Spanish and English profanity, vulgar jokes, sexual jokes, crude humour, slang, anatomical terminology, mild sexual references, irreverence and playful or non-targeted insults are **allowed by design and must stay allowed**.

**No word is blocked for being vulgar.** Sixteen tests assert this against a *populated* policy, so passing proves the filter has no hidden profanity list — not merely that the shipped list happens to be empty.

## 4. Automatic-Block Categories

Three, and the code names them as an enum so widening the policy requires an explicit edit:

| Category | Apple basis |
|---|---|
| `protectedClassSlur` | 1.1.1 — race, ethnicity, religion, sexual orientation, gender identity, disability |
| `childExploitation` | 1.1.4 |
| `exploitationSolicitation` | 1.1.4 — **phrases only** |

**Explicitly not auto-blocked:** generic or severe insults · profanity · vulgarity · sexual jokes or references · anatomical words · edgy humour · threats · harassment · self-harm · ambiguous sexual content. These need a target, an intent or a pattern no word list can see, and they belong to reporting and host removal. A test asserts three of them stay allowed, so a future widening fails in CI.

---

## 5. Exact Normalization Algorithm

`ContentFilter._normalize`, applied identically to input and to policy terms:

1. **Lowercase.**
2. **Fold accents** — `á é í ó ú ü â ã ç …` to bare letters. **`ñ` is preserved**: it is a distinct letter in Spanish, and folding it to `n` would both mangle words and invent matches.
3. **Five approved substitutions, and only five** — `4→a`, `1→i`, `0→o`, `3→e`, `$→s`. No open-ended leet table.
4. **Collapse runs of three or more** identical characters to one. **Three, not two** — Spanish legitimately doubles `ll`, `rr`, `cc` (`llave`, `carro`, `acción`), and collapsing at two would manufacture false positives.
5. **Split on non-letters, rejoin with single spaces, pad with spaces.** This is what makes matching boundary-aware and lets multi-word phrases match through the same code path.

**Deliberately absent:** intra-token punctuation stripping (the highest false-positive mechanism available — `p-e-n-d-e-j-o` is accepted evasion, covered by reporting and removal, not by widening this) · fuzzy matching · phonetic matching · edit distance · Unicode confusable mapping.

Pure, offline, no clock, no randomness. A determinism test runs each input six times.

---

## 6. Where Names Are Filtered

`RoomRepository.createRoom` (host name) and `RoomRepository.joinRoom` (`player.name`) — the two points where a name crosses into Firestore.

**Names get the same policy as answers, and the reason is exposure, not tone. [VERIFIED]** A name does not stay in the room: `onMatchCompleted.ts:153` copies it to `nickname` and `services.ts:295` writes it into the leaderboard `identity` document, which `firestore.rules:242,246` make readable by **every authenticated user**. An answer is a joke in a living room; a name is a broadcast.

**PD-13 untouched:** no maximum length, no minimum, no character-count rule, no general sanitisation. **Content only, never length.**

## 7. Where Answers Are Filtered

`RoomRepository.submitAnswerTransaction`, before the transaction opens — a refused answer never reaches Firestore and is never seen by another player. Answers remain room-scoped and ephemeral (`clearRoundData` nulls them each round); the filter runs before persistence regardless.

## 8. Practice Mode

**Same policy, same filter, no exemption.** `PracticeRoomRepository.createRoom` and `.submitAnswerTransaction` call the same `enforce`.

Filtering is a property of the **input contract**, not of the mode. A Practice-only exemption would be precisely the conditional behaviour R-21's non-goals forbid. Bot strings are first-party constants and are not filtered — nothing is gained by checking a constant we wrote. **No reporting or removal mechanics were added to Practice by this package.**

## 9. Persistence / Transmission Boundaries

**Integration is at the repository layer, not in widgets.** Five call sites, one line each, with all logic in `ContentFilter`:

| Path | Call site |
|---|---|
| Host name | `RoomRepository.createRoom` |
| Joining name | `RoomRepository.joinRoom` |
| Answer | `RoomRepository.submitAnswerTransaction` |
| Practice name | `PracticeRoomRepository.createRoom` |
| Practice answer | `PracticeRoomRepository.submitAnswerTransaction` |

Chosen because it is the narrowest boundary that (a) no ordinary caller can bypass, (b) gives Practice the property for free, and (c) puts zero policy logic in a screen. The UI only maps the resulting error code to copy.

**Rejection, never redaction.** `ContentRejectedException` is thrown; nothing is starred out; no sanitised variant is produced or persisted. A test asserts the input string is unmodified after a rejection.

---

## 10. Files Changed

| File | Change |
|---|---|
| `lib/core/moderation/content_policy.dart` | **new** — owner-owned term lists, three categories |
| `lib/core/moderation/content_filter.dart` | **new** — normalization, matching, `evaluate`/`enforce` |
| `lib/core/exceptions.dart` | `ContentRejectedException` (`CONTENT_NOT_ALLOWED`) |
| `lib/core/game_copy.dart` | `contentNotAllowed` |
| `lib/data/repositories/room_repository.dart` | three `enforce` calls |
| `lib/data/repositories/practice_room_repository.dart` | two `enforce` calls |
| `lib/screens/home_screen.dart` | error-code → copy mapping |
| `lib/screens/game_screen.dart` | error-code → copy mapping |
| `test/content_filter_test.dart` | **new** — 42 tests |
| `docs/design/v1.1/R20_PACKAGE1_IMPLEMENTATION_REPORT.md` | this report |

**No Firestore rules change. No Cloud Function. No dependency added. No UI redesign. No refactor.**

## 11. Tests Added

`test/content_filter_test.dart` — **42 tests**:

* **16** — ordinary comedic language allowed, against a *populated* policy: Spanish and English profanity, crude humour, vulgar and sexual jokes, mild sexual references, anatomical terms, playful and non-targeted insults, irreverence, slang.
* **4** — the three approved categories block, **plus** an assertion that contextual harms (threats, harassment, self-harm) stay allowed.
* **12** — normalization: case, accents, **ñ preserved**, boundary matching, 3+ collapse, **2 not collapsed**, `ll`/`rr`/`cc` intact, digit substitutions, **punctuation not stripped**, empty/ordinary input, determinism.
* **4** — enforcement: allowed passes, blocked throws, the exception leaks no category or term, the input is never mutated.
* **2** — the shipped policy is empty and the filter therefore blocks nothing today.
* **5** — the persistence boundary: blocked host name creates no room · blocked joining name creates no player document · blocked answer never reaches the player document · **an allowed vulgar answer is written unchanged** · **Practice is held to the same policy**.

Mechanism tests use placeholder terms (`zzslur`, `zzchild`, …). The behaviour under test is normalization and matching, which does not care what the words mean — and a test suite should not carry a lexicon of abuse to prove a boundary check works.

---

## 12. Test Commands and Results

```
$ flutter analyze
No issues found! (ran in 9.1s)

$ flutter test test/content_filter_test.dart
00:06 +42: All tests passed!

$ flutter test          (run 1)
02:03 +485 -2: Some tests failed.

$ flutter test test/final_winner_share_feedback_test.dart
00:11 +2: All tests passed!

$ flutter test          (run 2)
       +487: All tests passed

$ flutter test test/golden/component_golden_test.dart
00:07 +10: All tests passed!

$ git status --short -- bufon_flutter/test/golden/
(empty)
```

**The first full run is reported rather than hidden.** Two tests failed: *"a failed share tells the player…"* and *"that failure is presented by the feedback primitive"*, both in `final_winner_share_feedback_test.dart`. They pass **2/2 in isolation** and **the second full run was clean at 487**. That file exercises `ShareVictoryCard` image generation and the `share_plus` platform channel, and this package touches neither — no file in §10 is on that path. **Assessed as load-related flake in a timing-sensitive test, not a regression.** No test was modified to make anything pass.

**Baseline was 445; now 487** — +42, none removed, none weakened.

**Goldens: 10/10, byte-identical.** `--update-goldens` was never run. No UI element was added by this package, so no golden surface changed.

**Firestore rules tests were not re-run:** this package changes no rule. `git status -- firestore.rules functions/` is empty.

---

## 13. Limitations

1. **The filter blocks nothing today.** The shipped policy is empty (§14). The mechanism is present and tested; **Apple 1.2's filtering precaution is not yet effective in production.** A test asserts this state so it cannot be overlooked.
2. **Client-side only, and not a security boundary.** A modified client can bypass it. This is product behaviour and Apple 1.2 compliance evidence, not adversarial enforcement — as the brief directs.
3. **Coverage is Spanish-first plus high-severity English.** All other languages are out of scope, and the review notes must say so rather than imply coverage.
4. **Determined evasion succeeds.** `p-e-n-d-e-j-o` passes, by choice. Reporting and host removal cover what the word list will not.

## 14. Owner Decisions Still Outstanding

| # | Decision | Status |
|---|---|---|
| **1** | **The denylist contents** | **OUTSTANDING — the blocker.** `content_policy.dart` ships empty with the structure in place, so populating it is a policy act with no code change and a reviewable diff |
| 2 | Whether severe non-targeted insults are blocked | Policy says **no**; unchanged here |
| 3 | Borderline sexual content: filter or report | Policy says **report**; unchanged here |
| 4 | Community Standards wording | Package 3 |
| 5 | Contact destination and response commitment | Blocks reporting and R-23, not this package |

**I did not invent terms.** Choosing what Bufón censors is a product judgement, and inventing a list would have substituted my moderation policy for the owner's — which the brief and the policy decision both forbid.

## 15. Deviations

**One, and it is the shape of the deliverable rather than its content.** `R20_CONTENT_POLICY_DECISION.md` ends **BLOCKED — OWNER DECISION REQUIRED** on the denylist. Rather than deliver nothing, this package implements everything the policy *does* specify — normalization, matching, integration, copy, tests — and ships the term list **empty and owner-owned**.

That is not a speculative policy decision: no term was invented, no category was added, and the empty state is asserted by a test and stated in §13. **What it is not is a working filter yet.**

No other deviation. Normalization matches `R20_R23_IMPLEMENTATION_SPEC.md` §2.1 as amended by the policy decision §8 (3+ collapse, five substitutions, no punctuation stripping).

## 16. Apple Guideline 1.2 Compliance Mapping

**Package 1 does not complete Guideline 1.2, and nothing here should be read as claiming it does.**

| Precaution | Status |
|---|---|
| *"A method for filtering objectionable material"* | ⚠️ **Mechanism implemented; not effective until the denylist is populated** (§13.1, §14.1) |
| *"A mechanism to report offensive content and timely responses"* | ❌ **NOT implemented in this package** — Package 3 |
| *"The ability to block abusive users from the service"* | ✅ Implemented separately in **`ea9eb2e`** (R-20 Package 2), room-scoped, with its own stated limits |
| *"Published contact information"* | ❌ **NOT implemented in this package** — R-23, and blocked on owner input |

---

*R-20 PACKAGE 1 — NARROW OBJECTIONABLE-CONTENT FILTER — 487 TESTS · 10/10 GOLDENS · ANALYZE CLEAN · DENYLIST AWAITING OWNER*
