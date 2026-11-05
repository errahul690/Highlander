import 'package:flutter/material.dart';

import '../club_repository.dart';
import '../models.dart';
import '../widgets/club_bar.dart';
import '../widgets/club_page_body.dart';
import '../widgets/squad_showcase.dart';

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
    setState(() => _content = future);
    await future;
  }

  @override
  Widget build(BuildContext context) => ClubScaffold(
    backgroundColor: Colors.white,
    appBar: const ClubBar(title: 'The Squad'),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ClubContent>(
        future: _content,
        initialData: ClubRepository.instance.cachedContent,
        builder: (_, snapshot) => SquadShowcase(
          players:
              (snapshot.data ?? ClubRepository.instance.cachedContent).players,
        ),
      ),
    ),
  );
}
