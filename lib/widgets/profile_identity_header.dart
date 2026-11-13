import 'package:flutter/material.dart';

import '../brand_colors.dart';
import 'club_header.dart';
import 'profile_cover.dart';

/// The same cover, avatar and identity layout on personal and public profiles.
class ProfileIdentityHeader extends StatelessWidget {
  const ProfileIdentityHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.cover,
    required this.avatarBuilder,
    this.actions,
    this.coverKey,
    this.onCoverEdit,
    this.coverBusy = false,
  });

  final String name, subtitle, cover;
  final Widget Function(double radius) avatarBuilder;
  final Widget? actions;
  final Key? coverKey;
  final VoidCallback? onCoverEdit;
  final bool coverBusy;

  @override
  Widget build(BuildContext context) {
    final headerHeight =
        MediaQuery.paddingOf(context).top +
        const ClubHeader(title: 'Profile').preferredSize.height;
    // The curved header artwork has a transparent lower edge. Start the
    // cover behind that edge, including the taller iOS status-bar area.
    final coverTop = headerHeight * .68;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: coverTop + 194,
          child: Stack(
            children: [
              Positioned(
                top: coverTop,
                left: 0,
                right: 0,
                height: 140,
                child: ProfileCover(
                  key: coverKey,
                  source: cover,
                  allowViewing: true,
                  onEdit: onCoverEdit,
                  busy: coverBusy,
                ),
              ),
              Positioned(
                top: coverTop + 128,
                left: 0,
                right: 0,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFF7F6FB),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: coverTop + 110,
                left: 18,
                child: Container(
                  key: const ValueKey('profile-avatar-frame'),
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: avatarBuilder(22),
                ),
              ),
              Positioned(
                top: coverTop + 134,
                left: 82,
                right: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              color: Color(0xFF171717),
                            ),
                          ),
                          if (subtitle.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF737584),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (actions != null) ...[
                      const SizedBox(width: 8),
                      actions!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileStatsBar extends StatelessWidget {
  const ProfileStatsBar({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelect,
    this.keyPrefix,
  });
  final Map<String, String> counts;
  final String selected;
  final ValueChanged<String> onSelect;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x160F172A),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          for (final section in ['posts', 'followers', 'following']) ...[
            if (section != 'posts')
              const SizedBox(
                height: 36,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE7E4DE),
                ),
              ),
            Expanded(
              child: Material(
                color: selected == section
                    ? const Color(0xFFFCEEF3)
                    : Colors.white,
                child: InkWell(
                  key: keyPrefix == null
                      ? null
                      : ValueKey('$keyPrefix-$section'),
                  onTap: () => onSelect(section),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 9,
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/icons/profile-$section.png',
                          width: 18,
                          height: 18,
                          color: selected == section
                              ? brandAccent
                              : const Color(0xFF737584),
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          counts[section] ?? '0',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: selected == section
                                ? brandAccent
                                : const Color(0xFF1E2229),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          section == 'posts'
                              ? 'Posts'
                              : section == 'followers'
                              ? 'Followers'
                              : 'Following',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected == section
                                ? brandAccent
                                : const Color(0xFF737584),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
