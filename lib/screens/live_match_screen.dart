import '../widgets/club_page_body.dart';
import '../widgets/club_header.dart';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/club_crest.dart';
import '../widgets/match_highlights_player.dart';
import '../widgets/match_highlights_source.dart';
import '../widgets/web_video_fullscreen.dart';
import 'match_detail_screen.dart';

class LiveMatchScreen extends StatefulWidget {
  const LiveMatchScreen({super.key, required this.fixture});
  final Fixture fixture;
  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _failed = false;
  bool _loading = true;
  bool _homeLineup = true;
  bool get _usingSample =>
      widget.fixture.details.homeLineup.isEmpty &&
      widget.fixture.details.awayLineup.isEmpty;

  Fixture get fixture {
    final source = widget.fixture;
    if (!_usingSample) return source;
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
      heading: league == 'Matchday' ? 'Indian Super League' : league,
      homeLogo: source.homeLogo,
      awayLogo: source.awayLogo,
      homeLogoBackground: source.homeLogoBackground,
      awayLogoBackground: source.awayLogoBackground,
      details: _sampleDetails(source.details.broadcast),
      liveUrl: source.liveUrl,
      matchStatus: source.matchStatus,
      journeyStage: source.journeyStage,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!isPlayableHighlight(fixture.liveUrl)) _load();
  }

  Future<void> _load() async {
    try {
      final uri = Uri.tryParse(fixture.liveUrl);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty)
        throw const FormatException();
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!mounted) return;
      await configureWebVideoFullscreen(context, controller);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              ['http', 'https'].contains(Uri.tryParse(request.url)?.scheme)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted)
              setState(() => _failed = true);
          },
        ),
      );
      await controller.loadRequest(uri);
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _pause() {
    _controller
        ?.runJavaScript(
          'document.querySelectorAll("video,audio").forEach(function(v){v.pause();});',
        )
        .catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    _pause();
    _controller
        ?.loadRequest(Uri.parse('about:blank'))
        .catchError((Object _) {});
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playable = isPlayableHighlight(fixture.liveUrl);
    return ClubScaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      appBar: const ClubHeader(
        title: 'Watch live',
        showBack: true,
        showSearch: false,
        showSupport: false,
        uppercaseTitle: false,
      ),
      body: ListView(
        key: const PageStorageKey('watch-live-scroll'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              key: const ValueKey('live-stream-frame'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDEDCE2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: playable
                    ? MatchHighlightsPlayer(source: fixture.liveUrl)
                    : _failed
                    ? Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MatchDetailScreen(fixture: fixture),
                                ),
                              ),
                          child: const Text(
                            'Stream unavailable. Follow match',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_controller != null)
                            WebViewWidget(controller: _controller!),
                          if (_loading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              children: [_header(), const SizedBox(height: 14), _lineups()],
            ),
          ),
        ],
      ),
    );
  }

  String get _league => _leagueOf(fixture);

  String _leagueOf(Fixture match) {
    final heading = match.heading.trim();
    if (heading.isEmpty) return 'Matchday';
    final lower = heading.toLowerCase();
    final home = match.home.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final away = match.away.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final isFixtureTitle =
        RegExp(r'\bvs\.?\b', caseSensitive: false).hasMatch(heading) &&
        home.isNotEmpty &&
        away.isNotEmpty &&
        lower.contains(home) &&
        lower.contains(away);
    return isFixtureTitle ? 'Matchday' : heading;
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
      lineupStatus: 'confirmed',
      broadcast: broadcast.trim().isEmpty ? 'Sports18 · JioCinema' : broadcast,
      homeFormation: '4-2-3-1',
      awayFormation: '4-3-3',
      homeCoach: 'Juan Pedro Benali',
      awayCoach: 'Khalid Jamil',
      homeCaptain: 'Richard Osei',
      awayCaptain: 'Parthib Gogoi',
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
        : '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
    final time = fixture.time.trim();
    if (date.isEmpty) return time.isEmpty ? '' : '$time IST';
    return time.isEmpty ? date : '$date · $time IST';
  }

  Widget _header() {
    final broadcast = fixture.details.broadcast.trim();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: clubRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    fontFamily: clubFontFamily,
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _league,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: clubFontFamily,
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${fixture.home}  –  ${fixture.away}',
            style: const TextStyle(
              fontFamily: clubFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: Color(0xFF14161C),
            ),
          ),
          if (_when.isNotEmpty) ...[
            const SizedBox(height: 10),
            _meta(Icons.calendar_today_outlined, _when),
          ],
          if (fixture.venue.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _meta(Icons.location_on_outlined, fixture.venue.trim()),
          ],
          if (broadcast.isNotEmpty) ...[
            const SizedBox(height: 6),
            _meta(Icons.live_tv_outlined, broadcast),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: const Color(0xFF9AA3B2)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontFamily: clubFontFamily,
            color: Color(0xFF1C1F26),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    ],
  );

  Widget _lineups() {
    final details = fixture.details;
    final published =
        details.homeLineup.isNotEmpty || details.awayLineup.isNotEmpty;
    final status = details.lineupStatus == 'confirmed'
        ? 'Confirmed'
        : details.lineupStatus == 'probable'
        ? 'Probable'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Line-ups',
                style: TextStyle(
                  fontFamily: clubFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF14161C),
                ),
              ),
            ),
            if (_usingSample)
              const Text(
                'Sample',
                style: TextStyle(
                  fontFamily: clubFontFamily,
                  color: Color(0xFF9AA3B2),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (status.isNotEmpty)
              Text(
                status,
                style: const TextStyle(
                  fontFamily: clubFontFamily,
                  color: clubRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!published)
          const _Panel(
            child: Text(
              'The team sheet is not published yet.',
              style: TextStyle(
                fontFamily: clubFontFamily,
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          )
        else ...[
          _teamTabs(),
          const SizedBox(height: 10),
          _homeLineup
              ? _xi(
                  team: fixture.home,
                  formation: details.homeFormation,
                  coach: details.homeCoach,
                  captain: details.homeCaptain,
                  players: details.homeLineup,
                  bench: details.homeBench,
                )
              : _xi(
                  team: fixture.away,
                  formation: details.awayFormation,
                  coach: details.awayCoach,
                  captain: details.awayCaptain,
                  players: details.awayLineup,
                  bench: details.awayBench,
                ),
        ],
      ],
    );
  }

  Widget _teamTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E4DE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _teamTab(fixture.home, fixture.homeLogo, true)),
          Expanded(child: _teamTab(fixture.away, fixture.awayLogo, false)),
        ],
      ),
    );
  }

  Widget _teamTab(String name, String logo, bool home) {
    final selected = _homeLineup == home;
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() => _homeLineup = home),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClubCrest(
                team: name,
                logo: logo,
                size: 18,
                color: clubInk,
                background: logoDisc(
                  home
                      ? fixture.homeLogoBackground
                      : fixture.awayLogoBackground,
                  home: home,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: clubFontFamily,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF14161C)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _xi({
    required String team,
    required String formation,
    required String coach,
    required String captain,
    required List<MatchLineupPlayer> players,
    required List<MatchLineupPlayer> bench,
  }) {
    final marked = captain.trim().isNotEmpty
        ? captain.trim()
        : players.where((player) => player.captain).firstOrNull?.name ?? '';
    final home = team == fixture.home;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClubCrest(
                team: team,
                logo: home ? fixture.homeLogo : fixture.awayLogo,
                size: 28,
                color: clubInk,
                background: logoDisc(
                  home
                      ? fixture.homeLogoBackground
                      : fixture.awayLogoBackground,
                  home: home,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: clubFontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.2,
                        color: Color(0xFF14161C),
                      ),
                    ),
                    if (formation.trim().isNotEmpty || coach.trim().isNotEmpty)
                      Text(
                        [
                          if (formation.trim().isNotEmpty) formation.trim(),
                          if (coach.trim().isNotEmpty) coach.trim(),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: clubFontFamily,
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (players.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Lineup not published',
                style: TextStyle(
                  fontFamily: clubFontFamily,
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            for (final player in players) _playerRow(player, marked),
          ],
          if (bench.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                'Bench',
                style: TextStyle(
                  fontFamily: clubFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            for (final player in bench) _playerRow(player, ''),
          ],
        ],
      ),
    );
  }

  Widget _playerRow(MatchLineupPlayer player, String captain) {
    final name = player.name == captain && captain.isNotEmpty
        ? '${player.name} (C)'
        : player.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              player.number,
              style: const TextStyle(
                fontFamily: clubFontFamily,
                color: Color(0xFF9AA3B2),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontFamily: clubFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: Color(0xFF14161C),
              ),
            ),
          ),
          Text(
            player.position,
            style: const TextStyle(
              fontFamily: clubFontFamily,
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}
