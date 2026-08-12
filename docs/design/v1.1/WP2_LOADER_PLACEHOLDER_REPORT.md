# BUFÓN 1.1 — PHASE 2B / WP2
# Loader + Placeholder primitives

**Date:** 2026-08-11
**Base commit:** `cca4518 fix: restore legacy chrome phase scopes`
**State:** implemented, verified, **uncommitted**
**Scope:** WP2 only. No screen was redesigned; no navigation, business logic,
Firestore query, Firebase rule or dependency was touched.

---

## 1. Implementation summary

Two primitives now carry every player-facing loading, empty and error state.

Before WP2 the app expressed those states in three different generic ways: 16
bare `CircularProgressIndicator`s, five hand-rolled icon/title/body columns
(two of which printed the raw exception to the player), and one 64 px Material
icon standing in for an empty state. There was no shared language, so each new
screen invented one again.

The blueprint had already specified both components and both were listed as
**P0 / new** in its component table (line 166-167) — this builds them and, more
importantly, **adopts** them.

### `BufonLoader`

The breathing isotype the blueprint asks for: *"Loading states | Isotype |
Breathing (scale 1.0 ↔ 1.008, 4 s, `easeInOut`)"*. It reuses `BrandMark` rather
than introducing new artwork, and every motion number comes from
`MotionPhysics`/`MotionCurves` — tokens that were written for exactly this
component and had **zero call sites** before now (audit finding SWA-8).

The blueprint rejects both alternatives by name, so neither was considered:
`flutter_spinkit` ("a prettier generic spinner is still generic") and skeleton
shimmer ("a shimmer is a better generic, and generic is the problem"). No
animation package was added; no second motion vocabulary exists.

### `BufonPlaceholder`

One component, three variants — `empty` / `error` / `offline` — exactly as the
blueprint specifies, with brand illustration, voice copy and **at most one
action**. Colours come from the active `BufonPhase` register and the theme's
`ColorScheme`; callers cannot pass a colour at all.

---

## 2. Files changed

### Created (3)

| File | Purpose |
|---|---|
| `lib/presentation/widgets/bufon_loader.dart` | The loading primitive |
| `lib/presentation/widgets/bufon_placeholder.dart` | The empty/error/offline primitive |
| `test/bufon_state_primitives_test.dart` | 10 tests — behaviour + adoption invariants |

### Modified (11)

| File | Change |
|---|---|
| `lib/core/game_copy.dart` | +3 voice strings for the placeholder defaults |
| `lib/screens/game_screen.dart` | 3 loaders, 1 placeholder (error, keeps its "Volver al Inicio" action) |
| `lib/screens/lobby_screen.dart` | 2 loaders, 1 placeholder |
| `lib/screens/voting_screen.dart` | 1 loader, 1 placeholder |
| `lib/screens/round_result_screen.dart` | 1 loader, 3 placeholders (error + two edge states) |
| `lib/screens/final_winner_screen.dart` | 1 error-copy fix |
| `lib/presentation/screens/profile_screen.dart` | 1 loader, 2 placeholders, 1 error-copy fix |
| `lib/presentation/screens/profile_public_screen.dart` | 2 loaders, 1 placeholder (**raw-exception leak removed**), 1 error-copy fix |
| `lib/presentation/screens/leaderboard_screen.dart` | 1 loader, 2 placeholders (error w/ retry + empty) |
| `lib/presentation/screens/season_details_screen.dart` | 1 loader, 2 placeholders |
| `lib/presentation/screens/paywall_screen.dart` | 1 loader (**removes a hardcoded `#E94560` spinner**), 2 error-copy fixes |
| `lib/presentation/dialogs/title_selector_dialog.dart` | 1 loader, 1 placeholder |

No dependency, `pubspec.yaml`, Firebase, navigation or backend change.

---

## 3. API and behaviour

### `BufonLoader`

```dart
const BufonLoader({double size = 48, String? semanticLabel});
const BufonLoader.small({String? semanticLabel});   // size 32
```

Two parameters, deliberately. There is no colour, curve, duration, stroke or
child parameter: a loader that can be customised per call site stops being one
loading language.

