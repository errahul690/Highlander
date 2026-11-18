import 'package:Highlanders/core/theme/brand_colors.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:Highlanders/core/network/realtime_client.dart';

import 'package:flutter/services.dart';

import 'package:Highlanders/features/settings/data/app_settings_repository.dart';
import 'package:Highlanders/core/theme/theme.dart';
import 'package:Highlanders/features/notifications/screens/alerts_screen.dart';
import 'package:Highlanders/features/community/screens/community_screen.dart';
import 'package:Highlanders/features/explore/screens/explore_screen.dart';
import 'package:Highlanders/features/community/screens/friends_screen.dart';
import 'package:Highlanders/features/gallery/screens/gallery_screen.dart';
import 'package:Highlanders/features/grounds/screens/grounds_screen.dart';
import 'package:Highlanders/features/grounds/widgets/grounds_host.dart';
import 'package:Highlanders/features/feed/widgets/quick_card_image.dart';
import 'package:Highlanders/features/matches/screens/matches_screen.dart';
import 'package:Highlanders/features/profile/screens/profile_screen.dart';
import 'package:Highlanders/features/settings/screens/settings_screen.dart';
import 'package:Highlanders/features/squad/screens/squad_screen.dart';
import 'package:Highlanders/features/sponsors/screens/sponsors_screen.dart';
import 'package:Highlanders/features/swoofi/screens/swoofi_screen.dart';

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
        RealtimeClient.instance.trackFeedRefresh(_reload(force: true));
      } else if (event['resource'] == 'all' || event['resource'] == 'buttons') {
        _reload(force: true);
      }
    });
  }

  bool _fetching = false;
  @override
  void initState() {
    super.initState();
    _listenForUpdates();
    _buttons = _repository.current;
    _repository.addListener(_onButtonsChanged);
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    _repository.removeListener(_onButtonsChanged);
    _settingsSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload(force: true);
  }

  void _onButtonsChanged() {
    if (mounted) setState(() => _buttons = _repository.current);
  }

  @override
  void didUpdateWidget(covariant AppQuickLinks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository == widget.repository) return;
    (oldWidget.repository ?? AppSettingsRepository.instance).removeListener(
      _onButtonsChanged,
    );
    _repository.addListener(_onButtonsChanged);
    _buttons = _repository.current;
    _reload();
  }

  Future<void> _reload({bool force = false}) async {
    if (_fetching) {
      if (force) _reloadAgain = true;
      return;
    }
    _fetching = true;
    final buttons = await (force
        ? _repository.load()
        : _repository.ensureLoaded());
    _fetching = false;
    if (mounted) setState(() => _buttons = buttons);
    if (_reloadAgain && mounted) {
      _reloadAgain = false;
      await _reload(force: true);
    }
  }

  Future<void> _open(AppQuickButton button) async {
    if (button.link == AlertsScreen.routeName) {
      AlertsScreen.open(context);
      return;
    }
    if (button.link == '/grounds' && GroundsHost.open(context)) return;
    final pages = <String, Widget>{
      '/squad': const SquadScreen(),
      '/matches': const MatchesScreen(),
      '/gallery': const GalleryScreen(),
      '/grounds': const GroundsScreen(),
      '/profile': const ProfileScreen(),
      '/settings': const SettingsScreen(),
      '/friends': const FriendsScreen(title: 'Friends'),
      '/circles': const CommunityScreen(),
      '/explore': const ExploreScreen(),
      '/swoofi': const SwoofiScreen(),
      SponsorsScreen.routeName: const SponsorsScreen(),
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
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const FormatException();
      }
      await const MethodChannel('highlanders/app_links')
          .invokeMethod<void>('openUrl', {'url': uri.toString()});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this link. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const ValueKey('app-quick-links-scroll'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: (constraints.maxWidth - 8).clamp(0, double.infinity),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < _buttons.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              SizedBox(width: 88, child: _card(_buttons[index], index)),
            ],
          ],
        ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241F0D15),
            offset: Offset(0, 5),
            blurRadius: 9,
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Color(0x141F0D15),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: button.backgroundImageUrl.isEmpty
            ? background
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('app-quick-button-$index'),
          onTap: () => _open(button),
          child: SizedBox(
            height: 140,
            child: Stack(
              children: [
                if (button.backgroundImageUrl.isEmpty)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x66FFFFFF),
                            Color(0x00FFFFFF),
                            Color(0x09000000),
                          ],
                        ),
                      ),
                      child: CustomPaint(painter: _CardTint(tint)),
                    ),
                  ),
                if (button.backgroundImageUrl.isNotEmpty)
                  Positioned.fill(
                    child: _uploadedImage(
                      button.backgroundImageUrl,
                      trimTransparentPadding: true,
                      fit: BoxFit.fill,
                      fallback: ColoredBox(
                        color: background,
                        child: CustomPaint(painter: _CardTint(tint)),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 78,
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
                  top: 59,
                  left: 7,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white, width: 1.3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24000000),
                          offset: Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: button.customIconUrl.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(5),
                            child: _uploadedImage(
                              button.customIconUrl,
                              fit: BoxFit.contain,
                              fallback: Icon(
                                _icons[button.icon] ?? Icons.link,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            _icons[button.icon] ?? Icons.link,
                            size: 15,
                            color: Colors.white,
                          ),
                  ),
                ),
                Positioned(
                  top: 87,
                  left: 7,
                  right: 7,
                  child: Text(
                    button.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: clubFontFamily,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: Color(0xFF191919),
                    ),
                  ),
                ),
                Positioned(
                  top: 106,
                  left: 7,
                  right: 26,
                  child: Text(
                    button.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: clubFontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                      color: Color(0xFF676168),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    key: ValueKey('app-quick-arrow-$index'),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
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
    bool trimTransparentPadding = false,
  }) => QuickCardImage(
    key: ValueKey('quick-art-$url'),
    url: url,
    fit: fit,
    fallback: fallback,
    trimTransparentPadding: trimTransparentPadding,
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
