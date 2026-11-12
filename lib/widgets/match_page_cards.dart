import '../brand_colors.dart';
import 'package:flutter/material.dart';

import '../club_identity.dart';
import '../match_competition.dart';
import '../models.dart';
import 'match_team_crest.dart';
import 'match_versus.dart';
import 'hero_latest_result_card.dart' as result;

const matchPageRed = brandAccent;
const matchPageInk = Color(0xFF11132D);
const _muted = Color(0xFF747588);

String matchPageDate(Fixture fixture, {bool upper = false}) {
  final date = DateTime.tryParse(fixture.date);
  if (date == null) {
    return fixture.date.isEmpty ? 'Date to be confirmed' : fixture.date;
  }
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
  final label = '${date.day} ${months[date.month - 1]}';
  return upper ? label.toUpperCase() : label;
}

String matchPageTime(Fixture fixture) {
  final time = fixture.time.trim();
  if (time.isEmpty) return '';
  return time.toUpperCase().contains('IST') ? time : '$time IST';
}

String _resultTime(Fixture fixture) {
  final value = fixture.time.trim();
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
  if (match == null) return value.isEmpty ? 'Time TBC' : value;
  final hour = int.parse(match.group(1)!);
  return '${hour % 12 == 0 ? 12 : hour % 12}:${match.group(2)} ${hour >= 12 ? 'PM' : 'AM'}';
}

String _teamName(String team) =>
    isNorthEastClub(team) ? 'NorthEast\nUnited FC' : team;

String _competition(Fixture fixture) {
  final value = matchCompetition(fixture);
  return value == 'Indian Super League'
      ? 'ISL'
      : value == 'Competition not available'
      ? ''
      : value;
}

Widget _crest(Fixture fixture, bool home, double size) => MatchTeamCrest(
  key: ValueKey('match-page-team-logo-${home ? fixture.home : fixture.away}'),
  team: home ? fixture.home : fixture.away,
  logo: home ? fixture.homeLogo : fixture.awayLogo,
  size: size,
);

class MatchPageHero extends StatelessWidget {
  const MatchPageHero({
    super.key,
    required this.fixture,
    required this.onOpen,
    this.onHighlights,
    this.onWatchLive,
    this.live = false,
    this.showReportAction = true,
    this.minHeight = 250,
  });
  final Fixture fixture;
  final VoidCallback onOpen;
  final VoidCallback? onHighlights;
  final VoidCallback? onWatchLive;
  final bool live;
  final bool showReportAction;
  final double minHeight;

  Widget _team(bool home, double size) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _crest(fixture, home, size),
      const SizedBox(height: 5),
      Text(
        _teamName(home ? fixture.home : fixture.away),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final played = fixture.played && !live;
    final style = result.getOutcomeStyle(result.getMatchOutcome(fixture));
    final competition = _competition(fixture);
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        key: ValueKey(played ? 'last-match-hero' : 'next-match-hero'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF10152A),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/matches-sunset-stadium.png',
                fit: BoxFit.cover,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x10000000),
                      Color(0x08000000),
                      Color(0xA6001000),
                    ],
                    stops: [0, .45, 1],
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpen,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: played ? 20 : 24,
                            vertical: played ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: matchPageRed,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white70),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!played) ...[
                                Icon(
                                  live ? Icons.circle : Icons.sports_soccer,
                                  size: live ? 10 : 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 7),
                              ],
                              Flexible(
                                child: Text(
                                  played
                                      ? 'Latest Result${competition.isEmpty ? '' : ' · $competition'}'
                                      : live
                                      ? 'Live Match'
                                      : 'Next Match',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: played ? 14 : 16,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _team(
                                true,
                                constraints.maxWidth < 350 ? 56 : 58,
                              ),
                            ),
                            if (played)
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${fixture.homeScoreDisplay} - ${fixture.awayScoreDisplay}',
                                        style: const TextStyle(
                                          fontSize: 43,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'FULL TIME',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: style.bg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        style.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: style.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const MatchVersus(),
                            Expanded(
                              child: _team(
                                false,
                                constraints.maxWidth < 350 ? 56 : 58,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!played) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: Colors.white,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  matchPageDate(fixture),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                height: 20,
                                width: 1,
                                color: Colors.white54,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                              ),
                              const Icon(
                                Icons.schedule,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  matchPageTime(fixture),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (played) ...[
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  matchPageDate(fixture, upper: true),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 18,
                                color: Colors.white54,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                            ],
                            ImageIcon(
                              const AssetImage('assets/icons/match-location.png'),
                              color: Colors.white,
                              size: played ? 16 : 20,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              flex: played ? 2 : 1,
                              child: Text(
                                fixture.venue.isEmpty
                                    ? 'Venue to be confirmed'
                                    : fixture.venue,
                                maxLines: played ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: played ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (live && onWatchLive != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const ValueKey('match-centre-watch-live'),
                              onPressed: onWatchLive,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: matchPageRed,
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Watch Live'),
                            ),
                          ),
                        ],
                        if (played) ...[
                          if (onHighlights != null) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 32,
                              child: FilledButton.icon(
                                onPressed: onHighlights,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: matchPageRed,
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text(
                                  'Watch Highlights',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (showReportAction)
                            TextButton(
                              onPressed: onOpen,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.only(top: 6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Match Report',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                        ],
                      ],
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
}

class MatchPageSurface extends StatelessWidget {
  const MatchPageSurface({super.key, required this.child, this.strip});
  final Widget child;
  final Color? strip;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x230F102D),
          blurRadius: 10,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: MatchPageWaves())),
          if (strip != null)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 5,
              child: ColoredBox(color: strip!),
            ),
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    ),
  );
}

