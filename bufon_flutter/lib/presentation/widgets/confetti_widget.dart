import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiWidget extends StatefulWidget {
  final bool isActive;
  final Duration duration;

  const ConfettiWidget({
    super.key,
    required this.isActive,
    this.duration = const Duration(seconds: 3),
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
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    if (widget.isActive) {
      _startConfetti();
    }
  }

  @override
  void didUpdateWidget(ConfettiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startConfetti();
    }
  }

  void _startConfetti() {
    _particles.clear();
    for (int i = 0; i < 50; i++) {
      _particles.add(
        ConfettiParticle(
          x: _random.nextDouble(),
          y: -0.1,
          color: _getRandomColor(),
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

  Color _getRandomColor() {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFE94560), // Primary Red
      const Color(0xFF00D9FF), // Cyan
      const Color(0xFFFF6B6B), // Coral
      const Color(0xFF4ECDC4), // Turquoise
      const Color(0xFFFFA07A), // Light Salmon
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(
          particles: _particles,
          progress: _controller.value,
        ),
        size: Size.infinite,
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
