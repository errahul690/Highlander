import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import '../club_repository.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/club_bar.dart';
import 'player_screen.dart';

const _filters = [
  'ALL',
  'GOALKEEPER',
  'DEFENDER',
  'MIDFIELDER',
  'FORWARD',
  'COACH',
];

class FullSquadScreen extends StatefulWidget {
  const FullSquadScreen({super.key});

  @override
  State<FullSquadScreen> createState() => _FullSquadScreenState();
}

class _FullSquadScreenState extends State<FullSquadScreen> {
  String _filter = 'ALL';
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClubScaffold(
      backgroundColor: Colors.white,
      appBar: const ClubBar(title: 'Full Squad'),
      body: FutureBuilder<ClubContent>(
        initialData: ClubRepository.instance.cachedContent,
        future: ClubRepository.instance.load(),
        builder: (context, snapshot) {
          final allPlayers =
              (snapshot.data ?? ClubRepository.instance.cachedContent).players;
          final players = allPlayers.where((player) {
            final matchesFilter = _filter == 'ALL' || player.group == _filter;
            final matchesQuery =
                _query.isEmpty ||
                player.name.toLowerCase().contains(_query.toLowerCase()) ||
                player.position.toLowerCase().contains(_query.toLowerCase()) ||
                player.jerseyLabel.toLowerCase().contains(_query.toLowerCase());
            return matchesFilter && matchesQuery;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input Box
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _query = val),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.black45,
                        size: 20,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 18,
                                color: Colors.black45,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      hintText: 'Search Players',
                      hintStyle: const TextStyle(
                        color: Colors.black38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ),

              // Horizontal Filter Chips
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _filters[index];
                    final isSelected = _filter == cat;
                    return InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: () => setState(() => _filter = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? clubRed : Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: isSelected
                                ? clubRed
                                : const Color(0xFFE4E2DC),
                            width: 1.1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: clubRed.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF222222),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Player Count Header with short accent line
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${players.length} PLAYERS',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                        color: Color(0xFF1B1B1F),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: clubRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Players List
              Expanded(
                child: players.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 52,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No players found',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final player = players[index];
                          return _FullSquadPlayerCard(player: player);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FullSquadPlayerCard extends StatelessWidget {
  const _FullSquadPlayerCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEAE4), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlayerScreen(player: player)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Player Avatar or Jersey Number Badge
                _buildPlayerThumbnail(),

                const SizedBox(width: 14),

                // Player Details (Name, Position & Nationality)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        player.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.3,
                          color: Color(0xFF1B1B1F),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${player.position.toUpperCase()} · ${player.nationality}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.2,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Jersey Number
                Text(
                  player.jerseyLabel,
                  style: const TextStyle(
                    color: clubRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing chevron
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerThumbnail() {
    // If player has a photo
    if (player.image.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF2F0EC),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            player.image,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: 100,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return child;
              }
              return _buildFallbackNumberBox();
            },
            errorBuilder: (_, _, _) => _buildFallbackNumberBox(),
          ),
        ),
      );
    }

    return _buildFallbackNumberBox();
  }

  Widget _buildFallbackNumberBox() {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5D6D4), width: 1),
      ),
      child: Text(
        player.jerseyBadge,
        style: const TextStyle(
          color: clubRed,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}
