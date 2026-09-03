# WP27 — Practice Mode Local Presence Consistency

## 1. Objective

Make Practice Mode's local player presence internally consistent with the
existing `Player.isDisconnected` / `PlayerEligibility` contract, without
changing any shared multiplayer behavior. Practice players must never be
falsely treated as disconnected during a normal Practice session.

## 2. Confirmed Root Cause

Established by a prior read-only forensic investigation and reconfirmed here
before editing:

- `Player.isDisconnected` (`lib/models/player.dart:24-27`) applies a
  hardcoded 20-second staleness threshold to `lastSeen`.
- `PracticeRoomRepository.createRoom` (`practice_room_repository.dart`) set
  every player's `lastSeen` once, at room creation, via `Player`'s
  constructor default (`lastSeen ?? DateTime.now()`) — and no Practice code
  path updated it afterward.
- Real multiplayer never crosses the threshold because
  `ConnectionService.startHeartbeat` (`lib/services/connection_service.dart`)
  rewrites `lastSeen` to Firestore every 10 seconds.
- `voting_screen.dart` derives `eligible` from `PlayerEligibility.eligible`
  (`player.dart:98-102`) and gates both the automatic and the manual
  "Ver Resultados" advance on `allVoted = eligibleCount > 0 && votedCount ==
  eligibleCount`.
- Once every Practice player crossed 20 seconds since room creation,
  `eligibleCount` collapsed to 0 and `allVoted` could never become true
  again — Voting had no timeout fallback to recover.
- Confirmed on a physical device: Voting was entered 18 seconds after room
  creation and never advanced; the app was backgrounded ~2 minutes later
  with no further gameplay transition logged.

## 3. Architectural Decision

**Option A — a local, in-memory presence heartbeat confined entirely to
`PracticeRoomRepository`** — was selected over modifying the shared
eligibility/presence predicate, for one reason established by a dedicated
architectural reconciliation before this work began: `player.dart`,
`voting_screen.dart` and `game_screen.dart` are the shared, mode-agnostic
contract every gameplay screen already trusts. `PRACTICE_MODE_IMPLEMENTATION_
REPORT.md` treats "no gameplay screen knows it is driving a Practice game" as
a load-bearing, test-enforced property of the feature. Narrowing or bypassing
`Player.isDisconnected` in shared code would have introduced a second,
competing presence rule into the exact predicate WP22 hardened for real
multiplayer — reopening a file two prior work packages (WP22, WP25) treat as
a high-stakes, hash-verified surface, for no benefit Practice actually needs.

Practice does not need multiplayer's presence architecture; it needs to
**honor the same presence contract locally**, the same way it already mirrors
every other production guard (the three-player minimum, the ballot-answer
minimum). A local heartbeat does exactly that, with zero coupling to
Firestore, `ConnectionService`, or any shared file.

## 4. Implementation

**File changed:** `bufon_flutter/lib/data/repositories/practice_room_repository.dart`

- `PracticeRoomRepository()` constructor: now calls `_refreshPresence()`
  immediately, then starts `_presenceTimer = Timer.periodic(_presenceRefreshInterval,
  (_) => _refreshPresence())`. This mirrors `ConnectionService.startHeartbeat`'s
  exact pattern (immediate beat, then periodic) verbatim, entirely in memory.
- `_presenceRefreshInterval`: `const Duration(seconds: 10)` — the same
  cadence `ConnectionService` already uses for real multiplayer, not an
  invented value.
- `_presenceTimer`: `Timer?` field holding the periodic timer.
- `_refreshPresence()`: new private method. No-op if `_room == null`
  (before room creation, or after `deleteRoom`). Otherwise republishes the
  current room with every player's `lastSeen` set to `DateTime.now()`, via
  the existing `_publish` method — no new publish/stream mechanism.
- `dispose()`: now also calls `_presenceTimer?.cancel()` before closing the
  room stream.

No other method was touched. `createRoom`, `submitAnswerTransaction`,
`moveToVoting`, `submitVoteTransaction`, `moveToRoundResult`,
`advanceToNextRound`, `cleanupDisconnectedPlayers`, `deleteRoom`, and every
other `RoomRepository` method are byte-for-byte unchanged.

## 5. Lifecycle / Timer Safety

