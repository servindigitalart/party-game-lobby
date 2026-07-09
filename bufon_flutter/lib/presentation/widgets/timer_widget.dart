import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/motion_tokens.dart';
import '../../services/sound_service.dart';

class TimerWidget extends StatefulWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final bool showWarning;

  const TimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.showWarning = true,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int? _lastSecond;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: MotionDurations.pulse,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: MotionScale.pulseUrgent).animate(
      CurvedAnimation(parent: _pulseController, curve: MotionCurves.pulse),
    );
  }

  @override
  void didUpdateWidget(TimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingSeconds != _lastSecond) {
      _lastSecond = widget.remainingSeconds;

      if (widget.remainingSeconds <= 10 && widget.showWarning) {
        _pulseController
            .forward(from: 0)
            .then((_) => _pulseController.reverse());

        if (widget.remainingSeconds <= 5 && widget.remainingSeconds > 0) {
          HapticFeedback.lightImpact();
          SoundService.countdownPulse();
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getTimerColor() {
    if (widget.remainingSeconds <= 5) {
      return AppColors.primaryLight;
    } else if (widget.remainingSeconds <= 10) {
      return AppColors.warning;
    }
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.remainingSeconds / widget.totalSeconds;
    final isWarning = widget.remainingSeconds <= 10 && widget.showWarning;
    final urgencyCopy = widget.remainingSeconds <= 5
        ? 'Última llamada para soltar la tontería.'
        : widget.remainingSeconds <= 10
        ? 'Ya se siente la presión social.'
        : 'Tiempo para cocinar algo digno.';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isWarning ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getTimerColor().withValues(alpha: 0.1),
              borderRadius: AppShapes.borderRadiusMd,
              border: AppShapes.focusBorder(
                _getTimerColor().withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circular progress indicator
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    children: [
                      CustomPaint(
                        painter: _CircularTimerPainter(
                          progress: progress,
                          color: _getTimerColor(),
                        ),
                        size: const Size(40, 40),
                      ),
                      Center(
                        child: Icon(
                          Icons.timer_outlined,
                          color: _getTimerColor(),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Time display
                Text(
                  '${widget.remainingSeconds}s',
                  style: AppTypography.tabular(AppTypography.h3).copyWith(
                    color: _getTimerColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: MotionDurations.swap,
                    child: Text(
                      urgencyCopy,
                      key: ValueKey(urgencyCopy),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CircularTimerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularTimerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularTimerPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
