// test/launch_empty_states_test.dart
//
// WP20 · gate A9 — "Profile, Leaderboard, Seasons render **empty**, never
// **error**, unauthenticated with no profile".
//
// The clean-install state is the one a reviewer sees, and before WP20 all
// three surfaces reported it as a failure: `userIdProvider` defaulted to null
// and was only ever assigned inside home_screen's two room handlers, so
// nobody was signed in, Firestore denied every read, and the app said
// "No se pudo cargar el perfil" to someone whose only crime was not having
// played yet (audit A C-2, H-1).
//
// The other half of this file is the guard against over-correcting. An empty
// state must not swallow a genuine failure: no identity and a broken stream
// still have to look like what they are.

import 'package:bufon_flutter/core/logging/app_log_destination.dart';
import 'package:bufon_flutter/core/logging/app_log_entry.dart';
import 'package:bufon_flutter/core/logging/app_logger.dart';
import 'package:bufon_flutter/core/telemetry/game_telemetry_service.dart';
import 'package:bufon_flutter/core/telemetry/telemetry_event.dart';
import 'package:bufon_flutter/data/repositories/leaderboard_repository.dart';
import 'package:bufon_flutter/models/leaderboard_entry.dart';
import 'package:bufon_flutter/models/user_profile.dart';
import 'package:bufon_flutter/presentation/screens/leaderboard_screen.dart';
import 'package:bufon_flutter/presentation/screens/profile_screen.dart';
import 'package:bufon_flutter/presentation/widgets/brand_mark.dart';
import 'package:bufon_flutter/presentation/widgets/season_countdown_banner.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/providers/leaderboard_providers.dart';
import 'package:bufon_flutter/providers/progression_providers.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures what reaches the log fan-out, so a "silent" failure can be proven
/// to be no longer silent.
class _CaptureDestination implements AppLogDestination {
  final List<AppLogEntry> entries = [];

  @override
  void onLog(AppLogEntry entry) => entries.add(entry);

  Iterable<TelemetryEvent> get events =>
      entries.map((e) => e.telemetryEvent).whereType<TelemetryEvent>();
}

/// `currentWeekKeyProvider` builds a `LeaderboardRepository`, whose default
/// constructor reaches for `FirebaseFirestore.instance`. A fake keeps the
/// screen buildable without standing up Firebase — the same reason the
/// existing repository stubs hand one to `super`.
Override get _leaderboardRepositoryOverride =>
    leaderboardRepositoryProvider.overrideWithValue(
      LeaderboardRepository(firestore: FakeFirebaseFirestore()),
    );

