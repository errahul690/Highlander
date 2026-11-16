import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/features/gallery/data/gallery_cache.dart';
import 'package:Highlanders/core/network/network_read.dart';

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

class AppSettingsRepository extends ChangeNotifier {
  AppSettingsRepository({http.Client? client, GalleryCache? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? GalleryCache();
  static AppSettingsRepository instance = AppSettingsRepository();
  final http.Client _client;
  final GalleryCache _storage;
  Future<void>? _restored;
  Future<List<AppQuickButton>>? _inFlight;
  bool _hasLoaded = false;
  String get _settingsKey =>
      '${OtpApi.apiBase}/api/public/app-settings#quick-links';
  List<AppQuickButton> _current = defaultAppButtons;
  List<AppQuickButton> get current => _current;
  int _loadVersion = 0;

  Future<void> restore() => _restored ??= _restore();

  Future<void> _restore() async {
    final settingsKey = _settingsKey;
    try {
      final saved = await _storage
          .read(settingsKey)
          .timeout(const Duration(milliseconds: 250), onTimeout: () => null);
      if (saved == null || _hasLoaded || settingsKey != _settingsKey) return;
      final rows = jsonDecode(utf8.decode(saved.bytes)) as List;
      if (rows.isEmpty) return;
      final buttons = rows
          .map(
            (row) =>
                AppQuickButton.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      if (_hasLoaded) return;
      _current = buttons;
      _hasLoaded = true;
      notifyListeners();
    } catch (_) {
      // A missing or invalid saved configuration must not delay online loading.
    }
  }

  Future<List<AppQuickButton>> ensureLoaded() =>
      _hasLoaded ? Future.value(_current) : load();

  Future<List<AppQuickButton>> load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    unawaited(restore());
    final request = _fetch();
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  Future<List<AppQuickButton>> _fetch() async {
    final version = ++_loadVersion;
    final settingsKey = _settingsKey;
    try {
      final response = await getWithRetry(
        _client,
        Uri.parse('${OtpApi.apiBase}/api/public/app-settings'),
        timeout: const Duration(seconds: 5),
        canRetry: () => settingsKey == _settingsKey,
      );
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
      if (version == _loadVersion && settingsKey == _settingsKey) {
        _current = buttons;
        _hasLoaded = true;
        notifyListeners();
        unawaited(
          _storage.write(
            settingsKey,
            SavedGalleryResource(
              Uint8List.fromList(utf8.encode(jsonEncode(json['buttons']))),
              const {},
            ),
          ),
        );
      }
    } catch (_) {
      /* Retain the last working buttons while offline. */
    }
    return _current;
  }
}
