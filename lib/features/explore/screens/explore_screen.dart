import 'package:Highlanders/shared/widgets/club_page_body.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:Highlanders/features/posts/data/posts_api.dart';
import 'package:Highlanders/core/network/network_read.dart';

import 'package:Highlanders/shared/widgets/club_header.dart';

import 'package:Highlanders/app/app_navigation.dart';
import 'package:Highlanders/shared/data/club_repository.dart';
import 'package:Highlanders/features/explore/data/explore_repository.dart';
import 'package:Highlanders/features/feed/data/feed_store.dart';
import 'package:Highlanders/core/notifications/message_alerts.dart';
import 'package:Highlanders/features/auth/data/otp_api.dart';
import 'package:Highlanders/core/network/realtime_client.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/core/theme/theme.dart';
import 'package:Highlanders/features/community/widgets/community_icons.dart';
import 'package:Highlanders/features/explore/widgets/explore_quick_access.dart';
import 'package:Highlanders/features/community/screens/community_screen.dart';
import 'package:Highlanders/features/auth/screens/login_screen.dart';

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
  bool _deleting = false;
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

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    if (_deleting || _logoutBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(28, 28, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Are You Sure?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF606060),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Please hit Delete if you wish to delete your account. '
                  'You can log in again within 90 days to cancel the deletion request and keep your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF606060),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _tone('logoutText', authRed),
                          side: BorderSide(color: _tone('logoutText', authRed)),
                          minimumSize: Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('confirm-delete-account'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _tone('logoutText', authRed),
                          foregroundColor: Colors.white,
                          minimumSize: Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    setState(() => _deleting = true);
    try {
      await PostsApi.instance.request('/api/auth/me', method: 'DELETE');
    } catch (error) {
      if (!context.mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiRequestException
                ? error.toString()
                : 'Could not delete account. Please try again.',
          ),
        ),
      );
      return;
    }

    // Once the server succeeds, a local cleanup failure must not leave the
    // deleted account signed in or ask the user to repeat the server request.
    try {
      await MessageAlerts.stop();
    } catch (_) {}
    try {
      await Session.logout();
    } catch (_) {
      Session.clear();
    }
    FeedStore.clear();
    OtpApi.instance.mobileVerificationToken = '';
    OtpApi.instance.emailVerificationToken = '';
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
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

  PreferredSizeWidget _header() => ClubHeader(
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
      body: ClubHeaderLayout(
        header: _header(),
        body: ClubPageBody(
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
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
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
                                  color: _tone(
                                    'linkIcon',
                                    const Color(0xFFFDECEC),
                                  ),
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
                                color: _tone(
                                  'chevron',
                                  const Color(0xFFB7B3AE),
                                ),
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
                    child: FilledButton.icon(
                      key: const ValueKey('explore-logout-button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _tone(
                          'logout',
                          const Color(0xFFFBECEC),
                        ),
                        foregroundColor: _tone('logoutText', authRed),
                        elevation: 0,
                        minimumSize: Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _logoutBusy || _deleting ? null : _logout,
                      icon: Icon(Icons.logout_rounded, size: 22),
                      label: Text(
                        _logoutBusy ? 'Logging out…' : _text('logoutLabel'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                  child: Center(
                    child: TextButton(
                      key: const ValueKey('delete-account-button'),
                      onPressed: _deleting || _logoutBusy
                          ? null
                          : () => _confirmDeleteAccount(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF858995),
                        textStyle: TextStyle(
                          fontFamily: clubFontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        minimumSize: Size(160, 48),
                      ),
                      child: Text(
                        _deleting ? 'Deleting account...' : 'Delete account',
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
}
