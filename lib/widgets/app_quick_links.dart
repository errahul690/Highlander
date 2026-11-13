import '../brand_colors.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../realtime_client.dart';

import 'package:flutter/services.dart';

import '../app_settings_repository.dart';
import '../theme.dart';
import '../screens/alerts_screen.dart';
import '../screens/community_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/grounds_screen.dart';
import 'grounds_host.dart';
import 'quick_card_image.dart';
import '../screens/matches_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/squad_screen.dart';
import '../screens/swoofi_screen.dart';

const _icons = <String, IconData>{
  'groups': Icons.groups_outlined,
  'calendar': Icons.calendar_month_outlined,
  'camera': Icons.image_outlined,
  'stadium': Icons.stadium_outlined,
  'notifications': Icons.notifications_outlined,
  'ticket': Icons.confirmation_number_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'link': Icons.link,
  'star': Icons.star_outline,
  'heart': Icons.favorite_outline,
  'home': Icons.home_outlined,
  'person': Icons.person_outline,
  'trophy': Icons.emoji_events_outlined,
};

class AppQuickLinks extends StatefulWidget {
  const AppQuickLinks({super.key, this.repository});
  final AppSettingsRepository? repository;
  @override
  State<AppQuickLinks> createState() => _AppQuickLinksState();
}

