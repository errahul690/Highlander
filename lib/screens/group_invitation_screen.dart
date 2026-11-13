import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/group_invitation_actions.dart';

class GroupInvitationScreen extends StatelessWidget {
  const GroupInvitationScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });
  final String groupId, groupName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubHeader(title: 'Group Invitation', showSearch: false),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            groupName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          GroupInvitationActions(groupId: groupId, groupName: groupName),
        ],
      ),
    ),
  );
}
