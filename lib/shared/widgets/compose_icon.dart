import 'package:flutter/material.dart';

/// New-chat mark used in Messenger: a rounded square with a pencil
/// crossing out of the top-right corner.
class ComposeIcon extends StatelessWidget {
  const ComposeIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return CustomPaint(
      size: Size.square(size),
      painter: _ComposeIconPainter(iconColor),
    );
  }
}

class _ComposeIconPainter extends CustomPainter {
  const _ComposeIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final square = Path()
      ..moveTo(15.4, 4.8)
      ..lineTo(8, 4.8)
      ..arcToPoint(
        const Offset(4.8, 8),
        radius: const Radius.circular(3.2),
        clockwise: false,
      )
      ..lineTo(4.8, 16)
      ..arcToPoint(
        const Offset(8, 19.2),
        radius: const Radius.circular(3.2),
        clockwise: false,
      )
      ..lineTo(16, 19.2)
      ..arcToPoint(
        const Offset(19.2, 16),
        radius: const Radius.circular(3.2),
        clockwise: false,
      )
      ..lineTo(19.2, 12.6);
    canvas.drawPath(square, stroke);

    final pencil = Path()
      ..moveTo(19.15, 3.35)
      ..lineTo(22.15, 6.35)
      ..lineTo(13.15, 15.35)
      ..lineTo(9.55, 16.15)
      ..lineTo(10.35, 12.55)
      ..close();
    canvas.drawPath(pencil, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ComposeIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