class _AppQuickLinksState extends State<AppQuickLinks>
    with WidgetsBindingObserver {
  AppSettingsRepository get _repository =>
      widget.repository ?? AppSettingsRepository.instance;
  late List<AppQuickButton> _buttons;
  StreamSubscription<Map<String, dynamic>>? _settingsSubscription;
  bool _reloadAgain = false;
  void _listenForUpdates() {
    _settingsSubscription = RealtimeClient.instance.settingsChanges.listen((
      event,
    ) {
      if (event['resource'] == 'feed-refresh') {
        RealtimeClient.instance.trackFeedRefresh(_reload());
      } else if (event['resource'] == 'all' || event['resource'] == 'buttons') {
        _reload();
      }
    });
  }

  bool _fetching = false;
  @override
  void initState() {
    super.initState();
    _listenForUpdates();
    _buttons = _repository.current;
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    if (_fetching) {
      _reloadAgain = true;
      return;
    }
    _fetching = true;
    final buttons = await _repository.load();
    _fetching = false;
    if (mounted) setState(() => _buttons = buttons);
    if (_reloadAgain && mounted) {
      _reloadAgain = false;
      await _reload();
    }
  }

  Future<void> _open(AppQuickButton button) async {
    if (button.link == '/grounds' && GroundsHost.open(context)) return;
    final pages = <String, Widget>{
      '/squad': const SquadScreen(),
      '/matches': const MatchesScreen(),
      '/gallery': const GalleryScreen(),
      '/grounds': const GroundsScreen(),
      '/alerts': const AlertsScreen(),
      '/profile': const ProfileScreen(),
      '/settings': const SettingsScreen(),
      '/friends': const FriendsScreen(title: 'Friends'),
      '/circles': const CommunityScreen(),
      '/explore': const ExploreScreen(),
      '/swoofi': const SwoofiScreen(),
    };
    final page = pages[button.link];
    if (page != null) {
      Navigator.of(context).push(
        button.link == '/grounds'
            ? GroundsScreen.route()
            : MaterialPageRoute(builder: (_) => page),
      );
      return;
    }
    try {
      final uri = Uri.parse(button.link);
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty)
        throw const FormatException();
      await const MethodChannel('highlanders/app_links')
          .invokeMethod<void>('openUrl', {'url': uri.toString()});
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this link. Please try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const ValueKey('app-quick-links-scroll'),
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < _buttons.length; index++) ...[
            if (index > 0) const SizedBox(width: 2),
            if (Theme.of(context).platform == TargetPlatform.android)
              SizedBox(
                width: 88,
                height: 161 * 88 / 98,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 98,
                    child: _card(_buttons[index], index),
                  ),
                ),
              )
            else
              SizedBox(width: 98, child: _card(_buttons[index], index)),
          ],
        ],
      ),
    ),
  );

  Widget _card(AppQuickButton button, int index) {
    final accent = _color(
      button.iconBackgroundColor,
      const [
        brandAccent,
        Color(0xFF0079BA),
        Color(0xFFE66B00),
        Color(0xFF397E28),
      ][index % 4],
    );
    final background = const [
      Color(0xFFFFF0F5),
      Color(0xFFEEF8FF),
      Color(0xFFFFF5E8),
      Color(0xFFF1F8E9),
    ][index % 4];
    final tint = const [
      Color(0xFFF6C7D6),
      Color(0xFFC6E6FB),
      Color(0xFFFFDAA6),
      Color(0xFFC9E5B3),
    ][index % 4];
    final artwork = button.topImageUrl;
    return Material(
      color: button.backgroundImageUrl.isEmpty
          ? background
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      elevation: button.backgroundImageUrl.isEmpty ? .5 : 0,
      shadowColor: const Color(0x10000000),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('app-quick-button-$index'),
        onTap: () => _open(button),
        child: SizedBox(
          height: 161,
          child: Stack(
            children: [
              if (button.backgroundImageUrl.isEmpty)
                Positioned.fill(child: CustomPaint(painter: _CardTint(tint))),
              if (button.backgroundImageUrl.isNotEmpty)
                Positioned.fill(
                  child: _uploadedImage(
                    button.backgroundImageUrl,
                    fit: BoxFit.fill,
                    fallback: ColoredBox(
                      color: background,
                      child: CustomPaint(painter: _CardTint(tint)),
                    ),
                  ),
                ),
              Positioned(
                top: 3,
                left: 5,
                right: 5,
                height: 81,
                child: ClipRRect(
                  key: ValueKey('app-quick-photo-$index'),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: artwork.isEmpty
                      ? (button.backgroundImageUrl.isNotEmpty
                            ? const SizedBox.shrink()
                            : _photoPlaceholder(accent, button.icon))
                      : _uploadedImage(
                          artwork,
                          fit: BoxFit.cover,
                          fallback: _photoPlaceholder(accent, button.icon),
                        ),
                ),
              ),
              Positioned(
                top: 60,
                left: 7,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white, width: 1.3),
                  ),
                  child: button.customIconUrl.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(5),
                          child: _uploadedImage(
                            button.customIconUrl,
                            fit: BoxFit.contain,
                            fallback: Icon(
                              _icons[button.icon] ?? Icons.link,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Icon(
                          _icons[button.icon] ?? Icons.link,
                          size: 20,
                          color: Colors.white,
                        ),
                ),
              ),
              Positioned(
                top: 94,
                left: 10,
                right: 5,
                child: Text(
                  button.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: clubFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: Color(0xFF191919),
                  ),
                ),
              ),
              Positioned(
                top: 116,
                left: 11,
                right: 30,
                child: Text(
                  button.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: clubFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: Color(0xFF676168),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 16,
                child: Container(
                  key: ValueKey('app-quick-arrow-$index'),
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tint,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: accent,
                  ),
                ),
              ),
              if (button.backgroundImageUrl.isEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder(Color accent, String icon) => Container(
    color: accent.withValues(alpha: .12),
    alignment: Alignment.center,
    child: Icon(
      Icons.image_outlined,
      size: 34,
      color: accent.withValues(alpha: .3),
    ),
  );

  Color _color(String value, Color fallback) =>
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)
      ? Color(int.parse('FF${value.substring(1)}', radix: 16))
      : fallback;

  Widget _uploadedImage(
    String url, {
    required BoxFit fit,
    required Widget fallback,
  }) => QuickCardImage(
    key: ValueKey('quick-art-$url'),
    url: url,
    fit: fit,
    fallback: fallback,
  );
}

class _CardTint extends CustomPainter {
  const _CardTint(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height - 25)
      ..lineTo(size.width, size.height)
      ..close(),
    Paint()..color = color,
  );
  @override
  bool shouldRepaint(_CardTint oldDelegate) => oldDelegate.color != color;
}
