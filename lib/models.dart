class Player {
  const Player({
    required this.name,
    required this.jersey,
    required this.position,
    required this.image,
    this.quote = '',
    this.nationality = 'India',
    this.frontImage = '',
    this.firstName = '',
    this.lastName = '',
    this.positionCode = '',
    this.displayOrder = 0,
  });

  final String name;
  // Older API records contain numbers; newer records also support text labels.
  final Object jersey;
  final String position;
  final String image;
  final String frontImage;
  final String quote;
  final String nationality;
  final String firstName, lastName, positionCode;
  final int displayOrder;

  String get jerseyLabel => '$jersey'.trim();
  String get jerseyBadge =>
      RegExp(r'^\d+$').hasMatch(jerseyLabel) ? '#$jerseyLabel' : jerseyLabel;

  String get group {
    final value = '$positionCode $position'.toLowerCase();
    if (value.contains('coach') || value.contains('manager')) return 'COACH';
    if (value.contains('goal') ||
        value.contains('keeper') ||
        value.trim() == 'gk')
      return 'GOALKEEPER';
    if (value.contains('def') ||
        value.contains('back') ||
        value.contains('centre-back'))
      return 'DEFENDER';
    if (value.contains('mid')) return 'MIDFIELDER';
    if (value.contains('forward') ||
        value.contains('strik') ||
        value.contains('wing') ||
        value.contains('fwd'))
      return 'FORWARD';
    return 'MIDFIELDER';
  }
}

String matchText(Object? value) {
  if (value is! String && value is! num) return '';
  final text = value.toString().trim();
  return ['null', 'undefined', 'none', 'n/a'].contains(text.toLowerCase())
      ? ''
      : text;
}

double? matchNumber(Object? value, {required double min, required double max}) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(matchText(value));
  return number != null && number.isFinite && number >= min && number <= max
      ? number
      : null;
}

class MatchLineupPlayer {
  const MatchLineupPlayer({
    required this.name,
    this.number = '',
    this.position = '',
    this.captain = false,
    this.dateOfBirth = '',
    this.age,
    this.nationality = '',
    this.heightCm,
    this.preferredFoot = '',
    this.imageUrl = '',
    this.rating,
    this.sourceUrl = '',
  });
  final String name, number, position;
  final bool captain;
  final String dateOfBirth, nationality, preferredFoot, imageUrl, sourceUrl;
  final int? age;
  final double? heightCm, rating;

  int? ageOn(DateTime date) {
    final birth = DateTime.tryParse(dateOfBirth);
    if (birth == null || birth.isAfter(date)) return null;
    return date.year -
        birth.year -
        (date.month < birth.month ||
                (date.month == birth.month && date.day < birth.day)
            ? 1
            : 0);
  }
}

class MatchEvent {
  const MatchEvent({
    required this.minute,
    required this.type,
    this.team = '',
    this.player = '',
    this.detail = '',
  });
  final String minute, type, team, player, detail;
}

class MatchSubstitution {
  const MatchSubstitution({
    required this.team,
    required this.minute,
    required this.playerIn,
    required this.playerOut,
    this.reason = '',
  });
  final String team, minute, playerIn, playerOut, reason;
}

class MatchStatistic {
  const MatchStatistic({
    required this.label,
    required this.home,
    required this.away,
  });
  final String label, home, away;
}

class MatchDetails {
  const MatchDetails({
    this.homeLineup = const [],
    this.awayLineup = const [],
    this.homeFormation = '',
    this.awayFormation = '',
    this.lineupStatus = '',
    this.stats = const [],
    this.broadcast = '',
    this.sources = const [],
    this.fetchedAt = '',
    this.homeBench = const [],
    this.awayBench = const [],
    this.homeCoach = '',
    this.awayCoach = '',
    this.events = const [],
    this.homeCaptain = '',
    this.awayCaptain = '',
    this.substitutions = const [],
  });
  final List<MatchLineupPlayer> homeLineup, awayLineup;
  final String homeFormation, awayFormation, lineupStatus, broadcast, fetchedAt;
  final List<MatchStatistic> stats;
  final List<String> sources;
  final List<MatchLineupPlayer> homeBench, awayBench;
  final String homeCoach, awayCoach;
  final List<MatchEvent> events;
  final String homeCaptain, awayCaptain;
  final List<MatchSubstitution> substitutions;

