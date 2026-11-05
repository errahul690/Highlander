import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_banners_repository.dart';
import 'app_marquee_repository.dart';
import 'app_poll_repository.dart';
import 'app_settings_repository.dart';
import 'gallery_repository.dart';
import 'otp_api.dart';
import 'session.dart';

/// Starts Feed requests at launch for a saved login, or alongside sign-in and sign-up.
class FeedStartup {
  static Future<Map<String, dynamic>>? _posts;
  static String? _postsForToken;
  static bool _publicStarted = false;
  static final http.Client _client = http.Client();

  static void warm(Future<void> sessionReady) {
    unawaited(sessionReady.then((_) {
      if (Session.isSignedIn) start();
    }));
  }

  /// Safe to call again. A later sign-in replaces the signed-out post request.
  static void start() {
    if (!_publicStarted) {
      _publicStarted = true;
      unawaited(AppSettingsRepository.instance.load());
      unawaited(AppBannersRepository.instance.load());
      unawaited(AppMarqueeRepository.instance.load());
      unawaited(
        GalleryRepository.instance.loadGallery(
          type: 'videos',
          useFallback: false,
        ),
      );
    }
    if (_postsForToken == Session.token && _posts != null) return;
    final previous = _posts;
    _postsForToken = Session.token;
    _posts = _fetchFirstPosts();
    unawaited(_posts!.then((_) {}, onError: (_) {}));
    if (previous != null) unawaited(previous.then((_) {}, onError: (_) {}));
    if (Session.token.isNotEmpty) unawaited(AppPollRepository.instance.load());
  }

  /// The first Feed page joins the request that already left at launch.
  static Future<Map<String, dynamic>>? claimPosts() {
    final pending = _posts;
    _posts = null;
    return pending;
  }

  static Future<Map<String, dynamic>> _fetchFirstPosts() async {
    final path = Session.token.isEmpty ? '/api/public/posts' : '/api/user/posts';
    final response = await _client
        .get(
          Uri.parse('${OtpApi.apiBase}$path').replace(
            queryParameters: const {'limit': '10'},
          ),
          headers: {
            if (Session.token.isNotEmpty) 'Authorization': 'Bearer ${Session.token}',
          },
        )
        .timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['success'] != true ||
        data['posts'] is! List) {
      throw Exception('Could not load posts.');
    }
    return Map<String, dynamic>.from(data);
  }
}
