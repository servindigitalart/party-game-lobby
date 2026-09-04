// test/home_privacy_link_test.dart
//
// R-23's legal half: a Privacy Policy link on Home, opened in the system
// browser via url_launcher. These tests mock url_launcher's platform
// boundary — the same seam the package itself is built around — so no real
// browser launch is attempted, and assert the exact URL Home asks it to
// open.

import 'package:bufon_flutter/core/game_copy.dart';
import 'package:bufon_flutter/main.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  String? lastUrl;
  LaunchOptions? lastOptions;
  bool result = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastUrl = url;
    lastOptions = options;
    return result;
  }
}

void main() {
  late _FakeUrlLauncher fakeLauncher;
  final realLauncher = UrlLauncherPlatform.instance;

  setUp(() {
    fakeLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = realLauncher;
  });

  Widget home() => ProviderScope(
        overrides: [
          currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MyApp(),
      );

  group('R-23 — Privacy Policy link on Home', () {
    testWidgets('Home renders, and the link is present', (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();

      expect(find.text(GameCopy.privacyPolicyLabel), findsOneWidget);
    });

    testWidgets('tapping the link launches exactly the published URL, '
        'in the external browser, with no WebView', (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();

      await tester.ensureVisible(find.text(GameCopy.privacyPolicyLabel));
      await tester.pump();
      await tester.tap(find.text(GameCopy.privacyPolicyLabel));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastUrl, 'https://bufon-privacy.netlify.app');
      expect(fakeLauncher.lastUrl, GameCopy.privacyPolicyUrl);
      expect(fakeLauncher.lastOptions?.mode, PreferredLaunchMode.externalApplication);
      expect(tester.takeException(), isNull);
    });

    testWidgets('existing Home actions are unaffected by the new link',
        (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();

      expect(find.text('Crear Sala'), findsOneWidget);
      expect(find.text('Unirse a Sala'), findsOneWidget);
      expect(find.text(GameCopy.practiceTitle), findsOneWidget);
      expect(find.text(GameCopy.playersRequired), findsOneWidget);
      expect(find.text(GameCopy.privacyPolicyLabel), findsOneWidget);
    });

    testWidgets('the link sits below the season banner, staying tertiary',
        (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();

      double y(Finder f) => tester.getTopLeft(f).dy;
      final linkY = y(find.text(GameCopy.privacyPolicyLabel));

      expect(linkY, greaterThan(y(find.text('Crear Sala'))));
      expect(linkY, greaterThan(y(find.text('Unirse a Sala'))));
      expect(linkY, greaterThan(y(find.text(GameCopy.practiceTitle))));
    });
  });
}
