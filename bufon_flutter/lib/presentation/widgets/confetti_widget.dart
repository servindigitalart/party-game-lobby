import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/reduced_motion.dart';

/// Celebration particles.
///
/// Fase 2A changes, all from BUFON_DESIGN_SYSTEM.md:
/// - **Brand palette** (Capítulo 21). The engine was still throwing the
///   retired casino colours — gold `#FFD700`, red `#E94560`, cyan `#00D9FF`
///   and three unrelated pastels — so the loudest moment in the game was the
///   least on-brand thing in it. The doc specifies a Butter-weighted mix.
/// - **A density/duration parameter** (Capítulo 22/32). Both call sites used
///   to fire 50 particles, which made the Ganador de la Noche visually
///   identical to a round win and flattened the three-tier intensity ladder
///   the doc exists to protect. See [ConfettiTier].
/// - **Reduce motion** (Capítulo 28): a full-screen particle storm is a known
///   vestibular trigger, so it is skipped entirely when the platform asks.
/// - Repainting is driven by an `AnimatedBuilder` rather than a `setState`
///   listener, so the frame loop no longer rebuilds this subtree 60×/second.
///
/// The simulation itself — per-particle velocity, gravity, rotation, one
/// `CustomPainter` — is preserved intact.
enum ConfettiTier {
  /// Ganador de ronda: 50 particles over 3s (Capítulo 22).
  round(count: 50, duration: Duration(seconds: 3)),

  /// Ganador de la noche: the only moment allowed to scale up.
  night(count: 90, duration: Duration(milliseconds: 4500));

  const ConfettiTier({required this.count, required this.duration});

  final int count;
  final Duration duration;
}

class ConfettiWidget extends StatefulWidget {
  final bool isActive;
  final ConfettiTier tier;

  const ConfettiWidget({
    super.key,
    required this.isActive,
    this.tier = ConfettiTier.round,
  });

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.tier.duration, vsync: this);

    if (widget.isActive) {
      _startConfetti();
    }
  }

  @override
  void didUpdateWidget(ConfettiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tier != oldWidget.tier) {
      _controller.duration = widget.tier.duration;
    }
    if (widget.isActive && !oldWidget.isActive) {
      _startConfetti();
    }
  }

  void _startConfetti() {
    _particles.clear();
    for (int i = 0; i < widget.tier.count; i++) {
      _particles.add(
        ConfettiParticle(
          x: _random.nextDouble(),
          y: -0.1,
          color: _brandColor(),
          size: _random.nextDouble() * 8 + 4,
          velocityX: (_random.nextDouble() - 0.5) * 2,
          velocityY: _random.nextDouble() * 3 + 2,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 4,
        ),
      );
    }
    _controller.forward(from: 0);
  }

  /// Capítulo 21's weighted mix: 40% Butter — the brand's own colour, so the
  /// celebration reads as Bufón's rather than as generic confetti — and 15%
  /// each of the four semantic accents.
  Color _brandColor() {
    final roll = _random.nextDouble();
    if (roll < 0.40) return AppColors.butter;
    if (roll < 0.55) return AppColors.mint;
    if (roll < 0.70) return AppColors.sky;
    if (roll < 0.85) return AppColors.lavender;
    return AppColors.coral;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Capítulo 28: a full-screen particle storm has no reduced version worth
    // showing — the celebration is still carried by colour, copy and haptic.
    if (!widget.isActive || context.reduceMotion) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class ConfettiParticle {
  double x;
  double y;
  final Color color;
  final double size;
  final double velocityX;
  final double velocityY;
  double rotation;
  final double rotationSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.velocityX,
    required this.velocityY,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final x = particle.x * size.width + particle.velocityX * progress * 100;
      final y = particle.y * size.height + particle.velocityY * progress * 150;

      if (y > size.height) continue;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: 1 - progress * 0.5)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + particle.rotationSpeed * progress);

      // Draw confetti as small rectangles
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 1.5,
          ),
          const Radius.circular(2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}
