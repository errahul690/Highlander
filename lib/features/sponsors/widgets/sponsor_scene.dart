import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Stadium photograph, slow drift, breathing lights and a soft sweep.
/// One ticker drives every ambient layer so they stay in sync.
class SponsorScene extends StatefulWidget {
  const SponsorScene({super.key, required this.animate});
  final bool animate;

  @override
  State<SponsorScene> createState() => _SponsorSceneState();
}

class _SponsorSceneState extends State<SponsorScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) {
    if (mounted) setState(() => _elapsed = elapsed);
  });
  Duration _elapsed = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SponsorScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final enabled =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (enabled && !_ticker.isActive) _ticker.start();
    if (!enabled && _ticker.isActive) _ticker.stop();
  }

  double _wave(int periodMs) {
    final t = (_elapsed.inMilliseconds % (periodMs * 2)) / periodMs;
    final saw = t <= 1 ? t : 2 - t;
    return Curves.easeInOutCubic.transform(saw.clamp(0, 1));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drift = _ticker.isActive ? _wave(36000) : 0.0;
    final glow = _ticker.isActive ? _wave(9000) : 0.35;
    final sweep = _ticker.isActive ? _wave(20000) : 0.2;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0A1722)),
          Transform.translate(
            offset: Offset(0, -14 * drift),
            child: Transform.scale(
              scale: 1.03 + (0.07 * drift),
              child: Image.asset(
                'assets/images/match_hero_stadium.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66060A12),
                  Color(0x4A060A12),
                  Color(0x59050A14),
                  Color(0x73050D15),
                  Color(0x99040C14),
                  Color(0xB8010B10),
                ],
                stops: [0, 0.25, 0.4, 0.62, 0.79, 1],
              ),
            ),
          ),
          Positioned(
            top: 250,
            right: -30,
            child: _Glow(
              width: 160,
              height: 120,
              color: const Color(0xFFF9F2D4),
              amount: 0.1 + (0.22 * glow),
            ),
          ),
          Positioned(
            top: 400,
            left: -80,
            child: _Glow(
              width: 180,
              height: 120,
              color: const Color(0xFFDC0634),
              amount: 0.08 + (0.2 * (1 - glow)),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(-80 + (160 * sweep), 0),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-0.2, -1),
                      end: Alignment(0.8, 1),
                      colors: [
                        Color(0x00EDFCFF),
                        Color(0x00EDFCFF),
                        Color(0x21EDFCFF),
                        Color(0x00EDFCFF),
                        Color(0x10EDFCFF),
                        Color(0x00EDFCFF),
                      ],
                      stops: [0, 0.42, 0.48, 0.56, 0.68, 0.78],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.width,
    required this.height,
    required this.color,
    required this.amount,
  });
  final double width, height, amount;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: amount.clamp(0, 1),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0)],
          ),
        ),
      ),
    ),
  );
}
