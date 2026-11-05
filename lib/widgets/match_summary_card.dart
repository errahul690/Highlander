import 'package:flutter/material.dart';

import '../models.dart';
import 'club_crest.dart';
import 'match_card_veil.dart';
import 'match_stadium_painter.dart';

/// One layout for fixtures and results, in featured and list sizes.
class MatchSummaryCard extends StatelessWidget {
  const MatchSummaryCard({
    super.key,
    required this.fixture,
    required this.onTap,
    required this.label,
    required this.metadata,
    this.featured = false,
    this.cardKey,
    this.score,
    this.outcome = '',
    this.outcomeColor = const Color(0xFF6B7280),
    this.outcomeBackground = const Color(0xFFF3F4F6),
    this.onHighlights,
  });

  final Fixture fixture;
  final VoidCallback onTap;
  final String label, metadata, outcome;
  final bool featured;
  final Key? cardKey;
  final String? score;
  final Color outcomeColor, outcomeBackground;
  final VoidCallback? onHighlights;

  Color get _ink => featured ? Colors.white : const Color(0xFF15263C);
  Color get _muted => featured ? Colors.white70 : const Color(0xFF748397);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(featured ? 22 : 18);
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: featured ? 20 : 28,
            child: featured
                ? Row(
                    children: [
                      const SizedBox(width: 60),
                      Expanded(
                        child: Center(
                          child: _chip(
                            label,
                            const Color(0xFF1D64F2),
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 60, child: _highlights()),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          metadata,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_hasHighlights) ...[
                        const SizedBox(width: 6),
                        _highlights(),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: featured ? 102 : 78,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _team(
                    fixture.home,
                    fixture.homeLogo,
                    fixture.homeLogoBackground,
                    true,
                  ),
                ),
                SizedBox(width: featured ? 70 : 68, child: _matchStatus()),
                Expanded(
                  child: _team(
                    fixture.away,
                    fixture.awayLogo,
                    fixture.awayLogoBackground,
                    false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            color: featured ? Colors.white24 : const Color(0xFFE7E9ED),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: featured
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          metadata,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 10,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: _venue()),
                    ],
                  )
                : _venue(),
          ),
        ],
      ),
    );
    return Container(
      key: cardKey,
      margin: featured ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: featured ? const Color(0xFF0F1E36) : Colors.white,
        borderRadius: radius,
        border: featured ? null : Border.all(color: const Color(0xFFEDE9E3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B1930),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                if (featured) ...[
                  Positioned.fill(
                    child: MatchCardPhoto(
                      alignment: Alignment.topCenter,
                      fallback: CustomPaint(painter: NightStadiumPainter()),
                    ),
                  ),
                  const Positioned.fill(child: MatchCardVeil()),
                ],
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _team(String name, String logo, String background, bool home) =>
      Column(
        children: [
          ClubCrest(
            team: name,
            logo: logo,
            size: featured ? 68 : 44,
            background: logoDisc(background, home: home),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: Text(
              name.replaceFirst(RegExp(r' FC$'), '\u00a0FC'),
              semanticsLabel: name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );

  Widget _matchStatus() => Column(
    children: [
      SizedBox(
        height: featured ? 68 : 44,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              score ?? 'VS',
              style: TextStyle(
                color: _ink,
                fontSize: featured ? 26 : 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 30,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              score == null ? 'KICK-OFF' : 'FULL TIME',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _muted,
                fontSize: 7.5,
                letterSpacing: .5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (outcome.isNotEmpty) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _chip(outcome, outcomeBackground, outcomeColor),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _chip(String text, Color background, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
    ),
  );

  bool get _hasHighlights =>
      onHighlights != null &&
      (fixture.highlightsUrl.isNotEmpty || fixture.videoUrl.isNotEmpty);

  Widget _highlights() => !_hasHighlights
      ? const SizedBox.shrink()
      : GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onHighlights,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline, size: 10, color: _ink),
                  const SizedBox(width: 2),
                  Text(
                    'Highlights',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

  Widget _venue() => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Icon(Icons.location_on_outlined, size: 12, color: _muted),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          fixture.venue.trim().isEmpty
              ? (score == null
                    ? 'Venue to be confirmed'
                    : 'Venue not available')
              : fixture.venue,
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _ink,
            fontSize: 10,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      if (!featured) ...[
        const SizedBox(width: 5),
        Icon(Icons.chevron_right, size: 16, color: _muted),
      ],
    ],
  );
}
