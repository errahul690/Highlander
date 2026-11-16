import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import 'package:Highlanders/shared/data/club_repository.dart';
import 'package:Highlanders/core/media/media_disk_cache.dart';

/// Pictures downloaded before the feed opens, so the first paint does not fetch them.
class MediaCache {
  MediaCache({
    http.Client? client,
    MediaDiskCache? storage,
    this.maxMemoryBytes = 32 * 1024 * 1024,
    this.maxMemoryFiles = 60,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? MediaDiskCache();
  static final MediaCache instance = MediaCache();
  final http.Client _client;
  final MediaDiskCache _storage;
  final int maxMemoryBytes, maxMemoryFiles;
  final _bytes = <String, Uint8List>{};
  int _memoryBytes = 0;
  final Map<String, Future<Uint8List?>> _requests = {};
  final generation = ValueNotifier<int>(0);

  /// Retry a single failed/corrupt photo without clearing successful photos.
  void evict(String url) {
    final resolved = ClubRepository.mediaUrl(url);
    final removed = _bytes.remove(resolved);
    _memoryBytes -= removed?.length ?? 0;
    unawaited(_storage.remove(resolved));
  }

  /// Drop saved pictures so the next paint downloads them again.
  void invalidate() {
    _bytes.clear();
    _memoryBytes = 0;
    _requests.clear();
    generation.value++;
    unawaited(_storage.clear());
  }

  Uint8List? bytesFor(String url) {
    if (url.isEmpty) return null;
    final resolved = ClubRepository.mediaUrl(url);
    final bytes = _bytes.remove(resolved);
    if (bytes != null) _bytes[resolved] = bytes;
    return bytes;
  }

  Future<void> prefetch(Iterable<String> urls) async {
    final unique = urls.where((url) => url.isNotEmpty).toSet();
    await Future.wait(unique.map(ensure));
  }

  Future<Uint8List?> ensure(String url) {
    final cached = bytesFor(url);
    if (cached != null) return Future.value(cached);
    final resolved = ClubRepository.mediaUrl(url);
    if (resolved.isEmpty) return Future.value(null);
    final pending = _requests[resolved];
    if (pending != null) return pending;
    final request = _download(resolved, generation.value);
    _requests[resolved] = request;
    return request.whenComplete(() {
      if (identical(_requests[resolved], request)) _requests.remove(resolved);
    });
  }

  void _remember(String url, Uint8List bytes) {
    _memoryBytes -= _bytes.remove(url)?.length ?? 0;
    if (bytes.length > maxMemoryBytes || maxMemoryFiles < 1) return;
    _bytes[url] = bytes;
    _memoryBytes += bytes.length;
    while (_memoryBytes > maxMemoryBytes || _bytes.length > maxMemoryFiles) {
      _memoryBytes -= _bytes.remove(_bytes.keys.first)!.length;
    }
  }

  Future<Uint8List?> _download(String resolved, int version) async {
    try {
      final saved = await _storage.read(resolved);
      if (version != generation.value) return null;
      if (saved != null && saved.isNotEmpty) {
        _remember(resolved, saved);
        await warmImage(saved);
        return saved;
      }
      final response = await _client
          .get(Uri.parse(resolved))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      if (version != generation.value) return null;
      _remember(resolved, response.bodyBytes);
      unawaited(_storage.write(resolved, response.bodyBytes));
      await warmImage(response.bodyBytes);
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}

/// Decode once so [Image.memory] can paint the frame that is already in the cache.
Future<void> warmImage(Uint8List bytes) async {
  final stream = MemoryImage(bytes).resolve(const ImageConfiguration());
  final done = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (image, _) {
      image.dispose();
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
    onError: (_, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
  );
  stream.addListener(listener);
  try {
    await done.future.timeout(const Duration(seconds: 3));
  } catch (_) {}
}
