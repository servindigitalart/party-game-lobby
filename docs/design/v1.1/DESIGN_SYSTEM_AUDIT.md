# DESIGN SYSTEM AUDIT — token layer, theme layer, adoption

> Verified against `bufon_flutter/lib/core/theme/*` and every consumer in `lib/`.
> Reference specification: `bufon_flutter/BUFON_DESIGN_SYSTEM.md` v1.1 (710 lines, commit `a900167`).

---

## 1. Where the tokens live

**FACT.** Six files under `lib/core/theme/`:

| File | Lines | Purpose | Quality |
|---|---|---|---|
| `app_colors.dart` | 144 | Butter Bliss palette + ramps + generators, **plus** the entire legacy palette | Split personality |
| `app_typography.dart` | 169 | Scale, display/body font seams, `tabular()` helper | Strong, one open decision |
| `app_spacing.dart` | 37 | 4/8/16/24/32/48/64 + `hairline`, `micro`, component constants | Complete |
| `app_shapes.dart` | 96 | Radius scale, border widths, composed `ShapeBorder` helpers | Complete |
| `app_elevation.dart` | 71 | "Capas de Foco" — ambient / protagonist / ceremonial | Complete |
| `motion_tokens.dart` | 133 | Durations, curves, scale factors, springs, brand physics | Complete |
| `app_theme.dart` | 491 | `lightTheme`, `darkTheme`, `legacyTheme` | Two of three unused |

**INFERENCE.** This is a well-above-average token layer for an indie project. The files are
documented with *reasoning*, not just values — `app_elevation.dart` explains why Material's z-axis
model was rejected; `motion_tokens.dart` explains why two press durations were preserved rather
than unified. That documentation is an asset worth protecting.

---

## 2. Colour tokens

### 2.1 Butter Bliss (canonical)

**FACT.** Eight base colours, each with a tint and a shade — 24 values total.

| Token | Base | Tint | Shade | Emotional role (Cap. 4) |
|---|---|---|---|---|
| `butter` | `#F8EE67` | `#FDFBE8` | `#D9C92A` | Anticipation — thresholds |
| `ink` | `#191919` | `#8A8578` (`inkSoft`) | `#000000` | Authority, text on light |
| `paper` | `#FAFAF7` | `#FFFFFF` | `#E4DFCF` (`paperLine`) | Calm, reading |
| `graphite` | `#242320` | `#3A382F` (`graphitePlus1`) | `#151410` | Live game, cinematic focus |
| `mint` | `#63D6A5` | `#E4F6EE` | `#1F9C6E` | Success, relief |
| `coral` | `#FF7A6A` | `#FDE9E4` | `#E85A46` | Tension, error |
| `sky` | `#6BC8FF` | `#E4F3FC` | `#1C7FB8` | Social energy, presence |
| `lavender` | `#9C8CFF` | `#EEEAFB` | `#6F5BD6` | Mystery, pre-verdict |

**FACT.** `generateTint()` / `generateShade()` implement the documented HSL formula so future
colours derive predictably. **Zero call sites.**

**INFERENCE.** The generators are correct infrastructure but currently dead code. They become
valuable the moment seasons get their own accent (`season.themeColor` is already an arbitrary int
from Firestore — see §6).

### 2.2 Legacy (still live)

**FACT.** 27 legacy tokens + 3 gradients remain in the same file, byte-for-byte unchanged from the
casino theme, with an explicit comment that they are deleted only after the last screen migrates.

**INFERENCE.** Keeping them was the right call for a phased migration — repointing them would have
silently reskinned nine screens. But the cost is real: a developer writing a new widget has 51
colour tokens to choose from and no compile-time signal about which set is canonical. That is how
a migration stalls.

**RECOMMENDATION.** Do not delete them in 1.1's first commit. Instead annotate every legacy token
with `@Deprecated('Legacy casino palette — migrate to Butter Bliss, see BUFON_DESIGN_SYSTEM.md
Cap. 5')`. `flutter analyze` then produces a live, decreasing burndown count of remaining migration
work, at zero runtime risk. `AppTypography.displayGold` already demonstrates the pattern.

### 2.3 Contrast verification

