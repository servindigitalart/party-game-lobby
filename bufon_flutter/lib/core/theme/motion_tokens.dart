/// BUFÓN Motion tokens — implements BUFON_DESIGN_SYSTEM.md v1.1, Capítulos
/// 16 (Motion language) y 17 (Animation timing), y el capítulo `BRAND
/// PHYSICS`.
///
/// This file is infrastructure only — it defines the *values* that Motion
/// language names (Press, Pulse, Arrive, Reveal, Swap, Settle) resolve to.
/// No widget in this phase is rewired to use them yet (Fase 3B+ does that);
/// existing widgets keep their own inline `Duration`/`Curves` values
/// unchanged so nothing visibly changes in this phase. New motion code
/// should never write a raw `Duration(milliseconds: ...)` or reach for
/// `Curves.easeInOut` directly — it should reference one of these instead.
library;

import 'package:flutter/animation.dart';

/// Named durations. Values match what's already hand-coded across
/// `animated_primary_button.dart`, `game_card.dart`, `timer_widget.dart`,
/// `page_transitions.dart` and `round_result_screen.dart` — this doesn't
/// invent new numbers, it gives the numbers that already exist a name so
/// the next widget picks from a list instead of guessing.
class MotionDurations {
  MotionDurations._();

  // Named motion vocabulary (Capítulo 16). `press`/`settle` below are tier
  // defaults for components with no precedent to match. Fase 3B found that
  // the two existing components using each ended up hand-tuned to slightly
  // different concrete values (100ms vs. 150ms for press, 200ms vs. 300ms
  // for settle) — both still land inside the same tier (Capítulo 17), so
  // rather than force one number on both and change either widget's feel,
  // each keeps its own exact constant below.
  static const Duration press = Duration(milliseconds: 120);
  static const Duration pulse = Duration(milliseconds: 500);
  static const Duration arrive = Duration(milliseconds: 250);
  static const Duration swap = Duration(milliseconds: 250);
  static const Duration settle = Duration(milliseconds: 250);
  static const Duration revealStage = Duration(milliseconds: 800);
  static const Duration celebratory = Duration(milliseconds: 1600);

  // Exact per-component values (Fase 3B migration — do not round these
  // together, see note above).
  static const Duration pressButton = Duration(milliseconds: 100); // AnimatedPrimaryButton
  static const Duration pressCard = Duration(milliseconds: 150); // GameCard (press + confirm pulse share one controller)
  static const Duration settleButton = Duration(milliseconds: 200); // AnimatedPrimaryButton's AnimatedContainer
  static const Duration settleCard = Duration(milliseconds: 300); // GameCard's AnimatedContainer

  // Tier bounds (Capítulo 17) — for validating that a new animation falls
  // within a documented tier rather than inventing an arbitrary number.
  static const Duration microMin = Duration(milliseconds: 100);
  static const Duration microMax = Duration(milliseconds: 150);
  static const Duration standardMin = Duration(milliseconds: 200);
  static const Duration standardMax = Duration(milliseconds: 300);
  static const Duration dramaticMin = Duration(milliseconds: 600);
  static const Duration dramaticMax = Duration(milliseconds: 900);
  static const Duration celebratoryMin = Duration(milliseconds: 1200);
  static const Duration celebratoryMax = Duration(milliseconds: 2000);
}

/// Named curves. `compress`/`release` are the two curves `BRAND PHYSICS`
/// asks for: fast-in when something is touched (loading the spring),
/// slower-with-overshoot when it's released (the spring letting go).
class MotionCurves {
  MotionCurves._();

  /// Touching an element — compress fast into tension.
  static const Curve compress = Curves.easeIn;

  /// Releasing a confirmed action, or an element arriving already "sprung" —
  /// overshoots slightly past its resting value before settling.
  static const Curve release = Curves.easeOutBack;

  /// An element calling attention to itself without user interaction
  /// (Pulse) — symmetric, since nothing is being "loaded" or "released".
  static const Curve pulse = Curves.easeInOut;

  /// A narrative unveiling (Reveal) — decelerating, no overshoot. An
  /// opening is not a spring: [release]'s bounce-back belongs to touch
  /// feedback, and a mask that overshoots past fully-open then settles back
  /// would re-hide content it had already revealed. Added in Fase 2A when
  /// `KeyholeRevealTransition` was finally wired in and needed the curve the
  /// blueprint names for it ("`revealStage` 800 ms, `easeOut`, origin
  /// centre") — the six existing curves had no decelerate-only member.
  static const Curve reveal = Curves.easeOut;

  /// A value/text swap, or a container settling after a state change.
  static const Curve settle = Curves.easeInOut;
}

/// Scale factors. Two distinct press values are kept instead of unified
/// into one, because the two components that already use them
/// (`AnimatedPrimaryButton` at 0.95, `GameCard` at 0.97) were tuned
/// separately and unifying them now would be a silent behavior change to
/// widgets this phase must not touch.
class MotionScale {
  MotionScale._();

  static const double pressStrong = 0.95; // botones
  static const double pressSubtle = 0.97; // tarjetas
  static const double pulseSelect = 1.03; // GameCard al seleccionar
  static const double pulseUrgent = 1.10; // TimerWidget en peligro
  static const double celebrationOvershoot = 1.15; // el resorte más grande, solo Ganador
  static const double arriveFrom = 0.88; // punto de partida de un Arrive
}

// `MotionSprings` (two `SpringDescription` presets, `press` and `release`)
// lived here with zero call sites. Its own doc named the case it was for —
// "gesture-driven interactions (e.g. a draggable card) where the animation
// needs to react to velocity" — and Bufón has no such interaction anywhere:
// no `Draggable`, no `Dismissible`, no pan handler, no `SpringSimulation`.
// Every animation in the app is a declarative `Tween`+`Curve` over a known
// duration, which is the correct mechanism for motion that is not reacting to
// a finger. Adopting the springs would have meant inventing a gesture to
// justify them. Removed; re-add from this history if a draggable surface is
// ever designed, at which point the values are one commit away.

/// Standalone physical constants from `BRAND PHYSICS` that aren't a
/// duration, curve, scale factor or spring on their own, but govern how
/// those are combined.
class MotionPhysics {
  MotionPhysics._();

  /// Idle "breathing" amplitude for a Protagonist-layer element at rest
  /// (scale oscillates between 1.0 and 1.0 + this value). Ambient-layer
  /// elements never breathe.
  static const double breathingAmplitude = 0.008;
  static const Duration breathingPeriod = Duration(seconds: 4);

  /// How far past 1.0 a confirmed action is allowed to overshoot before
  /// settling, as a ratio — used together with [MotionCurves.release].
  static const double overshootRatio = 1.05;
}
