import 'package:flutter/material.dart';

import '../models.dart';
import 'club_crest.dart';
import 'match_card_veil.dart';

/// Full-time summary laid out in the proportions of the supplied 756 × 372 design.
class MatchScoreSummary extends StatelessWidget {
  const MatchScoreSummary({
    super.key,
    required this.fixture,
    required this.resultLabel,
    required this.resultBackground,
    required this.resultForeground,
  });

  final Fixture fixture;
  final String resultLabel;
  final Color resultBackground, resultForeground;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(fixture.date);
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
    final dateLabel = date == null
        ? fixture.date
        : '${date.day} ${months[date.month - 1]}';
    final competition = fixture.heading.trim().isNotEmpty
        ? fixture.heading.trim()
        : fixture.round == 'Other'
        ? ''
        : fixture.round.trim();
    final metadata = [
      dateLabel,
      competition,
      fixture.venue.trim(),
    ].where((text) => text.isNotEmpty).join(' · ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 756;
        return ClipRRect(
          borderRadius: BorderRadius.circular(22 * scale),
          child: AspectRatio(
            aspectRatio: 756 / 372,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const MatchCardPhoto(),
                const MatchCardVeil(solid: true),
                Positioned(
                  left: 70 * scale,
                  top: 36 * scale,
                  width: 180 * scale,
                  child: _SummaryTeam(
                    name: fixture.home,
                    logo: fixture.homeLogo,
                    scale: scale,
                    background: logoDisc(
                      fixture.homeLogoBackground,
                      home: true,
                    ),
                  ),
                ),
                Positioned(
                  right: 80 * scale,
                  top: 36 * scale,
                  width: 180 * scale,
                  child: _SummaryTeam(
                    name: fixture.away,
                    logo: fixture.awayLogo,
                    scale: scale,
                    background: logoDisc(
                      fixture.awayLogoBackground,
                      home: false,
                    ),
                  ),
                ),
                Positioned(
                  left: 270 * scale,
                  right: 270 * scale,
                  top: 48 * scale,
                  height: 88 * scale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${fixture.homeScoreDisplay} - ${fixture.awayScoreDisplay}',
                      key: const ValueKey('summary-score'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 80 * scale,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 316 * scale,
                  top: 156 * scale,
                  width: 128 * scale,
                  height: 40 * scale,
                  child: DecoratedBox(
                    key: const ValueKey('summary-result'),
                    decoration: BoxDecoration(
                      color: resultBackground,
                      borderRadius: BorderRadius.circular(24 * scale),
                    ),
                    child: Center(
                      child: Text(
                        resultLabel,
                        style: TextStyle(
                          color: resultForeground,
                          fontSize: 20 * scale,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 30 * scale,
                  right: 30 * scale,
                  bottom: 42 * scale,
                  child: Text(
                    metadata,
                    key: const ValueKey('summary-metadata'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20 * scale,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryTeam extends StatelessWidget {
  const _SummaryTeam({
    required this.name,
    required this.logo,
    required this.scale,
    this.background = ClubCrest.homeBackground,
  });
  final String name, logo;
  final double scale;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final kerala = [
      'keralablasters',
      'keralablastersfc',
      'kbfc',
    ].contains(normalized);
    final northEast = [
      'northeastunited',
      'northeastunitedfc',
      'northeastutd',
      'neufc',
    ].contains(normalized);
    final displayName = northEast
        ? 'NorthEast\nUnited FC'
        : kerala
        ? 'Kerala\nBlasters'
        : name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: ValueKey('report-team-logo-$name'),
          width: 148 * scale,
          height: 148 * scale,
          child: kerala
              ? Center(
                  child: SizedBox(
                    width: 124 * scale,
                    height: 148 * scale,
                    child: ColoredBox(
                      color: const Color(0xFF103573),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFFFE21D),
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/images/kerala-blasters-logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                )
              : ClubCrest(
                  team: name,
                  logo: logo,
                  size: 148 * scale,
                  background: background,
                ),
        ),
        SizedBox(height: 14 * scale),
        Text(
          displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 32 * scale,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
