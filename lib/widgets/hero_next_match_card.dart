import 'package:flutter/material.dart';

import '../models.dart';
import 'club_crest.dart';
import 'match_card_veil.dart';
import 'team_logo_entrance.dart';

/// Top featured Hero Card for upcoming match:
/// - Sleek height (~205px)
/// - Night stadium lighting atmosphere & stadium background
/// - Football icon
/// - Left-aligned Date with Kickoff Time directly below it
/// - Right-aligned Location
class HeroNextMatchCard extends StatelessWidget {
  const HeroNextMatchCard({
    super.key,
    required this.fixture,
    required this.onViewMatch,
    this.badgeText = 'NEXT MATCH',
    this.live = false,
  });

  final Fixture fixture;
  final VoidCallback onViewMatch;
  final String badgeText;
  final bool live;

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
    if (timeStr.isEmpty) return '';
    final trimmed = timeStr.trim();
    if (trimmed.toUpperCase().contains('AM') ||
        trimmed.toUpperCase().contains('PM')) {
      return trimmed.contains('IST') ? trimmed : '$trimmed IST';
    }
    return '$trimmed IST';
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parseDate(fixture.date);
    final dateDisplay = parsed != null
        ? '${parsed.day} ${_formatMonth(parsed)}'
        : (fixture.date.isNotEmpty ? fixture.date : 'Date TBD');
    final formattedTime = _kickoffTime(fixture.time);
    final venueText = fixture.venue.isNotEmpty
        ? fixture.venue
        : 'Venue to be confirmed';

    return GestureDetector(
      onTap: onViewMatch,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: const ValueKey('next-match-hero'),
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
                        color: live
                            ? const Color(0xFFEF232B)
                            : const Color(0xFF1D64F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            live ? Icons.circle : Icons.sports_soccer,
                            size: live ? 7 : 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            live ? 'Live' : badgeText,
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

                    // Teams and the static matchup badge.
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

                        // Center football & VS
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sports_soccer,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 2),
                                const FaceoffVersus(
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
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
                                    formattedTime,
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

/// Stadium night sky atmosphere painter with corner spotlights
class NightStadiumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Deep midnight blue gradient background
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F274E), Color(0xFF0B1B36), Color(0xFF061021)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Left floodlight glow
    final leftGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.75),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.38),
          const Color(0xFF38BDF8).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), leftGlow);

    // Right floodlight glow
    final rightGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, -0.75),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.38),
          const Color(0xFF38BDF8).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), rightGlow);

    // Stadium stand arches
    final standPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 3; i++) {
      final y = size.height * 0.32 + (i * 20);
      final path = Path()
        ..moveTo(0, y - 8)
        ..quadraticBezierTo(size.width * 0.5, y + 16, size.width, y - 8);
      canvas.drawPath(path, standPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
