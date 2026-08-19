# WP4 Accessibility Report

**Date:** 2026-08-13 (implementation) · **closure/cleanup pass** same day
**Baseline commit:** `321d580 feat: elevate final winner ceremony` (= `origin/main`)
**State:** uncommitted, in the working tree. No commit, push, reset, clean or stash was run.
**Verification:** `flutter analyze` → **No issues found**. `flutter test` → **188 passing, 0 failing**
(171 baseline + 17 new). `git diff --check` → clean. Diff is **17 files**, all WP4.

> **WP4 is COMMIT-READY but not complete.** Five of six acceptance criteria are met; **AC2 (text
> scaling) stays PARTIAL** — the mechanism the blueprint specifies is in place, applied globally with
> no bypasses, and verified; but two loop screens still overflow vertically at the top of the band
> and the fix requires layout restructuring that is out of WP4's scope. See §4 and §10.1.
>
> **Superseded 2026-08-13 — WP5 resolved §10.1.** Both overflows are fixed and covered by 29 tests;
> see `WP5_LARGE_TEXT_LAYOUT_REPORT.md`. WP5 also corrected this report's characterisation of the
> defect: Round Result overflowed at **1.0×** with a full room, not only at maximum text scale.
> AC2's class-B gap is closed. The sections below are left as written, marked where superseded.
>
> The manual VoiceOver/TalkBack pass is **NOT TESTED** — no Android or iOS device or emulator was
> available (`flutter devices` reports only macOS desktop and Chrome). It was not simulated. The
> checklist to run it is `WP4_MANUAL_ACCESSIBILITY_CHECKLIST.md`.
>
> Status vocabulary used throughout: **IMPLEMENTED** · **VERIFIED AUTOMATICALLY** ·
> **MANUAL TEST REQUIRED** · **KNOWN LIMITATION** · **DEFERRED TO FUTURE WP**.

---

## 1. Starting Point

Continued from **`WP4_RECOVERY_REPORT.md`** (Option B — partially implemented, ~20-25%, continue,
do not restart). That report's §14 "Exact Recovery Point" was followed verbatim.

Specification used, unchanged from the recovery audit:

- `PHASE_2A_COMPLETION_AUDIT.md` §6 "WP4 — Accessibility floor" (lines 531-552) — objective,
  affected files, improvements, and the four original acceptance criteria.
- `TYPOGRAPHY_AUDIT.md` §7 "Text scaling" (lines 190-216) — **the text-scaling policy was taken
  from here, not invented.** It prescribes: clamp the global scaler in `MaterialApp.builder` to
  `TextScaler.linear(clamp(scale, 1.0, 1.4))`; fix `game_screen.dart` with the
  `SingleChildScrollView` + `ConstrainedBox(minHeight:)` pattern already proven in
  `home_screen.dart`; give `GameCard` `maxLines: 4` + ellipsis.
