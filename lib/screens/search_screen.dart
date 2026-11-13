import '../widgets/club_page_body.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../community_api.dart';
import '../explore_repository.dart';
import '../posts_api.dart';
import '../theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/club_header.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['People', 'Feature', 'Huddles', 'Group', 'Post'];
  final _input = TextEditingController();
  final _busy = <String>{};
  late final TabController _tabsController;
  Timer? _debounce;
  int _request = 0;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _tabsController = TabController(length: _tabs.length, vsync: this);
    _tabsController.addListener(() {
      if (!_tabsController.indexIsChanging) _run();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _tabsController.dispose();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _run);
  }

  Future<void> _run() async {
    final query = _input.text.trim();
    final tab = _tabsController.index;
    final request = ++_request;
    if (query.isEmpty) {
      setState(() {
        _rows = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _load(tab, query);
      if (!mounted || request != _request) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _rows = [];
        _loading = false;
        _error = '$error'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<List<Map<String, dynamic>>> _load(int tab, String query) async {
    final q = query.toLowerCase();
    if (tab == 1) return _features(q);
    if (tab == 4) {
      final data = await PostsApi.instance.request(
        '${PostsApi.instance.readPath}?limit=20&q=${Uri.encodeQueryComponent(query)}',
      );
      return (data['posts'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (tab == 0) {
      return CommunityApi.instance.list(
        '/people?q=${Uri.encodeQueryComponent(query)}',
      );
    }
    final kind = tab == 2 ? 'circles' : 'groups';
    final rows = await CommunityApi.instance.list('/$kind');
    return rows.where((row) {
      final text =
          '${row['name'] ?? ''} ${row['title'] ?? ''} ${row['description'] ?? ''}'
              .toLowerCase();
      return text.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> _features(String query) {
    final config = ExploreRepository.instance.current;
    final rows = <Map<String, dynamic>>[];
    for (final field in ['cards', 'quickLinks', 'links']) {
      for (final row in (config[field] as List? ?? const [])) {
        if (row is! Map || row['enabled'] == false) continue;
        final text = '${row['label'] ?? ''} ${row['subtitle'] ?? ''}'
            .toLowerCase();
        if (text.contains(query)) {
          rows.add(Map<String, dynamic>.from(row));
        }
      }
    }
    return rows;
  }

  Future<void> _follow(Map<String, dynamic> row) async {
    final id = '${row['_id']}';
    setState(() => _busy.add(id));
    try {
      await CommunityApi.instance.request(
        '/people/$id/follow',
        method: 'PUT',
        body: {
          'following':
              row['isFollowing'] != true && row['followRequested'] != true,
        },
      );
      if (mounted) await _run();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _openRoom(String kind, Map<String, dynamic> row) async {
    final member = row['membership'] == 'active' || row['canManage'] == true;
    if (!member) {
      final id = '${row['_id']}';
      setState(() => _busy.add(id));
      try {
        await CommunityApi.instance.request('/$kind/$id/join', method: 'POST');
        if (mounted) await _run();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
          );
        }
      } finally {
        if (mounted) setState(() => _busy.remove(id));
      }
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          title: '${row['name'] ?? row['title'] ?? ''}',
          image: '${row['iconImage'] ?? ''}',
          kind: kind,
          room: row,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tabsController.index;
    return ClubScaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      appBar: const ClubHeader(title: 'Search', showSearch: false),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('search-field'),
                      controller: _input,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => _schedule(),
                      decoration: InputDecoration(
                        hintText: 'Search Highlanders',
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, color: authRed),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabsController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: authRed,
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: authRed,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              tabs: [
                for (final label in _tabs)
                  Tab(key: ValueKey('search-tab-$label'), text: label),
              ],
            ),
            const Divider(height: 1),
            Expanded(child: _body(tab)),
          ],
        ),
      ),
    );
  }

  Widget _body(int tab) {
    if (_input.text.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Search people, features, huddles, groups and posts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: TextButton(onPressed: _run, child: Text('$_error. Retry')),
      );
    }
    if (_rows.isEmpty) {
      return Center(child: Text('No ${_tabs[tab].toLowerCase()} found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final row = _rows[index];
        if (tab == 0) return _person(row);
        if (tab == 1) return _feature(row);
        if (tab == 4) return _post(row);
        return _room(tab == 2 ? 'circles' : 'groups', row);
      },
    );
  }

  Widget _person(Map<String, dynamic> row) {
    final id = '${row['_id']}';
    final requested = row['followRequested'] == true;
    final following = row['isFollowing'] == true;
    return ListTile(
      key: ValueKey('search-person-$id'),
      leading: UserAvatar(
        userId: id,
        email: '${row['email'] ?? ''}',
        name: '${row['full_name'] ?? ''}',
        image: '${row['profile_photo'] ?? row['profileImage'] ?? ''}',
      ),
      title: Text('${row['full_name'] ?? 'Highlander'}'),
      subtitle: Text(
        [
          if ('${row['primary_sport'] ?? ''}'.isNotEmpty) row['primary_sport'],
          if ('${row['city'] ?? row['location'] ?? ''}'.isNotEmpty)
            row['city'] ?? row['location'],
          if (row['followsMe'] == true) 'Follows you',
        ].join(' · '),
      ),
      trailing: TextButton(
        onPressed: _busy.contains(id) ? null : () => _follow(row),
        child: Text(
          requested
              ? 'Requested'
              : following
              ? 'Following'
              : 'Follow',
        ),
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id))),
    );
  }

  Widget _feature(Map<String, dynamic> row) {
    return ListTile(
      key: ValueKey('search-feature-${row['id']}'),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFDECEC),
        child: Icon(Icons.auto_awesome_outlined, color: authRed),
      ),
      title: Text('${row['label'] ?? ''}'),
      subtitle: '${row['subtitle'] ?? ''}'.isEmpty
          ? null
          : Text('${row['subtitle']}'),
      onTap: () => openAppDestination(context, '${row['link'] ?? ''}'),
    );
  }

  Widget _room(String kind, Map<String, dynamic> row) {
    final id = '${row['_id']}';
    final member = row['membership'] == 'active' || row['canManage'] == true;
    return ListTile(
      key: ValueKey('search-$kind-$id'),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFDECEC),
        child: Icon(Icons.groups_outlined, color: authRed),
      ),
      title: Text('${row['name'] ?? row['title'] ?? ''}'),
      subtitle: Text('${row['memberCount'] ?? 0} members'),
      trailing: Text(member ? 'Open' : 'Join'),
      onTap: _busy.contains(id) ? null : () => _openRoom(kind, row),
    );
  }

  Widget _post(Map<String, dynamic> row) {
    final id = '${row['_id']}';
    final content = '${row['content'] ?? ''}'.trim();
    return ListTile(
      key: ValueKey('search-post-$id'),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFDECEC),
        child: Icon(Icons.article_outlined, color: authRed),
      ),
      title: Text('${row['authorName'] ?? 'Highlander'}'),
      subtitle: Text(
        content.isEmpty ? 'Photo or video' : content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id))),
    );
  }
}
