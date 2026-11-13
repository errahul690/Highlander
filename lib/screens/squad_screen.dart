import 'package:flutter/material.dart';

import '../club_repository.dart';
import '../models.dart';
import '../widgets/club_bar.dart';
import '../widgets/club_page_body.dart';
import '../widgets/squad_showcase.dart';
import '../widgets/squad_load_state.dart';

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});
  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  late Future<ClubContent> _content;
  @override
  void initState() {
    super.initState();
    _content = ClubRepository.instance.load();
  }

  Future<void> _refresh() async {
    final future = ClubRepository.instance.load(forceRefresh: true);
    setState(() {
      _content = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) => ClubScaffold(
    backgroundColor: Colors.white,
    appBar: const ClubBar(title: 'The Squad', showBack: true),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ClubContent>(
        future: _content,
        initialData: ClubRepository.instance.cachedOrNull,
        builder: (_, snapshot) {
          final content = snapshot.data;
          if (content == null || content.players.isEmpty) {
            return SquadLoadState(
              onRefresh: _refresh,
              loading:
                  content == null &&
                  snapshot.connectionState != ConnectionState.done,
              unavailable:
                  snapshot.hasError || content?.playersUnavailable == true,
            );
          }
          return SquadShowcase(players: content.players);
        },
      ),
    ),
  );
}