- `BUFON_V1.1_VISUAL_BLUEPRINT.md` lines 257, 290, 1103 — the same band ("clamp the global scaler
  to ~1.4 so the loop stays playable while still honouring the user's direction of preference"),
  and "every icon-only control gets a `tooltip` or `Semantics(label:)`".

Work preserved from the interrupted session, exactly as the recovery report required: all four
tooltips, both leaderboard composite labels, the five `header: true` wraps, and the room-code
`semanticsLabel`. Nothing was reverted or rewritten.

---

## 2. Recovery Fixes (Gate 0)

Two compile errors blocked the build. Both were the last thing the interrupted session wrote.

| # | Location | Error | Fix |
|---|---|---|---|
| 1 | `lib/screens/lobby_screen.dart:312` | `Duplicated named argument 'tooltip'` | Deleted the **pre-existing** `tooltip: 'Copiar código de sala'`. Kept WP4's state-aware `tooltip: _codeCopied ? 'Código copiado' : 'Copiar código de sala'`, which is what the added comment argues for. Control logic untouched. |
| 2 | `lib/presentation/screens/profile_public_screen.dart:223` | `The getter 'nickname' isn't defined for the class 'UserProfile'` | Label rewritten to `'Avatar: ${avatar.name}'`. `avatar` is already in scope on that line (resolved at `:178` from `profile.selectedAvatar`) and `Avatar.name` is a real field (`lib/models/avatar.dart:67`). **`UserProfile` was not modified** and no nickname was invented — the screen genuinely has no nickname to show. |

**Gate 0 result:** `flutter analyze` clean; `flutter test` **171 passing** — exactly the WP3
baseline, confirming the recovery report's arithmetic (157 passing + 14 blocked = 171) and that
there had been no test-logic regression.

**Gate 1 (format):** `dart format` applied to the four WP4 files that were not format-clean
(`lobby_screen`, `game_screen`, `round_result_screen`, `profile_public_screen`). Analyze, test and
`git diff --check` all still clean afterwards. See §10.4 for a scope error made during this step.

---

## 3. Semantics Floor

### AC1 — every screen now has an explicit accessibility strategy: **11 / 11**

| Screen | Nodes | What was added in this session |
|---|---|---|
| `home_screen.dart` | 1 | `header: true` on the `BUFÓN` headline |
| `profile_screen.dart` | 5 | avatar-name label; XP progress `label`+`value`; merged stat tiles; avatar cards; achievement cards |
| `paywall_screen.dart` | 2 | `header: true` on the title; composite label + action on both option cards |
| `season_details_screen.dart` | 5 | `header: true` ×3 (season name, "Recompensas", "Clasificación Actual"); reward-card labels; leaderboard-row composite labels |
| `game_screen.dart` | 3 | (2 pre-existing headers) + the all-answered live region |
| `voting_screen.dart` | 2 | (1 pre-existing header) + the vote-confirmation live region |
| `round_result_screen.dart` | 2 | (1 pre-existing header) + the winner live region |
| `leaderboard_screen.dart` | 2 | **unchanged** — recovered work, already correct |
| `lobby_screen.dart` | 2 | **unchanged** apart from the Gate 0 tooltip fix |
| `profile_public_screen.dart` | 2 | avatar label repaired; share button labelled |
| `final_winner_screen.dart` | 5 | **untouched** — WP3, complete |

Baseline was 7/11 (6 from the interrupted session + 1 from WP3), with `paywall_screen`,
`profile_screen`, `season_details_screen` and `home_screen` at zero.

### Colour-only state, now also semantic

Every state previously carried only by fill, border, opacity or a glyph:

| State | Was | Now announced as |
|---|---|---|
| Avatar locked / selected (`profile_screen`) | opacity 0.3 + border colour + rarity dot + lock glyph | `'Avatar <name>, <rarity>, bloqueado \| seleccionado'` + `selected:` |
| Achievement locked (`profile_screen`) | opacity + border + lock glyph | `'Logro <name>, bloqueado, …'` |
| Title equipped (`title_selector_dialog`) | border colour + width + "EQUIPADO" badge | `'<name>, <rarity>, equipado'` + `selected:` |
| Paywall plan (`paywall_screen`) | border colour + premium star | `'<title>, <subtitle>'` + `enabled:` |
| Season rank tier (`season_details`) | gold/primary/accent border | rank stated in words, plus `'primer lugar'` |

### Deliberate non-decisions

Not every `Text` was wrapped, per the brief:

- **`AppBar` titles** left alone — Flutter already contributes `namesRoute`/`isHeader`
  (confirmed in a semantics dump: `flags: isHeader, namesRoute, label: "Ronda 1 de 5"`).
- **`Tab`s** left alone — all use `Tab(text:)` and already carry tab semantics; there are no
  icon-only tabs.
- **The WP2/WP3 widget layer** (`timer_widget`, `bufon_loader`, `bufon_placeholder`, `brand_mark`,
  `game_progress_widgets`) not re-labelled, per the spec's "label the final components once, not
  twice". `final_winner_screen` untouched.
- **`GameCard`'s labels verified, not rewritten.** A semantics dump confirmed
  `label: "Graciosa", isButton, isEnabled` and, for the player's own answer,
  `"Tu respuesta: Algo. No puedes votar por ti mismo."` correctly *not* a button. An earlier dump
  appeared to show empty nodes; that was an artifact of dumping at frame 0, when the cards' entrance
  `TweenAnimationBuilder` is still at `Opacity(0)` and is therefore excluded from the tree by design.

---

## 4. Text Scaling

**Status: PARTIAL.** From 0 references to a working, tested band — but not yet safe at the
top of that band on two screens.

### 4.0 Closure-pass audit — infrastructure vs. layout

The closure pass re-examined AC2 specifically to separate the two failure classes the brief asks
about. The answer is unambiguous:

| Question | Finding |
|---|---|
| What does 1.0–1.4 mean per the audit? | `TYPOGRAPHY_AUDIT.md` §7 chose it as an **explicit compromise**, not a target: "an honest compromise that never breaks the loop is better than an aspiration that overflows." Capítulo 28 asks for **150–200%**; the band deliberately delivers 140%. This is a **documented, intentional deviation** from Cap. 28, recorded before WP4 existed — not a shortfall introduced here. |
| Does the blueprint require anything further? | No. Its three text-scaling deliverables are the global clamp, the `game_screen` scroll fix, and `GameCard` multi-line — blueprint lines 257 and 1103, `TYPOGRAPHY_AUDIT` §7 lines 213-216. The latter two were already done before WP4 and were not redone. |
| Is the band applied globally and correctly? | **Yes.** One `MediaQuery.withClampedTextScaling` in `MaterialApp.builder`, above `home:` — every route inherits it. |
| Does anything bypass it? | **No.** `grep -rn 'textScaler:' lib/` → **0** local overrides. No screen or component re-declares a scaler, so there is no way to escape the band. |
| Do fixed sizes make scaling useless? | **No, and this is the key distinction.** Every `TextStyle(fontSize: N)` — including the 80 pt profile emoji, the 84 pt winner emoji and the 24–32 pt leaderboard avatars — **does** scale, because `TextScaler` applies to `Text`. What does *not* scale is the geometry *around* them: the 140 px avatar circle, the 80 px-wide / 100–120 px-tall podium, the 44 px timer arc. Those are **layout** constraints, not scaling infrastructure. |

**Classification, as the brief requests:**

- **A — text-scaling infrastructure problem:** **NONE REMAINING.** The band exists, is global, is
  unbypassed, and is verified by tests asserting the exact clamp value and the non-inflating floor.
- **B — layout-specific problems:** **2 open** (§10.1), plus 3 found and fixed during
  implementation (below). These are compositions that cannot absorb 1.4×; the scaler is doing
  exactly what it is supposed to do and is surfacing them.

AC2 therefore stays **PARTIAL** on the strength of class B alone. It is not marked MET because
"partial" here has a real user consequence — two screens in the core loop can visibly break at the
maximum text size a user can select.

### What was implemented

`lib/main.dart` — the global band, in `MaterialApp.builder`:

```dart
builder: (context, child) => MediaQuery.withClampedTextScaling(
  minScaleFactor: 1.0,
  maxScaleFactor: 1.4,
  child: child!,
),
```

`MediaQuery.withClampedTextScaling` is Flutter's own first-class API (available on this project's
Flutter 3.32.5), so no custom scaling policy was introduced. The band is exactly the one
`TYPOGRAPHY_AUDIT.md` §7 and the blueprint prescribe. The floor is 1.0 because shrinking below the
design scale is not an accessibility win.

