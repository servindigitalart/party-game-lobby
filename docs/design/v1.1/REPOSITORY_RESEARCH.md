# REPOSITORY RESEARCH — 15 external references, classified

> Every entry below was checked against its **current** published state (August 2026) via its
> repository, `pubspec.yaml` or pub.dev page. Version numbers and dates are as observed.
>
> Classification key:
> **ADOPT** — take the dependency into Bufón in 1.1 ·
> **ADAPT** — reimplement the idea in Bufón's own code, no dependency ·
> **INSPIRE** — the thinking informs a decision, nothing is copied ·
> **REFERENCE ONLY** — useful to consult, never a dependency ·
> **REJECT** — actively wrong for Bufón, with a reason.

---

## Product / UX references

### 1. gskinner — Wonderous
`github.com/gskinnerTeam/flutter-wonderous-app` · MIT · 4.5k★

**REFERENCE (observed).** Built by gskinner with the Flutter team as a visual-fidelity showcase.
Dependencies relevant here, from its `pubspec.yaml`: `flutter_animate ^1.0.0`, `flutter_svg ^1.1.4`,
`particle_field`, `flutter_circular_text`, `drop_cap_text`, `extra_alignments`, `flextras`, `gap`,
`sized_context`, `smooth_page_indicator`, `image_fade`, `flutter_native_splash`, `screenshot`,
`flutter_displaymode`. Bundles **six** custom font families (Cinzel, Yeseva, Tenor, Raleway,
MaShanZheng, B612Mono) and organises assets per-wonder plus a shared `_common/` folder containing
`icons/` and `texture/`.

**What matters for Bufón:**

1. **REFERENCE.** Wonderous ships six fonts as bundled assets. It does not runtime-fetch typography
   for a design-led app. This is direct external corroboration of `TYPOGRAPHY_AUDIT.md`'s P0 finding.
2. **REFERENCE.** It maintains a shared `assets/images/_common/texture/` folder — texture is a
   first-class asset category, not an afterthought.
3. **REFERENCE.** It ships `flutter_native_splash`, i.e. the launch experience is treated as a design
   surface. Bufón's launch screen is still the Flutter template.
4. **REFERENCE.** The composition language — one enormous focal image, everything else compressed to
   thin edges — is precisely Cap. 3 law 4. Wonderous is the strongest existing proof that the law
   produces a distinctive product rather than an awkward one.
5. **INFERENCE.** Its small-utility dependencies (`gap`, `flextras`, `extra_alignments`,
   `sized_context`) are a layout-ergonomics choice, not a design one. Bufón's `AppSpacing` +
   `SizedBox` idiom is already consistent; adding four micro-packages to save keystrokes would be
   pure churn.

**Verdict: INSPIRE** for composition and asset discipline. **ADOPT nothing directly.** Its
`flutter_animate` dependency is assessed separately (§10).

---

### 2. AppFlowy
`github.com/AppFlowy-IO/AppFlowy` · AGPL-3.0 · Flutter + Rust

**REFERENCE (observed).** An open-source Notion alternative; Flutter front end, Rust backend, desktop
+ mobile from one codebase. Its repository overview does not document a design-token system or a
published component library; the visible design infrastructure is localisation tooling
(`project.inlang.json`, a translations resource tree).

**What matters for Bufón:**

1. **INFERENCE.** AppFlowy's relevance is *architectural*, not visual: it is the reference case for a
   Flutter app that survived growing into desktop + mobile with a shared component layer. Bufón is
   portrait-phone-only and locked that way in `main.dart`. There is no near-term need.
2. **REFERENCE.** Its licence is **AGPL-3.0**. Nothing may be copied from it into Bufón, which is a
   private commercial product. This is a hard blocker on code reuse, and worth recording so nobody
   lifts a widget from it later.