  factory MatchDetails.fromJson(Object? value) {
    if (value is! Map) return const MatchDetails();
    List<Map> rows(String key) => value[key] is List
        ? (value[key] as List).whereType<Map>().toList()
        : [];
    List<MatchLineupPlayer> lineup(String key) =>
        rows(key)
            .where((row) => matchText(row['name']).isNotEmpty)
            .map(
              (row) => MatchLineupPlayer(
                name: matchText(row['name']),
                number: matchText(row['number']),
                position: matchText(row['position']),
                captain: row['captain'] == true,
                dateOfBirth: matchText(row['date_of_birth']),
                age: matchNumber(row['age'], min: 0, max: 120)?.toInt(),
                nationality: matchText(row['nationality']),
                heightCm: matchNumber(row['height_cm'], min: 50, max: 300),
                preferredFoot: matchText(row['preferred_foot']),
                imageUrl: matchText(row['image_url']),
                rating: matchNumber(row['rating'], min: 0, max: 10),
                sourceUrl: matchText(row['source_url']),
              ),
            )
            .toList();
    return MatchDetails(
      homeLineup: lineup('home_lineup'),
      awayLineup: lineup('away_lineup'),
      homeBench: lineup('home_bench'),
      awayBench: lineup('away_bench'),
      homeCoach: matchText(value['home_coach']),
      awayCoach: matchText(value['away_coach']),
      homeCaptain: matchText(value['home_captain']),
      awayCaptain: matchText(value['away_captain']),
      substitutions: rows('substitutions')
          .map(
            (row) => MatchSubstitution(
              team: matchText(row['team']),
              minute: matchText(row['minute']),
              playerIn: matchText(row['player_in']),
              playerOut: matchText(row['player_out']),
              reason: matchText(row['reason']),
            ),
          )
          .toList(),
      events: rows('events')
          .map(
            (row) => MatchEvent(
              minute: matchText(row['minute']),
              type: '${row['type'] ?? 'other'}',
              team: matchText(row['team']),
              player: matchText(row['player']),
              detail: matchText(row['detail']),
            ),
          )
          .toList(),
      homeFormation: matchText(value['home_formation']),
      awayFormation: matchText(value['away_formation']),
      lineupStatus: matchText(value['lineup_status']),
      broadcast: matchText(value['broadcast']),
      stats: rows('stats')
          .map(
            (row) => MatchStatistic(
              label: matchText(row['label']),
              home: matchText(row['home']),
              away: matchText(row['away']),
            ),
          )
          .toList(),
      sources: value['source_urls'] is List
          ? (value['source_urls'] as List).whereType<String>().toList()
          : [],
      fetchedAt: matchText(value['fetched_at']),
    );
  }
}

class MatchPhoto {
  const MatchPhoto({required this.url, this.caption = ''});
  final String url, caption;
}

class MatchLink {
  const MatchLink({
    required this.url,
    this.title = '',
    this.sourceUrl = '',
    this.description = '',
  });
  final String url, title, sourceUrl, description;
  bool get isHighlight =>
      RegExp(r'\bhighlights?\b', caseSensitive: false).hasMatch(title);
}

class Fixture {
  const Fixture({
    required this.home,
    required this.away,
    required this.date,
    required this.time,
    required this.venue,
    required this.round,
    required this.section,
    this.homeScore,
    this.awayScore,
    this.homeScoreText = '',
    this.awayScoreText = '',
    this.heading = '',
    this.homeAway = '',
    this.homeLogo = '',
    this.awayLogo = '',
    this.homeLogoBackground = '',
    this.awayLogoBackground = '',
    this.details = const MatchDetails(),
    this.videoUrl = '',
    this.summary = '',
    this.report = '',
    this.sourceUrl = '',
    this.winner = '',
    this.images = const [],
    this.previewPhotos = const [],
    this.previewVideos = const [],
    this.videos = const [],
    this.links = const [],
    this.feedThumbnail = '',
    this.liveThumbnail = '',
    this.liveOverlay,
    this.previewThumbnail = '',
    this.reportThumbnail = '',
    this.previewTitle = '',
    this.previewDescription = '',
    this.previewContent = '',
    this.previewUrl = '',
    this.reportTitle = '',
    this.reportUrl = '',
    this.liveUrl = '',
    this.matchStatus = 'Upcoming',
    this.journeyStage = '',
    this.id = '',
  });

  final String home;
  final String away;
  final String date;
  final String time;
  final String venue;
  final String round;
  final String section;
  final int? homeScore;
  final int? awayScore;
  final String homeScoreText;
  final String awayScoreText;
  String get homeScoreDisplay =>
      homeScoreText.trim().isNotEmpty ? homeScoreText : '${homeScore ?? '—'}';
  String get awayScoreDisplay =>
      awayScoreText.trim().isNotEmpty ? awayScoreText : '${awayScore ?? '—'}';
  String get score => '$homeScoreDisplay – $awayScoreDisplay';
  final String heading;
  final String homeAway;
  String get homeAwayLabel => switch (homeAway.trim().toLowerCase()) {
    'home' => 'Home',
    'away' => 'Away',
    _ => '',
  };
  final String homeLogo;
  final String awayLogo;
  final String homeLogoBackground;
  final String awayLogoBackground;
  final MatchDetails details;
  final String videoUrl;
  final String summary, report, sourceUrl, winner;
  final List<String> images;
  final List<MatchPhoto> previewPhotos;
  final List<MatchLink> previewVideos;
  final List<MatchLink> videos, links;
  final String feedThumbnail, liveThumbnail, previewThumbnail, reportThumbnail;
  final double? liveOverlay;
  final String previewTitle,
      previewDescription,
      previewContent,
      previewUrl,
      reportTitle,
      reportUrl,
      liveUrl,
      matchStatus,
      journeyStage,
      id;
  String get highlightsUrl =>
      videos.where((video) => video.isHighlight).firstOrNull?.url ?? '';

  bool get played => section == 'completed' || homeScore != null;
}

class Story {
  const Story({required this.title, required this.category});

  final String title;
  final String category;
}

class ClubContent {
  const ClubContent({
    required this.players,
    required this.fixtures,
    required this.stories,
    this.fixturesUnavailable = false,
    this.playersUnavailable = false,
    this.defaultMatchThumbnail = '',
  });

  final List<Player> players;
  final List<Fixture> fixtures;
  final bool fixturesUnavailable;
  final bool playersUnavailable;
  final String defaultMatchThumbnail;
  final List<Story> stories;
}