### What the blueprint asked for and was **already done** (not redone)

- `game_screen.dart` scroll safety — already `Expanded` → `SingleChildScrollView` → `Column`
  (`:319-321`). This is why it is the one loop screen that passes the max-scale matrix.
- `GameCard` `maxLines: 4` + ellipsis — already present (`game_card.dart:198-199`).

### Overflows found and fixed

Both are horizontal `Row`s with unflexed `Text`, on the most-used screen:

| Location | Symptom | Fix |
|---|---|---|
| `game_progress_widgets.dart:127` | 232 px right overflow on the round/percentage bar | left label `Flexible` + `maxLines: 1` + ellipsis; percentage keeps priority |
| `timer_widget.dart:141` | 17 px right overflow | countdown wrapped in `Flexible`; urgency copy given `maxLines: 2` + ellipsis |
| `voting_screen.dart:375` | right overflow on the un-voted prompt | prompt wrapped in `Flexible` + centred |

The `voting_screen` overflow was **pre-existing** — `Semantics` is a layout-neutral proxy, so
wrapping the Row could not have caused it. It had simply never been rendered by a test at phone
width before.

### What is still not safe — see §10.1

`voting_screen` and `round_result_screen` overflow **vertically** at the top of the band on a short
viewport, because each composes a fixed header block above an `Expanded` region.

---

## 5. Dynamic State / Live Regions

Three added, each bound to a **one-time qualitative** change rather than to a counter or a frame.
The pre-existing `timer_widget` live region set the precedent and was not touched.