**No `phase` parameter.** The task sketched `BufonLoader(size:, phase:)`, but
after WP1 every reachable screen sits inside a `PhaseScope`, so the register is
already available through `context`. An explicit parameter would be a second,
overridable source of truth for something the tree already knows — so the
loader reads `context` and the API stays at two knobs. `BufonPlaceholder`
follows the same rule.

- **Motion:** scale `1.0 → 1.0 + MotionPhysics.breathingAmplitude` over
  `MotionPhysics.breathingPeriod`, `MotionCurves.pulse`, reversing. Nothing is
  hardcoded in the widget.
- **Reduced motion:** returns the static mark and **stops the ticker** — the
  check lives in `didChangeDependencies`, not `build`, so a running ticker is
  not merely ignored while still costing a frame callback every vsync.
- **Semantics:** one static `'Cargando'` label, `excludeSemantics: true`. Not a
  live region — a wait is announced once on focus, never re-announced per
  frame. The exclusion also swallows `BrandMark`'s own `'Bufón'` label, which
  would otherwise double-announce.

### `BufonPlaceholder`

```dart
const BufonPlaceholder({
  required String title,
  BufonPlaceholderVariant variant = BufonPlaceholderVariant.empty,
  String? message,
  String? actionLabel,
  VoidCallback? onAction,
});
```

| Variant | Mark | Colour source |
|---|---|---|
| `empty` | `BrandMark` (isotype) | — |
| `error` | `Icons.error_outline` | `colorScheme.error` |
| `offline` | `Icons.cloud_off` | `phase.onSurfaceMuted` |

- `empty` is the variant that carries the brand illustration, per Capítulo 25
  ("brand illustration in empty states") — this is what replaces the 64 px
  `Icons.emoji_events_outlined` the audit flagged. The brand is deliberately
  **not** the face of a failure, so `error`/`offline` use semantic icons, which
  is also what the existing hand-rolled error states already did.
- `title` is required because only the call site knows which noun failed or is
  missing; `message` defaults to the variant's voice copy in `GameCopy`.
- **≤1 action**, and it renders only when *both* `actionLabel` and `onAction`
  are supplied — a label without a callback is a dead button.
- The action uses the existing `AnimatedPrimaryButton` (outline variant), so it
  inherits the app's press physics, haptics and semantics rather than
  re-implementing them.
- **No colour parameter exists.** The same placeholder has to read correctly on
  Paper, on Graphite and on the screens still carrying the legacy palette;
  letting a caller pass a colour is how that guarantee gets broken.

---

## 4. Adoption — before → after

| Metric | Before | After |
|---|---|---|
| `CircularProgressIndicator` (whole `lib/`) | **16** | **2** |
| Player-facing generic loading states | **14** | **0** |
| Player-facing generic empty/error states | **8** | **0** |
| Raw player-facing `$error` / `$e` | **8** | **0** |
| Hardcoded spinner colour (`#E94560`) | 1 | 0 |
| `BufonLoader` call sites | 0 | **14** |
| `BufonPlaceholder` call sites | 0 | **14** |

### Loading migrated (14)

| # | Site | Category |
|---|---|---|
| 1-2 | `game_screen.dart` — room-closed and player-removed pre-navigation holds | LOADING |
| 3 | `game_screen.dart` — stream `loading:` | LOADING |
| 4 | `lobby_screen.dart` — room-deleted hold | LOADING |
| 5 | `lobby_screen.dart` — stream `loading:` | LOADING |
| 6 | `voting_screen.dart` — stream `loading:` | LOADING |
| 7 | `round_result_screen.dart` — stream `loading:` | LOADING |
| 8 | `profile_screen.dart` — profile stream | LOADING |
| 9 | `leaderboard_screen.dart` — top players | LOADING |
| 10 | `profile_public_screen.dart` — profile future | LOADING |
| 11 | `profile_public_screen.dart` — `_buildRankCardLoading` (uses `.small`) | LOADING |
| 12 | `season_details_screen.dart` — leaderboard section | LOADING |
| 13 | `title_selector_dialog.dart` — titles list | LOADING |
| 14 | `paywall_screen.dart` — purchase/ad flow (dropped a hardcoded casino-red spinner) | LOADING |

### Empty / error migrated (14 placeholders)

