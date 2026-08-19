# WP5 — Large-Text / Responsive Loop Layout

**Date:** 2026-08-13
**Baseline commit:** `dfd0f1a feat: add accessibility foundation to core screens` (= `origin/main`)
**State:** uncommitted, in the working tree. No commit, push, reset, restore, clean or stash was run.
**Verification:** `flutter analyze` → **No issues found**. `flutter test` → **217 passing, 0 failing**
(188 baseline + 29 new). `git diff --check` → clean. Diff is **2 production files**.

Resolves the two findings WP4 deferred (`WP4_ACCESSIBILITY_REPORT.md` §10.1) and closes AC2's
class-B gap. The global text-scaling policy is unchanged.

---

## 1. Baseline Failure

Reproduced before any code was touched, with a regression suite written first
(`test/large_text_layout_test.dart`). Matrix: {Voting pending, Voting cast, Round Result through the
full reveal} × {360×800, 390×844} × {1.0×, 1.2×, 1.4×}, driven with a full eight-player room and
answers at the 100-character cap the game enforces.

**Baseline result: 5 passing, 16 failing.**

| Screen | 1.0× | 1.2× | 1.4× |
|---|---|---|---|
| Voting (pending) | pass | **FAIL** | **FAIL** (267 px) |
| Voting (vote cast) | pass | **FAIL** | **FAIL** |
| Round Result | **FAIL** (118–145 px) | **FAIL** | **FAIL** |

Two composition assertions also failed, both as collateral of the same overflow: the Round Result
host CTA was pushed off the bottom of the screen (`rect.bottom > 800`), and the WP3 reveal-gating
test failed only because the recorded layout exception polluted it — the gate itself was intact.

> **Correction to WP4's account.** WP4 reported these as *maximum-text-scale* problems. They are
> not. **Round Result overflows at 1.0×**, at normal text size, whenever the room is full — an
> everyday eight-player game, not an accessibility edge case. WP4's figures came from a 3.0×
> harness with the test font and overstated the scale dependence while understating the severity.

Text scales are applied directly here rather than through `MyApp`, because the production band
clamps to 1.4 — so 1.0/1.2/1.4 are exactly the effective values a device can produce, and testing
3.0 would measure a state the app never renders.

---

## 2. Exact RenderFlex Cause — Voting

**Owner:** `Column` at `lib/screens/voting_screen.dart:255`, `Axis.vertical`. Confirmed from the
framework's own report, not inferred.

```
Padding(all: lg)
└ Column (stretch)                     ← THE OVERFLOWING RENDERFLEX
   ├ GameProgressBar                   ← non-flex, grows with text
   ├ Semantics(header) Text  (h2)      ← non-flex, grows a lot
   ├ Container(question)     (body1)   ← non-flex, grows a lot
   ├ [transition banner]               ← non-flex, conditional
   ├ Expanded(ListView.separated)      ← TIGHT FLEX
   ├ Container(status: icon + prompt + progress + copy)  ← non-flex, grows
   └ [AnimatedPrimaryButton]           ← non-flex, grows
```

`freeSpace = viewport − Σ(non-flex children)`. Every non-flex child grows with the text scale while
the viewport does not. Past ~1.2× their sum exceeds the viewport, `freeSpace` goes negative, the
single `Expanded` is allotted a negative extent, and `RenderFlex` reports the overflow.

## 3. Exact RenderFlex Cause — Round Result

**Owner:** `Column` at `lib/screens/round_result_screen.dart:269`, `Axis.vertical`.

```
Padding(all: lg)
└ Column (stretch)                     ← THE OVERFLOWING RENDERFLEX
   ├ TweenAnimationBuilder(_WinnerSpotlight)   ← non-flex; the app's most
   │                                             scale-sensitive block: a
   │                                             display-size name over a
   │                                             multi-line answer
   ├ stage ≥ 2 → [ SizedBox, Semantics(header) Text,
   │               Expanded(_NightScoreboard) ]  ← TIGHT FLEX
   │  else     → Spacer()                       ← TIGHT FLEX (Expanded)
   ├ SizedBox
   └ AnimatedPrimaryButton | waiting Container  ← non-flex, grows
```

Identical mechanism, with a tight flex child in *both* branches. It bites at 1.0× because the
spotlight is genuinely large: eight scoreboard rows plus a 100-character winning answer already
exceed a 360×800 viewport before any scaling is applied.

---

## 4. Rejected Approaches

WP4 rejected three options by reasoning. WP5 re-tested the load-bearing one **empirically** rather
than inheriting the conclusion, because the whole design depended on it.

### 4.1 `Flexible(loose)` on the header — REJECTED, now with measurements

The hope was that `RenderFlex`'s "last flex child receives `freeSpace − allocatedFlexSpace`" rule
would let a loose header take its intrinsic height and hand the remainder to the `Expanded` list.
A direct probe says otherwise:

```
Column(height 500) [ Flexible(loose, intrinsic 100), Expanded ]
  → header = 100, list = 250, total = 350
  → 150 px of DEAD SPACE
```

