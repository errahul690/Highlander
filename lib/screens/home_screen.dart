import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import '../club_repository.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/club_bar.dart';
import 'alerts_screen.dart';
import 'match_detail_screen.dart';
import 'matches_screen.dart';
import 'squad_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ClubScaffold(
      backgroundColor: clubCloud,
      appBar: ClubBar(
        title: 'Highlanders',
        showBack: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _open(context, const SquadScreen()),
          ),
        ],
      ),
      body: FutureBuilder<ClubContent>(
        future: ClubRepository.instance.load(),
        builder: (context, snapshot) {
          final content = snapshot.data ?? clubFallback;
          final upcoming = content.fixtures.where((fixture) => !fixture.played);
          final next = upcoming.isNotEmpty
              ? upcoming.first
              : (content.fixtures.isEmpty ? null : content.fixtures.first);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                '8 STATES · 1 UNITED',
                style: TextStyle(
                  color: clubRed,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The hills have a heartbeat.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              if (next != null) _MatchCard(fixture: next),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Shortcut(
                    label: 'Squad',
                    icon: Icons.groups,
                    onTap: () => _open(context, const SquadScreen()),
                  ),
                  const SizedBox(width: 10),
                  _Shortcut(
                    label: 'Matches',
                    icon: Icons.sports_soccer,
                    onTap: () => _open(context, const MatchesScreen()),
                  ),
                  const SizedBox(width: 10),
                  _Shortcut(
                    label: 'Alerts',
                    icon: Icons.campaign_outlined,
                    onTap: () => _open(context, const AlertsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'LATEST',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              for (final story in content.stories)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: clubLine),
                  ),
                  child: ListTile(
                    title: Text(
                      story.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(story.category),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.fixture});

  final Fixture fixture;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: clubInk,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(fixture: fixture),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fixture.round.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFF8A87),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${fixture.home}\nvs ${fixture.away}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${fixture.date}  ·  ${fixture.time}\n${fixture.venue}',
                style: const TextStyle(color: Color(0xFFD5D3CE), height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: clubLine),
            ),
            child: Column(
              children: [
                Icon(icon, color: clubRed),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
