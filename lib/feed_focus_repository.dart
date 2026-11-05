import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'otp_api.dart';

class FeedFocusRepository extends ChangeNotifier {
  FeedFocusRepository({http.Client? client})
    : _client = client ?? http.Client();
  static FeedFocusRepository instance = FeedFocusRepository();
  final http.Client _client;
  String title = 'Highlanders in Focus';
  String subtitle = 'From our latest videos';
  int recentAfterPosts = 2;
  int focusAfterPosts = 2;
  int _version = 0;

  int _count(dynamic value, dynamic fallback) {
    if (value is int && value >= 0 && value <= 30) return value;
    if (fallback is int && fallback >= 0 && fallback <= 30) return fallback;
    return 2;
  }

  Future<void> load() async {
    final version = ++_version;
    try {
      final response = await _client
          .get(Uri.parse('${OtpApi.apiBase}/api/public/app-settings'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data is! Map || data['success'] != true || version != _version) {
        return;
      }
      final nextTitle = data['feed_focus_title'];
      final nextSubtitle = data['feed_focus_subtitle'];
      if (nextTitle is String && nextTitle.trim().isNotEmpty) title = nextTitle;
      if (nextSubtitle is String) subtitle = nextSubtitle;
      recentAfterPosts = _count(
        data['recent_results_after_posts'],
        data['feed_sections_after_posts'],
      );
      focusAfterPosts = _count(
        data['feed_focus_after_posts'],
        data['feed_sections_after_posts'],
      );
      notifyListeners();
    } catch (_) {
      // Keep the last working text while offline.
    }
  }
}
