import '../widgets/club_page_body.dart';
import '../widgets/club_header.dart';

import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../club_repository.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/club_crest.dart';
import '../widgets/match_card_veil.dart';
import '../widgets/story_html.dart';
import '../widgets/match_highlights_player.dart';
import '../widgets/match_highlights_source.dart';
import '../widgets/post_video.dart';

class MatchPreviewScreen extends StatefulWidget {
  const MatchPreviewScreen({super.key, required this.fixture});
  final Fixture fixture;
  @override
  State<MatchPreviewScreen> createState() => _MatchPreviewScreenState();
}

class _Shot {
  const _Shot(this.source, [this.caption = '']);
  final String source, caption;
}

class _MatchPreviewScreenState extends State<MatchPreviewScreen> {
  bool _home = true;

  bool get _usingSample =>
      widget.fixture.previewContent.trim().isEmpty ||
      (widget.fixture.details.homeLineup.isEmpty &&
          widget.fixture.details.awayLineup.isEmpty);

  Fixture get fixture {
    final source = widget.fixture;
    if (!_usingSample) return source;
    final sheet =
        source.details.homeLineup.isEmpty && source.details.awayLineup.isEmpty;
    final league = _leagueOf(source);
    return Fixture(
      home: source.home,
      away: source.away,
      date: source.date,
      time: source.time,
      venue: source.venue.trim().isEmpty
          ? 'Indira Gandhi Athletic Stadium, Guwahati'
          : source.venue,
      round: source.round,
      section: source.section,
      heading: league.isEmpty || league == 'Matchday'
          ? 'Indian Super League'
          : source.heading,
      homeLogo: source.homeLogo,
      awayLogo: source.awayLogo,
      homeLogoBackground: source.homeLogoBackground,
      awayLogoBackground: source.awayLogoBackground,
      homeScore: source.homeScore,
      awayScore: source.awayScore,
      details: sheet
          ? _sampleDetails(source.details.broadcast)
          : source.details,
      images: source.images,
      previewPhotos: source.previewPhotos,
      previewVideos: source.previewVideos,
      previewThumbnail: source.previewThumbnail,
      previewTitle: source.previewTitle.trim().isEmpty
          ? 'Highlanders ready for a night under the lights'
          : source.previewTitle,
      previewDescription: source.previewDescription.trim().isEmpty
          ? 'A full house at the Fortress, a settled back line, and one last session before kick-off.'
          : source.previewDescription,
      previewContent: source.previewContent.trim().isEmpty
          ? _sampleArticle
          : source.previewContent,
      previewUrl: source.previewUrl,
      liveUrl: source.liveUrl,
      matchStatus: source.matchStatus,
      journeyStage: source.journeyStage,
    );
  }

  static const _sampleArticle =
      'The Highlanders trained under a low sun at the Fortress, the last full session before kick-off. Juan Pedro Benali kept the work short: the press from the front, the switch out to Parthib Gogoi, and the set pieces that have decided tight nights here.\n\n'
      'Richard Osei wears the armband. Wilmar Jordan starts through the middle, with Gogoi wide on the left. Mohammed Ali is the only late check in midfield after a knock in the week, and Benali said that call will be made after the morning scan.\n\n'
      'The visitors come in a settled 4-3-3 and have not lost on the road this month. The plan is to win the first ball, then use the flanks before they can sit into the game. A full house is expected, and the club has asked fans in the east stand to be in their seats before the teams walk out.\n\n'
      'Benali, speaking after the session, called it a night for the people who fill this ground. The interview from that conversation sits below.';

