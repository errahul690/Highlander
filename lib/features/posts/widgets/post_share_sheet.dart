import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Highlanders/core/network/network_read.dart';
import 'package:Highlanders/core/session/session.dart';
import 'package:Highlanders/core/theme/brand_colors.dart';
import 'package:Highlanders/core/theme/app_motion.dart';
import 'package:Highlanders/core/theme/theme.dart' show clubFontFamily;
import 'package:Highlanders/features/chat/data/chat_updates.dart';
import 'package:Highlanders/features/community/data/community_api.dart';
import 'package:Highlanders/features/posts/data/posts_api.dart';
import 'package:Highlanders/features/posts/services/post_link_router.dart';
import 'package:Highlanders/shared/widgets/user_avatar.dart';

Future<bool> showPostShareSheet(
  BuildContext context,
  Map<String, dynamic> post,
) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        reverseDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : appMotionDuration,
      ),
      builder: (_) => _PostShareSheet(post: post),
    ) ??
    false;

Future<bool> showChatForwardSheet(
  BuildContext context,
  List<String> messageIds,
  Map<String, dynamic> source,
) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        reverseDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : appMotionDuration,
      ),
      builder: (_) => _PostShareSheet(
        post: const {},
        messageIds: messageIds,
        source: source,
      ),
    ) ??
    false;

class _PostShareSheet extends StatefulWidget {
  const _PostShareSheet({
    required this.post,
    this.messageIds = const [],
    this.source = const {},
  });
  final Map<String, dynamic> post;
  final List<String> messageIds;
  final Map<String, dynamic> source;
  @override
  State<_PostShareSheet> createState() => _PostShareSheetState();
}

class _PostShareSheetState extends State<_PostShareSheet> {
  final _forwardRequestId = DateTime.now().microsecondsSinceEpoch.toRadixString(
    36,
  );
  static const _links = MethodChannel('highlanders/app_links');
  static const _tabs = ['Followers', 'Following', 'Groups', 'Huddles'];
  final _search = TextEditingController();
  final _selected = <String, Map<String, dynamic>>{};
  final _sent = <String>{};
  List<Map<String, dynamic>> _recent = [], _rows = [], _apps = [];
  Timer? _debounce;
  int _tab = 0, _version = 0, _offset = 0;
  bool _recentLoading = true, _loading = false, _loadingMore = false;
  bool _more = false, _hasMore = false, _sending = false, _changed = false;
  String? _error, _recentError;
  bool get _forwarding => widget.messageIds.isNotEmpty;
  String get _postId => '${widget.post['_id'] ?? widget.post['id'] ?? ''}';
  String get _link {
    final configured = '${widget.post['share_url'] ?? ''}'.trim();
    return configured.isEmpty ? sharedPostUrl(_postId) : configured;
  }