Widget _host(Widget screen, {required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: screen),
);

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() => GameTelemetryService.instance.init());

  group('Profile', () {
    testWidgets('signed in with no profile yet is EMPTY, not an error', (
      tester,
    ) async {
      // Exactly the clean-install state: `main()` resolved an anonymous
      // identity, and `users/{uid}` does not exist yet.
      await tester.pumpWidget(
        _host(
          const ProfileScreen(),
          overrides: [
            userIdProvider.overrideWith((ref) => 'uid-1'),
            userProfileStreamProvider.overrideWith(
              (ref) => Stream<UserProfile?>.value(null),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Tu perfil empieza aquí'), findsOneWidget);
      expect(find.textContaining('Juega tu primera partida'), findsOneWidget);

      // The `empty` variant is the one that shows the isotype (Capítulo 25);
      // the `error` variant shows a semantic icon instead. Asserting on both
      // is what makes this a state test rather than a copy test.
      expect(find.byType(BrandMark), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.text('No se pudo cargar el perfil'), findsNothing);
    });

    testWidgets('no identity is an ERROR, not an empty state', (tester) async {
      // The over-correction guard. After WP20 a null id no longer means
      // "first run" — it means sign-in failed — and dressing that up as
      // "you have no progress yet" would hide a real failure from the one
      // person who could act on it.
      await tester.pumpWidget(
        _host(
          const ProfileScreen(),
          overrides: [
            userIdProvider.overrideWith((ref) => null),
            userProfileStreamProvider.overrideWith(
              (ref) => Stream<UserProfile?>.value(null),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('No se pudo cargar el perfil'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Tu perfil empieza aquí'), findsNothing);
    });

    testWidgets('a failing profile stream is an ERROR with a retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ProfileScreen(),
          overrides: [
            userIdProvider.overrideWith((ref) => 'uid-1'),
            userProfileStreamProvider.overrideWith(
              (ref) => Stream<UserProfile?>.error(
                StateError('firestore unavailable'),
                StackTrace.empty,
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('No se pudo cargar el perfil'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('the share action is never silent without an identity', (
      tester,
    ) async {
      // audit A C-2 §4: `if (userId != null) { …push… }` with no `else`.
      // Tapping produced no navigation, no message and no haptic, which reads
      // as a broken control rather than an unavailable one.
      await tester.pumpWidget(
        _host(
          const ProfileScreen(),
          overrides: [
            userIdProvider.overrideWith((ref) => null),
            userProfileStreamProvider.overrideWith(
              (ref) => Stream<UserProfile?>.value(null),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.share));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('perfil público'), findsOneWidget);
    });
  });

  group('Leaderboard', () {
    testWidgets('an empty board is EMPTY, not an error', (tester) async {
      await tester.pumpWidget(
        _host(
          const LeaderboardScreen(),
          overrides: [
            _leaderboardRepositoryOverride,
            userIdProvider.overrideWith((ref) => 'uid-1'),
            topPlayersProvider.overrideWith(
              (ref, LeaderboardType type) async => <LeaderboardEntry>[],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('¡Sé el primero!'), findsOneWidget);
      expect(find.byType(BrandMark), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.text('No se pudo cargar el ranking'), findsNothing);
    });

    testWidgets('a failing board is still an ERROR', (tester) async {
      // The second over-correction guard: WP20 must not convert a genuine
      // backend failure into "nobody has played yet".
      await tester.pumpWidget(
        _host(
          const LeaderboardScreen(),
          overrides: [
            _leaderboardRepositoryOverride,
            userIdProvider.overrideWith((ref) => 'uid-1'),
            topPlayersProvider.overrideWith(
              (ref, LeaderboardType type) async =>
                  throw StateError('permission-denied'),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('No se pudo cargar el ranking'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('¡Sé el primero!'), findsNothing);
    });
  });

  group('Season banner', () {
    testWidgets('no active season renders nothing, and reports nothing', (
      tester,
    ) async {
      // Rendering a banner for a season that does not exist is not an honest
      // empty state — it is noise on the app's first screen, and the
      // Blueprint places this banner below the primary CTAs precisely so it
      // stops competing with the brand. Absence *is* Home's empty state here.
      final capture = _CaptureDestination();
      AppLogger.instance.registerDestination(capture);
      addTearDown(() => AppLogger.instance.unregisterDestination(capture));

      await tester.pumpWidget(
        _host(
          const Scaffold(body: SeasonCountdownBanner()),
          overrides: [
            currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(SeasonCountdownBanner), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(
        capture.events.where((e) => e.name == 'season_load_failed'),
        isEmpty,
        reason: 'an absent season is not a failure',
      );
    });

    testWidgets('a failing season still renders nothing but is NOT silent', (
      tester,
    ) async {
      // audit A H-1: three independent conditions collapsed to one empty box,
      // so a real Firestore failure "vanished without a trace". The pixels are
      // unchanged — the trace is what this asserts.
      final capture = _CaptureDestination();
      AppLogger.instance.registerDestination(capture);
      addTearDown(() => AppLogger.instance.unregisterDestination(capture));

      await tester.pumpWidget(
        _host(
          const Scaffold(body: SeasonCountdownBanner()),
          overrides: [
            currentSeasonProvider.overrideWith(
              (ref) => Stream<dynamic>.error(
                StateError('permission-denied'),
                StackTrace.empty,
              ).cast(),
            ),
          ],
        ),
      );
      await tester.pump();

      final reported = capture.events
          .where((e) => e.name == 'season_load_failed')
          .toList();
      expect(reported, hasLength(1), reason: 'exactly one report, once');
      expect(reported.single.status, TelemetryStatus.failed);
    });
  });
}
