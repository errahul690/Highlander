import '../brand_colors.dart';
import 'package:flutter/material.dart';

import '../club_identity.dart' show isNorthEastClub;
import '../models.dart';
import 'club_crest.dart';

class FeedMatchReportCard extends StatelessWidget {
  const FeedMatchReportCard({
    super.key,
    required this.fixture,
    required this.background,
    required this.onReadReport,
    required this.onViewAll,
  });

  final Fixture fixture;
  final Widget background;
  final VoidCallback onReadReport, onViewAll;
  static const accent = brandAccent;

  String _stat(List<String> labels, {bool percent = false}) {
    final stat = fixture.details.stats
        .where((stat) => labels.contains(stat.label.trim().toLowerCase()))
        .firstOrNull;
    if (stat == null) return '\u2014';
    final value = (isNorthEastClub(fixture.away) ? stat.away : stat.home)
        .trim();
    if (value.isEmpty) return '\u2014';
    return percent && !value.endsWith('%') ? '$value%' : value;
  }

  Widget _team(String name, String logo, String logoBackground, bool home) =>
      Expanded(
        child: Column(
          children: [
            ClubCrest(
              team: name,
              logo: logo,
              size: 50,
              background: logoDisc(logoBackground, home: home),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _metric(IconData icon, String value, String label) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: accent, size: 21),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF505361)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('feed-match-report'),
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Match Report',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'From our last match',
                    style: TextStyle(fontSize: 12, color: Color(0xFF505361)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View All', style: TextStyle(color: accent)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 17, color: accent),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(child: background),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22FFFFFF),
                          Color(0xDFFFFFFF),
                          Color(0x44FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Color(0xFF191919)),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _team(
                              fixture.home,
                              fixture.homeLogo,
                              fixture.homeLogoBackground,
                              true,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF39782F),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Full Time',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${fixture.homeScoreDisplay} \u2013 ${fixture.awayScoreDisplay}',
                                      style: const TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _team(
                              fixture.away,
                              fixture.awayLogo,
                              fixture.awayLogoBackground,
                              false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0x22808080)),
                        const SizedBox(height: 10),
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              _metric(
                                Icons.sports_soccer,
                                _stat(['shots', 'total shots', 'shots total']),
                                'Shots',
                              ),
                              const VerticalDivider(
                                width: 1,
                                color: Color(0x22808080),
                              ),
                              _metric(
                                Icons.gps_fixed,
                                _stat([
                                  'shots on target',
                                  'on target',
                                  'shots on goal',
                                  'on target shots',
                                  'on target shot',
                                ]),
                                'On Target',
                              ),
                              const VerticalDivider(
                                width: 1,
                                color: Color(0x22808080),
                              ),
                              _metric(
                                Icons.sports_soccer_outlined,
                                _stat([
                                  'possession',
                                  'ball possession',
                                  'possession %',
                                ], percent: true),
                                'Possession',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: onReadReport,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Read Match Report',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
