import '../widgets/club_page_body.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/user_avatar.dart';

import '../club_repository.dart';
import '../posts_api.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/club_bar.dart';
import '../widgets/feed_post_card.dart';
import '../realtime_client.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.scrollController,
    this.onCompose,
  });
  final String postId;
  final ScrollController? scrollController;
  final VoidCallback? onCompose;

  static Future<void> showComments(BuildContext context, String postId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        enableDrag: false,
        builder: (_) => _CommentsSheet(postId: postId),
      );
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _comment = TextEditingController();
  final _focus = FocusNode();
  final _liking = <String>{};
  Map<String, dynamic>? _post, _replyTo;
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true, _sending = false;
  String _error = '';
  int _loadVersion = 0;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  @override
  void initState() {
    super.initState();
    _load();
    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (event['resource'] == 'all' ||
          (event['resource'] == 'posts' && event['id'] == widget.postId)) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _comment.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    try {
      final post = await PostsApi.instance.getPost(widget.postId);
      final data = await PostsApi.instance.request(
        '${PostsApi.instance.readPath}/${widget.postId}/comments',
      );
      if (mounted && version == _loadVersion) {
        setState(() {
          _post = post;
          _comments = (data['comments'] as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
          _error = '';
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

  Future<void> _like(Map<String, dynamic> comment) async {
    final id = comment['_id']?.toString();
    if (id == null || _liking.contains(id)) {
      return;
    }
    if (Session.token.isEmpty) {
      _showError('Please log in to like comments.');
      return;
    }
    setState(() => _liking.add(id));
    try {
      final response = await PostsApi.instance.request(
        '/api/user/posts/${widget.postId}/comments/$id/like',
        method: 'PUT',
        body: {'liked': comment['liked'] != true},
      );
      final updated = Map<String, dynamic>.from(response['comment'] as Map);
      if (mounted) {
        setState(() {
          for (final row in _comments) {
            if (row['_id'] == comment['_id']) {
              row.addAll(updated);
            }
          }
        });
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _liking.remove(id));
      }
    }
  }

  void _reply(Map<String, dynamic> comment) {
    if (Session.token.isEmpty) {
      _showError('Please log in to reply.');
      return;
    }
    setState(() => _replyTo = comment);
    widget.onCompose?.call();
    _focus.requestFocus();
  }

  Future<void> _send() async {
    if (_comment.text.trim().isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await PostsApi.instance.request(
        '/api/user/posts/${widget.postId}/comments',
        method: 'POST',
        body: {
          'text': _comment.text,
          if (_replyTo != null) 'parentId': _replyTo!['_id'],
        },
      );
      if (!mounted) {
        return;
      }
      _comment.clear();
      setState(() => _replyTo = null);
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String _age(Object? value) {
    final date = DateTime.tryParse('$value');
    if (date == null) {
      return '';
    }
    final age = DateTime.now().difference(date);
    if (age.inDays > 0) {
      return '${age.inDays}d';
    }
    if (age.inHours > 0) {
      return '${age.inHours}h';
    }
    if (age.inMinutes > 0) {
      return '${age.inMinutes}m';
    }
    return 'now';
  }

  Widget _commentRow(Map<String, dynamic> comment, {bool reply = false}) {
    final id = comment['_id']?.toString();
    final liked = comment['liked'] == true;
    final busy = id == null || _liking.contains(id);
    final name = '${comment['authorName'] ?? 'Highlander'}';
    final image = ClubRepository.mediaUrl(comment['authorImage']);
    final onLike = busy ? null : () => _like(comment);
    return Padding(
      padding: EdgeInsets.only(top: 14, left: reply ? 28 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: '${comment['authorId'] ?? comment['created_by'] ?? ''}',
            email: '${comment['authorEmail'] ?? ''}',
            name: name,
            image: image,
            radius: reply ? 14 : 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (reply && comment['replyToName'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Reply to ${comment['replyToName']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: authMuted,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text('${comment['text'] ?? ''}'),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _age(comment['createdAt']),
                      style: const TextStyle(fontSize: 11, color: authMuted),
                    ),
                    TextButton(
                      key: ValueKey('comment-like-$id'),
                      onPressed: onLike,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: liked ? authRed : clubInk,
                      ),
                      child: Text(
                        liked ? 'Unlike' : 'Like',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      key: ValueKey('comment-reply-$id'),
                      onPressed: _sending || id == null
                          ? null
                          : () => _reply(comment),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        foregroundColor: clubInk,
                      ),
                      child: const Text(
                        'Reply',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${comment['likes'] ?? 0}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      tooltip: liked ? 'Unlike comment' : 'Like comment',
                      onPressed: onLike,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 36,
                      ),
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: authRed,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<({Map<String, dynamic> comment, bool reply})> _discussion() {
    final ids = _comments
        .map((row) => row['_id'])
        .where((id) => id != null)
        .toSet();
    final roots = _comments.where(
      (row) => row['parentId'] == null || !ids.contains(row['parentId']),
    );
    return [
      for (final root in roots) ...[
        (comment: root, reply: false),
        if (root['_id'] != null)
          for (final reply in _comments.where(
            (row) => row['parentId'] == root['_id'],
          ))
            (comment: reply, reply: true),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isSheet = widget.scrollController != null;
    final discussion = _discussion();
    return ClubScaffold(
      backgroundColor: Colors.white,
      appBar: isSheet ? null : const ClubBar(title: 'Comment'),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _post == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error.isEmpty ? 'Post unavailable' : _error),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: CustomScrollView(
                      key: const ValueKey('comments-scroll'),
                      controller: widget.scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (isSheet)
                          SliverAppBar(
                            pinned: true,
                            primary: false,
                            automaticallyImplyLeading: false,
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.white,
                            foregroundColor: clubInk,
                            toolbarHeight: 72,
                            title: Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCED0D4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const Text(
                                  'Comments',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            centerTitle: true,
                            actions: [
                              IconButton(
                                tooltip: 'Close comments',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        if (!isSheet)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: FeedPostCard(
                                post: _post!,
                                openComments: false,
                                onChanged: _load,
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_comments.length} Comments',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_error.isNotEmpty)
                                  TextButton(
                                    onPressed: _load,
                                    child: Text('$_error Tap to retry.'),
                                  ),
                                if (_comments.isEmpty && _error.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: Center(
                                      child: Text(
                                        'No comments yet. Start the conversation!',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverList.builder(
                            itemCount: discussion.length,
                            itemBuilder: (context, index) => _commentRow(
                              discussion[index].comment,
                              reply: discussion[index].reply,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE4E6EB))),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyTo != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Replying to ${_replyTo!['authorName'] ?? 'Highlander'}',
                              style: const TextStyle(
                                color: authRed,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cancel reply',
                            onPressed: _sending
                                ? null
                                : () => setState(() => _replyTo = null),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _comment,
                            focusNode: _focus,
                            onTap: widget.onCompose,
                            enabled: !_sending,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 1000,
                            decoration: InputDecoration(
                              hintText: _replyTo == null
                                  ? 'Comment as ${Session.name}'
                                  : 'Write a reply...',
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFFF0F2F5),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _replyTo == null
                              ? 'Send comment'
                              : 'Send reply',
                          onPressed: _sending || _post == null ? null : _send,
                          icon: const Icon(Icons.send, color: authRed),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.postId});
  final String postId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = DraggableScrollableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _expand() {
    if (_controller.isAttached) {
      _controller.animateTo(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: DraggableScrollableSheet(
        controller: _controller,
        initialChildSize: .65,
        minChildSize: .4,
        maxChildSize: 1,
        snap: true,
        snapSizes: const [.65],
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: PostDetailScreen(
            postId: widget.postId,
            scrollController: scrollController,
            onCompose: _expand,
          ),
        ),
      ),
    ),
  );
}
