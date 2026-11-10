import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/club_bar.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final image = player.image.isNotEmpty ? player.image : player.frontImage;
    const placeholder = Center(
      child: Icon(Icons.person, color: Colors.black38, size: 72),
    );

    return ClubScaffold(
      backgroundColor: Colors.white,
      appBar: ClubBar(title: player.name),
      body: ListView(
        children: [
          Container(
            height: 320,
            color: const Color(0xFFF2F0EC),
            child: image.isEmpty
                ? placeholder
                : Image.network(
                    image,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    width: double.infinity,
                    semanticLabel: player.name,
                    errorBuilder: (_, _, _) => placeholder,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.jerseyBadge,
                  style: const TextStyle(
                    color: clubRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  player.position,
                  style: const TextStyle(color: Colors.black54, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  player.quote.isEmpty
                      ? 'One of the Highlanders. Eight states, one badge.'
                      : player.quote,
                  style: const TextStyle(height: 1.45, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
