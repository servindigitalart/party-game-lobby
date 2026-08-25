// test/golden/golden_harness.dart
//
// Fase 2B WP9 — the deterministic fixture the visual baseline is recorded
// against. Everything a golden could drift on is pinned here, once, so the
// test file stays a list of components and states rather than a list of
// setup.

import 'package:bufon_flutter/core/theme/bufon_phase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The surface every golden is recorded on.
///
/// Logical pixels, at a device pixel ratio of 1, so a recorded PNG is the same
/// number of pixels as the layout is logical units and a diff is readable at
/// a glance. Wide enough that none of the five components hits its overflow
/// path (`TimerWidget` is the widest, with three flexible children) and tall
/// enough that nothing is clipped.
const Size kGoldenSurface = Size(400, 200);

/// The one register the baseline is recorded in.
///
/// Deliberately singular. Every one of these components resolves its colours
/// from `context.phase`, so recording all five in all registers would multiply
/// the artefact count by the register count for no additional protection:
/// *that* resolution is already asserted directly in `phase_scope_test.dart`.
/// What a golden protects is the composition — geometry, weight, spacing,
/// the painted arc — and that is register-independent. Answering is the
/// register the loop spends most of its time in.
const BufonPhase kGoldenPhase = BufonPhase.answering;

/// Registers the bundled brand face and the Material icon font with the test
/// renderer.
///
/// `flutter test` renders every glyph with its placeholder font unless the
/// real faces are loaded explicitly, which would make a typography baseline
/// worthless — a weight or family regression is exactly the kind of change
/// these goldens exist to catch. The files come from the asset bundle the
/// test runner already builds (`build/unit_test_assets/`), declared in
/// `pubspec.yaml`; nothing new is added to ship.
Future<void> loadGoldenFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await load('PlusJakartaSans', const [
    'assets/fonts/PlusJakartaSans-400.ttf',
    'assets/fonts/PlusJakartaSans-600.ttf',
    'assets/fonts/PlusJakartaSans-700.ttf',
  ]);
  // Two of the five components draw a Material glyph (`RoundIndicator`'s
  // gamepad, `TimerWidget`'s clock). Without this they record as tofu boxes.
  await load('MaterialIcons', const ['fonts/MaterialIcons-Regular.otf']);
}

/// Mounts [child] on the fixed surface, in the fixed register, and settles it.
///
/// Fresh-mounts only. None of the five components animates on mount — every
/// controller in `AnimatedPrimaryButton`, `GameCard` and `TimerWidget` is
/// driven from a gesture or from `didUpdateWidget` — so a mount plus a settle
/// lands on a stable frame. Reaching a state by *updating* a mounted widget
/// would be a different matter: `GameCard.didUpdateWidget` fires a haptic and
/// `TimerWidget`'s fires a sound, so each state is built as its own mount
/// instead.
Future<void> pumpGolden(WidgetTester tester, Widget child) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = kGoldenSurface;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        // Pinned rather than inherited: a golden recorded at the runner's
        // ambient text scale would move the moment that default changed.
        // Large-text behaviour has its own suite in `large_text_layout_test`.
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: PhaseScope(
          phase: kGoldenPhase,
          child: Scaffold(
            body: Center(
              // A Column, not a bare Center. `Center` passes bounded
              // constraints down, and every one of these components is a
              // Container with an `alignment` set — which expands to fill
              // whatever it is given, so a bare Center recorded a 168 px tall
              // button. In production they all sit in a Column, whose
              // children get unbounded vertical extent and shrink-wrap. This
              // reproduces the production constraint, not a convenient one.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(padding: const EdgeInsets.all(16), child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Asserts the mounted surface against `goldens/[name].png`.
Future<void> expectGolden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);
