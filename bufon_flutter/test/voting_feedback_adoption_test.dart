// test/voting_feedback_adoption_test.dart

import 'package:bufon_flutter/core/exceptions.dart';
import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_feedback.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/screens/voting_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP10 — the four feedback paths in `voting_screen` now go through
/// `BufonFeedback`.
///
/// These drive the real screen and the real handlers, and read the tone off
/// the `SnackBar` the primitive actually built. Asserting only that the source
/// no longer contains the string "SnackBar" would prove the call sites moved
/// and nothing about whether a failed vote still tells the player it failed.

/// Stands in for the room repository so the two handlers under test can be
/// driven to either outcome.
///
/// A subclass rather than a mock: voting goes through Cloud Functions, not
/// Firestore, so `fake_cloud_firestore` cannot reach it and there is no
/// mocking package in the project. Overriding the two methods the screen
/// calls keeps the rest of the repository — including the telemetry the
/// screen never touches — exactly as production has it. The Firestore handed
/// to `super` is a fake purely so the constructor does not reach for
/// `FirebaseFirestore.instance`.
class _StubRepository extends RoomRepository {
  _StubRepository({this.onVote, this.onAdvance})
    : super(firestore: FakeFirebaseFirestore());

  final Object? Function()? onVote;
  final Object? Function()? onAdvance;

  @override
  Future<void> submitVoteTransaction(
    String roomCode,
    String voterId,
    String votedForId,
  ) async {
    final failure = onVote?.call();
    if (failure != null) throw failure;
  }

  @override
  Future<void> moveToRoundResult(String roomCode) async {
    final failure = onAdvance?.call();
    if (failure != null) throw failure;
  }
}

Room _votingRoom({bool currentUserHasVoted = false, bool allVoted = false}) =>
    Room(
      code: 'ABCD12',
      hostId: 'host-1',
      phase: GamePhase.voting,
      currentRound: 1,
      totalRounds: 5,
      currentQuestionText: '¿Cuál es el peor consejo que has recibido?',
      players: [
        Player(
          id: 'host-1',
          name: 'Sofía',
          score: 0,
          currentAnswer: 'Algo',
          votedFor: currentUserHasVoted ? 'p2' : null,
        ),
        Player(
          id: 'p2',
          name: 'Bruno',
          score: 0,
          currentAnswer: 'Una respuesta graciosa',
          votedFor: allVoted ? 'host-1' : null,
        ),
      ],
    );

Future<void> _pumpVoting(
  WidgetTester tester, {
  required RoomRepository repository,
  bool currentUserHasVoted = false,
  bool allVoted = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomStreamProvider.overrideWith(
          (ref) => Stream.value(
            _votingRoom(
              currentUserHasVoted: currentUserHasVoted,
              allVoted: allVoted,
            ),
          ),
        ),
        userIdProvider.overrideWith((ref) => 'host-1'),
        roomRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: VotingScreen()),
    ),
  );
  await tester.pump();
  // The answer cards enter staggered from opacity 0; without this they are
  // present but not yet hit-testable.
  await tester.pump(const Duration(milliseconds: 600));
}

/// The `SnackBar` currently on screen, as the primitive built it.
SnackBar _feedback(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

/// The two tones, read back off a built `SnackBar` rather than hard-coded, so
/// this file cannot drift from the primitive's own palette.
Future<Color?> _fillFor(WidgetTester tester, BufonFeedbackTone tone) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => BufonFeedback.show(context, 'x', tone: tone),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  return _feedback(tester).backgroundColor;
}

void main() {
  testWidgets('a registered vote confirms in the success tone', (tester) async {
    final expected = await _fillFor(tester, BufonFeedbackTone.success);

    await _pumpVoting(tester, repository: _StubRepository());
    await tester.tap(find.text('Una respuesta graciosa'));
    await tester.pump();

    expect(find.text('¡Voto registrado!'), findsOneWidget);
    expect(_feedback(tester).backgroundColor, expected);
  });

  testWidgets('a rejected vote keeps its mapped message and the error tone', (
    tester,
  ) async {
    final expected = await _fillFor(tester, BufonFeedbackTone.error);

    await _pumpVoting(
      tester,
      repository: _StubRepository(
        onVote: () => VotingException('rechazado', code: 'ALREADY_VOTED'),
      ),
    );
    await tester.tap(find.text('Una respuesta graciosa'));
    await tester.pump();

    // The screen's own switch still maps the code; the primitive only decides
    // how the result is painted.
    expect(find.text('Ya has votado'), findsOneWidget);
    expect(_feedback(tester).backgroundColor, expected);
  });

  testWidgets('an unexpected vote failure still reaches the player', (
    tester,
  ) async {
    final expected = await _fillFor(tester, BufonFeedbackTone.error);

    await _pumpVoting(
      tester,
      // Not a VotingException: the bare `catch` is the path that used to be
      // the easiest one to lose, because nothing else reports it.
      repository: _StubRepository(onVote: () => StateError('boom')),
    );
    await tester.tap(find.text('Una respuesta graciosa'));
    await tester.pump();

    expect(
      find.text('Algo se atoró al registrar tu voto. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(_feedback(tester).backgroundColor, expected);
  });

  testWidgets('a failed advance to results reports in the error tone', (
    tester,
  ) async {
    final expected = await _fillFor(tester, BufonFeedbackTone.error);

    // The button only exists for the host once every vote is in.
    await _pumpVoting(
      tester,
      currentUserHasVoted: true,
      allVoted: true,
      repository: _StubRepository(
        onAdvance: () => RoomException('faltan votos', code: 'VOTES_PENDING'),
      ),
    );
    await tester.tap(find.text('Ver Resultados'));
    await tester.pump();

    expect(find.text('Todavía falta gente por votar.'), findsOneWidget);
    expect(_feedback(tester).backgroundColor, expected);

    // An all-voted room also arms the host's 2 s auto-advance. Unmounting
    // cancels it through the screen's own dispose rather than leaving a timer
    // pending past the test.
    await tester.pumpWidget(const SizedBox());
  });
}
