import 'package:bufon_flutter/core/theme/bufon_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/presentation/transitions/keyhole_reveal_transition.dart';
import 'package:bufon_flutter/presentation/widgets/animated_primary_button.dart';
import 'package:bufon_flutter/presentation/widgets/confetti_widget.dart';
import 'package:bufon_flutter/screens/final_winner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP3 — the ceremony that ends a night.
///
/// The screen stages itself over two timers: the winner's name at 900 ms and
/// the standings + actions at 1900 ms. These tests pump in *steps*: a single
/// large pump fires a timer and paints the same frame, leaving controllers at
/// elapsed zero.
void main() {
  final standings = [
    Player(id: 'p1', name: 'Sofía', score: 30),
    Player(id: 'p2', name: 'Bruno', score: 18),
    Player(id: 'p3', name: 'Cami', score: 7),
  ];

  Widget harness({bool reduceMotion = false, bool isWinner = true}) =>
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          home: FinalWinnerScreen(
            winnerNames: const ['Sofía'],
            winnerAvatarId: 'default',
            votesReceived: 4,
            totalScore: 30,
            isCurrentUserWinner: isWinner,
            standings: standings.finalRanking,
          ),
        ),
      );

  /// Past both stage timers, with each given its own frame.
  Future<void> pumpToStandings(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Runs the ceremony out so no ticker or timer outlives the test.
  ///
  /// Until WP7 this consumed one known exception: `ShareVictoryCard` declared a
  /// `600x800` frame around content that needed far more, so it overflowed the
  /// moment the ceremony mounted it. WP7 fixed the card, so the suppression is
  /// gone — **any** exception now fails the test, which is the whole point of
  /// having repaired it.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  }

  testWidgets('declares the ceremonial night-winner register', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final scope = tester.widget<PhaseScope>(find.byType(PhaseScope).first);
    expect(scope.phase, BufonPhase.nightWinner);

    await drain(tester);
  });

  testWidgets('stage 0 withholds the winner and the standings', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // The name is the night's last secret.
    expect(find.text('Sofía'), findsNothing);
    expect(find.text('...'), findsOneWidget);

    // The standings' first row would answer the question the reveal is
    // still asking.
    expect(find.text('Cómo terminó la noche'), findsNothing);
    expect(find.text('Bruno'), findsNothing);
    expect(find.text('30 pts'), findsNothing);

    await drain(tester);
  });

  testWidgets('stage 1 reveals the winner through the keyhole', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sofía'), findsWidgets);

    final keyhole = find.byType(KeyholeRevealTransition);
    expect(keyhole, findsOneWidget);
    final progress = tester
        .widget<KeyholeRevealTransition>(keyhole)
        .progress
        .value;
    expect(progress, greaterThan(0.0));

    // Standings still withheld at the moment of the reveal.
    expect(find.text('Cómo terminó la noche'), findsNothing);

    await drain(tester);
  });

  testWidgets('uses the night confetti tier, not the round tier', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();

    final confetti = tester.widget<ConfettiWidget>(find.byType(ConfettiWidget));
    expect(confetti.tier, ConfettiTier.night);
    expect(confetti.isActive, isTrue);

    await drain(tester);
  });

  testWidgets('standings arrive only after the reveal', (tester) async {
    await tester.pumpWidget(harness());
    await pumpToStandings(tester);

    expect(find.text('Cómo terminó la noche'), findsOneWidget);
    for (final p in standings) {
      expect(find.text(p.name), findsWidgets);
    }
    expect(find.text('18 pts'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('reduced motion suppresses the particle storm but keeps the '
      'ceremony', (tester) async {
    await tester.pumpWidget(harness(reduceMotion: true));
    await pumpToStandings(tester);

    // ConfettiWidget is still mounted and still asked to be active...
    final confetti = tester.widget<ConfettiWidget>(find.byType(ConfettiWidget));
    expect(confetti.isActive, isTrue);
    expect(confetti.tier, ConfettiTier.night);
    // ...but it paints nothing (Capítulo 28).
    expect(
      find.descendant(
        of: find.byType(ConfettiWidget),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );

    // The ceremony itself survives: winner named, standings shown.
    expect(find.text('Sofía'), findsWidgets);
    expect(find.text('Cómo terminó la noche'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('the exit action is always available once actions arrive', (
    tester,
  ) async {
    await tester.pumpWidget(harness(isWinner: false));
    await pumpToStandings(tester);

    expect(find.text('Salir'), findsOneWidget);
    // WP7 ungated share (blueprint G6): the card is the only artefact that
    // reaches non-players, and the person most likely to post it is often not
    // the winner. WP3 asserted `findsNothing` here and recorded the ungate as
    // WP7's work; the truthfulness of what gets posted is covered by
    // `GameCopy.shareVictory` in `share_victory_card_test.dart`.
    expect(find.text('Compartir victoria'), findsOneWidget);
    expect(find.byType(AnimatedPrimaryButton), findsNWidgets(2));

    await drain(tester);
  });

  testWidgets('the winner gets both the share and the exit action', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await pumpToStandings(tester);

    expect(find.text('Compartir victoria'), findsOneWidget);
    expect(find.text('Salir'), findsOneWidget);
    expect(find.byType(AnimatedPrimaryButton), findsNWidgets(2));

    await drain(tester);
  });

  testWidgets('renders no raw exception text', (tester) async {
    await tester.pumpWidget(harness());
    await pumpToStandings(tester);

    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('Error:'), findsNothing);
    expect(find.textContaining('FirebaseException'), findsNothing);

    await drain(tester);
  });

  testWidgets('survives the narrow phone width without overflow', (
    tester,
  ) async {
    final view = tester.view;
    view.physicalSize = const Size(1080, 2400); // 360x800 logical
    view.devicePixelRatio = 3.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(harness());
    await pumpToStandings(tester);

    // The ceremony scrolls, so its own content cannot overflow vertically;
    // what a narrow phone actually threatens is horizontal clipping of the
    // 48 pt winner name and the standings rows.
    expect(find.text('Sofía'), findsWidgets);
    expect(find.text('Salir'), findsOneWidget);
    expect(find.text('Cómo terminó la noche'), findsOneWidget);
    expect(tester.getSize(find.byType(SingleChildScrollView)).width, 360);

    await drain(tester);
  });
}
