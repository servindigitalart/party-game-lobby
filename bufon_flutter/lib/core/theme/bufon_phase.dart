// core/theme/bufon_phase.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_theme.dart';

/// BUFÓN phase registers — implements BUFON_DESIGN_SYSTEM.md v1.1,
/// Capítulos 4 (uso emocional del color), 29 (modo oscuro), 30 (modo claro)
/// y 33 (cómo debe sentirse cada fase).
///
/// The design system is built on **per-phase colour registers**: Butter/Paper
/// at the thresholds (before and after playing), Graphite with one punctual
/// accent while playing. Material's `ThemeData` exposes exactly one
/// `ColorScheme`, so it cannot express that on its own — `app_theme.dart`
/// already documents this limitation and says phase accents "must stay
/// explicit widget-level colors applied screen by screen".
///
/// [PhaseScope] is that mechanism, named. Fase 3D discovered it empirically
/// (Home and Lobby each wrapped themselves in a bare
/// `Theme(data: AppTheme.lightTheme)`); this promotes the pattern to a single
/// widget that also carries the phase's accent down the tree, so a screen
/// declares its register once instead of repeating `.copyWith(color: …)` at
/// every call site.
enum BufonPhase {
  /// Paper + Butter. "Something good is about to happen" (Capítulo 33).
  home,

  /// Paper + Butter. "We're about to start something."
  lobby,

  /// Paper + Ink. "This is me, my history."
  profile,

  /// Paper with Sky/Lavender accents. "Where do I stand?"
  leaderboard,

  /// Graphite + Sky. "Just me and my wit against the clock."
  answering,

  /// Graphite + Lavender. "I'm judging in secret."
  voting,

  /// Graphite + Butter. "The curtain opens."
  reveal,

  /// Graphite + Mint. "Momentary victory."
  roundWinner,

  /// Ceremonial Butter/Graphite. "This is going to be a screenshot."
  nightWinner,

  /// Screens that have not migrated yet (Capítulo 35, Fase 3H+). They keep
  /// [AppTheme.legacyTheme] as an **explicit, documented opt-in** rather than
  /// inheriting it from `MaterialApp`, so no screen can end up on the legacy
  /// casino palette by accident. Delete this value once every screen below
  /// has a real register.
  legacy;

  bool get isDark => switch (this) {
    home || lobby || profile || leaderboard => false,
    answering || voting || reveal || roundWinner => true,
    // The ceremonial register is a Butter→Graphite gradient, so its own
    // surface is dark and its content reads as Paper on top of it.
    nightWinner => true,
    legacy => true,
  };

  /// The single protagonist accent of the phase (Capítulo 4: "un color
  /// emocional por pantalla como protagonista"). Never two per screen.
  Color get accent => switch (this) {
    home || lobby => AppColors.butter,
    profile => AppColors.ink,
    leaderboard => AppColors.sky,
    answering => AppColors.sky,
    voting => AppColors.lavender,
    reveal => AppColors.butter,
    roundWinner => AppColors.mint,
    nightWinner => AppColors.butter,
    legacy => AppColors.primary,
  };

  /// Foreground guaranteed to read on top of [accent]. Butter and Mint are
  /// pale enough that white fails the contrast check on them, which is why
  /// Capítulo 5 says text over Butter is always Ink, never white.
  Color get onAccent => switch (this) {
    home || lobby || reveal || nightWinner => AppColors.ink,
    roundWinner => AppColors.ink,
    profile => AppColors.paper,
    leaderboard || answering => AppColors.graphiteShade,
    voting => AppColors.graphiteShade,
    legacy => AppColors.textPrimary,
  };

  /// Body/primary text colour for the phase's own surface.
  Color get onSurface =>
      isDark ? AppColors.paper : AppColors.ink;

  /// Secondary text colour for the phase's own surface. On light surfaces
  /// this is [AppColors.inkMuted], not `inkSoft` — see the note on that
  /// token for the contrast measurement.
  Color get onSurfaceMuted => isDark
      ? AppColors.paper.withValues(alpha: 0.72)
      : AppColors.inkMuted;

  ThemeData get theme => switch (this) {
    legacy => AppTheme.legacyTheme,
    _ => isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
  };

  /// Status/navigation bar styling for the phase. Before this existed,
  /// `main.dart` set one global overlay style hardcoded to a `#111111`
  /// navigation bar with light icons, which contradicted the two screens
  /// that had already migrated to Paper.
  SystemUiOverlayStyle get overlayStyle {
    final surface = theme.colorScheme.surface;
    return isDark
        ? SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: surface,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: surface,
            systemNavigationBarIconBrightness: Brightness.dark,
          );
  }
}

/// Declares the phase register for a screen subtree.
///
/// Applies the phase's [ThemeData], its system overlay style, and makes the
/// phase itself available to descendants via [PhaseScope.of].
class PhaseScope extends StatelessWidget {
  final BufonPhase phase;
  final Widget child;

  const PhaseScope({super.key, required this.phase, required this.child});

  /// The nearest enclosing phase, or [BufonPhase.legacy] when a widget is
  /// used outside any scope (a bare widget test, for instance) so callers
  /// never have to null-check.
  static BufonPhase of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_PhaseScopeMarker>();
    return inherited?.phase ?? BufonPhase.legacy;
  }

  @override
  Widget build(BuildContext context) {
    return _PhaseScopeMarker(
      phase: phase,
      child: Theme(
        data: phase.theme,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: phase.overlayStyle,
          child: child,
        ),
      ),
    );
  }
}

class _PhaseScopeMarker extends InheritedWidget {
  final BufonPhase phase;

  const _PhaseScopeMarker({required this.phase, required super.child});

  @override
  bool updateShouldNotify(_PhaseScopeMarker oldWidget) =>
      oldWidget.phase != phase;
}

extension PhaseScopeContext on BuildContext {
  /// The active phase register.
  BufonPhase get phase => PhaseScope.of(this);

  /// The active phase's protagonist accent.
  Color get accent => PhaseScope.of(this).accent;
}
