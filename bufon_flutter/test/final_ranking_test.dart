// test/final_ranking_test.dart
//
// WP24 — PD-4(a): the ceremony adopts the server's "everyone tied wins"
// policy.
//
// The invariant these tests exist to hold is one line, and it is the whole
// package:
//
//     client winner set == server isWinner set
//
// The server's rule lives at `functions/src/progression/onMatchCompleted.ts`:
//
//     isWinner: p.score > 0 && p.score === topScore
//
// Before WP24 the client sorted by score with no tie-break and took `.first`,
// so on a tie the room crowned whichever player's anonymous Firebase UID
// sorted first while the backend credited every tied player. `_serverIsWinner`
// below is that server expression, transcribed and computed independently, so
// the tests compare two implementations rather than one implementation with
// itself.

import 'package:bufon_flutter/core/game_copy.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/screens/final_winner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(String id, String name, int score, {DateTime? lastSeen}) =>
    Player(id: id, name: name, score: score, lastSeen: lastSeen);

/// `onMatchCompleted.ts:160-167`, transcribed. Deliberately not expressed in
/// terms of `finalRanking` — a test that computed the expectation with the
/// code under test would prove nothing.
Set<String> _serverIsWinner(List<Player> players) {
  if (players.isEmpty) return <String>{};
  final topScore = players.map((p) => p.score).reduce((a, b) => a > b ? a : b);
  return players
      .where((p) => p.score > 0 && p.score == topScore)
      .map((p) => p.id)
      .toSet();
}

Set<String> _clientWinners(List<Player> players) => players.finalRanking
    .where((standing) => standing.isWinner)
    .map((standing) => standing.player.id)
    .toSet();

