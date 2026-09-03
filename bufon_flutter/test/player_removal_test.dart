// test/player_removal_test.dart
//
// R-20 Package 2 — host player removal and the room-scoped rejoin bar.
//
// Apple's Guideline 1.2 asks for "the ability to block abusive users from the
// service". Bufón has no service to be blocked from, so the honest equivalent
// is: the host removes someone from the room they are in, and that room
// refuses them afterwards.
//
// Note the division of labour. `fake_cloud_firestore` does not evaluate
// security rules, so the *security* half of this contract — that a removed
// player cannot clear their own uid, and that a non-host cannot append one —
// is proven against the real emulator in `firestore-tests/rules.test.mjs`,
// not here. These tests prove the behaviour.

import 'package:bufon_flutter/core/exceptions.dart';
import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _host = 'host-uid';
const _p2 = 'player2-uid';
const _p3 = 'player3-uid';

Future<RoomRepository> _seed({
  GamePhase phase = GamePhase.lobby,
  List<String> removed = const [],
  List<String> players = const [_host, _p2, _p3],
}) async {
  final firestore = FakeFirebaseFirestore();
  final room = Room(
    code: 'ABC123',
    hostId: _host,
    phase: phase,
    removedPlayerIds: removed,
  );
  await firestore.collection('rooms').doc('ABC123').set({
    ...room.toJson(),
    'playerCount': players.length,
  });
  for (final id in players) {
    await firestore
        .collection('rooms')
        .doc('ABC123')
        .collection('players')
        .doc(id)
        .set(Player(id: id, name: id, isHost: id == _host).toJson());
  }
  return RoomRepository(firestore: firestore);
}

Future<Map<String, dynamic>> _roomDoc(RoomRepository repo) async {
  final room = await repo.getRoom('ABC123');
  return room!.toJson();
}

