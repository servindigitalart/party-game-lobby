// test/blueprint_sweep_test.dart
//
// WP26 — the Blueprint completion sweep's behavioural guards.
//
// Only the items where a meaningful regression is possible are here. The
// dead-file removal (R-26) needs no test: `flutter analyze` is clean and the
// suite is green with the files gone, which is the whole claim.
//
// Each of these fails against the pre-WP26 code:
//
//   R-32  `Season.themeColor` was a raw Firestore int painted directly onto
//         Home — an unconstrained colour-injection path (BP F7)
//   R-38  a room code typed before "Crear Sala" was silently discarded
//         (BP Part IV §1(d))
//   R-34  three routes were still on Flutter's default transition (BP X2)
//   R-24  `NSAllowsArbitraryLoads` disabled ATS app-wide (audit A M-1)

import 'dart:io';

import 'package:bufon_flutter/core/game_copy.dart';
import 'package:bufon_flutter/core/theme/app_colors.dart';
import 'package:bufon_flutter/core/theme/season_accent.dart';
import 'package:bufon_flutter/main.dart';
import 'package:bufon_flutter/models/season.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Season _season(int themeColor) => Season(
  id: 's1',
  name: 'Temporada de Prueba',
  startDate: DateTime(2026),
  endDate: DateTime(2027),
  themeColor: themeColor,
  isActive: true,
  createdAt: DateTime(2026),
);

void main() {
  group('R-32 · a season cannot inject an arbitrary colour', () {
    test('the four accents resolve to themselves', () {
      expect(
        SeasonAccent.fromThemeColor(AppColors.lavender.toARGB32()),
        SeasonAccent.lavender,
      );
      expect(
        SeasonAccent.fromThemeColor(AppColors.sky.toARGB32()),
        SeasonAccent.sky,
      );
      expect(
        SeasonAccent.fromThemeColor(AppColors.mint.toARGB32()),
        SeasonAccent.mint,
      );
      expect(
        SeasonAccent.fromThemeColor(AppColors.coral.toARGB32()),
        SeasonAccent.coral,
      );
    });

    test('an unrecognised int cannot reach the screen as itself', () {
      // The defect, in one line: this value is what the existing season
      // fixture carries, and before WP26 it was painted onto Home's banner
      // verbatim. It is not a Bufón colour and never was.
      const injected = 0xFF7C4DFF;
      final accent = SeasonAccent.fromThemeColor(injected);

      expect(accent, SeasonAccent.lavender);
      expect(accent.color, AppColors.lavender);
      expect(accent.color.toARGB32(), isNot(injected));
    });

    test('every resolved colour is a design-system colour', () {
      const palette = [
        AppColors.lavender,
        AppColors.sky,
        AppColors.mint,
        AppColors.coral,
      ];
      for (final accent in SeasonAccent.values) {
        expect(palette, contains(accent.color), reason: accent.name);
      }
    });

    test('Season exposes the constrained accent, not the raw int', () {
      final season = _season(0xFF7C4DFF);
      // The stored value survives — R-32's non-goal is explicit that this
      // needs no Firestore schema change.
      expect(season.themeColor, 0xFF7C4DFF);
      expect(season.toFirestore()['themeColor'], 0xFF7C4DFF);
      // But what paints is constrained.
      expect(season.accent.color, AppColors.lavender);
    });
  });

  group('R-38 · the room code is no longer silently discarded', () {
    Widget home() => ProviderScope(
      overrides: [
        currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const MyApp(),
    );

    testWidgets('pressing "Crear Sala" with a code typed says so', (
      tester,
    ) async {
      // BP Part IV §1(d): *"typing a code then pressing 'Crear Sala' silently
      // discards it."* Before WP26 the code was dropped with no message and
      // no navigation change — the button simply behaved as though the field
      // were empty.
      await tester.pumpWidget(home());
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Sofía');
      await tester.enterText(find.byType(TextField).last, 'ABCD12');
      await tester.tap(find.text('Crear Sala'));
      await tester.pump();

      expect(find.text(GameCopy.codeIgnoredWhenCreating), findsOneWidget);
    });

    testWidgets('the message clears as soon as the field is edited', (
      tester,
    ) async {
      await tester.pumpWidget(home());
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Sofía');
      await tester.enterText(find.byType(TextField).last, 'ABCD12');
      await tester.tap(find.text('Crear Sala'));
      await tester.pump();
      expect(find.text(GameCopy.codeIgnoredWhenCreating), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '');
      await tester.pump();

      expect(
        find.text(GameCopy.codeIgnoredWhenCreating),
        findsNothing,
        reason: 'the message outlived the problem',
      );
    });
  });

  group('R-34 · the navigation language is complete', () {
    // Source-level, in the same shape as `bufon_component_primitives_test`'s
    // `adoption` group: the claim is about which API every call site uses,
    // and that is a property of the source, not of one rendered frame.
    test('no screen builds a raw MaterialPageRoute', () {
      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        // The transitions file is where the routes are *defined*.
        if (file.path.endsWith('page_transitions.dart')) continue;
        final source = file.readAsStringSync();
        // Strip comments: several files discuss the old routes in prose.
        final code = source
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (code.contains('MaterialPageRoute')) offenders.add(file.path);
      }
      expect(offenders, isEmpty, reason: 'BP X2 — no raw routes remain');
    });
  });

  group('R-24 · ATS is not disabled app-wide', () {
    test('Info.plist carries no blanket exemption', () {
      // audit A M-1. Verified before removal: the app makes no cleartext
      // request of its own — no `http://`, no `Uri.parse`, no emulator host
      // anywhere in `lib/`.
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
      expect(plist, isNot(contains('NSAppTransportSecurity')));
    });
  });
}
