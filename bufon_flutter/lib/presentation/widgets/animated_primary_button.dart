import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/motion_tokens.dart';
import '../../services/sound_service.dart';

class AnimatedPrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  /// Disabled-state background color. Defaults to the legacy
  /// `AppColors.surfaceDark` so the three pre-existing consumers
  /// (voting/game/final_winner screens) keep their exact current look.
  /// Pass an explicit value on a migrated (light-mode) screen, where the
  /// legacy dark surface would look like a stray dark box.
  final Color? disabledBackgroundColor;

  /// Disabled-state label color. Defaults to the legacy
  /// `AppColors.textSecondary` for the same reason as
  /// [disabledBackgroundColor].
  final Color? disabledForegroundColor;

  final double? width;
  final EdgeInsets? padding;

  const AnimatedPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.width,
    this.padding,
  });

  @override
  State<AnimatedPrimaryButton> createState() => _AnimatedPrimaryButtonState();
}

class _AnimatedPrimaryButtonState extends State<AnimatedPrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MotionDurations.pressButton,
      vsync: this,
    );
    // BRAND PHYSICS "Compresión y Resorte": compress fast into the touch
    // (forward, on tap-down), release with a small overshoot back to rest
    // (reverse, on tap-up/cancel) — asymmetric on purpose, see Capítulo
    // BRAND PHYSICS in BUFON_DESIGN_SYSTEM.md.
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: MotionScale.pressStrong,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: MotionCurves.compress,
        reverseCurve: MotionCurves.release,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _controller.forward();
      HapticFeedback.lightImpact();
      SoundService.tap();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: MotionDurations.settleButton,
              width: widget.width,
              padding:
                  widget.padding ??
                  const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
              decoration: BoxDecoration(
                gradient: isDisabled
                    ? null
                    : LinearGradient(
                        colors: [
                          widget.backgroundColor ?? AppColors.primary,
                          (widget.backgroundColor ?? AppColors.primary)
                              .withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isDisabled
                    ? (widget.disabledBackgroundColor ?? AppColors.surfaceDark)
                    : null,
                borderRadius: AppShapes.borderRadiusMd,
                boxShadow: isDisabled || _isPressed
                    ? AppElevation.ambient
                    : AppElevation.protagonistShadow(
                        widget.backgroundColor ?? AppColors.primary,
                      ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.textColor ?? Colors.white,
                        ),
                      ),
                    )
                  else ...[
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: widget.textColor ?? Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      widget.text,
                      style: AppTypography.button.copyWith(
                        color: isDisabled
                            ? (widget.disabledForegroundColor ??
                                  AppColors.textSecondary)
                            : (widget.textColor ?? Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
