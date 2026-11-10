import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../gallery_repository.dart';
import '../gallery_decoded_cache.dart';

/// Paints a gallery picture from the bytes saved at startup.
/// Parent rebuilds do not start another download.
class GalleryImage extends StatefulWidget {
  const GalleryImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.expand = true,
    this.placeholder = const Color(0xFFE5E7EB),
    this.decodeWidth = 512,
  });

  final String url;
  final BoxFit fit;
  final bool expand;
  final Color placeholder;
  final int decodeWidth;

  @override
  State<GalleryImage> createState() => _GalleryImageState();
}

class _GalleryImageState extends State<GalleryImage> {
  static final _decoded = GalleryDecodedCache();
  Uint8List? _bytes;
  ui.Image? _image;
  int _request = 0;
  late final GalleryRepository _gallery = GalleryRepository.instance;

  @override
  void initState() {
    super.initState();
    _gallery.addListener(_onGallery);
    _resolve();
  }

  void _onGallery() {
    final bytes = _gallery.bytesFor(widget.url);
    if (!mounted || bytes == null || identical(bytes, _bytes)) return;
    setState(_resolve);
  }

  @override
  void dispose() {
    _gallery.removeListener(_onGallery);
    _request++;
    _image?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GalleryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url &&
        oldWidget.decodeWidth == widget.decodeWidth) {
      return;
    }
    if (oldWidget.url != widget.url) {
      _image?.dispose();
      _image = null;
    }
    _resolve();
  }

  void _resolve() {
    final request = ++_request;
    final bytes = _gallery.bytesFor(widget.url);
    _bytes = bytes;
    final ready = bytes == null
        ? null
        : _decoded.lookup(bytes, widget.decodeWidth);
    if (ready != null) {
      _image?.dispose();
      _image = ready;
    } else if (widget.url.isNotEmpty) {
      unawaited(_load(widget.url, request));
    }
  }

  Future<void> _load(String url, int request) async {
    final bytes = await _gallery.ensureBytes(url);
    if (!mounted || request != _request || bytes == null) return;
    try {
      final image = await _decoded.load(bytes, widget.decodeWidth);
      if (!mounted || request != _request) {
        image.dispose();
        return;
      }
      setState(() {
        _bytes = bytes;
        _image?.dispose();
        _image = image;
      });
    } catch (_) {
      // Invalid pictures keep their placeholder or the last valid frame.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) return ColoredBox(color: widget.placeholder);
    final image = RawImage(image: _image, fit: widget.fit);
    if (!widget.expand) return image;
    return SizedBox.expand(child: image);
  }
}
