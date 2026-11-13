import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../post_reaction.dart';

/// A short floating-reaction burst anchored to the tapped Like button.
class PostLikeBurst extends StatefulWidget {
  const PostLikeBurst({
    super.key,
    required this.trigger,
    required this.child,
    this.reaction = PostReaction.like,
  });

  final int trigger;
  final Widget child;
  final PostReaction reaction;

  @override
  State<PostLikeBurst> createState() => _PostLikeBurstState();
}

class _PostLikeBurstState extends State<PostLikeBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void didUpdateWidget(PostLikeBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger &&
        !MediaQuery.disableAnimationsOf(context)) {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) {
      final t = _animation.value;
      final pop = t < .24 ? math.sin(t / .24 * math.pi) * .18 : 0.0;
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.scale(scale: 1 + pop, child: child),
          if (_animation.isAnimating)
            Positioned(
              left: -26,
              bottom: 14,
              width: 100,
              height: 128,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Stack(
                    key: const ValueKey('post-like-burst'),
                    clipBehavior: Clip.none,
                    children: [for (var i = 0; i < 6; i++) _particle(i, t)],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _particle(int i, double t) {
    final delay = i * .055;
    final progress = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    final opacity =
        (progress / .12).clamp(0.0, 1.0) *
        ((1 - progress) / .3).clamp(0.0, 1.0);
    const spread = [-20.0, 14.0, -7.0, 34.0, 24.0, -27.0];
    const rise = [82.0, 110.0, 98.0, 75.0, 103.0, 66.0];
    final drift =
        spread[i] * Curves.easeOut.transform(progress) +
        math.sin(progress * math.pi * 2 + i) * 4;
    final diameter = i.isEven ? 22.0 : 19.0;
    return Positioned(
      left: 45 - diameter / 2 + drift,
      bottom: rise[i] * Curves.easeOut.transform(progress),
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: math.sin(progress * math.pi + i) * .18,
          child: Transform.scale(
            scale: .7 + .3 * Curves.easeOut.transform(progress),
            child: Container(
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: PostReactionIcon(
                reaction: widget.reaction,
                size: diameter * .65,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