  String _key(Map<String, dynamic> row) => '${row['kind']}:${row['target']}';
  Map<String, dynamic> _person(Map<String, dynamic> row) => {
    'kind': 'direct',
    'target': '${row['email'] ?? ''}',
    'name': '${row['name'] ?? row['full_name'] ?? row['email'] ?? ''}',
    'image':
        row['iconImage'] ?? row['profile_photo'] ?? row['profileImage'] ?? '',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecent());
    if (!_forwarding) unawaited(_loadApps());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    setState(() {
      _recentLoading = true;
      _recentError = null;
    });
    try {
      final rows = Session.token.isEmpty
          ? <Map<String, dynamic>>[]
          : await CommunityApi.instance.list('/chats');
      final seen = <String>{};
      final recent = rows
          .map(_person)
          .where((row) {
            final email = '${row['target']}';
            return email.isNotEmpty &&
                email != Session.email &&
                seen.add(email);
          })
          .take(10)
          .toList();
      if (mounted) setState(() => _recent = recent);
    } catch (error) {
      if (mounted) setState(() => _recentError = userFacingError(error));
    } finally {
      if (mounted) setState(() => _recentLoading = false);
    }
  }

  Future<void> _loadApps() async {
    try {
      final apps = await _links.invokeListMethod<dynamic>('getShareTargets');
      if (mounted) {
        setState(
          () => _apps = (apps ?? [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .where((row) => '${row['id'] ?? ''}'.isNotEmpty)
              .take(5)
              .toList(),
        );
      }
    } on MissingPluginException {
      // The system More action remains available on older app builds.
    } on PlatformException {
      // App discovery is optional; More uses the system share sheet.
    }
  }

  void _showMore() {
    if (_sending) return;
    setState(() {
      _more = true;
      _error = null;
    });
    unawaited(_load());
  }

  void _back() {
    _debounce?.cancel();
    ++_version;
    FocusManager.instance.primaryFocus?.unfocus();
    _search.clear();
    setState(() {
      _more = false;
      _loading = false;
      _loadingMore = false;
      _error = null;
    });
  }

  Future<void> _load({bool append = false}) async {
    if (append && (!_hasMore || _loadingMore || _loading)) return;
    final version = ++_version;
    final tab = _tab, offset = append ? _offset : 0;
    final query = _search.text.trim();
    setState(() {
      _error = null;
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _rows = [];
      }
    });
    try {
      List<Map<String, dynamic>> rows;
      var more = false, nextOffset = 0;
      if (tab < 2) {
        final relation = tab == 0 ? 'followers' : 'following';
        final people = await CommunityApi.instance.list(
          '/people?relation=$relation&q=${Uri.encodeQueryComponent(query)}&offset=$offset&limit=50',
        );
        rows = people
            .where(
              (row) =>
                  row['email'] != Session.email &&
                  '${row['email'] ?? ''}'.isNotEmpty,
            )
            .map(_person)
            .toList();
        more = people.length == 50;
        nextOffset = offset + people.length;
      } else {
        final kind = tab == 2 ? 'groups' : 'circles';
        rows = (await CommunityApi.instance.list('/$kind'))
            .where(
              (row) =>
                  (row['membership'] == 'active' || row['canManage'] == true) &&
                  row['chatPermission'] != 'off' &&
                  (row['chatPermission'] != 'admins' ||
                      row['canManage'] == true),
            )
            .map(
              (row) => <String, dynamic>{
                'kind': kind,
                'target': '${row['_id']}',
                'name': '${row['name'] ?? row['title'] ?? ''}',
                'image': row['iconImage'] ?? row['image'] ?? '',
              },
            )
            .where(
              (row) =>
                  '${row['name']}'.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
      if (mounted && version == _version) {
        setState(() {
          final unique = <String, Map<String, dynamic>>{
            if (append)
              for (final row in _rows) _key(row): row,
            for (final row in rows) _key(row): row,
          };
          _rows = unique.values.toList();
          _hasMore = more;
          _offset = nextOffset;
        });
      }
    } catch (error) {
      if (mounted && version == _version) {
        setState(() => _error = userFacingError(error));
      }
    } finally {
      if (mounted && version == _version) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _toggle(Map<String, dynamic> row) {
    final key = _key(row);
    if (_sending || _sent.contains(key)) return;
    setState(() {
      if (_selected.containsKey(key)) {
        _selected.remove(key);
      } else {
        _selected[key] = row;
      }
    });
  }

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final failed = <String>[];
    for (final row in _selected.values.toList()) {
      try {
        final direct = row['kind'] == 'direct';
        final result = await CommunityApi.instance.request(
          _forwarding
              ? '/message-forward'
              : direct
              ? '/direct/messages'
              : '/${row['kind']}/${row['target']}/messages',
          method: 'POST',
          body: _forwarding
              ? {
                  ...widget.source,
                  'messageIds': widget.messageIds,
                  'requestId': _forwardRequestId,
                  'destination': direct
                      ? {'email': row['target']}
                      : {'kind': row['kind'], 'roomId': row['target']},
                }
              : {'sharedPostId': _postId, if (direct) 'email': row['target']},
        );
        if (result is! Map ||
            (_forwarding
                ? result['forwarded'] != widget.messageIds.length
                : '${result['sharedPostId'] ?? ''}' != _postId)) {
          throw Exception('Post sharing is not available yet.');
        }
        _sent.add(_key(row));
        _selected.remove(_key(row));
        _changed = true;
        ChatUpdates.instance.notifyChanged();
      } catch (error) {
        failed.add('${row['name']}: ${userFacingError(error)}');
      }
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = failed.isEmpty ? null : failed.join('\n');
    });
    if (failed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 64),
          padding: const EdgeInsets.symmetric(vertical: 8),
          duration: const Duration(milliseconds: 1200),
          content: const Text(
            'Sent',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: clubFontFamily,
              color: Color(0xFF21845B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
      Navigator.of(context).pop(_changed);
    }
  }

  Future<void> _copyLink() async {
    try {
      await Clipboard.setData(ClipboardData(text: _link));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Link copied')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _external([Map<String, dynamic>? app]) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _links.invokeMethod('sharePost', {
        'text': _link,
        if (app != null) 'target': app['id'],
      });
      _changed = true;
      if (Session.token.isNotEmpty) {
        try {
          await PostsApi.instance.request(
            '/api/user/posts/$_postId/share',
            method: 'POST',
          );
        } catch (_) {
          /* An unavailable counter must not undo a launched share. */
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _header() => Column(
    children: [
      Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFC9CBD0),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      Row(
        children: [
          if (_more)
            IconButton(
              tooltip: 'Back to sharing',
              onPressed: _sending ? null : _back,
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              _more
                  ? 'Send to'
                  : _forwarding
                  ? 'Forward'
                  : 'Share',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Close sharing',
            onPressed: _sending ? null : () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ],
  );

  Widget _tile({
    required String label,
    required Widget icon,
    required VoidCallback? onTap,
    Key? key,
    bool selected = false,
  }) => SizedBox(
    width: 82,
    child: InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox.square(dimension: 58, child: icon),
                if (selected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: brandAccent,
                        size: 21,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _roundIcon(
    IconData icon, {
    Color color = const Color(0xFF292D34),
    Color background = Colors.white,
  }) => CircleAvatar(
    backgroundColor: background,
    child: Icon(icon, color: color, size: 27),
  );
  Widget _appIcon(Map<String, dynamic> app) {
    final bytes = app['icon'];
    if (bytes is Uint8List) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Image.memory(
          bytes,
          errorBuilder: (_, _, _) => _roundIcon(Icons.share),
        ),
      );
    }
    return _roundIcon(
      Icons.chat_bubble_rounded,
      color: Colors.white,
      background: app['id'] == 'whatsapp'
          ? const Color(0xFF25D366)
          : const Color(0xFF279FDA),
    );
  }

  Widget _home() => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(),
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text(
              'Recent chats',
              style: TextStyle(fontSize: 13, color: Color(0xFF656B75)),
            ),
          ),
        ),
        if (Session.token.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Log in to send to people, groups and huddles.'),
          )
        else if (_recentLoading)
          const SizedBox(
            height: 118,
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (_recentError != null)
            TextButton(
              onPressed: _loadRecent,
              child: const Text('Retry recent chats'),
            ),
          SizedBox(
            height: 118,
            child: ListView(
              key: const ValueKey('share-recent-list'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final row in _recent)
                  _tile(
                    label: '${row['name']}',
                    key: ValueKey('share-recipient-${_key(row)}'),
                    icon: IgnorePointer(
                      child: UserAvatar(
                        name: '${row['name']}',
                        image: '${row['image']}',
                        radius: 29,
                      ),
                    ),
                    selected:
                        _selected.containsKey(_key(row)) ||
                        _sent.contains(_key(row)),
                    onTap: _sending ? null : () => _toggle(row),
                  ),
                _tile(
                  key: const ValueKey('share-more-people'),
                  label: 'More',
                  icon: _roundIcon(
                    Icons.more_horiz,
                    background: const Color(0xFFE8EBF0),
                  ),
                  onTap: _sending ? null : _showMore,
                ),
              ],
            ),
          ),
        ],
        if (!_forwarding) ...[
          const Divider(height: 16, indent: 20, endIndent: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                'Share to apps',
                style: TextStyle(fontSize: 13, color: Color(0xFF656B75)),
              ),
            ),
          ),
          SizedBox(
            height: 118,
            child: ListView(
              key: const ValueKey('share-app-list'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _tile(
                  key: const ValueKey('share-copy-link'),
                  label: 'Copy link',
                  icon: _roundIcon(Icons.link),
                  onTap: _sending ? null : _copyLink,
                ),
                for (final app in _apps)
                  _tile(
                    key: ValueKey('share-app-${app['id']}'),
                    label: '${app['label']}',
                    icon: _appIcon(app),
                    onTap: _sending ? null : () => _external(app),
                  ),
                _tile(
                  key: const ValueKey('share-more-apps'),
                  label: 'More',
                  icon: _roundIcon(Icons.more_horiz),
                  onTap: _sending ? null : _external,
                ),
              ],
            ),
          ),
        ],
        if (_error != null) _errorText(),
        if (_selected.isNotEmpty || _sending) _sendButton(),
        const SizedBox(height: 8),
      ],
    ),
  );
  Widget _errorText() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Text(
      _error!,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.red, fontSize: 12),
    ),
  );
  Widget _sendButton() => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFEEF0F3))),
    ),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _sending || _selected.isEmpty ? null : _send,
        style: FilledButton.styleFrom(
          backgroundColor: brandAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _sending
              ? brandAccent
              : const Color(0xFFF0F2F5),
          disabledForegroundColor: _sending
              ? Colors.white
              : const Color(0xFF9299A5),
          minimumSize: const Size(0, 50),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: clubFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sending)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.send_rounded, size: 18),
            const SizedBox(width: 9),
            Text(
              _sending
                  ? 'Sending…'
                  : _selected.isEmpty
                  ? 'Send'
                  : 'Send (${_selected.length})',
            ),
          ],
        ),
      ),
    ),
  );

  Widget _recipients() => Column(
    children: [
      _header(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: _search,
          enabled: !_sending,
          decoration: InputDecoration(
            hintText: 'Search',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: const Color(0xFFF0F2F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) {
            _debounce?.cancel();
            ++_version;
            _debounce = Timer(const Duration(milliseconds: 300), _load);
          },
        ),
      ),
      SizedBox(
        height: 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _tabs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, index) => Center(
            child: ChoiceChip(
              label: Text(
                _tabs[index],
                style: TextStyle(
                  fontFamily: clubFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _tab == index ? Colors.white : const Color(0xFF292D34),
                ),
              ),
              selected: _tab == index,
              showCheckmark: false,
              selectedColor: brandAccent,
              backgroundColor: const Color(0xFFF5F6F8),
              side: BorderSide(
                color: _tab == index ? brandAccent : const Color(0xFFEBEDF1),
              ),
              shape: const StadiumBorder(),
              onSelected: _sending
                  ? null
                  : (_) {
                      _debounce?.cancel();
                      setState(() => _tab = index);
                      unawaited(_load());
                    },
            ),
          ),
        ),
      ),
      if (_error != null) _errorText(),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
            ? Center(
                child: _error != null
                    ? TextButton(onPressed: _load, child: const Text('Retry'))
                    : const Text('No recipients found'),
              )
            : ListView.builder(
                itemCount: _rows.length + (_hasMore ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index == _rows.length) {
                    return Center(
                      child: TextButton(
                        onPressed: _loadingMore
                            ? null
                            : () => _load(append: true),
                        child: Text(_loadingMore ? 'Loading…' : 'Load more'),
                      ),
                    );
                  }
                  final row = _rows[index];
                  final key = _key(row);
                  final sent = _sent.contains(key);
                  final selected = _selected.containsKey(key);
                  return Semantics(
                    selected: selected,
                    button: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 3,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('share-recipient-$key'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: _sending || sent ? null : () => _toggle(row),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFFFF3F7)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFEBC4D1)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                IgnorePointer(
                                  child: UserAvatar(
                                    name: '${row['name']}',
                                    image: '${row['image']}',
                                    radius: 23,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${row['name']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: clubFontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF242832),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (sent)
                                  const Text(
                                    'Sent',
                                    style: TextStyle(
                                      fontFamily: clubFontFamily,
                                      color: Color(0xFF21845B),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 23,
                                    height: 23,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? brandAccent
                                          : Colors.white,
                                      border: Border.all(
                                        color: selected
                                            ? brandAccent
                                            : const Color(0xFFD9DDE4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: selected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 15,
                                          )
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      _sendButton(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available =
        (media.size.height - media.padding.top - media.viewInsets.bottom).clamp(
          0.0,
          media.size.height,
        );
    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Material(
          color: _more ? Colors.white : const Color(0xFFF3F4F8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : appMotionDuration,
              curve: appMotionCurve,
              alignment: Alignment.bottomCenter,
              child: _more
                  ? SizedBox(height: available * .94, child: _recipients())
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: available * .82),
                      child: _home(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
