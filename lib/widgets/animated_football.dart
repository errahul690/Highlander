import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small football tapping the ground while a request is in progress.
class AnimatedFootball extends StatefulWidget {
  const AnimatedFootball({
    super.key,
    this.size = 24,
    this.color = const Color(0xFF20252B),
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
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size * 2,
    height: widget.size * 2,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final lift = widget.enableBounce
            ? math.sin(_controller.value * math.pi)
            : 0.0;
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: widget.size * (0.65 - lift * 0.2),
                height: 3,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Positioned(
              bottom: 4 + lift * widget.size * 0.55,
              child: Icon(
                Icons.sports_soccer,
                size: widget.size,
                color: widget.color,
              ),
            ),
          ],
        );
      },
    ),
  );
}
