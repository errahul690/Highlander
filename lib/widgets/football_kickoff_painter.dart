import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A brief kickoff play: pitch reveal, a rolling ball and a shot into the net.
class FootballKickoffPainter extends CustomPainter {
  const FootballKickoffPainter({
    required this.progress,
    this.origin,
    this.foreground = false,
    this.attackRight = true,
  });
  final double progress;
  final Offset? origin;
  final bool foreground;
  final bool attackRight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (!attackRight) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    _paintPlay(canvas, size);
    canvas.restore();
  }

  void _paintPlay(Canvas canvas, Size size) {
    final p = progress;
    final c = origin == null
        ? Offset(size.width / 2, size.height * .34)
        : Offset(
            attackRight ? origin!.dx : size.width - origin!.dx,
            origin!.dy,
          );
    final halfHeight = (size.height * .4).clamp(20.0, 34.0);
    final pitch = Rect.fromLTRB(
      size.width * .025,
      c.dy - halfHeight,
      size.width * .975,
      c.dy + halfHeight,
    );
    if (!foreground) {
      final opacity = math.sin(math.pi * ((p - .02) / .95).clamp(0.0, 1.0));
      final line = Paint()
        ..color = const Color(0xFF62AF81).withValues(alpha: opacity * .42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final outline = Path()
        ..addRRect(RRect.fromRectAndRadius(pitch, const Radius.circular(3)));
      final reveal = Curves.easeOutCubic.transform((p / .35).clamp(0.0, 1.0));
      for (final metric in outline.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * reveal), line);
      }
      if (p > .12) {
        canvas.drawLine(
          Offset(c.dx, pitch.top),
          Offset(c.dx, pitch.bottom),
          line,
        );
        canvas.drawCircle(c, halfHeight * .48, line);
        canvas.drawCircle(c, 1.6, Paint()..color = line.color);
        for (final x in [pitch.left, pitch.right - pitch.width * .1]) {
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              c.dy - halfHeight * .55,
              pitch.width * .1,
              halfHeight * 1.1,
            ),
            line,
          );
        }
      }
      // The right-hand goal flexes when the shot reaches it.
      final goal = Rect.fromLTWH(pitch.right - 10, c.dy - 14, 14, 28);
      final netT = ((p - .79) / .15).clamp(0.0, 1.0);
      final ripple = math.sin(netT * math.pi * 3) * (1 - netT) * 4;
      final net = Paint()
        ..color = const Color(0xFFE6F2EB).withValues(alpha: opacity * .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8;
      canvas.drawPath(
        Path()
          ..moveTo(goal.left, goal.top)
          ..lineTo(goal.right + ripple, goal.top + 3)
          ..lineTo(goal.right + ripple, goal.bottom - 3)
          ..lineTo(goal.left, goal.bottom),
        net,
      );
      for (var i = 1; i < 4; i++) {
        final y = goal.top + i * goal.height / 4;
        canvas.drawPath(
          Path()
            ..moveTo(goal.left, y)
            ..quadraticBezierTo(
              goal.center.dx + ripple,
              y + ripple * .35,
              goal.right + ripple,
              y,
            ),
          net,
        );
        final x = goal.left + i * goal.width / 4;
        canvas.drawPath(
          Path()
            ..moveTo(x, goal.top + 1)
            ..quadraticBezierTo(x + ripple, c.dy, x, goal.bottom - 1),
          net,
        );
      }
      return;
    }
    if (p < .22 || p >= .94) return;
    final radius = (size.height * .13).clamp(7.5, 13.0);
    double x, lift;
    if (p < .49) {
      final t = ((p - .22) / .27).clamp(0.0, 1.0);
      x = -radius + (c.dx + radius) * Curves.easeOutCubic.transform(t);
      lift = math.sin(t * math.pi * 2).abs() * 6 * (1 - t);
    } else if (p < .62) {
      final t = (p - .49) / .13;
      x = c.dx;
      lift = math.sin(t * math.pi) * 5;
    } else {
      final t = ((p - .62) / .2).clamp(0.0, 1.0);
      x = c.dx + (pitch.right - 4 - c.dx) * Curves.easeInQuad.transform(t);
      lift = math.sin(t * math.pi) * halfHeight * .65;
      // A faint curved pass line follows the ball, rather than generic sparks.
      final trace = Path()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo((c.dx + x) / 2, c.dy - halfHeight, x, c.dy - lift);
      canvas.drawPath(
        trace,
        Paint()
          ..color = const Color(0xFF98CBA7).withValues(alpha: (1 - t) * .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
    final alpha =
        ((p - .22) / .06).clamp(0.0, 1.0) *
        (1 - ((p - .84) / .1).clamp(0.0, 1.0));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, c.dy + radius + 2),
        width: radius * 2.1,
        height: radius * .45,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: alpha * .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.save();
    canvas.translate(x, c.dy - lift);
    canvas.rotate(p * math.pi * 11);
    final ball = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.5),
          colors: [
            Colors.white.withValues(alpha: alpha),
            const Color(0xFFD7E0E4).withValues(alpha: alpha),
          ],
          radius: 1.2,
        ).createShader(ball),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFF64727B).withValues(alpha: alpha * .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    final ink = Paint()
      ..color = const Color(0xFF1D2933).withValues(alpha: alpha);
    final pentagon = Path();
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 5;
      final point = Offset(math.cos(angle), math.sin(angle)) * radius * .43;
      i == 0
          ? pentagon.moveTo(point.dx, point.dy)
          : pentagon.lineTo(point.dx, point.dy);
      final edge = Offset(math.cos(angle), math.sin(angle)) * radius * .96;
      canvas.drawLine(
        point,
        edge,
        Paint()
          ..color = ink.color
          ..strokeWidth = .65,
      );
      final patch = Path()
        ..moveTo(edge.dx, edge.dy)
        ..lineTo(
          radius * .7 * math.cos(angle - .25),
          radius * .7 * math.sin(angle - .25),
        )
        ..lineTo(
          radius * .7 * math.cos(angle + .25),
          radius * .7 * math.sin(angle + .25),
        )
        ..close();
      canvas.drawPath(patch, ink);
    }
    canvas.drawPath(pentagon..close(), ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FootballKickoffPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      origin != oldDelegate.origin ||
      attackRight != oldDelegate.attackRight ||
      foreground != oldDelegate.foreground;
}
