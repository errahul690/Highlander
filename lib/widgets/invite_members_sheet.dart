import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../community_api.dart';
import '../session.dart';
import '../theme.dart';
import 'user_avatar.dart';

class InviteMembersSheet extends StatefulWidget {
  const InviteMembersSheet({
    super.key,
    required this.roomId,
    required this.roomTitle,
    this.kind = 'groups',
  });

  final String roomId;
  final String roomTitle;
  final String kind;

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required String roomTitle,
    String kind = 'groups',
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => InviteMembersSheet(
      roomId: roomId,
      roomTitle: roomTitle,
      kind: kind,
    ),
  );

  @override
  State<InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _InviteMembersSheetState extends State<InviteMembersSheet> {
  static const _appLinks = MethodChannel('highlanders/app_links');
  final _search = TextEditingController();
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;
  String? _error;
  final Set<String> _invitedEmails = {};
  final Set<String> _busyEmails = {};

  String get _inviteMessage =>
      'Join our Highlander group "${widget.roomTitle}"! Connect with the squad on the Highlanders app.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _search.text.trim();
      final url = '/people?q=${Uri.encodeComponent(q)}';
      final rows = await CommunityApi.instance.list(url);
      final myEmail = Session.email.toLowerCase();
      final filtered = rows
          .where((r) => '${r['email'] ?? ''}'.trim().toLowerCase() != myEmail)
          .toList();
      if (mounted) {
        setState(() {
          _people = filtered;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e'.replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _copyInvite() async {
    await Clipboard.setData(ClipboardData(text: _inviteMessage));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite message copied to clipboard!')),
      );
    }
  }

  Future<void> _shareInvite() async {
    try {
      await _appLinks.invokeMethod('sharePost', {'text': _inviteMessage});
    } catch (_) {
      await _copyInvite();
    }
  }

  Future<void> _invite(Map<String, dynamic> person) async {
    final email = '${person['email'] ?? ''}'.trim();
    if (email.isEmpty || _busyEmails.contains(email)) return;
    setState(() => _busyEmails.add(email));
    try {
      await CommunityApi.instance.request(
        '/${widget.kind}/${widget.roomId}/invite',
        method: 'POST',
        body: {
          'emails': [email],
        },
      );
      if (mounted) {
        setState(() {
          _busyEmails.remove(email);
          _invitedEmails.add(email.toLowerCase());
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invitation sent to ${person['full_name'] ?? 'friend'} in chat!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busyEmails.remove(email));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invite members',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add members to "${widget.roomTitle}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF4B5563)),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Share link quick action
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEAEA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.share_outlined,
                        color: authRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share invite link',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            'Share invite message with others',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy link',
                      icon: const Icon(Icons.copy_outlined, size: 20, color: authRed),
                      onPressed: _copyInvite,
                    ),
                    IconButton(
                      tooltip: 'Share',
                      icon: const Icon(Icons.send_rounded, size: 20, color: authRed),
                      onPressed: _shareInvite,
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search people to invite...',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Members List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: authRed),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: authRed)),
                          const SizedBox(height: 8),
                          TextButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _people.isEmpty
                  ? Center(
                      child: Text(
                        _search.text.isEmpty
                            ? 'No people available to invite.'
                            : 'No people found for "${_search.text.trim()}".',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: _people.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 68,
                        color: Color(0xFFF3F4F6),
                      ),
                      itemBuilder: (context, index) {
                        final person = _people[index];
                        final email = '${person['email'] ?? ''}'.trim().toLowerCase();
                        final name = '${person['full_name'] ?? person['name'] ?? 'Highlander'}';
                        final isInvited = _invitedEmails.contains(email);
                        final isBusy = _busyEmails.contains(email);
                        final subtitle = [
                          if ('${person['city'] ?? ''}'.isNotEmpty) person['city'],
                          if ('${person['primary_sport'] ?? ''}'.isNotEmpty) person['primary_sport'],
                        ].join(' · ');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: UserAvatar(
                            userId: '${person['_id'] ?? ''}',
                            email: email,
                            name: name,
                            image: '${person['profile_photo'] ?? person['profileImage'] ?? ''}',
                            radius: 22,
                          ),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          subtitle: subtitle.isNotEmpty
                              ? Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                )
                              : (email.isNotEmpty
                                  ? Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    )
                                  : null),
                          trailing: isInvited
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Color(0xFF16A34A),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Invited',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: authRed,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 0,
                                    ),
                                    minimumSize: const Size(64, 32),
                                  ),
                                  onPressed: isBusy ? null : () => _invite(person),
                                  child: isBusy
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Invite',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