void main() {
  group('winner set — the PD-4(a) invariant', () {
    test('single winner: 500 / 400 / 300', () {
      final players = [_p('a', 'Ana', 500), _p('b', 'Beto', 400),
          _p('c', 'Caro', 300)];
      expect(_clientWinners(players), {'a'});
      expect(_clientWinners(players), _serverIsWinner(players));
    });

    test('two-way tie: 500 / 500 / 400 crowns both', () {
      final players = [_p('a', 'Ana', 500), _p('b', 'Beto', 500),
          _p('c', 'Caro', 400)];
      expect(_clientWinners(players), {'a', 'b'});
      expect(_clientWinners(players), _serverIsWinner(players));
    });

    test('three-way tie: 500 / 500 / 500 crowns all three', () {
      // The historical session, and audit B's constructible 3-cycle: five
      // rounds of A→B→C→A leave 500/500/500. The room used to see one name.
      final players = [_p('a', 'Ana', 500), _p('b', 'Beto', 500),
          _p('c', 'Caro', 500)];
      expect(_clientWinners(players), {'a', 'b', 'c'});
      expect(_clientWinners(players), _serverIsWinner(players));
    });

    test('zero scores crown nobody', () {
      final players = [_p('a', 'Ana', 0), _p('b', 'Beto', 0),
          _p('c', 'Caro', 0)];
      expect(_clientWinners(players), isEmpty,
          reason: 'score > 0 is part of the server rule');
      expect(_clientWinners(players), _serverIsWinner(players));
    });

    test('an empty room produces no ranking and no winner', () {
      expect(<Player>[].finalRanking, isEmpty);
      expect(_clientWinners(const []), isEmpty);
    });

    test('agrees with the server across a table of shapes', () {
      final shapes = <List<int>>[
        [500, 400, 300], [500, 500, 400], [500, 500, 500], [0, 0, 0],
        [100, 0, 0], [300, 300, 300, 300], [800, 100, 100], [0, 0, 500],
        [200, 200, 100, 100], [100], [0],
      ];
      for (final scores in shapes) {
        final players = [
          for (var i = 0; i < scores.length; i++)
            _p('p$i', 'Jugador $i', scores[i]),
        ];
        expect(_clientWinners(players), _serverIsWinner(players),
            reason: 'scores $scores');
      }
    });
  });

  group('winner set is independent of ordering', () {
    // The pre-WP24 defect was precisely an ordering dependency: Dart's
    // List.sort is not guaranteed stable, and the input arrives in Firestore
    // document-ID order, so the crown followed the UID.
    final tied = [
      _p('zzz', 'Ana', 500),
      _p('aaa', 'Beto', 500),
      _p('mmm', 'Caro', 500),
    ];

    test('UID ordering cannot change the winner set', () {
      final ascending = [...tied]..sort((a, b) => a.id.compareTo(b.id));
      final descending = [...tied]..sort((a, b) => b.id.compareTo(a.id));

      expect(_clientWinners(ascending), {'zzz', 'aaa', 'mmm'});
      expect(_clientWinners(ascending), _clientWinners(descending));
    });

    test('document ordering cannot change the winner set', () {
      // Every permutation of the arrival order.
      final orders = [
        [0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0],
      ];
      for (final order in orders) {
        final permuted = [for (final i in order) tied[i]];
        expect(_clientWinners(permuted), {'zzz', 'aaa', 'mmm'},
            reason: 'arrival order $order');
      }
    });

    test('display order among equals is by name, and carries no rank', () {
      final ranking = tied.finalRanking;
      expect(ranking.map((s) => s.player.name), ['Ana', 'Beto', 'Caro']);
      // Every one of them is rank 1. The list order is presentation only.
      expect(ranking.map((s) => s.rank), [1, 1, 1]);
      expect(ranking.every((s) => s.isWinner), isTrue);
    });
  });

  group('competition ranking', () {
    test('500 / 500 / 500 / 400 ranks 1 / 1 / 1 / 4', () {
      final players = [_p('a', 'Ana', 500), _p('b', 'Beto', 500),
          _p('c', 'Caro', 500), _p('d', 'Dani', 400)];
      expect(players.finalRanking.map((s) => s.rank), [1, 1, 1, 4]);
    });

    test('500 / 500 / 400 / 300 ranks 1 / 1 / 3 / 4', () {
      final players = [_p('a', 'Ana', 500), _p('b', 'Beto', 500),
          _p('c', 'Caro', 400), _p('d', 'Dani', 300)];
      expect(players.finalRanking.map((s) => s.rank), [1, 1, 3, 4]);
    });

    test('is neither dense nor ordinal when ties exist', () {
      final players = [_p('a', 'Ana', 500), _p('b', 'Beto', 500),
          _p('c', 'Caro', 500), _p('d', 'Dani', 400)];
      final ranks = players.finalRanking.map((s) => s.rank).toList();
      expect(ranks, isNot([1, 1, 1, 2]), reason: 'dense ranking');
      expect(ranks, isNot([1, 2, 3, 4]), reason: 'ordinal ranking');
    });

    test('strict ordering still ranks 1 / 2 / 3', () {
      final players = [_p('a', 'Ana', 500), _p('b', 'Beto', 400),
          _p('c', 'Caro', 300)];
      expect(players.finalRanking.map((s) => s.rank), [1, 2, 3]);
    });

    test('rank is derived from score alone, never from position', () {
      final players = [_p('d', 'Dani', 400), _p('c', 'Caro', 500),
          _p('a', 'Ana', 500)];
      final ranking = players.finalRanking;
      expect(ranking.map((s) => s.player.score), [500, 500, 400]);
      expect(ranking.map((s) => s.rank), [1, 1, 3]);
    });
  });

  group('ranking population matches the server', () {
    test('a late-disconnected player stays in the winner set', () {
      // The server ranks every document in rooms/{code}/players and applies
      // no disconnection filter. Filtering here would drop a player the
      // backend still credits — and would do it precisely when a tied
      // player's heartbeat lapses at the end of the night.
      final stale = _p('b', 'Beto', 500,
          lastSeen: DateTime.now().subtract(const Duration(minutes: 5)));
      final players = [_p('a', 'Ana', 500), stale, _p('c', 'Caro', 400)];

      expect(stale.isDisconnected, isTrue, reason: 'fixture precondition');
      expect(_clientWinners(players), {'a', 'b'});
      expect(_clientWinners(players), _serverIsWinner(players));
    });

    test('finalRanking does not apply the WP22 eligibility filter', () {
      final stale = _p('b', 'Beto', 500,
          lastSeen: DateTime.now().subtract(const Duration(minutes: 5)));
      final players = [_p('a', 'Ana', 500), stale];

      // The filter exists and would have removed them — that is the trap.
      expect(players.eligible.map((p) => p.id), ['a']);
      // The ranking keeps them.
      expect(players.finalRanking.map((s) => s.player.id), ['a', 'b']);
    });
  });

  group('ceremony copy', () {
    test('joins winner names for a single line', () {
      expect(GameCopy.winnerNames(const []), '');
      expect(GameCopy.winnerNames(const ['Ana']), 'Ana');
      expect(GameCopy.winnerNames(const ['Ana', 'Beto']), 'Ana y Beto');
      expect(GameCopy.winnerNames(const ['Ana', 'Beto', 'Caro']),
          'Ana, Beto y Caro');
    });

    test('single-winner share text is unchanged', () {
      expect(GameCopy.shareVictory(isWinner: true, winnerName: 'Ana'),
          '¡Soy el Bufón de la Noche! 🏆');
      expect(GameCopy.shareVictory(isWinner: false, winnerName: 'Ana'),
          'Ana es el Bufón de la Noche. 🏆');
    });

    test('a tie is shared in the plural', () {
      expect(
        GameCopy.shareVictory(
            isWinner: true, winnerName: 'Ana y Beto', winnerCount: 2),
        '¡Empatamos como Bufones de la Noche! 🏆',
      );
      expect(
        GameCopy.shareVictory(
            isWinner: false, winnerName: 'Ana y Beto', winnerCount: 2),
        'Ana y Beto empataron como Bufones de la Noche. 🏆',
      );
    });
  });

  group('ceremony renders the winner set', () {
    Widget harness(List<String> winners, List<Player> players) => MaterialApp(
          home: FinalWinnerScreen(
            winnerNames: winners,
            winnerAvatarId: 'default',
            votesReceived: 5,
            totalScore: 500,
            standings: players.finalRanking,
          ),
        );

    void useViewport(WidgetTester tester) {
      final view = tester.view;
      view.physicalSize = const Size(390, 1400) * 3.0;
      view.devicePixelRatio = 3.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);
    }

    Future<void> pumpToStandings(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> drain(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    }

    final tied = [
      _p('a', 'Ana', 500),
      _p('b', 'Beto', 500),
      _p('c', 'Caro', 500),
      _p('d', 'Dani', 400),
    ];

    testWidgets('a three-way tie names every winner', (tester) async {
      useViewport(tester);
      await tester.pumpWidget(harness(const ['Ana', 'Beto', 'Caro'], tied));
      await pumpToStandings(tester);

      for (final name in ['Ana', 'Beto', 'Caro']) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      await drain(tester);
    });

    testWidgets('a tie says so, and never crowns one of them', (tester) async {
      useViewport(tester);
      await tester.pumpWidget(harness(const ['Ana', 'Beto', 'Caro'], tied));
      await pumpToStandings(tester);

      expect(find.text(GameCopy.nightWinnersTied), findsOneWidget);

      // Equal prominence: the three names render in the same style, so no
      // reader can pick "the" winner out of the set.
      final styles = ['Ana', 'Beto', 'Caro']
          .map((n) => tester
              .widgetList<Text>(find.text(n))
              .first
              .style)
          .toList();
      expect(styles[0], styles[1]);
      expect(styles[1], styles[2]);

      await drain(tester);
    });

    testWidgets('the tied rows all read rank 1 in the standings',
        (tester) async {
      useViewport(tester);
      await tester.pumpWidget(harness(const ['Ana', 'Beto', 'Caro'], tied));
      await pumpToStandings(tester);

      // Competition ranking on screen: 1 / 1 / 1 / 4.
      expect(find.text('1'), findsNWidgets(3));
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);

      await drain(tester);
    });

    testWidgets('one winner still reveals exactly one name and no tie copy',
        (tester) async {
      useViewport(tester);
      final players = [_p('a', 'Ana', 500), _p('b', 'Beto', 400)];
      await tester.pumpWidget(harness(const ['Ana'], players));
      await pumpToStandings(tester);

      expect(find.text('Ana'), findsWidgets);
      expect(find.text(GameCopy.nightWinnersTied), findsNothing);
      expect(find.text(GameCopy.nightNoWinner), findsNothing);

      await drain(tester);
    });

    testWidgets('an empty winner set crowns nobody and still shows standings',
        (tester) async {
      useViewport(tester);
      final players = [_p('a', 'Ana', 0), _p('b', 'Beto', 0)];
      await tester.pumpWidget(harness(const [], players));
      await pumpToStandings(tester);

      expect(find.text(GameCopy.nightNoWinner), findsOneWidget);
      // The night is still reported.
      expect(find.text('Ana'), findsWidgets);
      expect(find.text('Beto'), findsWidgets);
      // Nothing to share when there is no winner.
      expect(find.text('Compartir victoria'), findsNothing);

      await drain(tester);
    });
  });
}
