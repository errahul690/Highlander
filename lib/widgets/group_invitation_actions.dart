import 'package:flutter/material.dart';

import '../community_api.dart';
import '../screens/chat_screen.dart';
import '../theme.dart';

class GroupInvitationActions extends StatefulWidget {
  const GroupInvitationActions({
    super.key,
    required this.groupId,
    required this.groupName,
    this.sentByMe = false,
    this.wasAdded = false,
  });

  final String groupId, groupName;
  final bool sentByMe, wasAdded;

  @override
  State<GroupInvitationActions> createState() => _GroupInvitationActionsState();
}

class _GroupInvitationActionsState extends State<GroupInvitationActions> {
  String? _status, _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.sentByMe) {
      _status = widget.wasAdded ? 'active' : 'sent';
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data = await CommunityApi.instance.request(
        '/groups/${widget.groupId}/invitation',
      ) as Map;
      if (mounted) setState(() => _status = '${data['status']}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load invitation.');
    }
  }

  Future<void> _respond(String action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await CommunityApi.instance.request(
        '/groups/${widget.groupId}/$action',
        method: 'POST',
      ) as Map;
      if (!mounted) return;
      setState(() => _status = '${data['status']}');
      if (action == 'join' && _status == 'active') _open();
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
        await _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatScreen(
        title: widget.groupName,
        kind: 'groups',
        room: {
          '_id': widget.groupId,
          'name': widget.groupName,
          'membership': 'active',
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_error != null) ...[
        Text(_error!, style: const TextStyle(color: authRed, fontSize: 12)),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  setState(() => _error = null);
                  _load();
                },
          child: const Text('Retry'),
        ),
      ],
      if (_status == null && _error == null)
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      if (_status == 'pending')
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _busy ? null : () => _respond('join'),
              child: const Text('Join'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _respond('decline'),
              child: const Text('Decline'),
            ),
          ],
        )
      else if (_status == 'active')
        FilledButton.icon(
          onPressed: _busy ? null : _open,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('Open Group'),
        )
      else if (_status != null)
        Text(
          _status == 'sent'
              ? 'Invitation sent'
              : _status == 'declined'
              ? 'Invitation declined'
              : 'Invitation no longer available',
          style: const TextStyle(fontSize: 12, color: authMuted),
        ),
    ],
  );
}
