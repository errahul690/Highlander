import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../media_cache.dart';

/// Trim transparent padding and soft outer shadows from exported card artwork.
/// Opaque artwork, including its white frame, remains intact.
Rect pollArtworkBounds(Uint8List rgba, int width, int height) {
  var left = width, top = height, right = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (rgba[(y * width + x) * 4 + 3] < 250) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  return right < left || bottom < top
      ? Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble())
      : Rect.fromLTRB(
          left.toDouble(),
          top.toDouble(),
          right + 1.0,
          bottom + 1.0,
        );
}

class PollBackgroundImage extends StatefulWidget {
  const PollBackgroundImage({super.key, required this.source, this.cache});
  final String source;
  final MediaCache? cache;

  @override
  State<PollBackgroundImage> createState() => _PollBackgroundImageState();
}

class _PollBackgroundImageState extends State<PollBackgroundImage> {
  ui.Image? _image;
  Rect _bounds = Rect.zero;
  int _version = 0;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(PollBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _retry?.cancel();
      unawaited(_resolve());
    }
  }

  Future<void> _resolve({bool retry = true}) async {
    final version = ++_version;
    final bytes = await (widget.cache ?? MediaCache.instance).ensure(widget.source);
    if (!mounted || version != _version) return;
    if (bytes == null) {
      if (retry) {
        _retry = Timer(const Duration(seconds: 1), () {
          if (mounted) unawaited(_resolve(retry: false));
        });
      }
      return;
    }
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      decoded = (await codec.getNextFrame()).image;
      if (!mounted || version != _version) {
        decoded.dispose();
        return;
      }
      final image = decoded;
      final previous = _image;
      // Paint the image immediately; alpha trimming must not delay visibility.
      setState(() {
        _image = image;
        _bounds = Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );
      });
      previous?.dispose();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data != null && mounted && version == _version) {
          final bounds = pollArtworkBounds(
            data.buffer.asUint8List(),
            image.width,
            image.height,
          );
          setState(() => _bounds = bounds);
        }
      } catch (_) {
        // Keep the complete image visible if pixel extraction is unsupported.
      }
    } catch (_) {
      if (decoded != null && !identical(decoded, _image)) decoded.dispose();
    } finally {
      codec?.dispose();
    }
  }

  @override
  void dispose() {
    _version++;
    _retry?.cancel();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: _image == null
        ? null
        : CustomPaint(painter: _ArtworkPainter(_image!, _bounds)),
  );
}

class _ArtworkPainter extends CustomPainter {
  const _ArtworkPainter(this.image, this.bounds);
  final ui.Image image;
  final Rect bounds;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    bounds,
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.medium,
  );

  @override
  bool shouldRepaint(_ArtworkPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.bounds != bounds;
}
