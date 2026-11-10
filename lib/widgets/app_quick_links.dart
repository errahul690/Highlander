import 'dart:async';

import 'package:flutter/material.dart';

import '../realtime_client.dart';

import 'package:flutter/services.dart';

import '../app_settings_repository.dart';
import '../media_cache.dart';
import '../otp_api.dart';
import '../theme.dart';
import '../screens/alerts_screen.dart';
import '../screens/community_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/grounds_screen.dart';
import 'grounds_host.dart';
import '../screens/matches_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/squad_screen.dart';
import '../screens/swoofi_screen.dart';

const _icons = <String, IconData>{
  'groups': Icons.groups_outlined,
  'calendar': Icons.calendar_month_outlined,
  'camera': Icons.photo_camera_outlined,
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0F0F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('app-quick-links-scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < _buttons.length; index++)
              SizedBox(
                width: (constraints.maxWidth / 4).clamp(70.0, double.infinity),
                child: InkWell(
                  key: ValueKey('app-quick-button-$index'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _open(_buttons[index]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const [
                              Color(0xFFF0EBFF),
                              Color(0xFFFFEEE8),
                              Color(0xFFE7F2FF),
                              Color(0xFFE5FAEF),
                            ][index % 4],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: _buttons[index].iconUrl.isEmpty
                              ? _quickIcon(_buttons[index].icon, index)
                              : Image.network(
                                  Uri.parse(OtpApi.apiBase)
                                      .resolve(_buttons[index].iconUrl)
                                      .toString(),
                                  key: ValueKey(
                                    'quick-${_buttons[index].iconUrl}-${MediaCache.instance.generation.value}',
                                  ),
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, error, stack) =>
                                      _quickIcon(_buttons[index].icon, index),
                                ),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            _buttons[index].label.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: clubFontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF303137),
                              height: 1.25,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (_buttons[index].subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _buttons[index].subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: clubFontFamily,
                              fontSize: 10,
                              height: 1.25,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _quickIcon(String icon, int index) => Icon(
    _icons[icon] ?? Icons.link,
    size: 25,
    color: const [
      Color(0xFF8A79CB),
      Color(0xFFEA4D3D),
      Color(0xFF2588CA),
      Color(0xFF24A6A4),
    ][index % 4],
  );
}
