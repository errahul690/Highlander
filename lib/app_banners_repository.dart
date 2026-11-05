import 'dart:convert';

import 'package:http/http.dart' as http;

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

const defaultAppBanners = [
  AppBanner(
    imageUrl: 'https://media.base44.com/images/public/6a7206ad13fad16ac9170985/e530d33f2_generated_b2f0c018.png',
    link: '/matches',
  ),
];

class AppBannersRepository {
  AppBannersRepository({http.Client? client})
    : _client = client ?? http.Client();
  static AppBannersRepository instance = AppBannersRepository();
  final http.Client _client;
  List<AppBanner> _current = defaultAppBanners;
  List<AppBanner> get current => _current;
  int _loadVersion = 0;
  Future<List<AppBanner>>? _inFlight;

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
          data['banners'] is! List)
        return _current;
      final banners = (data['banners'] as List)
          .map(
            (row) => AppBanner.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      if (version == _loadVersion) _current = banners;
    } catch (_) {
      /* Keep the last working configuration while offline. */
    }
    return _current;
  }
}
