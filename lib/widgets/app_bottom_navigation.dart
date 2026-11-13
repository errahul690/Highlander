import '../brand_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../chat_updates.dart';
import 'unread_chat_badge.dart';

import '../screens/shell.dart';
import '../theme.dart';

class AppBottomNavigation extends StatefulWidget {
  const AppBottomNavigation({
    super.key,
    this.selectedIndex = -1,
    this.onSelect,
  });
  final int selectedIndex;
  final ValueChanged<int>? onSelect;

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation> {
  ScrollNotificationObserverState? _observer;
  bool _visible = true;
  int get selectedIndex => widget.selectedIndex;
  ValueChanged<int>? get onSelect => widget.onSelect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = ScrollNotificationObserver.maybeOf(context);
    if (identical(observer, _observer)) return;
    _observer?.removeListener(_onScroll);
    _observer = observer;
    _observer?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(AppBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _visible = true;
  }

  void _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return;
    }
    bool? visible;
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      visible = notification.direction == ScrollDirection.forward;
    } else if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      visible = true;
    }
    if (visible != null && visible != _visible && mounted) {
      setState(() => _visible = visible!);
    }
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onFeed = selectedIndex == 2;
    final textScaler = MediaQuery.textScalerOf(context);
    final barHeight = (35 + textScaler.scale(10) * 1.1).clamp(
      54.0,
      double.infinity,
    );
    final feedSize = (38 + textScaler.scale(11) * 1.1).clamp(
      58.0,
      double.infinity,
    );
    void onSelected(int index) {
      if (onSelect != null) {
        onSelect!(index);
      } else {
        AppShell.openTab(context, index);
      }
    }

    return IgnorePointer(
      ignoring: !_visible,
      child: ExcludeSemantics(
        excluding: !_visible,
        child: AnimatedSlide(
          key: const ValueKey('bottom-bar-slide'),
          offset: _visible ? Offset.zero : const Offset(0, 1.3),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                10,
                18,
                Theme.of(context).platform == TargetPlatform.iOS
                    ? MediaQuery.paddingOf(context).bottom
                    : MediaQuery.viewPaddingOf(context).bottom + 4,
              ),
              child: Container(
                key: const ValueKey('floating-bottom-bar'),
                height: barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    _destination(
                      context,
                      0,
                      'Friends',
                      Icons.people_outline,
                      image: const AssetImage('assets/icons/nav-friends.png'),
                    ),
                    _destination(
                      context,
                      1,
                      'Huddles',
                      Icons.groups_outlined,
                      image: const AssetImage('assets/icons/nav-circles.png'),
                    ),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: onFeed ? 'Create a post' : 'Open Feed',
                        child: GestureDetector(
                          key: const ValueKey('feed-post-action'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelected(2),
                          child: OverflowBox(
                            minHeight: feedSize,
                            maxHeight: feedSize,
                            child: Transform.translate(
                              offset: const Offset(0, -4),
                              child: Container(
                                width: feedSize,
                                height: feedSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [brandAccent, brandAccentDark],
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x25900F32),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.article_outlined,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      onFeed ? 'Post' : 'Feed',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: clubFontFamily,
                                        fontSize: 11,
                                        height: 1.1,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _destination(context, 3, 'Explore', Icons.explore_outlined),
                    _destination(
                      context,
                      4,
                      'Profile',
                      Icons.person_outline,
                      image: const AssetImage('assets/icons/nav-profile.png'),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        key: ValueKey(
          index == 1 ? 'nav-huddles' : 'nav-${label.toLowerCase()}',
        ),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect != null
            ? onSelect!(index)
            : AppShell.openTab(context, index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index == 1)
                ValueListenableBuilder<int>(
                  valueListenable: ChatUpdates.instance.unreadCount,
                  builder: (_, count, __) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _assetIcon(
                        image!,
                        selectedIndex == index
                            ? const Color(0xFF747474)
                            : authRed,
                        26,
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
              else if (index == 3)
                CustomPaint(
                  key: const ValueKey('nav-explore-artwork'),
                  size: const Size(24, 24),
                  painter: _ExploreCompass(
                    selectedIndex == index ? const Color(0xFF747474) : authRed,
                  ),
                )
              else if (image != null)
                _assetIcon(
                  image,
                  selectedIndex == index ? const Color(0xFF747474) : authRed,
                  index == 0 ? 30 : 26,
                )
              else
                Icon(
                  icon,
                  color: selectedIndex == index
                      ? const Color(0xFF747474)
                      : authRed,
                  size: 24,
                ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selectedIndex == index
                      ? const Color(0xFF747474)
                      : authRed,
                  fontFamily: clubFontFamily,
                  fontSize: 10,
                  height: 1.1,
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

  // The supplied PNGs have different transparent margins. Match their visible
  // artwork while keeping every icon and label on the same 24 px slot.
  Widget _assetIcon(ImageProvider image, Color color, double artworkSize) =>
      SizedBox.square(
        dimension: 24,
        child: OverflowBox(
          minWidth: artworkSize,
          maxWidth: artworkSize,
          minHeight: artworkSize,
          maxHeight: artworkSize,
          child: ImageIcon(image, color: color, size: artworkSize),
        ),
      );
}

// Vector paths from assets/icons/nav-explore.svg, drawn at its original 25×25
// viewBox so the supplied thin strokes stay sharp at any device pixel ratio.
class _ExploreCompass extends CustomPainter {
  const _ExploreCompass(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 23, size.height / 23);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 24.5581, 24.5581));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = .845089
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(21.1877, 12.5799)
        ..cubicTo(21.1877, 17.8987, 16.8759, 22.2105, 11.557, 22.2105)
        ..cubicTo(6.23818, 22.2105, 1.92639, 17.8987, 1.92639, 12.5799)
        ..cubicTo(1.92639, 7.261, 6.23818, 2.94922, 11.557, 2.94922)
        ..cubicTo(16.8759, 2.94922, 21.1877, 7.261, 21.1877, 12.5799)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(15.6402, 8.49609)
        ..lineTo(13.9029, 13.7072)
        ..cubicTo(13.8083, 13.9909, 13.649, 14.2487, 13.4375, 14.4602)
        ..cubicTo(13.2261, 14.6716, 12.9683, 14.831, 12.6846, 14.9255)
        ..lineTo(7.47345, 16.6629)
        ..lineTo(9.21082, 11.4517)
        ..cubicTo(9.30537, 11.168, 9.46469, 10.9102, 9.67615, 10.6988)
        ..cubicTo(9.8876, 10.4873, 10.1454, 10.328, 10.4291, 10.2335)
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ExploreCompass oldDelegate) => oldDelegate.color != color;
}
