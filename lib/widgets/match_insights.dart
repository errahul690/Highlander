import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../models.dart';
import '../club_repository.dart';
import '../pitch_layout.dart';
import '../theme.dart';

export '../pitch_layout.dart' show lineupRole, parseFormation, layoutRows;

Widget _initials(String name, {Color color = clubRed, double size = 42}) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  final letters = words.isEmpty
      ? '?'
      : words.take(2).map((word) => word.characters.first).join().toUpperCase();
  return CircleAvatar(
    radius: size / 2,
    backgroundColor: color.withValues(alpha: .1),
    child: Text(
      letters,
      style: TextStyle(
        color: color,
        fontSize: size * .3,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

Widget _portrait(
  MatchLineupPlayer player, {
  double size = 42,
  Color color = clubRed,
}) {
  if (player.imageUrl.isEmpty) {
    return _initials(player.name, color: color, size: size);
  }
  return ClipOval(
    child: Image.network(
      ClubRepository.mediaUrl(player.imageUrl),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          _initials(player.name, color: color, size: size),
    ),
  );
}

void showMatchPlayer(
  BuildContext context,
  MatchLineupPlayer player,
  String team,
  String matchDate, {
  String captainName = '',
}) {
  final date = DateTime.tryParse(matchDate);
  final matchAge = date == null ? null : player.ageOn(date);
  final fields = <String, String>{
    if (player.position.isNotEmpty) 'Position': player.position,
    if (player.number.isNotEmpty) 'Shirt number': player.number,
    if (matchAge != null)
      'Age on match day': '$matchAge years'
    else if (player.age != null)
      'Reported age': '${player.age} years',
    if (player.dateOfBirth.isNotEmpty) 'Date of birth': player.dateOfBirth,
    if (player.nationality.isNotEmpty) 'Nationality': player.nationality,
    if (player.heightCm != null)
      'Height':
          '${player.heightCm!.toStringAsFixed(player.heightCm! % 1 == 0 ? 0 : 1)} cm',
    if (player.preferredFoot.isNotEmpty) 'Preferred foot': player.preferredFoot,
    if (isMatchCaptain(player, captainName)) 'Role': 'Captain',
    if (player.rating != null)
      'Match rating': '${player.rating!.toStringAsFixed(1)} / 10',
  };
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _portrait(player, size: 70),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(team, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (fields.isEmpty)
              const Text(
                'More player details are not available for this match.',
              ),
            for (final field in fields.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        field.key,
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        field.value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class MatchPlayerTile extends StatelessWidget {
  const MatchPlayerTile({
    super.key,
    required this.player,
    required this.team,
    required this.matchDate,
    this.color = clubRed,
    this.captainName = '',
  });
  final MatchLineupPlayer player;
  final String team, matchDate;
  final Color color;
  final String captainName;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Material(
      color: const Color(0xFFF8F9FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showMatchPlayer(
          context,
          player,
          team,
          matchDate,
          captainName: captainName,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _portrait(player, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${player.name}${isMatchCaptain(player, captainName) ? ' (C)' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (player.number.isNotEmpty) '#${player.number}',
                        if (player.position.isNotEmpty) player.position,
                        if (player.nationality.isNotEmpty) player.nationality,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (player.rating != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF102A43),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    player.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right,
                size: 17,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Color ratingTint(double rating) {
  if (rating >= 8) return const Color(0xFF16A34A);
  if (rating >= 7) return const Color(0xFF65A30D);
  if (rating >= 6) return const Color(0xFFCA8A04);
  return const Color(0xFFEA580C);
}

class MatchPitch extends StatelessWidget {
  const MatchPitch({
    super.key,
    required this.players,
    required this.team,
    required this.matchDate,
    this.color = clubRed,
    this.awayPlayers = const [],
    this.awayTeam = '',
    this.awayColor = const Color(0xFFF5C518),
    this.homeFormation = '',
    this.awayFormation = '',
    this.homeCaptain = '',
    this.awayCaptain = '',
  });
  final List<MatchLineupPlayer> players;
  final List<MatchLineupPlayer> awayPlayers;
  final String team, matchDate, awayTeam;
  final String homeFormation, awayFormation, homeCaptain, awayCaptain;
  final Color color, awayColor;

  static bool canDisplay(
    List<MatchLineupPlayer> players, {
    String formation = '',
  }) {
    if (players.length != 11 ||
        players.where((player) => lineupRole(player.position) == 'GK').length !=
            1) {
      return false;
    }
    if (parseFormation(formation).isNotEmpty) return true;
    return players.every((player) => lineupRole(player.position) != null);
  }

  @override
  Widget build(BuildContext context) {
    final homeRows = canDisplay(players, formation: homeFormation)
        ? layoutRows(players, formation: homeFormation)
        : <List<MatchLineupPlayer>>[];
    final awayRows = canDisplay(awayPlayers, formation: awayFormation)
        ? layoutRows(awayPlayers, formation: awayFormation)
        : <List<MatchLineupPlayer>>[];
    final homeAvg = teamRating(players);
    final awayAvg = teamRating(awayPlayers);
    return Container(
      key: const ValueKey('match-position-pitch'),
      height:
          90.0 +
          82 *
              ((homeRows.isEmpty ? 1 : homeRows.length) +
                  (awayRows.isEmpty ? 1 : awayRows.length)),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B2A22), Color(0xFF146B4A), Color(0xFF0B2A22)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _PitchLines())),
          Positioned(
            left: 10,
            right: 10,
            top: 10,
            child: _PitchBanner(
              home: team,
              away: awayTeam,
              homeFormation: homeFormation,
              awayFormation: awayFormation,
              homeRating: homeAvg,
              awayRating: awayAvg,
              homeColor: color,
              awayColor: awayColor,
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 58, 4, 22),
              child: Column(
                children: [
                  if (awayRows.isEmpty)
                    const Expanded(
                      child: _EmptyHalf(
                        label: 'Away pitch positions unavailable',
                      ),
                    )
                  else
                    for (final row in awayRows)
                      Expanded(
                        child: _PitchRow(
                          players: row,
                          team: awayTeam.isEmpty ? team : awayTeam,
                          matchDate: matchDate,
                          color: awayColor,
                          captainName: awayCaptain,
                          darkText: true,
                        ),
                      ),
                  if (homeRows.isEmpty)
                    const Expanded(
                      child: _EmptyHalf(
                        label: 'Home pitch positions unavailable',
                      ),
                    )
                  else
                    for (final row in homeRows.reversed)
                      Expanded(
                        child: _PitchRow(
                          players: row,
                          team: team,
                          matchDate: matchDate,
                          color: color,
                          captainName: homeCaptain,
                        ),
                      ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 12,
            right: 12,
            bottom: 6,
            child: Text(
              'STARTING SHAPE · TAP A PLAYER  ·  C = MATCH CAPTAIN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 8,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchBanner extends StatelessWidget {
  const _PitchBanner({
    required this.home,
    required this.away,
    required this.homeFormation,
    required this.awayFormation,
    required this.homeRating,
    required this.awayRating,
    required this.homeColor,
    required this.awayColor,
  });
  final String home, away, homeFormation, awayFormation;
  final double? homeRating, awayRating;
  final Color homeColor, awayColor;

  @override
  Widget build(BuildContext context) {
    Widget chip(String name, String label, Color color, double? rating) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rating != null) ...[
                Tooltip(
                  message: 'Average of available player ratings',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: ratingTint(rating),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rating.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  '$name ${label.isEmpty ? '' : label}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        );
    return Row(
      children: [
        Expanded(child: chip(home, homeFormation, homeColor, homeRating)),
        const SizedBox(width: 8),
        if (away.isNotEmpty)
          Expanded(child: chip(away, awayFormation, awayColor, awayRating)),
      ],
    );
  }
}

class _EmptyHalf extends StatelessWidget {
  const _EmptyHalf({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _PitchRow extends StatelessWidget {
  const _PitchRow({
    required this.players,
    required this.team,
    required this.matchDate,
    required this.color,
    required this.captainName,
    this.darkText = false,
  });
  final List<MatchLineupPlayer> players;
  final String team, matchDate, captainName;
  final Color color;
  final bool darkText;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (final player in players)
        Expanded(
          child: _PitchToken(
            player: player,
            team: team,
            matchDate: matchDate,
            color: color,
            captain: isMatchCaptain(player, captainName),
            captainName: captainName,
            darkText: darkText,
          ),
        ),
    ],
  );
}

class _PitchToken extends StatelessWidget {
  const _PitchToken({
    required this.player,
    required this.team,
    required this.matchDate,
    required this.color,
    required this.captain,
    required this.captainName,
    required this.darkText,
  });
  final MatchLineupPlayer player;
  final String team, matchDate;
  final Color color;
  final bool captain, darkText;
  final String captainName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showMatchPlayer(
        context,
        player,
        team,
        matchDate,
        captainName: captainName,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: captain ? const Color(0xFFF5C518) : Colors.white,
                        width: captain ? 2.4 : 1.6,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: ColoredBox(
                        color: color,
                        child: player.imageUrl.isEmpty
                            ? Center(
                                child: Text(
                                  player.number.isEmpty ? '•' : player.number,
                                  style: TextStyle(
                                    color: darkText
                                        ? const Color(0xFF111827)
                                        : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : Image.network(
                                ClubRepository.mediaUrl(player.imageUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    player.number.isEmpty ? '•' : player.number,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                if (captain)
                  const Positioned(
                    left: -2,
                    top: -4,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Color(0xFFF5C518),
                      child: Text(
                        'C',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                if (player.rating != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: ratingTint(player.rating!),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        player.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                if (player.number.isNotEmpty && player.imageUrl.isNotEmpty)
                  Positioned(
                    right: 0,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        player.number,
                        style: TextStyle(
                          color: darkText
                              ? const Color(0xFF111827)
                              : Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              player.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                height: 1.05,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
          if (player.position.isNotEmpty)
            Text(
              player.position,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _PitchLines extends CustomPainter {
  const _PitchLines();
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 8; i++) {
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(0, size.height * i / 8, size.width, size.height / 8),
          Paint()..color = const Color(0x09FFFFFF),
        );
      }
    }
    final paint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final field = Rect.fromLTWH(14, 16, size.width - 28, size.height - 36);
    canvas.drawRect(field, paint);
    canvas.drawLine(
      Offset(14, field.center.dy),
      Offset(size.width - 14, field.center.dy),
      paint,
    );
    canvas.drawCircle(field.center, size.width * .12, paint);
    canvas.drawRect(
      Rect.fromLTWH(size.width * .25, 16, size.width * .5, 48),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .25, field.bottom - 48, size.width * .5, 48),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MatchStatComparison extends StatelessWidget {
  const MatchStatComparison({super.key, required this.stat});
  final MatchStatistic stat;
  @override
  Widget build(BuildContext context) {
    final home = double.tryParse(stat.home.replaceAll('%', '').trim());
    final away = double.tryParse(stat.away.replaceAll('%', '').trim());
    final ratio =
        home != null &&
            away != null &&
            home.isFinite &&
            away.isFinite &&
            home >= 0 &&
            away >= 0 &&
            home + away > 0
        ? home / (home + away)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.home,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  stat.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  stat.away,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 420),
                tween: Tween(begin: 0, end: ratio),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  color: clubRed,
                  backgroundColor: const Color(0xFF2463EB),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MatchTimeline extends StatelessWidget {
  const MatchTimeline({super.key, required this.fixture});
  final Fixture fixture;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'MATCH MOMENTS',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 5),
      const Text(
        'The story of the game, minute by minute.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      ),
      const SizedBox(height: 18),
      if (fixture.details.events.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.timeline, color: Colors.grey),
              SizedBox(width: 12),
              Expanded(child: Text('Match timeline not available yet.')),
            ],
          ),
        ),
      for (final event in fixture.details.events)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(
                    "${event.minute}'",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      left: BorderSide(
                        color: event.team == 'away'
                            ? const Color(0xFF2463EB)
                            : clubRed,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        event.type.contains('goal') || event.type == 'penalty'
                            ? Icons.sports_soccer
                            : event.type == 'substitution'
                            ? Icons.swap_horiz
                            : event.type.contains('card')
                            ? Icons.style
                            : Icons.flag_outlined,
                        size: 20,
                        color: event.type == 'yellow_card'
                            ? Colors.amber[700]
                            : event.type == 'red_card'
                            ? clubRed
                            : clubInk,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.type.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                                color: Color(0xFF667085),
                              ),
                            ),
                            if (event.player.isNotEmpty)
                              Text(
                                event.player,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            if (event.detail.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  event.detail,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            if (event.team.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  event.team == 'home'
                                      ? fixture.home
                                      : fixture.away,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class MatchHighlightsBanner extends StatelessWidget {
  const MatchHighlightsBanner({super.key, required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Material(
    color: clubRed,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => openAppDestination(context, url),
      child: const Padding(
        padding: EdgeInsets.all(17),
        child: Row(
          children: [
            Icon(Icons.play_circle_fill, size: 42, color: Colors.white),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WATCH HIGHLIGHTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Replay the match moments',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_outward, size: 20, color: Colors.white),
          ],
        ),
      ),
    ),
  );
}