3. **INSPIRE.** Its use of a formal localisation pipeline is a genuine gap-flag for Bufón: Bufón's
   Spanish strings are hardcoded in Dart with no i18n layer. Not a 1.1 concern, but the day Bufón
   wants an English build, `GameCopy` becomes the bottleneck — and centralising *all* copy in
   `GameCopy` (already a P1 recommendation for voice reasons) is also the right first step for i18n.

**Verdict: REFERENCE ONLY.** AGPL forbids reuse; the desktop/plugin architecture problems it solves
are not Bufón's problems.

---

### 3. LocalSend
`github.com/localsend/localsend` · MIT

**REFERENCE (observed).** Cross-platform file transfer, six platforms. UI/theming dependencies:
`yaru 10.2.0`, `dynamic_color 1.8.1`, `flex_color_picker 3.8.0`, `local_hero 0.3.0` (hero
transitions between routes), `pretty_qr_code 3.6.0`. State via `refena_flutter`; localisation via
`slang`. Assets: `assets/img/` and a bundled `CHANGELOG.md`.

**What matters for Bufón:**

1. **REFERENCE — the clearest single lesson.** LocalSend leans *into* platform-adaptive theming
   (`dynamic_color` for Material You, `yaru` for Linux). It lets the OS supply the palette. Bufón
   must do the **opposite**: Butter and Ink are the brand, and a dynamic-colour scheme derived from a
   user's wallpaper would erase `FIRMA VISUAL` item 1. Recording this explicitly matters because
   `dynamic_color` is a fashionable, well-reviewed package that would be actively destructive here.
2. **INSPIRE.** `local_hero` animates a widget between routes without a `Hero` on both sides. That is
   structurally the right shape for two Bufón moments: the room code travelling from Lobby into the
   game header, and a winning answer card travelling from the voting list into the reveal spotlight.
   Bufón can express both with Flutter's built-in `Hero` because the source and destination are known
   — no dependency needed.
3. **REFERENCE.** LocalSend bundles `CHANGELOG.md` as an asset and renders it in-app. Cheap idea for
   a "what's new in 1.1" surface; low priority.

**Verdict: REJECT `dynamic_color`/`yaru` for Bufón (they contradict the brand). INSPIRE for
shared-element transitions, implemented with the SDK's own `Hero`.**

---

### 4. Lichess Mobile
`github.com/lichess-org/mobile` · AGPL-3.0

**REFERENCE (observed) — the closest structural analogue to Bufón in this list:** a Flutter mobile
game client, Riverpod state management, Firebase Crashlytics + Messaging, realtime multiplayer over
WebSocket. Observed dependencies of interest: `flutter_riverpod ^3.4.1`,
`material_symbols_icons ^4.2960.0`, `cupertino_icons ^1.0.9`, `dynamic_system_colors ^1.9.0`,
`material_color_utilities ^0.13.0`, `sound_effect ^0.2.0`, `flutter_spinkit ^5.2.2`,
`flutter_native_splash ^2.4.8`, `flutter_displaymode ^0.7.0`, `auto_size_text ^3.0.0`,
`visibility_detector`, `wakelock_plus ^1.7.0`, `popover`, `fl_chart`.

Bundled assets: **six** sound theme directories (`futuristic`, `lisp`, `nes`, `piano`, `standard`,
`sfx`), board thumbnails, and **four custom icon fonts** — `LichessIcons.ttf`, `SocialIcons.ttf`,
`ChessSansPiratf.ttf`, `PuzzleIcons.ttf`.

**What matters for Bufón:**

1. **REFERENCE — icons.** Lichess ships custom icon fonts **alongside** `material_symbols_icons`. It
   does not choose between custom and library; it uses custom glyphs for domain concepts and a library
   for generic UI verbs. This is direct external validation of `ICONOGRAPHY_AUDIT.md`'s hybrid
   recommendation, from a mature app at far greater scale.
2. **REFERENCE — sound.** Six *selectable* sound themes as bundled asset directories, played through
   `sound_effect` (a deliberately minimal low-latency package rather than a full audio engine).
   Bufón's Cap. 20 material language (cardstock / wood / stamp / bell) maps onto exactly this shape:
   one bundled directory, one thin playback package. This is the concrete implementation model for
   Bufón 1.2's audio work.
