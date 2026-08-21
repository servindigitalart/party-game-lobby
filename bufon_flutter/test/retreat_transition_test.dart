import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/presentation/navigation/page_transitions.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:bufon_flutter/screens/final_winner_screen.dart';
import 'package:bufon_flutter/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP6 — the retreat transition's adoption.
///
/// `FadePageRoute` exists because Capítulo 23 asks for it: "las transiciones de
/// salida/retroceso (salir de una sala, volver a Home) usan un fade simple sin
/// slide, para que se sientan claramente distintas de 'avanzar en el juego'."
/// `pushAndRemoveAllFade` — the whole-stack variant, for leaving a room or
/// finishing a night — shipped with zero call sites, so every exit still used
/// the forward fade+slide and leaving felt like advancing.
///
/// These assert the *navigation contract* of an exit, not a curve: the
/// destination, the cleared stack, and that the route taken is the retreat one
/// rather than the forward one. The route type is the contract here — it is the
/// entire difference between "advancing" and "retreating" in this codebase.
void main() {
  final standings = [
    Player(id: 'p1', name: 'Sofía', score: 30),
    Player(id: 'p2', name: 'Bruno', score: 18),
    Player(id: 'p3', name: 'Cami', score: 7),
  ];

  /// Records the routes the navigator is asked to push, so a test can name the
  /// transition an exit actually used.
  late List<Route<dynamic>> pushed;

  setUp(() => pushed = <Route<dynamic>>[]);

  final observer = _RecordingObserver(() => pushed);

  /// A real phone viewport. The default 800x600 test surface leaves the
  /// ceremony's exit CTA below the fold, where a tap hit-tests nothing.
  void useViewport(WidgetTester tester) {
    final view = tester.view;
    view.physicalSize = const Size(390, 844) * 3.0;
    view.devicePixelRatio = 3.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  }

  /// Driven as a non-winner: the share branch is the winner-only one, and the
  /// exit CTA is identical either way.
  Widget harness({bool reduceMotion = false}) => ProviderScope(
    overrides: [
      currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
    ],
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        navigatorObservers: [observer],
        home: FinalWinnerScreen(
          winnerName: 'Sofía',
          winnerAvatarId: 'default',
          votesReceived: 4,
          totalScore: 30,
          isCurrentUserWinner: false,
          standings: standings,
        ),
      ),
    ),
  );

  /// Past both ceremony timers, each given its own frame, then consumes the
  /// one exception that is not this WP's.
  ///
  /// WP6 consumed one known exception here: `ShareVictoryCard` is mounted
  /// off-screen for every player and used to overflow its own frame the moment
  /// it was laid out. WP7 repaired the card, so nothing is consumed any more.
  Future<void> pumpToStandings(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  }

  Future<void> exitToHome(WidgetTester tester) async {
    // Scrolled into view rather than assumed on-screen: the ceremony is a
    // `SingleChildScrollView`, and its action column grew when WP7 ungated
    // share, so on a 390x844 surface the exit sits just past the fold for a
    // non-winner. `ensureVisible` is what a player does, and it keeps this
    // test from tracking the ceremony's height.
    await tester.ensureVisible(find.text('Salir'));
    await tester.pump();
    await tester.tap(find.text('Salir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('leaving the ceremony retreats to Home and clears the stack', (
    tester,
  ) async {
    useViewport(tester);
    await tester.pumpWidget(harness());
    await tester.pump();
    await pumpToStandings(tester);

    await exitToHome(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(FinalWinnerScreen), findsNothing);

    // Nothing left to go back to: a finished night is not a page you return to.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets(
    'leaving the ceremony uses the retreat route, not the forward one',
    (tester) async {
      useViewport(tester);
      await tester.pumpWidget(harness());
      await tester.pump();
      await pumpToStandings(tester);

      await exitToHome(tester);

      final exit = pushed.last;
      expect(
        exit,
        isA<FadePageRoute>(),
        reason: 'finishing a night is a retreat, not an advance',
      );
      expect(exit, isNot(isA<FadeSlidePageRoute>()));
    },
  );

  testWidgets('the exit still completes under reduced motion', (tester) async {
    useViewport(tester);
    await tester.pumpWidget(harness(reduceMotion: true));
    await tester.pump();
    await pumpToStandings(tester);

    await exitToHome(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });
}

class _RecordingObserver extends NavigatorObserver {
  final List<Route<dynamic>> Function() _sink;

  _RecordingObserver(this._sink);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sink().add(route);
  }
}