class MatchPageWaves extends CustomPainter {
  const MatchPageWaves();
  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in [
      (0.0, const Color(0xFFFCE8F1)),
      (.12, const Color(0xFFF7D6E5)),
      (.24, const Color(0xFFF0BED4)),
    ]) {
      final shift = entry.$1;
      canvas.drawPath(
        Path()
          ..moveTo(size.width * (.62 + shift), size.height)
          ..quadraticBezierTo(
            size.width * (.94 + shift * .15),
            size.height * .72,
            size.width,
            size.height * (.45 + shift),
          )
          ..lineTo(size.width, size.height)
          ..close(),
        Paint()..color = entry.$2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _pill(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
  decoration: BoxDecoration(
    color: const Color(0xFFF9E2ED),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      color: matchPageRed,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  ),
);

class MatchPageFixtureCard extends StatelessWidget {
  const MatchPageFixtureCard({
    super.key,
    required this.fixture,
    required this.onTap,
  });
  final Fixture fixture;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MatchPageSurface(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: Column(
          children: [
            Row(
              children: [
                if (_competition(fixture).isNotEmpty)
                  _pill(_competition(fixture)),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: matchPageRed,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          '${matchPageDate(fixture)} · ${matchPageTime(fixture)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _crest(fixture, true, 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _teamName(fixture.home),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const _VersusBadge(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fixture.away,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _crest(fixture, false, 46),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const ImageIcon(
                  AssetImage('assets/icons/match-location.png'),
                  size: 18,
                  color: matchPageRed,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    fixture.venue.isEmpty
                        ? 'Venue to be confirmed'
                        : fixture.venue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _VersusBadge extends StatelessWidget {
  const _VersusBadge();
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.12,
    child: Container(
      width: 42,
      height: 26,
      transform: Matrix4.skewX(-.25),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCF0045), Color(0xFF760026)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        'VS',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class MatchPageResultCard extends StatelessWidget {
  const MatchPageResultCard({
    super.key,
    required this.fixture,
    required this.onTap,
  });
  final Fixture fixture;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final style = result.getOutcomeStyle(result.getMatchOutcome(fixture));
    final competition = _competition(fixture);
    final strip = style.label == 'LOST'
        ? const Color(0xFFE60046)
        : style.accentStrip;
    return MatchPageSurface(
      strip: strip,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 14, 6),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: _pill(
                          '${matchPageDate(fixture, upper: true)} · ${_resultTime(fixture)}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (competition.isNotEmpty ||
                          fixture.homeAwayLabel.isNotEmpty)
                        Flexible(
                          child: _pill(
                            [
                              competition,
                              fixture.homeAwayLabel,
                            ].where((value) => value.isNotEmpty).join(' · '),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _teamRow(fixture, true),
                  const SizedBox(height: 5),
                  _teamRow(fixture, false),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const ImageIcon(
                        AssetImage('assets/icons/match-location.png'),
                        size: 17,
                        color: matchPageRed,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          fixture.venue.isEmpty
                              ? 'Venue not available'
                              : fixture.venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: style.bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          style.label,
                          style: TextStyle(
                            color: style.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 1, color: Color(0xFFE2DEEA)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 7, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Match Report',
                    style: TextStyle(
                      color: matchPageRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward,
                    color: matchPageRed,
                    size: 19,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamRow(Fixture fixture, bool home) => Row(
    children: [
      _crest(fixture, home, 30),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          home ? fixture.home : fixture.away,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        home ? fixture.homeScoreDisplay : fixture.awayScoreDisplay,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class MatchPageRecentForm extends StatelessWidget {
  const MatchPageRecentForm({
    super.key,
    required this.fixtures,
    required this.onOpen,
    this.resultsTab = false,
  });
  final List<Fixture> fixtures;
  final ValueChanged<Fixture> onOpen;
  final bool resultsTab;
  @override
  Widget build(BuildContext context) {
    final recent = fixtures
        .where(
          (fixture) =>
              (isNorthEastClub(fixture.home) ||
                  isNorthEastClub(fixture.away)) &&
              result.getMatchOutcome(fixture) !=
                  result.MatchOutcome.unavailable,
        )
        .take(5)
        .toList()
        .reversed
        .toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: const Color(0xFFF7E5EE),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: MatchPageWaves()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        color: matchPageRed,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Recent Form',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            color: matchPageInk,
                          ),
                        ),
                      ),
                      Text(
                        resultsTab ? 'Latest' : 'Last 5 matches',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (resultsTab) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: _muted,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        'No recent results yet',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var index = 0; index < recent.length; index++) ...[
                          if (index > 0) const SizedBox(width: 8),
                          Expanded(child: _chip(recent[index])),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(Fixture fixture) {
    final outcome = result.getMatchOutcome(fixture);
    final letter = outcome == result.MatchOutcome.won
        ? 'W'
        : outcome == result.MatchOutcome.lost
        ? 'L'
        : 'D';
    return Tooltip(
      message: '${fixture.home} ${fixture.score} ${fixture.away}',
      child: Material(
        color: letter == 'W'
            ? const Color(0xFF08AA61)
            : letter == 'D'
            ? const Color(0xFFF4AC00)
            : const Color(0xFFF24465),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onOpen(fixture),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
