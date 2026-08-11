# ICONOGRAPHY AUDIT

> Verified by extracting every `Icons.*` reference in `lib/` and cross-referencing usage context.

---

## 1. Current state

**FACT.** Bufón uses exactly one icon source: Flutter's bundled **Material Icons**
(`uses-material-design: true`). There are:

- **0** custom icons
- **0** SVG icons (no `flutter_svg`, no vector assets)
- **0** `CupertinoIcons` uses, despite `cupertino_icons: ^1.0.8` being a declared dependency
- **0** icon fonts of Bufón's own
- **37** distinct Material glyphs, **8** of them outline variants

---

## 2. Complete glyph inventory

| Glyph | Uses | Where | Verdict |
|---|---|---|---|
| `emoji_events` (trophy) | 6 | season banner, season details, leaderboard, voting CTA, season badges | Over-used; four different meanings |
| `workspace_premium` | 4 | rank #1 badges | Redundant with `emoji_events` |
| `stars` | 3 | rank tier, winner stat | Redundant with `star` |
| `share` | 3 | profile app bar, winner CTA, public profile | Correct |
| `military_tech` | 3 | title selector, titles | Wrong register — medals are institutional, not playful |
| `close` | 3 | paywall, title selector | Correct |
| `check_circle` | 3 | `GameCard` selected, answer sent, vote sent | Correct and consistent |
| `visibility` | 2 | reveal banner, reveal stage 0 | Weak — see §4 |
| `star` | 2 | achievements | Redundant with `stars` |
| `photo_size_select_actual` | 2 | **top-10 season rank badge** | **Almost certainly a mis-pick** — this is a photo-crop icon |
| `lock` | 2 | locked avatars/titles | Correct |
| `how_to_vote` | 2 | voting CTA, vote banner | Correct, if generic |
| `favorite` (heart) | 2 | votes-received stat | Ambiguous — "likes" ≠ "votes" |
| `error_outline` | 2 | error states | Thin outline — forbidden by Cap. 12 |
| `calendar_today` | 2 | week indicator | Correct |
| `trending_up` | 1 | leaderboard | Corporate-analytics register |
| `touch_app` | 1 | "toca una respuesta" | Correct, if generic |
| `timer_outlined` | 1 | `TimerWidget` | Thin outline in the app's most important component |
| `theater_comedy` | 1 | reveal stage 2 | **Closest to brand of any glyph in use** |
| `star_outline` | 1 | locked achievement | Outline variant |
| `sports_esports` (gamepad) | 1 | `RoundIndicator` | Wrong semantics — Bufón is not a video game |
| `send` | 1 | submit answer | Correct |
| `refresh` | 1 | leaderboard reload | Correct |
| `public` | 1 | global leaderboard | Correct |
| `play_circle_outline` | 1 | watch-ad CTA | Outline variant |
| `person` | 1 | profile | Correct |
| `military_tech_outlined` | 1 | empty titles state | Outline variant |
| `lock_outline` | 1 | locked item | Inconsistent with `lock` used elsewhere |
| `home` | 1 | exit to home | Correct |
| `games` | 1 | achievements | Redundant with `sports_esports` |
| `emoji_events_outlined` | 1 | empty leaderboard | Outline variant |
| `edit` | 1 | edit profile | Correct |
| `copy` | 1 | copy room code | Correct |
| `chevron_right` | 1 | season banner affordance | Correct |
| `check` | 1 | title selected | Inconsistent with `check_circle` elsewhere |
| `arrow_forward_ios` | 1 | list affordance | Inconsistent with `chevron_right` |
| `add` | 1 | (paywall) | Correct |

---

## 3. Findings

### 3.1 Mixed weight families — Cap. 12 / Cap. 34 violation

**FACT.** 8 of 37 glyphs are outline variants (`timer_outlined`, `error_outline`, `star_outline`,
`lock_outline`, `military_tech_outlined`, `emoji_events_outlined`, `play_circle_outline`,
`visibility` in outline context), used alongside 29 filled glyphs — sometimes for the *same concept*
in different places (`lock` vs. `lock_outline`, `check` vs. `check_circle`,
`chevron_right` vs. `arrow_forward_ios`, `emoji_events` vs. `emoji_events_outlined`).

