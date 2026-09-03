// test/practice_mode_test.dart
//
// PD-12(c) + (a) + (d) / R-21 — Practice Mode.
//
// The product invariant these tests defend: Bufón needs three players, and
// Practice does not bend that. It satisfies it with one human and two
// simulated bufones — three real `Player`s going through the production
// guards, not a bypass around them.
//
// Note what this file does *not* need: `Firebase.initializeApp`. Every test
// below runs with no Firebase app at all, so any Firestore or Auth call on the
// Practice path would fail with `[core/no-app]` rather than pass quietly.
// That absence is the proof for A10, S10, and the offline requirement.

import 'package:bufon_flutter/core/exceptions.dart';
import 'package:bufon_flutter/core/game_copy.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_context.dart';
import 'package:bufon_flutter/data/repositories/practice_room_repository.dart';
import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/main.dart';
import 'package:bufon_flutter/presentation/widgets/animated_primary_button.dart';
import 'package:bufon_flutter/presentation/widgets/season_countdown_banner.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:bufon_flutter/screens/lobby_screen.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

const _humanId = 'practice-human';

Future<Room> _startedRoom(PracticeRoomRepository repo) async {
  await repo.createRoom('PRAC01', _humanId, 'Sofía');
  await repo.startFirstRound(
    roomCode: 'PRAC01',
    questionId: 'q1',
    questionText: '¿Qué es lo más ridículo que has hecho?',
  );
  return (await repo.getRoom('PRAC01'))!;
}

/// One complete round, driven in exactly the order the production screens
/// drive it: the human answers, the host opens the ballot, the human votes,
/// the host reveals.
Future<Room> _playRound(
  PracticeRoomRepository repo, {
  required String humanAnswer,
  required String humanVotesFor,
}) async {
  await repo.submitAnswerTransaction('PRAC01', _humanId, humanAnswer);
  await repo.moveToVoting('PRAC01');
  await repo.submitVoteTransaction('PRAC01', _humanId, humanVotesFor);
  await repo.moveToRoundResult('PRAC01');
  return (await repo.getRoom('PRAC01'))!;
}

