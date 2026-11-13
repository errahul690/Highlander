import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import '../widgets/match_page_cards.dart';

import '../app_navigation.dart';
import '../models.dart';
import '../feed_match_schedule.dart';
import '../club_repository.dart';
import '../theme.dart';
import '../widgets/club_bar.dart';
import '../widgets/match_insights.dart';
import '../widgets/story_html.dart';
import 'match_report_screen.dart';
import 'live_match_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({
    super.key,
    required this.fixture,
    this.playHighlights = false,
  });

  final Fixture fixture;
  final bool playHighlights;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  String _lineupTeam = 'HOME'; // 'HOME' or 'AWAY'
  final _overviewKey = GlobalKey();

  Fixture get fixture => widget.fixture;
  bool get _isLive =>
      fixture.section.trim().toLowerCase() != 'completed' &&
      fixture.journeyStage.trim().toLowerCase() != 'report' &&
      (fixture.matchStatus.trim().toLowerCase() == 'live' ||
          fixture.section.trim().toLowerCase() == 'live' ||
          fixturePhase(fixture, DateTime.now()) == FeedMatchPhase.live);

  // Parse fixture date to friendly format e.g. "SAT, 20 SEP"
  String _getFormattedDate() {
    final raw = fixture.date.trim();
    if (raw.isEmpty) return 'TBD';

    DateTime? parsed;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) {
      try {
        parsed = DateTime.parse(raw.substring(0, 10));
      } catch (_) {}
    } else {
      const monthMap = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final match = RegExp(r'(\d{1,2})\s+([a-zA-Z]{3})(?:\s+(\d{4}))?')
          .firstMatch(raw);
      if (match != null) {
        final day = int.tryParse(match.group(1)!) ?? 1;
        final mon = monthMap[match.group(2)!.toLowerCase()] ?? 1;
        final yr = match.group(3) != null
            ? int.tryParse(match.group(3)!) ?? DateTime.now().year
            : DateTime.now().year;
        parsed = DateTime(yr, mon, day);
      }
    }

    if (parsed != null) {
      const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      const months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ];
      final dayName = days[parsed.weekday - 1];
      final monthName = months[parsed.month - 1];
      return '$dayName, ${parsed.day} $monthName';
    }

    return raw.toUpperCase();
  }

  String _getDateAndTimeDisplay() {
    final date = _getFormattedDate();
    final time = fixture.time.trim();
    if (time.isNotEmpty) {
      return '$date · $time';
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    if (fixture.played && !_isLive) {
      return MatchReportScreen(
        fixture: fixture,
        lineups: _buildLineUpsTab(),
        playHighlights: widget.playHighlights,
      );
    }
    return ClubScaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const ClubBar(title: 'MATCH CENTRE'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Hero Match Card (Stadium Atmosphere)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: _buildHeroMatchCard(),
            ),

            if (fixture.highlightsUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: MatchHighlightsBanner(url: fixture.highlightsUrl),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: KeyedSubtree(
                key: _overviewKey,
                child: _buildOverviewTab(),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Hero Next Match / Match Banner Card
  // ---------------------------------------------------------
  Widget _buildHeroMatchCard() => MatchPageHero(
    fixture: fixture,
    live: _isLive,
    onWatchLive: _isLive && fixture.liveUrl.trim().isNotEmpty
        ? () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LiveMatchScreen(fixture: fixture),
            ),
          )
        : null,
    onOpen: () {
      final overview = _overviewKey.currentContext;
      if (overview == null) return;
      Scrollable.ensureVisible(
        overview,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    },
  );

  // ---------------------------------------------------------
  // Upcoming match details
  // ---------------------------------------------------------
  Widget _buildOverviewTab() {
    final competitionName = fixture.heading.isNotEmpty
        ? fixture.heading
        : (fixture.round.isNotEmpty ? fixture.round : 'Not available');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fixture.details.stats.isNotEmpty)
          _detailCard([
            const Text(
              'MATCH SNAPSHOT',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8),
            ),
            const SizedBox(height: 5),
            Text(
              '${fixture.home} / ${fixture.away}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            for (final stat in fixture.details.stats.take(3))
              MatchStatComparison(stat: stat),
          ]),
        // Section Title: MATCH INFO
        const Text(
          'MATCH INFO',
          style: TextStyle(
            color: Color(0xFF101014),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: clubRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(height: 16),

        // White Card with Kick-Off, Venue, Competition
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildInfoRow(label: 'KICK-OFF', value: _getDateAndTimeDisplay()),
              const Divider(color: Color(0xFFF1F2F5), height: 26, thickness: 1),
              _buildInfoRow(label: 'VENUE', value: fixture.venue.toUpperCase()),
              const Divider(color: Color(0xFFF1F2F5), height: 26, thickness: 1),
              _buildInfoRow(
                label: 'COMPETITION',
                value: competitionName.toUpperCase(),
              ),
              if (fixture.winner.isNotEmpty) ...[
                const Divider(
                  color: Color(0xFFF1F2F5),
                  height: 26,
                  thickness: 1,
                ),
                _buildInfoRow(label: 'WINNER', value: fixture.winner),
              ],
            ],
          ),
        ),

        if (fixture.summary.isNotEmpty || fixture.report.isNotEmpty) ...[
          const SizedBox(height: 16),
          _detailCard([
            Text(
              fixture.played ? 'MATCH REPORT' : 'MATCH PREVIEW',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (fixture.summary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                fixture.summary,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
            if (storyHasText(fixture.report) &&
                fixture.report.trim() != fixture.summary.trim()) ...[
              const SizedBox(height: 10),
              StoryHtml(
                html: fixture.report,
                style: const TextStyle(height: 1.5),
              ),
            ],
          ]),
        ],
        if (fixture.images.isNotEmpty)
          _detailCard([
            const Text(
              'MATCH IMAGES',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            for (final url in fixture.images)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Image.network(
                  url,
                  errorBuilder: (_, _, _) => const Text('Image unavailable'),
                ),
              ),
          ]),
        if (fixture.videos.isNotEmpty)
          _detailCard([
            Text(
              fixture.highlightsUrl.isEmpty
                  ? 'MATCH VIDEOS'
                  : 'MATCH HIGHLIGHTS & VIDEOS',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            for (final video in fixture.videos)
              TextButton.icon(
                onPressed: () => openAppDestination(context, video.url),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(video.title.isEmpty ? 'Watch video' : video.title),
              ),
          ]),
        if (fixture.links.isNotEmpty)
          _detailCard([
            const Text(
              'MATCH LINKS',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            for (final link in fixture.links)
              TextButton(
                onPressed: () => openAppDestination(context, link.url),
                child: Text(link.title.isEmpty ? link.url : link.title),
              ),
          ]),
        // Broadcast & Fan Notice Card
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tv, color: Color(0xFF4B5563), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE BROADCAST',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      fixture.details.broadcast.isEmpty
                          ? 'Broadcast information not available'
                          : fixture.details.broadcast,
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coachTile(String team, String coach, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(Icons.sports, color: color, size: 18),
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
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  coach.isEmpty ? 'Coach not published' : coach,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Coach',
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _substitutionTile(
    MatchSubstitution sub,
    List<MatchLineupPlayer> squad,
    Color color,
  ) {
    MatchLineupPlayer? named(String name) {
      final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final player in squad) {
        if (player.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ==
            key) {
          return player;
        }
      }
      return null;
    }

    final incoming = named(sub.playerIn);
    final outgoing = named(sub.playerOut);
    Widget portrait(MatchLineupPlayer? player) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CircleAvatar(
        radius: 17,
        backgroundColor: color.withValues(alpha: .1),
        foregroundImage: player != null && player.imageUrl.isNotEmpty
            ? NetworkImage(ClubRepository.mediaUrl(player.imageUrl))
            : null,
        onForegroundImageError: player != null && player.imageUrl.isNotEmpty
            ? (_, _) {}
            : null,
        child: Text(
          player?.number ?? '',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    Widget rating(MatchLineupPlayer? player) {
      if (player?.rating == null) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ratingTint(player!.rating!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          player.rating!.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${sub.minute}'",
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              portrait(incoming),
              Icon(
                Icons.arrow_upward,
                size: 16,
                color: const Color(0xFF047857),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '↑ ${sub.playerIn}',
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              rating(incoming),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              portrait(outgoing),
              Icon(Icons.arrow_downward, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '↓ ${sub.playerOut}',
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
              rating(outgoing),
            ],
          ),
          if (sub.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                sub.reason,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: clubFontFamily,
            color: Color(0xFF111827),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: clubFontFamily,
              color: Color(0xFF111827),
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // Tab 2: LINE-UPS
  // ---------------------------------------------------------
  Widget _detailCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildLineUpsTab() {
    final home = _lineupTeam == 'HOME';
    final details = fixture.details;
    final players = home ? details.homeLineup : details.awayLineup;
    final bench = home ? details.homeBench : details.awayBench;
    final formation = home ? details.homeFormation : details.awayFormation;
    final team = home ? fixture.home : fixture.away;
    final captain = (home ? details.homeCaptain : details.awayCaptain).trim();
    final matchCaptain = captain.isNotEmpty
        ? captain
        : players.where((player) => player.captain).firstOrNull?.name ?? '';
    final changes = details.substitutions
        .where((sub) => sub.team == (home ? 'home' : 'away'))
        .toList();
    String normalize(String name) =>
        name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final usedNames = changes.map((sub) => normalize(sub.playerIn)).toSet();
    final usedBench = bench
        .where((player) => usedNames.contains(normalize(player.name)))
        .toList();
    final otherBench = bench
        .where((player) => !usedNames.contains(normalize(player.name)))
        .toList();
    final color = home ? clubRed : const Color(0xFF2463EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'HOME',
              label: Text(
                fixture.home,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ButtonSegment(
              value: 'AWAY',
              label: Text(
                fixture.away,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          selected: {_lineupTeam},
          onSelectionChanged: (value) =>
              setState(() => _lineupTeam = value.first),
        ),
        const SizedBox(height: 16),
        _detailCard([
          _buildInfoRow(
            label: 'FORMATION',
            value: formation.isEmpty ? 'Not available' : formation,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            label: 'STARTING XI',
            value: details.lineupStatus.isEmpty
                ? 'Not available'
                : details.lineupStatus.toUpperCase(),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            label: 'MATCH CAPTAIN',
            value: matchCaptain.isEmpty ? 'Not available' : matchCaptain,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            label: home ? 'OPPOSITE XI' : 'HOME XI',
            value: (home ? details.awayLineup : details.homeLineup).isEmpty
                ? 'Not published yet'
                : '${(home ? details.awayLineup : details.homeLineup).length} starters available',
          ),
        ]),
        if (MatchPitch.canDisplay(
              details.homeLineup,
              formation: details.homeFormation,
            ) ||
            MatchPitch.canDisplay(
              details.awayLineup,
              formation: details.awayFormation,
            )) ...[
          MatchPitch(
            players: details.homeLineup,
            team: fixture.home,
            matchDate: fixture.date,
            color: clubRed,
            awayPlayers: details.awayLineup,
            awayTeam: fixture.away,
            homeFormation: details.homeFormation,
            awayFormation: details.awayFormation,
            homeCaptain: details.homeCaptain,
            awayCaptain: details.awayCaptain,
          ),
        ],
        _detailCard([
          const Text(
            'MANAGERS',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .6),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _coachTile(fixture.home, details.homeCoach, clubRed),
              ),
              Container(width: 1, height: 46, color: const Color(0xFFE5E7EB)),
              Expanded(
                child: _coachTile(
                  fixture.away,
                  details.awayCoach,
                  const Color(0xFF2463EB),
                ),
              ),
            ],
          ),
        ]),
        _detailCard([
          Row(
            children: [
              Container(width: 4, height: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  team.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${players.length} players',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap a player to explore their profile',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (players.isEmpty)
            const Text('Lineup not available for this match.'),
          for (final player in players)
            MatchPlayerTile(
              player: player,
              team: team,
              matchDate: fixture.date,
              color: color,
              captainName: matchCaptain,
            ),
        ]),
        if (changes.isNotEmpty)
          _detailCard([
            const Text(
              'SUBSTITUTIONS · WHO CAME ON',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            for (final sub in changes)
              _substitutionTile(sub, [...players, ...bench], color),
          ]),
        if (usedBench.isNotEmpty)
          _detailCard([
            const Text(
              'SUBSTITUTES WHO PLAYED',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            for (final player in usedBench)
              MatchPlayerTile(
                player: player,
                team: team,
                matchDate: fixture.date,
                color: color,
              ),
          ]),
        if (otherBench.isNotEmpty)
          _detailCard([
            const Text(
              'MATCHDAY BENCH',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .6),
            ),
            const SizedBox(height: 10),
            const Text(
              'No verified entry recorded for these players. This does not confirm they were unused.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            for (final player in otherBench)
              MatchPlayerTile(
                player: player,
                team: team,
                matchDate: fixture.date,
                color: color,
              ),
          ]),
      ],
    );
  }
}
