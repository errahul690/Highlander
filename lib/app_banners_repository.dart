import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'media_cache.dart';
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
    if (data['image_url'] is! String || (data['image_url'] as String).isEmpty)
      throw const FormatException('Invalid banner');
    return AppBanner(
      imageUrl: data['image_url'] as String,
      link: data['link'] as String? ?? '',
      enabled: data['enabled'] != false,
    );
  }
}

class AppBannersRepository {
  AppBannersRepository({http.Client? client})
    : _client = client ?? http.Client();
  static AppBannersRepository instance = AppBannersRepository();
  final http.Client _client;
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
  /// A finished settings request is not enough: the feed stays covered until
  /// the banner files themselves are saved.
  Future<void> whenImagesReady() async {
    if (!_hasLoaded) await load();
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
    final request = _fetch();
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  Future<List<AppBanner>> _fetch() async {
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
        _images = _downloadImages();
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
    final request = _fetch();
    _inFlight = request;
    final banners = await request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
    final pending = _images;
    if (pending != null) await pending;
    return banners;
  }

  Future<void> _downloadImages() async {
    final banners = _current.where((banner) => banner.enabled).toList();
    if (banners.isEmpty) {
      imagesReady = true;
      return;
    }
    try {
      await Future.wait(banners.map(_downloadOne));
    } catch (_) {}
    imagesReady = banners.any((banner) => _bytes.containsKey(imageUrl(banner)));
    if (!imagesReady) _images = null;
  }

  Future<void> _downloadOne(AppBanner banner) async {
    final url = imageUrl(banner);
    if (_bytes.containsKey(url)) return;
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _bytes[url] = response.bodyBytes;
        await warmImage(response.bodyBytes);
      }
    } catch (_) {}
  }
}
