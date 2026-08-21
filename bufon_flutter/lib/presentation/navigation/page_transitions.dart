import 'package:flutter/material.dart';
import '../../core/theme/motion_tokens.dart';

/// Backward/retreat transition — a plain fade with no slide.
///
/// Capítulo 23: "Las transiciones de salida/retroceso (salir de una sala,
/// volver a Home) usan un fade simple sin slide, para que se sientan
/// claramente distintas de 'avanzar en el juego'." Before Fase 2A every
/// navigation that existed used the same forward fade+slide, so leaving a
/// room felt identical to advancing a round.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadePageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: MotionDurations.arrive,
        reverseTransitionDuration: MotionDurations.arrive,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: MotionCurves.settle,
            ),
            child: child,
          );
        },
      );
}

/// Custom page route with fade + slide transition
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final Curve curve;
  final Offset beginOffset;

  FadeSlidePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeInOut,
    this.beginOffset = const Offset(0.0, 0.05),
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           // Fade animation
           final fadeAnimation = Tween<double>(
             begin: 0.0,
             end: 1.0,
           ).animate(CurvedAnimation(parent: animation, curve: curve));

           // Slide animation
           final slideAnimation = Tween<Offset>(
             begin: beginOffset,
             end: Offset.zero,
           ).animate(CurvedAnimation(parent: animation, curve: curve));

           return FadeTransition(
             opacity: fadeAnimation,
             child: SlideTransition(position: slideAnimation, child: child),
           );
         },
       );
}

/// Navigation helpers
extension NavigationExtensions on BuildContext {
  /// Push with fade + slide transition
  Future<T?> pushFadeSlide<T>(Widget page) {
    return Navigator.of(this).push<T>(FadeSlidePageRoute(page: page));
  }

  /// Replace with fade + slide transition
  Future<T?> replaceFadeSlide<T>(Widget page) {
    return Navigator.of(
      this,
    ).pushReplacement<T, void>(FadeSlidePageRoute(page: page));
  }

  // There is no forward whole-stack push. `pushAndRemoveAllFadeSlide` used to
  // sit here and was, until Fase 2B WP6, what every exit actually called —
  // which is why leaving a room animated exactly like advancing a round.
  // Clearing the entire stack only ever happens on the way back to Home, and
  // that is a retreat by definition, so the forward variant had no legitimate
  // case left once [pushAndRemoveAllFade] was adopted.

  /// Replace with a retreat transition (fade only) — see [FadePageRoute].
  Future<T?> replaceFade<T>(Widget page) {
    return Navigator.of(
      this,
    ).pushReplacement<T, void>(FadePageRoute(page: page));
  }

  /// Replace the whole stack with a retreat transition — leaving a room or
  /// finishing a night, as opposed to advancing through one.
  Future<T?> pushAndRemoveAllFade<T>(Widget page) {
    return Navigator.of(
      this,
    ).pushAndRemoveUntil<T>(FadePageRoute(page: page), (route) => false);
  }
}
