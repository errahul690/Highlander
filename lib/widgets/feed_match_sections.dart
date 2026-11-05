import 'dart:async';

import 'package:flutter/material.dart';

import 'club_crest.dart';
export 'feed_match_feature.dart';

import '../app_navigation.dart';
import '../gallery_repository.dart';
import '../feed_focus_repository.dart';
import '../realtime_client.dart';
import '../screens/gallery_screen.dart';
import 'match_highlights_player.dart';
import '../club_identity.dart';
import '../club_repository.dart';
import '../models.dart';
import '../screens/match_detail_screen.dart';
import '../screens/matches_screen.dart'
    show MatchesScreen, MatchOutcome, getMatchOutcome;

const _red = Color(0xFF29388C);
const _ink = Color(0xFF191B24);

void _openMatch(BuildContext context, Fixture fixture) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: fixture)));
void _allMatches(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MatchesScreen()));

Widget _sectionTitle(
  BuildContext context,
  String title, {
  String? subtitle,
  VoidCallback? onViewAll,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -.6,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerRight,
            ),
            onPressed: onViewAll ?? () => _allMatches(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View all', style: TextStyle(color: _red)),
                Icon(Icons.chevron_right, color: _red, size: 20),
              ],
            ),
          ),
        ],
      ),
      if (subtitle != null)
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF818181), fontSize: 14),
        ),
    ],
  ),
);

class RecentResultsSection extends StatelessWidget {
  const RecentResultsSection({super.key, required this.content});
  final Future<ClubContent> content;
  @override
  Widget build(BuildContext context) => FutureBuilder<ClubContent>(
    future: content,
    builder: (context, snapshot) {
      final results =
          (snapshot.data?.fixtures ?? []).where((f) => f.played).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      if (results.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            context,
            'Recent results',
            subtitle: 'Scores, reports and highlights',
          ),
          SizedBox(
            height: 220,
            child: ListView.separated(
              // Keep horizontal results separate from the feed's saved offset.
              key: const PageStorageKey('feed-recent-results-scroll'),
              scrollDirection: Axis.horizontal,
              itemCount: results.take(6).length,
              separatorBuilder: (_, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final f = results[index];
                final badge = _resultBadge(getMatchOutcome(f));
                return Container(
                  width: 320,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: badge.$2,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge.$1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              index == 0 && isNorthEastClub(f.home)
                                  ? 'Last home match'
                                  : '${f.heading.isEmpty ? 'Match' : f.heading} · ${isNorthEastClub(f.home) ? 'Home' : 'Away'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF707070),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _resultDate(f.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _resultLogo(
                            f.home,
                            f.homeLogo,
                            logoDisc(f.homeLogoBackground, home: true),
                          ),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  f.score,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111111),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _resultLogo(
                            f.away,
                            f.awayLogo,
                            logoDisc(f.awayLogoBackground, home: false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _resultName(f.home, TextAlign.left)),
                          const SizedBox(width: 8),
                          Expanded(child: _resultName(f.away, TextAlign.right)),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: _pill(
                              'Report',
                              Icons.description_outlined,
                              const Color(0xFFE0F2EA),
                              const Color(0xFF2C6046),
                              () => _openMatch(context, f),
                            ),
                          ),
                          if (f.highlightsUrl.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _pill(
                                'Highlights',
                                Icons.play_arrow,
                                const Color(0xFFE5E9FF),
                                const Color(0xFF29388C),
                                () => openAppDestination(
                                  context,
                                  f.highlightsUrl,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    },
  );
}

class FeedMatchSections extends StatelessWidget {
  const FeedMatchSections({super.key, required this.content});
  final Future<ClubContent> content;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RecentResultsSection(content: content),
      const FeedGalleryFocus(),
    ],
  );
}

Widget _pill(
  String label,
  IconData icon,
  Color background,
  Color color,
  VoidCallback onTap,
) => Material(
  color: background,
  borderRadius: BorderRadius.circular(24),
  child: InkWell(
    borderRadius: BorderRadius.circular(24),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: label == 'Highlights'
                ? const Color(0xFF5369FF)
                : const Color(0xFF55A97C),
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  ),
);

Widget _resultLogo(String name, String logo, Color background) => CircleAvatar(
  radius: 25,
  backgroundColor: background,
  child: Padding(
    padding: const EdgeInsets.all(4),
    child: logo.isEmpty && name.toLowerCase().contains('bengaluru')
        ? const Text(
            'BFC',
            style: TextStyle(
              color: Color(0xFF303BA5),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          )
        : ClubCrest(
            team: name,
            logo: logo,
            size: 32,
            color: const Color(0xFF394A65),
            background: background,
          ),
  ),
);

Widget _resultName(String name, TextAlign align) => Text(
  isNorthEastClub(name) ? 'NEUFC' : name,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  textAlign: align,
  style: const TextStyle(fontSize: 13, color: Color(0xFF707070)),
);

(String, Color) _resultBadge(MatchOutcome outcome) => switch (outcome) {
  MatchOutcome.won => ('WON', const Color(0xFF55A97C)),
  MatchOutcome.draw => ('DRAW', const Color(0xFFF4BD38)),
  MatchOutcome.lost => ('LOST', const Color(0xFFE16060)),
  MatchOutcome.unavailable => ('FT', const Color(0xFF818181)),
};

String _resultDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

class FeedGalleryFocus extends StatefulWidget {
  const FeedGalleryFocus({super.key});
  @override
  State<FeedGalleryFocus> createState() => _FeedGalleryFocusState();
}

class _FeedGalleryFocusState extends State<FeedGalleryFocus>
    with WidgetsBindingObserver {
  late Future<List<GalleryItem>> _videos;
  late final FeedFocusRepository _focus;
  StreamSubscription<Map<String, dynamic>>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _focus = FeedFocusRepository.instance;
    _focus.addListener(_refreshHeading);
    WidgetsBinding.instance.addObserver(this);
    _settingsSubscription = RealtimeClient.instance.settingsChanges.listen((
      event,
    ) {
      if (event['resource'] == 'feed-refresh') {
        final videos = _reloadVideos();
        RealtimeClient.instance.trackFeedRefresh(
          Future.wait([videos, _focus.load()]),
        );
      } else if (event['resource'] == 'feed-focus' ||
          event['resource'] == 'all') {
        unawaited(_focus.load());
      }
    });
    unawaited(_focus.load());
    _videos = GalleryRepository.instance.loadGallery(
      type: 'videos',
      useFallback: false,
    );
  }

  Future<List<GalleryItem>> _reloadVideos() {
    GalleryRepository.instance.invalidateFeedVideos();
    final videos = GalleryRepository.instance.loadGallery(
      type: 'videos',
      useFallback: false,
    );
    setState(() => _videos = videos);
    return videos;
  }

  void _refreshHeading() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_focus.load());
      _reloadVideos();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_refreshHeading);
    WidgetsBinding.instance.removeObserver(this);
    _settingsSubscription?.cancel();
    super.dispose();
  }

