import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../club_repository.dart';
import '../realtime_client.dart';
import '../widgets/club_crest.dart';
import '../widgets/hero_latest_result_card.dart';
import '../widgets/hero_next_match_card.dart';
import '../widgets/match_card_veil.dart';
import '../widgets/team_logo_entrance.dart';
import '../club_identity.dart' as club_identity;
import '../app_navigation.dart';
import '../feed_match_schedule.dart';
import '../models.dart';
import '../match_competition.dart';
import 'live_match_screen.dart';
import 'match_detail_screen.dart';
import 'match_preview_screen.dart';

class FormMatchResult {
  final String letter;
  final Color color;
  final String opponent;
  final String score;
  final String tooltip;
  final Fixture fixture;

  const FormMatchResult({
    required this.letter,
    required this.color,
    required this.opponent,
    required this.score,
    required this.tooltip,
    required this.fixture,
  });
}

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, this.repository});
  final ClubRepository? repository;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  String _tab = 'FIXTURES';
  DateTime? _selectedDate;
  DateTime? _selectedResultDate;
  late Future<ClubContent> _content;
  StreamSubscription<Map<String, dynamic>>? _matches;

  @override
  void initState() {
    super.initState();
    _content = (widget.repository ?? ClubRepository.instance).load(
      forceRefresh: true,
    );
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
      _selectedDate = null;
      _selectedResultDate = null;
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      appBar: AppBar(
        toolbarHeight: 56,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFBA0C12),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          'MATCHES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: FutureBuilder<ClubContent>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final content = snapshot.data ?? clubFallback;
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
          final upcomingFixtures = content.fixtures
              .where((f) => !f.played)
              .toList();
          final completedMatches = content.fixtures
              .where((f) => f.played)
              .toList();

          // Sort upcoming fixtures chronologically (earliest upcoming match first)
          upcomingFixtures.sort((a, b) {
            final da = _parseFixtureDate(a.date);
            final db = _parseFixtureDate(b.date);
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });

          // Sort completed matches reverse-chronologically (most recent match first)
          completedMatches.sort((a, b) {
            final da = _parseFixtureDate(a.date);
            final db = _parseFixtureDate(b.date);
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          });

          // Truly next upcoming match
          final featuredMatch = upcomingFixtures.isNotEmpty
              ? upcomingFixtures.first
              : null;

          // Extract real unique dates of upcoming fixtures
          final matchDates = <DateTime>[];
          for (final f in upcomingFixtures) {
            final dt = _parseFixtureDate(f.date);
            if (dt != null) {
              final pure = DateTime(dt.year, dt.month, dt.day);
              if (!matchDates.any((x) => _isSameDay(x, pure))) {
                matchDates.add(pure);
              }
            }
          }
          matchDates.sort((a, b) => a.compareTo(b));

          // Pre-cache remote logos so they appear smoothly
          for (final f in content.fixtures) {
            if (f.homeLogo.isNotEmpty && !isNorthEastClub(f.home)) {
              precacheImage(NetworkImage(f.homeLogo), context);
            }
            if (f.awayLogo.isNotEmpty && !isNorthEastClub(f.away)) {
              precacheImage(NetworkImage(f.awayLogo), context);
            }
          }

          // Filter fixtures by selected date if user chose one
          final displayedUpcoming = _selectedDate == null
              ? upcomingFixtures
              : upcomingFixtures
                    .where((f) => _doesFixtureMatchDate(f, _selectedDate!))
                    .toList();

          // Dynamic month title: matches current selected date or earliest upcoming match
          final currentDisplayMonth = _formatMonthName(
            _selectedDate ??
                (matchDates.isNotEmpty ? matchDates.first : DateTime.now()),
          );

          // Completed results and their independent date filter
          final latestResult = completedMatches.isNotEmpty
              ? completedMatches.first
              : null;

          final resultDates = <DateTime>[];
          for (final f in completedMatches) {
            final dt = _parseFixtureDate(f.date);
            if (dt != null) {
              final pure = DateTime(dt.year, dt.month, dt.day);
              if (!resultDates.any((x) => _isSameDay(x, pure))) {
                resultDates.add(pure);
              }
            }
          }
          resultDates.sort((a, b) => a.compareTo(b));

          final displayedResults = _selectedResultDate == null
              ? (completedMatches.length > 1
                    ? completedMatches.sublist(1)
                    : completedMatches)
              : completedMatches
                    .where(
                      (f) => _doesFixtureMatchDate(f, _selectedResultDate!),
                    )
                    .toList();

          final currentResultMonth = _formatMonthName(
            _selectedResultDate ??
                (resultDates.isNotEmpty ? resultDates.last : DateTime.now()),
          );

          // Calculate real form from actual completed matches
          final recentForm = _calculateRecentForm(completedMatches);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9E3),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        children: [
                          for (final tab in ['FIXTURES', 'RESULTS'])
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _tab = tab),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _tab == tab
                                        ? const Color(0xFFD21E1E)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(50),
                                    boxShadow: _tab == tab
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFD21E1E)
                                                  .withValues(alpha: .32),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    tab,
                                    style: TextStyle(
                                      color: _tab == tab
                                          ? Colors.white
                                          : const Color(0xFF2B2B2B),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      letterSpacing: .8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_tab == 'FIXTURES') ...[
                    // Hero Card: Real Next Upcoming Match
                    if (featuredMatch != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _HeroNextMatchCard(
                          fixture: featuredMatch,
                          live: _isLive(featuredMatch),
                          onViewMatch: () =>
                              _openFixture(context, featuredMatch),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Recent Form Section (Dynamically computed from actual completed matches)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7F0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up_rounded,
                                      color: Color(0xFF059669),
                                      size: 20,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Recent form',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  recentForm.isNotEmpty
                                      ? 'Last ${recentForm.length} matches'
                                      : 'Recent matches',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (recentForm.isEmpty)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'No completed matches recorded yet this season.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  for (
                                    int i = 0;
                                    i < recentForm.length;
                                    i++
                                  ) ...[
                                    Expanded(
                                      child: Tooltip(
                                        message: recentForm[i].tooltip,
                                        child: InkWell(
                                          key: ValueKey('recent-form-$i'),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () => _openReport(
                                            context,
                                            recentForm[i].fixture,
                                          ),
                                          child: _buildFormChip(
                                            recentForm[i].letter,
                                            recentForm[i].color,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (i < recentForm.length - 1)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Section Header: UPCOMING FIXTURES
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'UPCOMING FIXTURES',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: 44,
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD21E1E),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedDate != null)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedDate = null;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'CLEAR FILTER',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Fixture Cards List or Empty State
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: displayedUpcoming.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 28,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFEDE9E3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.event_busy_outlined,
                                    size: 42,
                                    color: Colors.black38,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedDate == null
                                        ? 'NO UPCOMING FIXTURES'
                                        : 'NO MATCHES ON ${_formatFullDate(_selectedDate!)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: Color(0xFF1B1B1F),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'There are no fixtures scheduled on this date.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedDate = null;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFFD21E1E),
                                      ),
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text(
                                      'SHOW ALL UPCOMING FIXTURES',
                                      style: TextStyle(
                                        color: Color(0xFFD21E1E),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                for (final fixture in displayedUpcoming)
                                  _UpcomingFixtureCard(
                                    fixture: fixture,
                                    onTap: () => _openFixture(context, fixture),
                                  ),
                              ],
                            ),
                    ),
                  ] else ...[
                    if (latestResult != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _HeroLatestResultCard(
                          fixture: latestResult,
                          onViewMatch: () => _openReport(context, latestResult),
                          onHighlights: () => _openReport(
                            context,
                            latestResult,
                            playHighlights: true,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Recent Form Section (Dynamically computed from actual completed matches)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7F0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up_rounded,
                                      color: Color(0xFF059669),
                                      size: 20,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Recent form',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                                const Row(
                                  children: [
                                    Text(
                                      'Latest',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: Color(0xFF059669),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (recentForm.isEmpty)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'No completed matches recorded yet this season.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  for (
                                    int i = 0;
                                    i < recentForm.length;
                                    i++
                                  ) ...[
                                    Expanded(
                                      child: Tooltip(
                                        message: recentForm[i].tooltip,
                                        child: InkWell(
                                          key: ValueKey('recent-form-$i'),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () => _openReport(
                                            context,
                                            recentForm[i].fixture,
                                          ),
                                          child: _buildFormChip(
                                            recentForm[i].letter,
                                            recentForm[i].color,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (i < recentForm.length - 1)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Section Header: PREVIOUS RESULTS
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PREVIOUS RESULTS',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: 44,
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD21E1E),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedResultDate != null)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedResultDate = null;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'CLEAR FILTER',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Previous Results Cards List or Empty State
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: displayedResults.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 28,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFEDE9E3),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.event_busy_outlined,
                                    size: 42,
                                    color: Colors.black38,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedResultDate == null
                                        ? 'NO PREVIOUS RESULTS'
                                        : 'NO MATCHES ON ${_formatFullDate(_selectedResultDate!)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: Color(0xFF1B1B1F),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                for (final fixture in displayedResults)
                                  _PreviousResultCard(
                                    fixture: fixture,
                                    onTap: () => _openReport(context, fixture),
                                    onHighlights: () => _openReport(
                                      context,
                                      fixture,
                                      playHighlights: true,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],

                  const SizedBox(height: 36),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateCard({
    required DateTime date,
    required bool isSelected,
    required bool hasMatch,
    required VoidCallback onTap,
  }) {
    final dayNum = date.day.toString().padLeft(2, '0');
    final monthStr = _formatMonthCode(date);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD21E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFEDE9E3), width: 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFD21E1E).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayNum,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : const Color(0xFF1B1B1F),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              monthStr,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: isSelected ? Colors.white70 : const Color(0xFF6B7280),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildFormChip(String letter, Color color) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // --- Dynamic Form Calculator ---

  static List<FormMatchResult> _calculateRecentForm(List<Fixture> completed) {
    final sorted = List<Fixture>.from(completed)
      ..sort((a, b) {
        final da = _parseFixtureDate(a.date);
        final db = _parseFixtureDate(b.date);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

    final results = <FormMatchResult>[];
    for (final f in sorted) {
      if (results.length >= 5) break;
      final isHome = isNorthEastClub(f.home);
      final isAway = isNorthEastClub(f.away);

      int? neuScore;
      int? oppScore;
      String oppName = '';

      if (isHome) {
        neuScore = f.homeScore;
        oppScore = f.awayScore;
        oppName = f.away;
      } else if (isAway) {
        neuScore = f.awayScore;
        oppScore = f.homeScore;
        oppName = f.home;
      } else {
        continue;
      }

      if (neuScore != null && oppScore != null) {
        String letter = 'D';
        Color color = const Color(0xFFF59E0B);
        if (neuScore > oppScore) {
          letter = 'W';
          color = const Color(0xFF10B981);
        } else if (neuScore < oppScore) {
          letter = 'L';
          color = const Color(0xFFEF4444);
        }

        results.add(
          FormMatchResult(
            letter: letter,
            color: color,
            opponent: oppName,
            score: '$neuScore - $oppScore',
            tooltip:
                '${letter == "W"
                    ? "Won"
                    : letter == "D"
                    ? "Draw"
                    : "Lost"} $neuScore-$oppScore vs $oppName',
            fixture: f,
          ),
        );
      }
    }

    return results.reversed.toList();
  }

  // --- Date Utility Helpers ---

  static bool _isLive(Fixture fixture) =>
      fixturePhase(fixture, DateTime.now()) == FeedMatchPhase.live;

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

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

  static DateTime? _parseFixtureDateTime(String dateStr, String timeStr) {
    final d = _parseFixtureDate(dateStr);
    if (d == null) return null;
    final trimmedTime = timeStr.trim();
    if (trimmedTime.isNotEmpty) {
      final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmedTime);
      if (match24 != null) {
        final hour = int.tryParse(match24.group(1)!) ?? 19;
        final min = int.tryParse(match24.group(2)!) ?? 30;
        return DateTime(d.year, d.month, d.day, hour, min);
      }
      final match12 = RegExp(
        r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
        caseSensitive: false,
      ).firstMatch(trimmedTime);
      if (match12 != null) {
        int hour = int.tryParse(match12.group(1)!) ?? 7;
        final min = int.tryParse(match12.group(2)!) ?? 30;
        final isPm = match12.group(3)!.toUpperCase() == 'PM';
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        return DateTime(d.year, d.month, d.day, hour, min);
      }
    }
    return null;
  }

  static bool _doesFixtureMatchDate(Fixture fixture, DateTime targetDate) {
    final dt = _parseFixtureDate(fixture.date);
    if (dt != null) {
      return _isSameDay(dt, targetDate);
    }

    final dayStr = targetDate.day.toString().padLeft(2, '0');
    final monthStr = _formatMonthCode(targetDate);
    final norm = fixture.date.toUpperCase();
    return norm.contains('$dayStr $monthStr') ||
        norm.contains('${targetDate.day} $monthStr');
  }

  static String _formatMonthName(DateTime dt) {
    const fullMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return fullMonths[dt.month - 1];
  }

  static String _kickoffLabel(String time) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time.trim());
    if (match == null) {
      return time.trim().isEmpty ? 'Time to be confirmed' : time.trim();
    }
    var hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $suffix IST';
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

  static String _formatMonthCode(DateTime dt) {
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
    return months[dt.month - 1];
  }

  static String _formatFullDate(DateTime dt) {
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
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
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
      primary: Color(0xFFBA0C12),
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

/// Hero Next Match Card - delegates to HeroNextMatchCard
class _HeroNextMatchCard extends StatelessWidget {
  const _HeroNextMatchCard({
    required this.fixture,
    required this.onViewMatch,
    this.live = false,
  });

  final Fixture fixture;
  final VoidCallback onViewMatch;
  final bool live;

  @override
  Widget build(BuildContext context) => HeroNextMatchCard(
    fixture: fixture,
    onViewMatch: onViewMatch,
    live: live,
  );
}

class _LiveMark extends StatelessWidget {
  const _LiveMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('match-live-icon'),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
    decoration: BoxDecoration(
      color: const Color(0xFFEF232B),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: Colors.white, size: 7),
        SizedBox(width: 5),
        Text(
          'Live',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Team Crest Shield with club brand colors and shield aesthetic badge
class _TeamCrestShield extends StatelessWidget {
  const _TeamCrestShield({required this.teamName, this.size = 50});

  final String teamName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = getTeamColors(teamName);

    return Container(
      width: size,
      height: size * 1.08,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.primary, colors.secondary],
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(size * 0.16),
          bottom: Radius.circular(size * 0.48),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          colors.shortCode,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.23,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// Card for Upcoming Fixture matching reference design
class _UpcomingFixtureCard extends StatelessWidget {
  const _UpcomingFixtureCard({required this.fixture, required this.onTap});

  final Fixture fixture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsedDate = _MatchesScreenState._parseFixtureDate(fixture.date);
    final isHome = fixture.homeAwayLabel == 'Home';
    final isAway = fixture.homeAwayLabel == 'Away';

    final formattedTime = fixture.time.isNotEmpty
        ? (fixture.time.contains('AM') || fixture.time.contains('PM')
              ? fixture.time
              : '${fixture.time} IST')
        : 'Time to be confirmed';
    final dateDisplay = parsedDate != null
        ? '${parsedDate.day} ${_MatchesScreenState._formatMonthCode(parsedDate)} · $formattedTime'
        : (fixture.date.isNotEmpty
              ? '${fixture.date} · $formattedTime'
              : formattedTime);

    final venueText = fixture.venue.isNotEmpty
        ? fixture.venue
        : 'Venue to be confirmed';

    final badgeText = upcomingFixtureTag(fixture);
    final live = _MatchesScreenState._isLive(fixture);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE9E3), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Vertical Colored Accent Strip
              Container(
                width: 4.5,
                color: isHome
                    ? const Color(0xFFEF4444)
                    : isAway
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFE5E7EB),
              ),

              // Card Content
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Tag badge and Date
                          Row(
                            children: [
                              if (live) ...[
                                _LiveMark(
                                  key: ValueKey(
                                    'match-live-${fixture.date}-${fixture.home}-${fixture.away}',
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: badgeText.isEmpty
                                      ? const SizedBox.shrink()
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 3.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isHome
                                                ? const Color(0xFFFEE2E2)
                                                : isAway
                                                ? const Color(0xFFDBEAFE)
                                                : const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            badgeText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isHome
                                                  ? const Color(0xFFDC2626)
                                                  : isAway
                                                  ? const Color(0xFF2563EB)
                                                  : const Color(0xFF6B7280),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 12.5,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        dateDisplay,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 11,
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

                          // Middle Row: Teams Clash
                          Row(
                            children: [
                              // Home Team Logo & Name
                              buildTeamMiniShield(
                                fixture.home,
                                fixture.homeLogo,
                                size: 36,
                                background: logoDisc(
                                  fixture.homeLogoBackground,
                                  home: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fixture.home,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Color(0xFF111827),
                                    height: 1.25,
                                  ),
                                ),
                              ),

                              // VS Badge
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: FaceoffVersus(
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),

                              // Away Team Name & Logo
                              Expanded(
                                child: Text(
                                  fixture.away,
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Color(0xFF111827),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              buildTeamMiniShield(
                                fixture.away,
                                fixture.awayLogo,
                                size: 36,
                                background: logoDisc(
                                  fixture.awayLogoBackground,
                                  home: false,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Bottom Row: Location & Chevron
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    venueText,
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

/// Hero Latest Result Card - delegates to HeroLatestResultCard
class _HeroLatestResultCard extends StatelessWidget {
  const _HeroLatestResultCard({
    required this.fixture,
    required this.onViewMatch,
    required this.onHighlights,
  });

  final Fixture fixture;
  final VoidCallback onViewMatch;
  final VoidCallback onHighlights;

  @override
  Widget build(BuildContext context) => HeroLatestResultCard(
    fixture: fixture,
    onViewMatch: onViewMatch,
    onHighlights: onHighlights,
  );
}

/// Card for Previous Result matching user reference design
class _PreviousResultCard extends StatelessWidget {
  const _PreviousResultCard({
    required this.fixture,
    required this.onTap,
    required this.onHighlights,
  });

  final Fixture fixture;
  final VoidCallback onTap;
  final VoidCallback onHighlights;

  @override
  Widget build(BuildContext context) {
    final parsedDate = _MatchesScreenState._parseFixtureDate(fixture.date);
    final dateDisplay = parsedDate != null
        ? '${parsedDate.day.toString().padLeft(2, '0')} ${_MatchesScreenState._formatMonthCode(parsedDate)}'
        : fixture.date.trim();

    String cleanTime = '';
    final trimmedTime = fixture.time.trim();
    if (trimmedTime.isNotEmpty &&
        !trimmedTime.toLowerCase().contains('confirm')) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(trimmedTime);
      if (match != null) {
        var hour = int.parse(match.group(1)!);
        final minute = match.group(2)!;
        final suffix = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;
        cleanTime = '$hour:$minute $suffix';
      } else {
        cleanTime = trimmedTime;
      }
    }
    final dateAndTimeBadge = cleanTime.isNotEmpty
        ? '$dateDisplay · $cleanTime'
        : dateDisplay;

    final outcome = getMatchOutcome(fixture);
    final style = getOutcomeStyle(outcome);
    final leagueName = _extractLeagueName(fixture);
    final highlights = fixture.highlightsUrl.isNotEmpty
        ? fixture.highlightsUrl
        : fixture.videoUrl;

    final venueText = fixture.venue.isNotEmpty
        ? fixture.venue
        : 'Venue not available';

    final homeScore = fixture.homeScoreDisplay;
    final awayScore = fixture.awayScoreDisplay;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE9E3), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Strip matching outcome color (Green / Yellow / Red)
              Container(width: 5, color: style.accentStrip),

              // Card Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Date & Time Pill on Left, League Name on Right (blank if no league name)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F1FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  dateAndTimeBadge,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (leagueName.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F1EC),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFE7E1D8),
                                        ),
                                      ),
                                      child: Text(
                                        leagueName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: Color(0xFF6B6258),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: .3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Team 1 Row
                          Row(
                            children: [
                              buildTeamMiniShield(
                                fixture.home,
                                fixture.homeLogo,
                                size: 28,
                                background: logoDisc(
                                  fixture.homeLogoBackground,
                                  home: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  fixture.home,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                homeScore,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Team 2 Row
                          Row(
                            children: [
                              buildTeamMiniShield(
                                fixture.away,
                                fixture.awayLogo,
                                size: 28,
                                background: logoDisc(
                                  fixture.awayLogoBackground,
                                  home: false,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  fixture.away,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                awayScore,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Venue and Outcome Badge Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  venueText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
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
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),

                    // Divider before action links
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F0ED),
                    ),

                    // Bottom Action Links Row: Watch Highlights (Left) & Match Report -> (Right)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          // Left: Watch Highlights
                          if (highlights.isNotEmpty)
                            Expanded(
                              child: InkWell(
                                onTap: onHighlights,
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    'Watch Highlights',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const Spacer(),

                          const SizedBox(width: 8),

                          // Right: Match Report ->
                          InkWell(
                            onTap: onTap,
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Match Report',
                                    style: TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 14,
                                    color: Color(0xFF2563EB),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  static String _extractLeagueName(Fixture fixture) {
    final h = fixture.heading.trim();
    final r = fixture.round.trim();
    final combined = '$h $r'.trim();
    if (combined.isEmpty) return '';

    if (RegExp(
      r'\b(isl|indian\s+super\s+league)\b',
      caseSensitive: false,
    ).hasMatch(combined)) {
      return 'ISL';
    }
    if (RegExp(
      r'\bdurand(\s+cup)?\b',
      caseSensitive: false,
    ).hasMatch(combined)) {
      return 'Durand Cup';
    }
    if (RegExp(r'\bsuper\s+cup\b', caseSensitive: false).hasMatch(combined)) {
      return 'Super Cup';
    }
    if (RegExp(r'\bi[- ]league\b', caseSensitive: false).hasMatch(combined)) {
      return 'I-League';
    }
    if (RegExp(r'\bafc\b', caseSensitive: false).hasMatch(combined)) {
      return 'AFC';
    }

    // Only allow if it's a valid league and not a fallback or team clash string
    if (h.isNotEmpty &&
        !h.toLowerCase().contains('not available') &&
        !h.toLowerCase().contains('unknown') &&
        !RegExp(r'\bvs?\.?\s|\bversus\b', caseSensitive: false).hasMatch(h)) {
      return h;
    }

    return ''; // Blank if no verified league name
  }
}