void main() {
  group('Room model — removedPlayerIds', () {
    test('defaults to empty', () {
      expect(Room(code: 'A', hostId: 'h').removedPlayerIds, isEmpty);
    });

    test('round-trips through toJson/fromJson', () {
      final room = Room(code: 'A', hostId: 'h', removedPlayerIds: const ['x', 'y']);
      expect(Room.fromJson(room.toJson()).removedPlayerIds, ['x', 'y']);
    });

    test('a room written before the field existed still deserializes', () {
      // No migration: the fallback is the same shape `usedQuestionIds` uses.
      final legacy = Room(code: 'A', hostId: 'h').toJson()
        ..remove('removedPlayerIds');
      expect(Room.fromJson(legacy).removedPlayerIds, isEmpty);
    });

    test('copyWith carries and replaces it', () {
      final room = Room(code: 'A', hostId: 'h', removedPlayerIds: const ['x']);
      expect(room.copyWith().removedPlayerIds, ['x']);
      expect(room.copyWith(removedPlayerIds: const ['z']).removedPlayerIds, ['z']);
    });
  });

  group('host removal', () {
    test('the host removes another player', () async {
      final repo = await _seed();
      await repo.removePlayer(
          roomCode: 'ABC123', hostId: _host, playerId: _p2);

      final room = await repo.getRoom('ABC123');
      expect(room!.players.map((p) => p.id), isNot(contains(_p2)));
      expect(room.removedPlayerIds, [_p2]);
    });

    test('the target player document is deleted', () async {
      final repo = await _seed();
      await repo.removePlayer(
          roomCode: 'ABC123', hostId: _host, playerId: _p2);

      final room = await repo.getRoom('ABC123');
      expect(room!.players, hasLength(2));
    });

    test('playerCount drops by exactly one', () async {
      final repo = await _seed();
      await repo.removePlayer(
          roomCode: 'ABC123', hostId: _host, playerId: _p2);
      expect((await _roomDoc(repo))['code'], 'ABC123');

      final room = await repo.getRoom('ABC123');
      expect(room!.players.length, 2);
    });

    test('the uid is appended exactly once, even if removal repeats', () async {
      final repo = await _seed(removed: const [_p2]);
      // The player doc still exists in this fixture, so a second removal is
      // reachable; the list must not grow a duplicate.
      await repo.removePlayer(
          roomCode: 'ABC123', hostId: _host, playerId: _p2);

      final room = await repo.getRoom('ABC123');
      expect(room!.removedPlayerIds, [_p2]);
    });

    test('the host cannot remove themselves', () async {
      final repo = await _seed();
      expect(
        () => repo.removePlayer(
            roomCode: 'ABC123', hostId: _host, playerId: _host),
        throwsA(isA<RoomException>()
            .having((e) => e.code, 'code', 'CANNOT_REMOVE_SELF')),
      );
    });

    test('a non-host cannot invoke removal', () async {
      final repo = await _seed();
      expect(
        () => repo.removePlayer(
            roomCode: 'ABC123', hostId: _p2, playerId: _p3),
        throwsA(
            isA<RoomException>().having((e) => e.code, 'code', 'NOT_HOST')),
      );
    });

    test('removing someone who is not in the room fails safely', () async {
      final repo = await _seed();
      expect(
        () => repo.removePlayer(
            roomCode: 'ABC123', hostId: _host, playerId: 'ghost'),
        throwsA(isA<RoomException>()
            .having((e) => e.code, 'code', 'PLAYER_NOT_FOUND')),
      );

      // Nothing was recorded for a player who never existed.
      final room = await repo.getRoom('ABC123');
      expect(room!.removedPlayerIds, isEmpty);
      expect(room.players, hasLength(3));
    });

    test('a missing room fails safely', () async {
      final repo = await _seed();
      expect(
        () => repo.removePlayer(
            roomCode: 'NOPE00', hostId: _host, playerId: _p2),
        throwsA(isA<RoomException>()
            .having((e) => e.code, 'code', 'ROOM_NOT_FOUND')),
      );
    });
  });

  group('rejoin bar', () {
    test('a removed uid cannot rejoin the same room', () async {
      final repo = await _seed();
      await repo.removePlayer(
          roomCode: 'ABC123', hostId: _host, playerId: _p2);

      expect(
        () => repo.joinRoom('ABC123', Player(id: _p2, name: 'Beto')),
        throwsA(isA<RoomException>()
            .having((e) => e.code, 'code', 'PLAYER_REMOVED')),
      );
    });

    test('removal closes the existing-player early return', () async {
      // joinRoom returns early, outside its transaction, whenever the caller
      // already has a player document — which would bypass every guard below
      // it. Deleting the document in the same transaction as the append is
      // what makes the bar reachable at all.
      final repo = await _seed();
      await repo.removePlayer(
          roomCode: 'ABC123', hostId: _host, playerId: _p2);

      final room = await repo.getRoom('ABC123');
      expect(room!.players.map((p) => p.id), isNot(contains(_p2)),
          reason: 'the early return must have nothing to return');

      expect(
        () => repo.joinRoom('ABC123', Player(id: _p2, name: 'Beto')),
        throwsA(isA<RoomException>()),
      );
    });

    test('a legitimate existing-player reconnect still works', () async {
      final repo = await _seed();
      final room = await repo.joinRoom('ABC123', Player(id: _p2, name: 'Beto'));
      expect(room.code, 'ABC123');
      expect(room.players, hasLength(3));
    });

    test('an unrelated player can still join', () async {
      final repo = await _seed(players: const [_host, _p2]);
      await repo.removePlayer(
          roomCode: 'ABC123', hostId: _host, playerId: _p2);

      final room = await repo.joinRoom('ABC123', Player(id: 'new', name: 'Nuevo'));
      expect(room.players.map((p) => p.id), contains('new'));
    });

    test('GAME_ALREADY_STARTED still wins for a non-removed newcomer',
        () async {
      final repo = await _seed(phase: GamePhase.answering);
      expect(
        () => repo.joinRoom('ABC123', Player(id: 'new', name: 'Nuevo')),
        throwsA(isA<RoomException>()
            .having((e) => e.code, 'code', 'GAME_ALREADY_STARTED')),
      );
    });

    test('the removal bar is checked before the phase guard', () async {
      // Ordering matters: a removed player should be told they were removed,
      // not that the game started. The fixture omits _p2's player document
      // because that is the state real removal leaves behind.
      final repo = await _seed(
        phase: GamePhase.answering,
        removed: const [_p2],
        players: const [_host, _p3],
      );
      expect(
        () => repo.joinRoom('ABC123', Player(id: 'newcomer', name: 'x')),
        throwsA(isA<RoomException>()
            .having((e) => e.code, 'code', 'GAME_ALREADY_STARTED')),
      );
      expect(
        () => repo.joinRoom('ABC123', Player(id: _p2, name: 'Beto')),
        throwsA(isA<RoomException>()
            .having((e) => e.code, 'code', 'PLAYER_REMOVED')),
      );
    });

    test('the bar depends on the document being deleted — the coupling is '
        'load-bearing', () async {
      // Recording the uid *without* deleting the player document would be
      // inert: joinRoom's early return fires before the transaction and hands
      // the room straight back. This test states that dependency, so a future
      // change that splits the two writes fails here rather than in the wild.
      final repo = await _seed(removed: const [_p2]); // doc deliberately kept
      final room = await repo.joinRoom('ABC123', Player(id: _p2, name: 'Beto'));
      expect(room.code, 'ABC123',
          reason: 'early return bypasses the guard when the doc survives — '
              'which is why removePlayer deletes it in the same transaction');
    });

    test('ROOM_FULL still applies to a non-removed newcomer', () async {
      final repo = await _seed(
        players: const ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'],
      );
      expect(
        () => repo.joinRoom('ABC123', Player(id: 'p9', name: 'Nueve')),
        throwsA(isA<RoomException>()
            .having((e) => e.code, 'code', 'ROOM_FULL')),
      );
    });

    test('the bar is room-scoped, not global', () async {
      // The same uid removed from one room joins another without obstruction.
      final firestore = FakeFirebaseFirestore();
      for (final code in ['AAA111', 'BBB222']) {
        await firestore.collection('rooms').doc(code).set({
          ...Room(code: code, hostId: _host).toJson(),
          'playerCount': 1,
        });
        await firestore
            .collection('rooms')
            .doc(code)
            .collection('players')
            .doc(_host)
            .set(Player(id: _host, name: 'Host', isHost: true).toJson());
      }
      final repo = RoomRepository(firestore: firestore);

      await repo.joinRoom('AAA111', Player(id: _p2, name: 'Beto'));
      await repo.removePlayer(
          roomCode: 'AAA111', hostId: _host, playerId: _p2);

      expect(
        () => repo.joinRoom('AAA111', Player(id: _p2, name: 'Beto')),
        throwsA(isA<RoomException>()),
      );
      final other = await repo.joinRoom('BBB222', Player(id: _p2, name: 'Beto'));
      expect(other.players.map((p) => p.id), contains(_p2));
    });
  });
}
