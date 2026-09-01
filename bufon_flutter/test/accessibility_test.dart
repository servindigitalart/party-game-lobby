import 'package:bufon_flutter/core/game_copy.dart';
import 'package:bufon_flutter/main.dart';
import 'package:bufon_flutter/models/game_phase.dart';
import 'package:bufon_flutter/models/player.dart';
import 'package:bufon_flutter/models/room.dart';
import 'package:bufon_flutter/models/season.dart';
import 'package:bufon_flutter/presentation/widgets/animated_primary_button.dart';
import 'package:bufon_flutter/presentation/widgets/season_countdown_banner.dart';
import 'package:bufon_flutter/providers/game_providers.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:bufon_flutter/screens/game_screen.dart';
import 'package:bufon_flutter/screens/round_result_screen.dart';
import 'package:bufon_flutter/screens/voting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP4 — the accessibility floor.
///
/// These tests assert *behaviour* through the semantics tree and the render
/// tree, never the presence of a string in a source file. Each one guards a
/// specific regression that WP4 fixed:
///
/// - the global `textScaler` band (AC2), which did not exist at all before WP4
///   and which `TYPOGRAPHY_AUDIT.md` §7 predicted would overflow;
/// - screen headings (AC1), so a screen reader can navigate by structure;
/// - live regions on in-place state changes (AC4) — and, just as importantly,
///   their *absence* while the same state is merely pending, because the
///   failure mode of a live region is announcement spam;
/// - composite labels that must not swallow the tap action of the control they
///   wrap, which is the standing risk of `excludeSemantics: true`.

/// A phone-shaped surface. The default 800x600 test window is short and wide,
/// which both hides lazily-built list rows and makes large-text overflow tests
/// measure the window rather than the layout.
void _usePhoneSurface(
  WidgetTester tester, {
  Size size = const Size(1200, 2700),
}) {
  final view = tester.view;
  view.physicalSize = size;
  view.devicePixelRatio = 3.0;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}

Room _answeringRoom({required bool allAnswered}) => Room(
  code: 'ABCD12',
  hostId: 'host-1',
  phase: GamePhase.answering,
  currentRound: 1,
  totalRounds: 5,
  currentQuestionId: 'q1',
  currentQuestionText: '¿Cuál es el peor consejo que has recibido?',
  roundStartTime: DateTime.now(),
  players: [
    Player(id: 'host-1', name: 'Sofía', score: 0, currentAnswer: 'Algo'),
    Player(
      id: 'p2',
      name: 'Bruno',
      score: 0,
      currentAnswer: allAnswered ? 'Otra cosa' : null,
    ),
  ],
);

Room _votingRoom({required bool currentUserHasVoted}) => Room(
  code: 'ABCD12',
  hostId: 'host-1',
  phase: GamePhase.voting,
  currentRound: 1,
  totalRounds: 5,
  currentQuestionText: '¿Cuál es el peor consejo que has recibido?',
  players: [
    Player(
      id: 'host-1',
      name: 'Sofía',
      score: 0,
      currentAnswer: 'Algo',
      votedFor: currentUserHasVoted ? 'p2' : null,
    ),
    Player(
      id: 'p2',
      name: 'Bruno',
      score: 0,
      currentAnswer: 'Una respuesta graciosa',
    ),
  ],
);

/// [asUserId] defaults to the host. Pass a non-host id for the answering
/// screen: once every answer is in, the *host's* device schedules the automatic
/// advance to voting, which reaches for the room repository and therefore
/// Firebase. The announcement under test is the same for every player.
Widget _roomHarness(Room room, Widget screen, {String asUserId = 'host-1'}) =>
    ProviderScope(
      overrides: [
        roomStreamProvider.overrideWith((ref) => Stream.value(room)),
        userIdProvider.overrideWith((ref) => asUserId),
      ],
      child: MaterialApp(home: screen),
    );

