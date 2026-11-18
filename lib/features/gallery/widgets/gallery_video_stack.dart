import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:Highlanders/features/gallery/data/gallery_repository.dart';

class GalleryVideoStackController extends ChangeNotifier {
  int requestedIndex = 0;
  void goTo(int index) {
    requestedIndex = index;
    notifyListeners();
  }
}

class GalleryVideoStackStyle {
  const GalleryVideoStackStyle({
    this.widthFactor = .78,
    this.maxWidth = 390,
    this.aspectRatio = 1.586,
    this.radius = 16,
    this.height,
    this.alignment = Alignment.center,
    this.premium = false,
  });
  static const focus = GalleryVideoStackStyle(
    widthFactor: .80,
    maxWidth: 400,
    aspectRatio: 1.67,
    radius: 20,
    alignment: Alignment.center,
    premium: true,
  );
  final double widthFactor, maxWidth, aspectRatio, radius;
  final double? height;
  final Alignment alignment;
  final bool premium;
}

/// Landscape stack and turn-away swipe from the supplied mobile card reference.
class GalleryVideoStack extends StatefulWidget {
  const GalleryVideoStack({
    super.key,
    required this.items,
    required this.onOpen,
    required this.imageBuilder,
    required this.subtitle,
    this.verticalSpacing = 24,
    this.style = const GalleryVideoStackStyle(),
    this.controller,
    this.onIndexChanged,
  });

  final List<GalleryItem> items;
  final ValueChanged<GalleryItem> onOpen;
  final Widget Function(GalleryItem) imageBuilder;
  final String Function(GalleryItem) subtitle;
  final double verticalSpacing;
  final GalleryVideoStackStyle style;
  final GalleryVideoStackController? controller;
  final ValueChanged<int>? onIndexChanged;

  @override
  State<GalleryVideoStack> createState() => _GalleryVideoStackState();
}

