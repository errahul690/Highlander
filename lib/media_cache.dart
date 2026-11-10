import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import 'club_repository.dart';

/// Pictures downloaded before the feed opens, so the first paint does not fetch them.
class MediaCache {
  MediaCache({http.Client? client}) : _client = client ?? http.Client();
  static final MediaCache instance = MediaCache();
  final http.Client _client;
  final Map<String, Uint8List> _bytes = {};
  final Map<String, Future<Uint8List?>> _requests = {};
  final generation = ValueNotifier<int>(0);

  /// Drop saved pictures so the next paint downloads them again.
  void invalidate() {
    _bytes.clear();
    _requests.clear();
    generation.value++;
  }

  Uint8List? bytesFor(String url) {
    if (url.isEmpty) return null;
    final resolved = ClubRepository.mediaUrl(url);
    return _bytes[url] ?? _bytes[resolved];
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
    final request = _download(url, resolved);
    _requests[resolved] = request;
    return request.whenComplete(() {
      if (identical(_requests[resolved], request)) _requests.remove(resolved);
    });
  }

  Future<Uint8List?> _download(String url, String resolved) async {
    try {
      final response = await _client
          .get(Uri.parse(resolved))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      _bytes[resolved] = response.bodyBytes;
      _bytes[url] = response.bodyBytes;
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
