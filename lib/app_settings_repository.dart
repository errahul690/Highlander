import 'dart:convert';

import 'package:http/http.dart' as http;

import 'otp_api.dart';

class AppQuickButton {
  const AppQuickButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.link,
    this.iconUrl = '',
    this.imageUrl = '',
    this.backgroundImageUrl = '',
    this.iconBackgroundColor = '',
  });
  final String label, subtitle, icon, link, iconUrl, imageUrl;
  final String backgroundImageUrl, iconBackgroundColor;
  String get topImageUrl => imageUrl;
  String get customIconUrl => iconUrl;
  factory AppQuickButton.fromJson(Map<String, dynamic> json) {
    if (json['label'] is! String ||
        json['icon'] is! String ||
        json['link'] is! String ||
        (json['label'] as String).trim().isEmpty)
      throw const FormatException('Invalid app button');
    return AppQuickButton(
      label: json['label'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      icon: json['icon'] as String,
      link: json['link'] as String,
      iconUrl: json['icon_url'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      backgroundImageUrl: json['background_image_url'] as String? ?? '',
      iconBackgroundColor: json['icon_background_color'] as String? ?? '',
    );
  }
}

const defaultAppButtons = [
  AppQuickButton(
    label: 'SQUAD',
    subtitle: 'Club roster',
    icon: 'groups',
    link: '/squad',
  ),
  AppQuickButton(
    label: 'MATCHES',
    subtitle: 'Fixtures',
    icon: 'calendar',
    link: '/matches',
  ),
  AppQuickButton(
    label: 'GALLERY',
    subtitle: 'Photo & Videos',
    icon: 'camera',
    link: '/gallery',
  ),
  AppQuickButton(
    label: 'GROUNDS',
    subtitle: 'Venues',
    icon: 'stadium',
    link: '/grounds',
  ),
];

class AppSettingsRepository {
  AppSettingsRepository({http.Client? client})
    : _client = client ?? http.Client();
  static AppSettingsRepository instance = AppSettingsRepository();
  final http.Client _client;
  List<AppQuickButton> _current = defaultAppButtons;
  List<AppQuickButton> get current => _current;
  int _loadVersion = 0;
  Future<List<AppQuickButton>> load() async {
    final version = ++_loadVersion;
    try {
      final response = await _client
          .get(Uri.parse('${OtpApi.apiBase}/api/public/app-settings'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return _current;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic> ||
          json['success'] != true ||
          json['buttons'] is! List ||
          (json['buttons'] as List).isEmpty)
        return _current;
      final buttons = (json['buttons'] as List)
          .map(
            (row) =>
                AppQuickButton.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      if (version == _loadVersion) _current = buttons;
    } catch (_) {
      /* Retain the last working buttons while offline. */
    }
    return _current;
  }
}
