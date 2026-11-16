import 'package:Highlanders/core/network/session_http_client.dart';
import 'package:Highlanders/shared/widgets/club_page_body.dart';
import 'package:Highlanders/features/feed/widgets/feed_background.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:Highlanders/shared/widgets/club_header.dart';
import 'package:Highlanders/shared/widgets/startup_loader.dart';
import 'package:Highlanders/features/feed/widgets/feed_match_sections.dart';
import 'package:Highlanders/shared/data/club_repository.dart';
import 'package:Highlanders/shared/models/club_content.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:Highlanders/features/gallery/data/gallery_repository.dart';
import 'package:Highlanders/features/feed/data/feed_focus_repository.dart';
import 'package:Highlanders/features/feed/services/feed_startup.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/core/network/realtime_client.dart';
import 'package:Highlanders/features/feed/widgets/app_quick_links.dart';
import 'package:Highlanders/features/feed/widgets/app_feed_banners.dart';
import 'package:Highlanders/features/feed/widgets/app_feed_marquee.dart';
import 'package:Highlanders/features/polls/widgets/app_feed_poll.dart';
import 'package:Highlanders/features/posts/data/post_pager.dart';
import 'package:Highlanders/core/network/network_read.dart';
import 'package:Highlanders/features/posts/widgets/post_list_view.dart';
import 'package:Highlanders/features/feed/widgets/feed_loading_gate.dart';
import 'package:Highlanders/features/settings/data/app_settings_repository.dart';
import 'package:Highlanders/features/feed/data/app_banners_repository.dart';
import 'package:Highlanders/features/feed/data/app_marquee_repository.dart';
import 'package:Highlanders/features/polls/data/app_poll_repository.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, this.client, this.clubRepository, this.now});
  final http.Client? client;
  final ClubRepository? clubRepository;
  final DateTime? now;
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  late final http.Client _client;
  late final PostPager _pager;
  late Future<ClubContent> _clubContent;
  int _recentAfter = 2;
  int _focusAfter = 2;
  FeedFocusRepository? _focus;
  late Future<void> _initialPosts;
  late Future<void> _initialFocus;
  Future<void>? _preparing;
  bool _preparedOnce = false;

  @override
  void initState() {
    super.initState();
    _client = SessionHttpClient(widget.client ?? http.Client());
    _pager = PostPager(_fetchPage)..addListener(_pageChanged);
    _clubContent = (widget.clubRepository ?? ClubRepository.instance).load();
    _focus = FeedFocusRepository.instance;
    _recentAfter = _focus!.recentAfterPosts;
    _focusAfter = _focus!.focusAfterPosts;
    _focus!.addListener(_onFocus);
    _initialFocus = _focus!.load();
    unawaited(_initialFocus);
    WidgetsBinding.instance.addObserver(this);
    _initialPosts = _loadPosts();
    unawaited(_initialPosts);
    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      // A like already updates the card. Reloading the list only shows the
      // footer spinner.
      if ((event['resource'] == 'posts' || event['resource'] == 'all') &&
          event['action'] != 'liked') {
        _loadPosts();
      }
      if (['all', 'feed-focus', 'recent-results'].contains(event['resource'])) {
        unawaited(_focus?.load());
      }
      if ([
        'all',
        'feed-match',
        'knockoutMatches',
        'matches',
      ].contains(event['resource'])) {
        final club = (widget.clubRepository ?? ClubRepository.instance).load(
          forceRefresh: true,
        );
        setState(() {
          _clubContent = club;
        });
      }
    });
  }

  void _pageChanged() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    final recent = _focus?.recentAfterPosts ?? 2;
    final focus = _focus?.focusAfterPosts ?? 2;
    if (mounted && (recent != _recentAfter || focus != _focusAfter)) {
      setState(() {
        _recentAfter = recent;
        _focusAfter = focus;
      });
    }
  }

  Future<void> _loadPosts() => _pager.refresh();

  Future<void> _prepareInitialFeed() {
    final pending = _preparing;
    if (pending != null) return pending;
    final retry = _preparedOnce;
    _preparedOnce = true;
    final request = _prepareFeed(retry: retry);
    _preparing = request;
    return request.whenComplete(() {
      if (identical(_preparing, request)) _preparing = null;
    });
  }

  Future<void> _prepareFeed({required bool retry}) async {
    final posts = retry ? _loadPosts() : _initialPosts;
    if (retry) {
      setState(() {
        _clubContent = (widget.clubRepository ?? ClubRepository.instance).load(
          forceRefresh: true,
        );
      });
    }
    await Future.wait([
      posts,
      _clubContent,
      AppSettingsRepository.instance.ensureLoaded(),
      AppBannersRepository.instance.ensureLoaded(),
      AppMarqueeRepository.instance.load(),
      if (Session.token.isNotEmpty) AppPollRepository.instance.load(),
      if (retry) ?_focus?.load() else _initialFocus,
    ]);
    if (!mounted) return;
    if (_pager.posts.isEmpty && _pager.error != null) {
      throw StateError('The initial feed is unavailable');
    }
    await FeedStartup.prepareVisibleImages(
      await _clubContent,
      _pager.posts,
      now: widget.now,
    );
    if (mounted) FeedStartup.prefetchOtherScreens();
  }

  Future<void> _refresh() async {
    final club = (widget.clubRepository ?? ClubRepository.instance).load(
      forceRefresh: true,
    );
    setState(() {
      _clubContent = club;
    });
    await Future.wait([
      club,
      _loadPosts(),
      ?_focus?.load(),
      GalleryRepository.instance.revalidate('videos'),
      RealtimeClient.instance.refreshFeed(),
    ]);
  }

  Future<Map<String, dynamic>> _fetchPage(String? cursor) async {
    if (cursor == null && widget.client == null) {
      final warmed = FeedStartup.claimPosts();
      if (warmed != null) return warmed;
    }
    final path = Session.token.isEmpty
        ? '/api/public/posts'
        : '/api/user/posts';
    final sessionToken = Session.token;
    final response = await getWithRetry(
      _client,
      Uri.parse('${OtpApi.apiBase}$path').replace(
        queryParameters: {'limit': '10', if (cursor != null) 'cursor': cursor},
      ),
      headers: sessionToken.isEmpty
          ? const {}
          : {'Authorization': 'Bearer $sessionToken'},
      canRetry: () => mounted && Session.token == sessionToken,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map ||
        data['success'] != true ||
        data['posts'] is! List) {
      throw Exception('Could not load posts.');
    }
    return Map<String, dynamic>.from(data);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _focus?.removeListener(_onFocus);
    _pager.dispose();
    _subscription?.cancel();
    if (widget.client == null) _client.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    child: FeedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ClubHeaderLayout(
          header: const _FeedHeader(),
          body: ClubPageBody(
            color: Colors.transparent,
            child: FeedLoadingGate(
              prepare: _prepareInitialFeed,
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: PostListView(
                  key: const PageStorageKey('feed-scroll'),
                  pager: _pager,
                  onChanged: _loadPosts,
                  spacing: 6,
                  emptyLoading: const StartupLoader(),
                  inserts: [
                    PostListInsert(
                      afterPosts: _recentAfter,
                      child: RecentResultsSection(content: _clubContent),
                    ),
                    PostListInsert(
                      afterPosts: _focusAfter,
                      child: const FeedGalleryFocus(),
                    ),
                  ],
                  padding: EdgeInsets.fromLTRB(
                    18,
                    6,
                    18,
                    MediaQuery.paddingOf(context).bottom + 20,
                  ),
                  header: [
                    const AppQuickLinks(),
                    const AppFeedBanners(padding: EdgeInsets.only(top: 6)),
                    const SizedBox(height: 6),
                    FeedMatchFeature(content: _clubContent, now: widget.now),
                    const AppFeedMarquee(key: ValueKey('feed-announcements')),
                    const AppFeedPoll(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FeedHeader extends StatelessWidget implements PreferredSizeWidget {
  const _FeedHeader();
  @override
  Size get preferredSize => const ClubHeader(title: '').preferredSize;
  @override
  Widget build(BuildContext context) => const ClubHeader(
    title: 'NORTHEAST UNITED',
    showBack: false,
    showLogo: true,
    uppercaseTitle: true,
    // subtitle: 'FAN COMMUNITY',
    embedded: true,
  );
}
