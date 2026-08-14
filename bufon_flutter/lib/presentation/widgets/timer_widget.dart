import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';
import '../../core/theme/motion_tokens.dart';
import '../../core/theme/reduced_motion.dart';
import '../../services/haptic_service.dart';
import '../../services/sound_service.dart';

/// The answering-phase countdown.
///
/// Fase 2A changes, all from BUFON_DESIGN_SYSTEM.md:
/// - **Brand colour ramp** instead of the legacy cyan/orange/pink: the calm
///   state takes the phase accent (Sky while answering, Capítulo 33) and
///   urgency is Coral, the only colour Capítulo 4 assigns to tension. The
///   step from "warning" to "danger" is deliberately *not* a third colour —
///   Capítulo 28 forbids communicating a state by colour alone, so that step
///   is carried by the pulse, the haptic and the copy instead.
/// - **Escalating haptic** (Capítulo 19, "economía de haptics"): the last
///   second is a `mediumImpact` rather than the fifth identical
///   `lightImpact`, so the body perceives a build-up instead of a repetition.
/// - **Filled glyph** instead of `Icons.timer_outlined` (Capítulo 12/34:
///   never thin Material outline iconography).
/// - **Semantics**: the arc was invisible to assistive technology and the
///   remaining time was never announced.
/// - **Reduce motion** (Capítulo 28).
///
/// The mechanism — custom-painted arc, pulse under 10s, copy that escalates
/// through an `AnimatedSwitcher`, tabular figures — is preserved intact.
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

  /// Seconds at which the remaining time is announced to assistive
  /// technology. Announcing every tick would flood the screen reader and
  /// make the rest of the screen unusable.
  static const _announceAt = {30, 10, 5};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: MotionDurations.pulse,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: MotionScale.pulseUrgent)
        .animate(
          CurvedAnimation(parent: _pulseController, curve: MotionCurves.pulse),
        );
  }

  @override
  void didUpdateWidget(TimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingSeconds != _lastSecond) {
      _lastSecond = widget.remainingSeconds;

      if (widget.remainingSeconds <= 10 && widget.showWarning) {
        _pulseController.forward(from: 0).then((_) {
          if (mounted) _pulseController.reverse();
        });

        if (widget.remainingSeconds <= 5 && widget.remainingSeconds > 0) {
          // Capítulo 19: escalate rather than repeat. The final second is
          // the only one that lands as a medium impact.
          if (widget.remainingSeconds == 1) {
            HapticService.mediumImpact();
          } else {
            HapticService.lightImpact();
          }
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

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;
    final progress = widget.totalSeconds == 0
        ? 0.0
        : widget.remainingSeconds / widget.totalSeconds;
    final isUrgent = widget.remainingSeconds <= 10 && widget.showWarning;
    final timerColor = isUrgent ? AppColors.coral : phase.accent;

    final urgencyCopy = widget.remainingSeconds <= 5
        ? 'Última llamada para soltar la tontería.'
        : widget.remainingSeconds <= 10
        ? 'Ya se siente la presión social.'
        : 'Tiempo para cocinar algo digno.';

    return Semantics(
      // Only a handful of ticks are announced; the rest are silent so the
      // screen reader stays usable while the countdown runs.
      liveRegion: _announceAt.contains(widget.remainingSeconds),
      label: 'Quedan ${widget.remainingSeconds} segundos. $urgencyCopy',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = isUrgent ? _pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: context.motion(full: scale, reduced: 1.0),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: timerColor.withValues(alpha: 0.12),
            borderRadius: AppShapes.borderRadiusMd,
            border: AppShapes.focusBorder(timerColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      painter: _CircularTimerPainter(
                        progress: progress.clamp(0.0, 1.0),
                        color: timerColor,
                      ),
                      size: const Size(44, 44),
                    ),
                    Icon(Icons.timer, color: timerColor, size: 20),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Fase 2B WP4: flexible so the Row cannot overflow at the top of
              // the text-scale band. At most three characters ("90s"), so it
              // never actually ellipsizes at any real scale — this only removes
              // the countdown as a source of overflow pressure.
              Flexible(
                child: Text(
                  '${widget.remainingSeconds}s',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.tabular(
                    AppTypography.h3,
                  ).copyWith(color: timerColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: AnimatedSwitcher(
                  duration: MotionDurations.swap,
                  child: Text(
                    urgencyCopy,
                    key: ValueKey(urgencyCopy),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: phase.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    // Inset by the stroke's half-width so the ring is not clipped by the
    // widget's own bounds.
    final radius = (size.width / 2) - 2;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius, bgPaint);

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
