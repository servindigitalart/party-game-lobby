// test/loop_stall_test.dart
//
// WP22 — the stalls audit B found and the suite could not see.
//
// audit B §9.2 is blunt about the starting point: *"**Every G-1 test.** No
// test anywhere constructs a room with a disconnected player and asserts that
// the round still advances… The voting stall (G-1F), the single-answerer
// deadlock (G-1G) and the zero-answer stranding (G-1H) are all invisible to
// the current suite."*
//
// Each test below asserts an invariant of the loop, not a widget arrangement,
// and each one fails against the pre-WP22 code:
//
//   G-1F  a disconnected player blocked completion in both phases
//   G-1F  `cleanupDisconnectedPlayers` was never called from voting
//   G-1G  one answer opened a ballot nobody could legally complete
//   G-1H  a zero-answer expiry retried, threw and toasted every 2 s, forever
//   G-2F  the round-result CTA had no in-flight guard

import 'package:bufon_flutter/core/exceptions.dart';
import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/question.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/presentation/widgets/animated_primary_button.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/screens/game_screen.dart';
import 'package:bufon_flutter/screens/round_result_screen.dart';
import 'package:bufon_flutter/screens/voting_screen.dart';
import 'package:bufon_flutter/services/question_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A player whose heartbeat stopped. 20 s is `Player.isDisconnected`'s own
/// threshold and `cleanupDisconnectedPlayers`'s, matched to the 10 s
/// heartbeat — two missed beats.
DateTime get _stale => DateTime.now().subtract(const Duration(seconds: 45));

Player _player(
  String id, {
  String? answer,
  String? votedFor,
  bool connected = true,
  bool isHost = false,
}) => Player(
  id: id,
  name: id,
  currentAnswer: answer,
  votedFor: votedFor,
  isHost: isHost,
  lastSeen: connected ? DateTime.now() : _stale,
);

/// Records which repository calls a screen makes, in order, so a *sequence*
/// can be asserted — the sweep has to happen before the transition, not just
/// at some point.
class _RecordingRepository extends RoomRepository {
  _RecordingRepository({this.sweptRoom, this.latency = Duration.zero})
    : super(firestore: FakeFirebaseFirestore());

  /// Round-trip time for the sweep. A real double tap lands while the first
  /// request is still in flight; with an instantaneous stub the first call
  /// would finish inside `await tester.tap(...)` and the second tap would be
  /// a legitimate, separate advance rather than the race R-13 guards.
  final Duration latency;

  /// What the sweep reports back. `null` is the production signal for "the
  /// room fell below two players and was deleted", which short-circuits
  /// `_advanceRound`, so any test that needs the round to advance supplies a
  /// surviving room here.
  final Room? sweptRoom;

  final List<String> calls = [];

  @override
  Future<Room?> cleanupDisconnectedPlayers(String roomCode) async {
    calls.add('cleanup');
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return sweptRoom;
  }

  @override
  Future<void> moveToVoting(String roomCode, {bool requireAllAnswered = true}) async {
    calls.add('moveToVoting(requireAllAnswered: $requireAllAnswered)');
  }

  @override
  Future<void> moveToRoundResult(String roomCode) async {
    calls.add('moveToRoundResult');
  }

  @override
  Future<void> clearRoundData(String roomCode) async => calls.add('clearRoundData');

  @override
  Future<void> updateRoom(Room room) async =>
      calls.add('updateRoom(round: ${room.currentRound})');

  /// WP23 moved the round advance off `updateRoom`'s whole-document write and
  /// onto this transactional, field-level method (audit B X-3). The invariant
  /// R-13 guards is unchanged — one advance per double tap — so the assertion
  /// below simply follows the call to where it now lives. Without the
  /// override the real implementation would reach the empty fake and throw
  /// `ROOM_NOT_FOUND`, which would make the test pass by recording nothing.
  @override
  Future<void> advanceToNextRound({
    required String roomCode,
    required String questionId,
    required String questionText,
  }) async => calls.add('advanceToNextRound($questionId)');
}

/// `QuestionService` reads `assets/questions.json` through `rootBundle` and
/// throws on an empty corpus. A fixed corpus keeps `_advanceRound` testable
/// without asserting anything about question selection, which is WP23's.
class _FixedQuestionService extends QuestionService {
  @override
  Question getRandomQuestion(List<String> usedQuestionIds) =>
      Question(id: 'q-next', text: '¿Y ahora qué?', pack: 'test');

  @override
  List<Question> getAllQuestions() => [getRandomQuestion(const [])];
}

