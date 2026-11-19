import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Owns the chat's IME space when Scaffold resizing is disabled.
/// Native incremental inset frames are applied directly. Discrete height jumps
/// get one short animation, without rebuilding the conversation on every tick.
class ChatKeyboardInset extends StatefulWidget {
  const ChatKeyboardInset({super.key, required this.child, this.onSettled});
  final Widget child;
  final VoidCallback? onSettled;

  @override
  State<ChatKeyboardInset> createState() => _ChatKeyboardInsetState();
}

class _ChatKeyboardInsetState extends State<ChatKeyboardInset>
    with SingleTickerProviderStateMixin {
  late final AnimationController _inset = AnimationController.unbounded(
    vsync: this,
  )..addStatusListener(_settled);
  double _target = 0;
  bool _initialized = false;

  void _settled(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        mounted &&
        widget.onSettled != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSettled?.call();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MediaQuery.viewInsetsOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_initialized && next == _target && !reduceMotion) return;
    if (!_initialized || reduceMotion || (next - _inset.value).abs() <= 64) {
      _initialized = true;
      _target = next;
      _inset.stop();
      _inset.value = next;
    } else if (next != _target) {
      _target = next;
      _inset.animateTo(
        next,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _inset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: _inset,
      child: widget.child,
      builder: (context, child) {
        final bottom = math.max(0.0, _inset.value);
        // Hand safe-area space over to the keyboard gradually as it opens.
        final safeBottom = math.max(0.0, media.viewPadding.bottom - bottom);
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: MediaQuery(
            data: media.copyWith(
              viewInsets: media.viewInsets.copyWith(bottom: 0),
              padding: media.padding.copyWith(bottom: safeBottom),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}
