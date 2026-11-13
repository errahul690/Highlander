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
  Size get preferredSize =>
      ClubHeader(title: title, actions: actions).preferredSize;

  @override
  Widget build(BuildContext context) {
    return ClubHeader(
      title: title,
      showBack: showBack,
      showLogo: !showBack,
      uppercaseTitle: !showBack,
      actions: actions,
    );
  }
}
