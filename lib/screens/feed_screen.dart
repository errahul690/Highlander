import '../widgets/club_page_body.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/animated_football.dart';
import '../theme.dart';
import '../widgets/feed_match_sections.dart';
import '../club_repository.dart';
import '../models.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../app_banners_repository.dart';
import '../feed_focus_repository.dart';
import '../feed_startup.dart';
import '../session.dart';
import '../otp_api.dart';
import '../realtime_client.dart';
import '../widgets/app_quick_links.dart';
import '../widgets/app_feed_banners.dart';
import '../widgets/app_feed_marquee.dart';
import '../gallery_repository.dart';
import '../widgets/app_feed_poll.dart';
import '../post_pager.dart';
import '../widgets/post_list_view.dart';

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
  bool _opening = false;
  Timer? _openTimer;
  ImageStream? _bannerStream;
  ImageStreamListener? _bannerListener;
  int _recentAfter = 2;
  int _focusAfter = 2;
  FeedFocusRepository? _focus;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
    _pager = PostPager(_fetchPage)..addListener(_pageChanged);
    _clubContent = (widget.clubRepository ?? ClubRepository.instance).load();
    _focus = FeedFocusRepository.instance;
    _recentAfter = _focus!.recentAfterPosts;
    _focusAfter = _focus!.focusAfterPosts;
    _focus!.addListener(_onFocus);
    unawaited(_focus!.load());
    WidgetsBinding.instance.addObserver(this);
    _loadPosts();
    if (widget.client == null) {
      _opening = true;
      unawaited(_warmFirstBanner());
      _openTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _opening = false);
      });
    }
    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (event['resource'] == 'posts' || event['resource'] == 'all')
        _loadPosts();
      if ([
        'all',
        'feed-focus',
        'recent-results',
      ].contains(event['resource'])) {
        unawaited(_focus?.load());
      }
      if ([
        'all',
        'feed-match',
        'knockoutMatches',
        'matches',
      ].contains(event['resource'])) {
        setState(
          () =>
              _clubContent = (widget.clubRepository ?? ClubRepository.instance)
                  .load(forceRefresh: true),
        );
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

  Future<void> _warmFirstBanner() async {
    try {
      final banners = await AppBannersRepository.instance.load();
      final banner = banners.where((item) => item.enabled).firstOrNull;
      if (banner == null || !mounted) return;
      final url = Uri.parse(
        OtpApi.apiBase,
      ).resolve(banner.imageUrl).toString();
      final stream = NetworkImage(
        url,
      ).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (image, synchronousCall) => _dropBannerStream(),
        onError: (error, stackTrace) => _dropBannerStream(),
      );
      _bannerStream = stream;
      _bannerListener = listener;
      stream.addListener(listener);
    } catch (_) {}
  }

  void _dropBannerStream() {
    final stream = _bannerStream;
    final listener = _bannerListener;
    _bannerStream = null;
    _bannerListener = null;
    if (stream != null && listener != null) stream.removeListener(listener);
  }

  Future<void> _refresh() async {
    GalleryRepository.instance.invalidateFeedVideos();
    final club = (widget.clubRepository ?? ClubRepository.instance).load(
      forceRefresh: true,
    );
    setState(() => _clubContent = club);
    await Future.wait([
      club,
      _loadPosts(),
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
    final response = await _client
        .get(
          Uri.parse('${OtpApi.apiBase}$path').replace(
            queryParameters: {
              'limit': '10',
              if (cursor != null) 'cursor': cursor,
            },
          ),
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
        data['posts'] is! List)
      throw Exception('Could not load posts.');
    return Map<String, dynamic>.from(data);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _openTimer?.cancel();
    _dropBannerStream();
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
    child: Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      body: Stack(
        children: [
          Column(
        children: [
          const _FeedHeader(),
          Expanded(
            child: ClubPageBody(
                    color: const Color(0xFFF9F7F3),
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: PostListView(
                        key: const PageStorageKey('feed-scroll'),
                        pager: _pager,
                        onChanged: _loadPosts,
                        spacing: 20,
                        emptyLoading: Semantics(
                          label: 'Loading feed',
                          child: AnimatedFootball(
                            size: 64,
                            color: clubRed,
                            enableBounce: false,
                          ),
                        ),
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
                          16,
                          18,
                          MediaQuery.paddingOf(context).bottom + 20,
                        ),
                        header: [
                          const AppQuickLinks(),
                          const SizedBox(height: 16),
                          const AppFeedBanners(),
                          const SizedBox(height: 18),
                          FeedMatchFeature(
                            content: _clubContent,
                            now: widget.now,
                          ),
                          const AppFeedMarquee(
                            key: ValueKey('feed-announcements'),
                          ),
                          const AppFeedPoll(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
          if (_opening)
            Positioned.fill(
              child: ColoredBox(
                color: Color(0xFFF9F7F3),
                child: Center(
                  child: Semantics(
                    label: 'Loading feed',
                    child: AnimatedFootball(
                      size: 64,
                      color: clubRed,
                      enableBounce: false,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();
  @override
  Widget build(BuildContext context) => const ClubHeader(
    title: 'Highlanders',
    // subtitle: 'FAN COMMUNITY',
    embedded: true,
  );
}
