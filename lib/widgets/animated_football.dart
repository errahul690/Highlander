import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A free kick: the ball curls off a pitch, trails, and hits the net.
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
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.55;
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 3.15,
      height: widget.size * 2.2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _FreeKickPainter(
            t: _controller.value,
            color: widget.color,
            arc: widget.enableBounce ? 1 : 0.55,
          ),
        ),
      ),
    );
  }
}

class _FreeKickPainter extends CustomPainter {
  const _FreeKickPainter({
    required this.t,
    required this.color,
    required this.arc,
  });

  final double t;
  final Color color;
  final double arc;

  @override
  void paint(Canvas canvas, Size size) {
    final ballR = size.height * 0.13;
    final pitch = Rect.fromLTWH(
      size.width * 0.05,
      size.height * 0.52,
      size.width * 0.78,
      size.height * 0.4,
    );
    final mouth = pitch.right - 1;
    final goalTop = pitch.bottom - ballR * 4.6;
    final start = Offset(pitch.left + pitch.width * 0.16, pitch.bottom - ballR);
    final end = Offset(mouth - ballR * 0.15, goalTop + ballR * 2.15);
    final lift = size.height * 0.5 * arc;
    final controlA = Offset(pitch.left + pitch.width * 0.34, start.dy - lift);
    final controlB = Offset(
      pitch.left + pitch.width * 0.68,
      start.dy - lift * 0.72,
    );

    final phase = _phase(t);
    final spot = phase.flight == null
        ? (phase.beforeKick ? start : end)
        : _curve(phase.flight!, start, controlA, controlB, end);
    final spin = (phase.flight ?? (phase.beforeKick ? 0 : 1)) * math.pi * 5.5;
    final air = phase.flight == null ? 0.0 : math.sin(phase.flight! * math.pi);
    final squash = phase.beforeKick
        ? 0.85
        : (phase.flight == null ? (1 - phase.net).clamp(0.0, 1.0) : 0.0);

    _grass(canvas, pitch);
    _markings(canvas, pitch);
    _goal(canvas, pitch, mouth, goalTop, phase.net * ballR * 0.7);
    if (phase.flight != null) {
      _curl(canvas, phase.flight!, start, controlA, controlB, end);
      _trail(canvas, phase.flight!, ballR, start, controlA, controlB, end);
    }
    _shadow(canvas, pitch, spot, ballR, air);
    if (phase.flight == null && !phase.beforeKick) {
      _dust(canvas, end, ballR, phase.net);
    }

    canvas.save();
    canvas.translate(spot.dx, spot.dy - air * ballR * 0.08);
    canvas.scale(1 + air * 0.16 + squash * 0.1, 1 + air * 0.16 - squash * 0.16);
    _ball(canvas, ballR, spin);
    canvas.restore();
    _flag(canvas, pitch);
  }

  _Kick _phase(double time) {
    if (time < 0.1) return const _Kick.before();
    if (time < 0.74) {
      final raw = (time - 0.1) / 0.64;
      return _Kick.flying(Curves.easeInOut.transform(raw));
    }
    return _Kick.hit(((time - 0.74) / 0.26).clamp(0.0, 1.0));
  }

