import 'package:flutter/material.dart';

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

  /// Push and remove all previous routes
  Future<T?> pushAndRemoveAllFadeSlide<T>(Widget page) {
    return Navigator.of(
      this,
    ).pushAndRemoveUntil<T>(FadeSlidePageRoute(page: page), (route) => false);
  }
}
