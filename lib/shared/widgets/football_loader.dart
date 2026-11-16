import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Native animation from design/loaders/highlanders-one-touch-goal-loader.html.
class FootballLoader extends StatefulWidget {
  const FootballLoader({
    super.key,
    this.size = 360,
    this.showBackground = true,
  });
  final double size;
  final bool showBackground;
  static const background = Color(0xFF180911);
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF230C19), Color(0xFF160911), Color(0xFF10080E)],
    stops: [0, .55, 1],
  );
  @override
  State<FootballLoader> createState() => _FootballLoaderState();
}

class _FootballLoaderState extends State<FootballLoader>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = .3;
    } else {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: widget.size,
      height: widget.size * 325 / 400,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: widget.showBackground ? FootballLoader.gradient : null,
          ),
          child: FittedBox(
            child: CustomPaint(
              size: const Size(400, 325),
              painter: _OneTouchPitch(_motion),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OneTouchPitch extends CustomPainter {
  _OneTouchPitch(this.motion) : super(repaint: motion);
  final Animation<double> motion;
  static const white = Color(0xFFFFF0EC), orange = Color(0xFFFFB55F);
  double between(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0, 1);
  Path polygon(List<Offset> p) => Path()..addPolygon(p, true);
  void line(Canvas c, Path p, Color color, double width) => c.drawPath(
    p,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
  void dash(
    Canvas c,
    Path p,
    Color color,
    double width,
    double length,
    double gap,
    double phase,
  ) {
    for (final m in p.computeMetrics()) {
      for (
        var x = -phase % (length + gap) - length - gap;
        x < m.length;
        x += length + gap
      ) {
        final a = x.clamp(0.0, m.length), b = (x + length).clamp(0.0, m.length);
        if (b > a) line(c, m.extractPath(a, b), color, width);
      }
    }
  }

  void pulse(
    Canvas c,
    Offset point,
    double t,
    double start,
    double peak,
    double end,
  ) {
    if (t < start || t > end) return;
    final p = Curves.easeOut.transform(between(t, start, end));
    final opacity = t < peak
        ? between(t, start, peak)
        : 1 - between(t, peak, end);
    c.drawCircle(
      point,
      13 * (.15 + p * 2.45),
      Paint()
        ..color = orange.withValues(alpha: opacity * .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  void paint(Canvas c, Size size) {
    final t = motion.value;
    const halo = Rect.fromLTWH(31, 30, 338, 276);
    c.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6F48).withValues(alpha: .2),
            const Color(0xFFEF2745).withValues(alpha: .08),
            Colors.transparent,
          ],
          stops: const [0, .6, 1],
        ).createShader(halo),
    );
    final pitch = polygon(const [
      Offset(127, 71),
      Offset(273, 71),
      Offset(357, 291),
      Offset(43, 291),
    ]);
    c.drawPath(
      pitch,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x27542031), Color(0x1079253A)],
        ).createShader(const Rect.fromLTWH(43, 71, 314, 220)),
    );
    line(c, pitch, const Color(0xFFFF8F92).withValues(alpha: .3), 1.5);
    final details = Path()
      ..moveTo(110, 118)
      ..lineTo(290, 118)
      ..moveTo(68, 241)
      ..lineTo(332, 241)
      ..addPath(
        polygon(const [
          Offset(150, 71),
          Offset(250, 71),
          Offset(270, 135),
          Offset(130, 135),
        ]),
        Offset.zero,
      )
      ..addPath(
        polygon(const [
          Offset(179, 71),
          Offset(221, 71),
          Offset(229, 104),
          Offset(171, 104),
        ]),
        Offset.zero,
      )
      ..addOval(const Rect.fromLTWH(162, 220, 76, 42))
      ..moveTo(159, 135)
      ..quadraticBezierTo(200, 170, 241, 135);
    line(c, details, white.withValues(alpha: .27), 1.2);
    c.drawCircle(
      const Offset(200, 241),
      2,
      Paint()..color = white.withValues(alpha: .28),
    );
    final shift = t >= .77 && t <= .89
        ? math.sin(between(t, .77, .89) * math.pi * 3) * 3
        : 0.0;
    c.save();
    c.translate(0, shift);
    final goal = Path()
      ..moveTo(168, 70)
      ..lineTo(168, 47)
      ..lineTo(176, 35)
      ..lineTo(224, 35)
      ..lineTo(232, 47)
      ..lineTo(232, 70);
    c.drawPath(goal, Paint()..color = white.withValues(alpha: .045));
    line(c, goal, const Color(0xFFFFE9D9).withValues(alpha: .66), 2);
    final net = Path();
    for (var x = 176; x <= 224; x += 12) {
      net
        ..moveTo(x.toDouble(), 35)
        ..lineTo(x.toDouble(), 69);
    }
    net
      ..moveTo(170, 48)
      ..lineTo(230, 48)
      ..moveTo(170, 57)
      ..lineTo(230, 57);
    line(c, net, white.withValues(alpha: .3), .7);
    line(
      c,
      Path()
        ..moveTo(168, 47)
        ..lineTo(232, 47),
      white.withValues(alpha: .9),
      2.5,
    );
    c.restore();
    final pass = Path()
      ..moveTo(93, 254)
      ..quadraticBezierTo(140, 226, 195, 188)
      ..quadraticBezierTo(238, 204, 302, 255);
    dash(
      c,
      pass,
      const Color(0xFFFFC18D).withValues(alpha: .28),
      1.9,
      7,
      15,
      t * 101.3,
    );
    final shot = Path()
      ..moveTo(302, 255)
      ..quadraticBezierTo(267, 157, 200, 63);
    dash(c, shot, white.withValues(alpha: .18), 1.3, 3, 9, 0);
    if (t >= .57 && t < .86) {
      final opacity = t < .8 ? 1.0 : 1 - between(t, .8, .86);
      for (final m in shot.computeMetrics()) {
        line(
          c,
          m.extractPath(0, m.length * between(t, .57, .8)),
          orange.withValues(alpha: opacity * .8),
          3.5,
        );
      }
    }
    const targets = [Offset(93, 254), Offset(195, 188), Offset(302, 255)];
    for (final point in targets) {
      dash(
        c,
        Path()..addOval(Rect.fromCircle(center: point, radius: 19)),
        orange.withValues(alpha: .22),
        1,
        3,
        6,
        0,
      );
      c.drawCircle(point, 5, Paint()..color = orange.withValues(alpha: .33));
    }
    pulse(c, targets[0], t, 0, .06, .17);
    pulse(c, targets[1], t, .27, .3, .42);
    pulse(c, targets[2], t, .52, .56, .7);
    if (t >= .76 && t <= .89) {
      final p = between(t, .76, .89),
          opacity = t < .8 ? between(t, .76, .8) : 1 - between(t, .8, .89);
      final bounds = Rect.fromCircle(
        center: const Offset(200, 62),
        radius: 25 * (.5 + p * 1.8),
      );
      c.drawOval(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [
              orange.withValues(alpha: opacity * .94),
              const Color(0xFFF14547).withValues(alpha: opacity * .45),
              Colors.transparent,
            ],
            stops: const [0, .42, 1],
          ).createShader(bounds),
      );
    }
    // Keyframes mirror the supplied CSS, including pauses at each touch.
    final frames = <({double at, Offset point, double scale, double alpha})>[
      (at: 0, point: targets[0], scale: 1, alpha: 1),
      (at: .07, point: targets[0], scale: 1, alpha: 1),
      (at: .28, point: targets[1], scale: .91, alpha: 1),
      (at: .32, point: targets[1], scale: .91, alpha: 1),
      (at: .53, point: targets[2], scale: 1, alpha: 1),
      (at: .57, point: targets[2], scale: 1, alpha: 1),
      (at: .79, point: const Offset(200, 63), scale: .43, alpha: 1),
      (at: .84, point: const Offset(200, 63), scale: .31, alpha: 0),
      (at: .85, point: targets[0], scale: .85, alpha: 0),
      (at: .94, point: targets[0], scale: .85, alpha: 0),
      (at: 1, point: targets[0], scale: 1, alpha: 1),
    ];
    for (var i = 1; i < frames.length; i++) {
      if (t > frames[i].at) continue;
      final a = frames[i - 1], b = frames[i], p = between(t, a.at, b.at);
      final point = Offset.lerp(a.point, b.point, p)!,
          scale = a.scale + (b.scale - a.scale) * p,
          alpha = a.alpha + (b.alpha - a.alpha) * p;
      c.drawOval(
        Rect.fromCenter(
          center: point + Offset(0, 14 * scale),
          width: 34 * scale,
          height: 11 * scale,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: .3 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      c.save();
      c.translate(point.dx, point.dy);
      c.scale(scale);
      c.rotate(t * math.pi * 6);
      ball(c, alpha);
      c.restore();
      break;
    }
  }

  void ball(Canvas c, double alpha) {
    c.drawCircle(
      Offset.zero,
      14.5,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: alpha),
            const Color(0xFFF6F4F0).withValues(alpha: alpha),
            const Color(0xFFB6B5BA).withValues(alpha: alpha),
          ],
          stops: const [0, .55, 1],
        ).createShader(const Rect.fromLTWH(-14.5, -14.5, 29, 29)),
    );
    final dark = const Color(0xFF2B2630).withValues(alpha: alpha);
    c.drawPath(
      polygon(const [
        Offset(0, -6.6),
        Offset(6.4, -2.1),
        Offset(4, 5.6),
        Offset(-4, 5.6),
        Offset(-6.4, -2.1),
      ]),
      Paint()..color = dark,
    );
    line(
      c,
      Path()
        ..moveTo(0, -6.6)
        ..lineTo(-2, -14)
        ..moveTo(6.4, -2.1)
        ..lineTo(13, -5)
        ..moveTo(4, 5.6)
        ..lineTo(9.3, 11.5)
        ..moveTo(-4, 5.6)
        ..lineTo(-9.3, 11.5)
        ..moveTo(-6.4, -2.1)
        ..lineTo(-13, -5),
      dark,
      1.7,
    );
    c.drawCircle(
      const Offset(-4, -6),
      4,
      Paint()..color = Colors.white.withValues(alpha: .2 * alpha),
    );
    c.drawCircle(
      Offset.zero,
      14.5,
      Paint()
        ..color = Colors.white.withValues(alpha: .65 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
  }

  @override
  bool shouldRepaint(_OneTouchPitch oldDelegate) =>
      oldDelegate.motion != motion;
}
