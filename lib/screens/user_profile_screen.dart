import '../brand_colors.dart';
import '../widgets/profile_identity_header.dart';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';

import '../widgets/user_avatar.dart';

import 'package:flutter/services.dart';

import '../club_repository.dart';
import '../community_api.dart';
import '../session.dart';
import '../post_pager.dart';
import '../widgets/post_list_view.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

/// Opens the signed-in user's own profile when a list includes their account.
Future<void> openUserProfile(BuildContext context, String id) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => id == Session.userId
            ? const ProfileScreen()
            : UserProfileScreen(userId: id),
      ),
    );

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});
  final String userId;
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with WidgetsBindingObserver {
  static const _red = brandAccent;
  Map<String, dynamic>? _profile;
  late final PostPager _pager;
  String? _error;
  String _section = 'posts';
  List<Map<String, dynamic>> _people = [];
  String? _peopleError;
  bool _peopleLoading = false, _saving = false;
  int _listRequest = 0;
  Map get _person => _profile?['person'] as Map? ?? {};

  @override
  void initState() {
    super.initState();
    _pager = PostPager(
      (cursor) async => Map<String, dynamic>.from(
        await CommunityApi.instance.request(
          Uri(
            path: '/people/${widget.userId}/profile',
            queryParameters: {
              'limit': '10',
              if (cursor != null) 'cursor': cursor,
            },
          ).toString(),
        ) as Map,
      ),
    )..addListener(_pageChanged);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _pager.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  void _pageChanged() {
    if (mounted)
      setState(() {
        if (_pager.response.isNotEmpty) _profile = _pager.response;
        _error = _profile == null ? _pager.error : null;
      });
  }

  Future<void> _load() => _pager.refresh();

  Future<void> _select(String section) async {
    final request = ++_listRequest;
    setState(() {
      _section = section;
      _peopleLoading = section != 'posts';
      _peopleError = null;
      _people = [];
    });
    if (section == 'posts') return;
    try {
      final rows = await CommunityApi.instance.list(
        '/people/${widget.userId}/connections?relation=$section',
      );
      if (mounted && request == _listRequest) setState(() => _people = rows);
    } catch (_) {
      if (mounted && request == _listRequest)
        setState(
          () => _peopleError = 'Could not load this list. Pull down to retry.',
        );
    } finally {
      if (mounted && request == _listRequest)
        setState(() => _peopleLoading = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_load(), if (_section != 'posts') _select(_section)]);
  }

  Future<void> _follow() async {
    setState(() => _saving = true);
    try {
      final result = await CommunityApi.instance.request(
        '/people/${widget.userId}/follow',
        method: 'PUT',
        body: {
          'following':
              _profile?['isFollowing'] != true &&
              _profile?['followRequested'] != true,
        },
      );
      if (mounted)
        setState(() {
          _profile!['isFollowing'] = result['following'] == true;
          _profile!['followRequested'] = result['requested'] == true;
        });
      await _load();
      if (_section == 'followers') await _select(_section);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chat() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          title: '${_person['full_name'] ?? 'Highlander'}',
          image: '${_person['profile_photo'] ?? _person['profileImage'] ?? ''}',
          recipientEmail: '${_person['email']}',
        ),
      ),
    );
    if (mounted) await _load();
  }

  Widget _avatar(Map person, double radius) {
    final url = ClubRepository.mediaUrl(
      person['profile_photo']?.toString().isNotEmpty == true
          ? person['profile_photo']
          : person['profileImage'] ?? '',
    );
    final name = '${person['full_name'] ?? 'Highlander'}';
    return UserAvatar(
      userId: '${person['_id'] ?? ''}',
      email: '${person['email'] ?? ''}',
      name: name,
      image: url,
      radius: radius,
    );
  }

  Widget _hero() => ProfileIdentityHeader(
    key: const ValueKey('user-profile-hero'),
    name: (_person['full_name'] ?? 'Highlander').toString(),
    subtitle: (_person['email'] ?? '').toString(),
    cover: (_person['cover_photo'] ?? _person['coverImage'] ?? '').toString(),
    coverKey: const ValueKey('user-profile-cover'),
    avatarBuilder: (radius) => _avatar(_person, radius),
  );

  Widget _stats() => ProfileStatsBar(
    keyPrefix: 'user-profile',
    counts: {
      for (final section in ['posts', 'followers', 'following'])
        section: ((_profile?['counts'] as Map?)?[section] ?? 0).toString(),
    },
    selected: _section,
    onSelect: _select,
  );

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF6D7383)),
      ),
    ),
  );
  Widget _content() {
    if (_peopleLoading)
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    if (_peopleError != null) return _message(_peopleError!);
    if (_people.isEmpty)
      return _message(
        _section == 'followers'
            ? 'No followers yet'
            : 'Not following anyone yet',
      );
    return Column(
      children: [
        for (final person in _people)
          Card(
            elevation: 0,
            color: Colors.white,
            child: ListTile(
              leading: _avatar(person, 22),
              title: Text('${person['full_name'] ?? 'Highlander'}'),
              subtitle: '${person['city'] ?? ''}'.isEmpty
                  ? null
                  : Text('${person['city']}'),
              onTap: () => openUserProfile(context, '${person['_id']}'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final requested = _profile?['followRequested'] == true;
    final following = _profile?['isFollowing'] == true;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F6FB),
        body: Stack(
          children: [
            if (_error != null)
              Center(
                child: TextButton(onPressed: _load, child: Text(_error!)),
              )
            else if (_profile == null)
              const Center(child: CircularProgressIndicator())
            else
              RefreshIndicator(
                onRefresh: _refresh,
                color: _red,
                edgeOffset: MediaQuery.paddingOf(context).top + 80,
                child: PostListView(
                  pager: _pager,
                  onChanged: _load,
                  spacing: 6,
                  showPosts: _section == 'posts',
                  alternative: _section == 'posts' ? null : _content(),
                  beforeHeader: _hero(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  header: [
                    _stats(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 23,
                          decoration: BoxDecoration(
                            color: _red,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          _section == 'posts'
                              ? 'Posts'
                              : _section == 'followers'
                              ? 'Followers'
                              : 'Following',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF171717),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClubHeader(
                title: 'Profile',
                embedded: true,
                showBack: true,
                uppercaseTitle: false,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _profile == null || _error != null
            ? null
            : Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                  border: Border(top: BorderSide(color: Color(0xFFE8E8EC))),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('user-profile-chat'),
                            onPressed: _profile?['canChat'] == true
                                ? _chat
                                : null,
                            icon: const Icon(Icons.chat_outlined, size: 19),
                            label: const Text('Chat'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _red,
                              side: const BorderSide(color: _red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(0, 42),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('user-profile-follow'),
                            onPressed: _saving ? null : _follow,
                            icon: Icon(
                              requested
                                  ? Icons.send_outlined
                                  : following
                                  ? Icons.person_outline
                                  : Icons.person_add_alt_1_outlined,
                              size: 19,
                            ),
                            label: Text(
                              _saving
                                  ? 'Saving…'
                                  : requested
                                  ? 'Requested'
                                  : following
                                  ? 'Unfollow'
                                  : 'Follow',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: requested || following
                                  ? const Color(0xFFFBEBEB)
                                  : _red,
                              foregroundColor: requested || following
                                  ? _red
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(0, 42),
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
}
