import 'package:flutter/material.dart';

import 'club_header.dart';

class ClubBar extends StatelessWidget implements PreferredSizeWidget {
  const ClubBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions = const [],
  });

  final String title;
  final bool showBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => Size.fromHeight(64 + (actions.isEmpty ? 0 : 44));

  @override
  Widget build(BuildContext context) {
    return ClubHeader(title: title, showBack: showBack, actions: actions);
  }
}
