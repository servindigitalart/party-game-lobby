import 'dart:io';

import 'package:bufon_flutter/core/game_copy.dart';
import 'package:bufon_flutter/presentation/widgets/animated_primary_button.dart';
import 'package:bufon_flutter/presentation/widgets/brand_mark.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_loader.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP2 — one loading language, one empty/error language.
Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: MaterialApp(home: Scaffold(body: child)),
  ),
);

/// The loader's own breath, ignoring any ScaleTransition the surrounding
/// MaterialApp route contributes.
Finder _breathIn(Type widget) => find.descendant(
  of: find.byType(widget),
  matching: find.byType(ScaleTransition),
);

void main() {
  group('BufonLoader', () {
    testWidgets('renders the brand mark with its default configuration', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const BufonLoader()));
      await tester.pump();

      expect(find.byType(BufonLoader), findsOneWidget);
      expect(find.byType(BrandMark), findsOneWidget);

      // Drain the breath so the ticker does not outlive the test.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('breathes by default', (tester) async {
      await tester.pumpWidget(_host(const BufonLoader()));
      // Let MaterialApp's own route transition finish first — it contributes
      // its own ScaleTransition and its own frame callbacks.
      await tester.pump(const Duration(milliseconds: 500));

      expect(_breathIn(BufonLoader), findsOneWidget);
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'the breathing ticker should be running',
      );

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('respects reduced motion: static mark, no ticker', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const BufonLoader(), reduceMotion: true));
      await tester.pumpAndSettle();

      // Still communicates loading...
      expect(find.byType(BrandMark), findsOneWidget);
      // ...but nothing animates. `pumpAndSettle` returning at all is itself
      // part of the assertion: a breathing loader never settles.
      expect(_breathIn(BufonLoader), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('announces a single static loading label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const BufonLoader(), reduceMotion: true));
      await tester.pump();

      // 'Cargando', not BrandMark's own 'Bufón' — no double announcement.
      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
      expect(find.bySemanticsLabel('Bufón'), findsNothing);

      handle.dispose();
    });
  });

  group('BufonPlaceholder', () {
    testWidgets('renders the empty state with the brand mark', (tester) async {
      await tester.pumpWidget(
        _host(const BufonPlaceholder(title: 'Todavía no hay nada')),
      );

      expect(find.text('Todavía no hay nada'), findsOneWidget);
      expect(find.text(GameCopy.placeholderEmpty), findsOneWidget);
      // Capítulo 25: empty states carry the brand illustration.
      expect(find.byType(BrandMark), findsOneWidget);
    });

    testWidgets('renders the error state with a semantic icon, not the mark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BufonPlaceholder(
            variant: BufonPlaceholderVariant.error,
            title: 'No se pudo cargar',
          ),
        ),
      );

      expect(find.text('No se pudo cargar'), findsOneWidget);
      expect(find.text(GameCopy.placeholderError), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(BrandMark), findsNothing);
    });

    testWidgets('exposes an optional action and calls it', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        _host(
          BufonPlaceholder(
            variant: BufonPlaceholderVariant.error,
            title: 'No se pudo cargar',
            actionLabel: 'Reintentar',
            onAction: () => taps++,
          ),
        ),
      );

      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.byType(AnimatedPrimaryButton));
      await tester.pump(const Duration(milliseconds: 300));

      expect(taps, 1);
    });

    testWidgets('renders no action when only one half is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BufonPlaceholder(
            title: 'Sin acción',
            actionLabel: 'Reintentar',
          ),
        ),
      );

      // Capítulo 25 caps this at one action; a label with no callback is a
      // dead button, so neither is rendered.
      expect(find.byType(AnimatedPrimaryButton), findsNothing);
    });
  });

  /// The adoption invariant. WP2's value is not that the primitives exist —
  /// it is that the generic ones are gone from player-facing state.
  group('adoption', () {
    test('no player-facing screen uses a bare CircularProgressIndicator', () {
      final screens = [
        ...Directory('lib/screens').listSync(),
        ...Directory('lib/presentation/screens').listSync(),
      ].whereType<File>().where((f) => f.path.endsWith('_screen.dart'));

      final offenders = <String>[];
      for (final f in screens) {
        final src = f.readAsStringSync();
        if (!src.contains('CircularProgressIndicator')) continue;
        // The only permitted survivor is a spinner nested inside another
        // component that already communicates the state (a SnackBar).
        if (f.path.endsWith('profile_public_screen.dart') &&
            src.contains('SnackBar')) {
          continue;
        }
        offenders.add(f.path);
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Player-facing loading states use BufonLoader. A spinner inside a '
            'button or a SnackBar is part of that component, not a screen '
            'loading state.',
      );
    });

    test('no screen renders a raw exception to the player', () {
      final screens = [
        ...Directory('lib/screens').listSync(),
        ...Directory('lib/presentation/screens').listSync(),
      ].whereType<File>().where((f) => f.path.endsWith('_screen.dart'));

      final offenders = <String>[];
      for (final f in screens) {
        for (final line in f.readAsStringSync().split('\n')) {
          if (line.trimLeft().startsWith('//')) continue;
          if (RegExp(r"Text\(\s*'[^']*\$(e|error)\b").hasMatch(line) ||
              RegExp(r"_showError\(\s*'[^']*\$(e|error)\b").hasMatch(line)) {
            offenders.add('${f.path}: ${line.trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Capítulo 26: the technical detail goes to AppLogger/Crashlytics, '
            'never in front of a player.',
      );
    });
  });
}