Answered directly, against the actual existing lifecycle rather than a new
one:

- **When does the heartbeat start?** At construction of
  `PracticeRoomRepository`, before any room exists. The first tick is a
  no-op; the constructor's own immediate call is also a no-op until
  `createRoom` runs.
- **Eager or on room creation?** Eager, at construction — the simplest
  option, since the class already has exactly one constructor and Riverpod
  creates exactly one instance per Practice session (`game_providers.dart`'s
  `roomRepositoryProvider` constructs a new `PracticeRoomRepository()` only
  when `practiceModeProvider` transitions to `true`).
- **Entering and exiting Practice?** `roomRepositoryProvider` is a plain
  (non-`autoDispose`) `Provider<RoomRepository>` that `ref.watch`es
  `practiceModeProvider`. Riverpod disposes the previous provider value —
  calling `ref.onDispose(practice.dispose)`, already wired at
  `game_providers.dart:29` — whenever that dependency changes, before
  building the new one. `practiceModeProvider` is flipped back to `false` at
  `room_exit.dart:74` and at three call sites in `home_screen.dart`, so
  leaving Practice reliably disposes the repository and cancels its timer.
- **Room recreated on the same instance?** `createRoom` does not touch or
  restart the timer. The single timer keeps running for the instance's
  lifetime and simply refreshes whatever `_room` currently holds.
- **Can multiple timers exist simultaneously?** No. Exactly one timer is
  created, once, in the constructor. A new `PracticeRoomRepository` instance
  is only ever constructed after the previous one was disposed (Riverpod
  provider re-evaluation semantics), so no two timers from two instances can
  be active at once under normal provider usage.
- **`dispose()` before/after room creation?** Before: `_presenceTimer` is
  always non-null once the constructor has run, so `_presenceTimer?.cancel()`
  is always a real cancel, never a no-op from a null timer. After: the timer
  is already cancelled; further `_refreshPresence` calls cannot fire.
- **Is the timer always cancelled?** Yes, verified by a dedicated test (§6) —
  proven with `fake_async`, not asserted only in prose.

## 6. Regression Test

**File changed:** `bufon_flutter/test/practice_mode_test.dart` (new group,
no existing test modified).

Added group `WP27 — Practice players stay eligible past the real 20s
threshold`, with two tests:

1. **The regression test.** Plays through Practice to a real, genuine vote
   from all three players (human vote → both bufones vote in the same beat,
   exactly as production does), then reproduces the exact pre-WP27 failure
   state on top of those real votes: every player's `lastSeen` is set to
   `DateTime.now().subtract(Duration(seconds: 25))` — a genuinely stale,
   real timestamp, not a virtual one. A sanity assertion confirms this trips
   the real, unmodified `Player.isDisconnected` and empties
   `PlayerEligibility.eligible` — the exact state that froze Voting on the
   physical device, even with valid votes on record. The test then runs
   inside `fakeAsync` and calls `async.elapse(Duration(seconds: 25))`,
   which fires the repository's real `Timer.periodic` (twice, crossing the
   full 20-second threshold) without any real wall-clock wait. It then
   re-checks `isDisconnected` (now false for all three) and recomputes
   `voting_screen.dart`'s exact `allVoted` formula
   (`eligible.isNotEmpty && votedCount == eligible.length`) directly from
   the real, shared `PlayerEligibility.eligible` extension — proving the
   shared completion gate the screen itself evaluates is satisfied.

   **Verified to discriminate pre/post-fix behavior**, not just asserted:
   the constructor's heartbeat code was temporarily disabled and the test
   was re-run — it failed at exactly the two assertions WP27 fixes (`Expected:
   true / Actual: <false>`), then the fix was restored and the test passed
   again. This is not a happy-path test; it specifically exercises the
   original failure mechanism.

2. **A lifecycle test.** Constructs a `PracticeRoomRepository` inside
   `fakeAsync`, asserts `async.pendingTimers.length > 0` (the heartbeat
   started), calls `dispose()`, and asserts `async.pendingTimers.length ==
   0` — proving the timer is cancelled, not merely stopped from firing.
   Also verified to fail without the fix (no timer existed to cancel).

