import '../brand_colors.dart';
import 'package:flutter/material.dart';

import '../post_reaction.dart';
import '../posts_api.dart';
import '../widgets/feed_post_card.dart';
import '../widgets/user_avatar.dart';
import '../widgets/club_header.dart';
import '../widgets/club_page_body.dart';
import 'user_profile_screen.dart';

class PostActivityScreen extends StatefulWidget {
  const PostActivityScreen({
    super.key,
    required this.post,
    this.reposts = false,
  });
  final Map<String, dynamic> post;
  final bool reposts;

  @override
  State<PostActivityScreen> createState() => _PostActivityScreenState();
}

class _PostActivityScreenState extends State<PostActivityScreen> {
  final _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _counts = {};
  String? _filter;
  String _error = '';
  bool _loading = true, _more = false;
  int _version = 0, _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    final version = ++_version;
    final offset = append ? _rows.length : 0;
    setState(() {
      _loading = true;
      _error = '';
      if (!append) _rows.clear();
    });
    try {
      final id = widget.post['_id'] ?? widget.post['id'];
      // The shares endpoint returns repost posts plus an external-share total.
      final resource = widget.reposts ? 'shares' : 'reactions';
      final data = await PostsApi.instance.request(
        '${PostsApi.instance.readPath}/$id/$resource?offset=$offset'
        '${_filter == null ? '' : '&type=$_filter'}',
      );
      if (!mounted || version != _version) return;
      setState(() {
        if (!append) _rows.clear();
        _rows.addAll(
          (data['items'] as List).map(
            (row) => Map<String, dynamic>.from(row as Map),
          ),
        );
        _counts = Map<String, dynamic>.from(data['counts'] as Map? ?? {});
        final total = (data['total'] as num?)?.toInt() ?? 0;
        final externalShares = (data['externalShares'] as num?)?.toInt() ?? 0;
        _total = widget.reposts
            ? (total > externalShares ? total - externalShares : 0)
            : total;
        _more = data['hasMore'] == true;
      });
    } catch (error) {
      if (mounted && version == _version) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ClubScaffold(
    appBar: ClubHeader(
      title: widget.reposts ? 'People who reposted this' : 'Reactions',
      showBack: true,
      showSearch: false,
      showSupport: false,
      uppercaseTitle: false,
    ),
    body: Column(
      children: [
        if (!widget.reposts)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    selectedColor: brandAccent,
                    labelStyle: TextStyle(
                      color: _filter == null ? Colors.white : const Color(0xFF171717),
                    ),
                    label: Text('All $_total'),
                    selected: _filter == null,
                    onSelected: (_) {
                      _filter = null;
                      _load();
                    },
                  ),
                ),
                for (final reaction in PostReaction.values)
                  if ((_counts[reaction.name] as num? ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        selectedColor: brandAccent,
                        labelStyle: TextStyle(
                          color: _filter == reaction.name ? Colors.white : const Color(0xFF171717),
                        ),
                        label: Text(
                          '${reaction.emoji} ${_counts[reaction.name]}',
                        ),
                        selected: _filter == reaction.name,
                        onSelected: (_) {
                          _filter = reaction.name;
                          _load();
                        },
                      ),
                    ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.reposts) ...[
                  FeedPostCard(post: widget.post, showActions: false),
                  const SizedBox(height: 16),
                  Text(
                    '$_total reposts',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final row in _rows)
                  if (widget.reposts && row['post'] is Map)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FeedPostCard(
                        post: Map<String, dynamic>.from(row['post'] as Map),
                      ),
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(
                        userId: '${row['userId'] ?? ''}',
                        name: '${row['name'] ?? 'Highlander'}',
                        image: '${row['image'] ?? ''}',
                      ),
                      title: Text('${row['name'] ?? 'Highlander'}'),
                      subtitle: widget.reposts
                          ? const Text('Reposted this post')
                          : null,
                      trailing: widget.reposts
                          ? const Icon(Icons.repeat)
                          : Text(
                              (PostReaction.fromValue(row['reactionType']) ??
                                      PostReaction.like)
                                  .emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                      onTap: '${row['userId'] ?? ''}'.isEmpty
                          ? null
                          : () => openUserProfile(context, '${row['userId']}'),
                    ),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_error.isNotEmpty) ...[
                  Text(_error),
                  TextButton(
                    onPressed: () => _load(append: _rows.isNotEmpty),
                    child: const Text('Retry'),
                  ),
                ] else if (!_loading && _rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.reposts ? 'No reposts yet.' : 'No reactions yet.',
                    ),
                  ),
                if (_more && !_loading && _error.isEmpty)
                  TextButton(
                    onPressed: () => _load(append: true),
                    child: const Text('Load more'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class PostActivitySummary extends StatelessWidget {
  const PostActivitySummary({super.key, required this.post, this.color});
  final Map<String, dynamic> post;
  final Color? color;

  void _open(BuildContext context, bool reposts) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PostActivityScreen(post: post, reposts: reposts),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: color,
            alignment: Alignment.centerLeft,
          ),
          onPressed: () => _open(context, false),
          child: Text('👍  ${post['likes'] ?? 0} reactions'),
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: color),
        onPressed: () => _open(context, true),
        child: Text(
          "${post['reposts'] ?? 0} ${(post['reposts'] as num? ?? 0) == 1 ? 'repost' : 'reposts'}",
        ),
      ),
    ],
  );
}
