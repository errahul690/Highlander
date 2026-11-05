import 'package:flutter/material.dart';

import '../chat_updates.dart';
import 'unread_chat_badge.dart';

import '../screens/shell.dart';
import '../theme.dart';
import 'community_icons.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    this.selectedIndex = -1,
    this.onSelect,
  });
  final int selectedIndex;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final onFeed = selectedIndex == 2;
    void onSelected(int index) {
      if (onSelect != null) {
        onSelect!(index);
      } else {
        AppShell.openTab(context, index);
      }
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(44),
          border: Border.all(color: const Color(0xFFE9E9E9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x15000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _destination(context, 0, 'Friends', Icons.people_outline),
            _destination(
              context,
              1,
              'Huddles',
              Icons.groups_outlined,
              image: CommunityIcons.circles,
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: onFeed ? 'Create a post' : 'Open Feed',
                child: GestureDetector(
                  key: const ValueKey('feed-post-action'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: authRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x30C92B20),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              onFeed
                                  ? Icons.edit_note_outlined
                                  : Icons.article_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            Text(
                              onFeed ? 'Post' : 'Feed',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _destination(context, 3, 'Explore', Icons.explore_outlined),
            _destination(context, 4, 'Profile', Icons.person_outline),
          ],
        ),
      ),
    );
  }

  Widget _destination(
    BuildContext context,
    int index,
    String label,
    IconData icon, {
    ImageProvider? image,
  }) => Expanded(
    child: Semantics(
      button: true,
      selected: selectedIndex == index,
      child: GestureDetector(
        key: ValueKey('nav-${label.toLowerCase()}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect != null
            ? onSelect!(index)
            : AppShell.openTab(context, index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index == 1)
                ValueListenableBuilder<int>(
                  valueListenable: ChatUpdates.instance.unreadCount,
                  builder: (_, count, __) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ImageIcon(
                        image!,
                        color: selectedIndex == index
                            ? authRed
                            : const Color(0xFF747474),
                        size: 20,
                      ),
                      if (count > 0)
                        Positioned(
                          right: -17,
                          top: -10,
                          child: UnreadChatBadge(count: count),
                        ),
                    ],
                  ),
                )
              else if (image != null)
                ImageIcon(
                  image,
                  color: selectedIndex == index
                      ? authRed
                      : const Color(0xFF747474),
                  size: 20,
                )
              else
                Icon(
                  icon,
                  color: selectedIndex == index
                      ? authRed
                      : const Color(0xFF747474),
                  size: 20,
                ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: selectedIndex == index
                      ? authRed
                      : const Color(0xFF505050),
                  fontSize: 11.5,
                  fontWeight: selectedIndex == index
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
