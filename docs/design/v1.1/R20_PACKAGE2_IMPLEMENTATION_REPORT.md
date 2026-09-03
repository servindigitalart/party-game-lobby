# R-20 Package 2 Implementation Report

**Host player removal and room-scoped rejoin enforcement.**

---

## Executive Verdict

**COMPLETE.** Apple's Guideline 1.2 asks for *"the ability to block abusive users from the service."* Bufón has no service to be blocked from — no accounts, no discovery, no stranger contact — so the honest equivalent is implemented instead: **the host removes someone from the room they are in, and that room refuses them afterwards.**

**The security boundary is real, not client-side.** The verification pass found that `removedPlayerIds` would have been writable by *any* authenticated user, letting the removed player clear their own uid and walk back in. **`firestore.rules` now makes that field host-only and append-only**, and the attack is proven to fail against the live emulator — not asserted in a widget test.

**One conflict was found and reported rather than worked around.** The brief asked for the player-document delete rule to be tightened to host-only. **It cannot be**, and §Security explains why with citations: `cleanupDisconnectedPlayers` deletes *other* players' documents and is called by **every** client from four gameplay screens, not just the host. Tightening the rule would break WP22's disconnect sweep. The rule is left unchanged, the reason is recorded, and the guarantee is stated without it.

**445 Dart tests · 62 Firestore rules tests · 10/10 goldens byte-identical · analyze clean.**

---

## Scope

**Implemented:** `Room.removedPlayerIds` · host-only removal · one atomic transaction · the `joinRoom` rejoin guard · the `removedPlayerIds` security rule · removed-player client state · Spanish copy · tests · this report.

**Not implemented, and untouched:** R-20 filtering · R-20 reporting · R-23 legal surface · App Privacy · App Review Notes · Practice Mode's contract · scoring, XP, ranking, ceremony, voting semantics, question corpus, timers · PD-13.

---

## Implementation Changes

### Room Model

`bufon_flutter/lib/models/room.dart` — one field, following the `usedQuestionIds` precedent exactly: `final List<String> removedPlayerIds`, default `const []`, serialized in `toJson`, `fromJson` falling back to `const []`, and carried through `copyWith`. **No migration.** A room written before the field existed deserializes unchanged — proven by test.

### Host Removal

`RoomRepository.removePlayer({roomCode, hostId, playerId})`. Rejects self-removal up front (`CANNOT_REMOVE_SELF`), then inside the transaction verifies the room exists (`ROOM_NOT_FOUND`), that the caller is the host (`NOT_HOST`), and that the target exists (`PLAYER_NOT_FOUND`).

### Atomic Transaction

One transaction does all of it:

1. read the room · 2. verify host · 3. verify target · 4. **delete the target's player document** · 5. decrement `playerCount` · 6. append the uid to `removedPlayerIds`, de-duplicated.

**Why one transaction, and why the delete is not optional.** `joinRoom` returns early — *outside* its own transaction, at `room_repository.dart:731-738` — whenever the caller already has a player document. Recording the uid without deleting the document would therefore be **inert**: the removed player takes that early return and walks straight back in. Deleting without recording would let them rejoin as a new arrival. **Both halves land together or it is not a removal.** A test pins this coupling explicitly, so a future change that splits the two writes fails in CI rather than in the wild.

The new list is built explicitly rather than with `FieldValue.arrayUnion` — a transform is not a list at rule-evaluation time, and the append-only rule compares the proposed list against the stored one.

### Rejoin Guard

Inside `joinRoom`'s existing transaction, immediately after `Room.fromJson` and **before** the phase check, the capacity check, the player write and the `playerCount` mutation. The room is already deserialized there, so the guard costs **no extra read** and nothing has yet been mutated. Throws `RoomException(code: 'PLAYER_REMOVED')` — the codebase's existing error architecture, no new hierarchy.

The legitimate existing-player reconnect at `:731-738` is preserved untouched.

### Firestore Rules

One clause added to the room `allow update`:

```
&& (!changedKeys().hasAny(['removedPlayerIds']) ||
    (request.auth.uid == resource.data.hostId &&
     request.resource.data.removedPlayerIds
       .hasAll(resource.data.get('removedPlayerIds', []))));
```

