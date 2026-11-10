import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../app_navigation.dart';
import '../chat_updates.dart';
import '../club_repository.dart';
import '../community_api.dart';
import '../notification_router.dart';
import '../otp_api.dart';
import '../session.dart';
import '../support_hub_repository.dart';
import '../theme.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'friends_screen.dart';
import 'post_detail_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _unreadCount = 0;
  String _filter = 'all'; // 'all', 'unread', 'invites', 'messages'
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _connect();
  }

  void _connect() {
    if (Session.token.isEmpty) return;
    _socket = io.io(
      OtpApi.apiBase,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': Session.token})
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _socket!.on('notification:new', (dynamic value) {
      if (value is! Map || !mounted) return;
      final item = Map<String, dynamic>.from(value);
      if ('${item['type']}' == 'direct_message') return;
      setState(() {
        _items.removeWhere((row) => row['_id'] == item['_id']);
        _items.insert(0, item);
        _unreadCount++;
      });
      ChatUpdates.instance.noteUnreadNotifications(_unreadCount);
    });
    _socket!.onConnect((_) => _load());
    _socket!.connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _socket?.connect();
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = Map<String, dynamic>.from(
        await CommunityApi.instance.request('/notifications') as Map,
      );
      if (!mounted) return;
      setState(() {
        _items = (result['items'] as List? ?? const [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .where((row) => '${row['type']}' != 'direct_message')
            .toList();
        _unreadCount = result['unreadCount'] is num
            ? (result['unreadCount'] as num).toInt()
            : _items.where((row) => row['read'] != true).length;
        _error = null;
      });
      ChatUpdates.instance.noteUnreadNotifications(_unreadCount);
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0) return;
    try {
      await CommunityApi.instance.request('/notifications/read', method: 'PUT');
      if (mounted) {
        setState(() {
          _unreadCount = 0;
          for (final item in _items) {
            item['read'] = true;
          }
        });
        ChatUpdates.instance.noteUnreadNotifications(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$error'.replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    if (item['read'] != true) {
      setState(() {
        item['read'] = true;
        if (_unreadCount > 0) _unreadCount--;
      });
      ChatUpdates.instance.noteUnreadNotifications(_unreadCount);
      CommunityApi.instance
          .request('/notifications/${item['_id']}/read', method: 'PUT')
          .catchError((_) => null);
    }
    if (!mounted) return;
    final type = '${item['type'] ?? ''}';
    final metadata = item['metadata'] is Map
        ? Map<String, dynamic>.from(item['metadata'] as Map)
        : <String, dynamic>{};
    if (type == 'group_join_request') {
      await NotificationRouter.followMap(context, {
        'kind': type,
        'groupId': metadata['groupId'],
        'roomKind': metadata['kind'] ?? 'groups',
      });
      return;
    }
    if (type == 'group_invite') {
      final groupId = '${metadata['groupId'] ?? ''}';
      final roomName = '${metadata['roomName'] ?? 'Group'}';
      if (groupId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              title: roomName,
              kind: '${metadata['kind'] ?? 'groups'}',
              room: {
                '_id': groupId,
                'name': roomName,
                'membership': 'active',
              },
            ),
          ),
        );
        return;
      }
    }
    if (type == 'direct_message') {
      final email = '${metadata['senderEmail'] ?? item['actorEmail'] ?? ''}';
      if (email.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              title: '${item['actorName'] ?? item['title'] ?? 'Chat'}',
              recipientEmail: email,
              isCare:
                  metadata['isCare'] == true ||
                  item['title'] == 'Highlander Care' ||
                  item['title'] == SupportHubRepository.instance.name ||
                  item['title'] == 'Admin chat',
            ),
          ),
        );
      }
      return;
    }
    if (type == 'match_stage' || type == 'match_update') {
      final matchId = '${metadata['matchId'] ?? ''}';
      if (matchId.isNotEmpty) {
        await NotificationRouter.openMatch(context, matchId);
        return;
      }
    }
    if (type == 'follow_request') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const FriendsScreen(title: 'Friends', initialTab: 1),
        ),
      );
      return;
    }
    final postId = '${metadata['postId'] ?? ''}';
    if (postId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
      );
      return;
    }
    await openAppDestination(context, '${item['link'] ?? ''}');
  }

  IconData _icon(String type) {
    switch (type) {
      case 'group_invite':
        return Icons.group_add_rounded;
      case 'direct_message':
        return Icons.chat_bubble_rounded;
      case 'post_like':
      case 'comment_like':
        return Icons.favorite_rounded;
      case 'post_comment':
      case 'post_reply':
      case 'comment_reply':
        return Icons.forum_rounded;
      case 'match_update':
      case 'match_stage':
        return Icons.sports_soccer_rounded;
      case 'following_post':
        return Icons.article_rounded;
      default:
        if (type.startsWith('follow')) return Icons.person_add_rounded;
        return Icons.notifications_active_rounded;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'group_invite':
        return const Color(0xFFBA0C12);
      case 'direct_message':
        return const Color(0xFF2563EB);
      case 'post_like':
      case 'comment_like':
        return const Color(0xFFE11D48);
      case 'post_comment':
      case 'post_reply':
      case 'comment_reply':
        return const Color(0xFF0D9488);
      case 'match_update':
        return const Color(0xFF059669);
      default:
        if (type.startsWith('follow')) return const Color(0xFF7C3AED);
        return const Color(0xFFD97706);
    }
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'group_invite':
        return const Color(0xFFFFECEB);
      case 'direct_message':
        return const Color(0xFFEFF6FF);
      case 'post_like':
      case 'comment_like':
        return const Color(0xFFFFEEF2);
      case 'post_comment':
      case 'post_reply':
      case 'comment_reply':
        return const Color(0xFFF0FDFA);
      case 'match_update':
        return const Color(0xFFECFDF5);
      default:
        if (type.startsWith('follow')) return const Color(0xFFF5F3FF);
        return const Color(0xFFFFFBEB);
    }
  }

  String _time(dynamic raw) {
    final value = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    if (value == null) return '';
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${value.day}/${value.month}/${value.year}';
  }

  String _dateGroup(dynamic raw) {
    final date = DateTime.tryParse('${raw ?? ''}')?.toLocal();
    if (date == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(notificationDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return 'This Week';
    return 'Earlier';
  }

  List<Map<String, dynamic>> get _filteredItems {
    switch (_filter) {
      case 'unread':
        return _items.where((i) => i['read'] != true).toList();
      case 'invites':
        return _items.where((i) => '${i['type']}' == 'group_invite').toList();
      default:
        return _items;
    }
  }

  Widget _leadingAvatar(Map<String, dynamic> item, String type) {
    final actorImage = ClubRepository.mediaUrl(item['actorImage']);
    final actorEmail = '${item['actorEmail'] ?? ''}';
    final actorName = '${item['actorName'] ?? ''}';
    final badgeColor = _iconColor(type);
    final badgeBg = _iconBg(type);
    final icon = _icon(type);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        actorEmail.isNotEmpty
            ? UserAvatar(
                email: actorEmail,
                name: actorName,
                image: actorImage,
                radius: 23,
              )
            : Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: badgeColor, size: 22),
              ),
        if (actorEmail.isNotEmpty)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, color: badgeColor, size: 11),
              ),
            ),
          ),
      ],
    );
  }

  Widget _notificationCard(Map<String, dynamic> item) {
    final unread = item['read'] != true;
    final type = '${item['type'] ?? ''}';
    final isGroupInvite = type == 'group_invite';
    final timeStr = _time(item['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: unread ? const Color(0xFFFFF9F8) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unread ? const Color(0xFFFFCDC7) : const Color(0xFFECEFF2),
          width: unread ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: unread
                ? const Color(0xFFBA0C12).withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('notification-${item['_id']}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(item),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leadingAvatar(item, type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${item['title'] ?? 'Notification'}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: unread
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF334155),
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: unread
                                  ? const Color(0xFFBA0C12)
                                  : const Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if ('${item['body'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${item['body']}',
                          style: TextStyle(
                            color: unread
                                ? const Color(0xFF475569)
                                : const Color(0xFF64748B),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (isGroupInvite) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => _open(item),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBA0C12),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFBA0C12)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.group_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Open Group Chat',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFBA0C12),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label, int count, {IconData? icon}) {
    final selected = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _filter = key),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFBA0C12) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  selected ? const Color(0xFFBA0C12) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: const Color(0xFFBA0C12).withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF475569),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData icon = Icons.notifications_none_rounded;
    String title = 'No notifications yet';
    String subtitle =
        'When you get group invites, reactions, or updates, they will show up here.';

    if (_filter == 'unread') {
      icon = Icons.mark_email_read_rounded;
      title = 'All caught up!';
      subtitle = 'You have read all your notifications.';
    } else if (_filter == 'invites') {
      icon = Icons.group_add_outlined;
      title = 'No group invitations';
      subtitle = 'When friends invite you to groups, they will appear here.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFDE8E8),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFFBA0C12)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredItems;
    final inviteCount =
        _items.where((i) => '${i['type']}' == 'group_invite').length;

    // Group displayed items by date category while preserving chronological order
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in displayed) {
      final group = _dateGroup(item['createdAt']);
      grouped.putIfAbsent(group, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 56,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFBA0C12),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount new',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(
                Icons.done_all_rounded,
                color: Colors.white,
                size: 16,
              ),
              label: const Text(
                'Read all',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (_items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Tooltip(
                message: 'All caught up',
                child: Icon(
                  Icons.done_all_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBA0C12)),
            )
          : RefreshIndicator(
              color: const Color(0xFFBA0C12),
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Filter Chips Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        _filterChip('all', 'All', _items.length),
                        _filterChip(
                          'unread',
                          'Unread',
                          _unreadCount,
                          icon: Icons.mark_email_unread_outlined,
                        ),
                        if (inviteCount > 0)
                          _filterChip(
                            'invites',
                            'Invites',
                            inviteCount,
                            icon: Icons.group_add_outlined,
                          ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: authRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: authRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (displayed.isEmpty && _error == null)
                    _buildEmptyState()
                  else ...[
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (final item in entry.value)
                              _notificationCard(item),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }
}
