import 'package:flutter/material.dart';

const appMotionDuration = Duration(milliseconds: 220);
const appMotionCurve = Curves.easeOutCubic;

/// A short entrance over the existing page; no full-screen zoom or scrim.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final eased = animation.drive(CurveTween(curve: Curves.easeInOutCubic));
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.035, 0),
          end: Offset.zero,
        ).animate(eased),
        textDirection: Directionality.of(context),
        child: RepaintBoundary(child: child),
      ),
    );
  }
}
