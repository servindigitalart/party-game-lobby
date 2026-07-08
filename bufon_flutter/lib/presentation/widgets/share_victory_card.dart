// presentation/widgets/share_victory_card.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/theme/app_colors.dart';
import '../../models/avatar.dart';

/// Shareable victory card generator
///
/// Creates a PNG image celebrating a game victory
class ShareVictoryCard extends StatelessWidget {
  final String playerName;
  final String avatarId;
  final int votesReceived;
  final int roundWins;
  final GlobalKey repaintKey;

  const ShareVictoryCard({
    super.key,
    required this.playerName,
    required this.avatarId,
    required this.votesReceived,
    required this.roundWins,
    required this.repaintKey,
  });

  /// Generate PNG bytes from the card
  static Future<Uint8List> generateImage(GlobalKey key) async {
    try {
      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Avatars.all.firstWhere(
      (a) => a.id == avatarId,
      orElse: () => Avatars.all.first,
    );

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 600,
        height: 800,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.backgroundCard,
              AppColors.background,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Confetti effect
            Positioned.fill(child: CustomPaint(painter: _ConfettiPainter())),

            // Radial glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Crown emoji
                  const Text('👑', style: TextStyle(fontSize: 80)),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'BUFÓN DE LA NOCHE',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),

                  // Avatar
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.gold, AppColors.amber],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.6),
                          blurRadius: 50,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        avatar.emoji,
                        style: const TextStyle(fontSize: 120),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Player name
                  Text(
                    playerName,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 50),

                  // Stats
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn(
                          '❤️',
                          '$votesReceived',
                          'Votos',
                          AppColors.primary,
                        ),
                        Container(
                          width: 2,
                          height: 80,
                          color: AppColors.border,
                        ),
                        _buildStatColumn(
                          '🏆',
                          '$roundWins',
                          'Rondas',
                          AppColors.gold,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Message
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '🎭 Maestro del caos y rey del drama 🎭',
                      style: TextStyle(
                        fontSize: 22,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Watermark
                  Opacity(
                    opacity: 0.6,
                    child: Text(
                      'BUFÓN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    String emoji,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Confetti painter for celebration effect
class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      AppColors.primary,
      AppColors.gold,
      AppColors.accent,
      AppColors.success,
    ];

    final paint = Paint()..style = PaintingStyle.fill;

    // Draw confetti pieces
    for (var i = 0; i < 50; i++) {
      final x = (i * 37) % size.width.toInt();
      final y = (i * 53) % size.height.toInt();
      paint.color = colors[i % colors.length].withValues(alpha: 0.6);

      // Random shapes
      if (i % 3 == 0) {
        // Circle
        canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), 8, paint);
      } else if (i % 3 == 1) {
        // Square
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 12, 12),
          paint,
        );
      } else {
        // Triangle
        final path = Path()
          ..moveTo(x.toDouble(), y.toDouble())
          ..lineTo(x + 10.0, y + 15.0)
          ..lineTo(x - 10.0, y + 15.0)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
