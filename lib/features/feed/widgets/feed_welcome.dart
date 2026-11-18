import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/core/startup/startup_visibility.dart';
import 'package:Highlanders/shared/widgets/user_avatar.dart';

String feedGreeting(DateTime time) => time.hour < 12
    ? 'Good Morning 🌅'
    : time.hour < 17
    ? 'Good Afternoon ☀️'
    : 'Good Evening 🌙';

/// Keeps one greeting layer attached to the header throughout the welcome flight.
class FeedWelcome extends StatefulWidget {
  const FeedWelcome({
    super.key,
    required this.builder,
    this.now,
    this.enabled = true,
  });

  final DateTime? now;
  final bool enabled;
  final Widget Function(Widget greetingSlot) builder;

  @override
  State<FeedWelcome> createState() => _FeedWelcomeState();
}

class _FeedWelcomeState extends State<FeedWelcome>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _welcomeBackground = AssetImage(
    'assets/images/welcome-background.jpg',
  );
  bool _backgroundPrepared = false;
  static const _diagnostics =
      kDebugMode || bool.fromEnvironment('STADIUM_SPLASH_DIAGNOSTICS');
  final _link = LayerLink();
  final _targetKey = GlobalKey();
  final _sourceKey = GlobalKey();
  final _photoKey = GlobalKey();
  final _cardKey = GlobalKey();
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    animationBehavior: AnimationBehavior.preserve,
  );
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Ticker _entranceFrames = createTicker(_advanceEntrance);
  Duration _previousEntranceFrame = Duration.zero;

  void _advanceEntrance(Duration elapsed) {
    final delta = elapsed - _previousEntranceFrame;
    _previousEntranceFrame = elapsed;
    // The first live frame can be late while Android hands off its WebView.
    // Preserve the reference's small-to-large pop instead of skipping its entry.
    final step =
        delta.inMicroseconds.clamp(0, 32000) /
        _entrance.duration!.inMicroseconds;
    _entrance.value = (_entrance.value + step).clamp(0.0, 1.0);
    if (_entrance.isCompleted) _entranceFrames.stop();
  }

  Timer? _clock;
  Timer? _popupHold;
  Animation<double>? _routeAnimation;
  bool _started = false;
  bool _scheduled = false;
  Rect? _source, _target, _photo, _card;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Session.profileChanges.addListener(_update);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _update());
    if (_diagnostics) {
      var bucket = -1;
      _entrance.addListener(() {
        final next = (_entrance.value * 5).floor();
        if (next != bucket) {
          bucket = next;
          debugPrint(
            '[welcome-motion] entrance=${_entrance.value.toStringAsFixed(2)}',
          );
        }
      });
    }
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_backgroundPrepared) {
      _backgroundPrepared = true;
      unawaited(precacheImage(_welcomeBackground, context));
    }
    final animation = ModalRoute.of(context)?.animation;
    if (_routeAnimation != animation) {
      _routeAnimation?.removeStatusListener(_routeChanged);
      _routeAnimation = animation;
      animation?.addStatusListener(_routeChanged);
    }
  }

  void _routeChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _update();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Session.profileChanges.removeListener(_update);
    _clock?.cancel();
    _popupHold?.cancel();
    _routeAnimation?.removeStatusListener(_routeChanged);
    _animation.dispose();
    _entranceFrames.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  void _scheduleStart() {
    if (!widget.enabled ||
        _started ||
        _scheduled ||
        !StartupVisibility.isVisible(context) ||
        !TickerMode.valuesOf(context).enabled ||
        (_routeAnimation != null && !_routeAnimation!.isCompleted)) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          !widget.enabled ||
          !StartupVisibility.isVisible(context) ||
          !TickerMode.valuesOf(context).enabled ||
          (_routeAnimation != null && !_routeAnimation!.isCompleted)) {
        return;
      }
      final source = _rect(_sourceKey), target = _rect(_targetKey);
      final photo = _rect(_photoKey), card = _rect(_cardKey);
      if (source == null || target == null || photo == null || card == null) {
        return;
      }
      setState(() {
        _source = source;
        _target = target;
        _photo = photo;
        _card = card;
        _started = true;
      });
      if (_diagnostics) {
        debugPrint(
          '[welcome-motion] reduced=${MediaQuery.disableAnimationsOf(context)}',
        );
      }
      if (MediaQuery.disableAnimationsOf(context)) {
        _entrance.value = 1;
      } else {
        _previousEntranceFrame = Duration.zero;
        _entranceFrames.start();
      }
      // Start the reading time only after the destination route is visible.
      // A real timer keeps slow first frames from skipping the popup phase.
      _popupHold = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _animation.value = 1;
        } else {
          _animation.forward();
        }
      });
    });
  }

  // Same smoothstep and quadratic path as the supplied animation reference.
  double _ease(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  Offset _curve(Offset start, Offset control, Offset end, double t) =>
      start * ((1 - t) * (1 - t)) + control * (2 * (1 - t) * t) + end * (t * t);

  void _depart() {
    if (!_started ||
        _animation.isAnimating ||
        _animation.isCompleted ||
        !_entrance.isCompleted) {
      return;
    }
    _popupHold?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleStart();
    final slot = CompositedTransformTarget(
      link: _link,
      child: SizedBox(key: _targetKey, height: 46, width: double.infinity),
    );
    final greeting = feedGreeting(widget.now ?? DateTime.now());
    final name = Session.name.trim().isEmpty
        ? 'Highlander'
        : Session.name.trim();
    final welcomeCard = RepaintBoundary(
      key: _cardKey,
      child: _WelcomeCard(sourceKey: _sourceKey, photoKey: _photoKey),
    );
    // Keep the feed/shell out of the frame loop. Only the welcome overlay paints
    // while the photo and text travel; the header target stays compositor-linked.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _animation]),
        child: widget.builder(slot),
        builder: (context, feed) {
          final intro = widget.enabled && !_animation.isCompleted;
          final progress = _ease(_animation.value);
          final exit = _ease(progress / .76);
          final backdrop = 1 - _ease(_animation.value / .83);
          final entrance = _entrance.value;
          final card = _card;
          final scale = !_started
              ? 1.0
              : entrance < .8
              ? 1.02 * _ease(entrance / .8)
              : 1.02 - .02 * _ease((entrance - .8) / .2);
          // Zoom from zero with a small upward lift,
          // overshoot to 102%, then settle at full size.
          final entranceOffset = !_started
              ? 0.0
              : 12 * (1 - _ease(entrance / .75));
          final opacity = _started ? _ease(entrance / .45) : 0.0;
          final cardScale = scale * (1 - .075 * exit);
          final cardOffset = Offset(0, entranceOffset - 12 * exit);
          final target = _target;
          final source = _source;
          final photo = _photo;
          final ready =
              target != null && source != null && photo != null && card != null;
          Offset enter(Offset point) => card == null
              ? point
              : card.center +
                    (point - card.center) * scale +
                    Offset(0, entranceOffset);
          final photoEnd = Offset(18, 23);
          final textEnd = Offset(48, 0);
          final photoStart = ready
              ? enter(photo.center) - target.topLeft
              : photoEnd;
          final textStart = ready
              ? enter(source.topLeft) - target.topLeft
              : textEnd;
          final photoPosition = ready
              ? _curve(
                  photoStart,
                  Offset(
                    photoStart.dx - 6,
                    photoEnd.dy + (photoStart.dy - photoEnd.dy) * .16,
                  ),
                  photoEnd,
                  progress,
                )
              : photoEnd;
          final textPosition = ready
              ? _curve(
                  textStart,
                  Offset(
                    textEnd.dx + (textStart.dx - textEnd.dx) * .6,
                    textEnd.dy + (textStart.dy - textEnd.dy) * .23,
                  ),
                  textEnd,
                  progress,
                )
              : textEnd;
          final photoSize = ready
              ? lerpDouble(photo.width, 36, progress)!
              : 36.0;
          final identityScale = lerpDouble(scale, 1, progress)!;
          final textWidth = ready
              ? lerpDouble(
                  source.width,
                  (target.width - 48).clamp(1, double.infinity),
                  progress,
                )!
              : 140.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              TickerMode(
                enabled: !intro,
                child: RepaintBoundary(child: feed!),
              ),
              if (intro)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _depart,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Keep the club artwork behind the popup until it lands.
                        Opacity(
                          opacity: backdrop,
                          child: ColoredBox(
                            color: const Color(0xFF190610),
                            child: Opacity(
                              opacity: .05,
                              child: RepaintBoundary(
                                child: Image(
                                  key: const ValueKey('welcome-background'),
                                  image: _welcomeBackground,
                                  fit: BoxFit.cover,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: opacity * (1 - exit),
                          child: SafeArea(
                            child: Center(
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(24),
                                child: Transform.translate(
                                  offset: cardOffset,
                                  child: Transform.scale(
                                    scale: cardScale,
                                    child: welcomeCard,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.enabled)
                Positioned.fill(
                  child: IgnorePointer(
                    // After landing, the profile photo can open its viewer.
                    ignoring: intro,
                    child: CompositedTransformFollower(
                      link: _link,
                      showWhenUnlinked: false,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: target?.width ?? 180,
                          height: 46,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: photoPosition.dx - photoSize / 2,
                                top: photoPosition.dy - photoSize / 2,
                                width: photoSize,
                                height: photoSize,
                                child: Transform.scale(
                                  scale: identityScale,
                                  child: Opacity(
                                    opacity: ready ? opacity : 0,
                                    child: RepaintBoundary(
                                      child: UserAvatar(
                                        key: const ValueKey(
                                          'welcome-profile-photo',
                                        ),
                                        currentUser: true,
                                        radius: photoSize / 2,
                                        backgroundColor: const Color(
                                          0xFF5B213A,
                                        ),
                                        foregroundColor: const Color(
                                          0xFFFFD7AE,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: textPosition.dx,
                                top: textPosition.dy,
                                width: textWidth,
                                height: ready
                                    ? lerpDouble(source.height, 46, progress)!
                                    : 46,
                                child: Transform.scale(
                                  scale: identityScale,
                                  alignment: Alignment.topLeft,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: ready ? opacity : 0,
                                      child: RepaintBoundary(
                                        child: _Greeting(
                                          greeting: intro
                                              ? greeting
                                                    .split(' ')
                                                    .take(2)
                                                    .join(' ')
                                              : greeting,
                                          name: name,
                                          alignmentX: -progress,
                                          greetingSize: lerpDouble(
                                            15,
                                            10,
                                            progress,
                                          )!,
                                          nameSize: lerpDouble(
                                            32,
                                            20,
                                            progress,
                                          )!,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.greeting,
    required this.name,
    this.alignmentX = -1,
    this.greetingSize = 10,
    this.nameSize = 20,
  });
  final String greeting, name;
  final double alignmentX;
  final double greetingSize, nameSize;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Align(
        alignment: Alignment(alignmentX, 0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            greeting,
            style: TextStyle(
              color: Color(0xFFFFD0DB),
              fontSize: greetingSize,
              fontWeight: FontWeight.w700,
              letterSpacing: .9,
            ),
          ),
        ),
      ),
      const SizedBox(height: 3),
      Align(
        alignment: Alignment(alignmentX, 0),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: nameSize,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
      ),
    ],
  );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.sourceKey, required this.photoKey});
  final GlobalKey sourceKey, photoKey;
  static const _gold = Color(0xFFF3D7A3);

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('welcome-popup'),
    width: 352,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(33),
      border: Border.all(color: const Color(0xB3C48A95), width: 1.5),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF96324C), Color(0xFF681D36), Color(0xFF300F20)],
        stops: [0, .52, 1],
      ),
      boxShadow: const [
        BoxShadow(color: Color(0x33AA8491), spreadRadius: 7, blurRadius: 1),
        BoxShadow(color: Colors.black54, blurRadius: 50, offset: Offset(0, 20)),
      ],
    ),
    child: Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _WelcomeLines())),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0x24F4C6B4)),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x45E5B9AF)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_outlined, color: _gold, size: 14),
                    SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'A LITTLE MOMENT FOR YOU',
                          style: TextStyle(
                            color: Color(0xFFFFE5CE),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _WelcomeOrnament(),
              const SizedBox(height: 16),
              SizedBox.square(
                dimension: 154,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 154,
                      height: 154,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x1FF3D7A3)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1AF3D7A3),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 142,
                      height: 142,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x28F3D7A3)),
                      ),
                    ),
                    Container(
                      width: 128,
                      height: 128,
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Color(0xFFFFE5B1),
                            Color(0xFFAB6579),
                            Color(0xFFF5D7A0),
                            Color(0xFFFFE5B1),
                          ],
                        ),
                      ),
                      child: SizedBox.expand(key: photoKey),
                    ),
                    Positioned(
                      right: 19,
                      bottom: 24,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _gold,
                          border: Border.all(
                            color: const Color(0xFF77253D),
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 0,
                      top: 8,
                      child: Icon(Icons.auto_awesome, color: _gold, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SO GOOD TO SEE YOU',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF8DDC7),
                  fontSize: 10,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(key: sourceKey, height: 78, width: double.infinity),
              const SizedBox(height: 8),
              Container(
                width: 49,
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, _gold, Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A fresh day, a new story.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFF4EB),
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Here's to bright moments, good energy,\nand everything ahead.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xD9F8E5E5),
                  fontSize: 13,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 24),
              Container(height: 1, color: const Color(0x29EDC0B4)),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 10, color: _gold),
                  SizedBox(width: 13),
                  Text(
                    'MAKE TODAY YOURS',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(width: 13),
                  Icon(Icons.auto_awesome, size: 10, color: _gold),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WelcomeOrnament extends StatelessWidget {
  const _WelcomeOrnament();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 34,
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Color(0x99F3D7A3)],
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 11),
        child: Icon(Icons.auto_awesome, size: 9, color: Color(0xFFF3D7A3)),
      ),
      Container(
        width: 34,
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x99F3D7A3), Colors.transparent],
          ),
        ),
      ),
    ],
  );
}

class _WelcomeLines extends CustomPainter {
  const _WelcomeLines();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x07FFF0E3)
      ..strokeWidth = .8;
    for (double x = -size.height; x < size.width; x += 42) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height * .8, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WelcomeLines oldDelegate) => false;
}
