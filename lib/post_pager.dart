import 'dart:async';

import 'package:flutter/foundation.dart';

import 'club_repository.dart';
import 'media_cache.dart';

typedef FetchPostPage = Future<Map<String, dynamic>> Function(String? cursor);

Iterable<String> _postPhotoUrls(Map<String, dynamic> post) sync* {
  final seen = <String>{};
  String? take(Object? value) {
    final url = ClubRepository.mediaUrl(value);
    if (url.isEmpty || !seen.add(url)) return null;
    return url;
  }

  final images = post['images'];
  if (images is List) {
    for (final image in images) {
      final url = take(image);
      if (url != null) yield url;
    }
  }
  final single = take(post['image']);
  if (single != null) yield single;
  final repost = post['repost'];
  if (repost is Map) yield* _postPhotoUrls(Map<String, dynamic>.from(repost));
}

/// One in-flight page per list, with stale responses discarded after refresh.
class PostPager extends ChangeNotifier {
  PostPager(this.fetch);
  final FetchPostPage fetch;
  List<Map<String, dynamic>> posts = [];
  Map<String, dynamic> response = {};
  bool loading = false, hasMore = true;
  String? error, _cursor;
  int _generation = 0;
  bool _disposed = false, _refreshAgain = false, _failedReset = true;
  Future<void>? _refreshing;

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_refreshing != null) {
      _refreshAgain = true;
      return _refreshing!;
    }
    final operation = _refresh();
    _refreshing = operation;
    return operation;
  }

  Future<void> _refresh() async {
    try {
      do {
        _refreshAgain = false;
        await _load(reset: true);
      } while (_refreshAgain && !_disposed);
    } finally {
      _refreshing = null;
    }
  }

  Future<void> next() async {
    if (_disposed || loading || !hasMore) return;
    await _load(reset: false);
  }

  Future<void> retry() => _failedReset ? refresh() : next();

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_generation : _generation;
    final cursor = reset ? null : _cursor;
    _failedReset = reset;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await fetch(cursor);
      if (_disposed || generation != _generation) return;
      if (data['posts'] is! List ||
          (data['posts'] as List).any((row) => row is! Map)) {
        throw const FormatException('Invalid posts');
      }
      final page = (data['posts'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final nextCursor = data['nextCursor'];
      final more = data['hasMore'] == true;
      if (more &&
          (nextCursor is! String ||
              nextCursor.isEmpty ||
              nextCursor == cursor ||
              page.isEmpty)) {
        throw const FormatException('Invalid pagination');
      }
      final unique = <String, Map<String, dynamic>>{};
      for (final post in [
        ...(reset ? <Map<String, dynamic>>[] : posts),
        ...page,
      ]) {
        final id = post['_id']?.toString();
        if (id == null || id.isEmpty) {
          throw const FormatException('Missing post ID');
        }
        unique[id] = post;
      }
      posts = unique.values.toList();
      response = data;
      await _warmPostPhotos(page);
      _cursor = more ? nextCursor as String : null;
      hasMore = more;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = 'Could not load posts. Tap to retry.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _warmPostPhotos(List<Map<String, dynamic>> page) async {
    final first = <String>[];
    final rest = <String>[];
    for (final post in page) {
      final urls = _postPhotoUrls(post).toList();
      if (urls.isEmpty) continue;
      if (first.length < 6) {
        first.add(urls.first);
        rest.addAll(urls.skip(1));
      } else {
        rest.addAll(urls);
      }
    }
    if (rest.isNotEmpty) unawaited(MediaCache.instance.prefetch(rest));
    if (first.isEmpty) return;
    try {
      await MediaCache.instance.prefetch(first).timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
