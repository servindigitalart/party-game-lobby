// test/question_repetition_test.dart
//
// WP23 — audit B §9.3's G-2 row, which was at **zero coverage**:
// *"`grep -rn "getRandomQuestion\|usedQuestionIds" test` returns **zero
// matches**. `QuestionService` has no test file at all. The 20-question
// corpus has no test asserting its size, its uniqueness, or that a game's
// five questions are distinct."*
//
// Every test here fails against the pre-WP23 code:
//
//   R-14   the corpus was 20, not 100
//   R-18   `startFirstRound` wrote no history at all
//   R-18   `advanceToNextRound` did not exist — the path was
//          `updateRoom(room.copyWith(...))`, a whole-document write
//   G-2E   history lived in the host device's memory, so a handover lost it
//   PD-1   `roundDuration` defaulted to 90

import 'package:bufon_flutter/core/exceptions.dart';
import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/services/question_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R-14 · the corpus', () {
    late QuestionService service;

    setUp(() async {
      service = QuestionService();
      await service.loadQuestions();
    });

    test('holds the prototype\'s 100 questions', () {
      // audit B G-4H: the React prototype carried 100 questions and the
      // Flutter rewrite shipped 20, undocumented. R-14 calls the restoration
      // *"pure data"* and points at `6636976:src/questions.js`. Read with
      // `git show` — the stash was not applied.
      expect(service.getAllQuestions(), hasLength(100));
    });

    test('every id is unique', () {
      final ids = service.getAllQuestions().map((q) => q.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every text is unique', () {
      // The one that matters for repetition: two ids carrying the same words
      // would defeat de-duplication while passing the id check.
      final texts = service.getAllQuestions().map((q) => q.text).toList();
      expect(texts.toSet(), hasLength(texts.length));
    });

    test('every question is complete and packed', () {
      for (final q in service.getAllQuestions()) {
        expect(q.id, isNotEmpty);
        expect(q.text.trim(), isNotEmpty);
        expect(q.pack.trim(), isNotEmpty);
      }
    });

    test('the shipped 20 keep their ids and text', () {
      // The restoration is additive. Renumbering would orphan the history
      // already written into live room documents.
      final byId = {for (final q in service.getAllQuestions()) q.id: q};
      expect(byId['q001']!.text, '¿Quién es más propenso a tropezarse con el aire?');
      expect(byId['q020']!.text, '¿Cuál es la mentira más tonta que has dicho y te han creído?');
    });

    test('selection never replaces while anything remains', () {
      // The no-replacement guarantee, exercised across the whole corpus
      // rather than asserted from the shape of the code.
      final used = <String>[];
      for (var i = 0; i < 100; i++) {
        final q = service.getRandomQuestion(used);
        expect(used, isNot(contains(q.id)), reason: 'repeat at draw ${i + 1}');
        used.add(q.id);
      }
      expect(used.toSet(), hasLength(100));
    });

    test('exhaustion falls back rather than failing', () {
      // The documented existing rule — `question_service.dart`: *"If all
      // questions used, reset and pick any"*. WP23 preserves it; it is not a
      // new product rule and none was invented.
      final all = service.getAllQuestions().map((q) => q.id).toList();
      final q = service.getRandomQuestion(all);
      expect(all, contains(q.id));
    });
  });

  group('PD-1 · the answering clock', () {
    test('a new room runs 60 seconds', () {
      expect(Room(code: 'ABCD12', hostId: 'h').roundDuration, 60);
    });

    test('a room document with no duration falls back to 60', () {
      final room = Room.fromJson({
        'code': 'ABCD12',
        'hostId': 'h',
        'phase': 'lobby',
      });
      expect(room.roundDuration, 60);
    });

    test('an existing 90-second room keeps its own value', () {
      // PD-1's migration note: *"`Room.fromJson` falls back to 90, so a
      // default change affects new rooms only."* A room created before WP23
      // carries `roundDuration: 90` in its document and must keep it for its
      // lifetime — the clock is not retroactively shortened mid-game.
      final room = Room.fromJson({
        'code': 'ABCD12',
        'hostId': 'h',
        'phase': 'answering',
        'roundDuration': 90,
      });
      expect(room.roundDuration, 90);
    });
  });

  group('R-18 · the history lives on the room', () {
    test('it round-trips through the document', () {
      final room = Room(
        code: 'ABCD12',
        hostId: 'h',
        usedQuestionIds: const ['q001', 'q002'],
      );
      expect(Room.fromJson(room.toJson()).usedQuestionIds, ['q001', 'q002']);
    });

    test('a document written before WP23 reads as an empty history', () {
      expect(
        Room.fromJson({'code': 'ABCD12', 'hostId': 'h', 'phase': 'lobby'})
            .usedQuestionIds,
        isEmpty,
      );
    });
  });

  group('R-18 · durability through the real repository', () {
    late FakeFirebaseFirestore firestore;
    late RoomRepository repository;

    Future<void> seedRoom({
      GamePhase phase = GamePhase.lobby,
      int currentRound = 0,
      List<String> used = const [],
    }) async {
      await firestore.collection('rooms').doc('ABCD12').set({
        ...Room(
          code: 'ABCD12',
          hostId: 'host-1',
          phase: phase,
          currentRound: currentRound,
          usedQuestionIds: used,
        ).toJson(),
        'playerCount': 3,
      });
    }

    Future<Room> readRoom() async => Room.fromJson(
      (await firestore.collection('rooms').doc('ABCD12').get()).data()!,
    );

    /// Stands in for the two WP22-owned transitions that carry a room from
    /// `answering` to `roundResult`. Those have their own coverage in
    /// `loop_stall_test.dart` and need players and votes; this exercises the
    /// round-advance path itself, which is what WP23 changed.
    Future<void> reachRoundResult() async => firestore
        .collection('rooms')
        .doc('ABCD12')
        .update({'phase': GamePhase.roundResult.name});

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = RoomRepository(firestore: firestore);
    });

    test('startFirstRound records the question it opened with', () async {
      await seedRoom();
      await repository.startFirstRound(
        roomCode: 'ABCD12',
        questionId: 'q001',
        questionText: 'uno',
      );
      expect((await readRoom()).usedQuestionIds, ['q001']);
    });

    test('a second game APPENDS — it does not reset', () async {
      // The 80.6 % repeat rate, at its source. The lobby used to call
      // `getRandomQuestion([])` on every game, so game two drew from the full
      // corpus again. The room's history now spans the games it plays.
      await seedRoom(used: const ['q001', 'q002', 'q003']);
      await repository.startFirstRound(
        roomCode: 'ABCD12',
        questionId: 'q004',
        questionText: 'cuatro',
      );
      expect((await readRoom()).usedQuestionIds, [
        'q001',
        'q002',
        'q003',
        'q004',
      ]);
    });

    test('advanceToNextRound appends and counts from its own read', () async {
      // X-3: `currentRound + 1` used to be computed on the client from a
      // snapshot it had read earlier. It is now derived inside the
      // transaction.
      await seedRoom(
        phase: GamePhase.roundResult,
        currentRound: 2,
        used: const ['q001', 'q002'],
      );
      await repository.advanceToNextRound(
        roomCode: 'ABCD12',
        questionId: 'q003',
        questionText: 'tres',
      );

      final room = await readRoom();
      expect(room.currentRound, 3);
      expect(room.phase, GamePhase.answering);
      expect(room.usedQuestionIds, ['q001', 'q002', 'q003']);
    });

    test('advanceToNextRound refuses from the wrong phase', () async {
      // The server-side half of R-13's double-tap guard: two advances racing
      // off one snapshot cannot both land.
      await seedRoom(phase: GamePhase.answering, currentRound: 2);
      await expectLater(
        repository.advanceToNextRound(
          roomCode: 'ABCD12',
          questionId: 'q003',
          questionText: 'tres',
        ),
        throwsA(
          isA<RoomException>().having((e) => e.code, 'code', 'INVALID_PHASE'),
        ),
      );
      expect((await readRoom()).currentRound, 2);
    });

    test('it does not rewrite the fields the server owns', () async {
      // X-3's clobber. `updateRoom` wrote the whole document from a stale
      // client snapshot, including `gamesPlayedToday`, `adUnlocksRemaining`
      // and `nightPassExpiresAt` — which `firestore.rules` guards, so the
      // advance would have been rejected outright once the server moved them.
      await seedRoom(phase: GamePhase.roundResult, currentRound: 1);
      await firestore.collection('rooms').doc('ABCD12').update({
        'gamesPlayedToday': 2,
        'adUnlocksRemaining': 1,
      });

      await repository.advanceToNextRound(
        roomCode: 'ABCD12',
        questionId: 'q002',
        questionText: 'dos',
      );

      final raw = (await firestore
          .collection('rooms')
          .doc('ABCD12')
          .get()).data()!;
      expect(raw['gamesPlayedToday'], 2);
      expect(raw['adUnlocksRemaining'], 1);
    });

    test('a five-round game asks five distinct questions', () async {
      final service = QuestionService();
      await service.loadQuestions();

      await seedRoom();
      var room = await readRoom();

      final first = service.getRandomQuestion(room.usedQuestionIds);
      await repository.startFirstRound(
        roomCode: 'ABCD12',
        questionId: first.id,
        questionText: first.text,
      );

      for (var round = 2; round <= 5; round++) {
        await reachRoundResult();
        room = await readRoom();
        final next = service.getRandomQuestion(room.usedQuestionIds);
        await repository.advanceToNextRound(
          roomCode: 'ABCD12',
          questionId: next.id,
          questionText: next.text,
        );
      }

      room = await readRoom();
      expect(room.currentRound, 5);
      expect(room.usedQuestionIds, hasLength(5));
      expect(room.usedQuestionIds.toSet(), hasLength(5));
    });

    test('a host handover preserves the history', () async {
      // audit B G-2E. The history used to be `usedQuestionIdsProvider`, in the
      // *host device's* memory. A host promoted by
      // `cleanupDisconnectedPlayers` mid-game drew from its own empty list and
      // could re-ask what the room had already asked. A second repository
      // instance stands in for that second device: it shares no Dart state
      // with the first, only the room document.
      await seedRoom();
      await repository.startFirstRound(
        roomCode: 'ABCD12',
        questionId: 'q001',
        questionText: 'uno',
      );
      await reachRoundResult();

      final promotedHost = RoomRepository(firestore: firestore);
      final service = QuestionService();
      await service.loadQuestions();

      final roomAsSeenByNewHost = Room.fromJson(
        (await firestore.collection('rooms').doc('ABCD12').get()).data()!,
      );
      expect(roomAsSeenByNewHost.usedQuestionIds, ['q001']);

      final next = service.getRandomQuestion(
        roomAsSeenByNewHost.usedQuestionIds,
      );
      expect(next.id, isNot('q001'));

      await promotedHost.advanceToNextRound(
        roomCode: 'ABCD12',
        questionId: next.id,
        questionText: next.text,
      );
      expect((await readRoom()).usedQuestionIds, ['q001', next.id]);
    });
  });
}
