import 'dart:convert';

import 'package:http/http.dart' as http;

import 'club_repository.dart';

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

class GalleryRepository {
  GalleryRepository({http.Client? client}) : _client = client ?? http.Client();
  static GalleryRepository instance = GalleryRepository();
  final http.Client _client;

  Future<List<GalleryItem>>? _feedVideos;
  int _videoFetch = 0;

  void invalidateFeedVideos() {
    _videoFetch++;
    _feedVideos = null;
  }

  Future<List<GalleryItem>> loadGallery({
    String type = 'images',
    bool useFallback = true,
  }) {
    if (type == 'videos' && !useFallback) {
      final current = _feedVideos;
      if (current != null) return current;
      final generation = _videoFetch;
      final request = _fetchGallery(type: type);
      _feedVideos = request;
      return request.then((items) {
        if (generation == _videoFetch && identical(_feedVideos, request)) {
          _feedVideos = null;
        }
        return items;
      });
    }
    return _fetchGallery(type: type);
  }

  Future<List<GalleryItem>> _fetchGallery({
    required String type,
  }) async {
    try {
      final base = ClubRepository.apiBase;
      final uri = Uri.parse('$base/api/public/gallery?type=$type');
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.isNotEmpty) {
          final items = decoded
              .map((row) => GalleryItem.fromJson(row as Map<String, dynamic>))
              .where((item) => item.title.isNotEmpty)
              .toList();
          if (items.isNotEmpty) return items;
        }
      }
    } catch (_) {}

    return const [];
  }
}
