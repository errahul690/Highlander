import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:Highlanders/core/media/media_cache.dart';
import 'package:Highlanders/core/media/video_thumbnail.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/shared/data/club_repository.dart';
import 'package:Highlanders/shared/widgets/startup_loader.dart';

/// Keep each card's downloaded photos available until its widgets are disposed,
/// even when other downloads evict entries from the shared memory cache.
class PreparedPostMedia extends InheritedWidget {
  const PreparedPostMedia({
    super.key,
    required this.photos,
    required super.child,
  });
  final Map<String, Uint8List> photos;

  static PreparedPostMedia? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreparedPostMedia>();

  @override
  bool updateShouldNotify(PreparedPostMedia oldWidget) =>
      !identical(photos, oldWidget.photos);
}

/// Reveal a whole card only after its photos have a decoded first frame.
class PostMediaGate extends StatefulWidget {
  const PostMediaGate({
    super.key,
    required this.post,
    required this.child,
    this.cache,
  });
  final Map<String, dynamic> post;
  final Widget child;
  final MediaCache? cache;

  @override
  State<PostMediaGate> createState() => _PostMediaGateState();
}

class _PostMediaGateState extends State<PostMediaGate> {
  static final _prepared = <String, ({List<Object> keys, int bytes})>{};
  static int _preparedBytes = 0;
  String? _signature;
  bool _ready = false, _failed = false;
  int _attempt = 0;
  final _failedPhotos = <String>{};
  Map<String, Uint8List> _photoBytes = const {};
  final _pinnedImages =
      <({ImageStream stream, ImageStreamListener listener})>[];

  void _releaseImages() {
    for (final pin in _pinnedImages) {
      pin.stream.removeListener(pin.listener);
    }
    _pinnedImages.clear();
  }

  @override
  void dispose() {
    _releaseImages();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareIfChanged();
  }

  @override
  void didUpdateWidget(PostMediaGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareIfChanged();
  }

  void _prepareIfChanged({bool retry = false}) {
    if (retry) {
      for (final url in _failedPhotos) {
        (widget.cache ?? MediaCache.instance).evict(url);
      }
    }
    final photos = <String>{}, avatars = <String>{}, videos = <String>{};
    void collect(Map post) {
      final images = post['images'];
      final sources = images is List && images.isNotEmpty
          ? images
          : [post['image']];
      for (final source in sources) {
        final url = ClubRepository.mediaUrl(source);
        if (url.isNotEmpty) photos.add(url);
      }
      final own =
          post['official'] != true &&
          (post['isOwnPost'] == true ||
              (Session.userId.isNotEmpty &&
                  '${post['authorId'] ?? post['userId'] ?? ''}' ==
                      Session.userId) ||
              (Session.email.isNotEmpty &&
                  '${post['authorEmail'] ?? ''}'.toLowerCase() ==
                      Session.email.toLowerCase()));
      final avatar = '${own ? Session.profilePhoto : post['authorImage'] ?? ''}'
          .trim();
      if (avatar.isNotEmpty) {
        avatars.add(Uri.parse(OtpApi.apiBase).resolve(avatar).toString());
      }
      final video = '${post['video'] ?? ''}'.trim();
      if (video.isNotEmpty) videos.add(video);
      if (post['repost'] is Map) collect(post['repost'] as Map);
    }

    collect(widget.post);
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(480, 1440);
    final signature = jsonEncode([
      photos.toList(),
      avatars.toList(),
      videos.toList(),
      width,
      (widget.cache ?? MediaCache.instance).generation.value,
      identityHashCode(widget.cache ?? MediaCache.instance),
    ]);
    if (!retry && _signature == signature) return;
    _releaseImages();
    _photoBytes = const {};
    _signature = signature;
    _ready = photos.isEmpty && avatars.isEmpty && videos.isEmpty;
    _failed = false;
    _failedPhotos.clear();
    final attempt = ++_attempt;
    if (_ready) return;
    final prepared = _prepared.remove(signature);
    if (prepared != null) {
      _preparedBytes -= prepared.bytes;
      final cached = photos.every(
        (url) => (widget.cache ?? MediaCache.instance).bytesFor(url) != null,
      );
      if (!retry &&
          cached &&
          prepared.keys.every((key) {
            final status = PaintingBinding.instance.imageCache.statusForKey(
              key,
            );
            return status.keepAlive || status.live;
          })) {
        _prepared[signature] = prepared;
        _preparedBytes += prepared.bytes;
        _photoBytes = Map.unmodifiable({
          for (final url in photos)
            url: (widget.cache ?? MediaCache.instance).bytesFor(url)!,
        });
        _ready = true;
        return;
      }
    }
    _prepare(photos, avatars, videos, width).then(
      (media) {
        if (!mounted || attempt != _attempt) return;
        final cache = widget.cache ?? MediaCache.instance;
        final bytes =
            media.photos.values.fold<int>(
              0,
              (sum, bytes) => sum + bytes.length,
            ) +
            avatars.fold<int>(
              0,
              (sum, url) => sum + (cache.bytesFor(url)?.length ?? 0),
            );
        _preparedBytes -= _prepared.remove(signature)?.bytes ?? 0;
        if (bytes <= 16 * 1024 * 1024) {
          _prepared[signature] = (keys: media.keys, bytes: bytes);
          _preparedBytes += bytes;
          while (_prepared.length > 40 || _preparedBytes > 16 * 1024 * 1024) {
            _preparedBytes -= _prepared.remove(_prepared.keys.first)!.bytes;
          }
        }
        setState(() {
          _photoBytes = Map.unmodifiable(media.photos);
          _ready = true;
        });
      },
      onError: (Object error, StackTrace stack) {
        if (mounted && attempt == _attempt) setState(() => _failed = true);
      },
    );
  }