| Where | Trigger | Why it does not spam |
|---|---|---|
| `round_result_screen.dart:604` | `liveRegion: true` on the stage-2 winner node | The branch is only built at stage 2 and its label is fixed for the round. The reveal is *in place* — no navigation — so without it a screen reader is never told the reveal finished. |
| `voting_screen.dart:370` | `liveRegion: hasVoted` | Flips once per player per round. The "toca para votar" prompt is deliberately **never** a live region. |
| `game_screen.dart:496` | `liveRegion: allAnswered` | Fires once, when the last answer lands — not once per player (up to 8 a round), and not on the progress bar's every frame. While answers are pending the node stays readable on focus but silent, which also stops `GameCopy.answerWaiting`'s rotating variants from re-announcing the same state. |
| `timer_widget.dart:122` | `liveRegion: _announceAt.contains(...)` — 30/10/5 s only | **PRE-EXISTING (WP2).** Already the correct anti-flood shape; unchanged. |

Both the presence *and the absence* of each live region are asserted by tests (§8).

---

## 6. Tooltips and Icon-only Controls

### AC3 — met, and no duplicates

Every `IconButton` in `lib/` carries exactly one `tooltip` — a 1:1 ratio in all six files that
contain one (`title_selector_dialog`, `leaderboard_screen`, `paywall_screen`, `profile_screen`,
`home_screen` ×2, `lobby_screen`). There are no `FloatingActionButton`s and no icon-only tabs.

### The `InkWell`/`GestureDetector` controls the recovery report flagged

All five, plus one more found by census (`title_selector_dialog`), now describe their **action**:

| Control | Label / hint |
|---|---|
| `profile_screen` avatar tile | `'Avatar <name>, <rarity>, …'` · hint `'Toca para elegir este avatar'` / `'Toca para ver cómo desbloquearlo'` |
| `profile_screen` achievement tile | `'Logro <name>, …'` · `button: !isUnlocked`, because `onTap` does nothing once unlocked |
| `paywall_screen` option card | `'<title>, <subtitle>'` · `enabled: !_isLoading` |
| `profile_public_screen` share | `'Compartir perfil'` |
| `season_countdown_banner` | `'<season>, Termina en N días'` · hint `'Toca para ver los detalles de la temporada'` |
| `title_selector_dialog` option | `'<name>, <rarity>[, equipado]'` · `selected:` |

The banner's label strips the decorative `⏰` from the visible copy so a screen reader does not read
out "alarm clock"; the emoji stays on screen. A test asserts both halves.

### A severe pre-existing defect found and fixed

**Every primary button and every answer card in the app was announced as a button that a screen
reader could focus but never activate.**

`AnimatedPrimaryButton` and `GameCard` both wrap their `GestureDetector` in
`Semantics(..., excludeSemantics: true)`. `excludeSemantics` drops the entire subtree — including
the gesture detector's `SemanticsAction.tap` — while the wrapper declared `button: true` without
re-declaring `onTap`. The resulting node advertised `isButton` and carried **no tap action**.

Confirmed by dump: `flags: [hasSelectedState, isButton, hasEnabledState, isEnabled], label:
"Una respuesta graciosa"` — and no actions. Nothing in the 171-test baseline asserted a tap action,
so it had never been caught.

Practical effect: "Crear Sala", "Unirse a Sala", "Iniciar Votación", every answer in every voting
round — inert to VoiceOver and TalkBack. The core loop was unplayable with assistive technology.

Fixed by re-declaring the action on the node at all **8** sites (`animated_primary_button`,
`game_card`, and the six controls above). Where a callback was an inline closure it was named so the
node and the gesture share one action rather than duplicating it. No visual or logic change.

**Scope note.** `animated_primary_button` and `game_card` are WP2 components. This was judged
*inside* WP4 rather than a drive-by fix: WP4's objective is literally "every screen is navigable by
screen reader", AC1 requires identifiable actions, and AC6 requires that changes not remove existing
actions. An accessibility floor that leaves every button unpressable is not a floor. Two lines per
widget, no behaviour change, and now covered by tests.

---

## 7. Reduced Motion

**AC5 — not broken, and nothing rebuilt.** `lib/core/theme/reduced_motion.dart` and all five call
sites are untouched; it pre-dates WP4 by a day. `context.reduceMotion` still reads both signals
(`media.disableAnimations || media.accessibleNavigation`). One new test renders the voting screen
with `disableAnimations: true` and asserts it still renders its answers without error. The existing
reduced-motion assertions in `bufon_state_primitives_test.dart` still pass.