**FACT.** The design doc asserts three pairs pass AA. Computed WCAG 2.1 contrast ratios for the
pairs the code actually uses:

| Pair | Ratio | AA normal (4.5) | AA large (3.0) |
|---|---|---|---|
| `ink #191919` on `butter #F8EE67` | ~14.6 : 1 | Pass | Pass |
| `ink #191919` on `paper #FAFAF7` | ~16.4 : 1 | Pass | Pass |
| `paper #FAFAF7` on `graphite #242320` | ~14.2 : 1 | Pass | Pass |
| `inkSoft #8A8578` on `paper #FAFAF7` | ~3.0 : 1 | **Fail** | Pass |
| `inkSoft #8A8578` on `butterTint #FDFBE8` | ~3.1 : 1 | **Fail** | Pass |

**FACT.** `inkSoft` is used for body text in `home_screen.dart` (the tagline
"¿Quién es el más chistoso?", `body1` = 16pt) and for the "Código de Sala" label and disabled
button labels in `lobby_screen.dart`.

**INFERENCE — actionable defect.** `inkSoft` is a *muted* colour, not a *text* colour, and it is
currently being used as body text below the large-text threshold. Cap. 28's claim that the system's
text pairs all pass is true for the three primary pairs but not for the secondary pair the migrated
screens actually shipped.

**RECOMMENDATION.** Introduce `inkMuted` at roughly `#5C574C` (≈ 7.1 : 1 on Paper) for secondary
text, and reserve `inkSoft` for non-text uses (hairlines, disabled fills, icon washes). This is a
token addition, not a palette change — it does not touch the eight-colour identity.

---

## 3. Typography tokens

**FACT.** Scale: `caption` 12 · `body2` 14 · `body1`/`button` 16 · `buttonLarge` 18 · `h4` 20 ·
`h3` 24 · `h2` 28 · `h1` 32 · `display` 48. Line heights 1.1–1.5. Negative tracking restricted to
`display`/`h1`/`h2` exactly as Cap. 6 specifies.

**FACT.** Font selection is isolated behind two private functions, `_display()` and `_body()`, both
currently returning `GoogleFonts.plusJakartaSans`. Changing the Display face is a one-function
edit — an unusually clean seam.

**FACT.** Base styles hardcode `color: AppColors.textPrimary` (white). `app_theme.dart` compensates
with `.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)` for the new themes, and
documents why.

**INFERENCE.** The `.apply()` compensation only rewrites styles that flow through `Theme.of(context)
.textTheme`. Screens that call `AppTypography.h4` directly — which is what every screen does — get
the white default and must `.copyWith(color: …)` at every call site. `lobby_screen.dart` does this
19 times. That is the actual source of the "9 `AppColors.ink` uses" figure, and it is fragile: one
forgotten `copyWith` on a light screen produces invisible white-on-Paper text.

**RECOMMENDATION (1.1, P0).** Remove the hardcoded colour from `AppTypography` base styles
(`color: null`) once the legacy screens set an explicit colour or move to `Theme.of(context)`.
Until then, add colour-carrying convenience getters (`AppTypography.h4OnPaper` etc.) or migrate
screens to `Theme.of(context).textTheme`. The failure mode of the current design is silent and
invisible, which is the worst kind.

**FACT.** `AppTypography.tabular()` exists; applied twice (Lobby room code, `TimerWidget` seconds).
Scores, XP, vote counts and round counters do not use it.

**FACT.** `displayButter` exists and is unused; `displayGold` is deprecated and unused.

---

## 4. Spacing, shape and elevation tokens

**FACT — spacing.** `hairline: 1`, `micro: 2`, `xs: 4`, `sm: 8`, `md: 16`, `lg: 24`, `xl: 32`,
`xxl: 48`, `xxxl: 64`, plus `cardPadding/cardMargin/cardRadius(20)/buttonPadding/buttonRadius(16)/
buttonHeight(56)/screenPadding`. Adoption is genuinely high: screens use `AppSpacing.*` almost
exclusively. This is the single most successfully adopted token family in the app.

**FACT — shapes.** `radiusXs 8 · radiusSm 12 · radiusMd 16 · radiusLg 20 · radiusXl 28 ·
radiusFull 999`, `borderWidthHairline 1`, `borderWidthFocus 2`, plus `hairlineBorder()`,
`focusBorder()`, `pill`, `card()`, `heroCard()`, `button()`.