`get(..., [])` because rooms created before the field carry no key and a plain read would error rather than evaluate. **No other rule was changed.** No Cloud Function.

### UI

`lobby_screen.dart` — a trailing `IconButton` on each row, shown only when the viewer is the host and the row is not their own. Confirmation dialog reuses the existing `AnimatedPrimaryButton` shape from `RoomExit.confirmAndLeave`. In-flight guard (`_removingPlayerId`) so a double tap cannot start two transactions. Failure reports through `BufonFeedback` and `player_remove_failed` telemetry.

**No moderation screen, no lobby redesign, no new visual system.** The lobby row is a plain `Card`/`ListTile`, not a golden-covered primitive.

### Client State

The removed player's own client leaves the lobby when it sees its uid in `room.removedPlayerIds`, via the existing `_navigateToHomeWithMessage` path.

**Keyed on `removedPlayerIds`, deliberately, not on "am I still in `room.players`".** The looser test would also fire when `cleanupDisconnectedPlayers` evicts someone for a lapsed heartbeat — a different event, with different copy, owned by WP25. This fires only for an actual removal. A rejoin attempt surfaces `PLAYER_REMOVED` through Home's existing `_friendlyRoomError` map.

---

## Security Analysis

**Why `removedPlayerIds` cannot be cleared by the removed player.** The rule requires `request.auth.uid == resource.data.hostId` for *any* change to the field, and requires the proposed list to contain every entry already stored (`hasAll`). A removed player is not the host, so their write is rejected on the first condition; even a host cannot shorten the list, so the guarantee does not depend on the host's judgement. **Proven against the live emulator**, not inferred: `rules.test.mjs` asserts a removed P2 writing `removedPlayerIds: []` fails.

**Why non-host removal is prevented.** Twice. `removePlayer` throws `NOT_HOST` before writing, and the rule rejects the write regardless of client. A modified client cannot record a removal it is not entitled to.

**Why the early-return bypass is closed.** By construction: removal deletes the player document in the same transaction that records the uid, so `joinRoom:731-738` has nothing to return early with. Pinned by two tests.

### What remains outside the guarantee — stated, not hidden

1. **A fresh install evades it.** Identity is anonymous and per-install; someone who reinstalls arrives as a different uid. **This cannot be fixed without an account system, which is a non-goal.** The copy is written for this: *"Te sacaron de esta sala."* claims nothing about the future, and *"No puedes volver a entrar a esta sala."* is scoped to the room, which is exactly what is enforced.

2. **Player-document deletion remains open to any room member — and this is the conflict the brief asked to be reported rather than worked around.**

   `firestore.rules:149` reads `allow delete: if isAuthenticated() && isRoomMember(roomCode)`. Tightening it to host-only **would break disconnect cleanup**: `cleanupDisconnectedPlayers` deletes *other* players' documents at `room_repository.dart:842, 849, 851`, and it is called by **whichever client happens to be on screen** — `lobby_screen.dart:83, 137`, `game_screen.dart:170`, `voting_screen.dart:140`, `round_result_screen.dart:142` — not by the host. WP22's stall fixes depend on that.

   A narrower rule allowing deletion only of *stale* players is **not expressible**: `lastSeen` is stored as an ISO-8601 **string** (`player.dart:36`), so rules cannot compare it against `request.time`.

   **Consequence, stated plainly:** a modified client belonging to any room member could delete another player's document today, exactly as it could before this package. What this package adds is that such a client **cannot make it stick** — only the host can write the rejoin bar. The transient act was already open; the durable one is now closed. **No bypass was invented, and no cleanup path was broken.**

3. **Rooms remain enumerable** by any authenticated user (`firestore.rules:34`) — pre-existing, out of scope.

---

## Tests

```
$ flutter analyze
No issues found! (ran in 6.2s)

$ flutter test test/player_removal_test.dart
00:04 +21: All tests passed!

$ flutter test
01:33 +445: All tests passed!

$ flutter test test/golden/component_golden_test.dart
00:07 +10: All tests passed!

$ cd firestore-tests && firebase emulators:exec --only firestore --project demo-bufon "npm test"
# tests 62
# pass 62
# fail 0
```