  Future<void> _decode(
    ImageProvider image,
    List<Object> keys, {
    bool required = false,
    int? forAttempt,
  }) async {
    final attempt = forAttempt ?? _attempt;
    Object? failure;
    await precacheImage(
      image,
      context,
      onError: (error, _) => failure = error,
    ).timeout(const Duration(seconds: 5));
    if (required && failure != null) throw StateError('Photo unavailable');
    if (failure == null && mounted && attempt == _attempt) {
      keys.add(await image.obtainKey(createLocalImageConfiguration(context)));
      if (required && mounted && attempt == _attempt) {
        // Hold the decoded first frame until the complete card attaches its
        // Image widgets. A second decode must not reveal a blank photo area.
        final stream = image.resolve(createLocalImageConfiguration(context));
        final listener = ImageStreamListener((frame, _) => frame.dispose());
        stream.addListener(listener);
        _pinnedImages.add((stream: stream, listener: listener));
      }
    }
  }

  Future<({List<Object> keys, Map<String, Uint8List> photos})> _prepare(
    Set<String> photos,
    Set<String> avatars,
    Set<String> videos,
    int width,
  ) async {
    final keys = <Object>[];
    final photoBytes = <String, Uint8List>{};
    final attempt = _attempt;
    await Future.wait([
      for (final url in photos)
        () async {
          try {
            final bytes = await (widget.cache ?? MediaCache.instance).ensure(
              url,
            );
            if (!mounted) return;
            if (bytes == null) throw StateError('Photo unavailable');
            photoBytes[url] = bytes;
            // Match FeedPostCard's provider, including its decode width.
            await _decode(
              ResizeImage.resizeIfNeeded(width, null, MemoryImage(bytes)),
              keys,
              required: true,
              forAttempt: attempt,
            );
          } catch (_) {
            if (mounted && attempt == _attempt) _failedPhotos.add(url);
            rethrow;
          }
        }(),
      for (final url in avatars)
        () async {
          final bytes = await (widget.cache ?? MediaCache.instance).ensure(url);
          if (mounted && bytes != null) await _decode(MemoryImage(bytes), keys);
        }().catchError((Object _) {}),
      for (final video in videos)
        () async {
          final path = await VideoThumbnail.load(video);
          if (mounted && path != null) {
            await _decode(FileImage(File(path)), keys);
          }
        }().catchError((Object _) {}),
    ]);
    return (keys: keys, photos: photoBytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready)
      return PreparedPostMedia(photos: _photoBytes, child: widget.child);
    return Semantics(
      label: _failed ? 'Retry loading post' : 'Loading post',
      child: Container(
        key: const ValueKey('post-media-loading'),
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F8),
          borderRadius: BorderRadius.circular(22),
        ),
        child: _failed
            ? IconButton(
                tooltip: 'Retry loading post',
                color: Theme.of(context).colorScheme.primary,
                onPressed: () => setState(() => _prepareIfChanged(retry: true)),
                icon: const Icon(Icons.refresh_rounded),
              )
            : const StartupLoader(),
      ),
    );
  }
}