void main() {
  group('A10 — Practice runs with no Firebase', () {
    test('the repository instantiates without Firestore or Auth', () {
      // No Firebase app exists in this process. Constructing the production
      // repository here would throw.
      expect(PracticeRoomRepository.new, returnsNormally);
    });

    test('a whole room is created with no Firebase app present', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      final room = await repo.createRoom('PRAC01', _humanId, 'Sofía');
      expect(room.code, 'PRAC01');
    });

    test('the production repository, by contrast, needs Firebase', () {
      // The contrast is the point: this is what "no Firebase" looks like when
      // it is absent, and it is why the test above is meaningful.
      expect(RoomRepository.new, throwsA(anything));
    });
  });

  group('A11 / A12 — exactly three players, one human, two bufones', () {
    test('a Practice room opens with exactly three players', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      final room = await repo.createRoom('PRAC01', _humanId, 'Sofía');
      expect(room.players, hasLength(3));
    });

    test('exactly one is the human, and they are the host', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      final room = await repo.createRoom('PRAC01', _humanId, 'Sofía');

      final humans = room.players.where((p) => p.id == _humanId).toList();
      expect(humans, hasLength(1));
      expect(humans.single.isHost, isTrue);
      expect(room.hostId, _humanId);
    });

    test('exactly two are simulated, with fixed identities', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      final room = await repo.createRoom('PRAC01', _humanId, 'Sofía');

      final bots = room.players.where((p) => p.id != _humanId).toList();
      expect(bots, hasLength(2));
      expect(
        bots.map((p) => p.id).toSet(),
        {PracticeRoomRepository.botOneId, PracticeRoomRepository.botTwoId},
      );
      expect(bots.every((p) => p.isHost), isFalse);
    });

    test('nobody else can join a Practice room', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      await repo.createRoom('PRAC01', _humanId, 'Sofía');
      expect(
        () => repo.joinRoom('PRAC01', Player(id: 'x', name: 'Intruso')),
        throwsA(isA<RoomException>()),
      );
    });
  });

  group('the production three-player minimum is respected, not bypassed', () {
    test('Practice passes the guard because it really has three players',
        () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      final room = await _startedRoom(repo);
      expect(room.players.length, greaterThanOrEqualTo(3));
      expect(room.phase, GamePhase.answering);
    });

    test('the same guard still refuses a room below three', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      await repo.createRoom('PRAC01', _humanId, 'Sofía');
      // Force the room under the minimum and confirm Practice refuses too.
      final room = (await repo.getRoom('PRAC01'))!;
      await repo.updateRoom(room.copyWith(players: [room.players.first]));

      expect(
        () => repo.startFirstRound(
            roomCode: 'PRAC01', questionId: 'q1', questionText: 'q'),
        throwsA(isA<RoomException>().having(
            (e) => e.code, 'code', 'NOT_ENOUGH_PLAYERS')),
      );
    });

    test('the production repository still carries the minimum', () {
      // Source-level, in the shape `blueprint_sweep_test` established: the
      // claim is that this package did not weaken a production guard.
      final source =
          File('lib/data/repositories/room_repository.dart').readAsStringSync();
      expect(source, contains('playerCount < 3'));
      expect(source, contains('NOT_ENOUGH_PLAYERS'));
    });
  });

  group('A13 — the bufones carry a full game', () {
    test('the human completes five rounds and reaches the ceremony', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      var room = await _startedRoom(repo);

      for (var round = 1; round <= room.totalRounds; round++) {
        // The bufones already answered when the round opened — before the
        // human has typed anything. That is what lets one person complete a
        // round without a second device.
        room = (await repo.getRoom('PRAC01'))!;
        expect(
            room.players
                .where((p) => p.id != _humanId)
                .every((p) => p.hasAnswered),
            isTrue,
            reason: 'round $round');

        room = await _playRound(repo,
            humanAnswer: 'Respuesta $round',
            humanVotesFor: PracticeRoomRepository.botOneId);

        // Everyone voted, so the round genuinely completed.
        expect(room.players.every((p) => p.votedFor != null), isTrue,
            reason: 'round $round');
        expect(room.phase, GamePhase.roundResult);

        if (round < room.totalRounds) {
          await repo.advanceToNextRound(
              roomCode: 'PRAC01',
              questionId: 'q${round + 1}',
              questionText: 'Pregunta ${round + 1}');
        }
      }

      expect(await repo.finishGame('PRAC01'), isTrue);
      room = (await repo.getRoom('PRAC01'))!;
      expect(room.phase, GamePhase.finalWinner);
      expect(room.currentRound, room.totalRounds);

      // Points were awarded by the same rule the server uses: 100 a vote,
      // three votes a round, five rounds.
      final total = room.players.fold<int>(0, (sum, p) => sum + p.score);
      expect(total, 3 * 5 * PracticeRoomRepository.pointsPerVote);
    });

    test('the ballot guards are satisfied honestly', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      await _startedRoom(repo);
      await repo.submitAnswerTransaction('PRAC01', _humanId, 'Mi respuesta');

      final room = (await repo.getRoom('PRAC01'))!;
      // WP22 requires at least two answers on the ballot. Practice has three.
      expect(room.players.where((p) => p.hasAnswered).length, 3);
      await repo.moveToVoting('PRAC01');
      expect((await repo.getRoom('PRAC01'))!.phase, GamePhase.voting);
    });

    test('a bufón never votes for itself', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      var room = await _startedRoom(repo);

      for (var round = 1; round <= 4; round++) {
        room = await _playRound(repo,
            humanAnswer: 'R$round', humanVotesFor: PracticeRoomRepository.botOneId);
        for (final bot in room.players.where((p) => p.id != _humanId)) {
          expect(bot.votedFor, isNot(bot.id), reason: 'round $round');
        }
        if (round < 5) {
          await repo.advanceToNextRound(
              roomCode: 'PRAC01', questionId: 'q$round', questionText: 'q');
        }
      }
    });
  });

  group('WP27 — Practice players stay eligible past the real 20s threshold',
      () {
    // The regression this file did not have: every existing Practice test
    // completes a full game in well under 20 seconds of real time, so
    // `Player.isDisconnected`'s real, unmodified 20s threshold (`player.dart`)
    // never had a chance to trip. This is the one that reproduces the actual
    // physical-device failure — Voting entered, then stuck forever — and
    // fails without WP27's fix.
    test(
        'a lastSeen aged past the real threshold is corrected by the '
        'periodic refresh, and Voting can still complete', () {
      fakeAsync((async) {
        final repo = PracticeRoomRepository();
        addTearDown(repo.dispose);

        // `PracticeRoomRepository`'s methods are async but never truly await
        // anything, so every call below resolves on the very next microtask.
        // `capture` drains that queue and hands back the settled `Room`,
        // without needing this callback itself to be `async` (fakeAsync's
        // Timer control only applies to code running synchronously inside
        // it).
        Room? snapshot;
        Room capture() {
          repo.getRoom('PRAC01').then((r) => snapshot = r);
          async.flushMicrotasks();
          return snapshot!;
        }

        repo.createRoom('PRAC01', _humanId, 'Sofía');
        async.flushMicrotasks();
        repo.startFirstRound(
          roomCode: 'PRAC01',
          questionId: 'q1',
          questionText: '¿Qué es lo más ridículo que has hecho?',
        );
        async.flushMicrotasks();
        repo.submitAnswerTransaction('PRAC01', _humanId, 'Mi respuesta');
        async.flushMicrotasks();
        repo.moveToVoting('PRAC01');
        async.flushMicrotasks();
        // The human votes, and — same beat, same as production — so do both
        // bufones. All three ballots are genuinely cast before staleness is
        // ever introduced below.
        repo.submitVoteTransaction(
            'PRAC01', _humanId, PracticeRoomRepository.botOneId);
        async.flushMicrotasks();
        expect(capture().players.every((p) => p.votedFor != null), isTrue,
            reason: 'sanity check — every player really did vote');

        // Reproduce the exact pre-WP27 failure state on top of those real
        // votes: every player's lastSeen aged past the real 20s threshold,
        // the same way an unrefreshed Practice room drifted on the physical
        // device. This is a genuinely stale, real DateTime — not a virtual
        // one — so it trips `Player.isDisconnected` regardless of how this
        // test's own clock is later advanced.
        final stale = DateTime.now().subtract(const Duration(seconds: 25));
        final beforeFix = capture();
        repo.updateRoom(
          beforeFix.copyWith(
            players: [
              for (final p in beforeFix.players) p.copyWith(lastSeen: stale),
            ],
          ),
        );
        async.flushMicrotasks();

        final stalled = capture();
        expect(
          stalled.players.every((p) => p.isDisconnected),
          isTrue,
          reason: 'sanity check — the real, unmodified 20s threshold in '
              'player.dart really does trip on an unrefreshed timestamp; '
              'this is the exact state that froze Voting on-device',
        );
        expect(stalled.players.eligible, isEmpty,
            reason: 'sanity check — every voted player just became '
                'uncountable; this is what made allVoted permanently '
                'unreachable before WP27, even with real votes on record');

        // Advance past WP27's 10s local heartbeat cadence — twice, past the
        // full 20s threshold, exactly as the work package asks. The fake
        // Timer.periodic this constructs fires for real; only the wait is
        // virtual, so the test stays fast and deterministic.
        async.elapse(const Duration(seconds: 25));

        final corrected = capture();
        expect(
          corrected.players.every((p) => !p.isDisconnected),
          isTrue,
          reason: 'WP27: the local heartbeat must correct staleness before '
              'the real threshold in player.dart trips',
        );

        // Exactly voting_screen.dart's allVoted formula (voting_screen.dart
        // ~235-238), computed from the same PlayerEligibility.eligible this
        // test just proved is populated again. Not a widget test — a direct
        // check, against real production code, that the shared completion
        // gate the screen itself evaluates is satisfied.
        final eligible = corrected.players.eligible.toList();
        final votedCount = eligible.where((p) => p.votedFor != null).length;
        final allVoted = eligible.isNotEmpty && votedCount == eligible.length;
        expect(eligible, hasLength(3),
            reason: 'all three Practice players, human and bufones alike, '
                'must still be counted');
        expect(allVoted, isTrue,
            reason: 'Voting must be able to complete — this is exactly the '
                'condition that stayed false forever on-device');
      });
    });

    test('dispose() cancels the local heartbeat — no leaked timer', () {
      fakeAsync((async) {
        final repo = PracticeRoomRepository();
        expect(async.pendingTimers.length, greaterThan(0),
            reason: 'the periodic presence timer starts at construction');
        repo.dispose();
        expect(async.pendingTimers.length, 0,
            reason: 'dispose() must cancel it — nothing may keep firing '
                'after Practice ends');
      });
    });
  });

  group('bot determinism', () {
    Future<List<String>> transcript() async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      var room = await _startedRoom(repo);
      final log = <String>[];

      for (var round = 1; round <= 5; round++) {
        room = (await repo.getRoom('PRAC01'))!;
        for (final p in room.players.where((p) => p.id != _humanId)) {
          log.add('r$round ${p.id} answer=${p.currentAnswer}');
        }
        room = await _playRound(repo,
            humanAnswer: 'fija', humanVotesFor: PracticeRoomRepository.botOneId);
        for (final p in room.players.where((p) => p.id != _humanId)) {
          log.add('r$round ${p.id} vote=${p.votedFor} score=${p.score}');
        }
        if (round < 5) {
          await repo.advanceToNextRound(
              roomCode: 'PRAC01', questionId: 'q$round', questionText: 'q');
        }
      }
      return log;
    }

    test('two identical runs produce identical state transitions', () async {
      final first = await transcript();
      final second = await transcript();
      expect(second, first);
      expect(first, isNotEmpty);
    });

    test('no source of wall-clock randomness in the bufones', () {
      final source = File('lib/data/repositories/practice_room_repository.dart')
          .readAsStringSync();
      final code = source
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//') &&
              !l.trimLeft().startsWith('///'))
          .join('\n');
      expect(code, isNot(contains('Random')));
      expect(code, isNot(contains('shuffle')));
    });
  });

  group('S10 — Practice writes no Firestore state', () {
    test('the repository names no Firestore or Auth type', () {
      final source = File('lib/data/repositories/practice_room_repository.dart')
          .readAsStringSync();
      for (final forbidden in [
        'cloud_firestore',
        'FirebaseFirestore',
        'firebase_auth',
        'FirebaseAuth',
        'cloud_functions',
        'FirebaseFunctions',
        'CollectionReference',
        'DocumentReference',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('deleting a Practice room touches nothing outside memory', () async {
      final repo = PracticeRoomRepository();
      addTearDown(repo.dispose);
      await repo.createRoom('PRAC01', _humanId, 'Sofía');
      await repo.deleteRoom('PRAC01');
      expect(await repo.getRoom('PRAC01'), isNull);
    });
  });

  group('S11 — the game_mode dimension', () {
    test('the key is the product dimension, spelled as specified', () {
      expect(TelemetryKeys.gameMode, 'game_mode');
    });

    test('Home sets practice on the Practice path and multiplayer on the '
        'others', () {
      final source = File('lib/screens/home_screen.dart').readAsStringSync();
      expect(source, contains("TelemetryKeys.gameMode: 'practice'"));
      expect(source, contains("TelemetryKeys.gameMode: 'multiplayer'"));
    });

    test('no existing telemetry event was renamed', () {
      // WP19's boundary and the event vocabulary are untouched: Practice adds
      // a context dimension, not an event.
      final source = File('lib/screens/home_screen.dart').readAsStringSync();
      expect(source, isNot(contains('practice_started')));
      expect(source, isNot(contains('practice_mode_entered')));
    });
  });

  group('provider substitution is scoped to the explicit choice', () {
    test('practice mode is off by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(practiceModeProvider), isFalse);
    });

    test('turning it on selects the in-memory repository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(practiceModeProvider.notifier).state = true;
      expect(container.read(roomRepositoryProvider),
          isA<PracticeRoomRepository>());
    });

    test('leaving it off selects the Firestore repository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // With no Firebase app, constructing the production repository throws —
      // which is exactly how we know multiplayer still resolves to it.
      expect(() => container.read(roomRepositoryProvider), throwsA(anything));
    });

    test('nothing inspects identity, build mode, or review state', () {
      final sources = [
        'lib/providers/game_providers.dart',
        'lib/data/repositories/practice_room_repository.dart',
        'lib/screens/home_screen.dart',
      ].map((p) => File(p).readAsStringSync()).join('\n');

      for (final forbidden in [
        'kDebugMode',
        'kReleaseMode',
        'kProfileMode',
        'dart.vm.product',
        'Platform.environment',
        'RemoteConfig',
        'isReviewer',
        'isAppReview',
      ]) {
        expect(sources, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Practice is honest product copy', () {
    test('Home exposes it by name', () {
      expect(GameCopy.practiceTitle, 'Practica solo');
      expect(GameCopy.practiceSubtitle, isNotEmpty);
    });

    test('the copy says what it is: two simulated bufones', () {
      expect(GameCopy.practiceSubtitle.toLowerCase(), contains('simulados'));
    });

    test('no reviewer, demo or store language reaches the player', () {
      // The contract is what a player can read. Doc comments in this feature
      // deliberately *do* discuss what Practice is not — that history is worth
      // recording next to the code — so the grep below strips prose, in the
      // same shape `blueprint_sweep_test` established for R-34.
      for (final copy in [
        GameCopy.practiceTitle,
        GameCopy.practiceSubtitle,
        GameCopy.practiceHumanName,
      ]) {
        final lower = copy.toLowerCase();
        for (final forbidden in ['demo', 'test', 'review', 'apple', 'prueba']) {
          expect(lower, isNot(contains(forbidden)),
              reason: '"$copy" contains "$forbidden"');
        }
      }
    });

    test('no reviewer-facing string is built anywhere in the feature', () {
      final code = [
        'lib/core/game_copy.dart',
        'lib/data/repositories/practice_room_repository.dart',
        'lib/screens/home_screen.dart',
      ]
          .map((p) => File(p).readAsStringSync())
          .expand((s) => s.split('\n'))
          .where((l) =>
              !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
          .join('\n')
          .toLowerCase();

      for (final forbidden in [
        'app store review',
        'reviewer',
        'demo mode',
        'modo demo',
      ]) {
        expect(code, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Home exposes Practice, and keeps it tertiary', () {
    Widget home() => ProviderScope(
          overrides: [
            currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MyApp(),
        );

    testWidgets('Practice is visible on Home', (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();
      expect(find.text(GameCopy.practiceTitle), findsOneWidget);
      expect(find.text(GameCopy.practiceSubtitle), findsOneWidget);
    });

    testWidgets('multiplayer stays primary: Practice carries no button fill',
        (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();

      // The two ways to play with other people are the filled/outlined
      // primitives; Practice is a plain text button.
      expect(find.text('Crear Sala'), findsOneWidget);
      expect(find.text('Unirse a Sala'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(GameCopy.practiceTitle),
          matching: find.byType(AnimatedPrimaryButton),
        ),
        findsNothing,
      );
    });

    testWidgets('Practice sits below both multiplayer panels and above the '
        'season banner', (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();

      double y(Finder f) => tester.getTopLeft(f).dy;
      final practiceY = y(find.text(GameCopy.practiceTitle));

      expect(practiceY, greaterThan(y(find.text('Crear Sala'))));
      expect(practiceY, greaterThan(y(find.text('Unirse a Sala'))));
      // The banner renders nothing with no active season, so its slot is
      // asserted by position in the tree rather than by pixels.
      final column = tester.widget<Column>(
        find
            .ancestor(
              of: find.text(GameCopy.practiceTitle),
              matching: find.byType(Column),
            )
            .last,
      );
      final children = column.children;
      final practiceIndex =
          children.indexWhere((w) => w.runtimeType.toString().contains('Practice'));
      final bannerIndex =
          children.indexWhere((w) => w is SeasonCountdownBanner);
      expect(practiceIndex, greaterThanOrEqualTo(0));
      expect(bannerIndex, greaterThan(practiceIndex));
    });


    testWidgets('tapping Practice reaches the production lobby with three '
        'players and no Firebase', (tester) async {
      // The seam, end to end through the real screens: Home is a production
      // widget, LobbyScreen is the production lobby, and no Firebase app
      // exists in this process. If anything on this path touched Firestore or
      // Auth it would throw `[core/no-app]` here.
      final view = tester.view;
      view.physicalSize = const Size(390, 1600) * 3.0;
      view.devicePixelRatio = 3.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(home());
      await tester.pump();

      await tester.ensureVisible(find.text(GameCopy.practiceTitle));
      await tester.pump();
      await tester.tap(find.text(GameCopy.practiceTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(LobbyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Three players, named, in the production lobby.
      expect(find.text(GameCopy.practiceHumanName), findsWidgets);
      expect(find.text(PracticeRoomRepository.botOneName), findsWidgets);
      expect(find.text(PracticeRoomRepository.botTwoName), findsWidgets);
    });

    testWidgets('Home still states the real requirement', (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();
      // PD-12(d), shipped in WP25 and untouched here.
      expect(find.text(GameCopy.playersRequired), findsOneWidget);
    });
  });
}
