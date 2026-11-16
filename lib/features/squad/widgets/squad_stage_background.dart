import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Stadium linework drawn once at the section's size, without web/canvas loading.
class SquadStageBackground extends CustomPainter {
  const SquadStageBackground();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * .62, center = w / 2;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x12F4EFEA);
    for (var i = -8; i <= 8; i++) {
      canvas.drawLine(
        Offset(center + i * w * .03, horizon),
        Offset(center + i * w * .16, h),
        line,
      );
    }
    for (var i = 0; i < 6; i++) {
      final y = horizon + (h - horizon) * math.pow(i / 6, 1.7);
      canvas.drawLine(Offset(0, y), Offset(w, y), line);
    }
    for (var row = 0; row < 9; row++) {
      final base = horizon - 12 - row * h * .045;
      line
        ..color = Color.fromRGBO(244, 239, 234, .05 + .012 * (9 - row))
        ..strokeWidth = row % 3 == 0 ? 1.4 : .8;
      for (var band = 0; band < 2; band++) {
        final path = Path();
        for (var x = -20.0; x <= w + 20; x += 18) {
          final y =
              base +
              math.pow((x - center) / w, 2) * h * .22 +
              math.sin(x * .07 + row + band) * 1.2;
          if (x < 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, line);
      }
      line
        ..color = const Color(0x0DF4EFEA)
        ..strokeWidth = 1;
      for (var x = 8.0; x < w; x += 26) {
        final y = base + math.pow((x - center) / w, 2) * h * .22;
        canvas.drawLine(Offset(x, y), Offset(x + 2, y - h * .03), line);
      }
    }
    for (final fraction in [.07, .93]) {
      final x = w * fraction, y = h * .06, base = horizon - h * .32;
      line
        ..color = const Color(0x1FF4EFEA)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x - 10, base), Offset(x - 3, y + 40), line);
      canvas.drawLine(Offset(x + 10, base), Offset(x + 3, y + 40), line);
      for (var beam = y + 50; beam < base; beam += 22) {
        canvas.drawLine(Offset(x - 9, beam), Offset(x + 9, beam + 16), line);
      }
      canvas.drawRect(Rect.fromLTWH(x - 34, y, 68, 40), line);
      for (var column = 0; column < 4; column++) {
        for (var row = 0; row < 2; row++) {
          canvas.drawCircle(
            Offset(x - 24 + column * 16, y + 12 + row * 16),
            4,
            line,
          );
        }
      }
      final glow = Paint()
        ..shader =
            RadialGradient(
              colors: const [Color(0x16F4EFEA), Colors.transparent],
            ).createShader(
              Rect.fromCircle(center: Offset(x, y + 20), radius: w * .35),
            );
      canvas.drawRect(Offset.zero & size, glow);
    }
    final roof = Path();
    for (var x = 0.0; x <= w; x += 12) {
      final y = horizon - h * .44 + math.pow((x - center) / w, 2) * h * .25;
      if (x == 0) {
        roof.moveTo(x, y);
      } else {
        roof.lineTo(x, y);
      }
    }
    line
      ..color = const Color(0x2EB98A2F)
      ..strokeWidth = 1.2;
    canvas.drawPath(roof, line);
  }

  @override
  bool shouldRepaint(SquadStageBackground oldDelegate) => false;
}

class SquadSlant extends CustomClipper<Path> {
  const SquadSlant({this.onlyRight = false});
  final bool onlyRight;
  @override
  Path getClip(Size size) => Path()
    ..moveTo(onlyRight ? 0 : 8, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - 8, size.height)
    ..lineTo(0, size.height)
    ..close();
  @override
  bool shouldReclip(SquadSlant oldClipper) => oldClipper.onlyRight != onlyRight;
}