Room _room({
  required GamePhase phase,
  required List<Player> players,
  int currentRound = 1,
  int totalRounds = 5,
  Duration elapsed = Duration.zero,
}) => Room(
  code: 'ABCD12',
  hostId: 'host-1',
  phase: phase,
  players: players,
  currentRound: currentRound,
  totalRounds: totalRounds,
  currentQuestionId: 'q1',
  currentQuestionText: '¿Cuál es el peor consejo que has recibido?',
  roundDuration: 90,
  roundStartTime: DateTime.now().subtract(elapsed),
);

/// Emits the room twice.
///
/// `_startTimer` runs in a post-frame callback and assigns `_remainingSeconds`
/// **outside** `setState` (audit B G-1I), so an expired clock only reaches
/// `build` on the next rebuild. In production every Firestore snapshot
/// supplies one; a single-value stream would leave the first frame's stale
/// 90 s in place and never re-evaluate.
Stream<Room?> _roomStream(Room room) async* {
  yield room;
  await Future<void>.delayed(const Duration(milliseconds: 50));
  yield room;
}

Widget _host(Widget screen, Room room, _RecordingRepository repository) =>
    ProviderScope(
      overrides: [
        roomStreamProvider.overrideWith((ref) => _roomStream(room)),
        userIdProvider.overrideWith((ref) => 'host-1'),
        roomRepositoryProvider.overrideWithValue(repository),
        questionServiceProvider.overrideWithValue(_FixedQuestionService()),
      ],
      child: MaterialApp(home: screen),
    );

