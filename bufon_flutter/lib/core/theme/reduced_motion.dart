// core/theme/reduced_motion.dart

import 'package:flutter/widgets.dart';

/// Reduce-motion support — implements BUFON_DESIGN_SYSTEM.md v1.1,
/// Capítulo 28: "Respetar `MediaQuery.disableAnimations`/reduce motion: todo
/// `Pulse`/`Reveal` debe tener una versión reducida (cross-fade simple)
/// cuando el sistema lo pide."
///
/// This is deliberately a read-only helper, not a motion system. Bufón
/// already has one (`motion_tokens.dart`); this only answers the question
/// "should that motion play at full amplitude right now?" so each existing
/// animation can pick its own reduced path instead of a global switch turning
/// motion off everywhere.
extension ReducedMotion on BuildContext {
  /// True when the platform asks for reduced motion.
  ///
  /// Reads both signals Flutter exposes: `disableAnimations` (iOS "Reduce
  /// Motion", Android "Remove animations") and `accessibleNavigation` (a
  /// screen reader is driving the UI, where decorative motion is noise at
  /// best and interferes with focus at worst).
  bool get reduceMotion {
    final media = MediaQuery.maybeOf(this);
    if (media == null) return false;
    return media.disableAnimations || media.accessibleNavigation;
  }

  /// [full] normally, [reduced] when the platform asks for reduced motion.
  ///
  /// Used for durations and scale factors so a call site reads as one
  /// expression instead of an `if` around every animation:
  ///
  /// ```dart
  /// scale: context.motion(full: pulseValue, reduced: 1.0)
  /// ```
  T motion<T>({required T full, required T reduced}) =>
      reduceMotion ? reduced : full;
}
