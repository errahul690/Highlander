import 'package:flutter/material.dart';

/// The shared lightning VS artwork for match cards and the live popup.
class MatchVersus extends StatelessWidget {
  const MatchVersus({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 70,
    height: 96,
    child: CustomPaint(painter: _HeroVersus()),
  );
}

class _HeroVersus extends CustomPainter {
  const _HeroVersus();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .73, 0)
        ..lineTo(size.width * .35, size.height * .56)
        ..lineTo(size.width * .5, size.height * .5)
        ..lineTo(size.width * .22, size.height)
        ..lineTo(size.width * .66, size.height * .4)
        ..lineTo(size.width * .49, size.height * .46)
        ..close(),
      Paint()..color = const Color(0xFFE7003C),
    );
    final text = TextPainter(
      text: const TextSpan(
        text: 'VS',
        style: TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 38,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
    );
    text.dispose();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
