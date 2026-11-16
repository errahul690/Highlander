import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:Highlanders/shared/data/club_repository.dart';
import 'package:Highlanders/core/media/media_cache.dart';
import 'package:Highlanders/features/gallery/data/gallery_cache.dart';

class QuickCardImageCache {
  QuickCardImageCache({http.Client? client, GalleryCache? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? GalleryCache();

  static final instance = QuickCardImageCache();
  final http.Client _client;
  final GalleryCache _storage;
  final _images = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List?>>{};
  final _backgrounds = <String, Uint8List>{};
  final _backgroundPending = <String, Future<Uint8List?>>{};

  Uint8List? peek(String url) => _images[ClubRepository.mediaUrl(url)];
  Uint8List? peekBackground(String url) =>
      _backgrounds[ClubRepository.mediaUrl(url)];

  /// Uploaded card backgrounds can contain a transparent margin and baked shadow.
  /// Fit the opaque card itself to the same bounds as its loading placeholder.
  Future<Uint8List?> loadBackground(String url) {
    final resolved = ClubRepository.mediaUrl(url);
    if (resolved.isEmpty) return Future.value(null);
    if (_backgrounds.containsKey(resolved))
      return Future.value(_backgrounds[resolved]);
    return _backgroundPending[resolved] ??=
        () async {
          final bytes = await load(resolved);
          if (bytes == null) return null;
          final fitted = await _trimBackground(bytes);
          _backgrounds[resolved] = fitted;
          await warmImage(fitted);
          return fitted;
        }().whenComplete(() {
          _backgroundPending.remove(resolved);
        });
  }

  Future<Uint8List> _trimBackground(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? source;
    ui.Image? cropped;
    ui.Picture? picture;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      if (codec.frameCount != 1) return bytes;
      source = (await codec.getNextFrame()).image;
      final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return bytes;
      final pixels = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      var left = source.width, top = source.height, right = -1, bottom = -1;
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          // Exclude transparent padding and the faint exported drop shadow.
          if (pixels[(y * source.width + x) * 4 + 3] < 128) continue;
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
      if (right < left ||
          bottom < top ||
          (left == 0 &&
              top == 0 &&
              right == source.width - 1 &&
              bottom == source.height - 1))
        return bytes;
      final width = right - left + 1, height = bottom - top + 1;
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        source,
        ui.Rect.fromLTWH(
          left.toDouble(),
          top.toDouble(),
          width.toDouble(),
          height.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint(),
      );
      picture = recorder.endRecording();
      cropped = await picture.toImage(width, height);
      final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
      return png?.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes) ??
          bytes;
    } catch (_) {
      return bytes;
    } finally {
      cropped?.dispose();
      source?.dispose();
      picture?.dispose();
      codec?.dispose();
    }
  }

  Future<Uint8List?> load(String url) {
    final resolved = ClubRepository.mediaUrl(url);
    if (resolved.isEmpty) return Future.value(null);
    if (_images.containsKey(resolved)) return Future.value(_images[resolved]);
    return _pending[resolved] ??= _load(resolved).whenComplete(() {
      _pending.remove(resolved);
    });
  }

  Future<bool> _valid(Uint8List bytes) async {
    try {
      final codec = await ui
          .instantiateImageCodec(bytes)
          .timeout(const Duration(seconds: 5));
      codec.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> _load(String url) async {
    final saved = await _storage
        .read(url)
        .timeout(const Duration(milliseconds: 300), onTimeout: () => null);
    if (saved != null && await _valid(saved.bytes)) {
      _images[url] = saved.bytes;
      await warmImage(saved.bytes);
      return saved.bytes;
    }
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || !await _valid(response.bodyBytes)) {
        return null;
      }
      _images[url] = response.bodyBytes;
      await warmImage(response.bodyBytes);
      unawaited(
        _storage.write(url, SavedGalleryResource(response.bodyBytes, const {})),
      );
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}

class QuickCardImage extends StatefulWidget {
  const QuickCardImage({
    super.key,
    required this.url,
    required this.fit,
    required this.fallback,
    this.cache,
    this.trimTransparentPadding = false,
  });
  final String url;
  final BoxFit fit;
  final Widget fallback;
  final QuickCardImageCache? cache;
  final bool trimTransparentPadding;
  @override
  State<QuickCardImage> createState() => _QuickCardImageState();
}

class _QuickCardImageState extends State<QuickCardImage>
    with WidgetsBindingObserver {
  Uint8List? _bytes;
  Timer? _retry;
  int _version = 0;
  int _attempts = 0;
  QuickCardImageCache get _cache =>
      widget.cache ?? QuickCardImageCache.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolve();
  }

  void _resolve() {
    _retry?.cancel();
    _bytes = widget.trimTransparentPadding
        ? _cache.peekBackground(widget.url)
        : _cache.peek(widget.url);
    _attempts = 0;
    unawaited(_load(++_version));
  }

  Future<void> _load(int version) async {
    final bytes = await (widget.trimTransparentPadding
        ? _cache.loadBackground(widget.url)
        : _cache.load(widget.url));
    if (!mounted || version != _version) return;
    if (bytes != null) {
      setState(() => _bytes = bytes);
    } else if (++_attempts < 4) {
      _retry = Timer(
        Duration(seconds: 1 << (_attempts - 1)),
        () => _load(version),
      );
    }
  }

  @override
  void didUpdateWidget(QuickCardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.cache != widget.cache ||
        oldWidget.trimTransparentPadding != widget.trimTransparentPadding) {
      _resolve();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _bytes == null) _resolve();
  }

  @override
  void dispose() {
    _version++;
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _bytes == null
      ? widget.fallback
      : Image.memory(
          _bytes!,
          fit: widget.fit,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, error, stack) => widget.fallback,
        );
}
