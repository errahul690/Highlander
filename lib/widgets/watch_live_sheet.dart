import 'team_logo_entrance.dart';

import 'package:flutter/material.dart';

import '../models.dart';
import '../club_identity.dart';
import '../screens/live_match_screen.dart';
import '../theme.dart';
import 'club_crest.dart';

Future<void> showWatchLiveSheet(BuildContext context, Fixture fixture) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x99060B12),
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: WatchLiveCard(fixture: fixture),
    ),
  );
}

class WatchLiveCard extends StatelessWidget {
  const WatchLiveCard({super.key, required this.fixture});
  final Fixture fixture;

  String get _league {
    final heading = fixture.heading.trim();
    if (heading.isEmpty) return '';
    final lower = heading.toLowerCase();
    final home = fixture.home.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final away = fixture.away.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final isFixtureTitle =
        RegExp(r'\bvs\.?\b', caseSensitive: false).hasMatch(heading) &&
        home.isNotEmpty &&
        away.isNotEmpty &&
        lower.contains(home) &&
        lower.contains(away);
    return isFixtureTitle ? '' : heading;
  }

  String get _when {
    final parsed = DateTime.tryParse(fixture.date.trim());
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
    final date = parsed == null
        ? (fixture.date.trim().isEmpty ? 'Date to be confirmed' : fixture.date)
        : '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
    final time = fixture.time.trim();
    return time.isEmpty ? date : '$date · $time IST';
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(child: _details(context)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('watch-live-open'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LiveMatchScreen(fixture: fixture),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: clubRed,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: clubFontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Watch live'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Opens on the streaming platform',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9AA3B2), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: clubRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 7),
                  SizedBox(width: 6),
                  Text(
                    'LIVE NOW',
                    style: TextStyle(
                      fontFamily: clubFontFamily,
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F2F4),
              ),
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Close',
            ),
          ],
        ),
        const Text(
          'Watch live',
          style: TextStyle(
            fontFamily: clubFontFamily,
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF14161C),
          ),
        ),
        if (_league.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _league,
            style: const TextStyle(
              fontFamily: clubFontFamily,
              fontSize: 16,
              height: 1.2,
              color: Color(0xFF8B93A2),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 325 / 171,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF070709)),
                Image.asset(
                  'assets/images/watch_live_card_bg.png',
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  child: Column(
                    children: [
                      const Text(
                        '—  MATCHDAY  —',
                        style: TextStyle(
                          fontFamily: clubFontFamily,
                          color: Color(0xFFB7BDC8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.4,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: MatchFaceoffMotion(
                          attackRight:
                              isNorthEastClub(fixture.home) ||
                              !isNorthEastClub(fixture.away),
                          child: Row(
                            children: [
                              Expanded(
                                child: _Side(
                                  name: fixture.home,
                                  logo: fixture.homeLogo,
                                  enterFromLeft: true,
                                  background: logoDisc(
                                    fixture.homeLogoBackground,
                                    home: true,
                                  ),
                                ),
                              ),
                              const _Versus(),
                              Expanded(
                                child: _Side(
                                  name: fixture.away,
                                  logo: fixture.awayLogo,
                                  enterFromLeft: false,
                                  background: logoDisc(
                                    fixture.awayLogoBackground,
                                    home: false,
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Fact(icon: Icons.calendar_today_outlined, label: 'Date', value: _when),
        const Divider(height: 1, color: Color(0xFFE7E9EE)),
        _Fact(
          icon: Icons.location_on_outlined,
          label: 'Venue',
          value: fixture.venue.trim().isEmpty
              ? 'Venue to be confirmed'
              : fixture.venue.trim(),
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.name,
    required this.logo,
    this.background = ClubCrest.homeBackground,
    required this.enterFromLeft,
  });
  final String name, logo;
  final Color background;
  final bool enterFromLeft;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ClubCrest(
            team: name,
            enterFromLeft: enterFromLeft,
            logo: logo,
            size: 72,
            background: background,
          ),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 32,
        child: Text(
          _twoLines(name),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: clubFontFamily,
            color: Colors.white,
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

String _twoLines(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.length < 2) return name.trim();
  return '${words.first}\n${words.skip(1).join(' ')}';
}

class _Versus extends StatelessWidget {
  const _Versus();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: FaceoffVersus(style: TextStyle(fontFamily: clubFontFamily)),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: clubFontFamily,
                  color: Color(0xFF9AA3B2),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: clubFontFamily,
                  color: Color(0xFF1C1F26),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
