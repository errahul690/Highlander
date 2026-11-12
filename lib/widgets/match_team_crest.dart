import 'package:flutter/material.dart';

import '../club_identity.dart';
import 'club_crest.dart';

/// Equal crest frames, including when a team has no configured logo.
class MatchTeamCrest extends StatelessWidget {
  const MatchTeamCrest({
    super.key,
    required this.team,
    this.logo = '',
    this.size = 58,
  });

  final String team, logo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = isNorthEastClub(team)
        ? 'assets/images/club-logo.png'
        : team.toLowerCase().contains('kerala')
        ? 'assets/images/kerala-blasters-logo.png'
        : null;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE3DFE8)),
      ),
      child: logo.trim().isEmpty && asset != null
          ? Image.asset(asset, fit: BoxFit.contain)
          : ClubCrest(
              team: team,
              logo: logo.trim(),
              size: size * .8,
              disc: false,
            ),
    );
  }
}
