import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/screens/round_result_screen.dart';
import 'package:bufon_flutter/screens/voting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP5 — the two loop screens under large text.
///
/// WP4 shipped the global band `MediaQuery.withClampedTextScaling(1.0, 1.4)`
/// but left Voting and Round Result overflowing at the top of it: both compose
/// a text-scale-sensitive block in a `Column` that also holds a tight flex
/// child (`Expanded`/`Spacer`), so as the block grows `freeSpace` goes negative
/// and `RenderFlex` overflows.
///
/// These tests fail on the pre-WP5 layout and pass after it. They assert the
/// *absence of a layout exception*, never the presence of one — encoding the
/// overflow as expected would freeze the bug.
///
/// Scales are applied directly rather than through `MyApp`: the production band
/// clamps to 1.4, so 1.0/1.2/1.4 are exactly the effective values a device can
/// produce. There is no point testing 3.0 — the app never renders it.

/// Every framework error recorded while [body] runs, not just the first.
/// `takeException` yields one at a time and a single frame can record several.
Future<List<Object>> collectErrors(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final errors = <Object>[];
  await body();
  while (true) {
    final e = tester.takeException();
    if (e == null) break;
    errors.add(e);
  }
  return errors;
}

Matcher get hasNoLayoutOverflow => predicate<List<Object>>(
  (errors) =>
      errors.every((e) => !e.toString().toLowerCase().contains('overflow')),
  'no RenderFlex overflow',
);

void useViewport(WidgetTester tester, Size logical) {
  final view = tester.view;
  view.physicalSize = logical * 3.0;
  view.devicePixelRatio = 3.0;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}

/// A deliberately demanding but realistic round: eight players, the maximum the
/// lobby allows, with answers at the 100-character cap the game enforces.
const _longAnswer =
    'Le dije a mi jefe que el reporte estaba listo y luego fingí que se cayó '
    'el internet toda la tarde';

/// A brief round, for the assertions that need everything above the fold.
const _shortAnswer = 'Se cayó el internet';

Room votingRoom({
  required bool currentUserHasVoted,
  int players = 8,
  bool brief = false,
}) {
  String answer(int i) => brief ? '$_shortAnswer $i' : '$_longAnswer $i';
  return Room(
    code: 'ABCD12',
    hostId: 'host-1',
    phase: GamePhase.voting,
    currentRound: 3,
    totalRounds: 5,
    currentQuestionText: brief
        ? '¿La peor excusa?'
        : '¿Cuál es la peor excusa que has usado para salirte de una '
              'responsabilidad?',
    players: [
      Player(
        id: 'host-1',
        name: 'Sofía',
        score: 12,
        currentAnswer: answer(1),
        votedFor: currentUserHasVoted ? 'p2' : null,
      ),
      for (var i = 2; i <= players; i++)
        Player(
          id: 'p$i',
          name: 'Jugador $i',
          score: 10 - i,
          currentAnswer: answer(i),
        ),
    ],
  );
}

Room revealRoom({int players = 8, bool brief = false}) {
  String answer(int i) => brief ? '$_shortAnswer $i' : '$_longAnswer $i';
  return Room(
    code: 'ABCD12',
    hostId: 'host-1',
    phase: GamePhase.roundResult,
    currentRound: 3,
    totalRounds: 5,
    players: [
      Player(id: 'host-1', name: 'Sofía', score: 30, currentAnswer: answer(1)),
      for (var i = 2; i <= players; i++)
        Player(
          id: 'p$i',
          name: 'Jugador $i',
          score: 20 - i,
          currentAnswer: answer(i),
          votedFor: 'host-1',
        ),
    ],
  );
}

/// Driven as a non-host: the host's device schedules the automatic advance,
/// which reaches the room repository and therefore Firebase. Layout is
/// identical for every player.
Widget harness(Room room, Widget screen, {String asUserId = 'p2'}) =>
    ProviderScope(
      overrides: [
        roomStreamProvider.overrideWith((ref) => Stream.value(room)),
        userIdProvider.overrideWith((ref) => asUserId),
      ],
      child: MaterialApp(home: screen),
    );

