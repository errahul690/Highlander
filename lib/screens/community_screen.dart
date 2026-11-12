import '../brand_colors.dart';
import '../widgets/club_page_body.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/compose_icon.dart';

import '../widgets/user_avatar.dart';
import '../widgets/care_verified_badge.dart';
import '../widgets/support_hub_avatar.dart';
import '../widgets/unread_chat_badge.dart';

import '../community_api.dart';
import '../chat_updates.dart';
import '../realtime_client.dart';
import '../support_hub_repository.dart';
import '../theme.dart';
import '../widgets/community_icons.dart';
import '../widgets/invite_members_sheet.dart';
import 'chat_screen.dart';
import 'chat_settings_screen.dart' show chatPermissionItems;
import 'user_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    this.title = 'Huddles',
    this.initialIndex = 0,
    this.showBack = false,
    this.isActive = true,
  });
  final String title;
  final int initialIndex;
  final bool? showBack;
  final bool isActive;
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const _tabs = ['Huddles', 'Chats', 'Groups'];
  static const _icons = [
    CommunityIcons.circles,
    CommunityIcons.chats,
    CommunityIcons.groups,
  ];
  late int _tab;
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _rows;
  final _joining = <String>{};
  StreamSubscription<void>? _chatSubscription;
  StreamSubscription<Map<String, dynamic>>? _supportHub;
  bool _refreshingChats = false, _chatRefreshPending = false;
  String get _kind => _tab == 0 ? 'circles' : _tabs[_tab].toLowerCase();

  String _rowName(Map<String, dynamic> row) =>
      _tab == 1 && row['isCare'] == true
      ? SupportHubRepository.instance.name
      : '${row['name']}';

  void _onSupportHubName() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialIndex;
    SupportHubRepository.instance.addListener(_onSupportHubName);
    _reload();
    _chatSubscription = ChatUpdates.instance.changes.listen(
      (_) => _refreshChats(),
    );
    ChatUpdates.instance.acquire();
    _supportHub = RealtimeClient.instance.settingsChanges.listen((event) {
      if (event['resource'] == 'support-hub' || event['resource'] == 'all') {
        _refreshChats();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _refreshChats();
  }

  Future<void> _refreshChats() async {
    if (!mounted || _tab != 1) return;
    if (_refreshingChats) {
      _chatRefreshPending = true;
      return;
    }
    _refreshingChats = true;
    try {
      do {
        _chatRefreshPending = false;
        final rows = await CommunityApi.instance.list('/chats');
        if (mounted && _tab == 1) {
          setState(() {
            _rows = Future.value(rows);
          });
        }
      } while (mounted && _tab == 1 && _chatRefreshPending);
    } catch (_) {
      // Keep the current list; reconnect or pull-to-refresh retries failures.
    } finally {
      _refreshingChats = false;
    }
  }

  @override
  void dispose() {
    SupportHubRepository.instance.removeListener(_onSupportHubName);
    _chatSubscription?.cancel();
    _supportHub?.cancel();
    ChatUpdates.instance.release();
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _rows = CommunityApi.instance.list('/$_kind');
    if (_tab == 1) ChatUpdates.instance.refreshUnreadCount();
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (_tab != 1 &&
        row['membership'] != 'active' &&
        row['canManage'] != true) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          title: _rowName(row),
          image: '${row['iconImage'] ?? ''}',
          recipientEmail: _tab == 1 ? row['email'] as String : null,
          isCare: _tab == 1 && row['isCare'] == true,
          kind: _tab == 1 ? null : _kind,
          room: _tab == 1 ? null : row,
        ),
      ),
    );
    if (mounted) {
      if (_tab == 1) {
        await _refreshChats();
      } else {
        setState(_reload);
      }
      ChatUpdates.instance.refreshUnreadCount();
    }
  }

  Future<void> _join(Map<String, dynamic> row) async {
    final id = '${row['_id']}';
    setState(() => _joining.add(id));
    try {
      await CommunityApi.instance.request('/$_kind/$id/join', method: 'POST');
      if (mounted) setState(_reload);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _joining.remove(id));
    }
  }

  Future<void> _createGroup() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const _CreateGroup(),
    );
    if (created != null && mounted) {
      setState(_reload);
      await _open(created);
    }
  }

  Future<void> _newChat() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CommunityPeopleScreen()));
    if (mounted) setState(_reload);
  }

  Future<void> _confirmDeleteGroup(Map<String, dynamic> row) async {
    final id = '${row['_id']}';
    final name = '${row['name']}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete group',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "$name"? All messages and group data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: brandAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await CommunityApi.instance.request('/groups/$id', method: 'DELETE');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Group "$name" deleted')));
          setState(_reload);
        }
      } catch (error) {
        _error(error);
      }
    }
  }

  Future<void> _confirmLeaveGroup(Map<String, dynamic> row) async {
    final id = '${row['_id']}';
    final name = '${row['name']}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave group',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('Are you sure you want to leave "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: brandAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await CommunityApi.instance.request(
          '/groups/$id/leave',
          method: 'POST',
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Left "$name"')));
          setState(_reload);
        }
      } catch (error) {
        _error(error);
      }
    }
  }

  Widget _header() => ClubHeader(
    title: widget.title,
    embedded: true,
    showBack: false,
    showSearch: false,
    showNotifications: false,
    trailing: [
      if (_tab == 1)
        IconButton(
          key: const ValueKey('header-new-chat'),
          tooltip: 'New chat',
          constraints: const BoxConstraints.tightFor(width: 34, height: 40),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(34, 40),
            padding: EdgeInsets.zero,
          ),
          padding: EdgeInsets.zero,
          onPressed: _newChat,
          icon: const ComposeIcon(size: 30),
        ),
      if (_tab == 2)
        IconButton(
          key: const ValueKey('header-create-group'),
          tooltip: 'Create group',
          constraints: const BoxConstraints.tightFor(width: 32, height: 40),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(32, 40),
            padding: EdgeInsets.zero,
          ),
          padding: EdgeInsets.zero,
          onPressed: _createGroup,
          icon: const Icon(Icons.group_add_outlined, size: 22),
        ),
    ],
  );

  Widget _tabsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: _tab == i ? brandAccent : Colors.white,
                elevation: _tab == i ? 2 : 0,
                shadowColor: const Color(0x33C82D22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: _tab == i
                        ? brandAccent
                        : const Color(0xFFE5E7EB),
                    width: 1.2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    setState(() {
                      _tab = i;
                      _search.clear();
                      _reload();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ImageIcon(
                            _icons[i],
                            size: 18,
                            color: _tab == i
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _tabs[i],
                            style: TextStyle(
                              color: _tab == i
                                  ? Colors.white
                                  : const Color(0xFF4B5563),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (i == 1)
                            ValueListenableBuilder<int>(
                              valueListenable: ChatUpdates.instance.unreadCount,
                              builder: (_, count, __) => count > 0
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: UnreadChatBadge(
                                        count: count,
                                        inverted: _tab == 1,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: 'Search ${_tab == 0 ? 'huddles' : _kind}...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: const Icon(
              Icons.search,
              color: brandAccent,
              size: 20,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    if (_search.text.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            'No results found for "${_search.text.trim()}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        ),
      );
    }
    if (_tab == 2) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/groups-empty.png',
                key: const ValueKey('groups-empty-illustration'),
                width: 320,
                height: 212,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'No groups yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Create a group to plan sessions, organise matches, and keep your football crew together.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                key: const ValueKey('empty-create-group'),
                onPressed: _createGroup,
                icon: const Icon(
                  Icons.group_add,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'Create Group',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: const Color(0x3DC82D22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_tab == 1) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE8E7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: brandAccent,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No chats yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start a conversation with fellow Highlanders using New chat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _newChat,
                icon: const ComposeIcon(size: 18, color: Colors.white),
                label: const Text(
                  'New chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFFDE8E7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_outlined,
                color: brandAccent,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No huddles yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Huddles will appear here when an admin creates them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupTile(Map<String, dynamic> row) {
    final name = '${row['name']}';
    final id = '${row['_id']}';
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: const Color(0xFFF7E4EB),
        foregroundImage: row['image'] != null && '${row['image']}'.isNotEmpty
            ? NetworkImage('${row['image']}')
            : null,
        child: const Icon(Icons.groups_outlined, color: brandAccent),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${row['memberCount'] ?? 0} members'),
      onTap: () => _open(row),
      trailing: row['canManage'] == true || row['canInvite'] == true
          ? IconButton(
              tooltip: 'Add members',
              icon: const Icon(
                Icons.person_add_alt_1,
                color: brandAccent,
              ),
              onPressed: () => InviteMembersSheet.show(
                context,
                roomId: id,
                roomTitle: name,
                kind: 'groups',
              ),
            )
          : null,
    );
  }

  Widget _huddleAvatar(Map<String, dynamic> row, String name) {
    final image =
        '${row['iconImage'] ?? row['image'] ?? row['profile_photo'] ?? row['profileImage'] ?? ''}'
            .trim();
    if (image.isEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: const Color(0xFFFDE8E7),
        child: ImageIcon(_icons[0], color: brandAccent, size: 26),
      );
    }
    return UserAvatar(
      name: name,
      image: image,
      radius: 25,
      backgroundColor: const Color(0xFFFDE8E7),
      foregroundColor: brandAccent,
    );
  }

  Widget _circleTile(Map<String, dynamic> row) {
    final name = '${row['name']}';
    final id = '${row['_id']}';
    final joined = row['membership'] == 'active' || row['canManage'] == true;
    final pending = row['membership'] == 'pending';
    final memberCount = row['memberCount'] ?? 0;
    final description = '${row['description'] ?? ''}'.trim();
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: _huddleAvatar(row, name),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          subtitle: Text(
            '$memberCount members${description.isNotEmpty ? ' · $description' : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          trailing: joined
              ? null
              : pending
              ? const Text(
                  'Requested',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: brandAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    minimumSize: const Size(60, 32),
                  ),
                  onPressed: _joining.contains(id) ? null : () => _join(row),
                  child: Text(
                    _joining.contains(id) ? 'Joining…' : 'Join',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          onTap: () => _open(row),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 68, right: 16),
          child: Divider(height: 1, color: Color(0xFFF3F4F6)),
        ),
      ],
    );
  }

  Widget _chatTile(Map<String, dynamic> row) {
    final name = _rowName(row);
    final content = '${row['content'] ?? ''}';
    final unread = (row['unreadCount'] as num?)?.toInt() ?? 0;
    return Column(
      children: [
        ListTile(
          tileColor: unread > 0 ? const Color(0xFFFFF5F4) : null,
          trailing: unread > 0
              ? UnreadChatBadge(
                  key: ValueKey('unread-${row['email']}'),
                  count: unread,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: row['isCare'] == true
              ? const SupportHubAvatar()
              : UserAvatar(
                  email: '${row['email'] ?? ''}',
                  name: name,
                  image: '${row['iconImage'] ?? ''}',
                  radius: 25,
                ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (row['isCare'] == true) ...[
                const SizedBox(width: 6),
                const CareVerifiedBadge(),
              ],
            ],
          ),
          subtitle: Text(
            content.isNotEmpty ? content : 'Tap to start conversation',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: unread > 0
                  ? const Color(0xFF111827)
                  : const Color(0xFF6B7280),
              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          onTap: () => _open(row),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 68, right: 16),
          child: Divider(height: 1, color: Color(0xFFF3F4F6)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Column(
      children: [
        _header(),
        Expanded(
          child: ClubPageBody(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tabsBar(),
                _searchBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _rows,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: brandAccent,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Could not load community.'),
                              TextButton(
                                onPressed: () => setState(_reload),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }
                      final query = _search.text.trim().toLowerCase();
                      final allRows = snapshot.data ?? [];
                      final rows = allRows
                          .where(
                            (row) =>
                                _tab != 2 ||
                                row['membership'] == 'active' ||
                                row['canManage'] == true,
                          )
                          .where(
                            (row) =>
                                _rowName(row).toLowerCase().contains(query),
                          )
                          .toList();

                      if (rows.isEmpty) {
                        return LayoutBuilder(
                          builder: (context, constraints) => RefreshIndicator(
                            onRefresh: () async {
                              setState(_reload);
                              await _rows;
                            },
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Center(child: _emptyState()),
                              ),
                            ),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(_reload);
                          await _rows;
                        },
                        child: _tab == 2
                            ? _buildGroupsView(rows)
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  0,
                                  4,
                                  0,
                                  MediaQuery.paddingOf(context).bottom + 180,
                                ),
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final row = rows[index];
                                  return _tab == 1
                                      ? _chatTile(row)
                                      : _circleTile(row);
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildGroupsView(List<Map<String, dynamic>> rows) => ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.only(
      top: 4,
      bottom: MediaQuery.paddingOf(context).bottom + 180,
    ),
    itemCount: rows.length,
    itemBuilder: (context, index) => _groupTile(rows[index]),
  );
}

class _CreateGroup extends StatefulWidget {
  const _CreateGroup();
  @override
  State<_CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<_CreateGroup> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false, _allowMemberInvites = false;
  String _permission = 'all';
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a group name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await CommunityApi.instance.request(
        '/groups',
        method: 'POST',
        body: {
          'name': _name.text.trim(),
          'description': _description.text.trim(),
          'autoApprove': false,
          'allowMemberInvites': _allowMemberInvites,
          'chatPermission': _permission,
        },
      );
      if (mounted) {
        Navigator.of(context).pop(Map<String, dynamic>.from(row as Map));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _field(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF7F5F9),
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE9E2EA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE9E2EA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: brandAccent),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .94,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5DFE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7E4EB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.group_add_outlined,
                        color: brandAccent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Create a group',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF171717),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bring your football crew together.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF737584)),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  maxLength: 80,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: _field('Group name', 'Give your crew a name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 4,
                  enabled: !_busy,
                  decoration: _field(
                    'Description',
                    'What is this group about?',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _permission,
                  isExpanded: true,
                  decoration: _field('Who can send messages?', ''),
                  items: chatPermissionItems,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _permission = value!),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: brandAccent,
                  title: const Text(
                    'Members can invite',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Let members add people to the group.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _allowMemberInvites,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _allowMemberInvites = value),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: authRed),
                    ),
                  ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: brandAccent,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add, size: 20),
                  label: Text(
                    _busy ? 'Creating...' : 'Create group',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class CommunityPeopleScreen extends StatefulWidget {
  const CommunityPeopleScreen({
    super.key,
    this.title = 'New chat',
    this.relation,
    this.showBack = false,
    this.initialQuery = '',
  });
  final String title;
  final String? relation;
  final bool showBack;
  final String initialQuery;
  @override
  State<CommunityPeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<CommunityPeopleScreen> {
  final _search = TextEditingController();
  final _followingBusy = <String>{};
  Future<void> _follow(Map<String, dynamic> row) async {
    final id = '${row['_id']}';
    setState(() => _followingBusy.add(id));
    try {
      await CommunityApi.instance.request(
        '/people/$id/follow',
        method: 'PUT',
        body: {
          'following':
              row['isFollowing'] != true && row['followRequested'] != true,
        },
      );
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _followingBusy.remove(id));
    }
  }

  late Future<List<Map<String, dynamic>>> _people;
  @override
  void initState() {
    super.initState();
    _search.text = widget.initialQuery;
    _load();
  }

  void _load() {
    _people = CommunityApi.instance.list(
      '/people?q=${Uri.encodeComponent(_search.text.trim())}${widget.relation == null ? '' : '&relation=${widget.relation}'}',
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClubScaffold(
    backgroundColor: Colors.white,
    appBar: ClubHeader(title: widget.title, showBack: false),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => setState(_load),
            decoration: InputDecoration(
              hintText: 'Search people by name',
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: () => setState(_load),
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _people,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(_load),
                    child: const Text('Could not load people. Retry'),
                  ),
                );
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.relation == 'following'
                            ? 'You are not following anyone yet.'
                            : widget.relation == 'followers'
                            ? 'No followers yet.'
                            : 'No people found.',
                      ),
                      TextButton(
                        onPressed: () => setState(_load),
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                );
              }
              return ListView(
                children: [
                  for (final row in rows)
                    ListTile(
                      leading: UserAvatar(
                        userId: '${row['_id'] ?? ''}',
                        email: '${row['email'] ?? ''}',
                        name: '${row['full_name'] ?? ''}',
                        image:
                            '${row['profile_photo'] ?? row['profileImage'] ?? ''}',
                      ),
                      title: Text('${row['full_name'] ?? 'Highlander'}'),
                      subtitle: row['followsMe'] == true
                          ? const Text('Follows you')
                          : null,
                      trailing: TextButton(
                        onPressed: _followingBusy.contains('${row['_id']}')
                            ? null
                            : () => _follow(row),
                        child: Text(
                          row['followRequested'] == true
                              ? 'Requested'
                              : row['isFollowing'] == true
                              ? 'Unfollow'
                              : 'Follow',
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfileScreen(userId: '${row['_id']}'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