Flex allocates by weight, not sequentially: the loose child's unused share is not redistributed.
A second probe confirmed the other half of the picture — a `Flexible` wrapping a scroll view **does**
cap and scroll instead of overflowing (`inner 900 → viewport 250`, total exactly 500). So the
mechanism prevents overflow but pays for it with dead space at normal scale. **Rejected: it makes
1.0× materially worse to fix 1.4×.**

### 4.2 Home's `SingleChildScrollView` + `ConstrainedBox(minHeight:)` — REJECTED

It works on `home_screen` precisely *because* that Column has no flex children. Applied here it
gives the Column unbounded height, which `Expanded` and `Spacer` cannot live under, so it forces
deleting the `Spacer`, un-`Expanded`ing the list and scoreboard, and pinning nothing. **Rejected as
a blind copy** — though the chosen strategy borrows its spirit while keeping the CTA outside.

### 4.3 A fraction of `constraints.maxHeight` — REJECTED

A magic viewport constant by construction, and viewport-specific. Explicitly out of bounds.

### 4.4 Wrapping the whole screen in one scroll view — REJECTED

It removes the overflow but unpins the status block and the CTA. A vote confirmation that can
scroll out of view is not a confirmation, and the primary action would leave the screen exactly when
the content is longest.

---

## 5. Chosen Layout Strategy

**Move the scroll boundary outward around the *content*, and keep the chrome outside it.**
(Option D of the brief: "a constrained scrollable region while keeping the CTA outside it".)

One structural change per screen, and no new widget types beyond `SingleChildScrollView`:

```
Column
 ├ Expanded(                       ← the scroll region; was on the list alone
 │   child: SingleChildScrollView(
 │     child: Column [ everything that grows with text ] ))
 ├ status block        ← Voting only, stays pinned
 └ CTA                 ← stays pinned
```

Why this satisfies the contract:

- **`freeSpace` can no longer go negative.** The only flex child is the scroll region, and its
  content is now unbounded *inside* a viewport rather than pushing its siblings. Whatever the text
  scale, the Column's non-flex children are just the status block and the CTA.
- **1.0× is unchanged when the content fits.** The `Expanded` region occupies exactly the space the
  list used to, the header renders at the top of it, and the chrome sits where it always did.
- **The header stays a header.** It remains at the top of the content region and visible at rest;
  it was not collapsed, pinned, shrunk or restyled.
- **The CTA is never displaced.** It lives outside the scroll view, so it is on screen at 1.0× and
  at 1.4× alike — asserted at both.
- **The `Spacer` could be deleted honestly.** Its comment said it existed to *"hold the button at
  the bottom so the spotlight does not jump when the scoreboard arrives."* The `Expanded` does that
  job in both reveal stages, and unlike the `Spacer` it cannot be allotted a negative extent.

Both `ListView`s become `shrinkWrap: true` + `NeverScrollableScrollPhysics` so they participate in
the page scroll instead of competing with it. Both are bounded by the eight-player room cap, so
shrink-wrapping costs nothing.

No arbitrary `SizedBox` heights, no `MediaQuery` height fractions, no changes to the text-scale
policy, and no new dependency.

---

## 6. Files Changed

| File | Change |
|---|---|
| `lib/screens/voting_screen.dart` | Scroll boundary moved from the answer list to the header+list region; `ListView.separated` → shrink-wrapped, non-scrolling. Status block and CTA left outside. |
| `lib/screens/round_result_screen.dart` | Same move for spotlight+scoreboard; `Spacer` removed; `_NightScoreboard`'s `ListView.builder` → shrink-wrapped, non-scrolling. CTA left outside. |
| `test/large_text_layout_test.dart` | **New.** 29 tests. |

`git diff --stat`: 2 files, 196 insertions / 134 deletions — of which, ignoring whitespace,
**73 insertions / 11 deletions** are real content. The rest is reindentation from the new wrappers.

**Regression guard verified clean:** `main.dart`, `lib/core/theme/*`, `bufon_loader.dart`,
`bufon_placeholder.dart`, `final_winner_screen.dart`, every repository and controller, and
`pubspec.yaml` are all untouched.

---

## 7. Test Matrix

`test/large_text_layout_test.dart` — 29 tests, all passing. They assert the **absence** of a layout
exception and never its presence, so the bug cannot be frozen in as expected behaviour. Framework
errors are collected in a loop, because one frame can record several and `takeException` returns
them one at a time.

| Group | Cases |
|---|---|
| Overflow matrix | 3 scenarios × 2 viewports × 3 scales = **18** |
| Chrome stays pinned | Voting status + Round Result CTA, at 1.0× and 1.4× = **4** |
| Escape valve engages | Voting has real scroll extent at 1.4× with a full room = **1** |
| WP4 semantics survive | heading, tappable answer, vote live region, winner live region, scoreboard header = **4** |
| 1.0× composition | status on screen, CTA pinned low, reveal still gated = **3** |

