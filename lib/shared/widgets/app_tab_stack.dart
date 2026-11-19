import 'package:flutter/material.dart';
import 'package:Highlanders/core/theme/app_motion.dart';

/// Keeps tab state while only painting the active tab and its outgoing frame.
class AppTabStack extends StatefulWidget {
  const AppTabStack({super.key, required this.index, required this.children})
    : assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;

  @override
  State<AppTabStack> createState() => _AppTabStackState();
}

class _AppTabStackState extends State<AppTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: appMotionDuration,
    value: 1,
  )..addStatusListener(_finished);
  late final Animation<double> _fade = _controller.drive(
    CurveTween(curve: appMotionCurve),
  );
  int? _previous;

  void _finished(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previous != null) {
      setState(() => _previous = null);
    }
  }

  @override
  void didUpdateWidget(AppTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _previous = null;
      _controller.value = 1;
    } else {
      _previous = oldWidget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (var i = 0; i < widget.children.length; i++)
        Offstage(
          offstage: i != widget.index && i != _previous,
          child: IgnorePointer(
            ignoring: i != widget.index,
            child: ExcludeFocus(
              excluding: i != widget.index,
              child: ExcludeSemantics(
                excluding: i != widget.index,
                child: TickerMode(
                  enabled: i == widget.index,
                  child: FadeTransition(
                    opacity: i == widget.index
                        ? _fade
                        : ReverseAnimation(_fade),
                    child: RepaintBoundary(child: widget.children[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
