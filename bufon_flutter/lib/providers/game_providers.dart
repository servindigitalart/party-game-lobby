// providers/game_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../services/firebase_service.dart';
import '../services/question_service.dart';
import '../services/connection_service.dart';
import '../data/repositories/room_repository.dart';
import '../domain/controllers/game_controller.dart';

// Repositories
final roomRepositoryProvider = Provider((ref) => RoomRepository());

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

// Used question IDs
final usedQuestionIdsProvider = StateProvider<List<String>>((ref) => []);