---

## 8. Tests

`test/accessibility_test.dart` — **new, 17 tests.** Suite total **171 → 188, zero failures.** No
existing test was modified, weakened or deleted (§10.4 confirms the eight touched test files carry
formatter-only diffs).

Every test asserts behaviour through the semantics tree or the render tree. **None** greps a source
file for a string.

| Group | Coverage |
|---|---|
| AC2 — band | 3.0 clamps to exactly 1.4; 1.0 stays 1.0 (the floor must not inflate type); home survives max scale on a small phone with no recorded overflow |
| AC1 — headings | the home headline is a real `isHeader` node |
| AC4 — live regions | winner announced at stage 2 **and absent before it** (a live region there would spoil the reveal); vote confirmation silent while pending, live once cast; answer progress silent while pending, live once complete |
| AC2/AC5 — viewport matrix | answering + voting + reveal at **360×800 and 390×844**, at scale 1.0 and 3.0, asserting no recorded `FlutterError`; plus the loop rendering with animations disabled |
| AC1/AC3/AC6 — actions survive | a primary button exposes `hasTapAction` *and* the callback fires; a **disabled** button advertises no tap action; the season banner keeps `isButton` + `hasTapAction` through `excludeSemantics`; the voting answers remain labelled, enabled, tappable buttons after the status live region was added |

Two tests earned their place by failing first: the tap-action assertions are what exposed §6's
app-wide defect, and the viewport matrix is what exposed §4's three overflows.

Notes recorded in the test file for whoever maintains it: `daysRemaining` is `inDays` and truncates;
the answering screen must be driven as a **non-host** because the host's device schedules the
auto-advance to voting, which reaches Firebase; the reveal's `AnimatedSwitcher` needs an extra pump
because a child at `Opacity(0)` is correctly absent from the semantics tree.

---

## 9. Visual Verification

Done as assertions rather than goldens, per the brief's "no golden-test infrastructure unless
strictly necessary". A `RenderFlex` overflow, a clipped CTA and a broken layout all surface as a
recorded `FlutterError`, so they are directly checkable.

| Check | Result |
|---|---|
| 360×800, scale 1.0 — answering, voting (pending + cast), reveal | **Pass**, no overflow |
| 390×844, scale 1.0 — same four | **Pass**, no overflow |
| 360×800 / 390×844, scale 3.0→1.4 — answering | **Pass** (it already had the scroll pattern) |
| 360×800 / 390×844, scale 3.0→1.4 — voting, reveal | **Fail — vertical overflow.** §10.1 |
| Home, scale 3.0→1.4 on a small phone | **Pass**; "Crear Sala" still present and unclipped |
| Reduced motion — voting | **Pass**; answers render |
| Duplicate labels / double announcements | None. Verified by dumping the semantics trees of the voting and reveal screens: each row, status and heading is a single node |
| Duplicate tooltips | None; 1:1 `IconButton`-to-`tooltip` in all six files |

One caveat stated plainly: `flutter_test` renders with a test font whose every glyph is one em wide,
roughly double a real font's average. Horizontal overflow magnitudes above are therefore
**pessimistic**, and the residual failures in §10.1 are smaller in reality than the numbers suggest.
They were not dismissed on that basis — they are real at 1.4 with real fonts on a short phone — but
the numbers should not be read as literal device measurements.

**Not visually verified:** `profile_screen`, `profile_public_screen`, `paywall_screen`,
`season_details_screen`, `leaderboard_screen`. Their providers reach Firebase in `initState`
(`paywall_screen` constructs a `RoomRepository` directly), so they cannot be pumped without a
provider-override harness that does not exist yet. Their semantics were reasoned from the real widget
trees and verified by `flutter analyze`, but no render-time overflow evidence exists for them. This
is the largest gap in this report's evidence.

---

## 10. Remaining Known Issues

### 10.1 Vertical overflow at maximum text scale on two loop screens — **RESOLVED BY WP5 (2026-08-13)**