/// Past the deliberate 2 s transition beat (BP G16 owns that value; WP22 does
/// not touch it) with room to spare, so a *repeating* attempt would show up.
Future<void> _settleBeat(WidgetTester tester) async {
  // First frame, then the stream's second emission (which is what lets an
  // expired clock reach `build` — see `_roomStream`), then the 2 s beat the
  // rebuild arms, then the transition itself.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('G-1F · eligibility — who a phase may wait for', () {
    test('a stale heartbeat makes a player ineligible', () {
      final players = [
        _player('a'),
        _player('b', connected: false),
        _player('c'),
      ];
      expect(players.eligible.map((p) => p.id), ['a', 'c']);
    });

    test('hasAnswered matches the server definition, not `!= null`', () {
      // audit B G-1J: the screens tested `currentAnswer != null` while the
      // repository and the ballot builder both required non-empty after trim.
      expect(_player('a').hasAnswered, isFalse);
      expect(_player('a', answer: '').hasAnswered, isFalse);
      expect(_player('a', answer: '   ').hasAnswered, isFalse);
      expect(_player('a', answer: 'algo').hasAnswered, isTrue);
    });

    testWidgets('answering advances when the only non-answerer has dropped', (
      tester,
    ) async {
      // Pre-WP22 this room waited out the full 90 s clock, because `allAnswered`
      // counted the dropped player forever. That wait is the testers' complaint.
      final repository = _RecordingRepository();
      await tester.pumpWidget(
        _host(
          const GameScreen(),
          _room(
            phase: GamePhase.answering,
            players: [
              _player('host-1', answer: 'uno', isHost: true),
              _player('p2', answer: 'dos'),
              _player('p3', connected: false),
            ],
          ),
          repository,
        ),
      );
      await _settleBeat(tester);

      expect(
        repository.calls,
        contains(startsWith('moveToVoting')),
        reason: 'a dropped player still blocked completion',
      );
    });

    testWidgets('voting advances when the only non-voter has dropped', (
      tester,
    ) async {
      // The same defect on the stage that has no clock to rescue it.
      final repository = _RecordingRepository();
      await tester.pumpWidget(
        _host(
          const VotingScreen(),
          _room(
            phase: GamePhase.voting,
            players: [
              _player('host-1', answer: 'uno', votedFor: 'p2', isHost: true),
              _player('p2', answer: 'dos', votedFor: 'host-1'),
              _player('p3', answer: 'tres', connected: false),
            ],
          ),
          repository,
        ),
      );
      await _settleBeat(tester);

      expect(
        repository.calls,
        contains('moveToRoundResult'),
        reason: 'a mid-vote disconnect stalled the room permanently',
      );
    });
  });

  group('R-10 · voting sweeps disconnected players', () {
    testWidgets('the sweep runs, and runs before the transition', (
      tester,
    ) async {
      // audit B: cleanup was called from the lobby, from answering and from
      // the round result — *"never from voting"*. Order matters as much as
      // presence: the server guard requires every remaining document to have
      // voted, so the sweep has to land first.
      final repository = _RecordingRepository();
      await tester.pumpWidget(
        _host(
          const VotingScreen(),
          _room(
            phase: GamePhase.voting,
            players: [
              _player('host-1', answer: 'uno', votedFor: 'p2', isHost: true),
              _player('p2', answer: 'dos', votedFor: 'host-1'),
              _player('p3', answer: 'tres', connected: false),
            ],
          ),
          repository,
        ),
      );
      await _settleBeat(tester);

      expect(repository.calls, contains('cleanup'));
      expect(
        repository.calls.indexOf('cleanup'),
        lessThan(repository.calls.indexOf('moveToRoundResult')),
      );
    });
  });

  group('G-1G · a ballot needs two answers', () {
    late FakeFirebaseFirestore firestore;
    late RoomRepository repository;

    Future<void> seed(List<Player> players) async {
      final room = Room(
        code: 'ABCD12',
        hostId: 'host-1',
        phase: GamePhase.answering,
        currentRound: 1,
      );
      await firestore.collection('rooms').doc('ABCD12').set(room.toJson());
      for (final player in players) {
        await firestore
            .collection('rooms')
            .doc('ABCD12')
            .collection('players')
            .doc(player.id)
            .set(player.toJson());
      }
    }

    Future<String?> phase() async => (await firestore
        .collection('rooms')
        .doc('ABCD12')
        .get())['phase'] as String?;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = RoomRepository(firestore: firestore);
    });

    test('zero answers is rejected and the room stays in answering', () async {
      await seed([_player('host-1'), _player('p2'), _player('p3')]);

      await expectLater(
        repository.moveToVoting('ABCD12', requireAllAnswered: false),
        throwsA(
          isA<RoomException>().having(
            (e) => e.code,
            'code',
            'NO_ANSWERS_SUBMITTED',
          ),
        ),
      );
      expect(await phase(), 'answering');
    });

    test('ONE answer is rejected — this is the deadlock', () async {
      // Pre-WP22 this call *succeeded* and moved the room to `voting`, where
      // the sole answerer had no legal vote (self-votes forbidden, every other
      // card absent), `allVoted` could never become true, and there was no
      // clock. Permanently dead. The guard now refuses to open that ballot.
      await seed([
        _player('host-1', answer: 'la única'),
        _player('p2'),
        _player('p3'),
      ]);

      await expectLater(
        repository.moveToVoting('ABCD12', requireAllAnswered: false),
        throwsA(
          isA<RoomException>().having(
            (e) => e.code,
            'code',
            'NOT_ENOUGH_ANSWERS',
          ),
        ),
      );
      expect(await phase(), 'answering');
    });

    test('two answers open the ballot', () async {
      await seed([
        _player('host-1', answer: 'uno'),
        _player('p2', answer: 'dos'),
        _player('p3'),
      ]);

      await repository.moveToVoting('ABCD12', requireAllAnswered: false);
      expect(await phase(), 'voting');
    });

    test('a whitespace answer does not count toward the ballot', () async {
      await seed([
        _player('host-1', answer: 'uno'),
        _player('p2', answer: '   '),
        _player('p3'),
      ]);

      await expectLater(
        repository.moveToVoting('ABCD12', requireAllAnswered: false),
        throwsA(isA<RoomException>()),
      );
      expect(await phase(), 'answering');
    });

    test('the room recovers: a later answer advances it', () async {
      // G-1H's *"a zero-answer expiry leaves a recoverable room"*, proven end
      // to end. The recovery path is the phase the room is already in —
      // `submitAnswerTransaction` checks the phase, not the clock — so no
      // round-retry mechanic is introduced (R-09 non-goal).
      await seed([_player('host-1'), _player('p2'), _player('p3')]);

      await expectLater(
        repository.moveToVoting('ABCD12', requireAllAnswered: false),
        throwsA(isA<RoomException>()),
      );

      await repository.submitAnswerTransaction('ABCD12', 'host-1', 'tarde');
      await repository.submitAnswerTransaction('ABCD12', 'p2', 'pero llegó');

      await repository.moveToVoting('ABCD12', requireAllAnswered: false);
      expect(await phase(), 'voting');
    });
  });

  group('G-1H · a stalled round does not spin', () {
    testWidgets('an expired round with no answers attempts nothing', (
      tester,
    ) async {
      // Pre-WP22 the host fired every 2 s at expiry: `shouldAdvance` was
      // `allAnswered || expired`, `_moveToVoting` threw, the catch toasted,
      // the `finally` rebuilt, and the whole thing rescheduled itself. An
      // error toast every two seconds for as long as the room existed.
      final repository = _RecordingRepository();
      await tester.pumpWidget(
        _host(
          const GameScreen(),
          _room(
            phase: GamePhase.answering,
            players: [_player('host-1', isHost: true), _player('p2'), _player('p3')],
            elapsed: const Duration(seconds: 200),
          ),
          repository,
        ),
      );
      await _settleBeat(tester);
      await tester.pump(const Duration(seconds: 10));

      expect(
        repository.calls.where((c) => c.startsWith('moveToVoting')),
        isEmpty,
        reason: 'the host retried a transition the guard must reject',
      );
    });

    testWidgets('an expired round with one answer attempts nothing', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      await tester.pumpWidget(
        _host(
          const GameScreen(),
          _room(
            phase: GamePhase.answering,
            players: [
              _player('host-1', answer: 'sola', isHost: true),
              _player('p2'),
              _player('p3'),
            ],
            elapsed: const Duration(seconds: 200),
          ),
          repository,
        ),
      );
      await _settleBeat(tester);

      expect(
        repository.calls.where((c) => c.startsWith('moveToVoting')),
        isEmpty,
        reason: 'the host opened a ballot with a single card',
      );
    });

    testWidgets('an expired round with two answers still advances', (
      tester,
    ) async {
      // The fallback must remain a fallback: not everyone answered, the clock
      // ran out, and the round proceeds anyway.
      final repository = _RecordingRepository();
      await tester.pumpWidget(
        _host(
          const GameScreen(),
          _room(
            phase: GamePhase.answering,
            players: [
              _player('host-1', answer: 'uno', isHost: true),
              _player('p2', answer: 'dos'),
              _player('p3'),
            ],
            elapsed: const Duration(seconds: 200),
          ),
          repository,
        ),
      );
      await _settleBeat(tester);

      expect(repository.calls, contains(startsWith('moveToVoting')));
    });
  });

  group('idempotency · one trigger, one transition', () {
    testWidgets('the answering auto-advance fires once, not repeatedly', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      await tester.pumpWidget(
        _host(
          const GameScreen(),
          _room(
            phase: GamePhase.answering,
            players: [
              _player('host-1', answer: 'uno', isHost: true),
              _player('p2', answer: 'dos'),
              _player('p3', answer: 'tres'),
            ],
          ),
          repository,
        ),
      );
      await _settleBeat(tester);
      await tester.pump(const Duration(seconds: 10));

      expect(
        repository.calls.where((c) => c.startsWith('moveToVoting')).length,
        1,
      );
    });

    testWidgets('R-13 · a round-result double tap advances one round', (
      tester,
    ) async {
      // audit B G-2F. `_nextRound` had no in-flight flag, so two taps ran
      // `_advanceRound` twice: two question draws and two `currentRound + 1`
      // writes off the same stale snapshot. Its two siblings always had this
      // guard; this CTA never did.
      final roundResultRoom = _room(
        phase: GamePhase.roundResult,
        players: [
          _player('host-1', answer: 'uno', votedFor: 'p2', isHost: true),
          _player('p2', answer: 'dos', votedFor: 'host-1'),
          _player('p3', answer: 'tres', votedFor: 'host-1'),
        ],
      );
      final repository = _RecordingRepository(
        sweptRoom: roundResultRoom,
        latency: const Duration(milliseconds: 300),
      );
      await tester.pumpWidget(
        _host(
          const RoundResultScreen(),
          _room(
            phase: GamePhase.roundResult,
            players: [
              _player('host-1', answer: 'uno', votedFor: 'p2', isHost: true),
              _player('p2', answer: 'dos', votedFor: 'host-1'),
              _player('p3', answer: 'tres', votedFor: 'host-1'),
            ],
          ),
          repository,
        ),
      );
      // Past both reveal stages, so the host CTA is on screen.
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Soltar la siguiente'), findsOneWidget);

      // Tap the control, not its label: the first tap flips it into its
      // loading state and the label is replaced, so a text finder would fail
      // on the second tap instead of exercising the guard.
      final cta = find.byType(AnimatedPrimaryButton);
      expect(cta, findsOneWidget);

      // Both taps inside the first request's flight time.
      await tester.tap(cta, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(cta, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));

      expect(
        repository.calls.where((c) => c.startsWith('advanceToNextRound')).length,
        1,
        reason: 'the round advanced twice off one snapshot',
      );
    });
  });
}
