import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_banners_repository.dart';
import 'app_marquee_repository.dart';
import 'app_poll_repository.dart';
import 'app_settings_repository.dart';
import 'club_repository.dart';
import 'feed_focus_repository.dart';
import 'grounds_repository.dart';
import 'support_hub_repository.dart';
import 'gallery_repository.dart';
import 'screens/swoofi_screen.dart';
import 'media_cache.dart';
import 'otp_api.dart';
import 'session.dart';
import 'widgets/quick_card_image.dart';

/// Starts Feed requests at launch for a saved login, or alongside sign-in and sign-up.
class FeedStartup {
  static Future<Map<String, dynamic>>? _posts;
  static String? _postsForToken;
  static bool _publicStarted = false;
  static Future<void>? _ready;
  static Future<void>? _publicReady;
  static final http.Client _client = http.Client();

  /// Banner pictures and gallery thumbnails started at launch.
  static Future<void> ready() {
    _startPublic();
    return _ready ??= _waitForFeed();
  }

  static Future<void> _waitForFeed() async {
    try {
      await Future.wait<void>([
        _publicReady!,
        AppBannersRepository.instance.whenImagesReady(),
        _prepareMatchLogos(),
        _prepareQuickLinks(),
      ]);
    } catch (_) {}
  }

  static Future<void> prepareForDisplay(Future<void>? sessionReady) async {
    final public = ready();
    final posts = () async {
      try {
        await sessionReady;
        if (!Session.isSignedIn) return;
        start();
        await _posts;
      } catch (_) {}
    }();
    await Future.wait<void>([public, posts]);
  }

  static Future<void> _prepareQuickLinks() async {
    await _publicReady;
    await Future.wait([
      for (final button in AppSettingsRepository.instance.current)
        for (final url in [
          button.imageUrl,
          button.iconUrl,
          button.backgroundImageUrl,
        ])
          if (url.isNotEmpty) QuickCardImageCache.instance.load(url),
    ]);
  }

  static Future<void> _prepareMatchLogos() async {
    try {
      final content = await ClubRepository.instance.load();
      final urls = <String>{
        for (final fixture in content.fixtures) ...[
          fixture.homeLogo,
          fixture.awayLogo,
          fixture.feedThumbnail,
          fixture.previewThumbnail,
          fixture.liveThumbnail,
          fixture.reportThumbnail,
        ],
        content.defaultMatchThumbnail,
      };
      await MediaCache.instance.prefetch(
        urls.where((url) => !url.startsWith('assets/')),
      );
    } catch (_) {}
  }

  static void warm(Future<void> sessionReady) {
    unawaited(
      sessionReady.then((_) {
        if (Session.isSignedIn) start();
      }),
    );
  }

  /// Public feed data does not need a saved login, so this leaves before session restore.
  static void warmBanners() {
    _startPublic();
  }

  static void _startPublic() {
    if (_publicStarted) return;
    _publicStarted = true;
    _publicReady = Future.wait([
      AppBannersRepository.instance.load(),
      AppSettingsRepository.instance.load(),
      AppMarqueeRepository.instance.load(),
      FeedFocusRepository.instance.load(),
      SupportHubRepository.instance.load(),
      GalleryRepository.instance.loadGallery(
        type: 'videos',
        useFallback: false,
      ),
      GalleryRepository.instance.loadGallery(type: 'images'),
    ]).then<void>((_) {}).catchError((Object _) {});
    unawaited(_publicReady!);
  }

  static bool _othersStarted = false;

  /// Feed is on screen. Warm the screens opened from it without blocking the feed.
  static void prefetchOtherScreens() {
    if (_othersStarted) return;
    _othersStarted = true;
    unawaited(ClubRepository.instance.load().then((_) {}, onError: (_) {}));
    unawaited(
      GalleryRepository.instance
          .loadGallery(type: 'images')
          .then((_) {}, onError: (_) {}),
    );
    unawaited(
      GalleryRepository.instance
          .loadGallery(type: 'videos', useFallback: false)
          .then((_) {}, onError: (_) {}),
    );
    unawaited(GroundsRepository.instance.preload());
    unawaited(SwoofiRepository.instance.load().then((_) {}, onError: (_) {}));
  }

  /// Safe to call again. A later sign-in replaces the signed-out post request.
  static void start() {
    _startPublic();
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
    final path = Session.token.isEmpty
        ? '/api/public/posts'
        : '/api/user/posts';
    final response = await _client
        .get(
          Uri.parse('${OtpApi.apiBase}$path')
              .replace(queryParameters: const {'limit': '10'}),
          headers: {
            if (Session.token.isNotEmpty)
              'Authorization': 'Bearer ${Session.token}',
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