**INFERENCE.** The isotype is drawn entirely in heavy solid ink with no thin strokes anywhere. A
1.5 px-stroke outline glyph next to it reads as a different design language, and the design doc names
this exact problem twice (Cap. 12: "prefer always the filled/bold variant"; Cap. 34: "never use thin
Material outline iconography unmodified"). Fixing it requires no new dependency and no new asset —
it is a find-and-replace with a review pass.

**RECOMMENDATION — P1, ~1 hour.** Replace every outline variant with its filled sibling.
Standardise the four duplicated pairs onto one glyph each. This is the cheapest measurable
consistency win available in the entire audit.

### 3.2 Semantic mis-picks

**FACT.** Three glyphs do not mean what they are being used to mean:

| Glyph | Used for | Problem |
|---|---|---|
| `photo_size_select_actual` | top-10 season finish | It is an image-cropping icon. No relationship to ranking. |
| `sports_esports` | round counter | A gamepad frames Bufón as a video game; Cap. 2 explicitly positions it as a table game among friends. |
| `military_tech` | player titles | A military medal is the "institutional achievement" register — the opposite of Cap. 2's "cómplice, no espectáculo". |

**FACT.** Four glyphs (`emoji_events`, `workspace_premium`, `stars`, `star`) all mean "achievement /
rank / reward" and are used interchangeably across five surfaces.

**INFERENCE.** A player cannot learn the icon language because the same idea has four glyphs and one
glyph (`emoji_events`) has four meanings (active season, season details, leaderboard, "see results").
This is a comprehension cost, not just an aesthetic one.

### 3.3 One glyph is accidentally right

**FACT.** `Icons.theater_comedy` — the twin comedy/tragedy masks — appears once, at
`round_result_screen.dart:362`, as the stage-2 reveal icon.

**INFERENCE.** It is the only glyph in the set whose *meaning* (masks, performance, concealment
then revelation) matches Bufón's brand and mechanic. It is used at exactly the right moment. This is
worth recording as the semantic target for a custom set: the masks idea, redrawn on the isotype's
grid, is a far better Bufón glyph vocabulary than trophies and medals.

### 3.4 No accessible labels

**FACT.** Zero `semanticLabel` arguments on any `Icon`. **FACT.** One `tooltip` in the entire app.

**INFERENCE.** Icon-only controls are invisible to screen readers: the Lobby copy button, the
leaderboard refresh button, the paywall close button, the title-selector close button. Two of those
are the only exit from their surface.

**RECOMMENDATION — P0.** Every icon-only interactive control gets a `tooltip` (which supplies
semantics for free) or an explicit `Semantics(label:)`. Decorative icons get
`excludeSemantics: true` so they do not pollute the reading order.

### 3.5 Touch targets

**FACT.** Interactive icon counts by file: `profile_screen.dart` 3, `title_selector_dialog.dart` 2,
`paywall_screen.dart` 2, and one each in lobby, leaderboard, public profile, season banner.

**FACT.** All icon-only controls use Material's `IconButton`, which enforces a 48×48 minimum by
default — so Cap. 15's touch-target rule is satisfied for icons **by inheritance, not by intent**.

**FACT.** The controls that *do* risk failing the 48 dp floor are the custom `GestureDetector`-based
ones: `AnimatedPrimaryButton` (~52 px tall by padding accident) and `SeasonCountdownBanner` (a whole
card, so fine). No text-only tappable spans exist.

**INFERENCE.** Low risk today, but it is luck rather than design. `AnimatedPrimaryButton` should
enforce `AppSpacing.buttonHeight` explicitly so a future caller passing tighter `padding` cannot
break it.

---

## 4. Strategy for 1.1

### 4.1 What Cap. 12 asks for, and whether to do it

The design doc's v1.1 position is: filled Material Symbols as a short-term patch; a **custom set of
15–20 icons** drawn on the isotype's exact grid for high-frequency glyphs; Material as fallback for
the long tail. It explicitly rejects adopting Phosphor wholesale on the grounds that a
mass-adopted third-party set communicates nothing proprietary.

**REFERENCE — what comparable projects do.** Lichess Mobile ships **four custom icon fonts**
(`LichessIcons.ttf`, `SocialIcons.ttf`, `ChessFont`, `PuzzleIcons.ttf`) *alongside*
`material_symbols_icons` and `cupertino_icons`. It does not choose between custom and library — it
uses custom glyphs for domain concepts (pieces, puzzle types) and a library for generic UI. Wonderous
ships `flutter_svg` and hand-authored SVG icons under `assets/images/_common/icons/`. shadcn_ui
depends on `lucide_icons_flutter`.

**INFERENCE.** The hybrid model is the industry-standard answer and it is also the cheapest: a small
custom set for the ~8 concepts that carry brand meaning, and a library for the ~30 that do not.
Bufón's own design doc reaches the same conclusion independently.

### 4.2 The recommended set

**RECOMMENDATION.** Draw **8 custom glyphs** in 1.1, not 15–20. Scope discipline matters more than
coverage, and these 8 cover every high-frequency, brand-carrying concept:

| # | Concept | Replaces | Why it must be custom |
|---|---|---|---|
| 1 | **Keyhole / secret** | `visibility`, `lock`, `lock_outline` | The single strongest brand device (isotype hat bells). Serves locked content *and* the pre-reveal state with one mark — a genuine idea, not a substitution. |
| 2 | **Mask / reveal** | `theater_comedy`, `visibility` | The reveal moment. Already semantically proven in-app. |
| 3 | **Crown / Bufón of the night** | `emoji_events`, `workspace_premium` | Winner is the emotional peak; a trophy is a sports metaphor Bufón is not. |
| 4 | **Stamp / vote** | `how_to_vote` | Cap. 20 makes the rubber stamp the material metaphor for confirming a verdict. Reifying it visually pays the audio system forward. |
| 5 | **Room / table** | `sports_esports`, `games` | "A phone in the middle of a table" is Cap. 1 law 4. A gamepad is the wrong product. |
| 6 | **Timer** | `timer_outlined` | Highest-visibility glyph in the app; sits inside the timer arc. |
| 7 | **Share** | `share` | Cap. 31 makes sharing a first-class brand act. |
| 8 | **Jester head (small)** | — | The isotype at icon scale: app bar identity, loader, avatar fallback. |

Everything else — `close`, `copy`, `refresh`, `edit`, `check`, `chevron_right`, `calendar_today`,
`person`, `send`, `add`, `home`, `public` — stays Material **filled**. These are generic UI verbs;
custom-drawing them buys nothing and costs consistency.

### 4.3 Delivery format

**RECOMMENDATION.** Ship the 8 as a **single icon font** (`.ttf`) rather than as SVGs.

Reasoning:
- One asset, tree-shakeable, `IconData`-compatible — so every existing `Icon(...)` call site,
  `IconTheme`, size and colour behaviour keeps working with a one-token change. No new dependency.
- **REFERENCE:** this is exactly Lichess Mobile's approach, on a Flutter app of comparable
  complexity and larger scale.
- The alternative (`flutter_svg` + 8 SVGs) adds a dependency and requires `SvgPicture` at every call
  site with manual colour filtering, breaking `IconTheme` inheritance.

**Caveat, stated honestly.** Icon fonts cannot be multi-colour and cannot animate their paths. If a
future direction wants a two-tone jester or an animating keyhole, that specific mark needs to be an
SVG or a `CustomPainter`. Recommendation: **font for the 8 UI glyphs, `CustomPainter` for the
isotype** (which needs animation for the breathing loader and the keyhole reveal anyway). That
combination needs zero new packages.

### 4.4 Should `material_symbols_icons` be adopted?

**REFERENCE.** `material_symbols_icons` 4.2960.0 (published ~3 weeks ago) provides 4,264 icons with
full variable-axis control: fill 0–100, weight 100–700, grade, optical size, in outlined/rounded/
sharp families. It bundles three variable font files and supports tree-shaking via the `Symbols`
class.

**INFERENCE.** The `weight: 700` + `fill: 100` + `rounded` combination is a genuinely close match to
the isotype's heavy-rounded language — far closer than stock Material Icons, which offer no weight
control. Adopting it would let the ~30 generic glyphs read as one family with the custom 8, rather
than as Google's defaults.

**Cost.** Three bundled variable font files. Tree-shaking works with the `Symbols` class, so only
used glyphs ship — but the fonts are assets, and the package's own docs do not publish a size figure.
For a 30-glyph app the marginal size should be small; it must be measured, not assumed.

**VERDICT: ADAPT, but as a P2 — after the custom 8 exist.** Adopting it before the custom set is
drawn would just be swapping one generic library for a newer generic library, which is precisely the
trap Cap. 34 warns against. Adopting it after gives a real benefit: a weight-matched fallback family.

### 4.5 Emoji as iconography

**FACT.** Emoji currently carry avatars (12), achievements, titles, share cards and the winner
headline. Emoji render in the OS font.

**INFERENCE.** Emoji are the largest *uncontrolled* icon set in the product. A Bufón avatar is
Apple's clown on iPhone and Google's clown on Android — the player's identity has two different
faces depending on the device, and neither belongs to Bufón. Cap. `FIRMA VISUAL` item 2 names "a
circular form substituted by a face" as a permanent brand device, and item 3 names closed-arc happy
eyes as the *only* sanctioned expression grammar. OS emoji satisfy neither.

**RECOMMENDATION — P1, and the largest visual-identity return in 1.1 after the app icon.** Replace
the 12 avatar emoji with 12 flat vector faces drawn on the isotype grid: same round nose, same
closed-arc eyes, same thick smile weight, differentiated by hat/accessory/colour rather than by
expression. This turns the avatar system from borrowed art into the brand's own character family,
and it makes every share card, lobby row, voting card and winner screen instantly Bufón.

Keep emoji only where they are *decorative punctuation in copy* (e.g. `⏰` in a countdown string),
never where they represent an entity.

---

## 5. Icon sizing

**FACT.** Literal sizes in use: 16, 20, 24, 28, 32, 36, 40, 46, 48, 64, plus emoji at 80/96/100/120.
There is no icon-size token.

**RECOMMENDATION — P2.** Add `AppShapes.iconSm 16 · iconMd 20 · iconLg 24 · iconXl 32 · iconHero 64`
and route call sites through it. Cap. 12 mandates a 24 dp minimum inside a 48 dp target for
interactive icons; a token makes that checkable.

---

## 6. Summary

| Decision | Verdict | Priority |
|---|---|---|
| Retain Material as the long-tail library | **Yes** | — |
| Replace all 8 outline variants with filled | **Yes** | **P1** |
| Consolidate the 4 duplicated glyph pairs | **Yes** | **P1** |
| Fix 3 semantic mis-picks (`photo_size_select_actual`, `sports_esports`, `military_tech`) | **Yes** | **P1** |
| Draw 8 custom brand glyphs, ship as one icon font | **Yes** | **P1** |
| Replace 12 emoji avatars with brand faces | **Yes** | **P1** |
| Add `semanticLabel`/`tooltip` to every icon-only control | **Yes** | **P0** |
| Adopt `material_symbols_icons` for weight-matched fallback | **Yes, after the custom 8** | P2 |
| Add icon-size tokens | **Yes** | P2 |
| Adopt Phosphor / Lucide / Hugeicons wholesale | **No** — Cap. 34; swaps one generic set for another | — |
| Adopt `flutter_svg` purely for icons | **No** — icon font is cheaper and preserves `IconTheme` | — |
