// test/golden/component_golden_test.dart

import 'package:bufon_flutter/presentation/widgets/animated_primary_button.dart';
import 'package:bufon_flutter/presentation/widgets/game_card.dart';
import 'package:bufon_flutter/presentation/widgets/game_progress_widgets.dart';
import 'package:bufon_flutter/presentation/widgets/timer_widget.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// Fase 2B WP9 — F5: the visual baseline the recolour work is allowed to be
/// checked against.
///
/// **Scope.** The five components `V1.1_GAP_ANALYSIS.md` §Fase 3B names as the
/// component library: `AnimatedPrimaryButton`, `GameCard`, `TimerWidget`,
/// `RoundIndicator`, `GameProgressBar`. The Blueprint's F5 row says "6 core
/// components" but the document set never enumerates a sixth, so none is
/// invented here — see the WP9 report.
///
/// **What a state has to earn.** One golden per component is the floor. A
/// second exists only where the component takes a *different colour branch*,
/// not merely a different value, and only where production actually renders
/// that branch. Every extra state below cites its production call site.
///
/// **What these protect.** Composition: geometry, spacing, weight, shape,
/// painted geometry, and the fill/foreground pairing each branch resolves.
/// They do not assert semantics, interaction or phase resolution — those have
/// their own suites (`accessibility_test`, `phase_scope_test`) and duplicating
/// them in an image would make the baseline noisier without making it
/// stricter.
void main() {
  setUpAll(loadGoldenFonts);

  group('AnimatedPrimaryButton', () {
    testWidgets('solid — the default fill', (tester) async {
      await pumpGolden(
        tester,
        AnimatedPrimaryButton(text: 'Enviar respuesta', onPressed: () {}),
      );
      await expectGolden(tester, 'animated_primary_button_solid');
    });

    // Separate branch, not a separate value: `isOutline` drops the fill to
    // transparent and repoints the foreground at the accent instead of
    // `onAccent` (animated_primary_button.dart:155-158).
    // Production: home_screen.dart:266, final_winner_screen.dart:288.
    testWidgets('outline — transparent with a hairline', (tester) async {
      await pumpGolden(
        tester,
        AnimatedPrimaryButton(
          text: 'Unirme a una sala',
          onPressed: () {},
          variant: PrimaryButtonVariant.outline,
        ),
      );
      await expectGolden(tester, 'animated_primary_button_outline');
    });

    // Third branch: disabled resolves fill *and* foreground from a different
    // pair entirely (animated_primary_button.dart:160-165), which is the Fase
    // 2A fix that stopped a disabled button painting the legacy dark surface
    // onto a light screen. Worth a baseline precisely because it regressed
    // once already.
    testWidgets('disabled — its own fill and foreground', (tester) async {
      await pumpGolden(
        tester,
        const AnimatedPrimaryButton(text: 'Enviar respuesta'),
      );
      await expectGolden(tester, 'animated_primary_button_disabled');
    });
  });

  group('GameCard', () {
    testWidgets('resting', (tester) async {
      await pumpGolden(
        tester,
        GameCard(text: 'Un pingüino con corbata', onTap: () {}),
      );
      await expectGolden(tester, 'game_card_resting');
    });

    // Selected repaints the fill with the accent and forces the foreground to
    // Ink — the pairing Capítulo 5 requires and that this component got wrong
    // (white on Mint, ≈1.9:1) before Fase 2A. An image is the only thing that
    // catches the two drifting apart again.
    testWidgets('selected — accent fill, Ink foreground', (tester) async {
      await pumpGolden(
        tester,
        GameCard(
          text: 'Un pingüino con corbata',
          onTap: () {},
          isSelected: true,
        ),
      );
      await expectGolden(tester, 'game_card_selected');
    });

    // Production: voting_screen.dart:358 renders the player's own answer this
    // way for the whole voting phase, so it is a state players see every round.
    testWidgets('disabled', (tester) async {
      await pumpGolden(
        tester,
        const GameCard(text: 'Un pingüino con corbata', isDisabled: true),
      );
      await expectGolden(tester, 'game_card_disabled');
    });
  });

  group('TimerWidget', () {
    // Fixed integers, never a clock: the widget takes `remainingSeconds` and
    // `totalSeconds` as plain ints and owns no Timer, so the countdown is the
    // caller's problem and the baseline can pin a single frame.
    testWidgets('normal — accent arc', (tester) async {
      await pumpGolden(
        tester,
        const TimerWidget(remainingSeconds: 45, totalSeconds: 60),
      );
      await expectGolden(tester, 'timer_widget_normal');
    });

    // The urgent branch (`remainingSeconds <= 10 && showWarning`,
    // timer_widget.dart:110) swaps the arc, the icon, the figure, the fill and
    // the border from the register accent to Coral, and swaps the copy. It is
    // also the only state of the only `CustomPainter` in the component layer —
    // `_CircularTimerPainter`'s output is not reachable by any widget finder,
    // so a golden is the only assertion that can see it at all.
    testWidgets('urgent — Coral, and a shorter arc', (tester) async {
      await pumpGolden(
        tester,
        const TimerWidget(remainingSeconds: 7, totalSeconds: 60),
      );
      await expectGolden(tester, 'timer_widget_urgent');
    });
  });

  group('RoundIndicator', () {
    // Stateless, no variants, no branches — one golden is the whole component.
    testWidgets('renders the round pill', (tester) async {
      await pumpGolden(
        tester,
        const RoundIndicator(currentRound: 3, totalRounds: 5),
      );
      await expectGolden(tester, 'round_indicator');
    });
  });

  group('GameProgressBar', () {
    // Mid-game on purpose: at round 3 of 5 the segment loop paints all three
    // of its branches — two completed, one current, two upcoming
    // (game_progress_widgets.dart:105-111) — so one image covers the lot. The
    // current-vs-completed distinction is itself a Fase 2A fix; before it,
    // both painted identically and a player could not see where they were.
    testWidgets('mid-game — all three segment states', (tester) async {
      await pumpGolden(
        tester,
        const GameProgressBar(currentRound: 3, totalRounds: 5),
      );
      await expectGolden(tester, 'game_progress_bar_midgame');
    });
  });
}
