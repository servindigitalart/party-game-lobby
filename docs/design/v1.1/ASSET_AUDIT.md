# ASSET AUDIT — what exists, where it lives, whether it ships

> Verified by enumerating every binary asset in the repository and cross-referencing
> `bufon_flutter/pubspec.yaml`, the iOS/Android native asset catalogues, and every `Image`/
> `rootBundle` reference in `lib/`.
> **No asset was created, renamed, replaced or modified.**

---

## 1. The headline finding

**FACT.** `bufon_flutter/pubspec.yaml` declares exactly one asset:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/questions.json
```

**FACT.** There is no `fonts:` section. There are no images, no SVGs, no Lottie JSON, no `.riv`
files, no audio files anywhere in `bufon_flutter/assets/`. The directory contains one file.

**FACT.** Bufón's two brand marks — `BUFON-ISOTIPE.png` and `BUFON-LOGO.png`, committed in
`cea9947` — live in `/public/`, the leftover Create React App web root at the repository root. They
are **not** inside the Flutter package and **cannot** be referenced by it.

**INFERENCE.** Bufón ships a mobile app that contains zero pixels of its own brand. Every visual
identity decision documented across 710 lines of design system is currently carried entirely by
colour and layout, because the marks are physically absent from the binary.

---

## 2. Brand marks

### 2.1 `public/BUFON-ISOTIPE.png`

**FACT — described from the file itself.** A jester's head, solid near-black, on a flat butter-yellow
ground. Composition: a two-point jester hat whose tips terminate in filled circles, each circle
carrying a **keyhole cut-out** (a small circle over a tapered slot); below it a rounded-square face
with a single-tone fill, two closed eyes drawn as upward arcs, a solid round nose, a thick upward
smile arc, and two small rounded ear bumps. One ink, no gradients, no shadows, no texture, no
outline weight variation. Screen-print / high-contrast poster language.

**FACT.** ~1.02 MB PNG. Raster only — no SVG exists.

**FACT.** Referenced by: nothing. Zero uses in Flutter, zero in the React shell's `index.html`.

**INFERENCE.** The keyhole detail is the strongest narrative device the brand has — it says "this
holds a secret until it decides to reveal it", which is literally the game's mechanic. It is the
correct germ for the reveal transition, the loading state, the voting-phase visual language and the
app icon. Today it does none of those jobs because the file is unreachable.

### 2.2 `public/BUFON-LOGO.png`

**FACT — described from the file itself.** The wordmark **BUFON** in an ultra-bold geometric
display face with heavily rounded terminals, very high x-height, and tight tracking, where the "O"
is replaced by the isotype face (hat, keyhole bells, closed-arc eyes, nose, smile). Same near-black
ink on the same butter-yellow ground. The face reads as a letter, not as a logo placed beside a
word.

**FACT.** ~1.01 MB PNG. Raster only.

**FACT.** Referenced by: nothing.

**FACT — discrepancy worth recording.** The wordmark reads **BUFON** (no accent). The app title in
`main.dart` is `'BUFÓN'`, the Home headline is `'BUFÓN'`, and all copy uses the accent.

**INFERENCE.** Either the accent is dropped deliberately in the lockup (common, and defensible —
the accent would collide with the hat) or the mark predates the naming decision. This needs an
owner's call, not a designer's guess. It matters because it determines whether the wordmark asset
can ever be used in place of typed text.

**RECOMMENDATION.** Record the decision explicitly in `BUFON_DESIGN_SYSTEM.md` Cap. 2. If the
lockup is accent-less by design, then typed "BUFÓN" and the lockup are two distinct brand
expressions and should never appear on the same screen.

---

## 3. App icon and launch screen

**FACT — verified visually.** `bufon_flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/
Icon-App-1024x1024@1x.png` is the **stock Flutter logo** (the blue chevron "F" on white). All 13
iOS icon sizes and all 5 Android `mipmap-*/ic_launcher.png` densities are the default template set.

**FACT.** iOS launch: `LaunchScreen.storyboard` shows the default template `LaunchImage` (a 168×185
placeholder) centred on a **white** background.

**FACT.** Android launch: `launch_background.xml` is the untouched template — a single
`@android:color/white` layer with the bitmap block still commented out.

**FACT.** App names: `AndroidManifest.xml` line 7 → `android:label="bufon_flutter"`;
`Info.plist` → `CFBundleDisplayName` = `"Bufon Flutter"`, `CFBundleName` = `"bufon_flutter"`.
Android `applicationId` = `com.bufon.bufon_flutter`.

**INFERENCE — this is the single most damaging visual finding in the audit.** The first, most
frequent and most permanent brand impression a player has is the icon on their home screen and the
name under it. Today a Bufón player sees the Flutter logo labelled "bufon_flutter". Every hour spent
refining in-app hierarchy is downstream of that. A tester who installs the TestFlight build cannot
find the app by looking for it.

**RECOMMENDATION (P0, first commit of 1.1).**
- App icon: the isotype, Ink on Butter, full-bleed (no white padding). The mark is already
  square-safe and high-contrast — it needs no redesign, only export.
- Launch screen: flat Butter ground with the isotype centred, so the transition from splash to Home
  (which is already Paper/Butter) is continuous rather than a white flash into cream.
- Names: `android:label="Bufón"`, `CFBundleDisplayName="Bufón"`. Verify accent rendering on both
  launchers before committing.

---

## 4. Web shell assets (out of scope for the app, recorded for completeness)

**FACT.** `/public/` also contains `favicon.ico`, `logo192.png`, `logo512.png`, `manifest.json`,
`index.html`, `robots.txt` — all Create React App defaults — and `/src/` contains `logo.svg` (the
React atom logo) plus the CRA scaffold. The root `README.md` is still the unmodified
"Getting Started with Create React App" text.

**INFERENCE.** The React shell appears to be dead scaffolding retained because the brand PNGs were
dropped into it. It is not a design problem, but it is why the marks ended up outside the app.

**RECOMMENDATION.** Move the two brand PNGs into `bufon_flutter/assets/brand/` as part of 1.1, and
leave the CRA shell alone (deleting it is out of scope for a visual release and touches build
config).

---

## 5. What is doing the illustration work today

**FACT.** With zero image assets, all pictorial content in Bufón is one of three things:

### 5.1 Emoji (the dominant illustration medium)

| Use | Count / detail | Location |
|---|---|---|
| Player avatars | 12 emoji: `🤡 😊 😎 🥳 🤓 😈 ⭐ 🔥 🤖 👑 💎 🌙` | `models/avatar.dart` |
| Achievement icons | `🏆 🎮 ⭐ 👑 🔥` and others | `models/achievement.dart` |
| Title decoration | `👑 Campeón de Temporada` | `models/title.dart:303` |
| Winner screen headline | `🏆 BUFÓN DE LA NOCHE 🏆` | `final_winner_screen.dart:157` |
| Share victory card | `👑` 80pt, `❤️`, `🏆`, `🎭 … 🎭` | `share_victory_card.dart` |
| Share profile card | `🏆 … ❤️ … 🎮` stat line | `share_profile_card.dart:186` |
| Season countdown | `⏰` appended under 7 days | `season_countdown_banner.dart:112` |
| Share text | `¡Soy el Bufón de la Noche! 🏆` | `final_winner_screen.dart:346` |

**INFERENCE.** Emoji are rendered by the OS font, so a Bufón avatar is Apple's clown on iOS and
Google's clown on Android — two different faces for the same player identity, neither of them
Bufón's. Emoji are also the *one* graphic element the brand cannot control, at exactly the point
(avatar, winner) where control matters most. Cap. `FIRMA VISUAL` item 2 explicitly names "the
substitution of a circular form by a face" as a permanent brand device; emoji avatars are that
device outsourced to Unicode.

**RECOMMENDATION.** This is the biggest *new asset* opportunity in 1.1 — see §7.

### 5.2 Material icons

**FACT.** 37 distinct `Icons.*`, 8 of them outline variants. See `ICONOGRAPHY_AUDIT.md`.

### 5.3 Painted geometry

**FACT.** Three `CustomPainter`s draw all remaining graphics: `_CircularTimerPainter` (timer arc),
`_ConfettiPainter` in `confetti_widget.dart` (falling particles), `_ConfettiPainter` in
`share_victory_card.dart` (static decorative shapes). `share_profile_card.dart` additionally draws
its entire card with a raw `Canvas`.

**INFERENCE.** Painted geometry is the *most* on-brand medium currently available — it is
resolution-independent, colourable from tokens, and matches the isotype's flat-vector language.
It is under-used relative to emoji.

---

## 6. Data assets

**FACT.** `assets/questions.json` — 20 questions, 3 fields each (`id`, `text`, `pack`).

Pack distribution:

| Pack | Questions |
|---|---|
| `DI LA NETA` | 8 |
| `¿QUÉ PEDO?` | 6 |
| `ALGUIEN DE AQUÍ` | 6 |

**FACT.** `QuestionService.loadQuestions()` maps through `Question.fromJson`, and
`models/question.dart` (16 lines) does not carry a `pack` field. The pack names are parsed nowhere
and shown nowhere. `getRandomQuestion()` draws from the flat list.

**INFERENCE — significant identity finding.** Three named, tonally distinct, very Mexican question
packs already exist as content and are invisible as product. Named packs are the natural home for
**pack artwork**, which is the natural home for a second tier of brand illustration, which is the
natural anchor for a Home screen that currently has nothing to look at but a text field.

**RECOMMENDATION (P1, 1.1).** Surface packs as selectable, illustrated cards on Home/Lobby. This
single change:
- gives Home a visual protagonist that is not the wordmark,
- creates a legitimate use for new illustration assets built in the Cap. 13 style,
- gives the host a pre-game decision (raising perceived depth at zero backend cost),
- creates a monetisation surface that is not a paywall interstitial (locked packs read better than
  a blocked room),
- and gives 20 questions a reason to feel like a curated set rather than a thin list.

Note the content constraint honestly: **20 questions over 5 rounds is 4 games before repeats.** Pack
UI will make the shallowness of the library more visible, not less. Content expansion should ship
alongside the UI, not after it.

---

## 7. Asset gaps and what should fill them

| Gap | Consequence today | Proposed 1.1 asset | Priority |
|---|---|---|---|
| App icon | Flutter logo on the home screen | Isotype, Ink on Butter, full-bleed | **P0** |
| Launch screen | White flash → cream Home | Butter ground + centred isotype | **P0** |
| Isotype in-app (SVG) | No mark anywhere in the UI | `assets/brand/isotype.svg` + PNG fallback | **P0** |
| Bundled display font | Brand type is runtime-fetched | `assets/fonts/*.ttf` for the Display + Body faces | **P0** |
| Wordmark in-app | Home headline is typed text | `assets/brand/wordmark.svg` for Home + share cards | P1 |
| Avatar art | OS emoji; 2 different faces per player | 12 flat vector faces built on the isotype grid (closed-arc eyes, round nose, thick smile — Cap. `FIRMA VISUAL` 2 & 3) | P1 |
| Pack artwork | Packs invisible | 3 flat 2-colour pack marks | P1 |
| Empty/error illustrations | 64 px Material icons | 3–4 isotype-relatives (empty leaderboard, no titles, offline, error) | P1 |
| Loading mark | Bare `CircularProgressIndicator` ×11 | Breathing isotype (Cap. 24) — can be pure code once the SVG exists | P1 |
| Sound assets | 2 OS system sounds for 5 semantic events | cardstock / wood / stamp / bell set (Cap. 20) | P2 |
| Share-card chassis art | Casino gold/red | Butter ground + corner isotype (Cap. 31) | P1 |
| Achievement/title art | Emoji | Reuse the avatar face grid + rarity ring | P2 |
| Texture | None | Optional subtle paper grain on Paper surfaces only | P3 |

---

## 8. Format recommendations

**RECOMMENDATION.** Ship the brand marks as **SVG**, not the existing 1 MB PNGs.

Reasoning, evidence-based rather than preferential:
- The isotype is flat, single-ink, gradient-free geometry — the exact case where SVG is smaller and
  sharper at every size. 1 MB × 2 raster files would be ~2 MB of a party-game binary for two logos.
- The mark must be **recolourable at runtime**: Ink-on-Butter on Home, Paper-on-Graphite during
  play, Butter-on-Graphite on the winner screen. A PNG cannot do that; an SVG with a
  `colorFilter` can.
- The mark must animate (breathing loader, keyhole reveal, winner stamp). Vector paths are
  animatable; a flattened bitmap is not.

**Dependency implication.** Flutter cannot render SVG without a package. `flutter_svg` is the
standard choice (**REFERENCE:** Wonderous ships `flutter_svg`; shadcn_ui depends on it). This is one
of only two new dependencies this blueprint recommends — see `REPOSITORY_RESEARCH.md` §Verdicts.

**Alternative that adds no dependency (INFERENCE).** Because the isotype is pure geometry, it can be
reproduced as a `CustomPainter` with hand-authored `Path` data. That gives runtime colour, free
animation and zero package weight, at the cost of one non-trivial file and a manual re-trace if the
mark ever changes. For an app whose logo is this simple and this stable, this is a genuinely
competitive option and should be evaluated before adding `flutter_svg`.

---

## 9. Assets that must not change

1. **The isotype's geometry.** Closed-arc eyes, round nose, thick smile, ear bumps, two-point hat,
   keyhole bells. `FIRMA VISUAL` items 2–4 make these permanent. Re-export, re-colour, re-vector —
   never redraw.
2. **The "O is the face" lockup device.** It is the strongest idea in the identity and it should
   constrain the Display typeface choice, not be constrained by it.
3. **Butter `#F8EE67` + Ink `#191919` at maximum contrast.** `FIRMA VISUAL` item 1.
4. **`questions.json` content and pack names.** They carry the voice; the voice is working.