3. **REFERENCE — `wakelock_plus`.** A chess app keeps the screen awake during a game. **INFERENCE:**
   Bufón has a 90-second answering phase during which a player may be typing slowly, reading, or
   laughing — and the phone will dim and sleep on its default timeout, mid-round, in the middle of a
   table. `wakelock_plus` during the active game phases is a small, real, unglamorous usability fix
   that nobody would think to ask for. **This is the single most useful finding in the entire external
   research pass.**
4. **REFERENCE — `auto_size_text`.** Used to fit dynamic strings without overflow. Relevant to
   `GameCard` (100-char answers) and the question card (`h2`, variable length). Bufón can achieve the
   same with `FittedBox`/`maxLines` + ellipsis; the package is a convenience, not a capability.
5. **REJECT — `dynamic_system_colors`.** Same reasoning as LocalSend: Bufón's palette is the brand.
6. **REFERENCE — licence.** AGPL-3.0. No code may be copied. Patterns and package *choices* are
   observable facts, not copyrightable expression — those are safe to learn from.

**Verdict: ADOPT `wakelock_plus` (P1). ADAPT the custom-icon-font + library hybrid. REFERENCE the
sound architecture for 1.2. REJECT dynamic system colours.**

---

### 5. Obtainium
`github.com/ImranR98/Obtainium` · GPL-3.0

**REFERENCE (observed).** Android app-updater. UI/theming stack: stock Material 3 plus
`dynamic_system_colors ^1.9.0`, `hsluv ^1.1.3`, `flex_color_picker ^3.8.0`, `animations ^2.2.0`,
`easy_localization`, and one bundled font (`Montserrat-Regular.ttf`). `provider` for state.

**What matters for Bufón:**

1. **REFERENCE.** `animations ^2.2.0` is the **Flutter-team-maintained** transition package
   (container transform, shared axis, fade-through, fade-scale) — Material's own motion spec, in a
   package. Worth naming explicitly because it is the obvious candidate for Bufón's page transitions
   and it is the **wrong** one: Cap. 34 forbids "un simple fade lineal de Material sin escala/rebote",
   and this package's entire value is faithfully implementing Material motion. Bufón already has
   `FadeSlidePageRoute`, which is 60 lines and does what the brand wants.
2. **REFERENCE.** `hsluv` performs perceptually-uniform colour manipulation. Bufón's
   `generateTint`/`generateShade` use plain HSL, which is *not* perceptually uniform — a fixed
   lightness shift reads as a different amount of change depending on hue. **INFERENCE:** for the
   eight hand-picked Butter Bliss colours this is irrelevant (they were tuned by eye and the values
   are fixed). It becomes relevant only if season accents are generated programmatically from
   arbitrary hues. Note it, don't act on it.
3. **INFERENCE.** Obtainium is a well-liked utility app that looks like *stock Material 3*. It is a
   useful negative control: it demonstrates exactly the ceiling Bufón would hit by staying on default
   Material. Good for a tool. Fatal for a party game whose product is emotional memory.

**Verdict: REFERENCE ONLY.** `animations` is explicitly **REJECT**ed by Cap. 34. `hsluv` is a
noted-but-unneeded refinement.

---

## Design systems / components

### 6. Forui
`pub.dev/packages/forui` · 0.25.0, published ~7 days ago · MIT + OFL-1.1 · requires Flutter 3.44+

**REFERENCE (observed).** 40+ widgets across layout, form, data, navigation, overlay and feedback
categories. Designs "heavily inspired by shadcn/ui". Explicitly targets desktop and touch interfaces
rather than native Material or Cupertino aesthetics. Ships a theming CLI and a `forui_hooks` companion
for Flutter Hooks integration.

**Assessment for Bufón:**

- **What it would give.** A complete, coherent, well-tested widget set with a real theming layer,
  replacing Material's aesthetic wholesale.