Baseline before the fix: **16 of the first 21 failing**. After: **29 of 29 passing**.

---

## 8. 1.0× Verification

| Check | Result |
|---|---|
| Voting, 360×800 and 390×844, full room | no layout exception |
| Round Result through all three reveal stages, both viewports | no layout exception (**was failing at 1.0× before**) |
| Voting status block within the viewport | `0 ≤ top`, `bottom ≤ 800` |
| Round Result host CTA pinned low | `top > 600`, `bottom ≤ 800` — it was *off-screen* before |
| Reveal gating (WP3 contract) | scoreboard absent before stage 2, present after |
| No clipped content, no alignment anomaly | no exception recorded at any pump |

**What was not verified, and why.** The brief asks for rendered images. No golden infrastructure
exists and the brief also says not to add any unless genuinely necessary, so verification is
geometric — exact rectangles and recorded layout errors — which is stricter than inspecting a
screenshot for the properties in question, but does **not** cover subjective appearance. A human
should still look at both screens on a device.

One honest limitation: `flutter_test` renders with a font whose every glyph is one em wide, roughly
double a real font's average advance. Measured consequence: even a three-player round with brief
answers exceeds the Voting content region by 67 px at 1.0× in the harness. So the suite **cannot**
assert "the screen does not scroll at all when content is short" — that would measure the test font,
not the layout. The pinning assertions were chosen instead because they hold whatever the font
metrics are. On a device with the real font, a short round will simply not scroll.

## 9. 1.4× Verification

| Check | Result |
|---|---|
| Voting pending + cast, both viewports, 1.2× and 1.4× | no layout exception (all four were failing) |
| Round Result full reveal, both viewports, 1.2× and 1.4× | no layout exception |
| Voting status block still on screen at 1.4× | within the viewport |
| Round Result CTA still on screen at 1.4× | within the viewport |
| Content remains reachable | scroll extent > 0 at 1.4×, so the overflow became scrollable content rather than clipped content |
| No forced tiny text, no hardcoded heights | no typography or constraint constants introduced |

---

## 10. Accessibility Regression Verification

The full WP4 suite (`test/accessibility_test.dart`, 17 tests) passes unchanged, and WP5 adds four
assertions aimed specifically at the risk that a new scroll boundary silently drops semantics:

| Node | Crossed the boundary? | Result |
|---|---|---|
| Voting heading "¿Cuál es la respuesta más chistosa?" | yes — now inside the scroll view | still `isHeader` |
| Voting answer card | yes | still `isButton`, `isEnabled`, `hasTapAction` |
| Voting "¡Voto enviado!" live region | no — deliberately left pinned outside | still `isLiveRegion` |
| Round Result winner announcement | yes | still `isLiveRegion` |
| Round Result "Marcador de la noche" | yes | still `isHeader` |

Nothing was removed or weakened: no `Semantics`, header, live region, label, tooltip, tap action or
reduced-motion path was touched. The vote confirmation was deliberately kept **outside** the scroll
view so it cannot scroll away from a user who needs it.

**No VoiceOver/TalkBack claim is made.** There is still no physical device, and
`WP4_MANUAL_ACCESSIBILITY_CHECKLIST.md` remains NOT TESTED throughout.

---

## 11. Remaining Limitations

1. **Manual screen-reader pass still outstanding** — unchanged from WP4; no device.
2. **No rendered-image verification** — geometric assertions only (§8).
3. **Scroll behaviour changed in the already-scrolling case.** When content exceeds the viewport,
   the round header now scrolls together with the answers instead of staying fixed above an
   internally-scrolling list. This is inherent to the fix: with a permanently fixed header there is
   no room to give back at 1.4×, so something has to scroll. When content fits, nothing scrolls and
   nothing moved.
4. **`ShareVictoryCard`'s 470 px overflow** — pre-existing from WP3, untouched, out of scope.
5. **Five provider-heavy screens** (`profile`, `profile_public`, `paywall`, `season_details`,
   `leaderboard`) still lack render-time coverage — WP4 §9, unchanged and out of scope here.

---

## 12. Confirmation: No Game Logic Changed

The change is presentation-only. Reviewed against the whitespace-insensitive diff, the entire
non-comment content change is: `Column`/`Expanded`/`SingleChildScrollView` wrappers, `shrinkWrap`
and `physics` on two `ListView`s, deletion of one `Spacer`, and formatter reflow.

Untouched and verified by inspection of the diff: vote submission (`_vote`,
`submitVoteTransaction`), vote counts, winner calculation (`roundSortedPlayers`, `voteCounts`),
reveal stages and their timers, scoreboard gating, `_scheduleAutoResults` / `_nextRound` /
`_advanceRound`, all Firestore reads and writes, navigation, animations, haptics and confetti.

The two `ListView`s changed how they scroll, not what they build: both item builders are byte-for-
byte identical apart from indentation.

No stop condition from the brief was triggered — no game logic, no text-scale policy change, no
magic viewport constant, no worse 1.0×, no removed semantics, no Firebase change, no dependency.
