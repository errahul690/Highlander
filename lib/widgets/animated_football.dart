import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An animated spinning football with a subtle athletic bounce.
class AnimatedFootball extends StatefulWidget {
  const AnimatedFootball({
    super.key,
    this.size = 18,
    this.color = Colors.white,
    this.enableBounce = true,
  });

  final double size;
  final Color color;
  final bool enableBounce;

  @override
  State<AnimatedFootball> createState() => _AnimatedFootballState();
}

class _AnimatedFootballState extends State<AnimatedFootball>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * 2 * math.pi;
        final bounce = widget.enableBounce
            ? math.sin(_controller.value * 4 * math.pi).abs() * -2.0
            : 0.0;
        return Transform.translate(
          offset: Offset(0, bounce),
          child: Transform.rotate(
            angle: angle,
            child: Icon(
              Icons.sports_soccer,
              size: widget.size,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}