- **What it would cost.** Bufón's identity is *not* minimalist. Cap. 2 is explicit: ingenious,
  complicit, warm, a little mischievous, screen-printed poster language, extreme corner rounding,
  thick solid ink. Forui's shadcn lineage is restrained, neutral, low-contrast, desktop-first — the
  aesthetic of a SaaS dashboard. Adopting it would make Bufón look competent and anonymous.
- **INFERENCE.** Bufón also does not have the *breadth* problem Forui solves. Its total component
  need is roughly 16 widgets (see `COMPONENT_INVENTORY.md`); 11 already exist and are mechanically
  good. Importing 40 widgets to use 6 of them adds a dependency, a Flutter-version floor and an
  aesthetic that must then be fought.
- **What is genuinely worth stealing.** Its **theming architecture** — a nested, inheritable style
  object per component rather than one global `ThemeData`. That is structurally the answer to the
  problem `DESIGN_SYSTEM_AUDIT.md` §5 identifies (Material's single global `ColorScheme` cannot
  express per-phase registers). Bufón's `PhaseScope` proposal is the same idea at 1/50th the scope.

**Verdict: ADAPT the per-component nested-style theming idea. REJECT the dependency.**

---

### 7. flutter-shadcn-ui
`pub.dev/packages/shadcn_ui` · 0.56.1, published ~5 days ago · 944 likes

**REFERENCE (observed).** 35+ components, positioned as a "material-alternative", "fully
customizable". Depends on `flutter_animate`, `flutter_svg`, `lucide_icons_flutter`. Maintainer's
stated philosophy: solve problems simply, make each widget extremely customisable.

**Assessment for Bufón:**

- Same aesthetic mismatch as Forui, from the same lineage. shadcn/ui's visual signature is subtle
  borders, muted neutrals and restrained radii; Bufón's is maximum contrast and extreme rounding.
- **REFERENCE — a useful datapoint.** Its dependency list is essentially the ecosystem consensus for
  "how you build a non-Material design system in Flutter in 2026": `flutter_animate` for motion,
  `flutter_svg` for vector assets, an icon-library package for glyphs. All three of Bufón's own
  open questions appear in one dependency block.
- **REJECT `lucide_icons_flutter` for Bufón.** Cap. 34 explicitly forbids adopting a mass-adopted
  icon set because it differentiates nothing. Lucide is the current default of that category.

**Verdict: REFERENCE ONLY.** Confirms the ecosystem's tool consensus; the aesthetic is wrong.

---

### 8. "Flutter UI Kit"
Ambiguous name; the candidates found are `ionicfirebaseapp/getwidget` (also `getwidget` on pub.dev,
1,000+ widgets), `iampawan/Flutter-UI-Kit`, `chandansgowda/flutter_ui_kit`,
`FlutterOpen/flutter-ui-nice`.

**REFERENCE (observed).** All four are large collections of pre-built screens/widgets/templates.
GetWidget is the most maintained (1,000+ widgets, published since 2017, ~23k monthly pub.dev users).
The others are template galleries.

**Assessment for Bufón:**

- **INFERENCE.** These are *velocity* tools for teams starting from nothing. Bufón is the opposite
  case: it has a 710-line design specification, a complete token layer and 11 working components, and
  its problem is adoption, not authorship. Importing a 1,000-widget kit would give Bufón a fourth
  colour authority and a fifth shape vocabulary.
- **INFERENCE — the specific danger.** Cap. 34 lists "patterns that would make Bufón look like a
  template" as a thing to avoid. Template kits are, definitionally, that. A kit's components are
  designed to look good *in a gallery screenshot*, which optimises for generic appeal — the exact
  opposite of Cap. 0's "recognisable without the logo" test.

**Verdict: REJECT.** Wrong problem, and directly counter to a stated brand constraint.

---

### 9. Awesome Flutter
`github.com/Solido/awesome-flutter`

