// test/registered_feedback_adoption_test.dart

import 'package:bufon_flutter/domain/controllers/game_controller.dart';
import 'package:bufon_flutter/main.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_feedback.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:bufon_flutter/screens/lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP11 — the last transient feedback on the register-scoped screens
/// now goes through `BufonFeedback`.
///
/// Each test drives the real screen and the real handler, then reads the tone
/// off the `SnackBar` the primitive actually built. The boundary this package
/// works to is the register: Home, Lobby and Final Winner carry real Bufón
/// registers, so their feedback belongs to the primitive. The five screens
/// still on `BufonPhase.legacy` keep theirs until the package that recolours
/// them.
///
/// Final Winner's share-failure path is migrated but **not covered here**. Its
/// action sits behind the ceremony's staged entrance and the confetti overlay,
/// and could not be driven under the widget-test binding without altering that
/// staging — which WP7 owns. The migration there is a one-expression
/// substitution inside an existing `catch`; the gap is in reach, not in risk.
/// See the WP11 report.

/// The error fill, read back off a real `BufonFeedback` rather than hard-coded,
/// so this file cannot drift from the primitive's own palette.
Future<Color?> errorFill(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                BufonFeedback.show(context, 'x', tone: BufonFeedbackTone.error),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  return tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor;
}

SnackBar feedback(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

/// Fails `startGame` so Lobby's catch runs and nothing after it does.
///
/// `implements` with a `noSuchMethod` fallback rather than `extends`:
/// `GameController`'s constructor takes a `FirebaseService`, which reaches for
/// Firebase the test never starts. Only the one method the path calls first is
/// given a body.
class _FailingGameController implements GameController {
  @override
  Future<void> startGame(String roomCode) async =>
      throw StateError('no se pudo iniciar');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Room _lobbyRoom() => Room(
  code: 'ABCD12',
  hostId: 'host-1',
  phase: GamePhase.lobby,
  currentRound: 0,
  totalRounds: 5,
  players: [
    Player(id: 'host-1', name: 'Sofía', score: 0, isHost: true),
    Player(id: 'p2', name: 'Bruno', score: 0),
    Player(id: 'p3', name: 'Cami', score: 0),
  ],
);

void main() {
  testWidgets('Home reports a validation failure through the primitive', (
    tester,
  ) async {
    final expected = await errorFill(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MyApp(),
      ),
    );

    // The empty-name guard is local: it returns before any controller or
    // Firebase call, which is what makes it the cleanest probe of the path.
    await tester.tap(find.text('Crear Sala'));
    await tester.pump();

    expect(find.text('Por favor ingresa tu nombre'), findsOneWidget);
    expect(feedback(tester).backgroundColor, expected);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home keeps its own error mapping above the primitive', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MyApp(),
      ),
    );

    // A different trigger, a different message: `_showError` is one helper
    // behind five call sites, so the primitive must not have flattened them.
    await tester.enterText(find.byType(TextField).first, 'Sofía');
    await tester.tap(find.text('Unirse a Sala'));
    await tester.pump();

    expect(find.text('Por favor ingresa el código de sala'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lobby reports a failed start through the primitive', (
    tester,
  ) async {
    final expected = await errorFill(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomStreamProvider.overrideWith((ref) => Stream.value(_lobbyRoom())),
          userIdProvider.overrideWith((ref) => 'host-1'),
          gameControllerProvider.overrideWithValue(_FailingGameController()),
        ],
        child: const MaterialApp(home: LobbyScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Empezar el desmadre'));
    await tester.pump();

    // The screen's own `_friendlyStartError` still owns the copy; the
    // primitive only decides how it is painted.
    expect(
      find.text('No pudimos empezar la partida. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(feedback(tester).backgroundColor, expected);
    expect(tester.takeException(), isNull);
  });
}
