import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'football_kickoff_painter.dart';

/// Staggered crest arrival, settle and light sweep, played once when visible.
class TeamLogoEntrance extends StatefulWidget {
  const TeamLogoEntrance({
    super.key,
    required this.fromLeft,
    required this.child,
  });
  final bool fromLeft;
  final Widget child;
  @override
  State<TeamLogoEntrance> createState() => _TeamLogoEntranceState();
}

class _TeamLogoEntranceState extends State<TeamLogoEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  double get _direction => widget.fromLeft ? -1 : 1;
  late final _travel = TweenSequence<Offset>([
    TweenSequenceItem(
      tween: Tween(
        begin: Offset(_direction * 1.8, .08),
        end: Offset(-_direction * .045, -.012),
      ).chain(CurveTween(curve: const Cubic(.18, .86, .22, 1))),
      weight: 64,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: Offset(-_direction * .045, -.012),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 36,
    ),
  ]);
  final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: .72,
        end: 1.045,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 62,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.045,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 38,
    ),
  ]);
  bool _started = false;
  bool _visibleTicker = true, _checkQueued = false;
  ScrollPosition? _scroll;
  _FaceoffTimeline? _scene;

  void _checkVisibility() {
    if (_started || _checkQueued || !mounted || _scene != null) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (!mounted || _started || !_visibleTicker) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final screen = MediaQuery.sizeOf(context);
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      if (!screen.isEmpty && !bounds.overlaps(Offset.zero & screen)) return;
      _started = true;
      _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scene = context.dependOnInheritedWidgetOfExactType<_FaceoffTimeline>();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (_scroll != scroll) {
      _scroll?.removeListener(_checkVisibility);
      _scroll = scroll;
      _scroll?.addListener(_checkVisibility);
    }
    _visibleTicker = TickerMode.valuesOf(context).enabled;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _started = true;
    } else if (!_started && _scene == null) {
      _checkVisibility();
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _scene?.animation ?? _controller,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        if (_scene != null) return _buildFaceoff(child!);
        // The away crest follows by 77 ms; both land as one coordinated pair.
        final delay = widget.fromLeft ? 0.0 : .07;
        final t = ((_controller.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final reveal = Curves.easeOutCubic.transform((t / .3).clamp(0.0, 1.0));
        final settle =
            1 - Curves.easeOutCubic.transform((t / .78).clamp(0.0, 1.0));
        final sweep = ((t - .43) / .43).clamp(0.0, 1.0);
        final transform = Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..rotateY(_direction * .48 * settle)
          ..rotateZ(_direction * .12 * settle);
        final accent = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFFD6A1)
            : const Color(0xFFE34B35);
        return SlideTransition(
          position: AlwaysStoppedAnimation(_travel.transform(t)),
          child: FadeTransition(
            opacity: AlwaysStoppedAnimation(reveal),
            child: Transform(
              alignment: Alignment.center,
              transform: transform,
              child: ScaleTransition(
                scale: AlwaysStoppedAnimation(_scale.transform(t)),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (t > 0 && t < 1)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CrestArrivalPainter(
                              progress: t,
                              direction: _direction,
                              accent: accent,
                            ),
                          ),
                        ),
                      ),
                    if (sweep > 0 && sweep < 1)
                      ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (bounds) {
                          final x = -1.8 + sweep * 3.6;
                          return LinearGradient(
                            begin: Alignment(x - .4, -.65),
                            end: Alignment(x + .4, .65),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(
                                alpha: .48 * math.sin(sweep * math.pi),
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0, .5, 1],
                          ).createShader(bounds);
                        },
                        child: child,
                      )
                    else
                      child!,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _buildFaceoff(Widget child) {
    final p = _scene!.animation.value;
    final box = context.findRenderObject();
    final stage = _scene!.stage.currentContext?.findRenderObject();
    final centerBox = _scene!.center.currentContext?.findRenderObject();
    var width = 52.0;
    var charge = -_direction * .85;
    if (box is RenderBox &&
        box.hasSize &&
        stage is RenderBox &&
        stage.hasSize) {
      width = box.size.width;
      final myCenter = box.localToGlobal(box.size.center(Offset.zero));
      final target = centerBox is RenderBox && centerBox.hasSize
          ? centerBox.localToGlobal(centerBox.size.center(Offset.zero))
          : stage.localToGlobal(stage.size.center(Offset.zero));
      charge =
          (target.dx - myCenter.dx) / math.max(width, 1) + _direction * .58;
    }
    // Stage 1: edge reveal. Stage 2: the crests charge towards VS. Stage 3:
    // a shared impact, recoil and settle. No independent logo clocks.
    final entryT = ((p - (widget.fromLeft ? .055 : .085)) / .30).clamp(
      0.0,
      1.0,
    );
    final entry = Curves.easeOutQuart.transform(entryT);
    final initial =
        _direction *
        math.max(
          2.5,
          MediaQuery.sizeOf(context).width * .55 / math.max(width, 1),
        );
    double x;
    if (p < .37) {
      x = initial * (1 - entry);
    } else if (p < .49) {
      x =
          charge *
          Curves.easeInCubic.transform(((p - .37) / .12).clamp(0.0, 1.0));
    } else if (p < .62) {
      x =
          charge +
          (-_direction * .2 - charge) *
              Curves.easeOutExpo.transform((p - .49) / .13);
    } else {
      x =
          -_direction *
          .2 *
          (1 - Curves.easeOutBack.transform(((p - .62) / .25).clamp(0.0, 1.0)));
    }
    final impact = math.sin(math.pi * ((p - .43) / .22).clamp(0.0, 1.0));
    final scale = p < .37 ? .46 + .54 * entry : 1 + .12 * impact;
    final roll = _direction * (.24 * (1 - entry) - .09 * impact);
    final yaw = _direction * 1.05 * (1 - entry);
    final sweep = ((p - .65) / .22).clamp(0.0, 1.0);
    Widget crest = child;
    if (sweep > 0 && sweep < 1) {
      crest = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final x = -2 + 4 * sweep;
          return LinearGradient(
            begin: Alignment(x - .4, -.6),
            end: Alignment(x + .4, .6),
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: math.sin(math.pi * sweep) * .65),
              Colors.transparent,
            ],
          ).createShader(bounds);
        },
        child: crest,
      );
    }
    return SlideTransition(
      position: AlwaysStoppedAnimation(Offset(x, -.035 * impact)),
      child: FadeTransition(
        opacity: AlwaysStoppedAnimation((entryT / .45).clamp(0.0, 1.0)),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .002)
            ..rotateY(yaw)
            ..rotateZ(roll),
          child: Transform.scale(scale: scale, child: crest),
        ),
      ),
    );
  }
}

