import 'dart:async';

import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../club_repository.dart';
import '../media_cache.dart';
import '../feed_match_schedule.dart';
import '../models.dart';
import '../screens/match_detail_screen.dart';
import '../screens/matches_screen.dart';
import '../screens/match_preview_screen.dart';
import '../theme.dart';
import 'club_crest.dart';
import 'feed_match_matchup.dart';
import 'hero_latest_result_card.dart';
import 'hero_next_match_card.dart';
import 'match_card_veil.dart';
import 'watch_live_sheet.dart';

class FeedMatchFeature extends StatefulWidget {
  const FeedMatchFeature({super.key, required this.content, this.now});
  final Future<ClubContent> content;
  final DateTime? now;
  @override
  State<FeedMatchFeature> createState() => _FeedMatchFeatureState();
}

class _FeedMatchFeatureState extends State<FeedMatchFeature> {
  Timer? _dayCheck;
  @override
  void initState() {
    super.initState();
    _dayCheck = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _dayCheck?.cancel();
    super.dispose();
  }

  void _open(Fixture f, String url) {
    if (f.section != 'completed' && f.previewContent.isNotEmpty) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => MatchPreviewScreen(fixture: f)));
      return;
    }
    if (url.isNotEmpty) {
      openAppDestination(context, url);
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: f)));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ClubContent>(
    future: widget.content,
    builder: (context, snapshot) {
      final content = snapshot.data;
      if (content == null) return const SizedBox.shrink();
      final selection = selectFeedMatch(
        content.fixtures,
        widget.now ?? DateTime.now(),
      );
      if (selection == null) return const SizedBox.shrink();
      final f = selection.fixture;
      final phase = selection.phase;
      if (phase == FeedMatchPhase.report) return const SizedBox.shrink();
      final thumbnail = feedMatchThumbnail(
        f,
        phase,
        content.defaultMatchThumbnail,
      );
      final image = _AdminMatchThumbnail(
        url: thumbnail,
        fallback: phase == FeedMatchPhase.live
            ? 'assets/images/matchday_live_default.png'
            : content.defaultMatchThumbnail,
      );
      if (phase == FeedMatchPhase.upcoming ||
          (phase == FeedMatchPhase.preview &&
              f.previewContent.trim().isEmpty)) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: HeroNextMatchCard(
            fixture: f,
            badgeText: phase == FeedMatchPhase.preview
                ? 'BEFORE KICK-OFF'
                : 'NEXT MATCH',
            onViewMatch: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: f)),
            ),
          ),
        );
      }
      if (phase == FeedMatchPhase.preview) {
        return _BeforeKickoffCard(
          fixture: f,
          image: _AdminMatchThumbnail(
            url: f.previewThumbnail.isNotEmpty
                ? f.previewThumbnail
                : 'assets/images/before_kickoff_default.png',
            fallback: 'assets/images/before_kickoff_default.png',
          ),
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MatchPreviewScreen(fixture: f)),
          ),
        );
      }
      if (phase == FeedMatchPhase.report &&
          f.reportUrl.isEmpty &&
          f.reportTitle.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: HeroLatestResultCard(
            fixture: f,
            onViewMatch: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: f)),
            ),
            onHighlights: () {
              final video = f.highlightsUrl.isNotEmpty
                  ? f.highlightsUrl
                  : f.videoUrl;
              if (video.isNotEmpty) {
                openAppDestination(context, video);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        MatchDetailScreen(fixture: f, playHighlights: true),
                  ),
                );
              }
            },
          ),
        );
      }
      if (phase != FeedMatchPhase.live) {
        final upcoming = phase == FeedMatchPhase.upcoming;
        final preview = false;
        final url = preview ? f.previewUrl : f.reportUrl;
        final title = preview ? f.previewTitle : f.reportTitle;
        final summary = preview ? f.previewDescription : f.summary;
        return Container(
          key: ValueKey(preview ? 'feed-match-preview' : 'feed-match-report'),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: preview ? const Color(0xFFE5F4FD) : const Color(0xFFF0F5EE),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    preview ? Icons.menu_book_outlined : Icons.article_outlined,
                    size: 18,
                    color: const Color(0xFF15263C),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    upcoming
                        ? 'Upcoming matches'
                        : preview
                        ? 'Before Kick-Off'
                        : 'Match Report',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15263C),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 2, bottom: 12),
                child: Text(
                  upcoming
                      ? '${f.date} · ${f.time.isEmpty ? 'Time to be confirmed' : '${f.time} IST'}'
                      : preview
                      ? 'The build-up to matchday'
                      : 'From our last match',
                  style: const TextStyle(
                    color: Color(0xFF748397),
                    fontSize: 12,
                  ),
                ),
              ),
              FeedMatchMatchup(
                fixture: f,
                onTap: () => upcoming
                    ? Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MatchDetailScreen(fixture: f),
                        ),
                      )
                    : _open(f, url),
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => upcoming
                      ? Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MatchDetailScreen(fixture: f),
                          ),
                        )
                      : _open(f, url),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 96,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: image,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    upcoming
                                        ? 'UPCOMING'
                                        : preview
                                        ? 'MATCH PREVIEW'
                                        : 'MATCH REPORT',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF1463FF),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    upcoming || title.isEmpty
                                        ? '${f.home} vs ${f.away}'
                                        : title,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF14253D),
                                    ),
                                  ),
                                  if (!upcoming && summary.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        height: 1.4,
                                        color: Color(0xFF748397),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    upcoming
                                        ? 'View match →'
                                        : preview
                                        ? 'Read Preview →'
                                        : 'Read Report →',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1463FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Padding(
        key: const ValueKey('feed-match-live'),
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Matchday LIVE',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF191B24),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MatchesScreen()),
                  ),
                  child: const Text(
                    'View all →',
                    style: TextStyle(color: Color(0xFFE11924)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Material(
                color: const Color(0xFF25392F),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MatchDetailScreen(fixture: f),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.61,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image,
                        MatchCardVeil(
                          opacityOverride: f.liveOverlay == null
                              ? null
                              : f.liveOverlay! / 100,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF232B),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: Colors.white,
                                          size: 7,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Live',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // const SizedBox(width: 8),
                                  // Expanded(
                                  //   child: Text(
                                  //     [
                                  //       f.heading,
                                  //       f.venue,
                                  //     ].where((s) => s.isNotEmpty).join(' · '),
                                  //     maxLines: 1,
                                  //     overflow: TextOverflow.ellipsis,
                                  //     textAlign: TextAlign.right,
                                  //     style: const TextStyle(
                                  //       color: Colors.white,
                                  //       fontSize: 11,
                                  //     ),
                                  //   ),
                                  // ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: _LiveTeam(
                                      name: f.home,
                                      logo: f.homeLogo,
                                      background: logoDisc(
                                        f.homeLogoBackground,
                                        home: true,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      'VS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 23,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _LiveTeam(
                                      name: f.away,
                                      logo: f.awayLogo,
                                      background: logoDisc(
                                        f.awayLogoBackground,
                                        home: false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              _LiveAction(
                                watch: f.liveUrl.isNotEmpty,
                                onTap: () => f.liveUrl.isEmpty
                                    ? Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MatchDetailScreen(fixture: f),
                                        ),
                                      )
                                    : showWatchLiveSheet(context, f),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _BeforeKickoffCard extends StatelessWidget {
  const _BeforeKickoffCard({
    required this.fixture,
    required this.image,
    required this.onOpen,
  });
  final Fixture fixture;
  final Widget image;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = fixture.previewTitle.trim().isEmpty
        ? '${fixture.home} vs ${fixture.away}'
        : fixture.previewTitle.trim();
    final when = [
      fixture.date,
      if (fixture.time.trim().isNotEmpty) '${fixture.time} IST',
    ].where((item) => item.trim().isNotEmpty).join(' · ');
    final venue = fixture.venue.trim();
    return Container(
      key: const ValueKey('feed-match-preview'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4FD),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Before Kick-Off',
            style: TextStyle(
              fontFamily: clubFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF15263C),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 12),
            child: Text(
              'The build-up to matchday',
              style: TextStyle(
                fontFamily: clubFontFamily,
                color: Color(0xFF748397),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 124, child: image),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MATCH PREVIEW',
                                style: TextStyle(
                                  fontFamily: clubFontFamily,
                                  fontSize: 10,
                                  letterSpacing: 0.3,
                                  color: Color(0xFF1463FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: clubFontFamily,
                                  fontSize: 14,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF14253D),
                                ),
                              ),
                              if (fixture.previewDescription
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  fixture.previewDescription.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: clubFontFamily,
                                    fontSize: 12,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF748397),
                                  ),
                                ),
                              ],
                              if (when.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _PreviewMeta(
                                  icon: Icons.schedule_outlined,
                                  text: when,
                                ),
                              ],
                              if (venue.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                _PreviewMeta(
                                  icon: Icons.location_on_outlined,
                                  text: venue,
                                ),
                              ],
                              const SizedBox(height: 8),
                              const Text(
                                'Read Preview →',
                                style: TextStyle(
                                  fontFamily: clubFontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1463FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMeta extends StatelessWidget {
  const _PreviewMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: const Color(0xFF8B93A2)),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: clubFontFamily,
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5C6B7E),
          ),
        ),
      ),
    ],
  );
}

