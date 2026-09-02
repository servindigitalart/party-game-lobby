// test/ceremony_votes_test.dart
//
// R-19 — the ceremony's vote count is the night's, not the last round's.
//
// The defect these tests exist to hold closed: the final ceremony used to
// count `votedFor == winner.id` across the room, and `clearRoundData` nulls
// `votedFor` at the end of every round. So a player who earned five votes
// across five rounds was congratulated for the one they earned in the last,
// while `onMatchCompleted` awarded XP on the real total — two numbers for one
// concept, and the smaller one on screen.
//
// Every assertion below reads what a player actually sees: the ceremony's
// `Votos` stat, via its semantics label. None of them restates the fixed
// expression back at itself — the fixture supplies a score and a deliberately
// *contradictory* set of final-round votes, and the test asserts the screen
// reports the score.

import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/screens/round_result_screen.dart';
import 'package:bufon_flutter/screens/final_winner_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _StubRepository extends RoomRepository {
  _StubRepository() : super(firestore: FakeFirebaseFirestore());
}

Player _p(String id, {required int score, String? votedFor, bool isHost = false}) =>
    Player(
      id: id,
      name: id,
      score: score,
      votedFor: votedFor,
      isHost: isHost,
      lastSeen: DateTime.now(),
    );

Room _finishedRoom(List<Player> players) => Room(
      code: 'ABC123',
      hostId: 'host-1',
      phase: GamePhase.finalWinner,
      players: players,
      currentRound: 5,
      totalRounds: 5,
    );

Widget _harness(Room room) => ProviderScope(
      overrides: [
        roomStreamProvider.overrideWith((ref) => Stream.value(room)),
        userIdProvider.overrideWith((ref) => 'host-1'),
        roomRepositoryProvider.overrideWithValue(_StubRepository()),
      ],
      child: const MaterialApp(home: RoundResultScreen()),
    );

/// Through the post-frame navigation, the route transition, and the ceremony's
/// first stage — the point at which the stats are on screen.
Future<void> _pumpToStats(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 950));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  expect(tester.takeException(), isNull);
}

void main() {
  // A generous surface: the ceremony is a tall scrolling column and this
  // package must not be the thing that makes it overflow.
  void useViewport(WidgetTester tester) {
    final view = tester.view;
    view.physicalSize = const Size(390, 1600) * 3.0;
    view.devicePixelRatio = 3.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  }

  group('R-19 · the ceremony reports the night, not the last round', () {
    testWidgets('a single winner is credited with every vote of the night',
        (tester) async {
      useViewport(tester);

      // The night: 3 votes for the host across five rounds — 300 points.
      // The final round: exactly ONE player voted for them.
      //
      // The old expression counted that one. The night's answer is three.
      final room = _finishedRoom([
        _p('host-1', score: 300, isHost: true),
        _p('p2', score: 100, votedFor: 'host-1'),
        _p('p3', score: 100, votedFor: 'p2'),
      ]);

      await tester.pumpWidget(_harness(room));
      await _pumpToStats(tester);

      expect(find.byType(FinalWinnerScreen), findsOneWidget);
      expect(find.bySemanticsLabel('3 Votos'), findsOneWidget);
      expect(find.bySemanticsLabel('1 Votos'), findsNothing,
          reason: 'that is the final round, not the night');

      await _drain(tester);
    });

    testWidgets('the number survives clearRoundData wiping every vote',
        (tester) async {
      useViewport(tester);

      // Every `votedFor` is null — exactly the state `clearRoundData` leaves
      // behind. The old expression would have counted zero and congratulated
      // the winner on nothing.
      final room = _finishedRoom([
        _p('host-1', score: 500, isHost: true),
        _p('p2', score: 200),
        _p('p3', score: 100),
      ]);

      await tester.pumpWidget(_harness(room));
      await _pumpToStats(tester);

      expect(find.bySemanticsLabel('5 Votos'), findsOneWidget);
      expect(find.bySemanticsLabel('0 Votos'), findsNothing);

      await _drain(tester);
    });

    testWidgets('a winner who scored nothing in the final round still counts',
        (tester) async {
      useViewport(tester);

      // Nobody voted for the winner in the last round at all, yet they lead
      // the night 400 to 200.
      final room = _finishedRoom([
        _p('host-1', score: 400, isHost: true),
        _p('p2', score: 200, votedFor: 'p3'),
        _p('p3', score: 200, votedFor: 'p2'),
      ]);

      await tester.pumpWidget(_harness(room));
      await _pumpToStats(tester);

      expect(find.bySemanticsLabel('4 Votos'), findsOneWidget);

      await _drain(tester);
    });
  });

  group('R-19 · gate A7 clause 3 — displayed votes == score / 100', () {
    for (final score in [100, 300, 500, 800]) {
      testWidgets('a score of $score displays ${score ~/ 100} votes',
          (tester) async {
        useViewport(tester);

        // The final-round votes are deliberately fixed at one, and wrong, for
        // every score in the table. Only a score-derived value can pass all
        // four cases.
        final room = _finishedRoom([
          _p('host-1', score: score, isHost: true),
          _p('p2', score: 0, votedFor: 'host-1'),
          _p('p3', score: 0, votedFor: 'p2'),
        ]);

        await tester.pumpWidget(_harness(room));
        await _pumpToStats(tester);

        expect(find.bySemanticsLabel('${score ~/ 100} Votos'), findsOneWidget);

        await _drain(tester);
      });
    }
  });

  group('R-19 · PD-4 behaviour is unchanged', () {
    testWidgets('tied winners each show the shared night total',
        (tester) async {
      useViewport(tester);

      final room = _finishedRoom([
        _p('host-1', score: 500, isHost: true),
        _p('p2', score: 500),
        _p('p3', score: 400),
      ]);

      await tester.pumpWidget(_harness(room));
      await _pumpToStats(tester);

      // Both are crowned (PD-4(a)) and the stat is the shared total.
      expect(find.text('host-1'), findsWidgets);
      expect(find.text('p2'), findsWidgets);
      expect(find.bySemanticsLabel('5 Votos'), findsOneWidget);

      await _drain(tester);
    });

    testWidgets('a room where nobody scored crowns nobody and shows no stat',
        (tester) async {
      useViewport(tester);

      final room = _finishedRoom([
        _p('host-1', score: 0, isHost: true),
        _p('p2', score: 0),
        _p('p3', score: 0),
      ]);

      await tester.pumpWidget(_harness(room));
      await _pumpToStats(tester);

      // The winner set is empty, so there is nobody for a vote count to
      // describe and the stats block is withheld rather than printed as zero.
      expect(find.bySemanticsLabel('0 Votos'), findsNothing);

      await _drain(tester);
    });

    testWidgets('the strict winner is still the only one crowned',
        (tester) async {
      useViewport(tester);

      final room = _finishedRoom([
        _p('host-1', score: 300, isHost: true),
        _p('p2', score: 200),
        _p('p3', score: 100),
      ]);

      await tester.pumpWidget(_harness(room));
      await _pumpToStats(tester);

      expect(find.bySemanticsLabel('3 Votos'), findsOneWidget);
      // Points are the night's score, untouched by this package.
      expect(find.bySemanticsLabel('300 Puntos'), findsOneWidget);

      await _drain(tester);
    });
  });
}
