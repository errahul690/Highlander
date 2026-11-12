import '../brand_colors.dart';

import 'dart:async';
import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/profile_identity_header.dart';
import '../posts_api.dart';

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
  const ProfileScreen({
    super.key,
    this.client,
    this.onBack,
    this.isActive = false,
  });
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
  bool _uploadingCover = false;
  int _coverRevision = 0;

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
    unawaited(_restoreCover());
    _postsSubscription = RealtimeClient.instance.settingsChanges.listen((
      event,
    ) {
      if ((event['resource'] == 'posts' || event['resource'] == 'all') &&
          event['action'] != 'liked') {
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
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: Color(0xFF8B8F97),
            ),
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
              borderSide: const BorderSide(color: brandAccent),
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
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      foregroundColor: brandAccent,
      backgroundColor: const Color(0xFFF7E4EB),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: Icon(icon, size: 22),
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
      const SizedBox(width: 8),
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

  Future<void> _restoreCover() async {
    final revision = _coverRevision;
    final userId = Session.userId;
    try {
      final data = (await _get('/api/auth/me'))['data'];
      if (!mounted ||
          revision != _coverRevision ||
          userId != Session.userId ||
          data is! Map) {
        return;
      }
      final cover =
          '${data['cover_photo']?.toString().isNotEmpty == true ? data['cover_photo'] : data['coverImage'] ?? ''}';
      if (cover != Session.coverPhoto) {
        await Session.updateDetails(coverPhoto: cover);
        if (mounted) setState(() {});
      }
    } catch (_) {
      /* Keep the saved cover while offline. */
    }
  }

  Future<void> _changeCover() async {
    if (_uploadingCover) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (photo == null || !mounted) return;
      setState(() => _uploadingCover = true);
      _coverRevision++;
      final userId = Session.userId;
      final url = await PostsApi.instance.upload(photo);
      if (userId != Session.userId) return;
      await PostsApi.instance.request(
        '/api/auth/me',
        method: 'PUT',
        body: {'cover_photo': url, 'coverImage': url},
      );
      if (userId != Session.userId) return;
      await Session.updateDetails(coverPhoto: url);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not upload cover photo. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Widget _profileHero(BuildContext context) => ProfileIdentityHeader(
    key: const ValueKey('profile-hero'),
    name: _getDisplayName(),
    subtitle: Session.email.trim(),
    cover: Session.coverPhoto,
    coverKey: const ValueKey('profile-cover'),
    onCoverEdit: _changeCover,
    coverBusy: _uploadingCover,
    avatarBuilder: (radius) => UserAvatar(
      currentUser: true,
      radius: radius,
      backgroundColor: brandAccent,
      foregroundColor: Colors.white,
    ),
    actions: _profileActions(),
  );

  Widget _profileStats() => ProfileStatsBar(
    counts: {
      'posts': _postCount?.toString() ?? '?',
      'followers': _followersCount?.toString() ?? '?',
      'following': _followingCount?.toString() ?? '?',
    },
    selected: _section,
    onSelect: _selectSection,
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _handleBack();
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F6FB),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              color: brandAccent,
              edgeOffset: MediaQuery.paddingOf(context).top + 80,
              child: PostListView(
                pager: _pager,
                onChanged: _loadUserPosts,
                showPosts: _section == 'posts',
                alternative: _section == 'posts' ? null : _sectionContent(),
                beforeHeader: _profileHero(context),
                padding: EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                spacing: 16,
                header: [
                  _profileStats(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 23,
                        decoration: BoxDecoration(
                          color: brandAccent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        _section == 'posts'
                            ? 'My Posts'
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
                  const SizedBox(height: 20),
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
                showSearch: true,
                showNotifications: true,
                showSupport: true,
                uppercaseTitle: false,
              ),
            ),
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
