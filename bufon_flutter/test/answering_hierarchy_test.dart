// test/answering_hierarchy_test.dart

import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_status_panel.dart';
import 'package:bufon_flutter/presentation/widgets/game_progress_widgets.dart';
import 'package:bufon_flutter/presentation/widgets/timer_widget.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP15 — G13 on the answering screen: one protagonist for progress.
///
/// The screen used to state the round twice. `RoundIndicator` in the app bar
/// renders "Ronda 3/5"; `GameProgressBar`, about a hundred pixels below it,
/// rendered the same `currentRound / totalRounds` again as five segments plus
/// "Ronda 3 de 5" plus "60%". Two readouts, one fact.
///
/// Worth being exact about which two signals collided, because it is not the
/// pairing the package assumed: `TimerWidget` reads
/// `remainingSeconds / totalSeconds` and `BufonStatusPanel` reads
/// `answeredCount / players.length`. Neither restates the round, and neither
/// restates the other — so both stay. Only the second round readout goes.
void main() {
  Room answeringRoom({
    bool allAnswered = false,
    bool currentUserAnswered = false,
  }) => Room(
    code: 'ABCD12',
    hostId: 'host-1',
    phase: GamePhase.answering,
    currentRound: 3,
    totalRounds: 5,
    currentQuestionId: 'q1',
    currentQuestionText: '¿Cuál es el peor consejo que has recibido?',
    roundDuration: 90,
    players: [
      Player(
        id: 'host-1',
        name: 'Sofía',
        score: 0,
        currentAnswer: currentUserAnswered || allAnswered ? 'Algo' : null,
      ),
      Player(
        id: 'p2',
        name: 'Bruno',
        score: 0,
        currentAnswer: allAnswered ? 'Otra cosa' : null,
      ),
    ],
  );

  Widget harness(Room room) => ProviderScope(
    overrides: [
      roomStreamProvider.overrideWith((ref) => Stream.value(room)),
      userIdProvider.overrideWith((ref) => 'host-1'),
    ],
    child: const MaterialApp(home: GameScreen()),
  );

  Future<void> pumpAnswering(WidgetTester tester, Room room) async {
    await tester.pumpWidget(harness(room));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('the round is stated once, by the app bar', (tester) async {
    await pumpAnswering(tester, answeringRoom());

    expect(find.byType(RoundIndicator), findsOneWidget);
    expect(find.byType(GameProgressBar), findsNothing);
    // The app bar's own wording survives; only the second copy of it is gone.
    expect(find.text('3'), findsWidgets);
    expect(find.text('Ronda 3 de 5'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the timer is the protagonist and keeps its own reading', (
    tester,
  ) async {
    await pumpAnswering(tester, answeringRoom());

    expect(find.byType(TimerWidget), findsOneWidget);
    final timer = tester.widget<TimerWidget>(find.byType(TimerWidget));
    // Seconds, not rounds — the signal the round bar never carried.
    expect(timer.totalSeconds, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('answer progress is kept: it restates neither round nor clock', (
    tester,
  ) async {
    // One of the two players has answered, so the panel reads 1/2.
    await pumpAnswering(tester, answeringRoom(currentUserAnswered: true));

    expect(find.byType(BufonStatusPanel), findsOneWidget);
    final panel = tester.widget<BufonStatusPanel>(
      find.byType(BufonStatusPanel),
    );
    // One of two players has answered. Distinct from 3/5 rounds and from the
    // clock, so this readout is not a duplicate and stays.
    expect(panel.progress, closeTo(0.5, 0.001));

    // Exactly one linear progress bar remains on the answering surface, and it
    // is the panel's own. Before this change there were two.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BufonStatusPanel),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the answering flow still works and still resolves', (
    tester,
  ) async {
    await pumpAnswering(tester, answeringRoom());

    // The question, the input and the submit action are all still there.
    expect(
      find.text('¿Cuál es el peor consejo que has recibido?'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Un pingüino con corbata');
    await tester.pump();
    expect(find.text('Un pingüino con corbata'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // And the room resolving to all-answered still renders without the
    // removed bar reappearing.
    await pumpAnswering(tester, answeringRoom(allAnswered: true));
    expect(find.byType(GameProgressBar), findsNothing);
    expect(find.byType(TimerWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
