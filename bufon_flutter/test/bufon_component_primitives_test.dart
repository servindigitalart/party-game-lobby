import 'dart:io';

import 'package:bufon_flutter/core/theme/app_colors.dart';
import 'package:bufon_flutter/core/theme/bufon_phase.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_feedback.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_player_row.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_status_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP8 — one feedback language, one status language, one player row.
///
/// These assert rendered behaviour, never the presence of a string in a source
/// file, except in the closing `adoption` group where the whole point is that
/// the hand-rolled versions are gone.

/// Hosts [child] under a register, below the root `ScaffoldMessenger` that
/// `MaterialApp` creates — the same relationship production has, and the one
/// that makes `BufonFeedback`'s eager resolution load-bearing.
Widget _host(Widget child, {BufonPhase phase = BufonPhase.answering}) =>
    MaterialApp(
      home: PhaseScope(
        phase: phase,
        child: Scaffold(body: Center(child: child)),
      ),
    );

/// Raises feedback from inside the register and returns the built `SnackBar`.
Future<SnackBar> _raise(
  WidgetTester tester, {
  required String message,
  BufonFeedbackTone? tone,
  BufonPhase phase = BufonPhase.answering,
}) async {
  // A fresh key remounts the whole app, and with it the root
  // ScaffoldMessenger: a messenger queues snackbars, so without this a second
  // `show` in the same test would still be reading the first one.
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: PhaseScope(
        phase: phase,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => tone == null
                  ? BufonFeedback.show(context, message)
                  : BufonFeedback.show(context, message, tone: tone),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  return tester.widget<SnackBar>(find.byType(SnackBar));
}

/// WCAG relative-contrast ratio between two opaque colours. Same formula the
/// chrome tests use in `phase_scope_test.dart`.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color? _barColor(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .valueColor!
    .value;

BoxDecoration _panelDecoration(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(
                of: find.byType(BufonStatusPanel),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  group('BufonFeedback', () {
    testWidgets('success and error are two distinct, tone-owned fills', (
      tester,
    ) async {
      final ok = await _raise(
        tester,
        message: 'Respuesta enviada',
        tone: BufonFeedbackTone.success,
      );
      expect(ok.backgroundColor, AppColors.mintShade);
      expect(find.text('Respuesta enviada'), findsOneWidget);

      final bad = await _raise(
        tester,
        message: 'Algo se atoró',
        tone: BufonFeedbackTone.error,
      );
      expect(bad.backgroundColor, AppColors.coralShade);
      expect(find.text('Algo se atoró'), findsOneWidget);

      expect(ok.backgroundColor, isNot(bad.backgroundColor));
    });

    testWidgets('error is the default tone', (tester) async {
      final snack = await _raise(tester, message: 'No encontramos esa sala.');
      expect(snack.backgroundColor, AppColors.coralShade);
    });

    testWidgets('the tone resolves from the caller, not from the messenger', (
      tester,
    ) async {
      // The root ScaffoldMessenger lives above every PhaseScope, so a SnackBar
      // builds under the app's own theme rather than the calling screen's. If
      // any part of the presentation were deferred instead of resolved eagerly
      // in `show`, these three would not agree.
      final fills = <Color?>[];
      for (final phase in [
        BufonPhase.answering,
        BufonPhase.voting,
        BufonPhase.legacy,
      ]) {
        final snack = await _raise(
          tester,
          message: 'Mismo tono',
          tone: BufonFeedbackTone.error,
          phase: phase,
        );
        fills.add(snack.backgroundColor);
      }
      expect(fills, everyElement(AppColors.coralShade));
    });

    testWidgets('the content colour clears the body-text contrast floor', (
      tester,
    ) async {
      // Every hand-built snackbar left the foreground to the root theme's
      // `contentTextStyle` (Paper), which measures ≈3.3:1 on both fills. The
      // primitive states the foreground itself; this is the reason why.
      for (final tone in BufonFeedbackTone.values) {
        final snack = await _raise(tester, message: 'Contraste', tone: tone);
        final text = tester.widget<Text>(find.text('Contraste'));

        expect(
          text.style?.color,
          isNotNull,
          reason:
              '$tone leaves the '
              'foreground to the ambient theme',
        );
        expect(
          _contrast(text.style!.color!, snack.backgroundColor!),
          greaterThanOrEqualTo(4.5),
          reason: '$tone body text must clear 4.5:1',
        );
      }
    });

    testWidgets('a confirmation clears itself; a failure stays put', (
      tester,
    ) async {
      await _raise(
        tester,
        message: 'Respuesta enviada',
        tone: BufonFeedbackTone.success,
      );
      // Let the entrance land first — the messenger only starts the display
      // timer once the snackbar has finished animating in.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.text('Respuesta enviada'), findsNothing);

      await _raise(
        tester,
        message: 'Algo se atoró',
        tone: BufonFeedbackTone.error,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      // Four seconds, not one: a failure has to outlast a glance.
      expect(find.text('Algo se atoró'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('exposes no action — this is not a notification framework', (
      tester,
    ) async {
      final snack = await _raise(tester, message: 'Sin acción');
      expect(snack.action, isNull);
      expect(find.byType(SnackBarAction), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('BufonStatusPanel', () {
    testWidgets('renders its message and, without progress, no bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const BufonStatusPanel(message: 'Faltan 2 bufones.')),
      );

      expect(find.text('Faltan 2 bufones.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders a determinate bar when progress is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const BufonStatusPanel(message: 'Mitad', progress: 0.5)),
      );

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
    });

    testWidgets('the headline is optional and its glyph follows the tone', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const BufonStatusPanel(message: 'Sin encabezado')),
      );
      expect(find.byIcon(Icons.touch_app), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      await tester.pumpWidget(
        _host(
          const BufonStatusPanel(
            message: 'Faltan votos',
            headline: 'Toca una respuesta para votar',
          ),
        ),
      );
      expect(find.text('Toca una respuesta para votar'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const BufonStatusPanel(
            message: 'Faltan votos',
            headline: '¡Voto enviado!',
            tone: BufonStatusTone.confirmed,
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.touch_app), findsNothing);
    });

    testWidgets('pending takes the register accent; confirmed takes Mint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BufonStatusPanel(message: 'Votando', progress: 0.4),
          phase: BufonPhase.voting,
        ),
      );
      expect(_barColor(tester), BufonPhase.voting.accent);
      expect(_panelDecoration(tester).color, AppColors.graphitePlus1);

      await tester.pumpWidget(
        _host(
          const BufonStatusPanel(message: 'Respondiendo', progress: 0.4),
          phase: BufonPhase.answering,
        ),
      );
      // Same widget, same tone, different register — the accent follows the
      // screen rather than the call site.
      expect(_barColor(tester), BufonPhase.answering.accent);

      await tester.pumpWidget(
        _host(
          const BufonStatusPanel(
            message: 'Votando',
            progress: 0.4,
            tone: BufonStatusTone.confirmed,
          ),
          phase: BufonPhase.voting,
        ),
      );
      // A confirmation is Mint on every register, exactly as it is in
      // BufonFeedback — it is not the phase's colour to choose.
      expect(_barColor(tester), AppColors.mint);
      expect(
        _panelDecoration(tester).color,
        isNot(AppColors.graphitePlus1),
        reason: 'the confirmed panel is tinted, not neutral',
      );
    });

    testWidgets('announces once as one node, live only when resolved', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          const BufonStatusPanel(
            message: 'Faltan 2 votos',
            progress: 0.4,
            headline: 'Toca una respuesta para votar',
            statusLabel: 'Toca una respuesta para votar',
          ),
        ),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Toca una respuesta para votar'),
        ),
        containsSemantics(isLiveRegion: false),
      );
      // The caption and the bar are folded into that one node, not announced
      // as unrelated fragments beside it.
      expect(find.bySemanticsLabel('Faltan 2 votos'), findsNothing);

      await tester.pumpWidget(
        _host(
          const BufonStatusPanel(
            message: 'Votos cerrados',
            progress: 1,
            headline: '¡Voto enviado!',
            statusLabel: '¡Voto enviado!',
            tone: BufonStatusTone.confirmed,
            live: true,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('¡Voto enviado!')),
        containsSemantics(label: '¡Voto enviado!', isLiveRegion: true),
      );

      handle.dispose();
    });
  });

  group('BufonPlayerRow', () {
    testWidgets('renders standing, name, detail and trailing figure', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BufonPlayerRow(
            position: 1,
            name: 'Sofía',
            detail: '3 votos esta ronda',
            trailingLabel: '30 pts',
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Sofía'), findsOneWidget);
      expect(find.text('3 votos esta ronda'), findsOneWidget);
      expect(find.text('30 pts'), findsOneWidget);
    });

    testWidgets('detail and trailing figure are both optional', (tester) async {
      await tester.pumpWidget(
        _host(const BufonPlayerRow(position: 4, name: 'Bruno')),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.subtitle, isNull);
      expect(tile.trailing, isNull);
      expect(find.text('Bruno'), findsOneWidget);
    });

    testWidgets(
      'only the highlighted row is tinted, with the register accent',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const BufonPlayerRow(position: 2, name: 'Bruno'),
            phase: BufonPhase.roundWinner,
          ),
        );
        // `null` falls through to cardTheme — the row does not paint itself.
        expect(tester.widget<Card>(find.byType(Card)).color, isNull);

        await tester.pumpWidget(
          _host(
            const BufonPlayerRow(position: 1, name: 'Sofía', highlighted: true),
            phase: BufonPhase.roundWinner,
          ),
        );
        expect(
          tester.widget<Card>(find.byType(Card)).color,
          BufonPhase.roundWinner.accent.withValues(alpha: 0.16),
        );
      },
    );

    testWidgets('announces the whole row as one sentence', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          const BufonPlayerRow(
            position: 1,
            name: 'Sofía',
            detail: '3 votos esta ronda',
            trailingLabel: '30 pts',
          ),
        ),
      );

      // Not a bare '1', a name and an unrelated '30 pts' with nothing
      // relating them.
      expect(
        find.bySemanticsLabel('Puesto 1, Sofía, 3 votos esta ronda, 30 pts'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Sofía'), findsNothing);

      handle.dispose();
    });
  });

  /// The adoption invariant, in the shape WP2 established: the value is not
  /// that the primitives exist, it is that the hand-rolled versions are gone
  /// from the surfaces WP8 claims.
  group('adoption', () {
    String read(String path) => File(path).readAsStringSync();

    // WP8 migrated the answering screen, WP10 voting, WP11 Home and Lobby.
    //
    // Two groups are deliberately outside this list. The five screens still on
    // `BufonPhase.legacy` move with the package that recolours them. Final
    // Winner is the other: it carries a real register and its one snackbar is
    // compatible, but its share-failure path sits behind the ceremony's staged
    // entrance and cannot be driven under the widget-test binding without
    // altering staging WP7 owns. It keeps its own snackbar until that path can
    // be covered on its own terms — asserting adoption there would be claiming
    // something no test checks.
    test('every adopted screen builds no SnackBar of its own', () {
      for (final path in [
        'lib/screens/game_screen.dart',
        'lib/screens/voting_screen.dart',
        'lib/screens/home_screen.dart',
        'lib/screens/lobby_screen.dart',
      ]) {
        expect(read(path), isNot(contains('SnackBar')), reason: path);
        expect(read(path), isNot(contains('ScaffoldMessenger')), reason: path);
      }
    });

    test('both loop screens take their progress panel from the primitive', () {
      for (final path in [
        'lib/screens/game_screen.dart',
        'lib/screens/voting_screen.dart',
      ]) {
        final src = read(path);
        expect(src, contains('BufonStatusPanel('), reason: path);
        expect(
          src,
          isNot(contains('LinearProgressIndicator')),
          reason: '$path hand-rolls a progress bar the panel already owns',
        );
      }
    });

    test('the night scoreboard takes its rows from the primitive', () {
      final src = read('lib/screens/round_result_screen.dart');
      expect(src, contains('BufonPlayerRow('));
      expect(src, isNot(contains('CircleAvatar')));
    });
  });
}