`game_screen` error (keeps its "Volver al Inicio" action) · `lobby_screen` error ·
`voting_screen` error · `round_result_screen` error + "Sala no encontrada" +
"No hay jugadores en la sala" · `profile_screen` null-profile + stream error ·
`profile_public_screen` error · `leaderboard_screen` error (keeps "Reintentar")
+ empty · `season_details_screen` error + empty · `title_selector_dialog` error.

---

## 5. Deliberately excluded, with reasons

### Excluded `CircularProgressIndicator` (2 remaining)

| Site | Reason |
|---|---|
| `animated_primary_button.dart:241` | **Part of another component.** A spinner inside a button is the button's own busy state, already sized to the label and already taking the button's resolved foreground (Capítulo 24). Replacing it with a brand mark would put a second logo inside every loading button. |
| `profile_public_screen.dart:681` | **Inside a `SnackBar`** ("Generando imagen…"). A Material control that already communicates the state through its own copy and surface. |

### Excluded `LinearProgressIndicator` (4, all of them)

All four represent **actual progress**, not loading, which the task excludes
explicitly: `game_screen.dart:472` and `voting_screen.dart:382` (round answer /
vote progress), `profile_screen.dart:202` and `profile_public_screen.dart:382`
(XP toward next level).

### Excluded error strings (2)

`share_profile_card.dart:226` and `share_victory_card.dart:41` —
`throw Exception('...: $e')`. Non-player-facing: these are internal rethrows
consumed by a `catch` that logs and shows friendly copy. Changing them would be
a backend/error-handling change, which is out of scope.

### `error: (_, __) => const SizedBox.shrink()` (5 sites)

Left as-is: `season_badges_section`, `season_countdown_banner`,
`leaderboard_screen:347`, `profile_public_screen:524/535`. These are
**optional decorations** that intentionally vanish on failure rather than
occupying the screen with an error. Converting them to placeholders would put
an error card where a badge strip used to be — a UX regression, not an
improvement.

---

## 6. Accessibility

Not a regression, and a small net improvement. Full accessibility work remains
WP4 and was **not** attempted.

- **Loader:** one static `'Cargando'` label; not a live region, so a screen
  reader announces the wait once instead of on every breath. `BrandMark`'s
  decorative `'Bufón'` label is excluded, removing a double announcement that
  would have appeared if the mark had simply been dropped in.
- **Placeholder:** the title is marked `Semantics(header: true)`, so a screen
  reader can jump to it as a landmark — the hand-rolled versions it replaces
  had no header semantics at all. Title and body remain ordinary `Text`, so
  they are read normally. The action is `AnimatedPrimaryButton`, which already
  carries `Semantics(button: true)` plus its label.
- **Not colour alone:** each variant differs by icon *and* copy, not just
  tint — the `error` icon is `Icons.error_outline` and the `offline` icon is
  `Icons.cloud_off`, both distinguishable without perceiving colour.

---

## 7. Reduced motion

Verified by test and by render.

`BufonLoader` reads `context.reduceMotion` — the existing helper, which checks
both `disableAnimations` and `accessibleNavigation`. No second mechanism was
introduced. When reduced motion is on:

- the breathing `ScaleTransition` is not built at all;
- the `AnimationController` is **stopped**, so `transientCallbackCount` is 0
  (asserted in the test) — the loader costs no frame callbacks;
- the static isotype still renders, so the wait is still communicated.

The reduced-motion render (`loading_legacy_reduced`) is visually identical to
the animated one at rest, which is the intended outcome: nothing is lost except
the motion.

---

## 8. Verification

```
flutter analyze  → No issues found! (7.4s)
flutter test     → +161: All tests passed!    (151 pre-existing + 10 new)
```

No existing test was removed, weakened or modified.

### New tests (10)

**`BufonLoader`** — renders with its default configuration · breathes by
default (scoped to the loader's own subtree) · respects reduced motion (static
mark, `transientCallbackCount == 0`, and `pumpAndSettle` returning at all is
part of the assertion since a breathing loader never settles) · announces a
single static label and not `BrandMark`'s.

**`BufonPlaceholder`** — empty state renders the brand mark and default copy ·
error state renders a semantic icon and *not* the mark · the optional action is
exposed and invoked · a half-supplied action renders nothing.

