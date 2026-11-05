import 'package:flutter/material.dart';

import '../club_identity.dart' as club_identity;
import '../models.dart';
import 'club_crest.dart';
import 'hero_next_match_card.dart' show NightStadiumPainter;
import 'match_card_veil.dart';

/// Match outcome classification for NorthEast United FC
enum MatchOutcome { won, draw, lost, unavailable }

/// Visual styling configuration for match outcome chip
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
  final isHome = club_identity.isNorthEastClub(fixture.home);
  final isAway = club_identity.isNorthEastClub(fixture.away);

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
        label: 'RESULT',
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
    case MatchOutcome.lost:
      return const OutcomeStyle(
        label: 'LOST',
        bg: Color(0xFFFEE2E2),
        text: Color(0xFF991B1B),
        accentStrip: Color(0xFFEF4444),
      );
    case MatchOutcome.draw:
      return const OutcomeStyle(
        label: 'DRAW',
        bg: Color(0xFFFEF3C7),
        text: Color(0xFF92400E),
        accentStrip: Color(0xFFF59E0B),
      );
  }
}

/// Hero Latest Result Card matching redesign:
/// - Sleek compact height (205px)
/// - Night stadium lighting atmosphere & stadium background
/// - Football icon in the badge
/// - Bold score and outcome chip
/// - Left-aligned Date with Kickoff Time directly below it
/// - Right-aligned Location
class HeroLatestResultCard extends StatelessWidget {
  const HeroLatestResultCard({
    super.key,
    required this.fixture,
    required this.onViewMatch,
    this.onHighlights,
    this.badgeText = 'MATCH RESULT',
  });

  final Fixture fixture;
  final VoidCallback onViewMatch;
  final VoidCallback? onHighlights;
  final String badgeText;

  static DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    return DateTime.tryParse(dateStr);
  }

  static String _formatMonth(DateTime dt) {
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

  static String _kickoffTime(String timeStr) {
    if (timeStr.isEmpty) return 'Full Time';
    final trimmed = timeStr.trim();
    if (trimmed.toUpperCase().contains('AM') ||
        trimmed.toUpperCase().contains('PM')) {
      return trimmed.contains('IST') ? trimmed : '$trimmed IST';
    }
    return '$trimmed IST';
  }

  @override
  Widget build(BuildContext context) {
    final outcome = getMatchOutcome(fixture);
    final result = getOutcomeStyle(outcome);
    final parsed = _parseDate(fixture.date);
    final dateDisplay = parsed != null
        ? '${parsed.day} ${_formatMonth(parsed)}'
        : (fixture.date.isNotEmpty ? fixture.date : 'Recent Match');
    final timeDisplay = _kickoffTime(fixture.time);
    final score = '${fixture.homeScoreDisplay} - ${fixture.awayScoreDisplay}';
    final venueText = fixture.venue.isNotEmpty
        ? fixture.venue
        : 'Venue to be confirmed';

    return GestureDetector(
      onTap: onViewMatch,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: const ValueKey('last-match-hero'),
        height: 205,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E36),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x330B1930),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Stadium Background Photo with custom night atmosphere fallback
              Positioned.fill(
                child: MatchCardPhoto(
                  alignment: Alignment.topCenter,
                  fallback: CustomPaint(painter: NightStadiumPainter()),
                ),
              ),
              // Gradient veil for contrast
              const Positioned.fill(child: MatchCardVeil()),

              // Card Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Top Pill: Match badge with football icon
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D64F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sports_soccer,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Teams Clash Row: Home, Center Score/FT/Outcome, Away
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Home Team
                        Expanded(
                          child: Column(
                            children: [
                              ClubCrest(
                                team: fixture.home,
                                logo: fixture.homeLogo,
                                size: 58,
                                background: logoDisc(
                                  fixture.homeLogoBackground,
                                  home: true,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                fixture.home,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Center: Score + FT + Outcome
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    score,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const Text(
                                    'FULL TIME',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: result.bg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      result.label,
                                      style: TextStyle(
                                        color: result.text,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Away Team
                        Expanded(
                          child: Column(
                            children: [
                              ClubCrest(
                                team: fixture.away,
                                logo: fixture.awayLogo,
                                size: 58,
                                background: logoDisc(
                                  fixture.awayLogoBackground,
                                  home: false,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                fixture.away,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),
                    const SizedBox(height: 8),

                    // Bottom Row: Date on Left (Time below it) & Location on Right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Left: Date, and under Date is Time
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    dateDisplay,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    timeDisplay,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Right: Location (Right Aligned)
                        Expanded(
                          flex: 5,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  venueText,
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}