> **Resolved.** `WP5_LARGE_TEXT_LAYOUT_REPORT.md` fixed both screens by moving the scroll boundary
> around the content while keeping the status block and CTA pinned outside it. 29 regression tests
> cover {Voting, Round Result} × {360×800, 390×844} × {1.0×, 1.2×, 1.4×}.
>
> Two corrections to the analysis below, both established by measurement rather than reasoning:
> **(a)** Round Result overflowed at **1.0×** with a full eight-player room — an everyday defect,
> not a maximum-scale one; **(b)** the `Flexible(loose)` rejection was right, and WP5 proved it with
> a probe: 150 px of dead space in a 500 px column. The rest of this section stands as the record of
> why the fix took the shape it did.

**Symptom.** At the top of the band (1.4×) on a 360×800 surface, `voting_screen` overflows at the
bottom by ≈2459 px and `round_result_screen` by ≈1346 px.

**Magnitude caveat, stated plainly.** Those figures come from `flutter_test`'s default font, in
which every glyph is one em wide — roughly double a real font's average advance — so headings and
question copy wrap to far more lines than on a device. The true on-device magnitude is **unmeasured**:
an attempt to re-measure with the bundled PlusJakartaSans via `FontLoader` did not complete in this
environment, and no number was invented to replace it. The overflow is real at 1.4× on a short
phone; the printed magnitudes are upper bounds, not device measurements. Rows V10 and R10 of
`WP4_MANUAL_ACCESSIBILITY_CHECKLIST.md` exist to capture the real figure.

**Cause — exact trees, from the closure-pass analysis.**

```
voting_screen.dart:253            round_result_screen.dart:267
Padding                           Padding
└ Column (stretch)                └ Column (stretch)
  ├ GameProgressBar                 ├ TweenAnimationBuilder(_WinnerSpotlight)   ← unbounded, scales
  ├ Semantics(header) Text  ← h2    │
  ├ Container(question)     ← body1 ├ if (stage >= 2): [ Text, Expanded(_NightScoreboard) ]
  ├ [transition banner]             │ else:            Spacer()      ← Expanded, tight
  ├ Expanded(ListView)              ├ SizedBox
  ├ status Container                └ button / status Container
  └ [host button]
```

Both are the same shape: **an unbounded, text-scale-sensitive block sitting in a non-scrolling
`Column` alongside a tight flex child.** As the block grows, `freeSpace` goes negative, the
`Expanded`/`Spacer` is allotted a negative extent, and `RenderFlex` reports the overflow. It is the
identical failure mode `TYPOGRAPHY_AUDIT.md` §7 predicted for `game_screen` — which was already
fixed with `Expanded` → `SingleChildScrollView`, and which is precisely why `game_screen` **passes**
the max-scale matrix while these two do not.

**Why no minimal local fix exists.** Three candidates were analysed against Flutter's flex
algorithm and all were rejected:

1. **Wrap the header block in `Flexible(fit: loose)`.** Flex children share `freeSpace` by flex
   weight. A loose `Flexible(flex: 1)` beside an `Expanded(flex: 1)` is allotted 50% of the free
   space; it takes its intrinsic height, the `Expanded` takes its full 50%, and the difference
   becomes **visible dead space at normal scale**. It changes the layout of a screen that is
   currently correct, to fix one that only breaks at 1.4×.
2. **Apply the `home_screen` pattern** (`LayoutBuilder` + `SingleChildScrollView` +
   `ConstrainedBox(minHeight:)`). It works on `home_screen` precisely *because* that Column has no
   flex children. Here it gives the Column unbounded height, which `Expanded` and `Spacer` cannot
   live under — so it requires deleting the `Spacer`, un-`Expanded`ing the list/scoreboard and
   converting them to `shrinkWrap`. That changes how both screens behave: the answer list and the
   night scoreboard stop scrolling independently and the CTA stops being pinned.
3. **Bound the header with a fraction of `constraints.maxHeight`.** This is the "magic height" the
   brief rules out, and it is viewport-specific by construction.

Every remaining option is on the brief's *not acceptable* list: shrinking type, truncating text,
lowering the global scaler, magic heights, hiding content, or redesigning to fit.

**Decision: NOT IMPLEMENTED.** Per the brief — "Si la solución requiere una reestructuración visual
importante: NO IMPLEMENTES." Both fixes require restructuring the screen's layout contract, not a
local correction.

**Not frozen into tests, either.** The viewport matrix asserts scale 1.0 for these two screens and
max scale for the rest; the exclusion is commented at the call site. No test asserts that the
overflow occurs, because that would lock the bug in as expected behaviour.

