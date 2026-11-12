import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import '../widgets/user_avatar.dart';

import '../club_repository.dart';
import '../community_api.dart';
import '../theme.dart';
import '../widgets/club_bar.dart';
import 'user_profile_screen.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});
  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _tab = 0, _loadVersion = 0;
  String? _busy, _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    try {
      final result = Map<String, dynamic>.from(
        await CommunityApi.instance.request('/follow-requests') as Map,
      );
      if (mounted && version == _loadVersion) {
        setState(() {
          _data = result;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _review(Map<String, dynamic> request, String action) async {
    setState(() {
      _busy = '${request['_id']}';
      _error = null;
    });
    try {
      await CommunityApi.instance.request(
        '/follow-requests/${request['_id']}',
        method: 'PUT',
        body: {'action': action},
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  Widget _card(Map<String, dynamic> request) {
    final person = Map<String, dynamic>.from(request['person'] as Map);
    final name = '${person['full_name'] ?? 'Highlander'}';
    final image = ClubRepository.mediaUrl(
      person['profile_photo']?.toString().isNotEmpty == true
          ? person['profile_photo']
          : person['profileImage'],
    );
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: clubLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                UserAvatar(
                  userId: '${person['_id'] ?? ''}',
                  email: '${person['email'] ?? ''}',
                  name: name,
                  image: image,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            openUserProfile(context, '${person['_id']}'),
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if ('${person['city'] ?? ''}'.isNotEmpty)
                        Text(
                          '${person['city']}',
                          style: const TextStyle(
                            color: authMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_tab == 0) ...[
                  TextButton(
                    onPressed: _busy != null
                        ? null
                        : () => _review(request, 'reject'),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy != null
                        ? null
                        : () => _review(request, 'approve'),
                    child: Text(
                      _busy == '${request['_id']}' ? 'Please wait…' : 'Accept',
                    ),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: _busy != null
                        ? null
                        : () => _review(request, 'cancel'),
                    child: Text(
                      _busy == '${request['_id']}'
                          ? 'Cancelling…'
                          : 'Cancel request',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = (_data?[_tab == 0 ? 'received' : 'sent'] as List?) ?? [];
    return ClubScaffold(
      appBar: const ClubBar(title: 'Follow requests'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (var index = 0; index < 2; index++) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(
                        '${index == 0 ? 'Received' : 'Sent'} (${(_data?[index == 0 ? 'received' : 'sent'] as List?)?.length ?? 0})',
                      ),
                      selected: _tab == index,
                      onSelected: (_) => setState(() => _tab = index),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: authRed),
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        if (rows.isEmpty && _error == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Text(
                              _tab == 0
                                  ? 'No pending follow requests.'
                                  : 'No sent follow requests.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: authMuted),
                            ),
                          ),
                        for (final row in rows)
                          _card(Map<String, dynamic>.from(row as Map)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
