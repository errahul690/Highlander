import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paints the system navigation area above every route in edge-to-edge mode.
class AndroidNavigationBackground extends StatelessWidget {
  const AndroidNavigationBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.android) return child;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (inset > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: inset,
            child: const IgnorePointer(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  systemNavigationBarColor: Colors.black,
                  systemNavigationBarDividerColor: Colors.black,
                  systemNavigationBarIconBrightness: Brightness.light,
                  systemNavigationBarContrastEnforced: false,
                ),
                child: ColoredBox(
                  key: ValueKey('system-navigation-black-background'),
                  color: Colors.black,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
