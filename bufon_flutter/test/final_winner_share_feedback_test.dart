// test/final_winner_share_feedback_test.dart

import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/presentation/widgets/animated_primary_button.dart';
import 'package:bufon_flutter/presentation/widgets/bufon_feedback.dart';
import 'package:bufon_flutter/screens/final_winner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP14 — the ceremony's share failure, driven end to end.
///
/// WP11 concluded this path could not be reached under the widget-test binding
/// and reverted its migration rather than ship an unproven claim. That was the
/// right call on the evidence it had, and the evidence was incomplete: two
/// separate test-side obstacles, neither of them in production code.
///
/// The first is the viewport. At the default 800x600 surface the ceremony's
/// actions sit below the fold, exactly as `retreat_transition_test` already
/// documents; the tap landed on nothing. The second is that the handler's
/// `RenderRepaintBoundary.toImage` is completed by the engine, not by the fake
/// clock, so `pump` alone leaves the handler suspended mid-flight forever.
/// `runAsync` is what lets the real encoding finish.
///
/// With both addressed the whole chain runs for real: real CTA, real handler,
/// real card capture, and a real failure at the real boundary — `path_provider`
/// has no implementation under the test binding, so `getTemporaryDirectory`
/// throws and the production `catch` runs on its own terms. Nothing is faked
/// and no production seam was added.
void main() {
  final standings = [
    Player(id: 'p1', name: 'Sofía', score: 30),
    Player(id: 'p2', name: 'Bruno', score: 18),
  ];

  /// A real phone viewport — the same helper shape `retreat_transition_test`
  /// uses, and for the same reason: the default surface hides the actions.
  void useViewport(WidgetTester tester) {
    final view = tester.view;
    view.physicalSize = const Size(390, 844) * 3.0;
    view.devicePixelRatio = 3.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  }

  Widget harness() => MaterialApp(
    key: UniqueKey(),
    home: FinalWinnerScreen(
      winnerNames: const ['Sofía'],
      winnerAvatarId: 'default',
      votesReceived: 4,
      totalScore: 30,
      isCurrentUserWinner: true,
      standings: standings.finalRanking,
    ),
  );

  /// Past both ceremony timers, each given its own frame, exactly as the
  /// existing ceremony tests do. Production timing is untouched.
  Future<void> pumpToStandings(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  Finder shareCta() =>
      find.widgetWithText(AnimatedPrimaryButton, 'Compartir victoria');

  String primaryLabel(WidgetTester tester) => tester
      .widget<AnimatedPrimaryButton>(find.byType(AnimatedPrimaryButton).first)
      .text;

  /// Runs the real share action to its real failure and returns nothing —
  /// callers assert on what the screen shows afterwards.
  Future<void> shareAndFail(WidgetTester tester) async {
    await tester.ensureVisible(shareCta());
    await tester.pump();
    await tester.tap(shareCta());
    await tester.pump();

    // The handler is in flight: the CTA relabels itself from `_isSharing`.
    // This is the proof that the tap reached the real method rather than
    // landing on a widget that merely looks like the button.
    expect(primaryLabel(tester), 'Generando...');

    // The handler opens with its own 100 ms delay, which is a fake-clock timer:
    // `runAsync` advances real time, not this one, so it has to be elapsed here
    // or the handler never reaches the capture at all.
    await tester.pump(const Duration(milliseconds: 200));

    // Now let the engine finish encoding the off-screen card, after which
    // `getTemporaryDirectory` fails.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a failed share tells the player, and the ceremony recovers', (
    tester,
  ) async {
    useViewport(tester);
    await tester.pumpWidget(harness());
    await tester.pump();
    await pumpToStandings(tester);

    await shareAndFail(tester);

    expect(
      find.text('No se pudo compartir. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    // `finally` ran: the button is offered again rather than stuck generating.
    expect(primaryLabel(tester), 'Compartir victoria');
    // The exit action is still there — the failure did not take the ceremony
    // down with it.
    expect(find.text('Salir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('that failure is presented by the feedback primitive', (
    tester,
  ) async {
    // What the primitive builds for an error, read back rather than
    // hard-coded, so this cannot drift from the primitive's own decisions.
    await tester.pumpWidget(
      MaterialApp(
        // A fresh key remounts the app and with it the root ScaffoldMessenger.
        // Without it the reference snackbar survives into the ceremony's tree
        // — `MaterialApp` reuses its element — and the comparison below would
        // be the reference measured against itself.
        key: UniqueKey(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => BufonFeedback.show(
                context,
                'reference',
                tone: BufonFeedbackTone.error,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    final reference = tester.widget<SnackBar>(find.byType(SnackBar));

    useViewport(tester);
    await tester.pumpWidget(harness());
    await tester.pump();
    await pumpToStandings(tester);

    await shareAndFail(tester);

    final actual = tester.widget<SnackBar>(find.byType(SnackBar));
    // Fill alone proves nothing here — the hand-rolled version already used
    // the same Coral. The float and the pill are what only the primitive
    // supplies, so they are what distinguishes adoption from coincidence.
    expect(actual.backgroundColor, reference.backgroundColor);
    expect(actual.behavior, reference.behavior);
    expect(actual.shape, reference.shape);
    expect(tester.takeException(), isNull);
  });
}
