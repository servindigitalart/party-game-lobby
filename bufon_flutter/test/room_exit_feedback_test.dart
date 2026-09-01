// test/room_exit_feedback_test.dart

import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/core/game_copy.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:bufon_flutter/screens/game_screen.dart';
import 'package:bufon_flutter/screens/home_screen.dart';
import 'package:bufon_flutter/screens/lobby_screen.dart';
import 'package:bufon_flutter/services/connection_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP13 — a player thrown out of a room is told why.
///
/// Both loop screens hand the same explanation to `BufonFeedback` on their way
/// back to Home. WP12 established that it never arrived: the outgoing route is
/// disposed when its 250 ms fade completes, and the feedback was scheduled for
/// 500 ms, by which point the `mounted` guard that protects it is false.
///
/// WP25 / R-12 replaced the literal these assertions used to carry. The copy
/// read "La sala se cerró por desconexión", which audit A H-2 called
/// accusatory: it blames the player's connection for a room that is actually
/// deleted when fewer than two active players remain. The assertions now read
/// the constant from `GameCopy`, so they cannot drift from production, and the
/// behaviour under test — that the message survives the navigation — is
/// unchanged.
///
/// These tests drive the real triggers — a room stream that goes null, a
/// cleanup pass that deletes the room, a player who is no longer in the
/// roster — and assert the message is on screen *after* both the transition
/// and the old 500 ms boundary have passed. Asserting before either would
/// prove nothing: the defect is entirely about what survives them.

/// Returns whatever `cleanupDisconnectedPlayers` is told to.
///
/// A subclass rather than a mock: the screens reach for the repository through
/// a provider, and only this one method is on the path under test. The
/// Firestore handed to `super` is a fake purely so the constructor does not
/// reach for `FirebaseFirestore.instance`.
class _StubRepository extends RoomRepository {
  _StubRepository({this.onCleanup}) : super(firestore: FakeFirebaseFirestore());

  final Room? Function()? onCleanup;

  @override
  Future<Room?> cleanupDisconnectedPlayers(String roomCode) async =>
      onCleanup?.call();
}

Room _room({required GamePhase phase, List<Player>? players}) => Room(
  code: 'ABCD12',
  hostId: 'host-1',
  phase: phase,
  currentRound: phase == GamePhase.lobby ? 0 : 1,
  totalRounds: 5,
  currentQuestionText: '¿Cuál es el peor consejo que has recibido?',
  players:
      players ??
      [
        Player(id: 'host-1', name: 'Sofía', score: 0, isHost: true),
        Player(id: 'p2', name: 'Bruno', score: 0),
        Player(id: 'p3', name: 'Cami', score: 0),
      ],
);

Widget _host(Widget screen, {required List<Override> overrides}) =>
    ProviderScope(
      overrides: [
        // Home is the destination of every path here, and it reads the season.
        currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
        userIdProvider.overrideWith((ref) => 'host-1'),
        connectionServiceProvider.overrideWithValue(
          ConnectionService(firestore: FakeFirebaseFirestore()),
        ),
        ...overrides,
      ],
      child: MaterialApp(home: screen),
    );

/// Past the post-frame callback that starts the navigation, past the 250 ms
/// retreat fade, and past the 500 ms mark the discarded callback used to wait
/// for — all well inside the primitive's four-second error duration, so a
/// message that was handed over is still on screen at the end.
Future<void> settleThroughOldBoundary(WidgetTester tester) async {
  await tester.pump(); // post-frame callback schedules navigation
  await tester.pump(); // navigation begins
  await tester.pump(const Duration(milliseconds: 300)); // fade completes
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 400)); // past 500 ms total
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('A — Lobby: a room deleted by cleanup explains itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LobbyScreen(),
        overrides: [
          roomCodeProvider.overrideWith((ref) => 'ABCD12'),
          roomStreamProvider.overrideWith(
            (ref) => Stream.value(_room(phase: GamePhase.lobby)),
          ),
          // Cleanup finds the room gone — the real trigger for this path.
          roomRepositoryProvider.overrideWithValue(
            _StubRepository(onCleanup: () => null),
          ),
        ],
      ),
    );
    await tester.pump();

    // The lobby's own 30 s periodic cleanup, not a hand-called private method.
    await tester.pump(const Duration(seconds: 30));
    await settleThroughOldBoundary(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(GameCopy.roomClosedTooFewPlayers), findsOneWidget);
  });

  testWidgets('B — Lobby: a room stream that goes null explains itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LobbyScreen(),
        overrides: [
          roomCodeProvider.overrideWith((ref) => 'ABCD12'),
          roomStreamProvider.overrideWith((ref) => Stream.value(null)),
          roomRepositoryProvider.overrideWithValue(_StubRepository()),
        ],
      ),
    );
    await settleThroughOldBoundary(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(GameCopy.roomClosedTooFewPlayers), findsOneWidget);
  });

  testWidgets('C — Game: a room stream that goes null explains itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const GameScreen(),
        overrides: [
          roomCodeProvider.overrideWith((ref) => 'ABCD12'),
          roomStreamProvider.overrideWith((ref) => Stream.value(null)),
          roomRepositoryProvider.overrideWithValue(_StubRepository()),
        ],
      ),
    );
    await settleThroughOldBoundary(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(GameCopy.roomClosedTooFewPlayers), findsOneWidget);
  });

  testWidgets('D — Game: a player no longer in the roster is told they left', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const GameScreen(),
        overrides: [
          roomCodeProvider.overrideWith((ref) => 'ABCD12'),
          // The room is alive; this player is simply not in it any more.
          roomStreamProvider.overrideWith(
            (ref) => Stream.value(
              _room(
                phase: GamePhase.answering,
                players: [
                  Player(id: 'p2', name: 'Bruno', score: 0),
                  Player(id: 'p3', name: 'Cami', score: 0),
                ],
              ),
            ),
          ),
          roomRepositoryProvider.overrideWithValue(_StubRepository()),
        ],
      ),
    );
    await settleThroughOldBoundary(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Saliste de la sala.'), findsOneWidget);
  });
}
