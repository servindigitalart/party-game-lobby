import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/presentation/transitions/keyhole_reveal_transition.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/screens/round_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the round reveal.
///
/// `RoundResultScreen` stages its reveal over two timers: the winning answer
/// at 750 ms (stage 1) and the author at 1550 ms (stage 2). Until Fase 2A the
/// full night scoreboard rendered from stage 0 alongside it, and its `#1` row
/// identifies the round winner — so a player could read the outcome off the
/// bottom of the screen during the 800 ms of engineered suspense above it.
///
/// Capítulo 35 Fase 3F's acceptance criterion: "el scoreboard no es visible
/// hasta que termina la etapa 2 del reveal."
void main() {
  // 'Sofía' leads the cumulative score, so the scoreboard's #1 row would name
  // her before the spotlight does — this is exactly the leak being tested.
  final room = Room(
    code: 'ABCD12',
    hostId: 'host-1',
    phase: GamePhase.roundResult,
    currentRound: 2,
    totalRounds: 5,
    players: [
      Player(id: 'host-1', name: 'Sofía', score: 30, currentAnswer: 'Algo'),
      Player(
        id: 'p2',
        name: 'Bruno',
        score: 10,
        currentAnswer: 'Una respuesta graciosa',
        votedFor: 'host-1',
      ),
    ],
  );

  // The default 800x600 test surface is short and wide; the scoreboard's
  // `ListView` is lazy, so on that shape the second row falls outside the
  // viewport and is never built. A phone-shaped surface (400x900 logical)
  // keeps the test measuring the gate rather than the window.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.physicalSize = const Size(1200, 2700);
    view.devicePixelRatio = 3.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  Widget harness() => ProviderScope(
    overrides: [
      roomStreamProvider.overrideWith((ref) => Stream.value(room)),
      userIdProvider.overrideWith((ref) => 'host-1'),
    ],
    child: const MaterialApp(home: RoundResultScreen()),
  );

  final scoreboard = find.text('Marcador de la noche');

  testWidgets('scoreboard is hidden before reveal stage 2', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(); // let the room stream deliver

    // Stage 0 — anticipation. Nothing but the spotlight.
    expect(scoreboard, findsNothing);
    expect(find.text('Sofía'), findsNothing);

    // Stage 1 (750 ms) — the answer opens, the author is still withheld.
    await tester.pump(const Duration(milliseconds: 800));
    expect(scoreboard, findsNothing);
    expect(find.text('Sofía'), findsNothing);

    // Drain the reveal so no ticker/timer outlives the test.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('scoreboard becomes visible at reveal stage 2', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // Past the 1550 ms stage-2 timer.
    await tester.pump(const Duration(milliseconds: 1600));

    expect(scoreboard, findsOneWidget);
    // Every player has a row, and the author is now named.
    expect(find.text('Sofía'), findsWidgets);
    expect(find.text('Bruno'), findsWidgets);
    expect(find.text('30 pts'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });

  // `KeyholeRevealTransition` was written for this exact moment and had never
  // rendered a frame in any build. This asserts it is mounted at stage 1 and
  // that its mask actually advances, so it cannot silently go dark again.
  testWidgets('keyhole mask opens over the answer at stage 1', (tester) async {
    final keyhole = find.byType(KeyholeRevealTransition);
    double progress() =>
        tester.widget<KeyholeRevealTransition>(keyhole).progress.value;

    await tester.pumpWidget(harness());
    await tester.pump();

    // Stage 0 — no answer on screen, so nothing to unmask.
    expect(keyhole, findsNothing);

    // Stage 1 fires at 750 ms; the mask starts closed and opens from there.
    await tester.pump(const Duration(milliseconds: 760));
    expect(keyhole, findsOneWidget);
    final atStart = progress();
    expect(atStart, lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 300));
    expect(progress(), greaterThan(atStart));

    // MotionDurations.revealStage is 800 ms, so the mask is fully open by the
    // time stage 2 names the author.
    await tester.pump(const Duration(milliseconds: 600));
    expect(progress(), 1.0);

    await tester.pump(const Duration(seconds: 4));
  });
}
