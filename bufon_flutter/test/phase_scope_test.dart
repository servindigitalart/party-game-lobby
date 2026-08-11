import 'dart:io';

import 'package:bufon_flutter/core/theme/app_colors.dart';
import 'package:bufon_flutter/core/theme/app_theme.dart';
import 'package:bufon_flutter/core/theme/bufon_phase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP1 — chrome correctness.
///
/// Fase 2A made `AppTheme.lightTheme` the application theme. A pushed route
/// does **not** inherit the pushing screen's `Theme`, so any screen still
/// painting legacy dark surfaces resolved its app-bar title, back arrow,
/// action icons and unstyled `Text` against the *light* theme — Ink on
/// near-black, around 1.03:1. `BufonPhase.legacy` is the documented opt-in
/// that restores the theme those screens were authored against.
/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('legacy register restores legible chrome under a light app theme', () {
    testWidgets('app-bar title and icons resolve to the legacy foreground', (
      tester,
    ) async {
      late ThemeData resolved;

      await tester.pumpWidget(
        MaterialApp(
          // The Fase 2A condition that caused the regression.
          theme: AppTheme.lightTheme,
          home: PhaseScope(
            phase: BufonPhase.legacy,
            child: Builder(
              builder: (context) {
                resolved = Theme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolved.brightness, Brightness.dark);
      expect(resolved.appBarTheme.titleTextStyle?.color, AppColors.textPrimary);
      expect(resolved.appBarTheme.iconTheme?.color, AppColors.textPrimary);
      expect(resolved.iconTheme.color, AppColors.textPrimary);

      // The specific failure mode: Ink foreground on a dark surface.
      expect(resolved.appBarTheme.titleTextStyle?.color, isNot(AppColors.ink));
      expect(resolved.appBarTheme.iconTheme?.color, isNot(AppColors.ink));
    });

    testWidgets('unstyled body text does not inherit the light foreground', (
      tester,
    ) async {
      late ThemeData resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PhaseScope(
            phase: BufonPhase.legacy,
            child: Builder(
              builder: (context) {
                resolved = Theme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // `lightTheme` applies `bodyColor: scheme.onSurface` (Ink) to every
      // style; the legacy theme deliberately does not, so each keeps its own
      // light foreground (`textPrimary` for body1, `textSecondary` for body2).
      expect(resolved.textTheme.bodyLarge?.color, AppColors.textPrimary);
      expect(resolved.textTheme.bodyMedium?.color, AppColors.textSecondary);

      // The property that actually matters, and the one the regression
      // violated: body copy must clear WCAG AA against the surface it is
      // painted on. Ink on the legacy surface measured about 1.1:1.
      for (final style in [
        resolved.textTheme.bodyLarge,
        resolved.textTheme.bodyMedium,
        resolved.textTheme.headlineMedium,
      ]) {
        expect(style?.color, isNot(AppColors.ink));
        expect(
          _contrast(style!.color!, resolved.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
      }

      expect(
        _contrast(AppColors.ink, resolved.scaffoldBackgroundColor),
        lessThan(1.5),
        reason: 'sanity check: this is what the light theme was producing',
      );
    });
  });

  /// The invariant WP1 exists to establish. This is a source check on purpose:
  /// the failure it guards against is a *new screen shipping without a
  /// register*, which no behavioural test of the existing screens can catch.
  test('every reachable player-facing screen declares a phase register', () {
    final screenFiles = [
      ...Directory('lib/screens').listSync(),
      ...Directory('lib/presentation/screens').listSync(),
    ].whereType<File>().where((f) => f.path.endsWith('_screen.dart')).toList();

    expect(
      screenFiles,
      isNotEmpty,
      reason: 'screen directories moved — update this test',
    );

    final unscoped = screenFiles
        .where((f) => !f.readAsStringSync().contains('PhaseScope('))
        .map((f) => f.path)
        .toList();

    expect(
      unscoped,
      isEmpty,
      reason:
          'Every screen must declare a BufonPhase register. Screens still on '
          'the legacy palette use BufonPhase.legacy as an explicit, '
          'documented opt-in — never inherit a register by accident.',
    );
  });
}
