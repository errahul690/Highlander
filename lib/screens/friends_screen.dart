import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/club_page_body.dart';

import '../widgets/user_avatar.dart';

import '../club_repository.dart';
import '../community_api.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    required this.title,
    this.showBack = true,
    this.isActive = true,
    this.initialTab = 0,
  });

  final String title;
  final bool showBack;
  final bool isActive;
  final int initialTab;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with WidgetsBindingObserver {
  static const _tabs = ['Friends', 'Requests', 'Suggestions'];
  static const _relations = ['following', 'followers', 'suggestions'];

  int _tab = 0;
  late int _friendTab;
  late Future<List<List<Map<String, dynamic>>>> _people;
  Map<String, dynamic>? _requestData;
  bool _requestsLoading = true;
  String? _requestsError;
  int _requestLoadVersion = 0;
  final _busy = <String>{};
  final _dismissed = <String>{};
  final _followStatus = <String, ({bool following, bool requested})>{};
  final _search = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  Future<List<Map<String, dynamic>>>? _searchResults;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tab = widget.initialTab < 0
        ? 0
        : widget.initialTab > 2
        ? 2
        : widget.initialTab;
    _friendTab = widget.title == 'Followers' ? 1 : 0;
    _load();
  }

  @override
  void didUpdateWidget(covariant FriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      setState(_load);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() {
    _followStatus.clear();
    _loadPeople();
    if (_query.isNotEmpty) _runSearch();
    Future.microtask(_loadRequests);
  }

  void _runSearch() {
    _searchDebounce?.cancel();
    _searchResults = CommunityApi.instance.list(
      Uri(path: '/people', queryParameters: {'q': _query}).toString(),
    );
    // The response can arrive before the next frame attaches FutureBuilder.
    _searchResults!.ignore();
  }

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _query = value.trim();
      _searchResults = null;
    });
    if (_query.isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(_runSearch);
    });
  }

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: TextField(
      key: const ValueKey('friends-search'),
      controller: _search,
      onChanged: _searchChanged,
      textInputAction: TextInputAction.search,
      maxLength: 80,
      onSubmitted: (_) {
        if (_query.isNotEmpty) setState(_runSearch);
      },
      decoration: InputDecoration(
        hintText: 'Search people by name',
        prefixIcon: const Icon(Icons.search),
        counterText: '',
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _search.clear();
                  _searchChanged('');
                },
                icon: const Icon(Icons.close),
              ),
      ),
    ),
  );

  Widget _searchContent() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _searchResults,
    builder: (context, snapshot) {
      if (_searchResults == null ||
          snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _errorState(
          'Could not search people.',
          () => setState(_runSearch),
        );
      }
      final people = snapshot.data ?? [];
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const Text(
            'SEARCH RESULTS',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 11),
          if (people.isEmpty)
            const _EmptySection(message: 'No people found. Try another name.'),
          for (final person in people)
            _person(
              person,
              person['isFollowing'] == true ? 0 : 2,
              canDismiss: false,
            ),
        ],
      );
    },
  );

  void _loadPeople() {
    _people = Future.wait([
      for (final relation in _relations)
        CommunityApi.instance.list('/people?relation=$relation'),
    ]);
  }

  Future<void> _loadRequests() async {
    final version = ++_requestLoadVersion;
    if (mounted) {
      setState(() {
        _requestsLoading = true;
        _requestsError = null;
      });
    }
    try {
      final result = Map<String, dynamic>.from(
        await CommunityApi.instance.request('/follow-requests') as Map,
      );
      if (mounted && version == _requestLoadVersion) {
        setState(() => _requestData = result);
      }
    } catch (error) {
      if (mounted && version == _requestLoadVersion) {
        setState(
          () => _requestsError = '$error'.replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted && version == _requestLoadVersion) {
        setState(() => _requestsLoading = false);
      }
    }
  }

  void _selectTab(int index) {
    _searchDebounce?.cancel();
    _search.clear();
    setState(() {
      _query = '';
      _searchResults = null;
      _tab = index;
      if (index == 2) _loadPeople();
    });
    if (index == 1) _loadRequests();
  }

  Future<void> _follow(Map<String, dynamic> person) async {
    final id = '${person['_id']}';
    if (_busy.contains(id)) return;
    final current = _followStatus[id];
    final following = current?.following ?? person['isFollowing'] == true;
    final requested = current?.requested ?? person['followRequested'] == true;
    setState(() => _busy.add(id));
    try {
      final result = await CommunityApi.instance.request(
        '/people/$id/follow',
        method: 'PUT',
        body: {'following': !following && !requested},
      );
      final data = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      if (mounted) {
        setState(() {
          _followStatus[id] = (
            following: data['following'] == true,
            requested:
                data['requested'] == true || data['followRequested'] == true,
          );
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _message(Map<String, dynamic> person) async {
    final email = '${person['email'] ?? ''}'.trim();
    if (email.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          title: '${person['full_name'] ?? 'Highlander'}',
          image: '${person['profile_photo'] ?? person['profileImage'] ?? ''}',
          recipientEmail: email,
        ),
      ),
    );
  }

  Future<void> _review(Map<String, dynamic> request, String action) async {
    final id = '${request['_id']}';
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await CommunityApi.instance.request(
        '/follow-requests/$id',
        method: 'PUT',
        body: {'action': action},
      );
      await _loadRequests();
      if (action == 'approve' && mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Widget _header() => ClubHeader(
    title: 'Friends',
    // subtitle: 'Your fellow Highlanders',
    embedded: true,
    showBack: widget.showBack,
  );

  int get _pendingRequestCount =>
      (_requestData?['received'] as List?)?.length ?? 0;

  Widget _tabsBar() => Container(
    margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE3E3E7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        for (var index = 0; index < _tabs.length; index++)
          Expanded(
            child: Material(
              color: _tab == index ? authRed : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                key: ValueKey('friends-tab-${_tabs[index].toLowerCase()}'),
                borderRadius: BorderRadius.circular(11),
                onTap: () => _selectTab(index),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _tabs[index],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _tab == index ? Colors.white : clubInk,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (index == 1 && _pendingRequestCount > 0) ...[
                        const SizedBox(width: 7),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tab == index ? Colors.white : authRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_pendingRequestCount',
                            style: TextStyle(
                              color: _tab == index ? authRed : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _friendSwitch() => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F2F4),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        for (var index = 0; index < 2; index++)
          Expanded(
            child: Material(
              color: _friendTab == index ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: ValueKey('friends-relation-${_relations[index]}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _friendTab = index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    index == 0 ? 'Following' : 'Followers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _friendTab == index ? authRed : authMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _avatar(Map<String, dynamic> person, {double radius = 23}) {
    final name = '${person['full_name'] ?? 'Highlander'}';
    final image = ClubRepository.mediaUrl(
      person['profile_photo']?.toString().isNotEmpty == true
          ? person['profile_photo']
          : person['profileImage'],
    );
    return UserAvatar(
      userId: '${person['_id'] ?? ''}',
      email: '${person['email'] ?? ''}',
      name: name,
      image: image,
      radius: radius,
    );
  }

  Widget _person(
    Map<String, dynamic> person,
    int relationIndex, {
    bool canDismiss = true,
  }) {
    final id = '${person['_id']}';
    final name = '${person['full_name'] ?? 'Highlander'}';
    final saved = _followStatus[id];
    final following = saved?.following ?? person['isFollowing'] == true;
    final requested = saved?.requested ?? person['followRequested'] == true;
    final location = '${person['city'] ?? person['location'] ?? ''}'.trim();
    final saving = _busy.contains(id);
    final suggestions = relationIndex == 2;
    final followers = relationIndex == 1;

    Widget action;
    if (relationIndex == 0 && following) {
      action = TextButton(
        key: ValueKey('friend-message-$id'),
        onPressed: saving ? null : () => _message(person),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF303137),
          backgroundColor: const Color(0xFFF0F0F1),
          minimumSize: const Size(72, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: const Text('Message', style: TextStyle(fontSize: 11)),
      );
    } else if (following) {
      action = OutlinedButton(
        key: ValueKey('friend-follow-$id'),
        onPressed: saving ? null : () => _follow(person),
        style: OutlinedButton.styleFrom(
          foregroundColor: authMuted,
          backgroundColor: const Color(0xFFF1F2F4),
          side: const BorderSide(color: Colors.transparent),
          minimumSize: const Size(72, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          saving ? 'Saving…' : 'Following',
          style: const TextStyle(fontSize: 11),
        ),
      );
    } else {
      action = OutlinedButton(
        key: ValueKey('friend-follow-$id'),
        onPressed: saving ? null : () => _follow(person),
        style: OutlinedButton.styleFrom(
          foregroundColor: requested ? authMuted : authRed,
          backgroundColor: requested ? const Color(0xFFF1F2F4) : Colors.white,
          side: BorderSide(color: requested ? Colors.transparent : authRed),
          minimumSize: const Size(72, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          saving
              ? 'Saving…'
              : requested
              ? 'Requested'
              : followers
              ? 'Follow back'
              : 'Follow',
          style: const TextStyle(fontSize: 11),
        ),
      );
    }

    return Container(
      key: ValueKey('friend-card-$id'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5E5E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              await openUserProfile(context, id);
              if (mounted) setState(_load);
            },
            child: _avatar(person),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () async {
                await openUserProfile(context, id);
                if (mounted) setState(_load);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: authMuted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location.isEmpty ? 'Highlanders community' : location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: authMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 7),
          action,
          if (relationIndex == 0) ...[
            const SizedBox(width: 1),
            PopupMenuButton<String>(
              key: ValueKey('friend-menu-$id'),
              tooltip: 'More options for $name',
              enabled: !saving,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 42),
              icon: const Icon(Icons.more_vert, size: 19),
              onSelected: (value) {
                if (value == 'unfollow') _follow(person);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'unfollow', child: Text('Unfollow')),
              ],
            ),
          ],
          if (suggestions && canDismiss)
            IconButton(
              tooltip: 'Dismiss suggestion for $name',
              onPressed: () => setState(() => _dismissed.add(id)),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 42),
              padding: const EdgeInsets.all(5),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request, {required bool received}) {
    final id = '${request['_id']}';
    final person = Map<String, dynamic>.from(request['person'] as Map);
    final name = '${person['full_name'] ?? 'Highlander'}';
    final location = '${person['city'] ?? ''}'.trim();
    final saving = _busy.contains(id);
    return Container(
      key: ValueKey('friend-request-$id'),
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5E5E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => openUserProfile(context, '${person['_id']}'),
            child: _avatar(person),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: authMuted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location.isEmpty ? 'Highlanders community' : location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: authMuted, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          if (received) ...[
            FilledButton(
              key: ValueKey('friend-request-accept-$id'),
              onPressed: saving ? null : () => _review(request, 'approve'),
              style: FilledButton.styleFrom(
                backgroundColor: authRed,
                minimumSize: const Size(66, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Text(
                saving ? 'Wait…' : 'Accept',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(width: 5),
            IconButton.outlined(
              key: ValueKey('friend-request-reject-$id'),
              tooltip: 'Reject request from $name',
              onPressed: saving ? null : () => _review(request, 'reject'),
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                foregroundColor: authRed,
                side: const BorderSide(color: authRed),
              ),
              icon: const Icon(Icons.close, size: 17),
            ),
          ] else
            TextButton(
              key: ValueKey('friend-request-cancel-$id'),
              onPressed: saving ? null : () => _review(request, 'cancel'),
              style: TextButton.styleFrom(
                foregroundColor: authMuted,
                backgroundColor: const Color(0xFFF0F1F3),
                minimumSize: const Size(68, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Text(
                saving ? 'Wait…' : 'Pending',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _peopleContent() => FutureBuilder<List<List<Map<String, dynamic>>>>(
    future: _people,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _errorState('Could not load people.', () => setState(_load));
      }
      final relationIndex = _tab == 2 ? 2 : _friendTab;
      final people = (snapshot.data ?? [[], [], []])[relationIndex]
          .where(
            (row) =>
                relationIndex != 2 || !_dismissed.contains('${row['_id']}'),
          )
          .toList();
      final heading = relationIndex == 0
          ? 'PEOPLE YOU FOLLOW'
          : relationIndex == 1
          ? 'YOUR FOLLOWERS'
          : 'PEOPLE YOU MAY KNOW';
      return RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await _people;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            if (_tab == 0) _friendSwitch(),
            Text(
              heading,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 11),
            if (people.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Text(
                      relationIndex == 0
                          ? 'Follow fellow Highlanders from Suggestions.'
                          : relationIndex == 1
                          ? 'Your followers will appear here.'
                          : 'No suggestions right now.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: authMuted, fontSize: 13),
                    ),
                    if (relationIndex != 2)
                      TextButton(
                        onPressed: () => _selectTab(2),
                        child: const Text('Find people'),
                      ),
                  ],
                ),
              ),
            for (final person in people) _person(person, relationIndex),
          ],
        ),
      );
    },
  );

  Widget _requestsContent() {
    if (_requestsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requestsError != null && _requestData == null) {
      return _errorState(_requestsError!, _loadRequests);
    }
    final received = (_requestData?['received'] as List?) ?? const [];
    final sent = (_requestData?['sent'] as List?) ?? const [];
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          const Text(
            'PENDING REQUESTS',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 11),
          if (received.isEmpty)
            const _EmptySection(message: 'No pending follow requests.'),
          for (final row in received)
            _requestCard(Map<String, dynamic>.from(row as Map), received: true),
          const SizedBox(height: 16),
          const Text(
            'SENT REQUESTS',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 11),
          if (sent.isEmpty)
            const _EmptySection(message: 'No sent follow requests.'),
          for (final row in sent)
            _requestCard(
              Map<String, dynamic>.from(row as Map),
              received: false,
            ),
        ],
      ),
    );
  }

  Widget _errorState(String message, VoidCallback retry) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFAA241C),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9E2118), Color(0xFFC82D22)],
          begin: Alignment.topLeft,
          end: Alignment.topRight,
        ),
      ),
      child: Column(
        children: [
          _header(),
          Expanded(
            child: ClubPageBody(
              child: Column(
                children: [
                  _tabsBar(),
                  if (_tab != 1) _searchField(),
                  Expanded(
                    child: _tab == 1
                        ? _requestsContent()
                        : _query.isNotEmpty
                        ? _searchContent()
                        : _peopleContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F8F9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: authMuted, fontSize: 12),
    ),
  );
}