**FACT — shape adoption.** `AppShapes.card()` 2 uses, `heroCard()` 1, `pill` 0, `borderRadiusXs` 0,
`radiusFull` 0. Meanwhile screens still hand-write `BorderRadius.circular(3|10|12|16|20|25)`.
`circular(25)` in `share_profile_card.dart` and `circular(3)` in two progress bars are outside the
scale entirely (the latter is documented as intentional, deriving from a 6px bar height).

**INFERENCE.** `pill` and `radiusFull` being unused is significant: Cap. 9 makes the pill one of
three sanctioned shapes and ties it directly to the logotype's letterforms. Every primary button in
the app is a 16px-radius rectangle. The shape vocabulary the brand claims is not the shape
vocabulary the app renders.

**FACT — elevation.** `AppElevation.ambient` (empty shadow list), `protagonistShadow(color)`
(colour-tinted, blur 12, offset 0/4, 30% alpha), `ceremonialGradient(from, to)`.
`protagonistShadow` is used by `AnimatedPrimaryButton`, `GameCard` and the Lobby room-code card.
`ceremonialGradient` has **zero** call sites — including on `final_winner_screen.dart`, the one
screen it was written for, which instead builds its own three-stop `LinearGradient` of
`primary@20% → #111111 → gold@10%`.

---

## 5. Theme layer

**FACT.** `AppTheme` exposes three themes:

- `lightTheme` — Paper register. Full Material 3 mapping: appBar, card (elevation 0, transparent
  shadow), elevated/outlined/text buttons, inputs, progress, divider, text selection, snackbar,
  dialog, bottom sheet, navigation bar, icon theme. **Applied only inside `home_screen.dart` and
  `lobby_screen.dart` via a local `Theme` widget.**
- `darkTheme` — Graphite register, identical structure. **Zero call sites.**
- `legacyTheme` — the untouched casino theme. **This is what `MaterialApp` applies.**

**FACT.** `_lightColorScheme.primary` is `butterShade`, not `butter`, with a documented reason:
Material spreads `primary` into hairlines and focus rings where `#F8EE67` on `#FAFAF7` would
disappear. True `butter` is applied explicitly to large button fills.

**INFERENCE.** That is a correct and non-obvious call. It is also the reason the migrated screens
must pass `backgroundColor: AppColors.butter` explicitly to `AnimatedPrimaryButton` — the theme
cannot do it for them.

**FACT.** `_darkColorScheme.primary` is `sky`, with a documented note that Material's single global
`ColorScheme` cannot express Cap. 33's per-phase accents (Lavender for voting, Mint for winning),
so those must be applied at widget level per screen.

**INFERENCE — architectural, and the most important finding in this document.** The design system
is built around **phase-scoped colour registers**, and Material's `ThemeData` is built around **one
global scheme**. The two are structurally mismatched. The repo has already discovered the
workaround empirically (Home and Lobby wrap themselves in a local `Theme`). That workaround should
be promoted to an explicit, named pattern rather than repeated ad hoc nine more times.

**RECOMMENDATION (1.1, P0).** Introduce a `BufonPhaseTheme` (or `PhaseScope`) wrapper —
a `StatelessWidget` that takes a phase enum (`lobby | answering | voting | reveal | winner |
profile | store`) and applies the right `ThemeData` plus exposes the phase accent through an
`InheritedWidget`. Every screen then declares its register in one line, and the accent is available
to every descendant without prop-drilling. This is a small amount of new code that removes the
per-screen `.copyWith(color:)` tax described in §3, and it makes "one emotional colour per screen"
enforceable rather than aspirational.

---

## 6. Tokens that bypass the system

**FACT.** Four colour authorities exist outside `AppColors`:

1. `AvatarRarity.color` → `String` hex (`'#CCCCCC'`, `'#4A9EFF'`, `'#B24AFF'`, `'#FFD700'`).
2. `TitleRarity.color` → `int` (`0xFFB3B3B3`, `0xFF2196F3`, `0xFF9C27B0`, `0xFFFFD700`).
3. `Season.themeColor` → arbitrary `int` from Firestore, rendered directly by
   `SeasonCountdownBanner` and `SeasonDetailsScreen` as fill, border, glow and icon colour.