**REFERENCE (observed).** A curated index — articles, videos, components, navigation, templates,
plugins, frameworks, community. It ships **no code**. Its Components section covers UI widgets, lists,
Material components, visual effects (shimmer, parallax), calendars, forms and theming tools; its
Animation section lists SpinKit, Villains, AnimatedTextKit; its Engines → Game section lists Flame,
Bonfire and Zerker.

**Verdict: REFERENCE ONLY** — by construction. It cannot be a dependency.

**INFERENCE — one caution worth writing down.** An index optimises for *discoverability*, and
browsing it while holding a design brief is how apps accrete dependencies. Bufón's audit shows the
codebase is currently commendably lean for UI (`google_fonts` and `cupertino_icons` are the only
UI-facing packages, and one of them is unused). That leanness is an asset. Any package sourced from
an index should have to clear the same bar as the two recommended in this document: it does something
Bufón cannot reasonably do in ~100 lines of its own code.

---

## Motion / interaction

### 10. flutter_animate
`pub.dev/packages/flutter_animate` · 4.5.2, published ~20 months ago · BSD-3 · gskinner (verified)

**REFERENCE (observed).** `.animate()` extension for chainable effects: fade, scale, slide, align,
flip, blur, shake, shimmer, shadows, crossfade, follow-path, colour/saturation/tint, plus
`ShaderEffect` (via `flutter_shaders`). `CustomEffect`, `ToggleEffect`, `SwapEffect` for bespoke
behaviour. `AnimateList` for staggered lists. Adapters (`ScrollAdapter`) to drive animations from
external sources. No codegen, no assets. Six platforms. Only dependency: `flutter_shaders ^0.1.2`.

**Assessment for Bufón — the closest call in this document.**

**For:**
- `AnimateList` with per-item interval is exactly the staggered entrance `voting_screen.dart:900`
  hand-rolls today with `200 + index*50`.
- `Arrive` (fade + scale from `MotionScale.arriveFrom` 0.88 + slight slide) becomes one chained line
  per widget instead of a `TweenAnimationBuilder` per site.
- It would delete meaningful boilerplate: the three `TweenAnimationBuilder` sites and both duplicated
  banner widgets.
- `shimmer` would give the loading states a treatment better than a spinner without new assets.
- Provenance is strong: gskinner authored it *and* Wonderous, so it is battle-tested in exactly the
  visual-fidelity context Bufón is aiming at. shadcn_ui depends on it too.

**Against:**
- **FACT.** Published 20 months ago — by far the least recently updated package in this research pass
  (compare Rive 6 days, Forui 7 days, shadcn_ui 5 days, Flame 21 days, Lottie 32 days). Not abandoned,
  but not actively moving either.
- **INFERENCE — the decisive argument.** Bufón's motion problem is **not expressiveness, it is
  adoption**. `motion_tokens.dart` already defines every duration, curve, scale and spring the design
  system asks for, and *half of them have never executed*. `KeyholeRevealTransition` is written and
  unused. The bottleneck is wiring, not ergonomics. Adding a fluent animation API to a codebase whose
  existing animation API is half-unused would optimise the wrong variable — and it would introduce a
  **second** motion vocabulary competing with `MotionDurations`/`MotionCurves`, which is precisely how
  the current two-palette situation happened.
- Its `.fade().scale()` chaining style also makes it easy to write animations that *don't* map to one
  of Cap. 16's six named behaviours, weakening a rule the token file exists to enforce.

**Verdict: ADAPT, not ADOPT — for 1.1.** Build one `Arrive` helper (a `StatelessWidget` or extension
wrapping `TweenAnimationBuilder`, reading `MotionDurations.arrive`, `MotionScale.arriveFrom` and
`MotionCurves.release`) — roughly 40 lines, and it enforces the token vocabulary instead of bypassing
it. **Revisit `flutter_animate` for 1.2** if, after that helper exists and Cap. 16's six behaviours
are all in use, motion authoring is still the bottleneck.

---

### 11. rive (Rive Flutter)
`pub.dev/packages/rive` · 0.14.11, published ~6 days ago · MIT runtime