`package:fake_async` was already a resolved transitive dependency in
`pubspec.lock` (pulled in by the existing `flutter_test`/`test` toolchain)
and required no `pubspec.yaml` change and no `pub get` — confirmed present
in `.dart_tool/package_config.json` before writing the test.

Both tests are deterministic and fast (complete in well under a second);
neither relies on a real 20-second sleep.

## 7. Scope Compliance

Confirmed NOT changed by this work package:

- `lib/models/player.dart` — untouched. `Player.isDisconnected` and
  `PlayerEligibility.eligible` are unmodified; the regression test calls
  them directly, unmodified, as production code.
- `lib/screens/voting_screen.dart` — untouched.
- `lib/screens/game_screen.dart` — untouched.
- `lib/services/connection_service.dart` — untouched; not called by the fix.
- `lib/data/repositories/room_repository.dart` — untouched.
- Multiplayer presence behavior — untouched; no multiplayer code path was
  read or written by this change.
- Firebase, Firestore, Cloud Functions, Firestore rules — untouched; the fix
  performs no Firebase operation of any kind (verified: `_refreshPresence`
  and the constructor changes touch only local `Room`/`Player` objects and
  `dart:async`'s `Timer`).
- App Check — untouched; the previously-investigated 403s remain
  independently confirmed unrelated to this defect and were not addressed.
- PD-2 (Voting timeout / visible clock) — untouched, not implemented, not
  designed around. This fix corrects false disconnection of players who did
  vote; it does not add a timeout for a player who is present but genuinely
  does not vote — that remains a separate, deferred product decision.
- `docs/design/v1.1/BUFON_V1.1_VISUAL_BLUEPRINT.md` — untouched.
- `docs/design/v1.1/MASTER_V1.1_RECONCILIATION.md` — not created, not
  modified (confirmed absent from this repository both before and after
  this work).
- No dependency was added or upgraded; `pubspec.yaml`, `pubspec.lock`, and
  `Podfile.lock` were not touched by this work package (the pre-existing
  modifications to `pubspec.lock`, `Podfile.lock`, and `project.pbxproj` from
  the earlier sync work remain, untouched, unstaged, and are not part of
  this commit).

## 8. Verification

Commands run, in order, from `bufon_flutter/`:

```
flutter test test/practice_mode_test.dart
```
Result: **35/35 passed**, including both new WP27 tests.

**Discriminating-power check** (temporary, reverted before commit): the
constructor's heartbeat code was commented out and
`flutter test test/practice_mode_test.dart --plain-name "WP27"` was run
again — both new tests **failed**, exactly at the assertions WP27's fix
addresses:
```
Expected: true
  Actual: <false>
WP27: the local heartbeat must correct staleness before the real threshold
in player.dart trips
```
```
Expected: a value greater than <0>
  Actual: <0>
the periodic presence timer starts at construction
```
The fix was then restored and the same command was re-run, confirming
**2/2 passed** again.

Full suite:
```
flutter test
```
Result: **479 passed, 5 failed.** All 5 failures are in
`test/golden/component_golden_test.dart` (`AnimatedPrimaryButton solid`,
`GameCard selected`, `TimerWidget normal`, `TimerWidget urgent`,
`GameProgressBar mid-game`), each failing with a golden-image pixel diff
(e.g. `Golden "goldens/timer_widget_urgent.png": Pixel test failed, 35.66%,
28524px diff detected`) — a rendering-environment difference (this
machine's Skia/font rasterization vs. whatever produced the checked-in
reference PNGs), not a logic assertion. None of the five failing tests
render, import, or reference `PracticeRoomRepository`, `Player`,
`voting_screen.dart`, or any file this work package touched. These failures
pre-date this change and are unrelated to it; they were not investigated
further or fixed, as doing so is out of WP27's scope (regenerating golden
images is unrelated cleanup this work package explicitly excludes).

## 9. Remaining Known Issues

- **PD-2 remains unresolved by design.** Voting still has no visible clock
  or expiry path for a player who is genuinely present but does not vote.
  WP27 does not touch, imply, or design around this — it is a separate,
  already-tracked, explicitly deferred product decision.
- **The pre-existing golden-image failures (§8)** are unrelated to Practice
  Mode and were not addressed by this work package.

## 10. Git / Commit

Recorded after the commit below.