  void _grass(Canvas canvas, Rect pitch) {
    final grass = RRect.fromRectAndRadius(pitch, const Radius.circular(16));
    canvas.drawRRect(
      grass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E9A57), Color(0xFF176B3A)],
        ).createShader(pitch),
    );
    canvas.save();
    canvas.clipRRect(grass);
    final stripe = pitch.width / 7;
    for (var i = 0; i < 7; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(pitch.left + stripe * i, pitch.top, stripe, pitch.height),
        Paint()..color = const Color(0x14FFFFFF),
      );
    }
    canvas.restore();
  }

  void _markings(Canvas canvas, Rect pitch) {
    final line = Paint()
      ..color = const Color(0xD9FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, pitch.height * 0.025);
    canvas.drawLine(
      Offset(pitch.center.dx, pitch.top + 8),
      Offset(pitch.center.dx, pitch.bottom - 8),
      line,
    );
    canvas.drawCircle(pitch.center, pitch.height * 0.22, line);
    canvas.drawCircle(
      pitch.center,
      pitch.height * 0.045,
      Paint()..color = color,
    );
  }

  void _goal(Canvas canvas, Rect pitch, double mouth, double top, double push) {
    final depth = pitch.width * 0.2;
    final back = mouth + depth;
    final post = Paint()
      ..color = const Color(0xFFF4F7F8)
      ..strokeWidth = math.max(2.2, pitch.height * 0.035)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(mouth, pitch.bottom), Offset(mouth, top), post);
    canvas.drawLine(Offset(back, pitch.bottom), Offset(back, top + 8), post);
    canvas.drawLine(Offset(mouth, top), Offset(back, top + 8), post);

    final net = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = top + (pitch.bottom - top) * i / 5;
      canvas.drawPath(
        Path()
          ..moveTo(mouth, y)
          ..quadraticBezierTo(mouth + depth * 0.55 + push, y, back, y + 5),
        net,
      );
    }
    for (var i = 1; i <= 3; i++) {
      final x = mouth + depth * i / 4;
      canvas.drawLine(
        Offset(x + push * 0.35, top + 6),
        Offset(x, pitch.bottom),
        net,
      );
    }
  }

  void _curl(
    Canvas canvas,
    double flight,
    Offset start,
    Offset controlA,
    Offset controlB,
    Offset end,
  ) {
    final path = Path();
    const steps = 28;
    for (var i = 0; i <= steps; i++) {
      final point = _curve(flight * i / steps, start, controlA, controlB, end);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _trail(
    Canvas canvas,
    double flight,
    double ballR,
    Offset start,
    Offset controlA,
    Offset controlB,
    Offset end,
  ) {
    for (var i = 5; i >= 1; i--) {
      final at = flight - i * 0.055;
      if (at <= 0) continue;
      final point = _curve(at, start, controlA, controlB, end);
      canvas.drawCircle(
        point,
        ballR * (0.72 - i * 0.08),
        Paint()..color = Colors.white.withValues(alpha: 0.22 - i * 0.03),
      );
    }
  }

  void _shadow(
    Canvas canvas,
    Rect pitch,
    Offset spot,
    double ballR,
    double air,
  ) {
    final width = ballR * (1.15 - air * 0.45);
    final height = ballR * (0.28 - air * 0.1);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(spot.dx, pitch.bottom - height),
        width: width * 2,
        height: height * 2,
      ),
      Paint()
        ..color = const Color(0x55071A10).withValues(alpha: 0.28 - air * 0.14),
    );
  }

  void _dust(Canvas canvas, Offset end, double ballR, double net) {
    final fade = (1 - net).clamp(0.0, 1.0);
    final dust = Paint()
      ..color = const Color(0xFFF4F1EC).withValues(alpha: 0.7 * fade);
    canvas.drawCircle(
      end + Offset(-ballR * 1.1, ballR * 0.2),
      ballR * 0.16 * fade,
      dust,
    );
    canvas.drawCircle(
      end + Offset(-ballR * 1.5, -ballR * 0.15),
      ballR * 0.1 * fade,
      dust,
    );
  }

  void _flag(Canvas canvas, Rect pitch) {
    final pole = Offset(pitch.left + 8, pitch.top + 4);
    canvas.drawLine(
      pole,
      pole + const Offset(0, 16),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    final wave = math.sin(t * math.pi * 2) * 1.5;
    canvas.drawPath(
      Path()
        ..moveTo(pole.dx, pole.dy)
        ..lineTo(pole.dx + 11, pole.dy + 4 + wave)
        ..lineTo(pole.dx, pole.dy + 8),
      Paint()..color = color,
    );
  }

  void _ball(Canvas canvas, double radius, double spin) {
    canvas.save();
    canvas.rotate(spin);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [Color(0xFFFFFFFF), Color(0xFFE4E6EB), Color(0xFFC4C7CF)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    final panel = Paint()..color = const Color(0xFF1B1E27);
    canvas.drawPath(_polygon(5, radius * 0.34), panel);
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 5 - math.pi / 2);
      canvas.translate(0, -radius * 0.78);
      canvas.drawPath(_polygon(5, radius * 0.26, rotation: math.pi / 5), panel);
      canvas.restore();
    }
    canvas.restore();
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.045
        ..color = const Color(0xFF2C303A),
    );
    canvas.restore();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-radius * 0.28, -radius * 0.32),
        width: radius * 0.5,
        height: radius * 0.26,
      ),
      Paint()..color = const Color(0x73FFFFFF),
    );
  }

  Path _polygon(int sides, double radius, {double rotation = -math.pi / 2}) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = rotation + i * 2 * math.pi / sides;
      final point = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Offset _curve(double u, Offset a, Offset b, Offset c, Offset d) {
    final v = 1 - u;
    return a * (v * v * v) +
        b * (3 * v * v * u) +
        c * (3 * v * u * u) +
        d * (u * u * u);
  }

  @override
  bool shouldRepaint(_FreeKickPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.color != color ||
      oldDelegate.arc != arc;
}

class _Kick {
  const _Kick.before() : flight = null, net = 0, beforeKick = true;
  const _Kick.flying(this.flight) : net = 0, beforeKick = false;
  const _Kick.hit(this.net) : flight = null, beforeKick = false;

  final double? flight;
  final double net;
  final bool beforeKick;
}
