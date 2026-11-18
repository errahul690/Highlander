import 'package:flutter/material.dart';

/// Editorial headline. The full line is always laid out, so typing never
/// changes the height of the page.
class SponsorHero extends StatefulWidget {
  const SponsorHero({super.key, required this.animate});
  final bool animate;

  @override
  State<SponsorHero> createState() => _SponsorHeroState();
}

class _SponsorHeroState extends State<SponsorHero>
    with SingleTickerProviderStateMixin {
  static const _lineOne = 'ON THE BOARDS.';
  static const _lineTwo = 'IN THE ';
  static const _fight = 'FIGHT.';
  static const _cycle = 13000.0;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 13000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SponsorHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final enabled =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (enabled) {
      if (!_clock.isAnimating) _clock.repeat();
    } else if (_clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typing = _clock.isAnimating;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width * 0.14,
        0,
        20,
        22,
      ),
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final time = typing ? _clock.value * _cycle : 8000.0;
          final fade = _groupFade(time);
          final pulse = _pulse(time);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const _Eyebrow(),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                label: 'On the boards. In the fight.',
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (pulse > 0)
                          Positioned(
                            left: 20,
                            top: 8,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: pulse * 0.55,
                                child: const SizedBox(
                                  width: 220,
                                  height: 90,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0x3DFF3967),
                                          Color(0x00FF3967),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Opacity(
                            opacity: fade,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _typedLine(
                                    _lineOne,
                                    _visible(_lineOne, time, 280, 68),
                                  ),
                                  const SizedBox(height: 2),
                                  _secondLine(time),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: _copyOpacity(time),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "They believed before the trophies.\nThey're here for every ninety minutes.",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Color(0xD6FFFFFF),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFF32C59),
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                      child: SizedBox(width: 46, height: 4),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _visible(String text, double time, double start, double step) {
    if (time <= start) return 0;
    return ((time - start) / step).floor().clamp(0, text.length);
  }

  double _letterT(double time, double start) {
    if (time <= start) return 0;
    return ((time - start) / 420).clamp(0, 1);
  }

  Widget _secondLine(double time) {
    final lead = _visible(_lineTwo, time, 1500, 64);
    final fightStart = 1500.0 + (_lineTwo.length * 64) + 160;
    final shownFight = _visible(_fight, time, fightStart, 72);
    final paint = ((time - fightStart) / 640).clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        const Opacity(opacity: 0, child: Text('IN THE FIGHT.', style: _style)),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < lead; i++)
              _Letter(_lineTwo[i], _letterT(time, 1500 + (i * 64))),
            _FightMark(
              shown: shownFight,
              paint: Curves.easeOutCubic.transform(paint),
              time: time,
              start: fightStart,
            ),
          ],
        ),
      ],
    );
  }

  Widget _typedLine(String text, int count) {
    final time = _clock.isAnimating ? _clock.value * _cycle : 8000.0;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Opacity(opacity: 0, child: Text(text, style: _style)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              _Letter(text[i], _letterT(time, 280 + (i * 68))),
          ],
        ),
      ],
    );
  }

  double _groupFade(double time) {
    if (time < 11600) return 1;
    if (time > 12600) return 0;
    return 1 - Curves.easeInOutCubic.transform((time - 11600) / 1000);
  }

  double _copyOpacity(double time) {
    const start = 2680.0;
    if (time < start) return 0;
    if (time < start + 800) {
      return Curves.easeOutCubic.transform((time - start) / 800);
    }
    return _groupFade(time);
  }

  double _pulse(double time) {
    const start = 2500.0;
    if (time < start || time > start + 760) return 0;
    final u = (time - start) / 760;
    if (u < 0.35) return Curves.easeOut.transform(u / 0.35);
    return 1 - Curves.easeIn.transform((u - 0.35) / 0.65);
  }
}

const _style = TextStyle(
  fontFamily: 'Montserrat',
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w900,
  fontSize: 30,
  height: 1.05,
  letterSpacing: -1.8,
  color: Colors.white,
);

// class _Eyebrow extends StatelessWidget {
//   const _Eyebrow();

//   @override
//   Widget build(BuildContext context) => const FittedBox(
//     fit: BoxFit.scaleDown,
//     alignment: Alignment.centerLeft,
//     child: Row(
//       children: [
//         DecoratedBox(
//           decoration: BoxDecoration(
//             color: Color(0xFFE61A47),
//             boxShadow: [BoxShadow(color: Color(0x66FF466E), blurRadius: 12)],
//           ),
//           child: SizedBox(width: 23, height: 2),
//         ),
//         SizedBox(width: 9),
//         Text(
//           'OUR PARTNERS',
//           style: TextStyle(
//             color: Color(0xDEF6F8FB),
//             fontSize: 10,
//             fontWeight: FontWeight.w800,
//             letterSpacing: 1.4,
//           ),
//         ),
//         SizedBox(width: 8),
//         Text(
//           '/',
//           style: TextStyle(
//             color: Color(0xFFFF5379),
//             fontSize: 13,
//             fontWeight: FontWeight.w400,
//           ),
//         ),
//         SizedBox(width: 8),
//         Text(
//           'NORTHEAST UNITED FC',
//           style: TextStyle(
//             color: Color(0xDEF6F8FB),
//             fontSize: 10,
//             fontWeight: FontWeight.w800,
//             letterSpacing: 1.4,
//           ),
//         ),
//       ],
//     ),
//   );
// }

class _Letter extends StatelessWidget {
  const _Letter(this.char, this.t);
  final String char;
  final double t;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(t);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 8),
        child: Transform.scale(
          scale: 0.92 + (0.08 * eased),
          alignment: Alignment.bottomCenter,
          child: Text(char, style: _style),
        ),
      ),
    );
  }
}

class _FightMark extends StatelessWidget {
  const _FightMark({
    required this.shown,
    required this.paint,
    required this.time,
    required this.start,
  });
  final int shown;
  final double paint;
  final double time;
  final double start;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.bottomLeft,
      transform: Matrix4.skewX(-0.14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.diagonal3Values(paint, 1, 1),
              child: const ColoredBox(color: Color(0xFFEB0A3C)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 7, 1),
            child: Transform(
              alignment: Alignment.bottomLeft,
              transform: Matrix4.skewX(0.14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _SponsorHeroState._fight.length; i++)
                    Opacity(
                      opacity: i < shown ? 1 : 0,
                      child: _Letter(
                        _SponsorHeroState._fight[i],
                        i < shown
                            ? Curves.easeOutCubic.transform(
                                ((time - (start + (i * 72))) / 420).clamp(0, 1),
                              )
                            : 0,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
