import '../widgets/club_page_body.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';

import '../app_navigation.dart';
import '../club_repository.dart';
import '../explore_repository.dart';
import '../feed_store.dart';
import '../message_alerts.dart';
import '../otp_api.dart';
import '../realtime_client.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/community_icons.dart';
import '../widgets/explore_quick_access.dart';
import 'community_screen.dart';
import 'login_screen.dart';

const _exploreIcons = <String, IconData>{
  'gallery': Icons.photo_library_outlined,
  'friends': Icons.people_outline,
  'swoofi': Icons.pets_outlined,
  'notifications': Icons.notifications_none_outlined,
  'help': Icons.help_outline,
  'squad': Icons.checkroom_outlined,
  'matches': Icons.sports_soccer,
  'grounds': Icons.stadium_outlined,
  'link': Icons.link,
  'star': Icons.star_outline,
  'heart': Icons.favorite_border,
};

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.repository});
  final ExploreRepository? repository;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  ExploreRepository get _repository =>
      widget.repository ?? ExploreRepository.instance;
  late Map<String, dynamic> _config;
  final _search = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  int _loadVersion = 0;
  bool _logoutBusy = false;
  String _text(String key) => '${_config[key] ?? ''}';
  @override
  void initState() {
    super.initState();
    _config = _repository.current;
    _repository.addListener(_applyConfig);
    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (event['resource'] == 'all' || event['resource'] == 'explore') {
        _load();
      }
    });
    if (!_repository.warmed) _load();
  }

  void _applyConfig() {
    if (!mounted) return;
    setState(() {
      _config = _repository.current;
      if (_config['showSearch'] == false) _search.clear();
    });
  }

  @override
  void dispose() {
    _repository.removeListener(_applyConfig);
    _subscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    final config = await _repository.load();
    if (mounted && version == _loadVersion) {
      setState(() {
        _config = config;
        if (_config['showSearch'] == false) {
          _search.clear();
        }
      });
    }
  }

  List<Map<String, dynamic>> _items(String field) =>
      (_config[field] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where(
            (row) =>
                row['enabled'] != false &&
                '${row['label']}'.toLowerCase().contains(
                  _search.text.trim().toLowerCase(),
                ),
          )
          .toList();
  Future<void> _open(String link) async {
    if (link == '/help') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => AnimatedBuilder(
          animation: _repository,
          builder: (_, _) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_repository.current['helpTitle'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SelectableText('${_repository.current['helpText'] ?? ''}'),
                    if ('${_repository.current['helpUrl'] ?? ''}'.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: FilledButton(
                          onPressed: () => openAppDestination(
                            sheetContext,
                            '${_repository.current['helpUrl'] ?? ''}',
                          ),
                          child: const Text('Contact support'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }
    await openAppDestination(context, link);
  }

  void _searchPeople() {
    final query = _search.text.trim();
    if (query.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityPeopleScreen(initialQuery: query),
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _logoutBusy = true);
    try {
      await MessageAlerts.stop();
      await Session.logout();
      FeedStore.clear();
      OtpApi.instance.mobileVerificationToken = '';
      OtpApi.instance.emailVerificationToken = '';
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log out. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _logoutBusy = false);
      }
    }
  }

  Widget _icon(
    Map<String, dynamic> item, {
    double size = 32,
    Color color = clubInk,
  }) {
    final image = '${item['image_url'] ?? ''}';
    if (image.isNotEmpty) {
      return Image.network(
        ClubRepository.mediaUrl(image),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(Icons.link, color: color, size: size),
      );
    }
    if (item['icon'] == 'circles') {
      return ImageIcon(CommunityIcons.circles, color: color, size: size);
    }
    return Icon(
      _exploreIcons[item['icon']] ?? Icons.link,
      color: color,
      size: size,
    );
  }

  Map<String, dynamic> get _colors => Map<String, dynamic>.from(
    (_config['colors'] as Map?) ?? defaultExplore['colors'] as Map,
  );
  Color _tone(String key, Color fallback) {
    final val = _colors[key];
    if (key == 'page' && (val == '#F7F4EF' || val == null)) {
      return const Color(0xFFF9F7F3);
    }
    return exploreColor(val, fallback);
  }
  Widget _header() => ClubHeader(
    title: _text('title'),
    subtitle: _text('headerSubtitle'),
    embedded: true,
    showLogo: false,
    showNotifications: _config['showNotifications'] != false,
    // Keep the existing admin setting key for saved Explore configurations.
    showSearch: _config['showProfile'] != false,
  );
  Widget _feature(Map<String, dynamic> item, double width) {
    final accent = _tone('cardAccent', authRed);
    return SizedBox(
    width: width,
    child: Material(
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF3D1919),
      child: InkWell(
        key: ValueKey('explore-card-${item['id']}'),
        onTap: () => _open('${item['link']}'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              ClubRepository.mediaUrl(item['image_url']),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Icon(
                  _exploreIcons[item['icon']] ?? Icons.sports_soccer,
                  color: Colors.white54,
                  size: 72,
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .4, 1],
                  colors: [
                    Color(0x88000000),
                    Colors.transparent,
                    Color(0x22000000),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 3,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item['label']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 23,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _items('cards'),
        quick = _items('quickLinks'),
        links = _items('links');
    final cardWidth = (MediaQuery.sizeOf(context).width * .42).clamp(
      156.0,
      210.0,
    );
    final page = _tone('page', const Color(0xFFF9F7F3));
    final heading = _tone('heading', const Color(0xFF171717));
    final muted = _tone('muted', const Color(0xFF8A847C));
    final accent = _tone('accent', authRed);
    return Scaffold(
      backgroundColor: page,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ClubPageBody(
              color: page,
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  key: const PageStorageKey('explore-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + 26,
                  ),
                  children: [
                    if (_config['showSearch'] != false)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _searchPeople(),
                          decoration: InputDecoration(
                            hintText: _text('searchPlaceholder'),
                            prefixIcon: Icon(Icons.search, color: muted),
                            hintStyle: TextStyle(color: muted, fontSize: 15),
                            filled: true,
                            fillColor: _tone('search', const Color(0xFFF1EEEA)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    if (_search.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextButton.icon(
                          onPressed: _searchPeople,
                          icon: const Icon(Icons.person_search_outlined),
                          label: const Text('Search people'),
                        ),
                      ),
                    if (_repository.hasError)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextButton(
                          onPressed: _load,
                          child: const Text('Could not refresh Explore. Retry'),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        _config['showSearch'] == false ? 14 : 0,
                        14,
                        10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text('heading'),
                            style: TextStyle(
                              color: heading,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.3,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _text('subtitle'),
                            style: TextStyle(
                              color: muted,
                              fontSize: 14.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (cards.isNotEmpty)
                      SizedBox(
                        height: cardWidth * (270 / 169),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: cards.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (_, index) =>
                              _feature(cards[index], cardWidth),
                        ),
                      ),
                    if (quick.isNotEmpty)
                      ExploreQuickAccess(
                        title: _text('quickTitle'),
                        items: quick,
                        onOpen: _open,
                        colors: _colors,
                      ),
                    if (links.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCED3DF)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x0A000000), blurRadius: 5),
                          ],
                        ),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < links.length;
                                index++
                              ) ...[
                                if (index > 0)
                                  const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                ListTile(
                                  key: ValueKey(
                                    'explore-link-${links[index]['id']}',
                                  ),
                                  onTap: () => _open('${links[index]['link']}'),
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _tone('linkIcon', const Color(0xFFFDECEC)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: _icon(
                                        links[index],
                                        size: 19,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${links[index]['label']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    size: 19,
                                    color: _tone('chevron', const Color(0xFFB7B3AE)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (cards.isEmpty &&
                        quick.isEmpty &&
                        links.isEmpty &&
                        _search.text.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matches found.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_config['showLogout'] != false)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _tone('logout', const Color(0xFFFBECEC)),
                            foregroundColor: _tone('logoutText', authRed),
                            elevation: 0,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _logoutBusy ? null : _logout,
                          child: Text(
                            _logoutBusy ? 'Logging out…' : _text('logoutLabel'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
