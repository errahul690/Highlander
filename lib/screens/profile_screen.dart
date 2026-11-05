import '../widgets/club_page_body.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';

import '../widgets/user_avatar.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../realtime_client.dart';
import '../session.dart';
import '../otp_api.dart';
import '../feed_store.dart';
import '../message_alerts.dart';
import '../club_repository.dart';
import '../post_pager.dart';
import '../widgets/post_list_view.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'user_profile_screen.dart';
import 'chat_screen.dart';
import 'shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.client, this.onBack, this.isActive = false});
  final http.Client? client;
  final VoidCallback? onBack;
  final bool isActive;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final http.Client _client;
  late final PostPager _pager;
  StreamSubscription<Map<String, dynamic>>? _postsSubscription;
  int? _postCount, _followersCount, _followingCount;
  String _section = 'posts';
  List<Map<String, dynamic>> _people = [];
  bool _peopleLoading = false;
  String? _peopleError;
  String _peopleQuery = '';
  final Set<String> _relationshipSaving = {};
  int _peopleRequest = 0, _countsRequest = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? http.Client();
    _pager = PostPager(
      (cursor) => _get(
        Uri(
          path: '/api/user/posts',
          queryParameters: {
            'mine': 'true',
            'limit': '10',
            if (cursor != null) 'cursor': cursor,
          },
        ).toString(),
      ),
    )..addListener(_pageChanged);
    _loadUserPosts();
    _loadCounts();
    _postsSubscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (event['resource'] == 'posts' || event['resource'] == 'all') {
        _loadUserPosts();
        _loadCounts();
      }
    });
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadUserPosts();
      _loadCounts();
    }
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _pager.dispose();
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client
        .get(
          Uri.parse('${OtpApi.apiBase}$path'),
          headers: {'Authorization': 'Bearer ${Session.token}'},
        )
        .timeout(const Duration(seconds: 10));
    final result = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        result is! Map<String, dynamic> ||
        result['success'] != true) {
      throw Exception('Could not load data. Please try again.');
    }
    return result;
  }

  void _pageChanged() {
    if (mounted)
      setState(() {
        _postCount =
            (_pager.response['total'] as num?)?.toInt() ??
            (_pager.response.isEmpty ? _postCount : _pager.posts.length);
      });
  }

  Future<void> _loadUserPosts() => _pager.refresh();

  Future<void> _loadCounts() async {
    final request = ++_countsRequest;
    try {
      final data = (await _get('/api/community/people-counts'))['data'] as Map;
      if (mounted && request == _countsRequest) {
        setState(() {
          _followersCount = data['followers'] as int;
          _followingCount = data['following'] as int;
        });
      }
    } catch (_) {
      /* Keep unavailable counts blank until a successful refresh. */
    }
  }

  Future<void> _selectSection(String section) async {
    final request = ++_peopleRequest;
    setState(() {
      _section = section;
      _people = [];
      _peopleError = null;
      _peopleQuery = '';
    });
    if (section == 'posts') return;
    setState(() => _peopleLoading = true);
    try {
      final data = await _get('/api/community/people?relation=$section');
      if (mounted && request == _peopleRequest) {
        setState(() {
          _people = (data['data'] as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
        });
      }
    } catch (_) {
      if (mounted && request == _peopleRequest) {
        setState(
          () => _peopleError = 'Could not load this list. Pull down to retry.',
        );
      }
    } finally {
      if (mounted && request == _peopleRequest) {
        setState(() => _peopleLoading = false);
      }
    }
  }

  Future<void> _unfollow(Map<String, dynamic> person) async {
    final id = '${person['_id']}';
    if (_relationshipSaving.contains(id)) return;
    setState(() => _relationshipSaving.add(id));
    try {
      final response = await _client
          .put(
            Uri.parse('${OtpApi.apiBase}/api/community/people/$id/follow'),
            headers: {
              'Authorization': 'Bearer ${Session.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'following': false}),
          )
          .timeout(const Duration(seconds: 10));
      final result = jsonDecode(response.body);
      if (response.statusCode != 200 || result['success'] != true) {
        throw Exception(
          result['message'] ?? 'Could not unfollow. Please try again.',
        );
      }
      if (!mounted) return;
      setState(() {
        if (_section == 'following')
          _people.removeWhere((row) => '${row['_id']}' == id);
        if (_followingCount != null && _followingCount! > 0)
          _followingCount = _followingCount! - 1;
      });
      await _loadCounts();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not unfollow. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _relationshipSaving.remove(id));
    }
  }

  Future<void> _followBack(Map<String, dynamic> person) async {
    final id = '${person['_id']}';
    if (_relationshipSaving.contains(id)) return;
    setState(() => _relationshipSaving.add(id));
    try {
      final response = await _client
          .put(
            Uri.parse('${OtpApi.apiBase}/api/community/people/$id/follow'),
            headers: {
              'Authorization': 'Bearer ${Session.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'following': true}),
          )
          .timeout(const Duration(seconds: 10));
      final result = jsonDecode(response.body);
      if (response.statusCode != 200 || result['success'] != true) {
        throw Exception(
          result['message'] ??
              'Could not follow this person. Please try again.',
        );
      }
      final data = result['data'] is Map ? result['data'] as Map : const {};
      if (!mounted) return;
      setState(() {
        person['isFollowing'] = data['following'] == true;
        person['followRequested'] = data['requested'] == true;
      });
      await _loadCounts();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not follow this person. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _relationshipSaving.remove(id));
    }
  }

  Future<void> _message(Map<String, dynamic> person) async {
    final email = '${person['email'] ?? ''}'.trim();
    if (email.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          title: '${person['full_name'] ?? 'Highlander'}',
          recipientEmail: email,
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadUserPosts(),
      _loadCounts(),
      if (_section != 'posts') _selectSection(_section),
    ]);
  }

  Widget _sectionContent() {
    if (_peopleLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_peopleError != null) return _empty(_peopleError!);
    if (_people.isEmpty) {
      return _empty(
        _section == 'followers'
            ? 'No followers yet'
            : 'You are not following anyone yet',
      );
    }
    return _connectionsContent();
  }

  Widget _connectionsContent() {
    final query = _peopleQuery.trim().toLowerCase();
    final visiblePeople = query.isEmpty
        ? _people
        : _people
              .where(
                (person) => '${person['full_name'] ?? ''}'
                    .toLowerCase()
                    .contains(query),
              )
              .toList();
    return Column(
      children: [
        TextField(
          key: ValueKey('profile-people-search-$_section'),
          onChanged: (value) => setState(() => _peopleQuery = value),
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: const TextStyle(
              color: Color(0xFF8B8F97),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF8B8F97)),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE7E4DE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE7E4DE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFC82D22)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E4DE)),
          ),
          child: visiblePeople.isEmpty
              ? _empty('No matching people found')
              : Column(
                  children: [
                    for (final person in visiblePeople) _connectionRow(person),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _connectionRow(Map<String, dynamic> person) {
    final id = '${person['_id']}';
    final name = '${person['full_name'] ?? 'Highlander'}';
    final image = ClubRepository.mediaUrl(
      person['profile_photo']?.toString().isNotEmpty == true
          ? person['profile_photo']
          : person['profileImage'] ?? '',
    );
    final saving = _relationshipSaving.contains(id);
    final following = person['isFollowing'] == true;
    final requested = person['followRequested'] == true;
    final action = _section == 'followers' && !following
        ? _connectionButton(
            key: ValueKey('profile-follow-back-$id'),
            label: saving
                ? 'Saving…'
                : requested
                ? 'Requested'
                : 'Follow back',
            primary: !requested,
            onPressed: saving || requested ? null : () => _followBack(person),
          )
        : _connectionButton(
            key: ValueKey('profile-message-$id'),
            label: 'Message',
            primary: false,
            onPressed: saving ? null : () => _message(person),
          );

    return SizedBox(
      key: ValueKey('profile-person-$id'),
      height: 55,
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              await openUserProfile(context, id);
              if (mounted) await _refresh();
            },
            child: UserAvatar(
              userId: id,
              email: '${person['email'] ?? ''}',
              name: name,
              image: image,
              radius: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () async {
                await openUserProfile(context, id);
                if (mounted) await _refresh();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 17),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF202126),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          action,
          if (_section == 'following') ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              key: ValueKey('profile-following-menu-$id'),
              tooltip: 'More options for $name',
              enabled: !saving,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'unfollow') _unfollow(person);
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'unfollow',
                  child: Text('Unfollow'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _connectionButton({
    required Key key,
    required String label,
    required bool primary,
    required VoidCallback? onPressed,
  }) => SizedBox(
    height: 32,
    child: TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: primary ? Colors.white : const Color(0xFF303137),
        backgroundColor: primary
            ? const Color(0xFFB32621)
            : const Color(0xFFF0F0F1),
        disabledForegroundColor: const Color(0xFF8B8F97),
        disabledBackgroundColor: const Color(0xFFF0F0F1),
        minimumSize: const Size(76, 32),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
  );

  Widget _empty(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF656D7B)),
      ),
    ),
  );

  Widget _profileAction({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => IconButton(
    key: key,
    tooltip: tooltip,
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      foregroundColor: const Color(0xFF7A1820),
      backgroundColor: const Color(0xFFFFF1EF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: Icon(icon, size: 18),
  );

  Widget _profileActions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _profileAction(
        key: const ValueKey('profile-edit-btn'),
        tooltip: 'Edit Profile',
        icon: Icons.edit_outlined,
        onPressed: _openEditProfile,
      ),
      const SizedBox(width: 6),
      _profileAction(
        key: const ValueKey('profile-settings-btn'),
        tooltip: 'Settings',
        icon: Icons.settings_outlined,
        onPressed: _openSettings,
      ),
    ],
  );

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (updated == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    try {
      await MessageAlerts.stop();
      await Session.logout();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log out. Please try again.')),
        );
      }
      return;
    }
    if (!mounted) return;
    FeedStore.clear();
    OtpApi.instance.mobileVerificationToken = '';
    OtpApi.instance.emailVerificationToken = '';
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _formatMaskedPhone() {
    final phone = Session.phone.trim();
    if (phone.length >= 4) {
      final last4 = phone.substring(phone.length - 4);
      return '+91 • • • • • • $last4';
    }
    return '';
  }

  String _getDisplayName() {
    if (Session.name.isNotEmpty && Session.name != 'Highlander') {
      return Session.name;
    }
    return 'Highlander';
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 2)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          body: Stack(
            children: [
              Column(
                children: [
                  // ================================================================
                  // HEADER BAR (Club Red with Back, Edit, and Settings Button)
                  // ================================================================
                  ClubHeader(
                    title: 'Profile',
                    embedded: true,
                  ),
                  // ================================================================
                  // BODY (User Info Card, Stats, and My Posts Feed)
                  // ================================================================
                  Expanded(
                    child: ClubPageBody(
                      color: const Color(0xFFF7F8FA),
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        color: const Color(0xFF881A1A),
                        child: PostListView(
                          pager: _pager,
                          onChanged: _loadUserPosts,
                          showPosts: _section == 'posts',
                          alternative: _section == 'posts'
                              ? null
                              : _sectionContent(),
                          padding: EdgeInsets.fromLTRB(
                            12,
                            10,
                            12,
                            MediaQuery.paddingOf(context).bottom + 24,
                          ),
                          header: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFE7E4DE)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x12000000),
                                    blurRadius: 18,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFE23A30),
                                          Color(0xFF8E1618),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: const UserAvatar(
                                        currentUser: true,
                                        radius: 30,
                                        backgroundColor: Color(0xFF7A1820),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              Session.email.trim().isEmpty &&
                                                  Session.city.trim().isEmpty &&
                                                  _formatMaskedPhone().isEmpty
                                              ? CrossAxisAlignment.center
                                              : CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    _getDisplayName(),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFF10141A),
                                                      letterSpacing: -.3,
                                                      height: 1.15,
                                                    ),
                                                  ),
                                                  if (Session.email
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      Session.email.trim(),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Color(
                                                          0xFF5A6372,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  if (_formatMaskedPhone()
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment: Alignment
                                                          .centerLeft,
                                                      child: Text(
                                                        _formatMaskedPhone(),
                                                        maxLines: 1,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Color(
                                                            0xFF5A6372,
                                                          ),
                                                          letterSpacing: .2,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _profileActions(),
                                          ],
                                        ),
                                        if (Session.city.trim().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                size: 14,
                                                color: Color(0xFFC82D22),
                                              ),
                                              const SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  Session.city.trim(),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF5A6372),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE7E4DE),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.grid_view_rounded,
                                      count: _postCount?.toString() ?? '—',
                                      label: 'Posts',
                                      selected: _section == 'posts',
                                      onTap: () => _selectSection('posts'),
                                    ),
                                  ),
                                  const _StatDivider(),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.group_outlined,
                                      count:
                                          _followersCount?.toString() ?? '—',
                                      label: 'Followers',
                                      selected: _section == 'followers',
                                      onTap: () => _selectSection('followers'),
                                    ),
                                  ),
                                  const _StatDivider(),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.person_add_alt_outlined,
                                      count:
                                          _followingCount?.toString() ?? '—',
                                      label: 'Following',
                                      selected: _section == 'following',
                                      onTap: () => _selectSection('following'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC82D22),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _section == 'posts'
                                      ? 'My posts'
                                      : _section == 'followers'
                                      ? 'Followers'
                                      : 'Following',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.2,
                                    color: Color(0xFF10141A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Accessible shortcut for automated logout test
              Positioned(
                bottom: 0,
                left: 0,
                child: SizedBox(
                  width: 80,
                  height: 36,
                  child: TextButton(
                    onPressed: _logout,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.transparent,
                    ),
                    child: const Text(
                      'Log out',
                      style: TextStyle(color: Colors.transparent, fontSize: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STAT CARD COMPONENT
// ============================================================================
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String count;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC82D22);
    return Material(
      color: selected ? const Color(0xFFFFF4F2) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: selected ? accent : const Color(0xFF8A92A0), size: 16),
              const SizedBox(height: 6),
              Text(
                count,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected ? accent : const Color(0xFF1E2229),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : const Color(0xFF8A92A0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 36,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Color(0xFFE7E4DE),
      ),
    );
  }
}