/// Coordinates the complete matchup rather than animating two unrelated icons.
class MatchFaceoffMotion extends StatefulWidget {
  const MatchFaceoffMotion({
    super.key,
    required this.child,
    this.attackRight = true,
  });
  final Widget child;
  final bool attackRight;
  @override
  State<MatchFaceoffMotion> createState() => _MatchFaceoffMotionState();
}

class _MatchFaceoffMotionState extends State<MatchFaceoffMotion>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  final _stage = GlobalKey(), _center = GlobalKey();
  ScrollPosition? _scroll;
  bool _started = false, _queued = false, _enabled = true;
  void _startIfVisible() {
    if (_started || _queued || !mounted) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || _started || !_enabled) return;
      final box = _stage.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final screen = MediaQuery.sizeOf(context);
      if (!screen.isEmpty &&
          !(box.localToGlobal(Offset.zero) & box.size).overlaps(
            Offset.zero & screen,
          )) {
        return;
      }
      _started = true;
      _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.valuesOf(context).enabled;
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_startIfVisible);
      _scroll = scroll;
      _scroll?.addListener(_startIfVisible);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _controller.value = 1;
    } else {
      _startIfVisible();
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_startIfVisible);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FaceoffTimeline(
    animation: _controller,
    stage: _stage,
    center: _center,
    child: RepaintBoundary(
      key: _stage,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (_, child) {
          final p = _controller.value;
          final stage = _stage.currentContext?.findRenderObject();
          final center = _center.currentContext?.findRenderObject();
          Offset? origin;
          if (stage is RenderBox &&
              center is RenderBox &&
              stage.hasSize &&
              center.hasSize) {
            origin = stage.globalToLocal(
              center.localToGlobal(center.size.center(Offset.zero)),
            );
          }
          final recoil =
              (1 - ((p - .49) / .13).clamp(0.0, 1.0)) * (p >= .49 ? 1 : 0);
          final shake = math.sin(p * 290) * recoil * 1.8;
          return CustomPaint(
            painter: p > 0 && p < 1
                ? FootballKickoffPainter(
                    progress: p,
                    origin: origin,
                    attackRight: widget.attackRight,
                  )
                : null,
            foregroundPainter: p > 0 && p < 1
                ? FootballKickoffPainter(
                    progress: p,
                    origin: origin,
                    foreground: true,
                    attackRight: widget.attackRight,
                  )
                : null,
            child: Transform.translate(
              offset: Offset(shake, shake * .35),
              child: child,
            ),
          );
        },
      ),
    ),
  );
}

class _FaceoffTimeline extends InheritedWidget {
  const _FaceoffTimeline({
    required this.animation,
    required this.stage,
    required this.center,
    required super.child,
  });
  final Animation<double> animation;
  final GlobalKey stage, center;
  @override
  bool updateShouldNotify(_FaceoffTimeline oldWidget) =>
      animation != oldWidget.animation;
}

