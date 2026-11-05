import '../widgets/club_page_body.dart';

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/compose_icon.dart';

import '../widgets/user_avatar.dart';
import '../widgets/care_verified_badge.dart';
import '../widgets/unread_chat_badge.dart';

import '../community_api.dart';
import '../chat_updates.dart';
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
    this.showBack,
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
  bool _refreshingChats = false, _chatRefreshPending = false;
  String get _kind => _tab == 0 ? 'circles' : _tabs[_tab].toLowerCase();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialIndex;
    _reload();
    _chatSubscription = ChatUpdates.instance.changes.listen(
      (_) => _refreshChats(),
    );
    ChatUpdates.instance.acquire();
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
    _chatSubscription?.cancel();
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
          title: '${row['name']}',
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

  Future<void> _decline(Map<String, dynamic> row) async {
    final id = '${row['_id']}';
    setState(() => _joining.add(id));
    try {
      await CommunityApi.instance.request('/$_kind/$id/leave', method: 'POST');
    } catch (_) {
      // Allow graceful UI dismissal
    } finally {
      if (mounted) {
        setState(() {
          _joining.remove(id);
          _reload();
        });
      }
    }
  }

  Future<void> _createGroup() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
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
              backgroundColor: const Color(0xFFC82D22),
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
              backgroundColor: const Color(0xFFC82D22),
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
    showBack: widget.showBack ?? Navigator.of(context).canPop(),
    showProfile: false,
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
                color: _tab == i ? const Color(0xFFC82D22) : Colors.white,
                elevation: _tab == i ? 2 : 0,
                shadowColor: const Color(0x33C82D22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: _tab == i
                        ? const Color(0xFFC82D22)
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
              color: Color(0xFFC82D22),
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
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _FootballCrewIllustration(),
              const SizedBox(height: 24),
              const Text(
                'No groups yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
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
                  'Create group',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC82D22),
                  foregroundColor: Colors.white,
                  elevation: 3,
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
                  color: Color(0xFFC82D22),
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
                  backgroundColor: const Color(0xFFC82D22),
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
                color: Color(0xFFC82D22),
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

  Widget _groupTile(
    Map<String, dynamic> row, {
    required bool isInvitation,
    bool isDiscover = false,
  }) {
    final name = '${row['name']}';
    final id = '${row['_id']}';
    final isJoined = row['membership'] == 'active' || row['canManage'] == true;
    final subtitle1 = isInvitation
        ? 'Invited by ${row['creatorName'] ?? row['creatorEmail']?.split('@').first ?? 'Highlander'}'
        : null;
    return InkWell(
      onTap: isInvitation || isDiscover ? null : () => _open(row),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFFFDE8E7),
                  foregroundImage:
                      row['image'] != null && '${row['image']}'.isNotEmpty
                      ? NetworkImage('${row['image']}')
                      : null,
                  child: const Icon(
                    Icons.sports_soccer,
                    color: Color(0xFFC82D22),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (subtitle1 != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isInvitation) ...[
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC82D22),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      minimumSize: const Size(60, 32),
                    ),
                    onPressed: _joining.contains(id) ? null : () => _join(row),
                    child: Text(
                      _joining.contains(id) ? '…' : 'Accept',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC82D22),
                      side: const BorderSide(color: Color(0xFFC82D22)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: const Size(60, 32),
                    ),
                    onPressed: _joining.contains(id)
                        ? null
                        : () => _decline(row),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (isDiscover) ...[
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC82D22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      minimumSize: const Size(64, 32),
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
                ] else if (isJoined) ...[
                  IconButton(
                    tooltip: 'Invite members',
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      color: Color(0xFFC82D22),
                      size: 20,
                    ),
                    onPressed: () => InviteMembersSheet.show(
                      context,
                      roomId: id,
                      roomTitle: name,
                      kind: 'groups',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 68, right: 16),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
        ],
      ),
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
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFFDE8E7),
            child: ImageIcon(
              _icons[0],
              color: const Color(0xFFC82D22),
              size: 26,
            ),
          ),
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
                    backgroundColor: const Color(0xFFC82D22),
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
    final name = '${row['name']}';
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
          leading: UserAvatar(
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
                            color: Color(0xFFC82D22),
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
                                '${row['name']}'.toLowerCase().contains(query),
                          )
                          .toList();

                      if (rows.isEmpty) {
                        return RefreshIndicator(
                          onRefresh: () async {
                            setState(_reload);
                            await _rows;
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [_emptyState()],
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

  Widget _buildGroupsView(List<Map<String, dynamic>> rows) {
    final yourGroups = rows
        .where((r) => r['membership'] == 'active' || r['canManage'] == true)
        .toList();
    final invitations = rows
        .where((r) => r['membership'] == 'pending')
        .toList();
    final discover = rows
        .where(
          (r) =>
              r['membership'] != 'active' &&
              r['membership'] != 'pending' &&
              r['canManage'] != true,
        )
        .toList();

    final showHeaders = invitations.isNotEmpty || discover.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        0,
        4,
        0,
        MediaQuery.paddingOf(context).bottom + 180,
      ),
      children: [
        if (yourGroups.isNotEmpty) ...[
          if (showHeaders)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                'Your groups',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          for (final group in yourGroups)
            _groupTile(group, isInvitation: false),
        ],
        if (invitations.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              'Invitations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          for (final group in invitations)
            _groupTile(group, isInvitation: true),
        ],
        if (discover.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              'Discover groups',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          for (final group in discover)
            _groupTile(group, isInvitation: false, isDiscover: true),
        ],
      ],
    );
  }
}

