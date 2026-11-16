import 'package:Highlanders/core/network/session_http_client.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:Highlanders/features/feed/data/app_banners_repository.dart';
import 'package:Highlanders/features/feed/data/app_marquee_repository.dart';
import 'package:Highlanders/features/polls/data/app_poll_repository.dart';
import 'package:Highlanders/features/settings/data/app_settings_repository.dart';
import 'package:Highlanders/shared/data/club_repository.dart';
import 'package:Highlanders/features/feed/data/feed_focus_repository.dart';
import 'package:Highlanders/features/grounds/data/grounds_repository.dart';
import 'package:Highlanders/features/support/data/support_hub_repository.dart';
import 'package:Highlanders/features/gallery/data/gallery_repository.dart';
import 'package:Highlanders/features/swoofi/screens/swoofi_screen.dart';
import 'package:Highlanders/core/media/media_cache.dart';
import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/core/network/network_read.dart';
import 'package:Highlanders/features/feed/widgets/quick_card_image.dart';
import 'package:Highlanders/shared/models/club_content.dart';
import 'package:Highlanders/features/matches/utils/feed_match_schedule.dart';

/// Starts Feed requests at launch for a saved login, or alongside sign-in and sign-up.
class FeedStartup {
  /// Only images needed for the initial feed, rather than the entire gallery.
  static Future<void> prepareVisibleImages(
    ClubContent content,
    List<Map<String, dynamic>> posts, {
    DateTime? now,
  }) async {
    final selected = selectFeedMatch(
      content.fixtures,
      now ?? DateTime.now(),
    )?.fixture;
    final urls = <String>{
      if (selected != null) ...[
        selected.homeLogo,
        selected.awayLogo,
        selected.feedThumbnail,
      ],
      content.defaultMatchThumbnail,
      for (final poll in AppPollRepository.instance.polls)
        AppPollRepository.instance.backgroundFor(poll),
      AppMarqueeRepository.instance.current.iconUrl,
    };
    void collect(Map post) {
      for (final field in ['image', 'authorImage']) {
        if (post[field] is String) urls.add(post[field] as String);
      }
      for (final image
          in (post['images'] is List ? post['images'] as List : const [])) {
        if (image is String) urls.add(image);
      }
      if (post['repost'] is Map) collect(post['repost'] as Map);
    }

    for (final post in posts.take(3)) {
      collect(post);
    }
    await Future.wait([
      _prepareQuickLinks(),
      AppBannersRepository.instance.whenImagesReady(),
      MediaCache.instance.prefetch(
        urls.where((url) => url.isNotEmpty && !url.startsWith('assets/')),
      ),
    ]);
  }

  static Future<Map<String, dynamic>>? _posts;
  static String? _postsForToken;
  static bool _publicStarted = false;
  static Future<void>? _ready;
  static Future<void>? _publicReady;
  static final http.Client _client = SessionHttpClient(http.Client());

  /// Only the resources needed to open the feed are awaited at launch.
  static Future<void> ready() {
    _startPublic();
    return _ready ??= _waitForFeed();
  }

  static Future<void> warmBundledImages(BuildContext context) async {
    final bundle = DefaultAssetBundle.of(context);
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    if (!context.mounted) return;
    final assets = manifest
        .listAssets()
        .where(
          (asset) =>
              (asset.startsWith('assets/icons/') ||
                  asset.startsWith('assets/images/')) &&
              RegExp(
                r'\.(png|webp|jpg|jpeg)$',
                caseSensitive: false,
              ).hasMatch(asset),
        )
        .toList();
    // Avoid decoding every bundled image in the same animation frame.
    for (var i = 0; i < assets.length; i += 3) {
      if (!context.mounted) return;
      await Future.wait([
        for (final asset in assets.skip(i).take(3))
          precacheImage(AssetImage(asset), context, onError: (_, _) {}),
      ]);
      await WidgetsBinding.instance.endOfFrame;
    }
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
    await Future.wait([
      for (final button in AppSettingsRepository.instance.current) ...[
        for (final url in [button.imageUrl, button.iconUrl])
          if (url.isNotEmpty) QuickCardImageCache.instance.load(url),
        if (button.backgroundImageUrl.isNotEmpty)
          QuickCardImageCache.instance.loadBackground(
            button.backgroundImageUrl,
          ),
      ],
    ]);
  }

  static Future<void> _prepareMatchLogos() async {
    try {
      final content = await ClubRepository.instance.load();
      final selected = selectFeedMatch(
        content.fixtures,
        DateTime.now(),
      )?.fixture;
      final urls = <String>{
        if (selected != null) ...[
          selected.homeLogo,
          selected.awayLogo,
          selected.feedThumbnail,
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
    unawaited(
      AppSettingsRepository.instance.restore().then(
        (_) => _prepareQuickLinks(),
      ),
    );
    _publicReady = Future.wait([
      AppBannersRepository.instance.load(),
      AppSettingsRepository.instance.load().then((_) => _prepareQuickLinks()),
      AppMarqueeRepository.instance.load(),
      FeedFocusRepository.instance.load(),
    ]).then<void>((_) {}).catchError((Object _) {});
    unawaited(_publicReady!);
  }

  static bool _othersStarted = false;

  /// Feed is on screen. Warm the screens opened from it without blocking the feed.
  static void prefetchOtherScreens() {
    if (_othersStarted) return;
    _othersStarted = true;
    unawaited(
      SupportHubRepository.instance.load().then((_) {}, onError: (_) {}),
    );
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
    final sessionToken = Session.token;
    final response = await getWithRetry(
      _client,
      Uri.parse('${OtpApi.apiBase}$path')
          .replace(queryParameters: const {'limit': '10'}),
      headers: {
        if (sessionToken.isNotEmpty) 'Authorization': 'Bearer $sessionToken',
      },
      canRetry: () => Session.token == sessionToken,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['success'] != true ||
        data['posts'] is! List) {
      throw Exception('Could not load posts.');
    }
    final posts = data['posts'] as List;
    final images = <String>{};
    void collect(Map post) {
      for (final field in ['image', 'authorImage']) {
        final url = post[field];
        if (url is String && url.isNotEmpty) images.add(url);
      }
      for (final url in (post['images'] as List? ?? const [])) {
        if (url is String && url.isNotEmpty) images.add(url);
      }
      if (post['repost'] is Map) collect(post['repost'] as Map);
    }

    for (final post in posts.whereType<Map>()) {
      collect(post);
    }
    unawaited(MediaCache.instance.prefetch(images));
    return Map<String, dynamic>.from(data);
  }
}
