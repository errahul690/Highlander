import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:Highlanders/features/sponsors/data/sponsors_repository.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_logo_strip.dart';

/// The logo and caption scale together from the rail into the spotlight.
class SponsorFlight extends StatefulWidget {
  const SponsorFlight({
    super.key,
    required this.from,
    required this.to,
    required this.sponsor,
    required this.onDone,
  });

  final Rect from;
  final Rect to;
  final Sponsor sponsor;
  final VoidCallback onDone;

  @override
  State<SponsorFlight> createState() => _SponsorFlightState();
}

class _SponsorFlightState extends State<SponsorFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1080),
  )..forward();

  @override
  void initState() {
    super.initState();
    _motion.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Overlay entries need their own text style, matching the spotlight card.
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyMedium!
          .copyWith(decoration: TextDecoration.none),
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_motion.value);
          final pos = Offset.lerp(widget.from.topLeft, widget.to.topLeft, t)!;
          final scale = _lerp(
            math.min(
              widget.from.width / widget.to.width,
              widget.from.height / widget.to.height,
            ),
            1,
            t,
          );
          return IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  width: widget.to.width,
                  height: widget.to.height,
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scale: scale,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(25)),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x6E000000),
                            blurRadius: 48,
                            offset: Offset(0, 22),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFA90534),
                                      Color(0xFFF32C59),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.only(
                                    bottomRight: Radius.circular(7),
                                  ),
                                ),
                                child: SizedBox(width: 101, height: 6),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  22,
                                  22,
                                  16,
                                ),
                                child: SponsorLogo(sponsor: widget.sponsor),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                18,
                                16,
                                22,
                              ),
                              child: _Caption(sponsor: widget.sponsor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _Caption extends StatelessWidget {
  const _Caption({required this.sponsor});
  final Sponsor sponsor;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        sponsor.name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.1,
          height: 1.14,
          color: Color(0xFF181A23),
        ),
      ),
      if (sponsor.role.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            sponsor.role.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFA70835),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.7,
              height: 1.5,
            ),
          ),
        ),
    ],
  );
}
