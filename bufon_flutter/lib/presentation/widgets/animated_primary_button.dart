import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/bufon_phase.dart';
import '../../core/theme/motion_tokens.dart';
import '../../core/theme/reduced_motion.dart';
import '../../services/haptic_service.dart';
import '../../services/sound_service.dart';

/// Bufón's primary action.
///
/// Fase 2A changes, all from BUFON_DESIGN_SYSTEM.md:
/// - **Flat fill by default** (Capítulo 3 ley 1 / Capítulo 34). The gradient
///   this used to draw on every enabled button was, on its own, most of the
///   16 `LinearGradient` sites the design system caps at 2-3. A gradient is
///   still reachable through [variant] for the one ceremonial moment that
///   earned it (Capítulo 8, capa Ceremonial).
/// - **Pill shape** (Capítulo 9): the primary button echoes the logotype's
///   letterforms, via `AppShapes.borderRadiusFull` — this draws itself with a
///   `BoxDecoration`, so it needs a `BorderRadius`, not a `ShapeBorder`.
/// - **Phase-aware defaults**: with no explicit colour it now takes the
///   screen's register accent instead of the legacy casino red, so an
///   unparameterised instance can no longer render red-on-Paper.
/// - **Semantics**: it was a bare `GestureDetector` wrapping a `Text`, so
///   screen readers saw no button at all.
/// - **Haptics through [HapticService]** instead of calling
///   `HapticFeedback` directly, which is what makes Capítulo 19's haptic
///   economy (coalesce/escalate) possible at all.
/// - **Reduce motion** (Capítulo 28).
/// - **Enforced 48dp+ touch target** (Capítulo 15) rather than relying on
///   padding happening to add up.
///
/// The press mechanism itself is untouched: compress fast into the touch,
/// release with a small overshoot (`BRAND PHYSICS`).
enum PrimaryButtonVariant {
  /// Flat fill. The default for ~every button in the app.
  solid,

  /// Transparent with a hairline border — a secondary action that still
  /// answers the touch with Bufón's own press physics, unlike a bare
  /// `OutlinedButton`.
  outline,

  /// The only gradient the design system allows outside a full-screen
  /// ceremonial background. Reserved for the winner moment.
  ceremonial,
}

class AnimatedPrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final PrimaryButtonVariant variant;

  /// Disabled-state background color. Defaults to a neutral drawn from the
  /// active register, so a disabled button no longer paints the legacy dark
  /// surface onto a light screen.
  final Color? disabledBackgroundColor;

  /// Disabled-state label color.
  final Color? disabledForegroundColor;

  final double? width;
  final EdgeInsets? padding;

  /// Overrides the accessibility label when the visible [text] is not a
  /// useful description on its own.
  final String? semanticLabel;

  const AnimatedPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.variant = PrimaryButtonVariant.solid,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.width,
    this.padding,
    this.semanticLabel,
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: MotionScale.pressStrong)
        .animate(
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

  bool get _isInteractive => widget.onPressed != null && !widget.isLoading;

  void _handleTapDown(TapDownDetails details) {
    if (!_isInteractive) return;
    setState(() => _isPressed = true);
    _controller.forward();
    HapticService.lightImpact();
    SoundService.tap();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isInteractive) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (!_isInteractive) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final phase = context.phase;
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final isOutline = widget.variant == PrimaryButtonVariant.outline;

    final fill = widget.backgroundColor ?? phase.accent;
    final foreground = widget.textColor ?? (isOutline ? fill : phase.onAccent);

    final disabledFill =
        widget.disabledBackgroundColor ??
        (phase.isDark ? AppColors.graphitePlus1 : AppColors.paperLine);
    final disabledForeground =
        widget.disabledForegroundColor ??
        (phase.isDark ? AppColors.inkSoft : AppColors.inkMuted);

    final resolvedForeground = isDisabled ? disabledForeground : foreground;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.semanticLabel ?? widget.text,
      // Fase 2B WP4: the action has to be re-declared here. `excludeSemantics`
      // drops the whole subtree, and the tap action belongs to the
      // `GestureDetector` inside it — so without this the node was announced
      // as a button that VoiceOver/TalkBack could focus but never activate.
      onTap: widget.onPressed,
      // The visible Text is already announced through `label`; letting it
      // through as well makes a screen reader read the button twice.
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              // Capítulo 28: the press still confirms via colour and haptic
              // when the platform asks for reduced motion; only the scale
              // goes away.
              scale: context.motion(full: _scaleAnimation.value, reduced: 1.0),
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: MotionDurations.settleButton,
            width: widget.width,
            constraints: const BoxConstraints(
              minHeight: AppSpacing.buttonHeight,
            ),
            alignment: Alignment.center,
            padding:
                widget.padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
            decoration: BoxDecoration(
              // Capítulo 8: the ceremonial gradient is the only gradient a
              // button may draw, and only for the moment that earned it.
              gradient:
                  widget.variant == PrimaryButtonVariant.ceremonial &&
                      !isDisabled
                  ? AppElevation.ceremonialGradient(
                      fill,
                      Color.lerp(fill, AppColors.graphite, 0.35)!,
                    )
                  : null,
              color: switch (widget.variant) {
                _ when isDisabled => isOutline ? null : disabledFill,
                PrimaryButtonVariant.outline => null,
                PrimaryButtonVariant.solid => fill,
                PrimaryButtonVariant.ceremonial => null,
              },
              border: isOutline
                  ? AppShapes.focusBorder(resolvedForeground)
                  : null,
              borderRadius: AppShapes.borderRadiusFull,
              // Capítulo 8: at most one Protagonist per screen, and never a
              // grey shadow. An outline/disabled/pressed button is Ambiente.
              boxShadow: isDisabled || _isPressed || isOutline
                  ? AppElevation.ambient
                  : AppElevation.protagonistShadow(fill),
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
                      // Capítulo 24: a spinner inside a button takes the
                      // button's own foreground, never a generic white.
                      valueColor: AlwaysStoppedAnimation<Color>(
                        resolvedForeground,
                      ),
                    ),
                  )
                else ...[
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: resolvedForeground, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: AppTypography.button.copyWith(
                        color: resolvedForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