class _GalleryVideoStackState extends State<GalleryVideoStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  int _active = 0;
  int _direction = 1;
  double _drag = 0;
  bool _dragging = false;
  bool _settling = false;
  int? _destination;

  void _requested() {
    final target = widget.controller!.requestedIndex % widget.items.length;
    if (target != _active) {
      _settle(_distance(target, _active) >= 0 ? 1 : -1, target: target);
    }
  }

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this)
      ..addListener(() => setState(() {}));
    widget.controller?.addListener(_requested);
  }

  @override
  void didUpdateWidget(GalleryVideoStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_requested);
      widget.controller?.addListener(_requested);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_requested);
    _motion.dispose();
    super.dispose();
  }

  int _distance(int index, int active) {
    var distance = (index - active) % widget.items.length;
    if (distance > widget.items.length / 2) distance -= widget.items.length;
    return distance;
  }

  Future<void> _settle(
    int direction, {
    bool advance = true,
    int? target,
  }) async {
    if (_settling || widget.items.length < 2) return;
    _settling = true;
    _direction = direction;
    _destination = target;
    try {
      await _motion
          .animateTo(
            advance ? 1 : 0,
            duration: Duration(
              milliseconds: advance
                  ? (520 * (1 - _motion.value)).round().clamp(40, 520)
                  : 220,
            ),
            curve: advance ? Curves.easeOutCubic : Curves.linear,
          )
          .orCancel;
      if (!mounted) return;
      setState(() {
        if (advance) {
          _active = _destination ?? (_active + direction) % widget.items.length;
        }
        _destination = null;
        _motion.value = 0;
        _settling = false;
      });
      if (advance) widget.onIndexChanged?.call(_active);
    } on TickerCanceled {
      // The gallery/tab was closed while the stack was settling.
    }
  }

  _StackPose _pose(int distance, double width) {
    final depth = distance.abs().toDouble();
    return _StackPose(
      x: distance * math.min(width * .17, 100),
      y: depth * 3,
      z: -depth * 105,
      scale: 1 - depth * .048,
      rotation: -distance * 7 * math.pi / 180,
      opacity: depth > 2.8 ? 0 : 1,
    );
  }

  void _cancelDrag() {
    if (!_dragging) return;
    _dragging = false;
    _settle(_direction, advance: false);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final cardWidth = math.min(
        width * widget.style.widthFactor,
        widget.style.maxWidth,
      );
      final progress = _motion.value;
      final incoming =
          _destination ?? (_active + _direction) % widget.items.length;
      final layers = <({int index, _StackPose pose, int order})>[];
      for (var index = 0; index < widget.items.length; index++) {
        final distance = _distance(index, _active);
        var pose = _pose(distance, width);
        var order = 30 - distance.abs() * 2;
        if (progress > 0) {
          if (index == _active) {
            final out = -_direction;
            pose = _StackPose(
              x: pose.x + out * progress * math.min(width * .30, 145),
              y: pose.y,
              z: 60 + 80 * math.sin(progress * math.pi),
              scale: 1 - .09 * progress,
              rotation: out * 85 * progress * math.pi / 180,
              opacity: progress > .84 ? (1 - progress) / .16 : 1,
            );
            order = 55;
          } else if (index == incoming) {
            pose = _StackPose.lerp(pose, _pose(0, width), progress);
            order = 45;
          } else {
            pose = _StackPose.lerp(
              pose,
              _pose(_distance(index, incoming), width),
              progress,
            );
          }
        }
        if (pose.opacity > 0) {
          layers.add((index: index, pose: pose, order: order));
        }
      }
      layers.sort((a, b) => a.order.compareTo(b.order));
      final active = widget.items[_active];
      return Semantics(
        label:
            'Video ${_active + 1} of ${widget.items.length}: ${active.title}',
        button: true,
        onTap: () => widget.onOpen(active),
        onIncrease: widget.items.length > 1 ? () => _settle(1) : null,
        onDecrease: widget.items.length > 1 ? () => _settle(-1) : null,
        child: Listener(
          onPointerCancel: (_) => _cancelDrag(),
          child: GestureDetector(
            key: const ValueKey('gallery-video-stack'),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: (details) {
              if (_settling || _dragging) return;
              final edge = (width - cardWidth) / 2;
              if (widget.items.length > 1 && details.localPosition.dx < edge) {
                _settle(-1);
              } else if (widget.items.length > 1 &&
                  details.localPosition.dx > width - edge) {
                _settle(1);
              } else {
                widget.onOpen(active);
              }
            },
            onHorizontalDragStart: (_) {
              if (_settling || widget.items.length < 2) return;
              _dragging = true;
              _drag = 0;
            },
            onHorizontalDragUpdate: (details) {
              if (!_dragging) return;
              _drag += details.delta.dx;
              _direction = _drag < 0 ? 1 : -1;
              _motion.value = (_drag.abs() / math.min(width * .34, 240)).clamp(
                0,
                .95,
              );
            },
            onHorizontalDragEnd: (_) {
              if (!_dragging) return;
              _dragging = false;
              _settle(_direction, advance: _drag.abs() > 45);
            },
            onHorizontalDragCancel: _cancelDrag,
            child: SizedBox(
              height:
                  widget.style.height ??
                  cardWidth / widget.style.aspectRatio + widget.verticalSpacing,
              child: ExcludeSemantics(
                child: Stack(
                  children: [
                    for (final layer in layers)
                      Align(
                        alignment: widget.style.alignment,
                        child: Transform(
                          key: ValueKey(
                            'gallery-video-layer-${widget.items[layer.index].id}',
                          ),
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, -1 / 1100)
                            ..translateByDouble(
                              layer.pose.x,
                              layer.pose.y,
                              layer.pose.z,
                              1,
                            )
                            ..rotateY(layer.pose.rotation)
                            ..scaleByDouble(
                              layer.pose.scale,
                              layer.pose.scale,
                              1,
                              1,
                            ),
                          child: Opacity(
                            opacity: layer.pose.opacity.clamp(0, 1),
                            child: SizedBox(
                              width: cardWidth,
                              height: cardWidth / widget.style.aspectRatio,
                              child: _card(widget.items[layer.index]),
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
      );
    },
  );

  Widget _card(GalleryItem item) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(widget.style.radius),
      border: widget.style.premium
          ? Border.all(color: Colors.white.withValues(alpha: .65))
          : null,
      boxShadow: [
        BoxShadow(
          color: widget.style.premium
              ? const Color(0x3D2B0518)
              : const Color(0x77000000),
          blurRadius: widget.style.premium ? 36 : 30,
          offset: Offset(0, 13),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(widget.style.radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.imageBuilder(item),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD9000000)],
                stops: [.35, 1],
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_outline_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StackPose {
  const _StackPose({
    required this.x,
    required this.y,
    required this.z,
    required this.scale,
    required this.rotation,
    required this.opacity,
  });
  final double x, y, z, scale, rotation, opacity;

  static _StackPose lerp(_StackPose a, _StackPose b, double t) => _StackPose(
    x: a.x + (b.x - a.x) * t,
    y: a.y + (b.y - a.y) * t,
    z: a.z + (b.z - a.z) * t,
    scale: a.scale + (b.scale - a.scale) * t,
    rotation: a.rotation + (b.rotation - a.rotation) * t,
    opacity: a.opacity + (b.opacity - a.opacity) * t,
  );
}
