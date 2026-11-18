import 'package:flutter/material.dart';

/// Paint the photo from its tapped bounds, independent of Hero controllers.
class ProfilePhotoTransition extends StatefulWidget {
  const ProfilePhotoTransition({
    super.key,
    required this.animation,
    required this.source,
    required this.image,
    required this.child,
  });

  final Animation<double> animation;
  final Rect source;
  final ImageProvider image;
  final Widget child;

  @override
  State<ProfilePhotoTransition> createState() => _ProfilePhotoTransitionState();
}

class _ProfilePhotoTransitionState extends State<ProfilePhotoTransition> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
    _stream = widget.image.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, synchronous) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      info.dispose();
      if (synchronous) {
        _imageSize = size;
      } else if (mounted) {
        setState(() => _imageSize = size);
      }
    }, onError: (_, _) {});
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.animation,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final progress = Curves.easeInOutCubic.transform(
          widget.animation.value,
        );
        final viewport = constraints.biggest;
        final fitted = applyBoxFit(
          BoxFit.contain,
          _imageSize ?? const Size(1, 1),
          viewport,
        );
        final target = Alignment.center.inscribe(
          fitted.destination,
          Offset.zero & viewport,
        );
        final rect = Rect.lerp(widget.source, target, progress)!;
        return Stack(
          children: [
            Offstage(
              offstage: !widget.animation.isCompleted,
              child: widget.child,
            ),
            if (!widget.animation.isCompleted) ...[
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: progress),
                ),
              ),
              Positioned.fromRect(
                rect: rect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    rect.shortestSide * .5 * (1 - progress),
                  ),
                  child: Image(
                    key: const ValueKey('profile-photo-zoom-image'),
                    image: widget.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Colors.black),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}
