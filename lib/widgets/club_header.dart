import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/alerts_screen.dart';
import '../screens/search_screen.dart';
import 'customer_support_button.dart';
import 'header_action_icon.dart';

/// The same club branding, navigation and live profile photo on every page.
class ClubHeader extends StatelessWidget implements PreferredSizeWidget {
  const ClubHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.backKey,
    this.embedded = false,
    this.showNotifications = true,
    this.showProfile = true,
    this.showLogo = true,
    this.actions = const [],
    this.trailing = const [],
  });

  final String title;
  final String? subtitle;
  final bool showBack, embedded, showNotifications, showProfile, showLogo;
  final VoidCallback? onBack;
  final Key? backKey;
  final List<Widget> actions;
  final List<Widget> trailing;

  @override
  Size get preferredSize => Size.fromHeight(64 + (actions.isEmpty ? 0 : 44));

  @override
  Widget build(BuildContext context) {
    final bar = AppBar(
      toolbarHeight: 64,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFF991C24),
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: showBack ? 0 : 12,
      leadingWidth: 36,
      leading: showBack
          ? IconButton(
              key: backKey,
              tooltip: 'Back',
              padding: EdgeInsets.zero,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 22),
            )
          : null,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF831B20), Color(0xFFB52626), Color(0xFF991C24)],
            stops: [0, .55, 1],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
      title: Row(
        children: [
          if (showLogo) ...[
            Image.asset(
              'assets/images/club-logo.png',
              width: 30,
              height: 38,
              fit: BoxFit.contain,
              semanticLabel: 'NorthEast United FC logo',
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: showLogo ? 17 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: showLogo ? .2 : .4,
                    ),
                  ),
                ),
                if (subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: .15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        ...trailing,
        if (showProfile)
          HeaderActionVisibility(
            kind: 'search',
            child: IconButton(
              key: const ValueKey('header-search'),
              tooltip: 'Search',
              constraints: const BoxConstraints.tightFor(width: 32, height: 40),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(32, 40),
                padding: EdgeInsets.zero,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
              icon: const HeaderActionIcon(
                kind: 'search',
                fallback: Icons.search_rounded,
                size: 26,
              ),
            ),
          ),
        const CustomerSupportButton(),
        if (showNotifications)
          HeaderActionVisibility(
            kind: 'notifications',
            child: IconButton(
              key: const ValueKey('header-notifications'),
              tooltip: 'Notifications',
              constraints: const BoxConstraints.tightFor(width: 32, height: 40),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(32, 40),
                padding: EdgeInsets.zero,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AlertsScreen())),
              icon: const HeaderActionIcon(
                kind: 'notifications',
                fallback: Icons.notifications_none_rounded,
              ),
            ),
          ),
        const SizedBox(width: 4),
      ],
      bottom: actions.isEmpty
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: SizedBox(
                height: 44,
                child: IconTheme(
                  data: const IconThemeData(color: Colors.white, size: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [...actions, const SizedBox(width: 8)],
                  ),
                ),
              ),
            ),
    );
    return embedded
        ? SizedBox(
            height: MediaQuery.paddingOf(context).top + preferredSize.height,
            child: bar,
          )
        : bar;
  }
}
