import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bufon_flutter/core/game_copy.dart';
import 'package:bufon_flutter/presentation/widgets/share_victory_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fase 2B WP7 — the card that leaves the app.
///
/// `ShareVictoryCard` declared a `600x800` frame around a composition whose
/// fixed children need 1190 px inside a 720 px content box. It overflowed by
/// 470 px, and because the PNG is captured from the boundary at the frame's
/// declared size, **every victory card ever shared was missing those 470 px** —
/// the stats block, the message and the watermark. It went unnoticed for so
/// long because nothing had ever mounted the widget.
///
/// These tests assert the two things that were actually broken: that the card
/// lays out clean, and that the content which used to fall outside the capture
/// is inside it. The export path is exercised for real — `toImage` through the
/// same `RepaintBoundary` the share flow uses — rather than inferred from the
/// absence of an overflow.
void main() {
  /// The frame the card declares, and the ratio the exported PNG carries.
  const frame = Size(600, 800);

  /// The share flow captures at 3.0 (`final_winner_screen._shareVictoryCard`).
  const capturePixelRatio = 3.0;

  final cardKey = GlobalKey();

  Widget harness() => MaterialApp(
    home: Scaffold(
      // Unconstrained so the card is measured at its own declared size rather
      // than squeezed by a phone-sized viewport — the same situation the real
      // off-screen render path creates.
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: ShareVictoryCard(
            repaintKey: cardKey,
            playerName: 'Sofía',
            avatarId: 'default',
            votesReceived: 4,
            roundWins: 30,
          ),
        ),
      ),
    ),
  );

  testWidgets('lays out at its declared frame with no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ShareVictoryCard)), frame);
  });

  testWidgets('exports a valid PNG at exactly the captured size', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // `toImage` and the PNG codec are real async work; the fake clock inside
    // `testWidgets` never completes them, so the capture has to run outside it.
    late Uint8List bytes;
    late ui.Image decoded;
    await tester.runAsync(() async {
      bytes = await ShareVictoryCard.generateImage(cardKey);
      decoded = await decodeImageFromList(bytes);
    });

    // A real PNG, not merely non-null: the 8-byte signature.
    expect(
      bytes.sublist(0, 8),
      equals(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      ),
      reason: 'the capture path must still produce PNG bytes',
    );

    // Decoded dimensions are exactly the frame at the share flow's pixel
    // ratio. This is the assertion that would have failed had the frame been
    // grown to fit the content instead of the content scaled into the frame.
    expect(decoded.width, (frame.width * capturePixelRatio).round());
    expect(decoded.height, (frame.height * capturePixelRatio).round());
    decoded.dispose();
  });

  testWidgets('the content that used to be clipped is inside the capture', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final cardRect = tester.getRect(find.byType(ShareVictoryCard));

    // Everything below the 720 px mark used to fall outside the boundary.
    // These are, in order, the stats block's two labels, the message and the
    // brand watermark — precisely what was missing from every shared card.
    for (final finder in <Finder>[
      find.text('Votos'),
      find.text('Rondas'),
      find.text('🎭 Maestro del caos y rey del drama 🎭'),
      find.text('BUFÓN'),
    ]) {
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder);
      expect(
        cardRect.contains(rect.topLeft) && cardRect.contains(rect.bottomRight),
        isTrue,
        reason:
            '${(finder as dynamic).toString()} sits outside the captured frame '
            '($rect vs $cardRect)',
      );
    }
  });

  group('the share text tells the truth about who won', () {
    test('the winner claims the title', () {
      expect(
        GameCopy.shareVictory(isWinner: true, winnerName: 'Sofía'),
        contains('Soy el Bufón de la Noche'),
      );
    });

    test('everyone else reports it instead of claiming it', () {
      final witness = GameCopy.shareVictory(
        isWinner: false,
        winnerName: 'Sofía',
      );

      // The defect this guards against: a non-winner posting the winner's
      // first-person claim, which is what the single hardcoded string did.
      expect(witness, isNot(contains('Soy el')));
      expect(witness, contains('Sofía'));
      expect(witness, contains('Bufón de la Noche'));
    });

    test('the two are not the same string', () {
      expect(
        GameCopy.shareVictory(isWinner: true, winnerName: 'Sofía'),
        isNot(GameCopy.shareVictory(isWinner: false, winnerName: 'Sofía')),
      );
    });
  });
}
