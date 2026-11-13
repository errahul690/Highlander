import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/club_header.dart';
import '../widgets/club_page_body.dart';
import '../widgets/group_add_privacy_toggle.dart';

class GroupSettingsScreen extends StatelessWidget {
  const GroupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => ClubScaffold(
    backgroundColor: const Color(0xFFF7F8FA),
    appBar: const ClubHeader(title: 'Group Settings', showSearch: false),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          'Who can add me?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 8),
        Text(
          'Choose how you join new groups.',
          style: TextStyle(fontSize: 14, color: authMuted, height: 1.4),
        ),
        SizedBox(height: 20),
        GroupAddPrivacyToggle(),
        SizedBox(height: 12),
        Text(
          'When direct adds are off, you receive an invitation and choose Join or Decline. Your existing groups stay the same.',
          style: TextStyle(fontSize: 13, color: authMuted, height: 1.5),
        ),
      ],
    ),
  );
}