**REFERENCE (observed).** Full control of `.riv` files: state machines, animations, layout, data
binding, runtime asset loading. Works on six platforms with both Flutter (Skia/Impeller) and Rive's
own native renderers; prebuilt native libraries are downloaded at build time. Files are authored
**exclusively** in the Rive editor (rive.app), which is a commercial product.

**Assessment for Bufón:**

- **What it uniquely enables.** State-machine-driven character animation — a jester face that reacts
  to game state (idle-breathing in the lobby, eyes-shut during voting, keyhole-opening at the reveal,
  laughing at the winner). That is a genuinely different product feel, and it is the *one* capability
  Bufón cannot reasonably hand-code.
- **What it costs.** (a) A commercial editor subscription and an authoring skill the project does not
  currently demonstrate. (b) A designer must produce and maintain `.riv` files — the pipeline, not the
  package, is the real cost. (c) Native library download at build time, which touches CI. (d) The
  package's own documentation acknowledges Impeller rendering issues requiring a Skia fallback.
- **INFERENCE — the sequencing argument.** Bufón currently has **no vector version of its own
  isotype** and no illustration assets at all. Rive is a tool for animating art that exists. Adopting
  it before the isotype exists as a vector, before the 12 avatar faces are drawn, and before the
  empty-state illustrations are drawn is buying a camera before there is anything to photograph.

**Verdict: REJECT for 1.1. Legitimate ADOPT candidate for 1.2+,** conditional on (1) the isotype and
avatar art existing as vectors, (2) someone owning the Rive authoring, (3) a named moment worth it —
the animated jester mark and the keyhole reveal are the two that would justify it.

---

### 12. lottie
`pub.dev/packages/lottie` · 3.5.1, published ~32 days ago · MIT

**REFERENCE (observed).** Renders After Effects animations exported as Bodymovin JSON, natively.
Supports Lottie JSON, dotLottie archives, Telegram `.tgs`, and zipped bundles with embedded images.
Feature parity is with **Lottie Android**, not with full After Effects. `renderCache` (added in 3.0)
renders frames lazily into an offscreen cache to cut CPU/GPU cost at the price of memory. Loads from
asset, network or memory.

**Assessment for Bufón:**

- **Pipeline reality.** Lottie needs After Effects (or a Lottie-exporting tool) plus an animator.
  Same fundamental dependency as Rive — art and a person to make it — with a *worse* interactivity
  story: Lottie plays timelines, it does not run state machines, so a jester that reacts to game state
  would need one file per state and manual crossfading.
- **Where it would actually fit.** One-shot celebratory flourishes: a level-up burst, an achievement
  unlock, an avatar-unlock reveal. Those are exactly the moments Bufón's *unreachable* progression
  screens would show.
- **INFERENCE.** Bufón's celebration needs are currently served by a 166-line `CustomPainter` that
  costs nothing, ships nothing, and is already correct in mechanism. Cap. 21 explicitly says preserve
  that engine and only recolour it. Replacing a working zero-dependency particle system with a
  JSON-asset pipeline would add weight and remove runtime colour control (a Lottie file's colours are
  baked at export; the confetti painter reads `AppColors` live).
- **REFERENCE — a real advantage worth noting.** Lottie files are cheap to *source* (LottieFiles has
  large libraries). **REJECT that specific path anyway:** a stock Lottie animation is the single
  fastest way to make Bufón look like every other app that used the same free file, which Cap. 0's
  recognisability test and Cap. 34's template rule both forbid.

**Verdict: REJECT for 1.1.** Weaker than Rive for interactivity, weaker than the existing painter for
colour control, and its cheap-asset advantage is a brand liability. Reconsider only for one-shot
reward flourishes in 1.2+, and only with bespoke files.

---

## Game / interaction

### 13. Flame
`pub.dev/packages/flame` · 1.38.0, published ~21 days ago · MIT

