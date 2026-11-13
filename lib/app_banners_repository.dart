import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'media_cache.dart';
import 'gallery_cache.dart';
import 'otp_api.dart';

class AppBanner {
  const AppBanner({
    required this.imageUrl,
    this.link = '',
    this.enabled = true,
  });
  final String imageUrl, link;
  final bool enabled;
  factory AppBanner.fromJson(Map<String, dynamic> data) {
    if (data['image_url'] is! String || (data['image_url'] as String).isEmpty) {
      throw const FormatException('Invalid banner');
    }
    return AppBanner(
      imageUrl: data['image_url'] as String,
      link: data['link'] as String? ?? '',
      enabled: data['enabled'] != false,
    );
  }
}

class AppBannersRepository extends ChangeNotifier {
  AppBannersRepository({http.Client? client, GalleryCache? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? GalleryCache();
  static AppBannersRepository instance = AppBannersRepository();
  final http.Client _client;
  final GalleryCache _storage;
  Future<void>? _restored;
  final Map<String, Future<void>> _downloads = {};
  String get _settingsKey =>
      '${OtpApi.apiBase}/api/public/app-settings#banners';
  List<AppBanner> _current = const [];
  List<AppBanner> get current => _current;
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;
  bool imagesReady = false;
  int _loadVersion = 0;
  Future<List<AppBanner>>? _inFlight;
  Future<void>? _images;
  final Map<String, Uint8List> _bytes = {};

  String imageUrl(AppBanner banner) =>
      Uri.parse(OtpApi.apiBase).resolve(banner.imageUrl).toString();

  Uint8List? bytesFor(AppBanner banner) => _bytes[imageUrl(banner)];

  /// Banner files start downloading with the list, before the feed exists.
  Future<void> prepareImages(BuildContext context) => whenImagesReady();

  /// Joins the download that starts with the banner list.
  /// The same download is shared by startup and the visible feed.
  Future<void> whenImagesReady() async {
    if (!_hasLoaded) await load();
    await _restored;
    final pending = _images;
    if (pending != null) await pending;
    if (!imagesReady && _current.any((banner) => banner.enabled)) {
      _images = _downloadImages();
      await _images;
    }
  }

  /// Banners already fetched this session, or the request that is still in flight.
  Future<List<AppBanner>> ensureLoaded() {
    if (_hasLoaded) return Future.value(_current);
    return load();
  }

  Future<List<AppBanner>> load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    _restored ??= _restore();
    final request = _fetch();
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  Future<void> _restore() async {
    final saved = await _storage.read(_settingsKey);
    if (saved == null || _hasLoaded) return;
    try {
      final rows = jsonDecode(utf8.decode(saved.bytes)) as List;
      final banners = rows
          .map(
            (row) => AppBanner.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      if (_hasLoaded) return;
      _current = banners;
      _hasLoaded = true;
      notifyListeners();
      _images = _downloadImages();
      await _images;
    } catch (_) {}
  }

  void _saveConfiguration() {
    final rows = [
      for (final banner in _current)
        {
          'image_url': banner.imageUrl,
          'link': banner.link,
          'enabled': banner.enabled,
        },
    ];
    unawaited(
      _storage.write(
        _settingsKey,
        SavedGalleryResource(
          Uint8List.fromList(utf8.encode(jsonEncode(rows))),
          const {},
        ),
      ),
    );
  }

  Future<List<AppBanner>> _fetch({bool refreshImages = false}) async {
    final version = ++_loadVersion;
    try {
      final response = await _client
          .get(Uri.parse('${OtpApi.apiBase}/api/public/app-settings'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return _current;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          data['banners'] is! List) {
        return _current;
      }
      final banners = <AppBanner>[];
      for (final row in data['banners'] as List) {
        if (row is! Map) continue;
        try {
          banners.add(AppBanner.fromJson(Map<String, dynamic>.from(row)));
        } catch (_) {}
      }
      if (version == _loadVersion) {
        _current = banners;
        _hasLoaded = true;
        _images = _downloadImages(force: refreshImages);
        _saveConfiguration();
        notifyListeners();
      }
    } catch (_) {
      /* Keep the last working configuration while offline. */
    }
    return _current;
  }

  /// Drop saved pictures and download the latest list and files.
  Future<List<AppBanner>> refresh() async {
    _bytes.clear();
    imagesReady = false;
    _images = null;
    final request = _fetch(refreshImages: true);
    _inFlight = request;
    final banners = await request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
    final pending = _images;
    if (pending != null) await pending;
    return banners;
  }

  Future<void> _downloadImages({bool force = false}) async {
    final version = _loadVersion;
    final banners = _current.where((banner) => banner.enabled).toList();
    if (banners.isEmpty) {
      imagesReady = true;
      return;
    }
    try {
      await Future.wait(
        banners.map((banner) => _downloadOne(banner, force: force)),
      );
    } catch (_) {}
    if (version != _loadVersion) return;
    imagesReady = banners.every(
      (banner) => _bytes.containsKey(imageUrl(banner)),
    );
    notifyListeners();
    if (!imagesReady) _images = null;
  }

  Future<void> _downloadOne(AppBanner banner, {bool force = false}) {
    final url = imageUrl(banner);
    if (!force && _bytes.containsKey(url)) return Future.value();
    return _downloads[url] ??= _loadImage(url, force: force).whenComplete(() {
      _downloads.remove(url);
    });
  }

  Future<void> _loadImage(String url, {bool force = false}) async {
    try {
      final saved = force ? null : await _storage.read(url);
      if (saved != null && saved.bytes.isNotEmpty) {
        await warmImage(saved.bytes);
        _bytes[url] = saved.bytes;
        notifyListeners();
        return;
      }
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await warmImage(response.bodyBytes);
        _bytes[url] = response.bodyBytes;
        notifyListeners();
        unawaited(
          _storage.write(
            url,
            SavedGalleryResource(response.bodyBytes, const {}),
          ),
        );
      }
    } catch (_) {}
  }
}
