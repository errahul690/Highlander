import 'dart:convert';

import 'package:http/http.dart' as http;

import 'otp_api.dart';

// Keep announcement data separate from match fixtures and banner images.
class AppMarquee {
  const AppMarquee({
    required this.text,
    this.id = '',
    this.link = '',
    this.enabled = true,
    this.icon = 'notifications',
    this.iconUrl = '',
  });
  final String text, id, link, icon, iconUrl;
  final bool enabled;
}

class AppMarqueeRepository {
  AppMarqueeRepository({http.Client? client})
    : _client = client ?? http.Client();
  static AppMarqueeRepository instance = AppMarqueeRepository();
  final http.Client _client;
  AppMarquee _current = const AppMarquee(
    text: 'View matchday updates and results',
    link: '/matches',
  );
  AppMarquee get current => _current;
  int _loadVersion = 0;
  Future<AppMarquee> load() async {
    final version = ++_loadVersion;
    try {
      final response = await _client
          .get(Uri.parse('${OtpApi.apiBase}/api/public/app-settings'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return _current;
      final data = jsonDecode(response.body);
      if (data is! Map ||
          data['success'] != true ||
          !data.containsKey('marquee'))
        return _current;
      if (version != _loadVersion) return _current;
      final value = data['marquee'];
      if (value == null) {
        _current = const AppMarquee(text: '', enabled: false);
      } else {
        if (value is! Map ||
            value['text'] is! String ||
            (value['enabled'] != false &&
                (value['text'] as String).trim().isEmpty))
          return _current;
        _current = AppMarquee(
          text: value['text'] as String,
          id: value['_id'] as String? ?? '',
          link: value['link'] as String? ?? '',
          enabled: value['enabled'] != false,
          icon: value['icon'] as String? ?? 'notifications',
          iconUrl: value['icon_url'] as String? ?? '',
        );
      }
    } catch (_) {
      /* Keep the last working announcement while offline. */
    }
    return _current;
  }
}
