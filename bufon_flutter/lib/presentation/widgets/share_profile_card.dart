// presentation/widgets/share_profile_card.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/title.dart' as bufon_title;
import '../../models/avatar.dart';

/// Shareable profile card generator
///
/// Creates a PNG image of user's profile for sharing
///
/// Usage:
/// ```dart
/// final bytes = await ShareProfileCard.generateImage(
///   avatar: avatar,
///   level: 5,
///   xp: 1000,
///   ...
/// );
/// ```
class ShareProfileCard {
  ShareProfileCard._(); // Private constructor - static class only

  /// Generate PNG bytes directly without requiring widget tree
  ///
  /// This uses a PictureRecorder to draw the card directly
  static Future<Uint8List> generateImage({
    required Avatar avatar,
    required int level,
    required int xp,
    required int totalWins,
    required int totalVotesReceived,
    required int totalGames,
    bufon_title.BufonTitle? equippedTitle,
  }) async {
    try {
      const double width = 600;
      const double height = 800;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw background
      final bgPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(width, height),
          [
            const Color(0xFF1A1A1A),
            const Color(0xFF2A2A2A),
            const Color(0xFF1A1A1A),
          ],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

      // Draw pattern (simple dots)
      final patternPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.fill;
      for (double x = 0; x < width; x += 40) {
        for (double y = 0; y < height; y += 40) {
          canvas.drawCircle(Offset(x, y), 2, patternPaint);
        }
      }

      // Draw "BUFÓN" header
      final headerParagraph = _buildTextParagraph(
        'BUFÓN',
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFFD700),
        letterSpacing: 4,
        width: width,
        textAlign: TextAlign.center,
      );
      canvas.drawParagraph(headerParagraph, const Offset(0, 40));

      // Draw gold line
      final linePaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(240, 0),
          const Offset(360, 0),
          [const Color(0xFFFFA500), const Color(0xFFFFD700)],
        )
        ..strokeWidth = 3;
      canvas.drawLine(
        const Offset(240, 110),
        const Offset(360, 110),
        linePaint,
      );

      // Draw avatar circle with gradient
      final avatarCirclePaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(300, 130),
          const Offset(300, 330),
          [const Color(0xFFFFA500), const Color(0xFFFFD700)],
        );
      canvas.drawCircle(const Offset(300, 230), 100, avatarCirclePaint);

      // Draw avatar emoji
      final avatarParagraph = _buildTextParagraph(
        avatar.emoji,
        fontSize: 100,
        width: width,
        textAlign: TextAlign.center,
      );
      canvas.drawParagraph(avatarParagraph, const Offset(0, 180));

      // Draw level badge
      final levelBadgeRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(225, 350, 150, 50),
        const Radius.circular(25),
      );
      final levelBadgePaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(225, 350),
          const Offset(375, 350),
          [const Color(0xFFFFA500), const Color(0xFFFFD700)],
        );
      canvas.drawRRect(levelBadgeRect, levelBadgePaint);

      final levelText = _buildTextParagraph(
        'Nivel $level',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        width: 150,
        textAlign: TextAlign.center,
      );
      canvas.drawParagraph(levelText, const Offset(225, 362));

      double yOffset = 420;

      // Draw equipped title if any
      if (equippedTitle != null) {
        final titleBg = RRect.fromRectAndRadius(
          Rect.fromLTWH(50, yOffset, width - 100, 80),
          const Radius.circular(12),
        );
        final titleBgPaint = Paint()
          ..color = Color(equippedTitle.rarity.color).withValues(alpha: 0.2);
        canvas.drawRRect(titleBg, titleBgPaint);

        final titleBorderPaint = Paint()
          ..color = Color(equippedTitle.rarity.color)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRRect(titleBg, titleBorderPaint);

        final titleNamePara = _buildTextParagraph(
          equippedTitle.name,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(equippedTitle.rarity.color),
          width: width - 100,
          textAlign: TextAlign.center,
        );
        canvas.drawParagraph(titleNamePara, Offset(50, yOffset + 15));

        final titleDescPara = _buildTextParagraph(
          equippedTitle.description,
          fontSize: 14,
          color: Colors.grey,
          width: width - 100,
          textAlign: TextAlign.center,
        );
        canvas.drawParagraph(titleDescPara, Offset(50, yOffset + 45));

        yOffset += 100;
      }

      // Draw XP
      final xpPara = _buildTextParagraph(
        'XP: $xp',
        fontSize: 18,
        color: Colors.white70,
        width: width,
        textAlign: TextAlign.center,
      );
      canvas.drawParagraph(xpPara, Offset(0, yOffset));
      yOffset += 40;

      // Draw stats
      final statsPara = _buildTextParagraph(
        '🏆 $totalWins Wins  •  ❤️ $totalVotesReceived Votes  •  🎮 $totalGames Games',
        fontSize: 16,
        color: Colors.white70,
        width: width,
        textAlign: TextAlign.center,
      );
      canvas.drawParagraph(statsPara, Offset(0, yOffset));
      yOffset += 80;

      // Draw CTA
      final ctaPara = _buildTextParagraph(
        'Descarga BUFÓN y demuestra\nque eres más caótico.',
        fontSize: 16,
        color: Colors.white54,
        width: width,
        textAlign: TextAlign.center,
      );
      canvas.drawParagraph(ctaPara, Offset(0, yOffset));

      // Draw logo at bottom
      final logoPara = _buildTextParagraph(
        'BUFÓN',
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
        width: width,
        textAlign: TextAlign.center,
      );
      canvas.drawParagraph(logoPara, const Offset(0, 750));

      // Convert to image
      final picture = recorder.endRecording();
      final img = await picture.toImage(
        (width * 3).toInt(),
        (height * 3).toInt(),
      );
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to generate profile card: $e');
    }
  }

  static ui.Paragraph _buildTextParagraph(
    String text, {
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.white,
    double letterSpacing = 0,
    required double width,
    TextAlign textAlign = TextAlign.left,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: textAlign,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
            ),
          )
          ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: width));
    return paragraph;
  }
}