void main() {
  const viewports = <String, Size>{
    '360x800': Size(360, 800),
    '390x844': Size(390, 844),
  };
  const scales = <double>[1.0, 1.2, 1.4];

  for (final viewport in viewports.entries) {
    for (final scale in scales) {
      final label = '${viewport.key} @ ${scale}x';

      testWidgets('Voting does not overflow — $label', (tester) async {
        useViewport(tester, viewport.value);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final errors = await collectErrors(tester, () async {
          await tester.pumpWidget(
            harness(
              votingRoom(currentUserHasVoted: false),
              const VotingScreen(),
            ),
          );
          await tester.pump();
          // Clear the answer cards' staggered entrance.
          await tester.pump(const Duration(milliseconds: 800));
        });

        expect(errors, hasNoLayoutOverflow, reason: errors.join('\n'));
      });

      testWidgets('Voting after voting does not overflow — $label', (
        tester,
      ) async {
        useViewport(tester, viewport.value);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final errors = await collectErrors(tester, () async {
          await tester.pumpWidget(
            harness(
              votingRoom(currentUserHasVoted: true),
              const VotingScreen(),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 800));
        });

        expect(errors, hasNoLayoutOverflow, reason: errors.join('\n'));
      });

      testWidgets(
        'Round Result does not overflow through the reveal — $label',
        (tester) async {
          useViewport(tester, viewport.value);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final errors = await collectErrors(tester, () async {
            await tester.pumpWidget(
              harness(revealRoom(), const RoundResultScreen()),
            );
            await tester.pump();
            // Stage 0 → 1 (750 ms) → 2 (1550 ms), then drain the animations.
            // Every stage changes the composition, so every stage is measured.
            await tester.pump(const Duration(milliseconds: 800));
            await tester.pump(const Duration(milliseconds: 800));
            await tester.pump(const Duration(seconds: 2));
          });

          expect(errors, hasNoLayoutOverflow, reason: errors.join('\n'));
        },
      );
    }
  }

  group('the chrome outside the scroll view stays pinned', () {
    // The whole point of putting the scroll boundary around the content rather
    // than around the screen: the status block and the CTA are chrome, and
    // must stay on screen at every scale however tall the content grows.
    //
    // What is deliberately *not* asserted here: "the screen does not scroll at
    // all when the content is short". `flutter_test`'s font makes every glyph
    // one em wide, so even a three-player round with brief answers already
    // exceeds the content region at 1.0x (measured: 67 px). That number
    // describes the test font, not the layout, so asserting a zero scroll
    // extent would measure the harness rather than the fix. The pinning
    // assertions below hold whatever the font metrics are.
    for (final scale in <double>[1.0, 1.4]) {
      testWidgets('Voting status block stays on screen at ${scale}x', (
        tester,
      ) async {
        useViewport(tester, const Size(360, 800));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          harness(
            votingRoom(currentUserHasVoted: true),
            const VotingScreen(),
            asUserId: 'host-1',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        final status = find.text('¡Voto enviado!');
        expect(status, findsOneWidget);
        final rect = tester.getRect(status);
        expect(rect.top, greaterThanOrEqualTo(0.0));
        expect(rect.bottom, lessThanOrEqualTo(800.0));
      });

      testWidgets('Round Result CTA stays on screen at ${scale}x', (
        tester,
      ) async {
        useViewport(tester, const Size(360, 800));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          harness(revealRoom(), const RoundResultScreen(), asUserId: 'host-1'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump(const Duration(seconds: 2));

        final cta = find.text('Soltar la siguiente');
        expect(cta, findsOneWidget);
        final rect = tester.getRect(cta);
        expect(rect.top, greaterThanOrEqualTo(0.0));
        expect(rect.bottom, lessThanOrEqualTo(800.0));
      });
    }

    testWidgets('Voting does become scrollable when the content is long', (
      tester,
    ) async {
      // The escape valve genuinely engages rather than the content being
      // silently clipped: at 1.4x with a full room there is real scroll extent.
      useViewport(tester, const Size(360, 800));
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        harness(votingRoom(currentUserHasVoted: false), const VotingScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, greaterThan(0.0));
    });
  });

  group('WP4 semantics survive the new scroll boundary', () {
    testWidgets('Voting keeps its heading and its tappable answers', (
      tester,
    ) async {
      useViewport(tester, const Size(360, 800));
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        harness(
          votingRoom(currentUserHasVoted: false, players: 3, brief: true),
          const VotingScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Heading — moved inside the scroll view by this WP.
      expect(
        tester.getSemantics(find.text('¿Cuál es la respuesta más chistosa?')),
        containsSemantics(isHeader: true),
      );

      // An answer card crossed the boundary and must keep its action. Card 1
      // belongs to another player, so it is votable for the current user.
      expect(
        tester.getSemantics(find.bySemanticsLabel('$_shortAnswer 1')),
        containsSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );

      handle.dispose();
    });

    testWidgets('Voting keeps its vote-confirmation live region', (
      tester,
    ) async {
      useViewport(tester, const Size(360, 800));
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        harness(
          votingRoom(currentUserHasVoted: true, players: 3, brief: true),
          const VotingScreen(),
          // `currentUserHasVoted` marks host-1's vote, so the screen has to be
          // driven as host-1 for `hasVoted` to be true.
          asUserId: 'host-1',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Deliberately left outside the scroll view: a confirmation that can
      // scroll out of view is not a confirmation.
      expect(
        tester.getSemantics(find.bySemanticsLabel('¡Voto enviado!')),
        containsSemantics(isLiveRegion: true),
      );

      handle.dispose();
    });

    testWidgets('Round Result keeps its winner live region and header', (
      tester,
    ) async {
      useViewport(tester, const Size(360, 800));
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        harness(revealRoom(players: 3, brief: true), const RoundResultScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Sofía, 2 votos recibidos')),
        containsSemantics(isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.text('Marcador de la noche')),
        containsSemantics(isHeader: true),
      );

      handle.dispose();
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('the 1.0x composition is preserved', () {
    testWidgets('Voting keeps its status footer and pinned CTA on screen', (
      tester,
    ) async {
      useViewport(tester, const Size(360, 800));

      await tester.pumpWidget(
        harness(
          votingRoom(currentUserHasVoted: true),
          const VotingScreen(),
          asUserId: 'host-1',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // The status block is chrome, not scrollable content: it must stay
      // within the viewport without the user scrolling.
      final status = find.text('¡Voto enviado!');
      expect(status, findsOneWidget);
      expect(tester.getRect(status).bottom, lessThanOrEqualTo(800.0));

      // Nothing was pushed off the top either.
      expect(tester.getRect(status).top, greaterThanOrEqualTo(0.0));
    });

    testWidgets('Round Result keeps the host CTA pinned at the bottom', (
      tester,
    ) async {
      useViewport(tester, const Size(360, 800));

      await tester.pumpWidget(
        harness(revealRoom(), const RoundResultScreen(), asUserId: 'host-1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(seconds: 2));

      final cta = find.text('Soltar la siguiente');
      expect(cta, findsOneWidget);

      final rect = tester.getRect(cta);
      expect(rect.bottom, lessThanOrEqualTo(800.0));
      // Pinned low: the Spacer/Expanded contract put it at the bottom of the
      // screen, and that must survive the restructure.
      expect(rect.top, greaterThan(600.0));
    });

    testWidgets('Round Result still gates the scoreboard until stage 2', (
      tester,
    ) async {
      useViewport(tester, const Size(360, 800));

      await tester.pumpWidget(harness(revealRoom(), const RoundResultScreen()));
      await tester.pump();

      // The reveal contract from WP3 must not be a casualty of the layout
      // change: the scoreboard names the winner, so it stays unbuilt.
      expect(find.text('Marcador de la noche'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('Marcador de la noche'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });
  });
}
