import '../brand_colors.dart';
import 'package:flutter/material.dart';

class GroundLocationIcon extends StatelessWidget {
  const GroundLocationIcon({super.key, this.size = 21});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/ground-location.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

/// Thin, rounded line drawings matching the ground facilities artwork.
class GroundFacilityIcon extends StatelessWidget {
  const GroundFacilityIcon({
    super.key,
    required this.name,
    this.icon = 'auto',
    this.iconUrl = '',
    this.color = brandAccent,
  });

  final String name, icon, iconUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = name.toLowerCase();
    final inferred = switch (value) {
      _ when value.contains('track') || value.contains('lane') => 'track',
      _ when value.contains('light') => 'lights',
      _ when value.contains('lounge') || value.contains('vip') => 'lounge',
      _ when value.contains('media') => 'media',
      _ when value.contains('aid') || value.contains('medical') => 'medical',
      _ when value.contains('dope') || value.contains('test') => 'test',
      _ when value.contains('roof') => 'roof',
      _ when value.contains('scoreboard') || value.contains('screen') =>
        'scoreboard',
      _ when value.contains('air-condition') || value.contains('cooling') =>
        'cooling',
      _
          when value.contains('barrier') ||
              value.contains('ramp') ||
              value.contains('lift') =>
        'accessibility',
      _ when value.contains('hostel') || value.contains('accommodation') =>
        'hostel',
      _ when value.contains('practice') || value.contains('warm-up') =>
        'practice',
      _ when value.contains('auditorium') => 'auditorium',
      _ when value.contains('parking') => 'parking',
      _ => '',
    };
    final kind = icon == 'auto' || icon.isEmpty ? inferred : icon;
    Widget preset() {
      const otherIcons = {
        'roof': Icons.roofing_outlined,
        'scoreboard': Icons.scoreboard_outlined,
        'cooling': Icons.ac_unit_outlined,
        'accessibility': Icons.accessible_outlined,
        'hostel': Icons.bed_outlined,
        'practice': Icons.sports_soccer_outlined,
        'auditorium': Icons.theater_comedy_outlined,
        'parking': Icons.local_parking_outlined,
      };
      if (const [
        'track',
        'lights',
        'lounge',
        'media',
        'medical',
        'test',
      ].contains(kind)) {
        return SizedBox.square(
          dimension: 21,
          child: CustomPaint(painter: _FacilityPainter(kind, color)),
        );
      }
      return Icon(
        otherIcons[kind] ?? Icons.check_circle_outline,
        size: 21,
        color: color,
      );
    }

    if (iconUrl.isEmpty) return preset();
    return Image.network(
      iconUrl,
      width: 21,
      height: 21,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => preset(),
    );
  }
}

class _FacilityPainter extends CustomPainter {
  const _FacilityPainter(this.kind, this.color);

  final String kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), pen);
    void box(
      double left,
      double top,
      double right,
      double bottom,
      double radius,
    ) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        Radius.circular(radius),
      ),
      pen,
    );

    switch (kind) {
      case 'track':
        box(1.5, 4, 22.5, 20, 5.5);
        box(4.5, 7, 19.5, 17, 3);
      case 'lights':
        box(3, 2, 21, 13, 0);
        line(9, 2, 9, 13);
        line(15, 2, 15, 13);
        line(3, 7.5, 21, 7.5);
        line(12, 13, 12, 21);
        line(7, 21, 17, 21);
      case 'lounge':
        box(5, 2.5, 19, 15.5, 2);
        canvas.drawPath(
          Path()
            ..moveTo(5, 9.5)
            ..lineTo(2.5, 9.5)
            ..lineTo(2.5, 19)
            ..lineTo(21.5, 19)
            ..lineTo(21.5, 9.5)
            ..lineTo(19, 9.5),
          pen,
        );
        line(5.5, 19, 5.5, 22);
        line(18.5, 19, 18.5, 22);
      case 'media':
        box(2, 5, 15.5, 19, 0);
        canvas.drawPath(
          Path()
            ..moveTo(15.5, 9)
            ..lineTo(22, 5)
            ..lineTo(22, 19)
            ..lineTo(15.5, 15),
          pen,
        );
      case 'medical':
        box(2, 6, 22, 22, 1);
        canvas.drawPath(
          Path()
            ..moveTo(8, 6)
            ..lineTo(8, 2)
            ..lineTo(16, 2)
            ..lineTo(16, 6),
          pen,
        );
        line(12, 10, 12, 18);
        line(8, 14, 16, 14);
      case 'test':
        canvas.drawPath(
          Path()
            ..moveTo(8, 2)
            ..lineTo(16, 2)
            ..moveTo(9, 2)
            ..lineTo(9, 10)
            ..lineTo(3, 20)
            ..quadraticBezierTo(2, 22, 4, 22)
            ..lineTo(20, 22)
            ..quadraticBezierTo(22, 22, 21, 20)
            ..lineTo(15, 10)
            ..lineTo(15, 2),
          pen,
        );
        line(6.5, 16, 17.5, 16);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FacilityPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
