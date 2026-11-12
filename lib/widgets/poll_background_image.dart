import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
  const PollBackgroundImage({super.key, required this.source});
  final String source;

  @override
  State<PollBackgroundImage> createState() => _PollBackgroundImageState();
}

class _PollBackgroundImageState extends State<PollBackgroundImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;
  Rect _bounds = Rect.zero;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PollBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _resolve();
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolve() {
    final version = ++_version;
    _detach();
    _info?.dispose();
    _info = null;
    _stream = NetworkImage(widget.source).resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, synchronousCall) async {
      _detach();
      final image = info.image;
      var bounds = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data != null) {
          bounds = pollArtworkBounds(
            data.buffer.asUint8List(),
            image.width,
            image.height,
          );
        }
      } catch (_) {
        // If pixels cannot be read, display the complete original image.
      }
      if (!mounted || version != _version) {
        info.dispose();
        return;
      }
      setState(() {
        _info = info;
        _bounds = bounds;
      });
    }, onError: (Object error, StackTrace? stack) => _detach());
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    _version++;
    _detach();
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: _info == null
        ? null
        : CustomPaint(painter: _ArtworkPainter(_info!.image, _bounds)),
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