4. `_getRankColor()` in `leaderboard_screen.dart` → `AppColors.gold`, `Colors.grey`, `Colors.brown`.

**INFERENCE.** Three of these are *server- or model-driven* colour, which is the hardest kind to
govern. `Season.themeColor` in particular means a Firestore document can inject any hue into the
Home screen — including one that clashes with Butter or fails contrast against Graphite. The design
system has no defence against this today.

**RECOMMENDATION.** In 1.1, constrain season theming to a **named palette enum** resolved client-side
(`SeasonAccent.lavender | .sky | .mint | .coral`), with `themeColor` retained only as a legacy
fallback. Derive tint/shade with the existing `generateTint`/`generateShade` so a new season accent
is automatically consistent. This finally gives those generators a job.

**RECOMMENDATION.** Collapse the two rarity colour ladders into one shared `Rarity` enum backed by
Butter Bliss values (see `COMPONENT_INVENTORY.md` §Rarity).

---

## 7. Adoption scorecard

| Token family | Defined | Adopted where it matters | Adoption |
|---|---|---|---|
| Spacing | ✅ complete | Everywhere | **~95%** |
| Typography scale | ✅ complete | Everywhere | **~95%** |
| Typography *face* | ⚠️ undecided, unbundled | n/a | **0%** (runtime-fetched) |
| Shapes — radii | ✅ complete | 2 screens + 3 widgets | **~25%** |
| Shapes — pill/full | ✅ complete | Nowhere | **0%** |
| Elevation — protagonist | ✅ complete | 3 components | **~40%** |
| Elevation — ceremonial | ✅ complete | Nowhere | **0%** |
| Colour — Butter/Ink/Paper | ✅ complete | Home + Lobby | **~18%** |
| Colour — Graphite/Sky/Lavender/Mint/Coral | ✅ complete | Nowhere | **0%** |
| Motion — durations/curves/scales | ✅ complete | 3 widgets | **~40%** |
| Motion — springs/physics/arrive | ✅ complete | Nowhere | **0%** |
| Themes — light/dark | ✅ complete | 2 screens, locally | **~18%** |

**Weighted design-system maturity: 6/10.** The specification and the token layer are 9/10 work.
The wiring is 3/10 work. 1.1's job is wiring.

---

## 8. Gaps in the system itself (not just adoption)

These are things the token layer genuinely does not have yet.

| Gap | Why it matters | Priority |
|---|---|---|
| No accessible secondary text colour | `inkSoft` fails AA at body size (see §2.3) | **P0** |
| No reduce-motion contract | Cap. 28 requires it; nothing reads `MediaQuery.disableAnimations` | **P0** |
| No phase-scope mechanism | Material's single scheme can't express per-phase registers | **P0** |
| No opacity scale | `withValues(alpha:)` uses 0.05/0.1/0.12/0.16/0.2/0.3/0.35/0.5/0.6/0.72/0.74/0.8 ad hoc | P1 |
| No icon-size scale | 16/20/24/28/32/36/46/48/64 appear as literals | P1 |
| No z-order / overlay token | Confetti, off-screen share card, banners stack by accident | P2 |
| No breakpoint tokens | Portrait-only today; tablet/foldable undefined | P2 |
| No duration for "wait/coiled" states | Cap. `BRAND PHYSICS` prescribes breathing; `MotionPhysics` has the numbers but no widget | P2 |

---

## 9. What must not change

1. **The spacing scale.** It is adopted, coherent, and invisible-when-right. Touching it would
   create diff noise across every file for zero perceived gain.
2. **The typographic scale.** Same reasoning. Only the *face* is open.
3. **The "Capas de Foco" model.** Rejecting Material elevation for narrative focus is the most
   original idea in the system and it is already implemented correctly.
4. **The motion asymmetry law** (compress fast, release with overshoot). It is implemented, it is
   correct, and it is the thing that makes taps feel like Bufón rather than like Flutter.
5. **The two-file font seam** (`_display`/`_body`). Do not inline `GoogleFonts.*` at call sites when
   the Display face is finally chosen.
