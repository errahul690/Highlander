import 'package:flutter/material.dart';

/// Stadium night sky atmosphere painter with corner spotlights
class NightStadiumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Deep midnight blue gradient background
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F274E), Color(0xFF0B1B36), Color(0xFF061021)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Left floodlight glow
    final leftGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.75),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.38),
          const Color(0xFF38BDF8).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), leftGlow);

    // Right floodlight glow
    final rightGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, -0.75),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.38),
          const Color(0xFF38BDF8).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), rightGlow);

    // Stadium stand arches
    final standPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 3; i++) {
      final y = size.height * 0.32 + (i * 20);
      final path = Path()
        ..moveTo(0, y - 8)
        ..quadraticBezierTo(size.width * 0.5, y + 16, size.width, y - 8);
      canvas.drawPath(path, standPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
