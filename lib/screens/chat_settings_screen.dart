import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../community_api.dart';
import '../theme.dart';
import '../widgets/club_bar.dart';
import '../widgets/invite_members_sheet.dart';

const chatPermissionItems = [
  DropdownMenuItem(value: 'all', child: Text('All members can send')),
  DropdownMenuItem(
    value: 'admins',
    child: Text('Only admin / creator can send'),
  ),
  DropdownMenuItem(value: 'off', child: Text('Chat off')),
];

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key, this.kind, this.room});
  final String? kind;
  final Map<String, dynamic>? room;
  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool _loading = true, _busy = false;
  String? _error;
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _requests = [];
  bool get _personal => widget.room == null;
  String get _path => '/${widget.kind}/${widget.room!['_id']}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_personal) {
        _settings = Map<String, dynamic>.from(
          await CommunityApi.instance.request('/settings') as Map,
        );
      } else {
        _settings = Map<String, dynamic>.from(
          await CommunityApi.instance.request('$_path/settings') as Map,
        );
        _requests = await CommunityApi.instance.list('$_path/requests');
      }
    } catch (error) {
      _error = '$error'.replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = _personal
          ? {
              for (final key in ['following', 'followers', 'anyone'])
                key: _settings[key] == true,
            }
          : {
              'autoApprove': _settings['autoApprove'] == true,
              'chatPermission': _settings['chatPermission'] ?? 'all',
            };
      await CommunityApi.instance.request(
        _personal ? '/settings' : '$_path/settings',
        method: 'PUT',
        body: values,
      );
      if (mounted) Navigator.of(context).pop(values);
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(Map<String, dynamic> member, String action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CommunityApi.instance.request(
        '$_path/requests/${member['_id']}',
        method: 'PUT',
        body: {'action': action},
      );
      if (mounted) setState(() => _requests.remove(member));
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteGroup() async {
    final name = '${_settings['name'] ?? widget.room?['name'] ?? 'Group'}';
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
            style: FilledButton.styleFrom(backgroundColor: authRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _busy = true);
      try {
        await CommunityApi.instance.request(_path, method: 'DELETE');
        if (mounted) {
          Navigator.of(context).pop({'deleted': true});
        }
      } catch (error) {
        if (mounted)
          setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Widget _toggle(String key, String title, String subtitle) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    activeThumbColor: authRed,
    title: Text(title),
    subtitle: Text(subtitle),
    value: _settings[key] == true,
    onChanged: _busy ? null : (v) => setState(() => _settings[key] = v),
  );
  @override
  Widget build(BuildContext context) {
    final isGroup = widget.kind == 'groups';
    final PreferredSizeWidget appBar = isGroup
        ? AppBar(
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
            centerTitle: false,
            title: Text(
              '${_settings['name'] ?? widget.room?['name'] ?? 'Group'} settings',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : ClubBar(
            title: _personal
                ? 'Chat settings'
                : '${widget.kind == 'circles' ? 'Huddle' : 'Group'} settings',
          );

    return ClubScaffold(
      appBar: appBar,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _settings.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'Could not load settings.'),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_personal) ...[
                  const Text(
                    'Who can message me?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _toggle(
                    'following',
                    'People I follow',
                    'Allow people you are following to message you.',
                  ),
                  _toggle(
                    'followers',
                    'My followers',
                    'Allow people following you to message you.',
                  ),
                  _toggle(
                    'anyone',
                    'Anyone',
                    'Allow every user to message you.',
                  ),
                  const Text(
                    'When Anyone is on, every user can message you. When it is off, your other selected options apply. Turn all three off to stop new incoming messages.',
                    style: TextStyle(color: authMuted),
                  ),
                ] else ...[
                  Text(
                    '${_settings['name'] ?? widget.room?['name'] ?? 'Group'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  if (isGroup && widget.room != null) ...[
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEAEA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          color: authRed,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Invite members',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: const Text(
                        'Add people or share group invite link',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF9CA3AF),
                      ),
                      onTap: () => InviteMembersSheet.show(
                        context,
                        roomId: '${widget.room!['_id']}',
                        roomTitle:
                            '${_settings['name'] ?? widget.room?['name'] ?? 'Group'}',
                        kind: 'groups',
                      ),
                    ),
                    const Divider(height: 24),
                  ],
                  _toggle(
                    'autoApprove',
                    'Auto approve join requests',
                    'Off: approve or reject each request manually. Changes apply to new requests.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: '${_settings['chatPermission'] ?? 'all'}',
                    decoration: const InputDecoration(
                      labelText: 'Who can send messages?',
                    ),
                    isExpanded: true,
                    items: chatPermissionItems,
                    onChanged: _busy
                        ? null
                        : (v) =>
                              setState(() => _settings['chatPermission'] = v),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: authRed),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Please wait…' : 'Save settings'),
                ),
                if (!_personal) ...[
                  const SizedBox(height: 28),
                  const Text(
                    'Join requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  if (_requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No pending requests.',
                        style: TextStyle(color: authMuted),
                      ),
                    ),
                  for (final member in _requests)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${member['userName'] ?? member['userEmail']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _review(member, 'reject'),
                                  child: const Text('Reject'),
                                ),
                                const Spacer(),
                                FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _review(member, 'approve'),
                                  child: const Text('Approve'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (widget.kind == 'groups' &&
                    widget.room?['canManage'] == true) ...[
                  const SizedBox(height: 36),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: authRed,
                      side: const BorderSide(color: authRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text(
                      'Delete group',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _busy ? null : _deleteGroup,
                  ),
                ],
              ],
            ),
    );
  }
}
