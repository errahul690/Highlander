import 'package:flutter/material.dart';

import '../club_repository.dart';
import 'team_logo_entrance.dart';

class ClubCrest extends StatelessWidget {
  const ClubCrest({
    super.key,
    required this.team,
    this.logo = '',
    this.size = 44,
    this.color = Colors.white,
    this.background = homeBackground,
    this.enterFromLeft,
  });

  /// Same discs as the feed result logos, so a white badge still shows.
  static const homeBackground = Color(0xFFF7E3E5);
  static const awayBackground = Color(0xFFDEDFEF);

  final String team, logo;
  final double size;
  final Color color;
  final Color background;
  final bool? enterFromLeft;

  Widget _disc(Widget child) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * .1),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: child,
  );

  Widget _initials() {
    final words = team
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && word.toLowerCase() != 'fc')
        .toList();
    final letters =
        (words.isEmpty ? team : words.take(2).map((word) => word[0]).join())
            .toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _badgeColor(team),
        shape: BoxShape.circle,
      ),
      child: Text(
        letters.isEmpty ? '?' : letters,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * (letters.length > 2 ? 0.22 : 0.32),
        ),
      ),
    );
  }

  Color _badgeColor(String name) {
    final value = name.toLowerCase();
    if (value.contains('goa')) return const Color(0xFFEA5B1D);
    if (value.contains('punjab')) return const Color(0xFFE25C1D);
    if (value.contains('mohun')) return const Color(0xFF006633);
    if (value.contains('bengaluru')) return const Color(0xFF0B4EA2);
    if (value.contains('odisha')) return const Color(0xFF5A2582);
    if (value.contains('east bengal')) return const Color(0xFFD9242C);
    if (value.contains('delhi')) return const Color(0xFF8B0000);
    if (value.contains('churchill')) return const Color(0xFF1B4F72);
    return const Color(0xFF1F2937);
  }

  @override
  Widget build(BuildContext context) {
    final crest = _crest();
    return enterFromLeft == null
        ? crest
        : TeamLogoEntrance(
            key: ValueKey('$team:$logo:$enterFromLeft'),
            fromLeft: enterFromLeft!,
            child: crest,
          );
  }

  Widget _crest() {
    if (logo.isEmpty) return _initials();
    return _disc(
      Image.network(
        ClubRepository.mediaUrl(logo),
        width: size * .8,
        height: size * .8,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => FittedBox(child: _initials()),
      ),
    );
  }
}

/// Admin team color when it is a hex value, otherwise the feed disc.
Color logoDisc(String hex, {required bool home}) {
  final raw = hex.trim().replaceFirst('#', '');
  final expanded = raw.length == 3
      ? raw.split('').map((char) => '$char$char').join()
      : raw;
  final value = int.tryParse(expanded, radix: 16);
  if (expanded.length == 6 && value != null) return Color(0xFF000000 | value);
  return home ? ClubCrest.homeBackground : ClubCrest.awayBackground;
}
