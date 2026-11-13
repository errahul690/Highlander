import '../widgets/club_page_body.dart';
import '../widgets/feed_background.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/startup_loader.dart';
import '../widgets/feed_match_sections.dart';
import '../club_repository.dart';
import '../models.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../gallery_repository.dart';
import '../feed_focus_repository.dart';
import '../feed_startup.dart';
import '../session.dart';
import '../otp_api.dart';
import '../realtime_client.dart';
import '../widgets/app_quick_links.dart';
import '../widgets/app_feed_banners.dart';
import '../widgets/app_feed_marquee.dart';
import '../widgets/app_feed_poll.dart';
import '../post_pager.dart';
import '../network_read.dart';
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
    unawaited(_loadPosts());
    FeedStartup.prefetchOtherScreens();
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
  );
}

class _FeedHeader extends StatelessWidget implements PreferredSizeWidget {
  const _FeedHeader();
  @override
  Size get preferredSize => const ClubHeader(title: '').preferredSize;
  @override
  Widget build(BuildContext context) => const ClubHeader(
    title: 'Highlanders',
    showBack: false,
    showLogo: true,
    uppercaseTitle: true,
    // subtitle: 'FAN COMMUNITY',
    embedded: true,
  );
}
