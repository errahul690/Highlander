import '../widgets/club_page_body.dart';
import 'package:flutter/material.dart';

import '../widgets/app_feed_poll.dart';
import '../widgets/club_bar.dart';

class PollsScreen extends StatelessWidget {
  const PollsScreen({super.key, this.pollId});
  final String? pollId;

  @override
  Widget build(BuildContext context) => ClubScaffold(
    appBar: const ClubBar(title: 'Fan Polls'),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AppFeedPoll(initialPollId: pollId),
    ),
  );
}
