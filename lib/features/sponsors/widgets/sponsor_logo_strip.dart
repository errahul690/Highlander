import 'dart:async';

import 'package:flutter/material.dart';

import 'package:Highlanders/features/sponsors/data/sponsors_repository.dart';

class SponsorLogo extends StatelessWidget {
  const SponsorLogo({super.key, required this.sponsor});
  final Sponsor sponsor;

  @override
  Widget build(BuildContext context) {
    final label = Center(
      child: Text(
        sponsor.name,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w900,
          color: Color(0xFF171923),
          fontSize: 16,
          height: 1.1,
        ),
      ),
    );
    final fallback = sponsor.assetLogo.isEmpty
        ? label
        : Image.asset(
            sponsor.assetLogo,
            fit: BoxFit.contain,
            semanticLabel: '${sponsor.name} logo',
            errorBuilder: (_, _, _) => label,
          );
    if (sponsor.logo.isEmpty) return fallback;
    return Image.network(
      sponsor.logo,
      fit: BoxFit.contain,
      semanticLabel: '${sponsor.name} logo',
      frameBuilder: (_, child, frame, synchronous) =>
          synchronous || frame != null ? child : fallback,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Logo cards. Autoplay advances one card at a time, then rests.
class SponsorLogoStrip extends StatefulWidget {
  const SponsorLogoStrip({
    super.key,
    required this.sponsors,
    required this.selectedId,
    required this.onSelected,
    this.onFly,
    this.departingId,
    this.animate = true,
    this.revealTick = 0,
    this.reverse = false,
  });

  final List<Sponsor> sponsors;
  final String selectedId;
  final ValueChanged<Sponsor> onSelected;
  final void Function(Sponsor sponsor, Rect origin)? onFly;
  final String? departingId;
  final bool animate;
  final int revealTick;
  final bool reverse;

  @override
  State<SponsorLogoStrip> createState() => _SponsorLogoStripState();
}

class _SponsorLogoStripState extends State<SponsorLogoStrip>
    with TickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _gleam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );
  Timer? _auto;
  DateTime _resumeAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _touching = false;
  double _itemExtent = 180;
  int _progress = 0;
  int _revealTick = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateProgress);
    _revealTick = widget.revealTick;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(SponsorLogoStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
    if (widget.revealTick != _revealTick) {
      _revealTick = widget.revealTick;
      _revealSelected();
    }
    if (widget.selectedId != oldWidget.selectedId && _motion) {
      _gleam.forward(from: 0);
    }
  }

  bool get _motion =>
      widget.animate &&
      widget.sponsors.length > 1 &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  void _syncMotion() {
    if (!_motion) {
      _enter.value = 1;
      _auto?.cancel();
      _auto = null;
      return;
    }
    if (!_enter.isAnimating && _enter.value == 0) _enter.forward();
    _auto ??= Timer.periodic(
      const Duration(milliseconds: 2800),
      (_) => _step(),
    );
  }

  void _step() {
    if (!mounted ||
        _touching ||
        DateTime.now().isBefore(_resumeAt) ||
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent <= 1) {
      return;
    }
    final max = _scroll.position.maxScrollExtent;
    final step = _itemExtent < max ? _itemExtent : max;
    final atEnd = _scroll.offset >= max - 1;
    final next = atEnd ? 0.0 : (_scroll.offset + step).clamp(0.0, max);
    _scroll.animateTo(
      next,
      duration: const Duration(milliseconds: 680),
      curve: Curves.easeInOutCubic,
    );
  }

  void _halt() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.offset);
  }

  void _revealSelected() {
    if (!_scroll.hasClients) return;
    final index = widget.sponsors.indexWhere(
      (sponsor) => sponsor.id == widget.selectedId,
    );
    if (index < 0) return;
    final max = _scroll.position.maxScrollExtent;
    final target = (index * _itemExtent).clamp(0.0, max);
    if (_motion) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 780),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _updateProgress() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final next = max <= 0
        ? 0
        : ((_scroll.offset / max) * 2).round().clamp(0, 2);
    if (next != _progress && mounted) setState(() => _progress = next);
  }

  void _release() {
    _touching = false;
    _resumeAt = DateTime.now().add(const Duration(milliseconds: 4200));
  }

  @override
  void dispose() {
    _auto?.cancel();
    _enter.dispose();
    _gleam.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sponsors.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 17),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x9EFFFFFF)),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Text(
          'No sponsor logos found in this category.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.white),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 84,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = ((constraints.maxWidth - 52) / 2.7).clamp(
                108.0,
                132.0,
              );
              _itemExtent = width + 12;
              return Listener(
                onPointerDown: (_) {
                  _touching = true;
                  _halt();
                },
                onPointerUp: (_) => _release(),
                onPointerCancel: (_) => _release(),
                child: ListView.builder(
                  key: ValueKey(
                    widget.reverse
                        ? 'sponsor-logo-strip-reverse'
                        : 'sponsor-logo-strip',
                  ),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  reverse: widget.reverse,
                  padding: const EdgeInsets.fromLTRB(17, 2, 17, 10),
                  itemExtent: _itemExtent,
                  itemCount: widget.sponsors.length,
                  itemBuilder: (context, index) {
                    final sponsor = widget.sponsors[index];
                    final selected = sponsor.id == widget.selectedId;
                    final start = (index * 0.08).clamp(0.0, 0.45);
                    return AnimatedBuilder(
                      animation: _enter,
                      builder: (context, child) {
                        final raw = ((_enter.value - start) / 0.5).clamp(
                          0.0,
                          1.0,
                        );
                        final eased = Curves.easeOutCubic.transform(raw);
                        return Opacity(
                          opacity: eased,
                          child: Transform.translate(
                            offset: Offset(0, (1 - eased) * 16),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Builder(
                          builder: (tileContext) {
                            return Semantics(
                              button: true,
                              selected: selected,
                              label: '${sponsor.name}, ${sponsor.role}',
                              child: GestureDetector(
                                key: ValueKey(
                                  widget.reverse
                                      ? 'sponsor-logo-reverse-$index'
                                      : 'sponsor-logo-$index',
                                ),
                                onTap: () {
                                  _touching = false;
                                  _resumeAt = DateTime.now().add(
                                    const Duration(milliseconds: 7000),
                                  );
                                  _halt();
                                  final box =
                                      tileContext.findRenderObject()
                                          as RenderBox?;
                                  widget.onSelected(sponsor);
                                  if (box != null &&
                                      box.hasSize &&
                                      box.attached) {
                                    final origin =
                                        box.localToGlobal(Offset.zero) &
                                        box.size;
                                    widget.onFly?.call(sponsor, origin);
                                  }
                                },
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 280),
                                  opacity: widget.departingId == sponsor.id
                                      ? 0.48
                                      : 1,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 340),
                                    curve: Curves.easeOutCubic,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(19),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white,
                                          Color(0xFFFBFBFC),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: selected
                                            ? const Color(0xFFE82550)
                                            : const Color(0xE8FFFFFF),
                                        width: selected ? 2 : 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0x40000000),
                                          blurRadius: selected ? 26 : 18,
                                          offset: const Offset(0, 10),
                                        ),
                                        if (selected)
                                          const BoxShadow(
                                            color: Color(0x33EC1746),
                                            spreadRadius: 2,
                                          ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 14,
                                          ),
                                          child: ExcludeSemantics(
                                            child: SponsorLogo(
                                              sponsor: sponsor,
                                            ),
                                          ),
                                        ),
                                        if (selected)
                                          const Align(
                                            alignment: Alignment.bottomCenter,
                                            child: FractionallySizedBox(
                                              widthFactor: 0.44,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(0xFFD50938),
                                                      Color(0xFFFF6681),
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                        top: Radius.circular(3),
                                                      ),
                                                ),
                                                child: SizedBox(height: 3),
                                              ),
                                            ),
                                          ),
                                        if (selected)
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: AnimatedBuilder(
                                                animation: _gleam,
                                                builder: (context, _) {
                                                  if (!_gleam.isAnimating &&
                                                      _gleam.value == 0) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  return FractionalTranslation(
                                                    translation: Offset(
                                                      -1.35 +
                                                          (2.7 * _gleam.value),
                                                      0,
                                                    ),
                                                    child: const DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                              colors: [
                                                                Color(
                                                                  0x00FFFFFF,
                                                                ),
                                                                Color(
                                                                  0xB3FFFFFF,
                                                                ),
                                                                Color(
                                                                  0x00FFFFFF,
                                                                ),
                                                              ],
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
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 2),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                AnimatedContainer(
                  key: ValueKey('sponsor-progress-$i'),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  width: i == _progress ? 25 : 7,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _progress
                        ? const Color(0xFFF7335D)
                        : const Color(0x52FFFFFF),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: i == _progress
                        ? const [
                            BoxShadow(color: Color(0x66FF1A50), blurRadius: 8),
                          ]
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
