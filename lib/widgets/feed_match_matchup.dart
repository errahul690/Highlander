import 'package:flutter/material.dart';

import '../models.dart';
import 'club_crest.dart';

/// Shared by the feed's Upcoming, Before Kick-Off and Report cards.
class FeedMatchMatchup extends StatelessWidget {
  const FeedMatchMatchup({super.key, required this.fixture, this.onTap});
  final Fixture fixture;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ClubCrest(
              team: fixture.home,
              logo: fixture.homeLogo,
              size: 44,
              background: logoDisc(fixture.homeLogoBackground, home: true),
            ),
            Text(
              fixture.played ? fixture.score : 'VS',
              style: const TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF15263C),
              ),
            ),
            ClubCrest(
              team: fixture.away,
              logo: fixture.awayLogo,
              size: 44,
              background: logoDisc(fixture.awayLogoBackground, home: false),
            ),
          ],
        ),
      ),
    ),
  );
}