**Which WP should resolve it.** A layout work package, not an accessibility one — the natural home
is a **Phase 2B/2C loop-screen layout pass** that owns the `voting` and `reveal` compositions and
can accept the visual consequences of making them scroll. Prerequisites for whoever takes it: the
real on-device magnitude from checklist rows V10/R10, and a decision on whether the answer list and
night scoreboard may become part of a page-level scroll.

### 10.2 `ShareVictoryCard` overflows its declared frame by 470 px

Pre-existing, found by WP3 and recorded in `WP3_FINAL_WINNER_REPORT.md`. Untouched — the share
system was out of scope.

### 10.3 The manual VoiceOver/TalkBack pass — **MANUAL TEST REQUIRED**

Requires a device and cannot be satisfied from code. The original `PHASE_2A_COMPLETION_AUDIT.md`
AC4 ("manual pass with TalkBack/VoiceOver through one full round") remains open and is the only
acceptance criterion in this report that no automated evidence can stand in for. §6's defect is a
good illustration of why: it was invisible to every form of review except an assertion about actions.

**Closure-pass status:** `flutter devices` reports only **macOS (desktop)** and **Chrome (web)**;
`adb` is not installed and no emulator is running. No pass was attempted and **no result was
simulated**. `WP4_MANUAL_ACCESSIBILITY_CHECKLIST.md` now exists with a per-flow matrix across all
12 flows, split Android/TalkBack vs iOS/VoiceOver, every row marked **NOT TESTED**, plus separate
passes for maximum text size and reduced motion.

### 10.4 Scope error: `dart format` reached 19 files outside WP4 — **RESOLVED in the closure pass**

Gate 1 said to format only the WP4 files that needed it; `dart format lib/` and `dart format lib/
test/` were run instead, normalising files WP4 never touched (the repository was not format-clean
at `321d580`).

**Resolved.** Each modified file was re-classified against `HEAD` by normalising away all
whitespace, closer-preceding trailing commas **and line comments**, then comparing. The split was
exact and unambiguous: **19 files formatting-only, 17 files with real WP4 changes**, and the 17
matched the intended WP4 file list precisely. The 19 were restored with
`git checkout -- <paths>` — a targeted restore of files provably containing no WP4 work, which is
the action this pass was asked to take.

Restored: `core/logging/log_level.dart`, `core/theme/app_theme.dart`, `core/theme/bufon_phase.dart`,
`core/theme/motion_tokens.dart`, `data/repositories/leaderboard_repository.dart`,
`data/repositories/room_repository.dart`, `domain/controllers/leaderboard_controller.dart`,
`domain/controllers/progression_controller.dart`, `presentation/widgets/bufon_placeholder.dart`,
`presentation/widgets/confetti_widget.dart`, `screens/final_winner_screen.dart`, and the eight test
files `analytics_destination`, `app_logger`, `crash_reporter`, `error_instrumentation`,
`final_winner`, `gameplay_instrumentation`, `migrated_telemetry`, `reveal`.

**Post-restore verification:** `flutter analyze` clean, `flutter test` **188 passing**,
`git diff --check` clean. The diff is now **17 files, all WP4** (1142 insertions / 849 deletions).
No test file is modified; the only test change in the tree is the new, untracked
`test/accessibility_test.dart`.

### 10.5 Priority 6 — no semantics helper was created, on purpose

The spec says "**possibly** a small `semantics` helper alongside `reduced_motion.dart`", and the
brief says it must solve a real repeated problem and not abstract a single line. Evidence against
building one now:

- `reduced_motion.dart` exists because it encapsulates a *decision* — reading two `MediaQuery`
  signals and selecting between two values. Nothing in the semantics work has an equivalent.
- The most repeated shape is `Semantics(header: true, child: Text(...))`, 13 sites. That is a
  one-line wrapper, and each site passes a different `AppTypography` getter and register colour, so
  a `BufonHeading` would have to re-expose all of it to save one line.
- The composite labels are only 4 sites and differ in arity and conditional fields.

The one genuinely repeated *problem* WP4 found is §6's `excludeSemantics`-drops-the-action trap
(8 sites). A helper enforcing "if you exclude the subtree, re-declare the action" would be
worthwhile — but it is a lint/invariant, and burying it in a wrapper would hide the very thing that
needs to stay visible at each call site. Recorded as a candidate, not built.

---

## 11. Final WP4 Acceptance Matrix