**Adoption (2 source-level invariants)** — no player-facing screen uses a bare
`CircularProgressIndicator` (with the SnackBar exception named explicitly), and
no screen renders a raw exception to a player. These are source checks on
purpose: the failure they guard against is *a new screen reintroducing the
generic pattern*, which no behavioural test of today's screens can catch.

---

## 9. Visual verification

Six states were rendered to PNG through a temporary harness (with the bundled
Plus Jakarta Sans faces loaded) and inspected directly. **The harness and its
output were deleted afterwards** — no golden files were added to the suite.

| Render | Result |
|---|---|
| Loading, Graphite register | Butter isotype centred on Graphite. Unmistakably Bufón, no spinner, no casino palette. |
| Loading, Paper register | Same mark on Paper — the loader is register-agnostic by construction. |
| Loading, legacy register, reduced motion | Static mark, correct on the legacy dark surface. |
| Empty, Paper register | Isotype + "¡Sé el primero!" in Ink + supporting line in `inkMuted`. Correct hierarchy and spacing. |
| Error + retry, legacy register | White title (WP1 chrome holding), muted body, error-tinted icon, "Reintentar" pill in the register's accent. |
| Offline, Graphite register | Muted icon, Paper title, muted body. |

Confirmed across all six: brand identity visible, animation restrained,
typography correct (bundled face, `h3` title / `body1` message), spacing
coherent (`AppSpacing.xl` padding, `md`/`sm`/`lg` gaps), **no generic Material
spinner in any migrated state**, no layout overflow at 400×900.

On legacy-register screens the placeholder's accent is the legacy casino red.
That is correct and intended: WP1 established that those screens keep their
authored palette until they migrate, and a primitive that adapts to its
register is exactly the behaviour being verified.

---

## 10. Known limitations

1. **The breath is very subtle.** 0.8 % scale over 4 s is close to
   imperceptible — this is the blueprint's own specification, implemented
   faithfully rather than reinterpreted. If a playtest shows it does not read as
   "working", the lever is `MotionPhysics.breathingAmplitude` /
   `breathingPeriod`, a **token** change that needs no edit to the component or
   to any of its 14 call sites. Flagging, not pre-emptively overriding a
   documented design decision.
2. **`Image.asset` decodes asynchronously,** so the loader's very first paint on
   a cold `ImageCache` is blank for a frame. This surfaced during visual
   verification (the first golden rendered empty; later ones hit a warm cache).
   Brief and invisible in practice on a real device, but it is a real property
   of an image-based loader that a vector or `CustomPainter` mark would not
   have. Worth a `precacheImage` at app start if it is ever observed.
3. **`BufonPlaceholder` has no `retryOnly`/compact form.** Every current call
   site is a full-region state, so no compact variant was built. YAGNI until a
   call site needs it.
4. **Snackbar/toast feedback is untouched.** The blueprint's `BufonFeedback`
   primitive (12 snackbar call sites, 5 colour sources) is a separate item and
   was not attempted; only the five raw-exception *strings* inside existing
   snackbars were cleaned, since the task's ERROR COPY rule is explicit.
5. **The `SizedBox.shrink()` failure mode is now inconsistent** with the rest of
   the app — five optional sections silently vanish on error while everything
   else shows a placeholder. Deliberate (see §5), but it is a product decision
   worth revisiting, not an oversight.

---

## 11. Discovered, not fixed (belongs to other work packages)

- **`profile_screen.dart:202` and `profile_public_screen.dart:382`** use
  `AppColors.accent` (legacy cyan `#00D9FF`) for the XP bar — a retired colour.
  Belongs to the Profile migration (audit opportunity #5).
- **`leaderboard_screen.dart:196-200`** uses `Colors.grey` / `Colors.amber` /
  `Colors.brown` for the podium — raw Material colours, not brand tokens. Same
  work package.
- **`final_winner_screen.dart`** remains fully legacy (hardcoded `#111111`,
  red/gold gradient, round-tier confetti, no arrival haptic). WP3.
- **`title_selector_dialog.dart`** now shows brand loading/error states but the
  rest of the dialog is still legacy-palette. Not a screen, so it fell outside
  WP1's register invariant; worth folding into the Profile migration.

---

*No commit, no push, nothing staged.*
