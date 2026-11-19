import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_style.dart';

class SponsorStadium extends StatelessWidget {
  const SponsorStadium({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topCenter,
        radius: 1.2,
        colors: [Color(0xFF1A1B26), SponsorStyle.night, SponsorStyle.ink],
      ),
    ),
    child: CustomPaint(painter: const _StadiumPainter(), child: child),
  );
}

class _StadiumPainter extends CustomPainter {
  const _StadiumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    for (final right in [false, true]) {
      final x = right ? size.width - 24 : 24.0;
      final beam = Path()
        ..moveTo(x - 10, 8)
        ..lineTo(x + 14, 8)
        ..lineTo(right ? size.width * .25 : size.width * .95, size.height * .9)
        ..lineTo(right ? -size.width * .35 : size.width * .75, size.height * .9)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFFAEB).withValues(alpha: .09),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
      for (var row = 0; row < 2; row++) {
        for (var col = 0; col < 4; col++) {
          final bulb = Rect.fromLTWH(x - 16 + col * 8, 12 + row * 8, 5, 5);
          canvas.drawCircle(
            bulb.center,
            9,
            Paint()
              ..color = const Color(0xFFFFFBE9).withValues(alpha: .2)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(bulb, const Radius.circular(1)),
            Paint()..color = const Color(0xFFFFFBE9),
          );
        }
      }
    }
    for (var row = 0; row < 10; row++) {
      final y = size.height * .47 + row * 10;
      for (var col = 0; col < (size.width / 13).ceil(); col++) {
        final x = col * 13.0 + (row.isOdd ? 6 : 0);
        final opacity = .13 + (math.sin(col * 7 + row * 3) + 1) * .07;
        canvas.drawCircle(
          Offset(x, y),
          2.2,
          Paint()..color = const Color(0xFF646577).withValues(alpha: opacity),
        );
      }
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x00E01F1B), Color(0x18E01F1B)],
          stops: [0, .5, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StadiumPainter oldDelegate) => false;
}

class SponsorPitch extends StatelessWidget {
  const SponsorPitch({super.key, required this.sponsorName});
  final String sponsorName;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 82,
    child: CustomPaint(
      painter: const _PitchPainter(),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'ON THE BOARDS  ',
                  style: SponsorStyle.mono,
                ),
                TextSpan(
                  text: sponsorName.toUpperCase(),
                  style: SponsorStyle.mono.copyWith(
                    color: SponsorStyle.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ),
  );
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = -5; i < 15; i++) {
      final top = i * size.width / 10;
      final bottom = size.width / 2 + (top - size.width / 2) * 1.8;
      canvas.drawPath(
        Path()
          ..moveTo(top, 0)
          ..lineTo(top + size.width / 10, 0)
          ..lineTo(bottom + size.width / 10 * 1.8, size.height)
          ..lineTo(bottom, size.height)
          ..close(),
        Paint()
          ..color = i.isEven
              ? const Color(0xFF1B5530)
              : const Color(0xFF1F5F36),
      );
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, 6), Offset(size.width, 6), line);
    canvas.drawLine(
      Offset(size.width / 2, 6),
      Offset(size.width / 2, size.height),
      line,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, 47),
        width: 90,
        height: 23,
      ),
      line..style = PaintingStyle.stroke,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x110B0B0E), SponsorStyle.ink],
          stops: [0, .96],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}

/// A subtle LED matrix over the white logo surfaces, as on the website boards.
class SponsorLedTexture extends CustomPainter {
  const SponsorLedTexture();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0F000000);
    for (var y = 2.0; y < size.height; y += 4) {
      for (var x = 2.0; x < size.width; x += 4) {
        canvas.drawCircle(Offset(x, y), .55, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SponsorLedTexture oldDelegate) => false;
}