  void _play(BuildContext context, GalleryItem video) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    video.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                  tooltip: 'Close video',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            MatchHighlightsPlayer(
              source: ClubRepository.mediaUrl(video.videoUrl),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<GalleryItem>>(
    future: _videos,
    builder: (context, snapshot) {
      final moments = (snapshot.data ?? const <GalleryItem>[])
          .where(
            (item) => item.type == 'videos' && item.videoUrl.trim().isNotEmpty,
          )
          .take(6)
          .toList();
      if (moments.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7FE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: _focus.subtitle.trim().isEmpty ? 8 : 3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _focus.title,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.25,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F0F0F),
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4136),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const GalleryScreen(initialTab: 'videos'),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_focus.subtitle.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _focus.subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF747474),
                  ),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final single = moments.length == 1;
                final width = single ? constraints.maxWidth : 230.0;
                const captionStyle = TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF171717),
                );
                final title = TextPainter(
                  text: TextSpan(
                    text: moments.first.title,
                    style: DefaultTextStyle.of(context).style
                        .merge(captionStyle),
                  ),
                  maxLines: 1,
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: width - 32);
                final height = single
                    ? width * 9 / 16 + 8 + title.height
                    : 176.0;
                title.dispose();
                return SizedBox(
                  height: height,
                  child: ListView.separated(
                    physics: single
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    scrollDirection: Axis.horizontal,
                    itemCount: moments.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final video = moments[index];
                      return SizedBox(
                        key: ValueKey('focus-video-${video.id}'),
                        width: width,
                        child: InkWell(
                          onTap: () => _play(context, video),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (video.thumbnail.isNotEmpty)
                                        Image.network(
                                          ClubRepository.mediaUrl(
                                            video.thumbnail,
                                          ),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, error, stack) =>
                                              const ColoredBox(
                                                color: Color(0xFF283934),
                                              ),
                                        )
                                      else
                                        const ColoredBox(
                                          color: Color(0xFF283934),
                                        ),
                                      const Center(
                                        child: CircleAvatar(
                                          backgroundColor: Colors.white,
                                          radius: 22,
                                          child: Icon(
                                            Icons.play_arrow,
                                            color: Colors.black,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  video.title,
                                  textAlign: TextAlign.left,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: captionStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
          ),
          const SizedBox(height: 24),
        ],
      );
    },
  );
}
