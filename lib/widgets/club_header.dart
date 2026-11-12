import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_updates.dart';
import '../screens/alerts_screen.dart';
import '../screens/search_screen.dart';
import 'customer_support_button.dart';
import 'header_action_icon.dart';

/// Shared club branding, navigation, search, support and notifications.
class ClubHeader extends StatelessWidget implements PreferredSizeWidget {
  const ClubHeader({
    super.key,
    required this.title,
    this.titleWidget,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.backKey,
    this.embedded = false,
    this.showNotifications = true,
    this.showSearch = true,
    this.showLogo = true,
    this.showSupport = true,
    this.uppercaseTitle = true,
    this.titleFontSize,
    this.backButtonWidth = 36,
    this.actions = const [],
    this.trailing = const [],
  });

  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final bool showBack, embedded, showNotifications, showSearch, showLogo;
  final bool showSupport, uppercaseTitle;
  final double? titleFontSize;
  final double backButtonWidth;
  final VoidCallback? onBack;
  final Key? backKey;
  final List<Widget> actions;
  final List<Widget> trailing;

  @override
  Size get preferredSize => Size.fromHeight(80 + (actions.isEmpty ? 0 : 44));

  @override
  Widget build(BuildContext context) {
    final bar = AppBar(
      toolbarHeight: 72,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: showBack ? 0 : 18,
      leadingWidth: backButtonWidth,
      leading: showBack
          ? IconButton(
              key: backKey,
              tooltip: 'Back',
              padding: EdgeInsets.zero,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 22),
            )
          : null,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/header-edge.png',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
          Positioned.fill(
            bottom: 4,
            child: Image.asset(
              'assets/images/header-background.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          const CustomPaint(painter: _HeaderStripes()),
        ],
      ),
      title:
          titleWidget ??
          Row(
            children: [
              if (showLogo) ...[
                Image.asset(
                  'assets/images/header-logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                  semanticLabel: 'Highlanders logo',
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 26, color: Colors.white54),
                const SizedBox(width: 12),
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
                        uppercaseTitle ? title.toUpperCase() : title,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize ?? (showLogo ? 18 : 22),
                          fontWeight: FontWeight.w700,
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
        if (showSearch)
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
        if (showSupport) const CustomerSupportButton(),
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
              icon: ValueListenableBuilder<int>(
                valueListenable: ChatUpdates.instance.unreadNotifications,
                builder: (_, count, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const HeaderActionIcon(
                      kind: 'notifications',
                      fallback: Icons.notifications_none_rounded,
                    ),
                    if (count > 0)
                      const Positioned(
                        right: -2,
                        top: -2,
                        child: NotificationUnreadDot(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(8 + (actions.isEmpty ? 0 : 44)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actions.isNotEmpty)
              SizedBox(
                height: 44,
                child: IconTheme(
                  data: const IconThemeData(color: Colors.white, size: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [...actions, const SizedBox(width: 16)],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
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

class _HeaderStripes extends CustomPainter {
  const _HeaderStripes();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height - 40));
    for (final start in [.38, .72]) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * start, size.height - 40)
          ..lineTo(size.width * (start + .23), 0)
          ..lineTo(size.width * (start + .39), 0)
          ..lineTo(size.width * (start + .16), size.height - 40)
          ..close(),
        Paint()..color = const Color(0x188F193F),
      );
    }
  }

  @override
  bool shouldRepaint(_HeaderStripes oldDelegate) => false;
}