/// Broadcast-style matchup emblem, synchronized with the kickoff play.
class FaceoffVersus extends StatelessWidget {
  const FaceoffVersus({super.key, this.style, this.label = 'VS'});
  final TextStyle? style;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scene = context
        .dependOnInheritedWidgetOfExactType<_FaceoffTimeline>();
    Widget badge(double p) {
      final arrival = Curves.easeOutCubic.transform(
        ((p - .12) / .22).clamp(0.0, 1.0),
      );
      final shot = p < .6
          ? ((p - .31) / .09).clamp(0.0, 1.0)
          : 1 - ((p - .65) / .16).clamp(0.0, 1.0);
      final impact = math.sin(math.pi * ((p - .78) / .18).clamp(0.0, 1.0));
      final lettering = (style ?? const TextStyle()).copyWith(
        color: Colors.white,
        fontSize: 23,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        height: 1,
        letterSpacing: -1.5,
        shadows: const [
          Shadow(color: Color(0xAA000000), offset: Offset(0, 2), blurRadius: 3),
        ],
      );
      return Opacity(
        opacity: arrival * (1 - shot),
        child: Transform.scale(
          scale: .72 + .28 * arrival + impact * .09,
          child: SizedBox(
            width: 58,
            height: 62,
            child: CustomPaint(
              painter: _VersusBadgePainter(progress: p),
              child: Center(
                child: label == 'VS'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(-18 * (1 - arrival), -3),
                            child: Text('V', style: lettering),
                          ),
                          const SizedBox(width: 3),
                          Transform.translate(
                            offset: Offset(18 * (1 - arrival), 3),
                            child: Text('S', style: lettering),
                          ),
                        ],
                      )
                    : Text(label, style: style),
              ),
            ),
          ),
        ),
      );
    }

    if (scene == null) return badge(1);
    return RepaintBoundary(
      key: scene.center,
      child: AnimatedBuilder(
        animation: scene.animation,
        builder: (_, _) => badge(scene.animation.value),
      ),
    );
  }
}

class _VersusBadgePainter extends CustomPainter {
  const _VersusBadgePainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final plate = Path()
      ..moveTo(size.width * .2, 8)
      ..lineTo(size.width, 2)
      ..lineTo(size.width * .83, size.height - 10)
      ..lineTo(0, size.height - 2)
      ..close();
    canvas.drawShadow(plate, const Color(0xFFDC322F), 9, false);
    canvas.drawPath(
      plate,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE74A32), Color(0xFF9C171E), Color(0xFF410F19)],
        ).createShader(rect),
    );
    canvas.drawPath(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFDB8C), Color(0x55F4AC59), Color(0xFFEFAE68)],
        ).createShader(rect),
    );
    // Diagonal separator and corner accents echo a football broadcast ident.
    final slash = Paint()
      ..color = const Color(0xFFFFD88A)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(size.width * .62, 13),
      Offset(size.width * .4, size.height - 12),
      slash,
    );
    canvas.drawLine(
      Offset(6, 7),
      Offset(size.width * .49, 3),
      slash..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(size.width * .5, size.height - 2),
      Offset(size.width - 3, size.height - 6),
      slash,
    );
    final sweep = ((progress - .81) / .19).clamp(0.0, 1.0);
    if (sweep > 0 && sweep < 1) {
      canvas.save();
      canvas.clipPath(plate);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-3 + 6 * sweep, -1),
            end: Alignment(-1.7 + 6 * sweep, 1),
            colors: const [
              Colors.transparent,
              Color(0x77FFFFFF),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_VersusBadgePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _CrestArrivalPainter extends CustomPainter {
  const _CrestArrivalPainter({
    required this.progress,
    required this.direction,
    required this.accent,
  });
  final double progress, direction;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final unit = size.shortestSide;
    final arrival = ((progress - .32) / .58).clamp(0.0, 1.0);
    final glow = math.sin(arrival * math.pi);
    if (glow > 0) {
      canvas.drawCircle(
        center,
        unit * .48,
        Paint()
          ..color = accent.withValues(alpha: glow * .16)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .16),
      );
      canvas.drawCircle(
        center,
        unit * (.5 + .22 * arrival),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .85
          ..color = accent.withValues(alpha: glow * .28),
      );
    }
    final trail = math.sin(math.pi * (progress / .65).clamp(0.0, 1.0));
    if (trail <= 0) return;
    for (var i = 0; i < 3; i++) {
      final y = center.dy + (i - 1) * unit * .19;
      final start = Offset(center.dx + direction * unit * (.55 + .17 * i), y);
      final end = Offset(center.dx + direction * unit * .23, y);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = i == 1 ? 1.6 : .8
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              accent.withValues(alpha: 0),
              accent.withValues(alpha: trail * .34),
            ],
            begin: direction < 0 ? Alignment.centerLeft : Alignment.centerRight,
            end: direction < 0 ? Alignment.centerRight : Alignment.centerLeft,
          ).createShader(Rect.fromPoints(start, end).inflate(1)),
      );
    }
  }

  @override
  bool shouldRepaint(_CrestArrivalPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      direction != oldDelegate.direction ||
      accent != oldDelegate.accent;
}
