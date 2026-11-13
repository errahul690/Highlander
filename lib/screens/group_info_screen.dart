import '../widgets/app_popup_menu.dart';
import '../brand_colors.dart';
import '../widgets/club_page_body.dart';
import '../widgets/club_header.dart';

import 'package:flutter/material.dart';

import '../community_api.dart';
import '../session.dart';
import '../widgets/invite_members_sheet.dart';
import '../widgets/user_avatar.dart';
import 'chat_settings_screen.dart';
import 'user_profile_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  static const _accent = brandAccent;
  Map<String, dynamic>? _info;
  String? _error;
  bool _loading = true, _leaving = false;
  final _busy = <String>{};
  final _membersKey = GlobalKey();
  String get _path => '/groups/${widget.groupId}';
  List<Map<String, dynamic>> get _members => (_info?['members'] as List? ?? [])
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await CommunityApi.instance.request('$_path/info') as Map;
      if (mounted)
        setState(() {
          _info = Map<String, dynamic>.from(data);
          _error = null;
        });
    } catch (error) {
      if (mounted)
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMembers() async {
    await InviteMembersSheet.show(
      context,
      roomId: widget.groupId,
      roomTitle: '${_info?['name'] ?? 'Group'}',
      kind: 'groups',
    );
    if (mounted) await _load();
  }

  Future<void> _settings() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ChatSettingsScreen(kind: 'groups', room: _info),
      ),
    );
    if (!mounted) return;
    if (result?['deleted'] == true) {
      Navigator.pop(context, result);
      return;
    }
    await _load();
  }

  Future<void> _follow(Map<String, dynamic> person) async {
    final id = '${person['userId']}';
    if (!_busy.add(id)) return;
    setState(() {});
    try {
      final result = await CommunityApi.instance.request(
        '/people/$id/follow',
        method: 'PUT',
        body: {'following': person['isFollowing'] != true},
      ) as Map;
      if (!mounted) return;
      final rows = _info!['members'] as List;
      final row = rows.cast<Map>().firstWhere(
        (row) => '${row['userId']}' == id,
      );
      setState(() {
        row['isFollowing'] = result['following'] == true;
        row['followRequested'] = result['requested'] == true;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _showError(Object error) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
      );
  }

  Future<void> _setAdmin(
    Map<String, dynamic> person, {
    bool remove = false,
  }) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(remove ? 'Remove admin role?' : 'Make group admin?'),
        content: Text(
          remove
              ? '${person['name']} will remain a member and lose admin permissions.'
              : '${person['name']} will be able to manage members and group settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(remove ? 'Remove admin' : 'Make admin'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final id = '${person['userId']}';
    setState(() => _busy.add(id));
    try {
      await CommunityApi.instance.request(
        '$_path/admins',
        method: 'PUT',
        body: {'email': person['email'], 'action': remove ? 'remove' : 'add'},
      );
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _leave() async {
    final admins = (_info?['adminEmails'] as List? ?? []);
    if (_info?['canManage'] == true && admins.length <= 1) {
      final hasMembers = _members.any(
        (row) => '${row['email']}' != Session.email,
      );
      final choose = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Another admin is needed'),
          content: Text(
            hasMembers
                ? 'Make another member an admin before you leave. Open their member menu and choose Make admin.'
                : 'Add a member and make them an admin before leaving. You can also delete this group from settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(hasMembers ? 'Choose member' : 'Add members'),
            ),
          ],
        ),
      );
      if (choose == true && mounted) {
        if (!hasMembers) {
          await _addMembers();
        } else if (_membersKey.currentContext != null) {
          await Scrollable.ensureVisible(
            _membersKey.currentContext!,
            duration: const Duration(milliseconds: 250),
          );
        }
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: Text(
          'You will leave ${_info?['name']}. A member with invite permission will need to add you again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave group'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await CommunityApi.instance.request('$_path/leave', method: 'POST');
      if (mounted) Navigator.pop(context, {'left': true});
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Widget _panel(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );

  Widget _member(Map<String, dynamic> person) {
    final own = person['email'] == Session.email;
    final id = '${person['userId']}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          UserAvatar(
            userId: id,
            email: '${person['email']}',
            name: '${person['name'] ?? 'Member'}',
            image: '${person['image'] ?? ''}',
            radius: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: own ? null : () => openUserProfile(context, id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    own ? 'You' : '${person['name'] ?? 'Member'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (person['isAdmin'] == true)
                    const Text(
                      'Group admin',
                      style: TextStyle(color: _accent, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          if (!own)
            TextButton(
              key: ValueKey('group-follow-$id'),
              onPressed: _busy.contains(id) || person['followRequested'] == true
                  ? null
                  : () => _follow(person),
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                person['isFollowing'] == true
                    ? 'Unfollow'
                    : person['followRequested'] == true
                    ? 'Requested'
                    : 'Follow',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (_info?['canManage'] == true && !own)
            AppPopupMenu<String>(
              tooltip: 'Member options for ${person['name']}',
              icon: const Icon(
                Icons.more_vert,
                size: 22,
                color: Color(0xFF596275),
              ),
              enabled: !_busy.contains(id),
              onSelected: (_) =>
                  _setAdmin(person, remove: person['isAdmin'] == true),
              itemBuilder: (_) => [
                AppMenuItem<String>(
                  value: 'admin',
                  label: person['isAdmin'] == true
                      ? 'Remove admin'
                      : 'Make admin',
                  icon: person['isAdmin'] == true
                      ? Icons.remove_moderator_outlined
                      : Icons.admin_panel_settings_outlined,
                  danger: person['isAdmin'] == true,
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ClubScaffold(
    backgroundColor: const Color(0xFFF7F6FB),
    appBar: ClubHeader(
      title: 'Group info',
      showBack: true,
      showSearch: false,
      showSupport: false,
      uppercaseTitle: false,
      trailing: [
        if (_info?['canManage'] == true)
          IconButton(
            tooltip: 'Group settings',
            onPressed: _settings,
            icon: const Icon(Icons.settings_outlined),
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _info == null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Could not load group.'),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFF7E4EB),
                    child: Icon(
                      Icons.groups_outlined,
                      size: 42,
                      color: _accent,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${_info!['name'] ?? 'Group'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_members.length} members',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF737584)),
                ),
                const SizedBox(height: 24),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About this group',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_info!['description'] ?? ''}'.trim().isEmpty
                            ? 'No description added yet.'
                            : '${_info!['description']}',
                        style: const TextStyle(
                          color: Color(0xFF737584),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_info!['canInvite'] == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: OutlinedButton.icon(
                      onPressed: _addMembers,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add members'),
                    ),
                  ),
                _panel(
                  Column(
                    key: _membersKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Members · ${_members.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final member in _members) _member(member),
                    ],
                  ),
                ),
                _panel(
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout, color: _accent),
                    title: Text(
                      _leaving ? 'Leaving…' : 'Leave group',
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _leaving ? null : _leave,
                  ),
                ),
              ],
            ),
          ),
  );
}