class _LiveAction extends StatelessWidget {
  const _LiveAction({required this.watch, required this.onTap});
  final bool watch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 36,
          padding: const EdgeInsets.fromLTRB(5, 0, 14, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFE11924),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  watch ? Icons.play_arrow_rounded : Icons.sensors,
                  color: Colors.white,
                  size: watch ? 18 : 15,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                watch ? 'Watch Live' : 'Follow match',
                style: const TextStyle(
                  color: Color(0xFF191B24),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveTeam extends StatelessWidget {
  const _LiveTeam({
    required this.name,
    required this.logo,
    this.background = ClubCrest.homeBackground,
  });
  final String name, logo;
  final Color background;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 44,
        child:
            name
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]'), '')
                .contains('keralablasters')
            ? Container(
                width: 34,
                color: const Color(0xFF103573),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFFFE21D),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/images/kerala-blasters-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              )
            : ClubCrest(
                team: name,
                logo: logo,
                size: 42,
                background: background,
              ),
      ),
      const SizedBox(height: 4),
      Text(
        RegExp(
              r'north\s*east|neufc|highlander',
              caseSensitive: false,
            ).hasMatch(name)
            ? 'NorthEast\nUnited FC'
            : name.toLowerCase().contains('kerala')
            ? 'Kerala\nBlasters'
            : name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _AdminMatchThumbnail extends StatelessWidget {
  const _AdminMatchThumbnail({required this.url, required this.fallback});
  final String url, fallback;
  Widget _empty() => const ColoredBox(color: Color(0xFF33483F));
  Widget _image(String source, Widget Function() failed) =>
      source.startsWith('assets/')
      ? Image.asset(
          source,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => failed(),
        )
      : Image.network(
          ClubRepository.mediaUrl(source),
          key: ValueKey(
            'match-thumb-$source-${MediaCache.instance.generation.value}',
          ),
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => failed(),
        );
  Widget _fallback() => fallback.isNotEmpty && fallback != url
      ? _image(fallback, _empty)
      : _empty();
  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback();
    return _image(url, _fallback);
  }
}