  @override
  Widget build(BuildContext context) {
    final title = fixture.previewTitle.trim().isEmpty
        ? '${fixture.home} vs ${fixture.away}'
        : fixture.previewTitle.trim();
    final shots = _gallery;
    final clips = fixture.previewVideos
        .where((clip) => clip.url.trim().isNotEmpty)
        .toList();
    return ClubScaffold(
      appBar: const ClubHeader(
        title: 'Match preview',
        showBack: true,
        showSearch: false,
        showSupport: false,
        uppercaseTitle: false,
      ),
      backgroundColor: clubCloud,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: 252, child: _heroImage(_hero)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: clubFontFamily,
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF14161C),
                    ),
                  ),
                  if (fixture.previewDescription.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      fixture.previewDescription.trim(),
                      style: const TextStyle(
                        fontFamily: clubFontFamily,
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3A3F4B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _facts(),
                  if (shots.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const _SectionLabel('From the session'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 128,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: shots.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) =>
                            _galleryCard(shots[index]),
                      ),
                    ),
                  ],
                  if (storyHasText(fixture.previewContent)) ...[
                    const SizedBox(height: 22),
                    const _SectionLabel('The story'),
                    const SizedBox(height: 10),
                    StoryHtml(
                      html: fixture.previewContent,
                      style: const TextStyle(
                        fontFamily: clubFontFamily,
                        fontSize: 15,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C313C),
                      ),
                    ),
                  ],
                  if (clips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const _SectionLabel('Watch'),
                    const SizedBox(height: 10),
                    for (final clip in clips) _PreviewClip(clip),
                  ],
                  const SizedBox(height: 22),
                  _lineups(),
                  if (fixture.previewUrl.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            openAppDestination(context, fixture.previewUrl),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF14161C),
                          side: const BorderSide(color: Color(0xFFD5D1C9)),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Read the full source',
                          style: TextStyle(
                            fontFamily: clubFontFamily,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroImage(String source) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _cover(source),
        const MatchCardVeil(),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pill('BEFORE KICK-OFF', filled: true),
                  if (_usingSample) ...[
                    const SizedBox(width: 8),
                    _pill('SAMPLE', filled: false),
                  ],
                ],
              ),
              if (_league.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _league,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: clubFontFamily,
                    color: Color(0xFFE7E4DE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _side(
                      fixture.home,
                      fixture.homeLogo,
                      background: logoDisc(
                        fixture.homeLogoBackground,
                        home: true,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontFamily: clubFontFamily,
                        color: clubRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _side(
                      fixture.away,
                      fixture.awayLogo,
                      background: logoDisc(
                        fixture.awayLogoBackground,
                        home: false,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, {required bool filled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? clubRed : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: Colors.white70),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: clubFontFamily,
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _facts() {
    final broadcast = fixture.details.broadcast.trim().isEmpty && _usingSample
        ? 'Sports18 · JioCinema'
        : fixture.details.broadcast.trim();
    final tiles = <(String, String)>[
      if (_when.isNotEmpty) ('Kick-off', _when),
      if (fixture.venue.trim().isNotEmpty) ('Venue', fixture.venue.trim()),
      if (broadcast.isNotEmpty) ('Watch', broadcast),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _factTile(tiles[i].$1, tiles[i].$2)),
        ],
      ],
    );
  }

  Widget _factTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: clubFontFamily,
              color: Color(0xFF8A8178),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: clubFontFamily,
              color: Color(0xFF14161C),
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryCard(_Shot shot) {
    return SizedBox(
      width: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 100,
              width: 168,
              child: _cover(shot.source),
            ),
          ),
          if (shot.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              shot.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: clubFontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5C6370),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cover(String source) {
    final fallback = Image.asset(
      'assets/images/before_kickoff_default.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _lineups() {
    final details = fixture.details;
    final published =
        details.homeLineup.isNotEmpty || details.awayLineup.isNotEmpty;
    if (!published) return const SizedBox.shrink();
    final home = _home;
    final players = home ? details.homeLineup : details.awayLineup;
    final bench = home ? details.homeBench : details.awayBench;
    final formation = (home ? details.homeFormation : details.awayFormation)
        .trim();
    final coach = (home ? details.homeCoach : details.awayCoach).trim();
    final captain = (home ? details.homeCaptain : details.awayCaptain).trim();
    final marked = captain.isNotEmpty
        ? captain
        : players.where((player) => player.captain).firstOrNull?.name ?? '';
    final status = details.lineupStatus.trim().toLowerCase();
    final statusLabel = status == 'confirmed'
        ? 'Confirmed XI'
        : status == 'probable'
        ? 'Probable XI'
        : 'Team sheet';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionLabel('Team news'),
            const Spacer(),
            Text(
              statusLabel,
              style: const TextStyle(
                fontFamily: clubFontFamily,
                color: clubRed,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE7E4DE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(child: _tab(fixture.home, true)),
              Expanded(child: _tab(fixture.away, false)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (formation.isNotEmpty || coach.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    [
                      if (formation.isNotEmpty) formation,
                      if (coach.isNotEmpty) coach,
                    ].join('  ·  '),
                    style: const TextStyle(
                      fontFamily: clubFontFamily,
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              for (final player in players)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          player.number.isEmpty ? '–' : player.number,
                          style: const TextStyle(
                            fontFamily: clubFontFamily,
                            color: clubRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          player.name == marked && marked.isNotEmpty
                              ? '${player.name} (C)'
                              : player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: clubFontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (player.position.isNotEmpty)
                        Text(
                          player.position,
                          style: const TextStyle(
                            fontFamily: clubFontFamily,
                            color: Color(0xFF8A8178),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              if (bench.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'BENCH',
                  style: TextStyle(
                    fontFamily: clubFontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF8A8178),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final player in bench)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: clubCloud,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          player.number.isEmpty
                              ? player.name
                              : '${player.number}  ${player.name}',
                          style: const TextStyle(
                            fontFamily: clubFontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tab(String name, bool home) {
    final selected = _home == home;
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() => _home = home),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: clubFontFamily,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? const Color(0xFF14161C)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _side(
    String name,
    String logo, {
    Color background = ClubCrest.homeBackground,
  }) => Column(
    children: [
      ClubCrest(team: name, logo: logo, size: 46, background: background),
      const SizedBox(height: 6),
      Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: clubFontFamily,
          color: Colors.white,
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  String get _league => _leagueOf(fixture);

  String _leagueOf(Fixture source) {
    final heading = source.heading.trim();
    if (heading.isEmpty) return '';
    final lower = heading.toLowerCase();
    final home = source.home.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final away = source.away.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final isFixtureTitle =
        RegExp(r'\bvs\.?\b', caseSensitive: false).hasMatch(heading) &&
        home.isNotEmpty &&
        away.isNotEmpty &&
        lower.contains(home) &&
        lower.contains(away);
    return isFixtureTitle ? '' : heading;
  }

  String get _when {
    final parsed = DateTime.tryParse(fixture.date.trim());
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
    final date = parsed == null
        ? fixture.date.trim()
        : '${parsed.day} ${months[parsed.month - 1]}';
    final time = fixture.time.trim();
    if (date.isEmpty) return time.isEmpty ? '' : '$time IST';
    return time.isEmpty ? date : '$date · $time';
  }

  String get _hero => fixture.previewThumbnail.trim().isNotEmpty
      ? fixture.previewThumbnail
      : 'assets/images/stadium_bg.jpg';

  List<_Shot> get _gallery {
    final seen = <String>{};
    final shots = <_Shot>[];
    void add(String value, [String caption = '']) {
      final raw = value.trim();
      if (raw.isEmpty) return;
      final url = raw.startsWith('assets/') || raw.startsWith('http')
          ? raw
          : ClubRepository.mediaUrl(raw);
      if (url.isEmpty || !seen.add(url)) return;
      shots.add(_Shot(url, caption));
    }

    for (final photo in fixture.previewPhotos) {
      add(photo.url, photo.caption);
    }
    if (fixture.previewPhotos.isEmpty) {
      for (final image in fixture.images) {
        add(image);
      }
    }
    const extras = [
      _Shot('assets/images/before_kickoff_default.png', 'Morning session'),
      _Shot('assets/images/stadium_bg.jpg', 'The Fortress'),
      _Shot('assets/images/match_hero_stadium.png', 'Match night'),
    ];
    if (!_usingSample) return shots.isEmpty ? extras.take(1).toList() : shots;
    for (final shot in extras) {
      if (shots.length >= 3) break;
      add(shot.source, shot.caption);
    }
    return shots;
  }

  MatchDetails _sampleDetails(String broadcast) {
    MatchLineupPlayer player(
      String name,
      String number,
      String position, {
      bool captain = false,
    }) => MatchLineupPlayer(
      name: name,
      number: number,
      position: position,
      captain: captain,
    );
    return MatchDetails(
      lineupStatus: 'probable',
      broadcast: broadcast.trim().isEmpty ? 'Sports18 · JioCinema' : broadcast,
      homeFormation: '4-2-3-1',
      awayFormation: '4-3-3',
      homeCoach: 'Juan Pedro Benali',
      awayCoach: 'Khalid Jamil',
      homeCaptain: 'Richard Osei',
      awayCaptain: 'David Lalhlansanga',
      homeLineup: [
        player('Subhasish Roy', '1', 'GK'),
        player('Richard Osei', '4', 'DF', captain: true),
        player('Aminou Bouba', '5', 'DF'),
        player('Lalchungnunga', '6', 'DF'),
        player('Gursimrat Gill', '3', 'DF'),
        player('Mohammed Ali', '8', 'MF'),
        player('Muthu Irulandi', '14', 'MF'),
        player('Jithin MS', '10', 'MF'),
        player('Alberto Noguera', '21', 'MF'),
        player('Wilmar Jordan', '9', 'FW'),
        player('Parthib Gogoi', '11', 'FW'),
      ],
      homeBench: [
        player('Dipesh Chauhan', '13', 'GK'),
        player('Phalguni Singh', '2', 'DF'),
        player('Bekey Oram', '17', 'MF'),
        player('Thomás Mosquera', '19', 'FW'),
      ],
      awayLineup: [
        player('Nora Fernandes', '1', 'GK'),
        player('Nongdamba Naorem', '2', 'DF'),
        player('Meldon Dsouza', '4', 'DF'),
        player('Sebastian Thangmuansang', '5', 'DF'),
        player('Joe Zoherliana', '3', 'DF'),
        player('Lalrinzuala', '8', 'MF'),
        player('Lalthankhuma', '6', 'MF'),
        player('David Lalhlansanga', '10', 'MF', captain: true),
        player('Ramhlunchhunga', '7', 'FW'),
        player('Lalrinzuala Lalbiaknia', '11', 'FW'),
        player('Gibson Jewson', '9', 'FW'),
      ],
      awayBench: [
        player('Lalthuammawia', '21', 'GK'),
        player('Lalchhuanmawia', '15', 'DF'),
        player('Jeremy Laldinpuia', '18', 'MF'),
        player('Lalremsanga', '20', 'FW'),
      ],
    );
  }
}

class _PreviewClip extends StatefulWidget {
  const _PreviewClip(this.clip);
  final MatchLink clip;
  @override
  State<_PreviewClip> createState() => _PreviewClipState();
}

class _PreviewClipState extends State<_PreviewClip> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final youtube = youtubeVideoId(clip.url) != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _open
                ? (youtube
                      ? MatchHighlightsPlayer(source: clip.url)
                      : PostVideo(
                          source: clip.url,
                          autoPlay: true,
                          aspectRatio: 16 / 9,
                        ))
                : AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Material(
                      color: const Color(0xFF14161C),
                      child: InkWell(
                        onTap: () => setState(() => _open = true),
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (clip.title.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              clip.title.trim(),
              style: const TextStyle(
                fontFamily: clubFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF14161C),
              ),
            ),
          ],
          if (clip.description.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              clip.description.trim(),
              style: const TextStyle(
                fontFamily: clubFontFamily,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5C6370),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontFamily: clubFontFamily,
        color: clubRed,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}
