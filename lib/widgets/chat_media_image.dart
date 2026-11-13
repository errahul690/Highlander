import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../chat_media_cache.dart';
import '../media_auto_download.dart';

import 'dart:async';

import '../screens/photo_viewer_screen.dart';
import '../theme.dart';

/// Automatic small preview, with an explicit download for the original photo.
class ChatMediaImage extends StatefulWidget {
  const ChatMediaImage({
    super.key,
    required this.url,
    this.thumbnail = '',
    this.width = 230,
    this.height,
    this.openOnTap = false,
  });
  final String url, thumbnail;
  final double width;
  final double? height;
  final bool openOnTap;
  @override
  State<ChatMediaImage> createState() => _ChatMediaImageState();
}

class _ChatMediaImageState extends State<ChatMediaImage> {
  late final _preferences = MediaAutoDownload.instance;
  bool _autoTried = false;
  Uint8List? _bytes;
  bool _original = false;
  bool _downloaded = false, _downloading = false, _downloadFailed = false;
  double _aspectRatio = 4 / 3;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _preferences.addListener(_settingsChanged);
    unawaited(_preferences.restore());
    _resolve();
  }

  @override
  void dispose() {
    _preferences.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    _autoTried = false;
    _maybeAuto();
  }

  void _maybeAuto() {
    if (mounted &&
        widget.openOnTap &&
        !_downloaded &&
        !_downloading &&
        !_autoTried &&
        _preferences.photos) {
      _autoTried = true;
      unawaited(_tap());
    }
  }

  @override
  void didUpdateWidget(ChatMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.thumbnail != widget.thumbnail) {
      _resolve();
    }
  }

  void _resolve() {
    final cache = ChatMediaCache.instance;
    final display = cache.peekDisplay(widget.url);
    _downloaded = display?.downloaded ?? false;
    final original = _downloaded ? cache.peek(widget.url) : null;
    _bytes = original ?? display?.bytes;
    _original = original != null;
    _aspectRatio = display?.aspectRatio ?? 4 / 3;
    _downloading = false;
    _autoTried = false;
    _downloadFailed = false;
    _load(++_version);
  }

  Future<void> _load(int version) async {
    final display = await ChatMediaCache.instance.display(
      widget.url,
      thumbnail: widget.thumbnail,
    );
    if (!mounted || version != _version) return;
    if (display == null) {
      _maybeAuto();
      return;
    }
    setState(() {
      final original = display.downloaded
          ? ChatMediaCache.instance.peek(widget.url)
          : null;
      _bytes = original ?? display.bytes;
      _original = original != null;
      _downloaded = display.downloaded;
      _aspectRatio = display.aspectRatio;
    });
    if (display.downloaded && widget.openOnTap && !_original) {
      final bytes = await ChatMediaCache.instance.cached(widget.url);
      if (!mounted || version != _version || bytes == null) return;
      setState(() {
        _bytes = bytes;
        _original = true;
      });
    }
    _maybeAuto();
  }

  Future<void> _tap() async {
    if (_downloading) return;
    if (!_downloaded) {
      final version = ++_version;
      setState(() {
        _downloading = true;
        _downloadFailed = false;
      });
      final bytes = await ChatMediaCache.instance.load(widget.url);
      final display = bytes == null
          ? null
          : await ChatMediaCache.instance.display(
              widget.url,
              thumbnail: widget.thumbnail,
            );
      if (!mounted || version != _version) return;
      setState(() {
        _downloading = false;
        _downloadFailed = bytes == null;
        if (bytes != null) {
          _bytes = bytes;
          _original = true;
          _downloaded = true;
          _aspectRatio = display?.aspectRatio ?? _aspectRatio;
        }
      });
      return;
    }
    final bytes = await ChatMediaCache.instance.load(widget.url);
    if (!mounted || bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewerScreen(
          images: const [],
          imageProvider: MemoryImage(bytes),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.openOnTap ? _tap : null,
      child: SizedBox(
        width: widget.width,
        height: widget.height ?? widget.width / _aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFF1E9EC)),
            if (_bytes != null)
              Image.memory(
                _bytes!,
                fit: widget.height == null ? BoxFit.contain : BoxFit.cover,
                // Decode the original at the screen pixel density, not thumbnail size.
                cacheWidth: _original
                    ? (widget.width * MediaQuery.devicePixelRatioOf(context))
                          .ceil()
                          .clamp(1, 1536)
                    : null,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: authMuted),
                ),
              )
            else
              const Center(
                child: Icon(Icons.image_outlined, color: authMuted, size: 32),
              ),
            if (widget.openOnTap && !_downloaded)
              Center(
                child: Material(
                  color: const Color(0xD92B2227),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    key: const ValueKey('chat-photo-download'),
                    onTap: _downloading ? null : _tap,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_downloading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            Icon(
                              _downloadFailed
                                  ? Icons.refresh
                                  : Icons.download_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            _downloading
                                ? 'Downloading…'
                                : _downloadFailed
                                ? 'Retry'
                                : 'Download',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