class _CreateGroup extends StatefulWidget {
  const _CreateGroup();
  @override
  State<_CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<_CreateGroup> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _auto = false, _busy = false;
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
          'autoApprove': _auto,
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Create group'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                maxLength: 80,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Group name'),
              ),
              TextField(
                controller: _description,
                maxLength: 500,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto approve requests'),
                value: _auto,
                onChanged: _busy ? null : (v) => setState(() => _auto = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: _permission,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Who can send messages?',
                ),
                items: chatPermissionItems,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _permission = v!),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: authRed)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: Text(_busy ? 'Creating…' : 'Create'),
        ),
      ],
    ),
  );
}

class CommunityPeopleScreen extends StatefulWidget {
  const CommunityPeopleScreen({
    super.key,
    this.title = 'New chat',
    this.relation,
    this.showBack = true,
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
    appBar: ClubHeader(title: widget.title, showBack: widget.showBack),
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

class _FootballCrewIllustration extends StatelessWidget {
  const _FootballCrewIllustration();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 150),
      painter: _FootballCrewPainter(),
    );
  }
}

class _FootballCrewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFFC82D22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFFC82D22)
      ..style = PaintingStyle.fill;

    final double cx = size.width / 2;
    const double groundY = 136;

    // Dashed ground baseline
    double startX = cx - 74;
    const double dashW = 4.5;
    const double spaceW = 3.5;
    while (startX < cx + 74) {
      canvas.drawLine(
        Offset(startX, groundY),
        Offset(math.min(startX + dashW, cx + 74), groundY),
        strokePaint,
      );
      startX += dashW + spaceW;
    }

    // --- Center Player (Player 2) ---
    const double cHeadY = groundY - 96;
    // Head & hair
    canvas.drawCircle(Offset(cx, cHeadY), 10, strokePaint);
    final cHair = Path()
      ..moveTo(cx - 9, cHeadY - 3)
      ..cubicTo(cx - 8, cHeadY - 14, cx + 8, cHeadY - 14, cx + 9, cHeadY - 3)
      ..close();
    canvas.drawPath(cHair, fillPaint);

    // Torso / Jersey
    final cJersey = Path()
      ..moveTo(cx - 15, groundY - 80)
      ..lineTo(cx - 13, groundY - 50)
      ..lineTo(cx + 13, groundY - 50)
      ..lineTo(cx + 15, groundY - 80)
      ..close();
    canvas.drawPath(cJersey, strokePaint);
    // V-neck
    canvas.drawLine(
      Offset(cx - 4, groundY - 80),
      Offset(cx, groundY - 74),
      strokePaint,
    );
    canvas.drawLine(
      Offset(cx + 4, groundY - 80),
      Offset(cx, groundY - 74),
      strokePaint,
    );

    // Arms around left and right teammate
    // Left arm
    final cArmL = Path()
      ..moveTo(cx - 15, groundY - 80)
      ..quadraticBezierTo(cx - 30, groundY - 84, cx - 40, groundY - 78);
    canvas.drawPath(cArmL, strokePaint);
    // Right arm
    final cArmR = Path()
      ..moveTo(cx + 15, groundY - 80)
      ..quadraticBezierTo(cx + 30, groundY - 84, cx + 40, groundY - 78);
    canvas.drawPath(cArmR, strokePaint);

    // Shorts
    final cShorts = Path()
      ..moveTo(cx - 13, groundY - 50)
      ..lineTo(cx - 15, groundY - 34)
      ..lineTo(cx - 2, groundY - 34)
      ..lineTo(cx, groundY - 40)
      ..lineTo(cx + 2, groundY - 34)
      ..lineTo(cx + 15, groundY - 34)
      ..lineTo(cx + 13, groundY - 50)
      ..close();
    canvas.drawPath(cShorts, strokePaint);

    // Legs & Cleats
    // Left leg
    canvas.drawLine(
      Offset(cx - 10, groundY - 34),
      Offset(cx - 10, groundY - 14),
      strokePaint,
    );
    canvas.drawLine(
      Offset(cx - 5, groundY - 34),
      Offset(cx - 5, groundY - 14),
      strokePaint,
    );
    canvas.drawLine(
      Offset(cx - 10, groundY - 18),
      Offset(cx - 5, groundY - 18),
      strokePaint,
    ); // sock
    canvas.drawRect(Rect.fromLTWH(cx - 12, groundY - 5, 8, 5), fillPaint);
    // Right leg
    canvas.drawLine(
      Offset(cx + 5, groundY - 34),
      Offset(cx + 5, groundY - 14),
      strokePaint,
    );
    canvas.drawLine(
      Offset(cx + 10, groundY - 34),
      Offset(cx + 10, groundY - 14),
      strokePaint,
    );
    canvas.drawLine(
      Offset(cx + 5, groundY - 18),
      Offset(cx + 10, groundY - 18),
      strokePaint,
    ); // sock
    canvas.drawRect(Rect.fromLTWH(cx + 4, groundY - 5, 8, 5), fillPaint);

    // --- Left Player (Player 1) ---
    final double lHeadX = cx - 38;
    const double lHeadY = groundY - 90;
    canvas.drawCircle(Offset(lHeadX, lHeadY), 9.5, strokePaint);
    final lHair = Path()
      ..moveTo(lHeadX - 9, lHeadY - 2)
      ..cubicTo(
        lHeadX - 8,
        lHeadY - 13,
        lHeadX + 8,
        lHeadY - 13,
        lHeadX + 9,
        lHeadY - 2,
      )
      ..close();
    canvas.drawPath(lHair, fillPaint);

    // Left player Jersey
    final lJersey = Path()
      ..moveTo(lHeadX - 14, groundY - 74)
      ..lineTo(lHeadX - 12, groundY - 47)
      ..lineTo(lHeadX + 12, groundY - 47)
      ..lineTo(lHeadX + 14, groundY - 74)
      ..close();
    canvas.drawPath(lJersey, strokePaint);
    // Outer arm bent
    final lArmOuter = Path()
      ..moveTo(lHeadX - 14, groundY - 74)
      ..lineTo(lHeadX - 20, groundY - 58)
      ..lineTo(lHeadX - 12, groundY - 50);
    canvas.drawPath(lArmOuter, strokePaint);

    // Left player shorts
    final lShorts = Path()
      ..moveTo(lHeadX - 12, groundY - 47)
      ..lineTo(lHeadX - 14, groundY - 32)
      ..lineTo(lHeadX - 2, groundY - 32)
      ..lineTo(lHeadX, groundY - 38)
      ..lineTo(lHeadX + 2, groundY - 32)
      ..lineTo(lHeadX + 14, groundY - 32)
      ..lineTo(lHeadX + 12, groundY - 47)
      ..close();
    canvas.drawPath(lShorts, strokePaint);

    // Left player legs & boots
    canvas.drawLine(
      Offset(lHeadX - 9, groundY - 32),
      Offset(lHeadX - 9, groundY - 12),
      strokePaint,
    );
    canvas.drawLine(
      Offset(lHeadX - 4, groundY - 32),
      Offset(lHeadX - 4, groundY - 12),
      strokePaint,
    );
    canvas.drawRect(Rect.fromLTWH(lHeadX - 11, groundY - 5, 8, 5), fillPaint);

    canvas.drawLine(
      Offset(lHeadX + 4, groundY - 32),
      Offset(lHeadX + 4, groundY - 12),
      strokePaint,
    );
    canvas.drawLine(
      Offset(lHeadX + 9, groundY - 32),
      Offset(lHeadX + 9, groundY - 12),
      strokePaint,
    );
    canvas.drawRect(Rect.fromLTWH(lHeadX + 3, groundY - 5, 8, 5), fillPaint);

    // --- Right Player (Player 3) ---
    final double rHeadX = cx + 38;
    const double rHeadY = groundY - 90;
    canvas.drawCircle(Offset(rHeadX, rHeadY), 9.5, strokePaint);
    final rHair = Path()
      ..moveTo(rHeadX - 9, rHeadY - 2)
      ..cubicTo(
        rHeadX - 8,
        rHeadY - 13,
        rHeadX + 8,
        rHeadY - 13,
        rHeadX + 9,
        rHeadY - 2,
      )
      ..close();
    canvas.drawPath(rHair, fillPaint);

    // Right player Jersey
    final rJersey = Path()
      ..moveTo(rHeadX - 14, groundY - 74)
      ..lineTo(rHeadX - 12, groundY - 47)
      ..lineTo(rHeadX + 12, groundY - 47)
      ..lineTo(rHeadX + 14, groundY - 74)
      ..close();
    canvas.drawPath(rJersey, strokePaint);
    // Outer arm bent
    final rArmOuter = Path()
      ..moveTo(rHeadX + 14, groundY - 74)
      ..lineTo(rHeadX + 20, groundY - 58)
      ..lineTo(rHeadX + 12, groundY - 50);
    canvas.drawPath(rArmOuter, strokePaint);

    // Right player shorts
    final rShorts = Path()
      ..moveTo(rHeadX - 12, groundY - 47)
      ..lineTo(rHeadX - 14, groundY - 32)
      ..lineTo(rHeadX - 2, groundY - 32)
      ..lineTo(rHeadX, groundY - 38)
      ..lineTo(rHeadX + 2, groundY - 32)
      ..lineTo(rHeadX + 14, groundY - 32)
      ..lineTo(rHeadX + 12, groundY - 47)
      ..close();
    canvas.drawPath(rShorts, strokePaint);

    // Right player legs & boots
    canvas.drawLine(
      Offset(rHeadX - 9, groundY - 32),
      Offset(rHeadX - 9, groundY - 12),
      strokePaint,
    );
    canvas.drawLine(
      Offset(rHeadX - 4, groundY - 32),
      Offset(rHeadX - 4, groundY - 12),
      strokePaint,
    );
    canvas.drawRect(Rect.fromLTWH(rHeadX - 11, groundY - 5, 8, 5), fillPaint);

    canvas.drawLine(
      Offset(rHeadX + 4, groundY - 32),
      Offset(rHeadX + 4, groundY - 12),
      strokePaint,
    );
    canvas.drawLine(
      Offset(rHeadX + 9, groundY - 32),
      Offset(rHeadX + 9, groundY - 12),
      strokePaint,
    );
    canvas.drawRect(Rect.fromLTWH(rHeadX + 3, groundY - 5, 8, 5), fillPaint);

    // --- Football at Center feet ---
    final double ballX = cx - 1;
    const double ballY = groundY - 9;
    const double ballR = 9.0;
    canvas.drawCircle(Offset(ballX, ballY), ballR, strokePaint);
    // Ball inner pentagon
    final pentagon = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * math.pi / 180;
      final px = ballX + 4.2 * math.cos(angle);
      final py = ballY + 4.2 * math.sin(angle);
      if (i == 0) {
        pentagon.moveTo(px, py);
      } else {
        pentagon.lineTo(px, py);
      }
    }
    pentagon.close();
    canvas.drawPath(pentagon, fillPaint);
    // Radiating lines from pentagon to perimeter
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * math.pi / 180;
      final px1 = ballX + 4.2 * math.cos(angle);
      final py1 = ballY + 4.2 * math.sin(angle);
      final px2 = ballX + ballR * math.cos(angle);
      final py2 = ballY + ballR * math.sin(angle);
      canvas.drawLine(Offset(px1, py1), Offset(px2, py2), strokePaint);
    }

    // --- Radiating burst celebration lines ---
    // Left burst
    canvas.drawLine(
      Offset(cx - 58, groundY - 94),
      Offset(cx - 67, groundY - 100),
      strokePaint,
    );
    canvas.drawLine(
      Offset(cx - 62, groundY - 82),
      Offset(cx - 72, groundY - 84),
      strokePaint,
    );
    canvas.drawLine(
      Offset(cx - 60, groundY - 70),
      Offset(cx - 70, groundY - 69),
      strokePaint,
    );
    // Right burst
    canvas.drawLine(
      Offset(cx + 58, groundY - 94),
      Offset(cx + 67, groundY - 100),
      strokePaint,
    );
    canvas.drawLine(
      Offset(cx + 62, groundY - 82),
      Offset(cx + 72, groundY - 84),
      strokePaint,
    );
    canvas.drawLine(
      Offset(cx + 60, groundY - 70),
      Offset(cx + 70, groundY - 69),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
