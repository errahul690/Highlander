import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import 'club_repository.dart';
import 'grounds_cache.dart';

class GroundGalleryItem {
  const GroundGalleryItem({
    required this.url,
    required this.fullWidth,
    required this.displayOrder,
  });

  final String url;
  final bool fullWidth;
  final int displayOrder;
}

class GroundRecord {
  const GroundRecord({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    required this.type,
    required this.description,
    required this.address,
    required this.pitch,
    required this.capacity,
    required this.image,
    required this.gallery,
    required this.galleryLayout,
    required this.facilities,
  });

  final String id;
  final String name;
  final String city;
  final String state;
  final String type;
  final String description;
  final String address;
  final String pitch;
  final String capacity;
  final String image;
  final List<String> gallery;
  final List<GroundGalleryItem> galleryLayout;
  final List<String> facilities;

  factory GroundRecord.fromJson(Map<String, dynamic> json) {
    final legacyGallery = (json['gallery'] as List? ?? const [])
        .map(ClubRepository.mediaUrl)
        .where((value) => value.isNotEmpty)
        .toList();
    final rawLayout = json['gallery_layout'] as List? ?? const [];
    final layout =
        rawLayout.indexed
            .map((entry) {
              final index = entry.$1;
              final raw = entry.$2;
              if (raw is! Map) return null;
              final item = Map<String, dynamic>.from(raw);
              final url = ClubRepository.mediaUrl(item['url']);
              if (url.isEmpty) return null;
              return GroundGalleryItem(
                url: url,
                fullWidth: item['full_width'] == true,
                displayOrder: (item['display_order'] as num?)?.toInt() ?? index,
              );
            })
            .whereType<GroundGalleryItem>()
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final galleryLayout = layout.isNotEmpty
        ? layout
        : legacyGallery.indexed
              .map(
                (entry) => GroundGalleryItem(
                  url: entry.$2,
                  fullWidth: false,
                  displayOrder: entry.$1,
                ),
              )
              .toList();
    return GroundRecord(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      city: '${json['city'] ?? ''}',
      state: '${json['state'] ?? ''}',
      type: '${json['type'] ?? ''}',
      description: '${json['description'] ?? ''}',
      address: '${json['address'] ?? ''}',
      pitch: '${json['pitch'] ?? ''}',
      capacity: '${json['capacity'] ?? ''}',
      image: ClubRepository.mediaUrl(json['image']),
      gallery: galleryLayout.map((item) => item.url).toList(),
      galleryLayout: galleryLayout,
      facilities: (json['facilities'] as List? ?? const [])
          .map((value) => '$value')
          .where((value) => value.isNotEmpty)
          .toList(),
    );
  }

  String get location =>
      [city, state].where((value) => value.isNotEmpty).join(', ');
}

class GroundsContent {
  const GroundsContent({
    required this.title,
    required this.subtitle,
    required this.mapImage,
    required this.mapHtml,
    required this.mapHtmlHeight,
    required this.grounds,
    this.mapHtmlContent = '',
    this.mapImagePath = '',
  });

  final String title;
  final String subtitle;
  final String mapImage;
  final String mapHtml;
  final double mapHtmlHeight;
  final List<GroundRecord> grounds;
  final String mapHtmlContent, mapImagePath;
}

class GroundsRepository {
  GroundsRepository({http.Client? client, GroundsCache? cache})
    : _client = client ?? http.Client(),
      _cache = cache ?? (client == null ? GroundsCache() : null);

  static GroundsRepository instance = GroundsRepository();
  final http.Client _client;
  final GroundsCache? _cache;
  GroundsContent? _cachedContent;
  GroundsContent? get cachedContent => _cachedContent;
  int _loadVersion = 0;
  Future<void>? _restoring;
  Future<GroundsContent>? _preloading;
  DateTime? _lastPreload;
  bool _preloadAgain = false;

  Future<void> restore() => _restoring ??= () async {
    if (_cache == null) return;
    try {
      final version = _loadVersion;
      final saved = await _cache.read(ClubRepository.apiBase);
      if (saved != null && _cachedContent == null && version == _loadVersion) {
        _cachedContent = _parse(
          saved.payload,
          html: saved.html,
          imagePath: saved.imagePath,
        );
      }
    } catch (_) {
      // A damaged optional cache must not prevent the app from starting.
    }
  }();

  Future<void> preload({bool force = false}) async {
    await restore();
    if (_preloading != null) {
      _preloadAgain |= force;
      try {
        await _preloading;
      } catch (_) {}
      return;
    }
    if (!force &&
        _lastPreload != null &&
        DateTime.now().difference(_lastPreload!) <
            const Duration(minutes: 15)) {
      return;
    }
    try {
      _preloading = load();
      await _preloading;
      _lastPreload = DateTime.now();
    } catch (_) {
      // Preloading is best effort and never delays entering the app.
    } finally {
      _preloading = null;
      if (_preloadAgain) {
        _preloadAgain = false;
        unawaited(preload(force: true));
      }
    }
  }

  Future<GroundsContent> loadForDisplay() => _preloading ?? load();

  Future<GroundsContent> load() async {
    final version = ++_loadVersion;
    final baseUrl = ClubRepository.apiBase;
    final response = await _client
        .get(Uri.parse('$baseUrl/api/public/grounds'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Could not load grounds. Please try again.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    SavedGrounds? saved;
    if (_cache != null) {
      try {
        saved = await _cache.prepare(json, baseUrl, _client);
        if (version == _loadVersion) {
          await _cache.commit(saved, isCurrent: () => version == _loadVersion);
        }
      } catch (_) {
        // Grounds remain available even if the phone cannot write its cache.
      }
    }
    final content = _parse(
      json,
      html: saved?.html ?? '',
      imagePath: saved?.imagePath ?? '',
    );
    if (version == _loadVersion) _cachedContent = content;
    return content;
  }

  GroundsContent _parse(
    Map<String, dynamic> json, {
    String html = '',
    String imagePath = '',
  }) {
    final settings = json['settings'] is Map
        ? Map<String, dynamic>.from(json['settings'] as Map)
        : <String, dynamic>{};
    return GroundsContent(
      title: '${settings['title'] ?? 'GROUNDS'}',
      subtitle: '${settings['subtitle'] ?? 'The Home Of The Highlanders'}',
      mapImage: ClubRepository.mediaUrl(settings['map_image']),
      mapHtml: ClubRepository.mediaUrl(settings['map_html']),
      mapHtmlContent: html,
      mapImagePath: imagePath,
      mapHtmlHeight: ((settings['map_html_height'] as num?)?.toDouble() ?? 260)
          .clamp(160, 600)
          .toDouble(),
      grounds: (json['grounds'] as List? ?? const [])
          .map(
            (row) =>
                GroundRecord.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .where((ground) => ground.name.isNotEmpty)
          .toList(),
    );
  }
}