**REFERENCE (observed).** "A minimalist Flutter game engine": game loop, component system (FCS),
effects and particles, collision detection, gesture/input handling, sprites and sprite sheets. Six
platforms. Bridge packages exist for audio, physics (Forge2D), gamepads, Tiled, SVG, Lottie and Rive.

**Assessment for Bufón:**

- **INFERENCE — the category error to avoid.** Bufón is not a game in the sense Flame addresses. It
  has no simulation, no world, no per-frame physics, no sprites, no collision. It is a **realtime
  synchronised form**: text in, votes in, results out, all state authoritative in Firestore. Its
  visual layer is widgets, and correctly so.
- Flame *can* be embedded in a widget tree via `GameWidget`, so a hybrid is technically possible —
  e.g. a Flame-rendered confetti or particle layer behind the winner screen.
- **INFERENCE.** That hybrid would mean two rendering paradigms, two coordinate systems, two
  lifecycles and a whole engine in the binary, to replace a 166-line `CustomPainter` that already
  works. Flame's particle system is more capable; Bufón's needs (50 rounded rectangles falling with
  gravity, brand-coloured) are entirely met.
- **REFERENCE — one thing worth learning without adopting.** Flame's `EffectController` model
  (composable, sequenceable, repeatable effects with named curves) is a better abstraction than
  chaining `AnimationController`s by hand. It is conceptually adjacent to Bufón's `MotionDurations`
  tiers and to `flutter_animate`'s chaining. Reading it is useful; importing it is not.

**Verdict: REJECT.** Right tool, wrong product. Note it explicitly so that "Bufón is a game, so it
should use a game engine" never gets proposed as an argument again — the reasoning is about
simulation, not about the word "game".

---

### 14. Flame game samples / awesome-flame
`github.com/flame-engine/awesome-flame`

**REFERENCE (observed).** A curated index of Flame games by genre (casual, endless runner,
platformer, RPG, strategy, education), plus tutorials on the component system, collision, pause
menus/overlays, scoring, and audio, plus plugins (`bonfire` for RPGs, `leap` for platformers). One
tutorial series has a dedicated "polishing and optimizing" episode; the index itself does not
document particle or juice techniques in depth.

**Assessment for Bufón:**

- **INFERENCE.** The samples are all simulation games. The transferable knowledge — game feel, juice,
  screen shake, hit pause, easing on score counters — is real but generic craft knowledge, not
  Flame-specific, and Bufón already implements the applicable subset (press compression, pulse,
  staged reveal, confetti, escalating haptics).
