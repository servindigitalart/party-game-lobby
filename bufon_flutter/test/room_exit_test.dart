// test/room_exit_test.dart
//
// WP25 — the exit paths two independent audits found missing, the presence
// bug that cost a reviewer their own room, and the banner a service with no
// UI has needed since launch.
//
// Each test fails against the pre-WP25 code:
//
//   R-11  every stream-error placeholder was a dead end — audit A S-5:
//         *"no back arrow, no retry, no home button. The reviewer must
//         force-quit."* `grep 'PopScope\|WillPopScope\|leaveRoom'` → 0
//   R-12  `inactive` paused the heartbeat, and on iOS that fires for Control
//         Centre, the app switcher and a notification banner
//   R-37  `ConnectionService` had no UI at all

import 'package:bufon_flutter/core/game_copy.dart';
import 'package:bufon_flutter/data/repositories/room_repository.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/presentation/navigation/room_exit.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_placeholder.dart';
import 'package:bufon_flutter/presentation/widgets/connection_banner.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:bufon_flutter/screens/game_screen.dart';
import 'package:bufon_flutter/screens/home_screen.dart';
import 'package:bufon_flutter/screens/lobby_screen.dart';
import 'package:bufon_flutter/screens/round_result_screen.dart';
import 'package:bufon_flutter/screens/voting_screen.dart';
import 'package:bufon_flutter/services/connection_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubRepository extends RoomRepository {
  _StubRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<Room?> cleanupDisconnectedPlayers(String roomCode) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionService connection;

  /// The real service against a fake Firestore, so `stopHeartbeat`'s write
  /// actually runs and can be asserted on.
  ConnectionService freshConnection(FakeFirebaseFirestore firestore) =>
      ConnectionService(firestore: firestore);

  List<Override> baseOverrides({
    ConnectionService? service,
    RoomRepository? repository,
  }) => [
    userIdProvider.overrideWith((ref) => 'host-1'),
    roomCodeProvider.overrideWith((ref) => 'ABCD12'),
    currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
    connectionServiceProvider.overrideWithValue(
      service ?? ConnectionService(firestore: FakeFirebaseFirestore()),
    ),
    roomRepositoryProvider.overrideWithValue(repository ?? _StubRepository()),
  ];

  Widget host(Widget screen, {required List<Override> overrides}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: screen),
      );

  group('R-11 · every stream-error placeholder offers a route out', () {
    // audit A S-5 ≡ BP P7 (duplicate work D-2). Four screens, four dead ends.
    // The assertion is on the placeholder's *action*, not on a label: a
    // `BufonPlaceholder` with a null `onAction` renders no button at all,
    // which is exactly what "no route out" looked like.
    Future<void> expectRouteOut(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(
        host(
          screen,
          overrides: [
            ...baseOverrides(),
            roomStreamProvider.overrideWith(
              (ref) => Stream<Room?>.error(
                StateError('permission-denied'),
                StackTrace.empty,
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      final placeholder = tester.widget<BufonPlaceholder>(
        find.byType(BufonPlaceholder),
      );
      expect(placeholder.variant, BufonPlaceholderVariant.error);
      expect(placeholder.onAction, isNotNull, reason: 'no route out');
      expect(placeholder.actionLabel, GameCopy.backToHome);
    }

    testWidgets('lobby', (t) => expectRouteOut(t, const LobbyScreen()));
    testWidgets('answering', (t) => expectRouteOut(t, const GameScreen()));
    testWidgets('voting', (t) => expectRouteOut(t, const VotingScreen()));
    testWidgets(
      'round result',
      (t) => expectRouteOut(t, const RoundResultScreen()),
    );
  });

  group('R-11 · leaving is a real exit, not just a navigation', () {
    testWidgets('it stops the heartbeat, clears the room, and lands Home', (
      tester,
    ) async {
      // The whole chain, asserted as state rather than as pixels: a control
      // that navigates away while leaving the player's document beating is
      // the failure this package exists to prevent.
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('rooms')
          .doc('ABCD12')
          .collection('players')
          .doc('host-1')
          .set(Player(id: 'host-1', name: 'Sofía').toJson());

      connection = freshConnection(firestore);
      connection.startHeartbeat(roomCode: 'ABCD12', playerId: 'host-1');
      addTearDown(connection.dispose);

      late WidgetRef capturedRef;
      final container = ProviderContainer(
        overrides: baseOverrides(service: connection),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return Scaffold(
                  body: TextButton(
                    onPressed: () => RoomExit.toHome(context, ref),
                    child: const Text('salir'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(container.read(roomCodeProvider), 'ABCD12');

      await tester.tap(find.text('salir'));
      await tester.pumpAndSettle();

      // 1. room membership released on the client
      expect(container.read(roomCodeProvider), isNull);
      // 2. presence written, so the player stops being eligible immediately
      final player = await firestore
          .collection('rooms')
          .doc('ABCD12')
          .collection('players')
          .doc('host-1')
          .get();
      expect(player['isOnline'], isFalse);
      // 3. and the document still exists — removal is the sweep's job, on the
      //    20 s window WP22's eligibility filtering depends on. A second
      //    eviction path here would be a competing definition of "gone".
      expect(player.exists, isTrue);
      // 4. landed somewhere usable
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(capturedRef, isNotNull);
    });

    testWidgets('system back asks first, and staying does not leave', (
      tester,
    ) async {
      // Every room screen is the root of its stack, so Android back used to
      // pop the *application* with the player still in the room.
      final container = ProviderContainer(overrides: baseOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RoomPopScope(child: Scaffold(body: Text('en la sala'))),
          ),
        ),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(GameCopy.leaveRoomTitle), findsOneWidget);

      await tester.tap(find.text(GameCopy.leaveRoomStay));
      await tester.pumpAndSettle();

      expect(find.text('en la sala'), findsOneWidget);
      expect(container.read(roomCodeProvider), 'ABCD12', reason: 'still in');
    });

    testWidgets('confirming the dialog performs the real exit', (tester) async {
      final container = ProviderContainer(overrides: baseOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RoomPopScope(child: Scaffold(body: Text('en la sala'))),
          ),
        ),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text(GameCopy.leaveRoomConfirm));
      await tester.pumpAndSettle();

      expect(container.read(roomCodeProvider), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('R-12 · a transient interruption is not a disconnect', () {
    testWidgets('`inactive` does NOT pause the heartbeat', (tester) async {
      // audit A H-2. On iOS `inactive` fires for Control Centre, the app
      // switcher and a notification banner. Pausing there stopped the beats,
      // and two missed beats is the 20 s window `cleanupDisconnectedPlayers`
      // evicts on — so pulling down Control Centre could cost a solo host
      // their own room.
      //
      // The assertion is that a beat still *lands* after the interruption,
      // not merely that a flag is set: the heartbeat surviving is the whole
      // guarantee, and a cancelled timer would show up as a stale `lastSeen`.
      final firestore = FakeFirebaseFirestore();
      final playerRef = firestore
          .collection('rooms')
          .doc('ABCD12')
          .collection('players')
          .doc('host-1');
      await playerRef.set(
        Player(
          id: 'host-1',
          name: 'Sofía',
          lastSeen: DateTime(2020),
        ).toJson(),
      );

      final service = freshConnection(firestore);
      service.startHeartbeat(roomCode: 'ABCD12', playerId: 'host-1');

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pump();
      // Past one beat of the 10 s cadence.
      await tester.pump(const Duration(seconds: 11));

      final player = await playerRef.get();
      expect(
        player['isOnline'],
        isTrue,
        reason: 'a transient interruption marked the player offline',
      );
      expect(
        DateTime.parse(player['lastSeen'] as String).year,
        DateTime.now().year,
        reason: 'the heartbeat stopped beating through a transient state',
      );

      // Inside the body, not in a tearDown: the surviving timer is the point
      // of this test, and the framework checks for pending timers first.
      await service.stopHeartbeat();
      service.dispose();
    });

    testWidgets('`paused` still does — eviction is unchanged', (tester) async {
      // The other half of the guarantee, and WP25's own stop condition:
      // genuine disconnect detection must not degrade. A real backgrounding
      // still delivers `paused`, and a player who is really gone must still
      // stop beating so the 20 s sweep can evict them — WP22's eligibility
      // filtering depends on that eviction continuing to work.
      final firestore = FakeFirebaseFirestore();
      final playerRef = firestore
          .collection('rooms')
          .doc('ABCD12')
          .collection('players')
          .doc('host-1');
      await playerRef.set(Player(id: 'host-1', name: 'Sofía').toJson());

      final service = freshConnection(firestore);
      service.startHeartbeat(roomCode: 'ABCD12', playerId: 'host-1');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));

      final player = await playerRef.get();
      expect(player['isOnline'], isFalse);

      service.dispose();
    });

    test('the accusatory copy is gone', () {
      // audit A H-2: the room is deleted when fewer than two active players
      // remain, not because the player's internet failed.
      expect(GameCopy.roomClosedTooFewPlayers, isNot(contains('desconexión')));
      expect(GameCopy.roomClosedTooFewPlayers, contains('jugadores'));
    });
  });

  group('R-37 · the connectivity banner', () {
    testWidgets('renders nothing while connected', (tester) async {
      // Load-bearing: every existing layout — the WP4/WP5 viewport and
      // text-scale matrices included — is unchanged in the normal case only
      // because this occupies no space.
      final service = ConnectionService(firestore: FakeFirebaseFirestore());
      addTearDown(service.dispose);

      await tester.pumpWidget(
        host(
          const Scaffold(body: ConnectionBanner()),
          overrides: baseOverrides(service: service),
        ),
      );
      await tester.pump();

      expect(find.text(GameCopy.connectionLost), findsNothing);
      expect(tester.getSize(find.byType(ConnectionBanner)), Size.zero);
    });

    testWidgets('appears when the heartbeat is lost', (tester) async {
      final service = ConnectionService(firestore: FakeFirebaseFirestore());
      addTearDown(service.dispose);

      await tester.pumpWidget(
        host(
          const Scaffold(body: ConnectionBanner()),
          overrides: baseOverrides(service: service),
        ),
      );
      await tester.pump();

      service.connectionLost.value = true;
      await tester.pump();

      expect(find.text(GameCopy.connectionLost), findsOneWidget);
      expect(
        find.bySemanticsLabel(GameCopy.connectionLost),
        findsOneWidget,
        reason: 'the player is told, not left to notice',
      );
    });
  });

  group('R-23 · the three-player requirement is stated before committing', () {
    testWidgets('Home says it', (tester) async {
      // audit A M-4: *"nothing tells the reviewer the game needs 3 people"*,
      // and audit A §3 records it as a block point on the first screen.
      await tester.pumpWidget(
        host(const HomeScreen(), overrides: baseOverrides()),
      );
      await tester.pump();

      expect(find.text(GameCopy.playersRequired), findsOneWidget);
      expect(GameCopy.playersRequired, contains('3'));
      expect(GameCopy.playersRequired, contains('8'));
    });
  });
}