**Dart — `test/player_removal_test.dart`, 21 tests.** Model (4): default empty · round-trip · legacy JSON without the field · `copyWith`. Removal (8): host removes · document deleted · count drops once · uid appended exactly once on repeat · host cannot remove self · non-host rejected · unknown target fails safely and records nothing · missing room fails safely. Rejoin (9): removed uid refused · early-return closed · legitimate reconnect still works · unrelated player still joins · `GAME_ALREADY_STARTED` still wins for a newcomer · the bar is checked before the phase guard · `ROOM_FULL` unaffected · **the delete/append coupling is load-bearing** · **the bar is room-scoped, not global**.

**Rules — `firestore-tests/rules.test.mjs`, 9 new (53 → 62).** Host may append · non-host member cannot · outsider cannot · **the removed player cannot clear their own uid** · not even the host may drop an entry · host may append to an existing list · a legacy room with no field accepts a first removal · host may remove and decrement together · a non-host cannot smuggle the field alongside a legitimate one.

**The split is deliberate:** `fake_cloud_firestore` does not evaluate security rules, so the security half is proven where rules actually run. **Not relied on solely in UI tests**, as the brief required.

---

## Goldens

**All 10 byte-identical.** `git status -- bufon_flutter/test/golden/` is empty; `--update-goldens` was never run. The removal affordance sits on the lobby's plain `Card`/`ListTile`, which no golden covers, and `GameCard` was not touched.

---

## Practice Mode

**Contract unchanged.** No `removedPlayerIds`, no removal UI, no Firebase, no network change, no bot-specific removal tests.

One compile-driven compatibility stub was required: `PracticeRoomRepository implements RoomRepository`, so adding `removePlayer` to the interface obliges it to satisfy the signature. It throws `NOT_SUPPORTED` — a Practice room holds one human host who cannot remove themselves and two first-party bot constants who are not people, and removing one would break the three-player minimum Practice exists to satisfy honestly. **This is the smallest possible adjustment and changes no Practice behaviour** — all 33 Practice tests pass unchanged.

---

## Manual Verification

**Manual device verification not performed; no suitable device available.** No screenshots or device evidence are claimed. The contract is verified by 21 behavioural tests and 9 emulator-backed rules tests.

---

## Files Changed

| File | Change |
|---|---|
| `bufon_flutter/lib/models/room.dart` | `removedPlayerIds` field, serialization, `copyWith` |
| `bufon_flutter/lib/data/repositories/room_repository.dart` | `removePlayer`; `joinRoom` guard |
| `bufon_flutter/lib/screens/lobby_screen.dart` | host affordance, confirmation, removed-player exit |
| `bufon_flutter/lib/screens/home_screen.dart` | `PLAYER_REMOVED` → existing error copy map |
| `bufon_flutter/lib/core/game_copy.dart` | eight removal strings |
| `bufon_flutter/lib/data/repositories/practice_room_repository.dart` | interface stub only |
| `firestore.rules` | one clause: `removedPlayerIds` host-only, append-only |
| `firestore-tests/rules.test.mjs` | 9 security tests |
| `bufon_flutter/test/player_removal_test.dart` | new, 21 tests |
| `docs/design/v1.1/R20_PACKAGE2_IMPLEMENTATION_REPORT.md` | this report |

---

## Git

**HEAD before:** `4a8d8f6` — *fix: show night-total votes in ceremony*
**Final HEAD:** see `git log` for the implementation commit.

`docs/testing/TESTFLIGHT_CHECKLIST.md` remains modified and **unstaged**, exactly as it was. All untracked design documents untouched. Blueprint, Master, `Archive.zip`, WP4/WP5 recovery reports and `R20_R23_IMPLEMENTATION_SPEC.md` untouched.

---

*R-20 PACKAGE 2 — HOST REMOVAL + ROOM-SCOPED REJOIN — 445 DART · 62 RULES · 10/10 GOLDENS · ANALYZE CLEAN*
