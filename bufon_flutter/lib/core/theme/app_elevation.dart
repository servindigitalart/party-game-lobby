// core/theme/app_elevation.dart

import 'package:flutter/material.dart';

/// BUFÓN "Capas de Foco" — implements BUFON_DESIGN_SYSTEM.md v1.1,
/// Capítulo 8.
///
/// This deliberately does *not* use Material's elevation model (a numeric
/// dp value implying a physical z-axis, with a grey/black shadow). The
/// design doc's v1.1 self-critique calls that out explicitly: the isotype
/// is completely flat, so a z-axis metaphor doesn't describe anything real
/// about Bufón — what actually needs describing is narrative focus (how
/// much attention an element commands), not physical height. Three layers,
/// not levels:
///
/// - [ambient]: the default for ~90% of components. No shadow — separation
///   comes from flat color contrast (Graphite vs. Graphite+1, Paper vs.
///   white) or a hairline border (`AppShapes.hairlineBorder`).
/// - [protagonistShadow]: the *one* focal element on a screen (Capítulo 3,
///   ley 4). Colored shadow, never grey/black — this already existed as an
///   unofficial pattern in `AnimatedPrimaryButton`'s pressed-state shadow;
///   this makes it the documented standard. At most one element per screen
///   should use this at a time.
/// - [ceremonialGradient]: reserved exclusively for the Ganador de la Noche
///   moment. The only place a gradient background is allowed by the design
///   system (Capítulo 3, ley 1) — it deliberately breaks the flat-color
///   rule because that moment earned it.
class AppElevation {
  AppElevation._();

  /// Ambient layer: no shadow. Exists as a named no-op so call sites can be
  /// explicit about the choice ("this is intentionally ambient") instead of
  /// silently omitting a decoration.
  static const List<BoxShadow> ambient = <BoxShadow>[];

  /// Protagonist layer: a soft shadow tinted with the element's own color,
  /// never a generic grey. Defaults corrected in Fase 3B to match the
  /// values actually already shipping in `AnimatedPrimaryButton` and
  /// `GameCard` (blurRadius 12, offset (0, 4), 30% opacity) — Fase 3A had
  /// written 16/(0, 6) from the doc's rounded spec before the exact
  /// existing numbers were checked against real code. Preserving the real
  /// numbers here means both widgets can adopt this helper with zero
  /// visual change.
  static List<BoxShadow> protagonistShadow(
    Color color, {
    double opacity = 0.3,
    double blurRadius = 12,
    Offset offset = const Offset(0, 4),
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blurRadius,
        offset: offset,
      ),
    ];
  }

  /// Ceremonial layer: full-screen gradient for the Ganador de la Noche
  /// moment only (Capítulo 8, capa 3). `colors` should be exactly two
  /// brand tones (e.g. Butter → Graphite, or Butter → Mint per the doc) —
  /// deliberately not exposed as a general-purpose gradient helper so it
  /// can't casually creep into a non-ceremonial screen.
  static LinearGradient ceremonialGradient(Color from, Color to) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [from, to],
    );
  }
}
