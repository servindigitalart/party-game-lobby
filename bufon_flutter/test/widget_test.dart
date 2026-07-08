import 'package:bufon_flutter/main.dart';
import 'package:bufon_flutter/providers/season_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Home screen renders the core room actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSeasonProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.text('BUFÓN'), findsOneWidget);
    expect(find.text('Crear Sala'), findsOneWidget);
    expect(find.text('Unirse a Sala'), findsOneWidget);
  });
}