- **One transferable idea worth naming:** *number tweening*. Games animate score counters rather than
  snapping them. Cap. 18 already requires this ("cada incremento anima el número con un `Settle`,
  nunca un salto instantáneo de texto") and Bufón does not do it anywhere — the answered-count, vote
  count, scores, and XP all snap. That is a small, high-polish win, achievable with
  `TweenAnimationBuilder<int>` and no dependency.

**Verdict: REFERENCE ONLY.**

---

## Flutter technical reference

### 15. flutter/samples
`github.com/flutter/samples` · Flutter team

**REFERENCE (observed).** Official sample collection. Relevant entries: `animations` (Flutter's
animation features), `material_3_demo` (Material 3 features in the Material library),
`dynamic_theme` (on-device APIs + Gemini output for dynamic styling), `platform_design` (maximising
code reuse while following distinct Android/iOS patterns), `desktop_photo_search`, `date_planner`.
The repository explicitly notes it is **not currently adding new samples** while reconsidering its
approach, though existing samples are maintained. It contains **no game samples**.

**Assessment for Bufón:**

- **REFERENCE.** `animations` is the canonical source for correct `AnimationController` lifecycle,
  `TickerProvider` usage, and staggered-animation structure. Bufón's six controllers are all correctly
  disposed, so it is confirmation rather than instruction — but it is the right place to check the
  reduce-motion pattern before implementing the `context.reduceMotion` helper.
- **REJECT `material_3_demo` as a design model.** It is a faithful demonstration of Material 3, which
  is what Cap. 34 tells Bufón not to look like. Its value is as a *reference for what the Material
  widgets do*, so that Bufón can override them knowingly.
- **INFERENCE — `platform_design` is a decision Bufón has implicitly already made and should record.**
  Bufón uses Material widgets on both platforms with no Cupertino adaptation (`cupertino_icons` is
  declared and never imported). That is the correct call for a brand-led game: a Bufón button should
  feel like Bufón on both platforms, not like iOS on iOS. Worth stating explicitly in the design
  system so nobody "fixes" it later by adding platform branching.

**Verdict: REFERENCE ONLY.**

---

## Consolidated verdicts

| # | Repository | Verdict | Action for 1.1 |
|---|---|---|---|
| 1 | Wonderous | **INSPIRE** | Bundle fonts; treat launch screen + texture as design surfaces; adopt the one-giant-element composition |
| 2 | AppFlowy | **REFERENCE ONLY** | AGPL — no reuse. Flags i18n as future work |
| 3 | LocalSend | **INSPIRE / partial REJECT** | `Hero` shared-element idea; **reject** `dynamic_color`/`yaru` |
| 4 | Lichess Mobile | **ADOPT (one package) / ADAPT** | **`wakelock_plus`** during game phases; hybrid custom-font + library icons; sound architecture model for 1.2 |
| 5 | Obtainium | **REFERENCE ONLY** | Negative control for "stock M3". `animations` rejected by Cap. 34 |
| 6 | Forui | **ADAPT (idea) / REJECT (dep)** | Steal per-component nested styling → `PhaseScope` |
| 7 | flutter-shadcn-ui | **REFERENCE ONLY** | Confirms ecosystem tool consensus; aesthetic wrong |
| 8 | Flutter UI Kit / GetWidget | **REJECT** | Solves breadth Bufón doesn't have; template look forbidden by Cap. 34 |
| 9 | Awesome Flutter | **REFERENCE ONLY** | Index; guard against dependency accretion |
| 10 | flutter_animate | **ADAPT for 1.1, revisit 1.2** | Build a ~40-line `Arrive` helper on existing tokens instead |
| 11 | rive | **REJECT for 1.1, candidate 1.2+** | Needs vector art + an authoring owner first |
| 12 | lottie | **REJECT** | Weaker interactivity than Rive, worse colour control than the existing painter |
| 13 | Flame | **REJECT** | Bufón is a synchronised form, not a simulation |
| 14 | Flame samples | **REFERENCE ONLY** | Take one idea: tween numeric counters |
| 15 | flutter/samples | **REFERENCE ONLY** | Use `animations` to verify the reduce-motion pattern |

### Packages actually recommended for adoption in 1.1

**Two, both small, both justified by something Bufón cannot do in ~100 lines of its own code:**

1. **`wakelock_plus`** — P1. The screen must not sleep during a 90-second answering phase while the
   phone sits on a table. Platform capability; not implementable in Dart. Evidence: Lichess Mobile
   ships it for the identical reason.
2. **`flutter_svg`** — P1, **conditional**. Only if the isotype ships as an SVG. If the isotype is
   instead reproduced as a `CustomPainter` (viable — it is flat, single-ink geometry), this dependency
   is unnecessary and should be skipped. Decide the asset format first, then the package. Evidence:
   Wonderous and shadcn_ui both ship it; it is the ecosystem default for vector assets.

**Explicitly not adopted:** `flutter_animate`, `rive`, `lottie`, `flame`, `forui`, `shadcn_ui`,
`getwidget`, `animations`, `dynamic_color`, `dynamic_system_colors`, `lucide_icons_flutter`,
`material_symbols_icons` (deferred to P2), `auto_size_text`, `flutter_native_splash`, `gap`,
`hsluv`, `sound_effect` (deferred to 1.2).

**INFERENCE.** Bufón's UI dependency footprint today is two packages, one of which (`cupertino_icons`)
is unused. Ending 1.1 with three or four is a deliberate, defensible position — and it means every
visual improvement in this blueprint is achievable almost entirely with code the project already owns.
