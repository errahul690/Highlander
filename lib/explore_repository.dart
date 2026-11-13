import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'club_repository.dart';
import 'otp_api.dart';
import 'network_read.dart';

void warmNetworkImage(String raw) {
  final testing = WidgetsBinding.instance.runtimeType
      .toString()
      .toLowerCase()
      .contains('test');
  if (testing) return;
  final url = ClubRepository.mediaUrl(raw);
  if (url.isEmpty) return;
  NetworkImage(url)
      .resolve(const ImageConfiguration())
      .addListener(ImageStreamListener((_, _) {}, onError: (_, _) {}));
}

Color exploreColor(Object? value, Color fallback) {
  final hex = RegExp(r'^#([0-9a-fA-F]{6})$')
      .firstMatch('${value ?? ''}'.trim());
  if (hex == null) return fallback;
  return Color(0xFF000000 | int.parse(hex.group(1)!, radix: 16));
}

const defaultExplore = <String, dynamic>{
  'title': 'EXPLORE',
  'headerSubtitle': '',
  'heading': 'Explore the Highlanders',
  'subtitle': 'The club, the fans, and everything in between.',
  'searchPlaceholder': 'Search Highlanders',
  'quickTitle': 'QUICK ACCESS',
  'logoutLabel': 'LOG OUT',
  'showSearch': true,
  'showNotifications': true,
  'showProfile': true,
  'showLogout': true,
  'helpTitle': 'Help & support',
  'helpText': 'For account, profile or matchday questions, contact the Highlanders team at help@neufc.com.',
  'helpUrl': '',
  'colors': {
    'page': '#F9F7F3',
    'accent': '#C92B20',
    'heading': '#171717',
    'muted': '#8A847C',
    'search': '#F1EEEA',
    'cardAccent': '#E10600',
    'linkIcon': '#FDECEC',
    'chevron': '#B7B3AE',
    'logout': '#FBECEC',
    'logoutText': '#C92B20',
  },
  'cards': [
    {
      'id': 'squad',
      'label': 'SQUAD',
      'image_url': '/uploads/explore-squad.png',
      'icon': 'squad',
      'link': '/squad',
      'enabled': true,
    },
    {
      'id': 'matches',
      'label': 'MATCHES',
      'image_url': '/uploads/explore-matches.png',
      'icon': 'matches',
      'link': '/matches',
      'enabled': true,
    },
    {
      'id': 'grounds',
      'label': 'GROUNDS',
      'image_url': '/uploads/explore-matches.png',
      'icon': 'grounds',
      'link': '/grounds',
      'enabled': true,
    },
  ],
  'quickLinks': [
    {
      'id': 'gallery',
      'label': 'Gallery',
      'subtitle': 'Matchday moments',
      'icon': 'gallery',
      'link': '/gallery',
      'enabled': true,
      'backgroundColor': '#FDECEC',
      'accentColor': '#E23B32',
    },
    {
      'id': 'circles',
      'label': 'Huddles',
      'subtitle': 'Your fan community',
      'icon': 'circles',
      'link': '/circles',
      'enabled': true,
      'backgroundColor': '#EEF2F8',
      'accentColor': '#5C6B86',
    },
    {
      'id': 'friends',
      'label': 'Friends',
      'subtitle': 'Your crew',
      'icon': 'friends',
      'link': '/friends',
      'enabled': true,
      'backgroundColor': '#F8F1E7',
      'accentColor': '#C4A06A',
    },
    {
      'id': 'swoofi',
      'label': 'Swoofi',
      'subtitle': 'Explore more',
      'icon': 'swoofi',
      'link': '/swoofi',
      'enabled': true,
      'backgroundColor': '#F3EEF8',
      'accentColor': '#7D62B0',
    },
  ],
  'links': [
    {
      'id': 'notifications',
      'label': 'Notifications',
      'icon': 'notifications',
      'link': '/alerts',
      'enabled': true,
    },
    {
      'id': 'help',
      'label': 'Help & support',
      'icon': 'help',
      'link': '/help',
      'enabled': true,
    },
  ],
};

class ExploreRepository extends ChangeNotifier {
  ExploreRepository({http.Client? client}) : _client = client ?? http.Client();
  static ExploreRepository instance = ExploreRepository();
  final http.Client _client;
  Map<String, dynamic> _current = Map.of(defaultExplore);
  Map<String, dynamic> get current => _current;
  bool hasError = false;
  bool warmed = false;
  int _request = 0;

  Future<File> _cacheFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}explore-cache.json');
  }

  Future<void> restore() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return;
      _current = {...defaultExplore, ...Map<String, dynamic>.from(data)};
      warmed = true;
      _precache(_current);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist(Map<String, dynamic> config) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(config));
    } catch (_) {}
  }

  void _precache(Map<String, dynamic> config) {
    for (final field in ['cards', 'quickLinks', 'links']) {
      final rows = config[field];
      if (rows is! List) continue;
      for (final row in rows.whereType<Map>()) {
        warmNetworkImage('${row['image_url'] ?? ''}');
        warmNetworkImage('${row['card_image_url'] ?? ''}');
        warmNetworkImage('${row['art_url'] ?? ''}');
      }
    }
  }

  Future<Map<String, dynamic>> load() async {
    final request = ++_request;
    try {
      final response = await getWithRetry(
        _client,
        Uri.parse('${OtpApi.apiBase}/api/public/explore'),
        timeout: const Duration(seconds: 8),
        canRetry: () => request == _request,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          body is! Map ||
          body['success'] != true ||
          body['explore'] is! Map) {
        throw const FormatException();
      }
      final config = Map<String, dynamic>.from(body['explore'] as Map);
      for (final field in ['cards', 'quickLinks', 'links']) {
        if (config[field] is! List ||
            (config[field] as List).any(
              (item) =>
                  item is! Map ||
                  item['label'] is! String ||
                  item['link'] is! String,
            )) {
          throw const FormatException();
        }
      }
      // A slow earlier response must not roll back a newly published revision.
      final revision = (config['revision'] as num?)?.toInt();
      final currentRevision = (_current['revision'] as num?)?.toInt();
      if (request == _request &&
          (revision == null ||
              currentRevision == null ||
              revision >= currentRevision)) {
        final colors = <String, dynamic>{
          ...Map<String, dynamic>.from(defaultExplore['colors'] as Map),
          if (config['colors'] is Map)
            ...Map<String, dynamic>.from(config['colors'] as Map),
        };
        if (colors['page'] == '#F7F4EF') {
          colors['page'] = '#F9F7F3';
        }
        _current = {...defaultExplore, ...config, 'colors': colors};
        hasError = false;
        warmed = true;
        unawaited(_persist(_current));
        _precache(_current);
        notifyListeners();
      }
    } catch (_) {
      if (request == _request) hasError = true;
    }
    return _current;
  }
}
