import 'package:flutter/material.dart';
import 'package:Highlanders/features/sponsors/data/sponsors_repository.dart';
import 'package:Highlanders/features/sponsors/widgets/sponsor_logo_strip.dart';

class SponsorBigScreen extends StatefulWidget {
  const SponsorBigScreen({
    super.key,
    required this.sponsor,
    required this.index,
    required this.count,
    required this.onPrevious,
    required this.onNext,
    required this.animate,
    required this.cardKey,
    this.concealContent = false,
  });

  final Sponsor sponsor;
  final int index;
  final int count;
  final VoidCallback onPrevious, onNext;
  final bool animate;
  final GlobalKey cardKey;
  final bool concealContent;

  @override
  State<SponsorBigScreen> createState() => _SponsorBigScreenState();
}

class _SponsorBigScreenState extends State<SponsorBigScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 9000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSweep();
  }

  @override
  void didUpdateWidget(SponsorBigScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSweep();
  }

  bool get _motion =>
      widget.animate &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  void _syncSweep() {
    if (_motion && !_sweep.isAnimating) _sweep.repeat();
    if (!_motion && _sweep.isAnimating) _sweep.stop();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final number = (widget.index + 1).toString().padLeft(2, '0');
    final total = widget.count.toString().padLeft(2, '0');
    return Semantics(
      container: true,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() < 180) return;
          if (details.primaryVelocity! < 0) {
            widget.onNext();
          } else {
            widget.onPrevious();
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 0, 12),
              child: Row(
                children: [
                  _LiveDot(animate: widget.animate),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'PARTNER SPOTLIGHT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xBDFFFFFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$number / $total',
                    style: const TextStyle(
                      color: Color(0xFFE6E7EE),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _NavButton(
                    tooltip: 'Previous sponsor',
                    icon: Icons.chevron_left_rounded,
                    onPressed: widget.onPrevious,
                  ),
                  const SizedBox(width: 6),
                  _NavButton(
                    tooltip: 'Next sponsor',
                    icon: Icons.chevron_right_rounded,
                    onPressed: widget.onNext,
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (context, child) {
                  return DecoratedBox(
                    key: widget.cardKey,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x6E000000),
                          blurRadius: 48,
                          offset: Offset(0, 22),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: ColoredBox(
                  color: Colors.white,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: widget.concealContent ? 0 : 1,
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
                              padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                              child: AnimatedSwitcher(
                                duration: _motion
                                    ? const Duration(milliseconds: 520)
                                    : Duration.zero,
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                layoutBuilder: (current, previous) => Stack(
                                  fit: StackFit.expand,
                                  alignment: Alignment.center,
                                  children: [
                                    ...previous,
                                    if (current != null) current,
                                  ],
                                ),
                                child: SponsorLogo(
                                  key: ValueKey(
                                    '${widget.sponsor.id}-${widget.sponsor.logo}',
                                  ),
                                  sponsor: widget.sponsor,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                            child: Column(
                              children: [
                                Text(
                                  widget.sponsor.name,
                                  key: const ValueKey('sponsor-name'),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                    letterSpacing: -1.1,
                                    height: 1.14,
                                    color: Color(0xFF181A23),
                                  ),
                                ),
                                if (widget.sponsor.role.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: Text(
                                      widget.sponsor.role.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.7,
                                        height: 1.5,
                                        color: Color(0xFFA70835),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        ),
                      ),
                      if (_sweep.isAnimating)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _sweep,
                              builder: (context, _) {
                                final u = _sweep.value;
                                final visible = u > 0.74 && u < 0.92;
                                final local = visible
                                    ? ((u - 0.74) / 0.18).clamp(0.0, 1.0)
                                    : 0.0;
                                return Opacity(
                                  opacity: visible ? 0.55 : 0,
                                  child: Transform.translate(
                                    offset: Offset(-420 + (840 * local), 0),
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment(-1, -0.4),
                                          end: Alignment(1, 0.4),
                                          colors: [
                                            Color(0x00FFFFFF),
                                            Color(0x99FFFFFF),
                                            Color(0x00FFFFFF),
                                          ],
                                          stops: [0.27, 0.48, 0.67],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ),
            // const Padding(
            //   padding: EdgeInsets.fromLTRB(12, 16, 12, 4),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       Icon(
            //         Icons.touch_app_outlined,
            //         size: 15,
            //         color: Color(0x9EFFFFFF),
            //       ),
            //       SizedBox(width: 8),
            //       Flexible(
            //         child: Text(
            //           'Tap any logo above to explore the partner',
            //           textAlign: TextAlign.center,
            //           style: TextStyle(
            //             color: Color(0x9EFFFFFF),
            //             fontSize: 11,
            //             letterSpacing: 0.2,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.animate});
  final bool animate;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void didUpdateWidget(_LiveDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final enabled =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (enabled && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!enabled && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) => Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFFFF315C),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5678).withValues(alpha: 0.45),
            blurRadius: 6 + (10 * _pulse.value),
            spreadRadius: 1 + (3 * _pulse.value),
          ),
        ],
      ),
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: const Color(0x1AFFFFFF),
      shape: const CircleBorder(side: BorderSide(color: Color(0x4DFFFFFF))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 29,
          height: 29,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    ),
  );
}
