import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../club_repository.dart';
import '../gallery_cache.dart';

class QuickCardImageCache {
  QuickCardImageCache({http.Client? client, GalleryCache? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? GalleryCache();

  static final instance = QuickCardImageCache();
  final http.Client _client;
  final GalleryCache _storage;
  final _images = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List?>>{};

  Uint8List? peek(String url) => _images[ClubRepository.mediaUrl(url)];

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
    final saved = await _storage.read(url);
    if (saved != null && await _valid(saved.bytes)) {
      return _images[url] = saved.bytes;
    }
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || !await _valid(response.bodyBytes))
        return null;
      _images[url] = response.bodyBytes;
      await _storage.write(
        url,
        SavedGalleryResource(response.bodyBytes, const {}),
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
  });
  final String url;
  final BoxFit fit;
  final Widget fallback;
  final QuickCardImageCache? cache;
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
    _bytes = _cache.peek(widget.url);
    _attempts = 0;
    unawaited(_load(++_version));
  }

  Future<void> _load(int version) async {
    final bytes = await _cache.load(widget.url);
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
    if (oldWidget.url != widget.url || oldWidget.cache != widget.cache)
      _resolve();
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
