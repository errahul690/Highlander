import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Highlanders/features/swoofi/data/swoofi_store_links.dart';

/// The reference's slide-in question expands into a centered store invitation.
class SwoofiPetInvite extends StatefulWidget {
  const SwoofiPetInvite({
    super.key,
    required this.trigger,
    required this.onOpenStore,
    required this.child,
    this.playStoreUrl = SwoofiStoreLinks.playStore,
    this.appStoreUrl = SwoofiStoreLinks.appStore,
  });

  final ValueNotifier<bool> trigger;
  final ValueChanged<String> onOpenStore;
  final Widget child;
  final String playStoreUrl;
  final String appStoreUrl;

  static const artwork = 'assets/swoofi/pet_portrait.png';
  static const dogArtwork = 'assets/swoofi/puppy_portrait.png';
  static const question = 'Are you a pet parent or a pet lover?';

  @override
  State<SwoofiPetInvite> createState() => _SwoofiPetInviteState();
}

class _SwoofiPetInviteState extends State<SwoofiPetInvite>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _purple = Color(0xFF7D2C83);
  static const _paper = Color(0xFFFFF7EE);
  static const _slideMs = 750;
  static const _letterMs = 70;
  static const _pauseMs = 1100;
  static const _artworkImage = AssetImage(SwoofiPetInvite.artwork);
  late final Widget _artwork = RepaintBoundary(
    child: Image(
      image: _artworkImage,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      excludeFromSemantics: true,
    ),
  );
  static const _introMs =
      _slideMs + SwoofiPetInvite.question.length * _letterMs + _pauseMs;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introMs),
  )..addStatusListener(_introStatus);
  late final AnimationController _expand = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addStatusListener(_expandedStatus);
  late final Listenable _motion = Listenable.merge([_intro, _expand]);
  final _closeFocus = FocusNode();
  bool _started = false;
  bool _dismissed = false;
  bool _expanded = false;
  bool _active = true;
  bool _visible = true;
  bool _reduceMotion = false;
  bool _artworkLoading = false;
  bool _artworkReady = false;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    widget.trigger.addListener(_resume);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animation = ModalRoute.of(context)?.animation;
    if (_routeAnimation != animation) {
      _routeAnimation?.removeStatusListener(_routeChanged);
      _routeAnimation = animation;
      animation?.addStatusListener(_routeChanged);
    }
    if (!_artworkLoading) {
      _artworkLoading = true;
      unawaited(_prepareArtwork());
    }
    _resume();
  }

  Future<void> _prepareArtwork() async {
    // Decode the portrait before moving it, outside the route's frame budget.
    await precacheImage(_artworkImage, context, onError: (_, _) {});
    if (!mounted) return;
    await precacheImage(
      const AssetImage(SwoofiPetInvite.dogArtwork),
      context,
      onError: (_, _) {},
    );
    if (!mounted) return;
    _artworkReady = true;
    _resume();
  }

  void _routeChanged(AnimationStatus status) => _resume();

  @override
  void didUpdateWidget(SwoofiPetInvite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger.removeListener(_resume);
      widget.trigger.addListener(_resume);
      _resume();
    }
  }

  void _resume() {
    if (!mounted || _dismissed) return;
    if (!_active ||
        !_visible ||
        !_artworkReady ||
        (_routeAnimation != null && !_routeAnimation!.isCompleted)) {
      _intro.stop(canceled: false);
      _expand.stop(canceled: false);
      return;
    }
    if (!widget.trigger.value) return;
    if (!_started) setState(() => _started = true);
    if (_reduceMotion) {
      _open();
    } else if (_expanded) {
      if (_expand.value < 1 && !_expand.isAnimating) _expand.forward();
    } else if (_intro.isCompleted) {
      _open();
    } else if (!_intro.isAnimating) {
      _intro.forward();
    }
  }

  void _introStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _active && _visible) _open();
  }

  void _expandedStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dismissed && _active && _visible) {
        _closeFocus.requestFocus();
      }
    });
  }

  void _open() {
    if (!mounted || _dismissed || !_active || !_visible) return;
    _intro.stop(canceled: false);
    if (!_expanded) setState(() => _expanded = true);
    if (_reduceMotion) {
      _expand.value = 1;
    } else if (!_expand.isAnimating && !_expand.isCompleted) {
      _expand.forward();
    }
  }

  void _dismiss() {
    if (_dismissed) return;
    _intro.stop(canceled: false);
    _expand.stop(canceled: false);
    _closeFocus.unfocus();
    setState(() => _dismissed = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.trigger.removeListener(_resume);
    _routeAnimation?.removeStatusListener(_routeChanged);
    _intro.dispose();
    _expand.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_expanded || _dismissed,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _dismiss();
    },
    child: LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _motion,
        child: widget.child,
        builder: (context, child) {
          final size = constraints.biggest;
          final safe = MediaQuery.paddingOf(context);
          final width = math.min(340.0, size.width - 48);
          final available = size.height - safe.vertical - 32;
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final height = math.min(available, width * .48 + 192 * scale);
          final heroHeight = math.min(width * .48, height * .48);
          final compact = Rect.fromLTWH(
            16,
            size.height - safe.bottom - 80,
            math.min(236, size.width - 32),
            64,
          );
          final full = Rect.fromLTWH(
            (size.width - width) / 2,
            safe.top + 16 + (available - height) / 2,
            width,
            height,
          );
          final progress = Curves.easeInOutCubic.transform(_expand.value);
          final rect = Rect.lerp(compact, full, progress)!;
          final elapsed = _intro.value * _introMs;
          final entry = _expanded
              ? 1.0
              : Curves.easeInOutCubic.transform(
                  (elapsed / _slideMs).clamp(0, 1),
                );
          final letters = ((elapsed - _slideMs) / _letterMs).floor().clamp(
            0,
            SwoofiPetInvite.question.length,
          );
          final entryTime = (elapsed / _slideMs).clamp(0.0, 1.0);
          final wobble = _expanded || _reduceMotion
              ? 0.0
              : math.sin(entryTime * math.pi * 4) *
                    math.sin(entryTime * math.pi);
          return Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                excluding: _expanded && !_dismissed,
                child: AbsorbPointer(
                  absorbing: _expanded && !_dismissed,
                  child: child,
                ),
              ),
              if (_started && !_dismissed) ...[
                if (_expanded)
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('swoofi-invite-backdrop'),
                      onTap: _dismiss,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: 8 * progress,
                            sigmaY: 8 * progress,
                          ),
                          child: ColoredBox(
                            color: const Color(0xFF24132C)
                                .withValues(alpha: .46 * progress),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fromRect(
                  rect: rect,
                  // Slide the painted card without relaying out its portrait.
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.translationValues(
                      -(compact.width + 32) * (1 - entry),
                      wobble * 5,
                      0,
                    )..rotateZ(wobble * .045),
                    child: Opacity(
                      opacity: entry,
                      child: Semantics(
                        explicitChildNodes: true,
                        scopesRoute: _expanded,
                        namesRoute: _expanded,
                        label: _expanded
                            ? 'Discover Swoofi'
                            : SwoofiPetInvite.question,
                        child: FocusScope(
                          onKeyEvent: (_, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.escape) {
                              _dismiss();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Container(
                            key: ValueKey(
                              _expanded
                                  ? 'swoofi-invite-dialog'
                                  : 'swoofi-invite-question',
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                22 + 6 * progress,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2C1230)
                                      .withValues(alpha: .25 * progress),
                                  blurRadius: 32,
                                  offset: Offset(0, 16),
                                ),
                              ],
                            ),
                            foregroundDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                22 + 6 * progress,
                              ),
                              border: Border.all(
                                color: const Color(0xFFB478AF)
                                    .withValues(alpha: progress),
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              clipBehavior: progress == 0
                                  ? Clip.none
                                  : Clip.antiAlias,
                              borderRadius: BorderRadius.circular(
                                22 + 6 * progress,
                              ),
                              child: Material(
                                color: Color.lerp(
                                  Colors.transparent,
                                  _paper,
                                  progress,
                                ),
                                child: GestureDetector(
                                  onTap: _expanded ? null : _open,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fromRect(
                                        rect: Rect.lerp(
                                          const Rect.fromLTWH(0, 4, 56, 56),
                                          Rect.fromLTWH(
                                            0,
                                            0,
                                            width,
                                            heroHeight,
                                          ),
                                          progress,
                                        )!,
                                        child: ClipRRect(
                                          clipBehavior: progress == 0
                                              ? Clip.none
                                              : Clip.antiAlias,
                                          borderRadius: BorderRadius.circular(
                                            28 * (1 - progress),
                                          ),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            fit: StackFit.expand,
                                            children: [
                                              if (progress < 1)
                                                Opacity(
                                                  opacity: 1 - progress,
                                                  child: _DogPortrait(
                                                    phase: elapsed / 1000,
                                                    motion: _reduceMotion
                                                        ? 0
                                                        : 1 - progress,
                                                  ),
                                                ),
                                              if (progress > 0)
                                                Opacity(
                                                  opacity: progress,
                                                  child: DecoratedBox(
                                                    decoration:
                                                        const BoxDecoration(
                                                          gradient:
                                                              RadialGradient(
                                                                center:
                                                                    Alignment(
                                                                      -.15,
                                                                      -.8,
                                                                    ),
                                                                radius: 1.35,
                                                                colors: [
                                                                  Color(
                                                                    0xFFFFF0DD,
                                                                  ),
                                                                  Color(
                                                                    0xFFE4C9DF,
                                                                  ),
                                                                ],
                                                              ),
                                                        ),
                                                    child: Padding(
                                                      padding: EdgeInsets.lerp(
                                                        const EdgeInsets.all(2),
                                                        const EdgeInsets.fromLTRB(
                                                          24,
                                                          18,
                                                          24,
                                                          8,
                                                        ),
                                                        progress,
                                                      )!,
                                                      child: _artwork,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (!_expanded && letters > 0)
                                        Positioned(
                                          left: 66,
                                          right: 0,
                                          top: 4,
                                          bottom: 4,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: AnimatedSize(
                                              duration: const Duration(
                                                milliseconds: 90,
                                              ),
                                              curve: Curves.easeOut,
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: ExcludeSemantics(
                                                  child: Text(
                                                    SwoofiPetInvite.question
                                                        .substring(0, letters),
                                                    style: const TextStyle(
                                                      fontFamily: 'SwoofiSans',
                                                      fontSize: 13,
                                                      height: 1.2,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (progress > .7) ...[
                                        Positioned(
                                          top: 15,
                                          left: 15,
                                          child: Opacity(
                                            opacity: ((progress - .7) / .3)
                                                .clamp(0, 1),
                                            child: Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: _paper,
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                              ),
                                              child: const Icon(
                                                Icons.pets,
                                                color: _purple,
                                                size: 23,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: heroHeight,
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Opacity(
                                            opacity: ((progress - .7) / .3)
                                                .clamp(0, 1),
                                            child: IgnorePointer(
                                              ignoring: !_expand.isCompleted,
                                              child: _Offer(
                                                onOpenStore: widget.onOpenStore,
                                                playStoreUrl:
                                                    widget.playStoreUrl,
                                                appStoreUrl: widget.appStoreUrl,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (_expanded)
                                        Positioned(
                                          top: 10 * progress,
                                          right: 10 * progress,
                                          child: _closeButton(progress),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );

  Widget _closeButton(double progress) => IconButton(
    key: const ValueKey('swoofi-invite-close'),
    focusNode: _closeFocus,
    tooltip: 'Close Swoofi invitation',
    onPressed: _dismiss,
    style: IconButton.styleFrom(
      minimumSize: Size(24 + 20 * progress, 24 + 20 * progress),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      side: BorderSide.none,
      padding: EdgeInsets.all(2 + 4 * progress),
    ),
    icon: Icon(Icons.close_rounded, size: 16 + 6 * progress),
  );
}

/// An animated ring surrounds the user's puppy photo during the side prompt.
class _DogPortrait extends StatelessWidget {
  const _DogPortrait({required this.phase, required this.motion});

  final double phase;
  final double motion;

  @override
  Widget build(BuildContext context) {
    final swing = phase * math.pi * 2.5;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.translationValues(
        math.sin(swing) * 4 * motion,
        (1 - math.cos(swing)) * -2 * motion,
        0,
      )..rotateZ(math.sin(swing) * .28 * motion),
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: const [
              Color(0xFF9B51B3),
              Color(0xFFFFB75E),
              Color(0xFFEF7C9B),
              Color(0xFF9B51B3),
            ],
            transform: GradientRotation(phase * math.pi),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x387D2C83),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Color(0x1F49224E),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: ColoredBox(
            color: const Color(0xFFFFE9CA),
            child: Transform.scale(
              scale: 1.08,
              child: Image.asset(
                SwoofiPetInvite.dogArtwork,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Offer extends StatelessWidget {
  const _Offer({
    required this.onOpenStore,
    required this.playStoreUrl,
    required this.appStoreUrl,
  });
  final ValueChanged<String> onOpenStore;
  final String playStoreUrl;
  final String appStoreUrl;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find your people on Swoofi',
          style: TextStyle(
            fontFamily: 'SwoofiSans',
            fontSize: 23,
            height: 1.15,
            letterSpacing: -.8,
            fontWeight: FontWeight.w700,
            color: Color(0xFF552057),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Meet fellow pet lovers and help street animals in your community.',
          style: TextStyle(
            fontFamily: 'SwoofiSans',
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF7B747D),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (playStoreUrl.isNotEmpty)
                _StoreBadge(
                  apple: false,
                  onTap: () => onOpenStore(playStoreUrl),
                ),
              if (appStoreUrl.isNotEmpty)
                _StoreBadge(apple: true, onTap: () => onOpenStore(appStoreUrl)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StoreBadge extends StatelessWidget {
  const _StoreBadge({required this.apple, required this.onTap});
  final bool apple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: apple
        ? 'Download Swoofi on the App Store'
        : 'Get Swoofi on Google Play',
    child: Material(
      color: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFF9C9C9C)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(apple ? 'swoofi-app-store' : 'swoofi-google-play'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (apple)
                const Icon(Icons.apple, color: Colors.white, size: 28)
              else
                const SizedBox(
                  width: 26,
                  height: 28,
                  child: CustomPaint(painter: _PlayIcon()),
                ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    apple ? 'Download on the' : 'GET IT ON',
                    style: const TextStyle(
                      fontFamily: 'SwoofiSans',
                      fontSize: 8,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    apple ? 'App Store' : 'Google Play',
                    style: const TextStyle(
                      fontFamily: 'SwoofiSans',
                      fontSize: 17,
                      height: 1.05,
                      letterSpacing: -.3,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PlayIcon extends CustomPainter {
  const _PlayIcon();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 26, size.height / 28);
    void triangle(Color color, Offset a, Offset b, Offset c) {
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..close(),
        Paint()..color = color,
      );
    }

    triangle(
      const Color(0xFF39D5EC),
      const Offset(1, 1),
      const Offset(14, 14),
      const Offset(1, 27),
    );
    triangle(
      const Color(0xFF67C64D),
      const Offset(1, 1),
      const Offset(20, 10),
      const Offset(14, 14),
    );
    triangle(
      const Color(0xFFFFCF47),
      const Offset(14, 14),
      const Offset(20, 10),
      const Offset(26, 14),
    );
    triangle(
      const Color(0xFFFFCF47),
      const Offset(14, 14),
      const Offset(26, 14),
      const Offset(20, 18),
    );
    triangle(
      const Color(0xFFF65D6C),
      const Offset(1, 27),
      const Offset(14, 14),
      const Offset(20, 18),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlayIcon oldDelegate) => false;
}
