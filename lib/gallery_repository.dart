import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'club_repository.dart';
import 'gallery_cache.dart';

class GalleryItem {
  const GalleryItem({
    required this.id,
    required this.title,
    required this.tagline,
    required this.thumbnail,
    this.type = 'images',
    this.images = const [],
    this.videoUrl = '',
    this.isFeatured = false,
    this.fullWidth = false,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String tagline;
  final String thumbnail;
  final String type; // 'images' or 'videos'
  final List<String> images;
  final String videoUrl;
  final bool isFeatured;
  final bool fullWidth;
  final int sortOrder;

  factory GalleryItem.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    List<String> parsedImages = [];
    if (rawImages is List) {
      parsedImages = rawImages
          .map((e) => ClubRepository.mediaUrl(e))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final thumb = ClubRepository.mediaUrl(json['thumbnail'] ?? '');
    var videoUrl = '${json['video_url'] ?? json['videoUrl'] ?? ''}'.trim();
    if (videoUrl.isEmpty && json['videos'] is List) {
      for (final entry in json['videos'] as List) {
        final url = entry is Map
            ? '${entry['url'] ?? entry['video_url'] ?? ''}'.trim()
            : '$entry'.trim();
        if (url.isNotEmpty && url != 'null') {
          videoUrl = url;
          break;
        }
      }
    }

    return GalleryItem(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      tagline: '${json['tagline'] ?? ''}',
      thumbnail: thumb.isNotEmpty
          ? thumb
          : (parsedImages.isNotEmpty ? parsedImages.first : ''),
      type: '${json['type'] ?? 'images'}',
      images: parsedImages,
      videoUrl: ClubRepository.mediaUrl(videoUrl),
      isFeatured: json['is_featured'] == true || json['isFeatured'] == true,
      fullWidth: json['full_width'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class GalleryRepository extends ChangeNotifier {
  GalleryRepository({http.Client? client, GalleryCache? cache})
    : _client = client ?? http.Client(),
      _cache = cache ?? GalleryCache();
  static GalleryRepository instance = GalleryRepository();
  final http.Client _client;
  final GalleryCache _cache;
  final Map<String, SavedGalleryResource> _resources = {};

  final Map<String, List<GalleryItem>> _items = {};
  final Map<String, Future<List<GalleryItem>>> _inFlight = {};
  final Map<String, Uint8List> _bytes = {};
  final Map<String, Future<Uint8List?>> _byteRequests = {};
  final Map<String, int> _generation = {'images': 0, 'videos': 0};

  bool hasLoaded(String type) => _items.containsKey(type);

  List<GalleryItem> current(String type) => _items[type] ?? const [];

  Uint8List? bytesFor(String url) {
    if (url.isEmpty) return null;
    return _bytes[url] ?? _bytes[ClubRepository.mediaUrl(url)];
  }

  /// One download per picture. A later caller waits for the request already running.
  Future<Uint8List?> ensureBytes(String url) {
    final cached = bytesFor(url);
    if (cached != null) return Future.value(cached);
    final resolved = ClubRepository.mediaUrl(url);
    if (resolved.isEmpty) return Future.value(null);
    final pending = _byteRequests[resolved];
    if (pending != null) return pending;
    final request = _downloadOne(url);
    _byteRequests[resolved] = request;
    return request.whenComplete(() {
      if (identical(_byteRequests[resolved], request)) {
        _byteRequests.remove(resolved);
      }
    });
  }

  void invalidateFeedVideos() {
    _generation['videos'] = (_generation['videos'] ?? 0) + 1;
    _items.remove('videos');
    _inFlight.remove('videos');
  }

  /// Latest list for [type]. A finished request stays cached for the feed and Gallery.
  Future<List<GalleryItem>> loadGallery({
    String type = 'images',
    bool useFallback = true,
  }) {
    final cached = _items[type];
    if (cached != null) return Future.value(cached);
    final pending = _inFlight[type];
    if (pending != null) return pending;
    return _start(type);
  }

  /// Ask the server again. The saved list stays on screen when nothing changed.
  /// [force] downloads pictures again even when the address is unchanged.
  Future<List<GalleryItem>> revalidate(String type, {bool force = false}) {
    if (force && _inFlight[type] != null) {
      _generation[type] = (_generation[type] ?? 0) + 1;
    } else if (_inFlight[type] != null) {
      return _inFlight[type]!;
    }
    final request = _revalidate(type, force: force);
    _inFlight[type] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[type], request)) _inFlight.remove(type);
    });
  }

  /// Refresh checks for changes without discarding visible pictures.
  Future<List<GalleryItem>> refresh(String type) => revalidate(type);

  Future<List<GalleryItem>> _start(String type) {
    final generation = _generation[type] ?? 0;
    final request = _fetchAndStore(type, generation);
    _inFlight[type] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[type], request)) _inFlight.remove(type);
    });
  }

  Future<List<GalleryItem>> _fetchAndStore(String type, int generation) async {
    final items = await _fetchGallery(type: type);
    if (items == null || (_generation[type] ?? 0) != generation) {
      return const [];
    }
    await _downloadThumbs(items);
    if ((_generation[type] ?? 0) != generation) return items;
    _items[type] = items;
    notifyListeners();
    unawaited(_revalidatePictures(items));
    return items;
  }

  Future<List<GalleryItem>> _revalidate(
    String type, {
    bool force = false,
  }) async {
    final generation = _generation[type] ?? 0;
    final previous = _items[type];
    final fresh = await _fetchGallery(type: type);
    if ((_generation[type] ?? 0) != generation) return current(type);
    if (fresh == null) return previous ?? const [];
    await _revalidatePictures(fresh, force: force);
    if ((_generation[type] ?? 0) != generation) return current(type);
    if (previous != null && _same(previous, fresh)) return previous;
    await _downloadThumbs(fresh);
    _items[type] = fresh;
    notifyListeners();
    _prefetchAlbumImages(fresh);
    return fresh;
  }

  bool _same(List<GalleryItem> current, List<GalleryItem> next) {
    if (current.length != next.length) return false;
    for (var index = 0; index < current.length; index++) {
      final a = current[index];
      final b = next[index];
      if (a.id != b.id ||
          a.title != b.title ||
          a.tagline != b.tagline ||
          a.thumbnail != b.thumbnail ||
          a.type != b.type ||
          a.videoUrl != b.videoUrl ||
          a.isFeatured != b.isFeatured ||
          a.fullWidth != b.fullWidth ||
          a.sortOrder != b.sortOrder ||
          a.images.length != b.images.length) {
        return false;
      }
      for (var image = 0; image < a.images.length; image++) {
        if (a.images[image] != b.images[image]) return false;
      }
    }
    return true;
  }

  Future<List<GalleryItem>?> _fetchGallery({required String type}) async {
    try {
      final base = ClubRepository.apiBase;
      final uri = Uri.parse('$base/api/public/gallery?type=$type');
      final url = uri.toString();
      final saved = _resources[url] ?? await _cache.read(url);
      http.Response? res;
      try {
        res = await _client
            .get(uri, headers: saved?.validators)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        if (saved == null) rethrow;
      }
      final bytes = res?.statusCode == 200 ? res!.bodyBytes : saved?.bytes;
      if (bytes != null) {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! List) return null;
        if (res?.statusCode == 200) {
          final resource = SavedGalleryResource(bytes, res!.headers);
          _resources[url] = resource;
          await _cache.write(url, resource);
        }
        return decoded
            .whereType<Map>()
            .map((row) => GalleryItem.fromJson(Map<String, dynamic>.from(row)))
            .where((item) => item.title.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    return null;
  }

  Future<void> _downloadThumbs(List<GalleryItem> items) {
    final urls = items
        .map((item) => item.thumbnail)
        .where((url) => url.isNotEmpty)
        .toSet();
    return Future.wait(urls.map(ensureBytes));
  }

  void _prefetchAlbumImages(List<GalleryItem> items) {
    for (final item in items) {
      for (final url in item.images) {
        if (url.isNotEmpty) unawaited(ensureBytes(url));
      }
    }
  }

  Future<Uint8List?> _downloadOne(String url) async {
    final resolved = ClubRepository.mediaUrl(url);
    if (resolved.isEmpty) return null;
    final cached = _bytes[resolved];
    if (cached != null) return cached;
    final saved = await _cache.read(resolved);
    if (saved != null && saved.bytes.isNotEmpty) {
      _resources[resolved] = saved;
      _bytes[resolved] = saved.bytes;
      return saved.bytes;
    }
    try {
      final response = await _client
          .get(Uri.parse(resolved))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _bytes[resolved] = response.bodyBytes;
        _bytes[url] = response.bodyBytes;
        final resource = SavedGalleryResource(
          response.bodyBytes,
          response.headers,
        );
        _resources[resolved] = resource;
        await _cache.write(resolved, resource);
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _revalidatePictures(
    List<GalleryItem> items, {
    bool force = false,
  }) async {
    final urls = {
      for (final item in items) ...[item.thumbnail, ...item.images],
    }..remove('');
    await Future.wait(
      urls.map((url) async {
        final resolved = ClubRepository.mediaUrl(url);
        if (resolved.isEmpty) return;
        if (force) {
          _bytes.remove(url);
          _bytes.remove(resolved);
          _resources.remove(resolved);
          _byteRequests.remove(resolved);
          try {
            final response = await _client
                .get(Uri.parse(resolved))
                .timeout(const Duration(seconds: 8));
            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
              final resource = SavedGalleryResource(
                response.bodyBytes,
                response.headers,
              );
              _resources[resolved] = resource;
              _bytes[resolved] = resource.bytes;
              _bytes[url] = resource.bytes;
              await _cache.write(resolved, resource);
              notifyListeners();
            }
          } catch (_) {}
          return;
        }
        final saved = _resources[resolved] ?? await _cache.read(resolved);
        await ensureBytes(url);
        // With versioned URLs, a new URL is enough to detect changed pictures.
        // Validators also detect a replacement served from the same URL.
        if (saved == null || saved.validators.isEmpty) return;
        try {
          final response = await _client
              .get(Uri.parse(resolved), headers: saved.validators)
              .timeout(const Duration(seconds: 8));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) return;
          final resource = SavedGalleryResource(
            response.bodyBytes,
            response.headers,
          );
          _resources[resolved] = resource;
          await _cache.write(resolved, resource);
          if (listEquals(saved.bytes, resource.bytes)) return;
          _bytes[resolved] = resource.bytes;
          _bytes[url] = resource.bytes;
          notifyListeners();
        } catch (_) {
          // Keep the picture visible while offline or when validation fails.
        }
      }),
    );
  }
}