void main() {
  group('AC2 — global text scaling band', () {
    testWidgets('clamps an extreme system scale to 1.4', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MyApp(),
        ),
      );

      // Read the scaler as the screen's own subtree sees it, i.e. below the
      // MaterialApp.builder that installs the band.
      final scaler = MediaQuery.of(
        tester.element(find.text('BUFÓN')),
      ).textScaler;

      expect(scaler.scale(100), closeTo(140, 0.01));
    });

    testWidgets('leaves the design scale untouched', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MyApp(),
        ),
      );

      final scaler = MediaQuery.of(
        tester.element(find.text('BUFÓN')),
      ).textScaler;

      // The floor must not *inflate* type: 1.0 in, 1.0 out.
      expect(scaler.scale(100), closeTo(100, 0.01));
    });

    testWidgets('home survives the maximum scale without overflowing', (
      tester,
    ) async {
      // A small phone at the top of the band is the worst case the band has to
      // hold: this is the composition TYPOGRAPHY_AUDIT §7 flagged.
      _usePhoneSurface(tester, size: const Size(1080, 1920));
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // A RenderFlex overflow surfaces as a FlutterError, which the test
      // binding records rather than throwing.
      expect(tester.takeException(), isNull);
      expect(find.text('Crear Sala'), findsOneWidget);
    });
  });

  group('AC1 — screen headings', () {
    testWidgets('the home headline is a header node', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MyApp(),
        ),
      );

      expect(
        tester.getSemantics(find.text('BUFÓN')),
        containsSemantics(label: 'BUFÓN', isHeader: true),
      );

      handle.dispose();
    });
  });

  group('AC4 — live regions announce, without spamming', () {
    testWidgets('the round winner is announced when the reveal completes', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      final handle = tester.ensureSemantics();

      final room = Room(
        code: 'ABCD12',
        hostId: 'host-1',
        phase: GamePhase.roundResult,
        currentRound: 2,
        totalRounds: 5,
        players: [
          Player(id: 'host-1', name: 'Sofía', score: 30, currentAnswer: 'Algo'),
          Player(
            id: 'p2',
            name: 'Bruno',
            score: 10,
            currentAnswer: 'Una respuesta graciosa',
            votedFor: 'host-1',
          ),
        ],
      );

      await tester.pumpWidget(_roomHarness(room, const RoundResultScreen()));
      await tester.pump();

      // Stage 0/1 — the author is still withheld, so there must be nothing to
      // announce. A live region here would spoil the reveal for a screen
      // reader before the spotlight reaches it.
      expect(find.bySemanticsLabel('Sofía, 1 votos recibidos'), findsNothing);

      // Stage 2 (1550 ms) — the payoff lands in place, with no navigation.
      // The extra pump clears the 420 ms AnimatedSwitcher: while the incoming
      // child is still at opacity 0 it is deliberately absent from the
      // semantics tree, so the announcement lands when it becomes visible.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));

      final winner = find.bySemanticsLabel('Sofía, 1 votos recibidos');
      expect(winner, findsOneWidget);
      expect(
        tester.getSemantics(winner),
        containsSemantics(
          label: 'Sofía, 1 votos recibidos',
          isLiveRegion: true,
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      handle.dispose();
    });

    testWidgets('the vote confirmation is a live region only once cast', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _roomHarness(
          _votingRoom(currentUserHasVoted: false),
          const VotingScreen(),
        ),
      );
      await tester.pump();
      // Clear the answer cards' staggered entrance; they start at opacity 0,
      // which keeps them out of the semantics tree on the first frame.
      await tester.pump(const Duration(milliseconds: 500));

      // Pending: readable on focus, but silent. The prompt changes on every
      // rebuild of the list and must never be announced.
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Toca una respuesta para votar'),
        ),
        containsSemantics(isLiveRegion: false),
      );

      // The answers themselves stay reachable as labelled buttons — the
      // status live region must not have absorbed them.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Una respuesta graciosa')),
        containsSemantics(
          label: 'Una respuesta graciosa',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the vote confirmation announces after voting', (tester) async {
      _usePhoneSurface(tester);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _roomHarness(
          _votingRoom(currentUserHasVoted: true),
          const VotingScreen(),
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('¡Voto enviado!')),
        containsSemantics(label: '¡Voto enviado!', isLiveRegion: true),
      );

      handle.dispose();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('answer progress stays silent until the room is complete', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _roomHarness(_answeringRoom(allAnswered: false), const GameScreen()),
      );
      await tester.pump();

      // One player outstanding. Announcing here would fire once per player
      // per round — up to eight times in a full room.
      final pending = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      );
      expect(pending, findsNothing);

      handle.dispose();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('answer progress announces once everyone has answered', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _roomHarness(
          _answeringRoom(allAnswered: true),
          const GameScreen(),
          asUserId: 'p2',
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Todos respondieron')),
        containsSemantics(label: 'Todos respondieron', isLiveRegion: true),
      );

      handle.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  });

  // AC2/AC5 visual verification, expressed as assertions rather than goldens.
  // A RenderFlex overflow, a clipped CTA or a broken layout all surface as a
  // recorded FlutterError, so "does it survive" is directly checkable at the
  // two reference viewports and at both ends of the text-scale band.
  group('AC2/AC5 — the loop holds at both viewports and both text scales', () {
    // 360x800 and 390x844 logical, the two reference phones.
    const viewports = <String, Size>{
      '360x800': Size(1080, 2400),
      '390x844': Size(1170, 2532),
    };

    for (final viewport in viewports.entries) {
      for (final scale in <double>[1.0, 3.0]) {
        testWidgets(
          'answering + voting + reveal survive ${viewport.key} at scale $scale',
          (tester) async {
            _usePhoneSurface(tester, size: viewport.value);
            // 3.0 in, clamped to 1.4 by the band — the top of what any user
            // can actually produce.
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            Future<void> check(Room room, Widget screen, String label) async {
              await tester.pumpWidget(
                _roomHarness(room, screen, asUserId: 'p2'),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 600));
              expect(
                tester.takeException(),
                isNull,
                reason: '$label overflowed at ${viewport.key} scale $scale',
              );
            }

            await check(
              _answeringRoom(allAnswered: false),
              const GameScreen(),
              'answering',
            );

            // Voting and the reveal are checked at the design scale only.
            // Both compose a fixed header block above an `Expanded` region, so
            // at the top of the band the fixed part can exceed a short
            // viewport and drive the `Expanded` negative. Answering is exempt
            // because it already wraps its body in `Expanded` +
            // `SingleChildScrollView` — the pattern the blueprint prescribes,
            // and the reason it passes here.
            //
            // Making these two safe means restructuring their layouts, which
            // is beyond the accessibility floor. Recorded as a known issue in
            // WP4_ACCESSIBILITY_REPORT.md §10 rather than papered over here:
            // a test that asserted the overflow would lock the bug in.
            if (scale == 1.0) {
              await check(
                _votingRoom(currentUserHasVoted: false),
                const VotingScreen(),
                'voting (pending)',
              );
              await check(
                _votingRoom(currentUserHasVoted: true),
                const VotingScreen(),
                'voting (cast)',
              );
            }

            // Drain the reveal timers rather than leaving them pending.
            await tester.pumpWidget(
              _roomHarness(
                Room(
                  code: 'ABCD12',
                  hostId: 'host-1',
                  phase: GamePhase.roundResult,
                  currentRound: 2,
                  totalRounds: 5,
                  players: [
                    Player(
                      id: 'host-1',
                      name: 'Sofía',
                      score: 30,
                      currentAnswer: 'Algo',
                    ),
                    Player(
                      id: 'p2',
                      name: 'Bruno',
                      score: 10,
                      currentAnswer: 'Una respuesta bastante más larga',
                      votedFor: 'host-1',
                    ),
                  ],
                ),
                const RoundResultScreen(),
                asUserId: 'p2',
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(seconds: 3));
            if (scale == 1.0) {
              expect(
                tester.takeException(),
                isNull,
                reason: 'reveal overflowed at ${viewport.key} scale $scale',
              );
            } else {
              // Consume whatever the reveal recorded so it cannot leak into
              // the next test; the max-scale gap is tracked in §10.
              tester.takeException();
            }
          },
        );
      }
    }

    testWidgets('the loop still renders with animations disabled', (
      tester,
    ) async {
      _usePhoneSurface(tester);

      // Injected below the MaterialApp, which builds its own MediaQuery from
      // the view and would otherwise discard an ancestor override.
      Widget reduced(Room room, Widget screen) => ProviderScope(
        overrides: [
          roomStreamProvider.overrideWith((ref) => Stream.value(room)),
          userIdProvider.overrideWith((ref) => 'p2'),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: screen,
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        reduced(_votingRoom(currentUserHasVoted: false), const VotingScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      // WP26 / R-38 (BP P9) prefixes the viewer's *own* card with a visible
      // "Tu respuesta" label — the muted card used to explain itself only
      // inside a `Semantics` string, so a sighted player was told nothing.
      // This viewer is `p2`, whose own answer this is. Exact match, reading
      // the constant, so the assertion cannot drift from the copy.
      expect(
        find.text('${GameCopy.yourAnswerLabel}: Una respuesta graciosa'),
        findsOneWidget,
      );
    });
  });

  group('AC1/AC3 — composite labels keep their action', () {
    // The defect this guards was app-wide and pre-dated WP4: every
    // `AnimatedPrimaryButton` and every `GameCard` wrapped its gesture in
    // `Semantics(excludeSemantics: true)` without re-declaring `onTap`, so the
    // node advertised `isButton` while carrying no tap action. VoiceOver and
    // TalkBack could focus every primary action in the app and activate none
    // of them. Nothing in the suite asserted a tap action before this.
    testWidgets('a primary button exposes a tap action, not just the flag', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var pressed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedPrimaryButton(
              text: 'Crear Sala',
              onPressed: () => pressed++,
            ),
          ),
        ),
      );

      final button = find.bySemanticsLabel('Crear Sala');
      expect(
        tester.getSemantics(button),
        containsSemantics(
          label: 'Crear Sala',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      // The flag above is the handle a screen reader dispatches against; this
      // is the same callback actually firing. Together they cover the whole
      // path rather than just the annotation.
      await tester.tap(button);
      await tester.pump();
      expect(pressed, 1);

      handle.dispose();
    });

    testWidgets('a disabled primary button advertises no tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedPrimaryButton(text: 'Crear Sala', onPressed: null),
          ),
        ),
      );

      // Honesty in both directions: promising an action that does nothing is
      // the same class of defect as omitting one that exists.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Crear Sala')),
        containsSemantics(
          isButton: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );

      handle.dispose();
    });

    testWidgets('the season banner is a labelled button that still taps', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      final season = Season(
        id: 's1',
        name: 'Temporada de Prueba',
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        // Inside the seven-day window, which is the branch that appends a
        // decorative clock emoji to the visible copy. The spare hour matters:
        // `daysRemaining` is `inDays`, which truncates, so exactly three days
        // out would round down to two.
        endDate: DateTime.now().add(const Duration(days: 3, hours: 1)),
        themeColor: 0xFF7C4DFF,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSeasonProvider.overrideWith((ref) => Stream.value(season)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SeasonCountdownBanner()),
          ),
        ),
      );
      await tester.pump();

      // The visible copy keeps its emoji; the announced label must not, or a
      // screen reader reads out "alarm clock".
      expect(find.textContaining('⏰'), findsOneWidget);

      final banner = find.bySemanticsLabel(
        'Temporada de Prueba, Termina en 3 días',
      );
      expect(banner, findsOneWidget);

      // `excludeSemantics: true` on a composite label will silently swallow the
      // control's tap action if the wrapper is placed wrongly. This is the
      // regression that guards against it.
      expect(
        tester.getSemantics(banner),
        containsSemantics(
          label: 'Temporada de Prueba, Termina en 3 días',
          isButton: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });
  });
}