| Criterion | Status | Evidence |
|---|---|---|
| **AC1 — Semantics: every screen has an explicit strategy** (main heading, identifiable actions, identifiable icon-only controls, communicable states, nothing colour-only) | **MET** — implemented + verified automatically | Final census: **11/11** screens carry a `Semantics` strategy, up from 7/11. Headings on 8 screens; composite labels on leaderboard, season, profile, paywall, title dialog; 5 colour-only states now announced (§3). `AppBar`/`Tab` correctly left to Flutter. Verified by semantics dumps and 17 tests. Per-control wording still **MANUAL TEST REQUIRED**. |
| **AC2 — Text scaling: a real strategy, verified with large text** | **PARTIAL** | *Infrastructure (class A): complete.* Global band `MediaQuery.withClampedTextScaling(1.0, 1.4)` in `MaterialApp.builder`, policy taken verbatim from `TYPOGRAPHY_AUDIT.md` §7; census confirms **0 local overrides**, so nothing bypasses it. Clamp value, non-inflating floor and home-at-max-scale all verified by test; 3 horizontal overflows found and fixed. *Layout (class B): closed by WP5.* `voting_screen` and `round_result_screen` overflowed vertically — the reveal already at 1.0× with a full room — and were **RESOLVED** in `WP5_LARGE_TEXT_LAYOUT_REPORT.md` (§4.0, §10.1). **As of WP5 this criterion is MET**; it is left as PARTIAL here to preserve the record of WP4's own scope. |
| **AC3 — Icon-only controls identifiable; no duplicate tooltips** | **MET** — implemented + verified automatically | Final census: **1:1** `IconButton`-to-`tooltip` in all six files, zero duplicates; the duplicate that broke the build is gone (§2). All six `InkWell`/`GestureDetector` action controls describe their action (§6). Announced wording **MANUAL TEST REQUIRED**. |
| **AC4 — Dynamic state communicable without spam** | **MET** — implemented + verified automatically | 3 new live regions + the pre-existing timer's 30/10/5 s pattern, untouched. Tests assert both presence *and* absence — pending prompts, pending answer progress and the pre-stage-2 reveal are all verified silent (§5, §8). Real-world announcement cadence **MANUAL TEST REQUIRED** (checklist A5, A10, V7). |
| **AC5 — Reduced motion not broken** | **MET** — verified automatically | `reduced_motion.dart` untouched (`git diff` on it is empty) and all five call sites intact; new test renders the loop with `disableAnimations: true`; existing reduced-motion tests still pass (§7). |
| **AC6 — New critical behaviour has automated regressions** | **MET** — verified automatically | 17 new behavioural tests, **188/188** passing, no existing test modified or weakened. Includes the guard for §6's app-wide defect — a button must expose a tap action, and a disabled one must not (§8). |
| *(original AC4)* **Manual TalkBack/VoiceOver pass through one full round** | **MANUAL TEST REQUIRED — NOT TESTED** | No Android/iOS device or emulator available; not simulated. Checklist prepared: `WP4_MANUAL_ACCESSIBILITY_CHECKLIST.md`, 12 flows, both platforms, all rows NOT TESTED (§10.3). |

### Verdict

**WP4 is COMMIT-READY. It is not complete.**

The accessibility floor exists: every screen is labelled, every icon-only control is named, dynamic
state is announced without flooding, the text scale is bounded and unbypassable, and — most
consequentially — the app's buttons and answer cards can actually be **activated** by a screen
reader, which was not true at any point before this work.

What remains, in priority order:

1. ~~**KNOWN LIMITATION / DEFERRED**~~ — **RESOLVED BY WP5.** Max-scale vertical overflow on `voting_screen` and
   `round_result_screen` (§10.1). Needs a layout decision, not more semantics. Belongs to a future
   loop-layout WP.
2. **MANUAL TEST REQUIRED** — the VoiceOver/TalkBack pass (§10.3). No automated evidence substitutes
   for it; §6's defect is the proof.
3. **KNOWN LIMITATION** — five provider-heavy screens (`profile`, `profile_public`, `paywall`,
   `season_details`, `leaderboard`) have no render-time overflow evidence, because their providers
   reach Firebase in `initState` (§9). A provider-override harness would close this.

AC2 is deliberately **not** marked MET. The band is correct and complete as infrastructure, but a
user selecting the largest text size can still visibly break two screens in the core loop, and
marking that MET would misrepresent what a player experiences.
