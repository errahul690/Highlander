import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Tap to juggle while waiting; the finishing shot is driven by real readiness.
class StartupFootball extends StatefulWidget {
  const StartupFootball({super.key, required this.ready, this.onFinished});
  final bool ready;
  final VoidCallback? onFinished;
  @override
  State<StartupFootball> createState() => _StartupFootballState();
}

class _StartupFootballState extends State<StartupFootball>
    with TickerProviderStateMixin {
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final _tap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final _shot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Listenable _animation = Listenable.merge([_idle, _tap, _shot]);
  bool _finishing = false;
  double _tapStart = 0;
  double _tapPeak = 0.30;

  double get _tapHeight {
    final t = _tap.value;
    if (t < 0.42) {
      return _tapStart +
          (_tapPeak - _tapStart) * Curves.easeOutCubic.transform(t / 0.42);
    }
    return _tapPeak *
        (1 - Curves.easeInQuad.transform(((t - 0.42) / 0.58).clamp(0.0, 1.0)));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _idle.stop();
    } else if (!_finishing) {
      _idle.repeat();
    }
    if (widget.ready) _finish();
  }

  @override
  void didUpdateWidget(StartupFootball oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    // Finish from the ball's current position instead of snapping to the ground.
    _idle.stop();
    _tap.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shot.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished?.call();
      });
      return;
    }
    try {
      await _shot.forward().orCancel;
      if (mounted) widget.onFinished?.call();
    } on TickerCanceled {
      /* The loading route was closed. */
    }
  }

  void _juggle() {
    if (_finishing) return;
    _tapStart = _tapHeight;
    _tapPeak = math.min(0.42, math.max(0.30, _tapStart + 0.10));
    if (!MediaQuery.disableAnimationsOf(context)) _tap.forward(from: 0);
  }

  @override
  void dispose() {
    _idle.dispose();
    _tap.dispose();
    _shot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.55,
    child: LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final w = box.maxWidth, h = box.maxHeight;
          final shot = Curves.easeInOutCubic.transform(
            (_shot.value / 0.78).clamp(0, 1),
          );
          final idleLift = math.sin(_idle.value * math.pi).abs() * h * 0.10;
          final tapLift = _tapHeight * h;
          final start = Offset(w * 0.25, h * 0.68 - idleLift - tapLift);
          final end = Offset(w * 0.86, h * 0.60);
          final ball =
              Offset.lerp(start, end, shot)! -
              Offset(0, math.sin(shot * math.pi) * h * 0.32);
          final ballSize = (w * 0.17).clamp(40.0, 66.0) * (1 - shot * 0.42);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _Pitch(shot: _shot.value, ball: ball),
                ),
              ),
              Positioned(
                left: ball.dx - 32,
                top: ball.dy - 32,
                width: 64,
                height: 64,
                child: Semantics(
                  button: !_finishing,
                  label: 'Tap football to juggle',
                  child: GestureDetector(
                    key: const ValueKey('startup-ball'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _finishing ? null : _juggle,
                    child: Center(
                      child: Transform.rotate(
                        angle:
                            _idle.value * math.pi * 0.2 +
                            _tap.value * math.pi * 2 +
                            shot * math.pi * 4,
                        child: Container(
                          width: ballSize,
                          height: ballSize,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.sports_soccer,
                            color: clubInk,
                            size: ballSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Pitch extends CustomPainter {
  const _Pitch({required this.shot, required this.ball});
  final double shot;
  final Offset ball;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ground = Rect.fromLTWH(w * 0.03, h * 0.60, w * 0.94, h * 0.27);
    canvas.drawRRect(
      RRect.fromRectAndRadius(ground, const Radius.circular(18)),
      Paint()..color = clubRed.withValues(alpha: 0.045),
    );
    final line = Paint()
      ..color = clubRed.withValues(alpha: 0.20)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.04, h * 0.81),
      Offset(w * 0.98, h * 0.81),
      line,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.33, h * 0.72),
        width: w * 0.29,
        height: h * 0.16,
      ),
      line,
    );
    canvas.drawLine(
      Offset(w * 0.33, h * 0.61),
      Offset(w * 0.33, h * 0.86),
      line,
    );
    final mouth = Rect.fromLTRB(w * 0.64, h * 0.43, w * 0.97, h * 0.77);
    final net = Paint()
      ..color = clubInk.withValues(alpha: 0.13)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final hit = shot < 0.78
        ? 0.0
        : math.sin((shot - 0.78) / 0.22 * math.pi) * w * 0.025;
    for (var i = 1; i < 5; i++) {
      final x = mouth.left + mouth.width * i / 5;
      canvas.drawPath(
        Path()
          ..moveTo(x, mouth.top)
          ..quadraticBezierTo(x + hit, mouth.center.dy, x, mouth.bottom),
        net,
      );
    }
    for (var i = 1; i < 7; i++) {
      final y = mouth.top + mouth.height * i / 7;
      canvas.drawLine(Offset(mouth.left, y), Offset(mouth.right, y), net);
    }
    canvas.drawPath(
      Path()
        ..moveTo(mouth.left, mouth.bottom)
        ..lineTo(mouth.left, mouth.top)
        ..lineTo(mouth.right, mouth.top)
        ..lineTo(mouth.right, mouth.bottom),
      Paint()
        ..color = clubInk
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      mouth.topLeft,
      mouth.topLeft + Offset(w * 0.035, -h * 0.04),
      line,
    );
    canvas.drawLine(
      mouth.topRight,
      mouth.topRight + Offset(w * 0.035, -h * 0.04),
      line,
    );
    canvas.drawLine(
      mouth.topLeft + Offset(w * 0.035, -h * 0.04),
      mouth.topRight + Offset(w * 0.035, -h * 0.04),
      line,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ball.dx, h * 0.80),
        width: w * 0.13,
        height: 6,
      ),
      Paint()
        ..color = clubInk.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    if (shot >= 0.78) {
      final burst = ((shot - 0.78) / 0.22).clamp(0.0, 1.0);
      for (var i = 0; i < 9; i++) {
        final origin =
            mouth.center +
            Offset.fromDirection(i * math.pi * 2 / 9, 20 + burst * 30);
        canvas.drawCircle(
          origin,
          2.5 * (1 - burst),
          Paint()..color = i.isEven ? clubRed : clubBlood,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Pitch oldDelegate) =>
      oldDelegate.shot != shot || oldDelegate.ball != ball;
}
