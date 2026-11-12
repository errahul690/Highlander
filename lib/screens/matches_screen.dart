import '../brand_colors.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../club_repository.dart';
import '../realtime_client.dart';
import '../widgets/club_crest.dart';
import '../widgets/club_header.dart';
import '../widgets/match_page_cards.dart';
import '../club_identity.dart' as club_identity;
import '../feed_match_schedule.dart';
import '../models.dart';
import 'live_match_screen.dart';
import 'match_detail_screen.dart';
import 'match_preview_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, this.repository});
  final ClubRepository? repository;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  String _tab = 'FIXTURES';
  bool _showAllResults = false;
  late Future<ClubContent> _content;
  ClubContent? _shown;
  StreamSubscription<Map<String, dynamic>>? _matches;

  ClubRepository get _repository =>
      widget.repository ?? ClubRepository.instance;

  @override
  void initState() {
    super.initState();
    _shown = _repository.cachedOrNull;
    // A saved list paints immediately. The refresh replaces it when it arrives.
    _content = _repository.load(forceRefresh: _shown != null);
    _matches = RealtimeClient.instance.settingsChanges.listen((event) {
      if (!mounted) return;
      if (['all', 'matches', 'knockoutMatches'].contains(event['resource'])) {
        setState(() {
          _content = (widget.repository ?? ClubRepository.instance).load(
            forceRefresh: true,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _matches?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _content = (widget.repository ?? ClubRepository.instance).load(
        forceRefresh: true,
      );
    });
    await _content;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/club-logo.png'), context);
    precacheImage(
      const AssetImage('assets/images/match_hero_stadium.png'),
      context,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F6FC),
    appBar: const ClubHeader(
      title: 'Matches',
      showBack: false,
      showSearch: false,
      showSupport: false,
      uppercaseTitle: false,
      backButtonWidth: 60,
    ),
    body: FutureBuilder<ClubContent>(
      future: _content,
      initialData: _shown,
      builder: (context, snapshot) {
        final content = snapshot.data;
        if (content == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || content.fixturesUnavailable) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load matches. Please try again.'),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }
        _shown = content;
        int compare(Fixture a, Fixture b) {
          final first = _parseFixtureDate(a.date),
              second = _parseFixtureDate(b.date);
          if (first == null) return second == null ? 0 : 1;
          if (second == null) return -1;
          return first.compareTo(second);
        }

        final upcoming =
            content.fixtures.where((fixture) => !fixture.played).toList()
              ..sort(compare);
        final completed =
            content.fixtures.where((fixture) => fixture.played).toList()
              ..sort((a, b) => compare(b, a));
        final resultsTab = _tab == 'RESULTS';
        final hero = resultsTab
            ? (completed.isEmpty ? null : completed.first)
            : (upcoming.isEmpty ? null : upcoming.first);
        final remainingFixtures = upcoming.skip(1).toList();
        final previous = completed.skip(1).toList();
        final shownResults = _showAllResults
            ? previous
            : previous.take(2).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          color: matchPageRed,
          child: ListView(
            key: ValueKey('matches-$_tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              13,
              20,
              13,
              MediaQuery.paddingOf(context).bottom + 28,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x200F102D),
                        blurRadius: 9,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _tabButton(
                        'FIXTURES',
                        'Fixtures',
                        Icons.calendar_today_outlined,
                      ),
                      _tabButton(
                        'RESULTS',
                        'Results',
                        Icons.emoji_events_outlined,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (hero != null)
                MatchPageHero(
                  fixture: hero,
                  live: _isLive(hero),
                  onOpen: () => resultsTab
                      ? _openReport(context, hero)
                      : _openFixture(context, hero),
                  onHighlights:
                      resultsTab &&
                          (hero.highlightsUrl.isNotEmpty ||
                              hero.videoUrl.isNotEmpty)
                      ? () => _openReport(context, hero, playHighlights: true)
                      : null,
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Text(
                      resultsTab ? 'No results yet' : 'No upcoming fixtures',
                      style: const TextStyle(color: Color(0xFF747588)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              MatchPageRecentForm(
                fixtures: completed,
                resultsTab: resultsTab,
                onOpen: (fixture) => _openReport(context, fixture),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resultsTab ? 'Previous Results' : 'Upcoming Fixtures',
                          style: TextStyle(
                            fontSize: resultsTab ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            color: matchPageInk,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 50,
                          height: 4,
                          decoration: BoxDecoration(
                            color: brandAccent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (resultsTab && previous.length > 2)
                    TextButton(
                      onPressed: () =>
                          setState(() => _showAllResults = !_showAllResults),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF747588),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_showAllResults ? 'Show less' : 'View all'),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (resultsTab) ...[
                if (shownResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No previous results yet',
                        style: TextStyle(color: Color(0xFF747588)),
                      ),
                    ),
                  ),
                for (final fixture in shownResults)
                  MatchPageResultCard(
                    fixture: fixture,
                    onTap: () => _openReport(context, fixture),
                  ),
              ] else ...[
                if (remainingFixtures.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No more upcoming fixtures',
                        style: TextStyle(color: Color(0xFF747588)),
                      ),
                    ),
                  ),
                for (final fixture in remainingFixtures)
                  MatchPageFixtureCard(
                    fixture: fixture,
                    onTap: () => _openFixture(context, fixture),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _tabButton(String value, String label, IconData icon) => Expanded(
    child: Material(
      color: _tab == value ? matchPageRed : Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => setState(() => _tab = value),
        borderRadius: BorderRadius.circular(28),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: _tab == value ? Colors.white : matchPageInk,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: _tab == value ? Colors.white : matchPageInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static bool _isLive(Fixture fixture) =>
      fixturePhase(fixture, DateTime.now()) == FeedMatchPhase.live;

  static DateTime? _parseFixtureDate(String str) {
    final trimmed = str.trim();
    if (trimmed.isEmpty) return null;

    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
      try {
        return DateTime.parse(trimmed.substring(0, 10));
      } catch (_) {}
    }

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
        .firstMatch(trimmed);
    if (match != null) {
      final day = int.tryParse(match.group(1)!) ?? 1;
      final mon = monthMap[match.group(2)!.toLowerCase()] ?? 1;
      final yr = match.group(3) != null
          ? int.tryParse(match.group(3)!) ?? DateTime.now().year
          : DateTime.now().year;
      return DateTime(yr, mon, day);
    }
    return null;
  }

  void _openFixture(BuildContext context, Fixture fixture) {
    final phase = fixturePhase(fixture, DateTime.now());
    final Widget page = switch (phase) {
      FeedMatchPhase.preview => MatchPreviewScreen(fixture: fixture),
      FeedMatchPhase.live => LiveMatchScreen(fixture: fixture),
      FeedMatchPhase.upcoming ||
      FeedMatchPhase.report => MatchDetailScreen(fixture: fixture),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openReport(
    BuildContext context,
    Fixture fixture, {
    bool playHighlights = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MatchDetailScreen(fixture: fixture, playHighlights: playHighlights),
      ),
    );
  }
}

/// Identifies if a team is the home club NorthEast United FC
bool isNorthEastClub(String name) => club_identity.isNorthEastClub(name);

/// Color theme configuration for Indian football clubs
class ClubColorTheme {
  final Color primary;
  final Color secondary;
  final Color text;
  final String shortCode;

  const ClubColorTheme({
    required this.primary,
    required this.secondary,
    required this.text,
    required this.shortCode,
  });
}

/// Returns signature club branding colors and initials for authentic shield rendering
ClubColorTheme getTeamColors(String teamName) {
  final name = teamName.toLowerCase();
  if (name.contains('mohun bagan') || name.contains('mariners')) {
    return const ClubColorTheme(
      primary: Color(0xFF006633),
      secondary: Color(0xFF800020),
      text: Color(0xFFFFDF7D),
      shortCode: 'MBSG',
    );
  }
  if (name.contains('kerala') || name.contains('blasters')) {
    return const ClubColorTheme(
      primary: Color(0xFFFFB800),
      secondary: Color(0xFF003B70),
      text: Colors.white,
      shortCode: 'KBFC',
    );
  }
  if (name.contains('bengaluru') || name.contains('blues')) {
    return const ClubColorTheme(
      primary: Color(0xFF0B4EA2),
      secondary: Color(0xFFD62235),
      text: Colors.white,
      shortCode: 'BFC',
    );
  }
  if (name.contains('odisha') || name.contains('kalinga')) {
    return const ClubColorTheme(
      primary: Color(0xFF5A2582),
      secondary: Color(0xFF222222),
      text: Colors.white,
      shortCode: 'OFC',
    );
  }
  if (name.contains('goa') || name.contains('gaurs')) {
    return const ClubColorTheme(
      primary: Color(0xFFEA5B1D),
      secondary: Color(0xFF132247),
      text: Colors.white,
      shortCode: 'FCG',
    );
  }
  if (name.contains('chennaiyin') || name.contains('machans')) {
    return const ClubColorTheme(
      primary: Color(0xFF004BA0),
      secondary: Color(0xFFFFD100),
      text: Colors.white,
      shortCode: 'CFC',
    );
  }
  if (name.contains('mumbai') || name.contains('islanders')) {
    return const ClubColorTheme(
      primary: Color(0xFF5BA6E8),
      secondary: Color(0xFF08264D),
      text: Colors.white,
      shortCode: 'MCFC',
    );
  }
  if (name.contains('east bengal') || name.contains('red and gold')) {
    return const ClubColorTheme(
      primary: Color(0xFFD9242C),
      secondary: Color(0xFFFFD400),
      text: Colors.white,
      shortCode: 'EBFC',
    );
  }
  if (name.contains('punjab')) {
    return const ClubColorTheme(
      primary: Color(0xFFE25C1D),
      secondary: Color(0xFF1B2F5B),
      text: Colors.white,
      shortCode: 'PFC',
    );
  }
  if (name.contains('hyderabad')) {
    return const ClubColorTheme(
      primary: Color(0xFFF7BD00),
      secondary: Color(0xFF000000),
      text: Colors.black,
      shortCode: 'HFC',
    );
  }
  if (name.contains('jamshedpur') || name.contains('red miners')) {
    return const ClubColorTheme(
      primary: Color(0xFF092956),
      secondary: Color(0xFFC8102E),
      text: Colors.white,
      shortCode: 'JFC',
    );
  }
  if (name.contains('sporting club delhi') || name.contains('delhi')) {
    return const ClubColorTheme(
      primary: Color(0xFF8B0000),
      secondary: Color(0xFF0A192F),
      text: Color(0xFFFFD700),
      shortCode: 'SCD',
    );
  }
  if (name.contains('shillong') || name.contains('lajong')) {
    return const ClubColorTheme(
      primary: Color(0xFFC62828),
      secondary: Color(0xFF1E1E1E),
      text: Colors.white,
      shortCode: 'SLFC',
    );
  }
  if (name.contains('bodoland')) {
    return const ClubColorTheme(
      primary: Color(0xFF1E7E34),
      secondary: Color(0xFFE65100),
      text: Colors.white,
      shortCode: 'BODO',
    );
  }
  if (name.contains('karbi') || name.contains('morning star')) {
    return const ClubColorTheme(
      primary: Color(0xFF1B5E20),
      secondary: Color(0xFFFFB300),
      text: Colors.white,
      shortCode: 'KAM',
    );
  }
  if (name.contains('mohammedan')) {
    return const ClubColorTheme(
      primary: Color(0xFF1A1A1A),
      secondary: Color(0xFF333333),
      text: Colors.white,
      shortCode: 'MSC',
    );
  }
  if (name.contains('churchill')) {
    return const ClubColorTheme(
      primary: Color(0xFFD32F2F),
      secondary: Color(0xFF1A1A1A),
      text: Colors.white,
      shortCode: 'CBFC',
    );
  }

  if (isNorthEastClub(teamName)) {
    return const ClubColorTheme(
      primary: brandAccent,
      secondary: Color(0xFF1A1A1A),
      text: Colors.white,
      shortCode: 'NEUFC',
    );
  }
  final initials = teamName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(3)
      .map((word) => word.characters.first.toUpperCase())
      .join();
  return ClubColorTheme(
    primary: const Color(0xFF475569),
    secondary: const Color(0xFF1E293B),
    text: Colors.white,
    shortCode: initials.isEmpty ? '?' : initials,
  );
}

/// Team mini shield or crest logo widget
Widget buildTeamMiniShield(
  String teamName,
  String logoUrl, {
  double size = 34,
  Color background = ClubCrest.homeBackground,
}) {
  return ClubCrest(
    team: teamName,
    logo: logoUrl,
    size: size,
    background: background,
  );
}

/// Mini crest shield placeholder with team colors
Widget buildMiniPlaceholder(String teamName, {double size = 34}) {
  final colors = getTeamColors(teamName);
  return Container(
    width: size,
    height: size * 1.05,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.primary, colors.secondary],
      ),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(size * 0.16),
        bottom: Radius.circular(size * 0.42),
      ),
      border: Border.all(color: Colors.white, width: 1.2),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    child: Center(
      child: Text(
        colors.shortCode,
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.28,
        ),
      ),
    ),
  );
}

/// Match outcome classification for NorthEast United FC
enum MatchOutcome { won, draw, lost, unavailable }

/// Visual styling configuration for match outcome chip and accent strip
class OutcomeStyle {
  final String label;
  final Color bg;
  final Color text;
  final Color accentStrip;

  const OutcomeStyle({
    required this.label,
    required this.bg,
    required this.text,
    required this.accentStrip,
  });
}

MatchOutcome getMatchOutcome(Fixture fixture) {
  final isHome = isNorthEastClub(fixture.home);
  final isAway = isNorthEastClub(fixture.away);

  final hScore = fixture.homeScore;
  final aScore = fixture.awayScore;
  if (hScore == null || aScore == null) return MatchOutcome.unavailable;

  if (hScore == aScore) return MatchOutcome.draw;

  if (isHome) {
    return hScore > aScore ? MatchOutcome.won : MatchOutcome.lost;
  } else if (isAway) {
    return aScore > hScore ? MatchOutcome.won : MatchOutcome.lost;
  } else {
    return hScore > aScore ? MatchOutcome.won : MatchOutcome.lost;
  }
}

OutcomeStyle getOutcomeStyle(MatchOutcome outcome) {
  switch (outcome) {
    case MatchOutcome.unavailable:
      return const OutcomeStyle(
        label: 'RESULT UNAVAILABLE',
        bg: Color(0xFFF3F4F6),
        text: Color(0xFF6B7280),
        accentStrip: Color(0xFF9CA3AF),
      );
    case MatchOutcome.won:
      return const OutcomeStyle(
        label: 'WON',
        bg: Color(0xFFD1FAE5),
        text: Color(0xFF065F46),
        accentStrip: Color(0xFF10B981),
      );
    case MatchOutcome.draw:
      return const OutcomeStyle(
        label: 'DRAW',
        bg: Color(0xFFFEF3C7),
        text: Color(0xFFD97706),
        accentStrip: Color(0xFFF59E0B),
      );
    case MatchOutcome.lost:
      return const OutcomeStyle(
        label: 'LOST',
        bg: Color(0xFFFEE2E2),
        text: Color(0xFFDC2626),
        accentStrip: Color(0xFFEF4444),
      );
  }
}
