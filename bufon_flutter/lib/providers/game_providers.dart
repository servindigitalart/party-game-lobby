// providers/game_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../services/firebase_service.dart';
import '../services/question_service.dart';
import '../services/connection_service.dart';
import '../data/repositories/practice_room_repository.dart';
import '../data/repositories/room_repository.dart';
import '../domain/controllers/game_controller.dart';

// Practice Mode (PD-12(c) / R-21).
//
// Flipped by a person tapping "Practica solo" on Home, and by nothing else.
// It is not derived from the build mode, the user's identity, a remote value,
// or any attempt to detect App Review — the app cannot tell who is holding it
// and does not try.
final practiceModeProvider = StateProvider<bool>((ref) => false);

// Repositories
//
// The one seam Practice needs. `PracticeRoomRepository` implements the same
// interface and is swapped in here, so every consumer below — the room
// stream, the game controller, and through them the production lobby, game,
// voting, round-result and ceremony screens — drives a Practice game with no
// knowledge that it is one. Multiplayer keeps the Firestore implementation.
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  if (ref.watch(practiceModeProvider)) {
    final practice = PracticeRoomRepository();
    ref.onDispose(practice.dispose);
    return practice;
  }
  return RoomRepository();
});

// Services
final firebaseServiceProvider = Provider((ref) => FirebaseService());
final questionServiceProvider = Provider((ref) => QuestionService());
final connectionServiceProvider = Provider((ref) => ConnectionService());

// Game Controller (combines Firebase + Repository).
// Monetization is enforced entirely via RoomRepository.canRoomStartGame
// (Firestore), so it is not injected here — see monetization_providers.dart
// for the local-cache/UI-only MonetizationController.
final gameControllerProvider = Provider<GameController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  final roomRepository = ref.watch(roomRepositoryProvider);
  return GameController(firebaseService, roomRepository);
});

// Current user ID.
//
// WP20: the initial value is seeded by `main()`, which resolves the anonymous
// identity before the first frame and overrides this provider. The `null`
// default below is therefore the *failure* value — no signed-in identity —
// not the ordinary first-run state it used to be.
//
// Consumers must keep that distinction. `null` means "we could not establish
// an identity", which is a failure worth reporting; it does not mean "this
// player has no data yet". The empty state belongs to the *data*, not to
// this provider.
//
// Still a writable `StateProvider`: home_screen assigns it after create/join,
// and this package leaves that path untouched.
final userIdProvider = StateProvider<String?>((ref) => null);

// Current room code
final roomCodeProvider = StateProvider<String?>((ref) => null);

// Room stream
final roomStreamProvider = StreamProvider.autoDispose<Room?>((ref) {
  final roomCode = ref.watch(roomCodeProvider);
  if (roomCode == null) {
    return Stream.value(null);
  }
  final repository = ref.watch(roomRepositoryProvider);
  return repository.watchRoom(roomCode);
});

// WP23 / R-18 removed `usedQuestionIdsProvider`.
//
// It was a `StateProvider<List<String>>` holding the room's question history
// in the *host device's memory*. That made the history host-local (a promoted
// host drew from its own empty list and could re-ask a used question) and
// per-game (the lobby reset it to `[]` on every new game, which is what
// produced the 80.6 % repeat rate across two consecutive games in one room).
//
// The history now lives on the room document as `Room.usedQuestionIds`, where
// it has one owner, survives host handover and process death, and accumulates
// across the games a room plays. Nothing replaces this provider — the room
// stream already carries the value.
