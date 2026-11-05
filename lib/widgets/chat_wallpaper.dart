import 'dart:async';

import 'package:flutter/material.dart';

import '../chat_background_repository.dart';

/// Light paper wallpaper with a few faint, widely spaced line icons.
class ChatWallpaper extends StatefulWidget {
  const ChatWallpaper({super.key, required this.child});

  final Widget child;

  @override
  State<ChatWallpaper> createState() => _ChatWallpaperState();
}

class _ChatWallpaperState extends State<ChatWallpaper> {
  late final ChatBackgroundRepository _background;

  @override
  void initState() {
    super.initState();
    _background = ChatBackgroundRepository.instance;
    _background.addListener(_changed);
    _background.start();
    unawaited(_background.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _background.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: ChatPaperPainter()),
        if (_background.imageBytes != null)
          Image.memory(
            _background.imageBytes!,
            key: ValueKey('admin-chat-background-${_background.imageUrl}'),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
        widget.child,
      ],
    );
  }
}

class ChatPaperPainter extends CustomPainter {
  const ChatPaperPainter();

  static const _paper = Color(0xFFF8F6F3);
  static const _ink = Color(0xFFD8CFC6);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);

    final wash = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: .7),
              _paper.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .5, size.height * .22),
              radius: size.shortestSide * .95,
            ),
          );
    canvas.drawRect(Offset.zero & size, wash);

    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const cell = 156.0;
    const icon = 28.0;
    var row = 0;
    for (var y = 36.0; y < size.height + icon; y += cell) {
      final shift = row.isOdd ? cell * .48 : 22.0;
      var col = 0;
      for (var x = shift; x < size.width + icon; x += cell) {
        _glyph(canvas, stroke, Offset(x, y), icon, (row * 3 + col) % 6);
        col++;
      }
      row++;
    }
  }

  void _glyph(Canvas canvas, Paint paint, Offset origin, double s, int kind) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    switch (kind) {
      case 0:
        _ball(canvas, paint, s);
      case 1:
        _trophy(canvas, paint, s);
      case 2:
        _shirt(canvas, paint, s);
      case 3:
        _shield(canvas, paint, s);
      case 4:
        _heart(canvas, paint, s);
      default:
        _flag(canvas, paint, s);
    }
    canvas.restore();
  }

  void _ball(Canvas canvas, Paint paint, double s) {
    final c = Offset(s / 2, s / 2);
    canvas.drawCircle(c, s * .46, paint);
    final inner = Path()
      ..moveTo(s * .5, s * .22)
      ..lineTo(s * .68, s * .38)
      ..lineTo(s * .61, s * .62)
      ..lineTo(s * .39, s * .62)
      ..lineTo(s * .32, s * .38)
      ..close();
    canvas.drawPath(inner, paint);
  }

  void _trophy(Canvas canvas, Paint paint, double s) {
    final cup = Path()
      ..moveTo(s * .28, s * .16)
      ..lineTo(s * .72, s * .16)
      ..lineTo(s * .66, s * .48)
      ..quadraticBezierTo(s * .5, s * .64, s * .34, s * .48)
      ..close();
    canvas.drawPath(cup, paint);
    canvas.drawArc(
      Rect.fromLTWH(s * .08, s * .16, s * .28, s * .28),
      1.2,
      2.2,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(s * .64, s * .16, s * .28, s * .28),
      -0.3,
      -2.2,
      false,
      paint,
    );
    canvas.drawLine(Offset(s * .5, s * .58), Offset(s * .5, s * .72), paint);
    canvas.drawLine(Offset(s * .34, s * .78), Offset(s * .66, s * .78), paint);
  }

  void _shirt(Canvas canvas, Paint paint, double s) {
    final shirt = Path()
      ..moveTo(s * .28, s * .22)
      ..lineTo(s * .08, s * .36)
      ..lineTo(s * .18, s * .5)
      ..lineTo(s * .32, s * .42)
      ..lineTo(s * .32, s * .82)
      ..lineTo(s * .68, s * .82)
      ..lineTo(s * .68, s * .42)
      ..lineTo(s * .82, s * .5)
      ..lineTo(s * .92, s * .36)
      ..lineTo(s * .72, s * .22)
      ..quadraticBezierTo(s * .5, s * .38, s * .28, s * .22)
      ..close();
    canvas.drawPath(shirt, paint);
  }

  void _shield(Canvas canvas, Paint paint, double s) {
    final shield = Path()
      ..moveTo(s * .5, s * .12)
      ..lineTo(s * .82, s * .24)
      ..lineTo(s * .82, s * .5)
      ..quadraticBezierTo(s * .82, s * .78, s * .5, s * .9)
      ..quadraticBezierTo(s * .18, s * .78, s * .18, s * .5)
      ..lineTo(s * .18, s * .24)
      ..close();
    canvas.drawPath(shield, paint);
    canvas.drawLine(Offset(s * .5, s * .34), Offset(s * .5, s * .62), paint);
    canvas.drawLine(Offset(s * .36, s * .48), Offset(s * .64, s * .48), paint);
  }

  void _heart(Canvas canvas, Paint paint, double s) {
    final heart = Path()
      ..moveTo(s * .5, s * .78)
      ..cubicTo(s * .08, s * .52, s * .12, s * .22, s * .32, s * .22)
      ..cubicTo(s * .44, s * .22, s * .5, s * .32, s * .5, s * .38)
      ..cubicTo(s * .5, s * .32, s * .56, s * .22, s * .68, s * .22)
      ..cubicTo(s * .88, s * .22, s * .92, s * .52, s * .5, s * .78)
      ..close();
    canvas.drawPath(heart, paint);
  }

  void _flag(Canvas canvas, Paint paint, double s) {
    canvas.drawLine(Offset(s * .28, s * .14), Offset(s * .28, s * .86), paint);
    final flag = Path()
      ..moveTo(s * .28, s * .16)
      ..quadraticBezierTo(s * .48, s * .04, s * .62, s * .2)
      ..quadraticBezierTo(s * .74, s * .34, s * .86, s * .24)
      ..lineTo(s * .86, s * .48)
      ..quadraticBezierTo(s * .7, s * .58, s * .56, s * .42)
      ..quadraticBezierTo(s * .42, s * .28, s * .28, s * .4)
      ..close();
    canvas.drawPath(flag, paint);
  }

  @override
  bool shouldRepaint(ChatPaperPainter oldDelegate) => false;
}
