import '../brand_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../club_repository.dart';
import '../media_cache.dart';
import '../otp_api.dart';
import '../posts_api.dart';
import '../post_reaction.dart';
import '../post_link_router.dart';
import '../theme.dart';
import '../session.dart';
import '../screens/post_detail_screen.dart';
import '../screens/repost_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/reels_screen.dart';
import '../screens/photo_viewer_screen.dart';
import 'post_video.dart';
import 'post_photo_carousel.dart';
import 'user_avatar.dart';

const _postRed = brandAccent;

class FeedPostCard extends StatefulWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    this.showActions = true,
    this.openComments = true,
    this.onChanged,
    this.videoPosts = const [],
  });
  final Map<String, dynamic> post;
  final bool showActions;
  final bool openComments;
  final VoidCallback? onChanged;
  final List<Map<String, dynamic>> videoPosts;
  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  late Map<String, dynamic> _post;
  bool _busy = false;
  bool _deleted = false;
  final _likeButtonKey = GlobalKey();

  String get _postId =>
      _post['_id']?.toString() ?? _post['id']?.toString() ?? '';

  bool get _isOwnPost {
    if (_post['isOwnPost'] == true) return true;
    final authorId =
        _post['authorId'] as String? ?? _post['userId'] as String? ?? '';
    if (authorId.isNotEmpty &&
        Session.userId.isNotEmpty &&
        authorId == Session.userId) {
      return true;
    }
    final authorEmail = _post['authorEmail'] as String? ?? '';
    if (authorEmail.isNotEmpty &&
        Session.email.isNotEmpty &&
        authorEmail.toLowerCase() == Session.email.toLowerCase()) {
      return true;
    }
    return false;
  }

  Color _hexToColor(String hex, {Color fallback = Colors.black}) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
      if (clean.length == 3) {
        final r = clean[0];
        final g = clean[1];
        final b = clean[2];
        return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _showEditDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(
      text: _post['content'] as String? ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          const line = Color(0xFFE7E4DE);
          final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: line),
          );
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit Post',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10141A),
                              letterSpacing: -.2,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                    const Text(
                      'Update the text on your post.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6D7383),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: controller,
                      maxLines: 5,
                      minLines: 4,
                      maxLength: 500,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E2229),
                      ),
                      decoration: InputDecoration(
                        hintText: 'What do you want to share?',
                        counterStyle: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A92A0),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F5F3),
                        contentPadding: const EdgeInsets.all(14),
                        border: border,
                        enabledBorder: border,
                        focusedBorder: border.copyWith(
                          borderSide: const BorderSide(
                            color: clubRed,
                            width: 1.4,
                          ),
                        ),
                      ),
                      validator: (val) {
                        final trimmed = val?.trim() ?? '';
                        final hasMedia =
                            (_post['images'] as List?)?.isNotEmpty == true ||
                            (_post['image'] as String? ?? '').isNotEmpty ||
                            (_post['video'] as String? ?? '').isNotEmpty;
                        if (trimmed.isEmpty && !hasMedia) {
                          return 'Please enter some text.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3A3F48),
                              side: const BorderSide(color: line),
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: clubRed,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setDlgState(() => saving = true);
                                    try {
                                      final updated = await PostsApi.instance
                                          .updatePost(
                                            _post['_id'] as String,
                                            content: controller.text.trim(),
                                          );
                                      if (!mounted) return;
                                      setState(() => _post = updated);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Post updated successfully',
                                          ),
                                          backgroundColor: Color(0xFF10B981),
                                        ),
                                      );
                                      widget.onChanged?.call();
                                    } catch (e) {
                                      setDlgState(() => saving = false);
                                      _error(e);
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDeleteDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    bool deleting = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(Icons.delete_outline, color: clubRed, size: 22),
                SizedBox(width: 8),
                Text(
                  'Delete Post',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              'Are you sure you want to delete this post? This action cannot be undone.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: deleting ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: clubRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: deleting
                    ? null
                    : () async {
                        setDlgState(() => deleting = true);
                        try {
                          await PostsApi.instance.deletePost(
                            _post['_id'] as String,
                          );
                          if (!mounted) return;
                          setState(() => _deleted = true);
                          if (ctx.mounted) Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Post deleted successfully'),
                              backgroundColor: clubRed,
                            ),
                          );
                          widget.onChanged?.call();
                        } catch (e) {
                          setDlgState(() => deleting = false);
                          _error(e);
                        }
                      },
                child: deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showReportDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    String selectedReason = 'Spam or Misleading';
    final reasons = [
      'Spam or Misleading',
      'Harassment or Bullying',
      'Hate Speech',
      'Violence or Dangerous',
      'Inappropriate Content',
      'Other',
    ];
    bool reporting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(Icons.flag_outlined, color: clubRed, size: 22),
                SizedBox(width: 8),
                Text(
                  'Report Post',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why are you reporting this post?',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  ...reasons.map(
                    (r) => InkWell(
                      onTap: () => setDlgState(() => selectedReason = r),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedReason == r
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selectedReason == r
                                  ? clubRed
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(r, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: reporting ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: clubRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: reporting
                    ? null
                    : () async {
                        setDlgState(() => reporting = true);
                        try {
                          await PostsApi.instance.reportPost(
                            _post['_id'] as String,
                            reason: selectedReason,
                          );
                          if (!mounted) return;
                          if (ctx.mounted) Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Report submitted. Thank you for keeping Highlanders safe.',
                              ),
                              backgroundColor: Colors.black87,
                            ),
                          );
                        } catch (e) {
                          setDlgState(() => reporting = false);
                          _error(e);
                        }
                      },
                child: reporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Report'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showBlockDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final author = _post['authorName'] as String? ?? 'this user';
    bool blocking = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(Icons.block_outlined, color: Colors.redAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Block User',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to block $author? You won\'t see posts from this user anymore.',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: blocking ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: brandAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: blocking
                    ? null
                    : () async {
                        setDlgState(() => blocking = true);
                        try {
                          await PostsApi.instance.blockUser(
                            _post['_id'] as String,
                          );
                          if (!mounted) return;
                          setState(() => _deleted = true);
                          if (ctx.mounted) Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('$author has been blocked.'),
                              backgroundColor: Colors.black87,
                            ),
                          );
                          widget.onChanged?.call();
                        } catch (e) {
                          setDlgState(() => blocking = false);
                          _error(e);
                        }
                      },
                child: blocking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Block'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _post = widget.post;
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _pickReaction() async {
    if (_busy) return;
    final button = _likeButtonKey.currentContext?.findRenderObject();
    if (button is! RenderBox || !button.hasSize) return;
    final reaction = await showPostReactionPicker(
      context,
      anchor: button.localToGlobal(Offset.zero) & button.size,
    );
    if (mounted && reaction != null) await _like(reaction: reaction);
  }

  Future<void> _like({PostReaction? reaction}) async {
    final id = _postId;
    if (id.isEmpty || _busy) return;
    if (Session.token.isEmpty) {
      _error('Please log in to like posts.');
      return;
    }
    final wasLiked = _post['liked'] == true;
    final previousReaction = _post['reactionType'];
    final currentLikes = (_post['likes'] as num?)?.toInt() ?? 0;
    final nextLiked = reaction != null || !wasLiked;
    final nextReaction = nextLiked
        ? (reaction ?? PostReaction.like).name
        : null;
    final nextLikes = nextLiked == wasLiked
        ? currentLikes
        : nextLiked
        ? currentLikes + 1
        : (currentLikes > 0 ? currentLikes - 1 : 0);

    setState(() {
      _busy = true;
      _post['liked'] = nextLiked;
      _post['likes'] = nextLikes;
      _post['reactionType'] = nextReaction;
    });

    try {
      final result = await PostsApi.instance.request(
        '/api/user/posts/$id/like',
        method: 'PUT',
        body: {'liked': nextLiked, 'reactionType': nextReaction},
      );
      if (mounted && result['post'] is Map) {
        final updated = Map<String, dynamic>.from(result['post'] as Map);
        _post.addAll(updated);
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _post['liked'] = wasLiked;
          _post['likes'] = currentLikes;
          _post['reactionType'] = previousReaction;
        });
      }
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _comments() async {
    final id = _postId;
    if (id.isEmpty) return;
    await PostDetailScreen.showComments(context, id);
    await _reload();
    widget.onChanged?.call();
  }

  Future<void> _repost() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RepostScreen(post: _post)),
    );
    await _reload();
    widget.onChanged?.call();
  }

  Future<void> _reload() async {
    final id = _postId;
    if (id.isEmpty) return;
    try {
      final post = await PostsApi.instance.getPost(id);
      if (mounted) setState(() => _post = post);
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _share() async {
    try {
      final link = sharedPostUrl('${_post['_id']}');
      await const MethodChannel(
        'highlanders/app_links',
      ).invokeMethod('sharePost', {'text': '${_post['content'] ?? ''}\n$link'});
      if (Session.token.isEmpty) return;
      // Count a share-sheet launch; external app delivery cannot be confirmed.
      final result = await PostsApi.instance.request(
        '/api/user/posts/${_post['_id']}/share',
        method: 'POST',
      );
      if (mounted) {
        setState(() => _post = result['post'] as Map<String, dynamic>);
      }
    } catch (error) {
      _error(error);
    }
  }

  String _time() {
    final date = DateTime.tryParse(_post['createdAt'] as String? ?? '');
    if (date == null) return '';
    final age = DateTime.now().difference(date);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  Widget _postImage(String source, {BoxFit fit = BoxFit.contain}) =>
      _CachedPostImage(source: source, fit: fit);

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const SizedBox.shrink();
    final official = _post['official'] == true;
    final rawBg = _post['backgroundColor'] as String?;
    Color? customBg;
    if (rawBg != null && rawBg.isNotEmpty) {
      try {
        final hex = rawBg.replaceFirst('#', '');
        if (hex.length == 6) {
          customBg = Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          customBg = Color(int.parse(hex, radix: 16));
        }
      } catch (_) {}
    }
    final cardBg =
        customBg ??
        (official ? const Color(0xFF131313) : const Color(0xFFFFFCFF));
    final isDarkBg = cardBg.computeLuminance() < 0.5;
    final color = isDarkBg ? Colors.white : clubInk;
    final mutedColor = isDarkBg
        ? const Color(0xFFC9C9C9)
        : const Color(0xFF77727D);
    final actionColor = isDarkBg ? Colors.white : const Color(0xFF171717);
    final time = _time();
    final avatar = _post['authorImage'] as String? ?? '';
    final image = (_post['image'] as String? ?? '').trim();
    final rawImages =
        (_post['images'] as List?)
            ?.map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final images = rawImages.isNotEmpty
        ? rawImages.toSet().toList()
        : (image.isNotEmpty ? <String>[image] : <String>[]);
    final maxImageHeight = MediaQuery.sizeOf(context).height * .42;
    final video = _post['video'] as String? ?? '';
    final author = _post['authorName'] as String? ?? 'Highlander';
    return Container(
      key: ValueKey('post-card-${_post['_id']}'),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(
        color: cardBg,
        gradient: customBg == null && !isDarkBg
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFFFF8FB)],
              )
            : null,
        borderRadius: BorderRadius.circular(22),
        border: Border.fromBorderSide(
          BorderSide(
            color: isDarkBg ? const Color(0x26FFFFFF) : const Color(0x80F0DCE5),
            width: .8,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkBg ? const Color(0x1AE4003B) : const Color(0x12900F32),
            blurRadius: 26,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
          const BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
          const BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 6),
              official
                  ? CircleAvatar(
                      radius: 30,
                      backgroundColor: authRed,
                      child: avatar.isEmpty
                          ? Icon(
                              official
                                  ? Icons.shield_outlined
                                  : Icons.person_outline,
                              color: Colors.white,
                              size: 24,
                            )
                          : ClipOval(
                              child: Image.network(
                                Uri.parse(OtpApi.apiBase)
                                    .resolve(avatar)
                                    .toString(),
                                key: ValueKey(
                                  'post-avatar-$avatar-${MediaCache.instance.generation.value}',
                                ),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stack) => Icon(
                                  official
                                      ? Icons.shield_outlined
                                      : Icons.person_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _postRed, width: 1.5),
                      ),
                      child: UserAvatar(
                        userId: '${_post['authorId'] ?? _post['userId'] ?? ''}',
                        email: '${_post['authorEmail'] ?? ''}',
                        currentUser: _isOwnPost,
                        name: author,
                        image: avatar,
                        radius: 26,
                      ),
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap:
                                official || '${_post['authorId'] ?? ''}'.isEmpty
                                ? null
                                : () => openUserProfile(
                                    context,
                                    '${_post['authorId']}',
                                  ),
                            child: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.2,
                              ),
                            ),
                          ),
                        ),
                        if (official) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.check_circle_outline,
                            color: clubRed,
                            size: 16,
                            semanticLabel: 'Verified admin',
                          ),
                        ],
                      ],
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                    // if (official) ...[
                    //   const SizedBox(height: 5),
                    //   Container(
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 10,
                    //       vertical: 3,
                    //     ),
                    //     decoration: BoxDecoration(
                    //       color: const Color(0xFFB80C1C),
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     // child: const Text(
                    //     //   'CLUB UPDATE',
                    //     //   style: TextStyle(
                    //     //     color: Colors.white,
                    //     //     fontSize: 10,
                    //     //     fontWeight: FontWeight.w700,
                    //     //   ),
                    //     // ),
                    //   ),
                    // ],
                  ],
                ),
              ),
              if (!official)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  offset: const Offset(0, 40),
                  color: Colors.white,
                  elevation: 12,
                  shadowColor: const Color(0x2E000000),
                  surfaceTintColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.transparent,
                  ),
                  icon: Icon(Icons.more_horiz, color: actionColor, size: 22),
                  onSelected: (value) async {
                    if (value == 'copy') {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        ClipboardData(text: sharedPostUrl('${_post['_id']}')),
                      );
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard'),
                        ),
                      );
                    } else if (value == 'edit') {
                      await _showEditDialog();
                    } else if (value == 'delete') {
                      await _showDeleteDialog();
                    } else if (value == 'report') {
                      await _showReportDialog();
                    } else if (value == 'block') {
                      await _showBlockDialog();
                    }
                  },
                  itemBuilder: (_) {
                    if (_isOwnPost) {
                      return const [
                        PopupMenuItem(
                          value: 'edit',
                          height: 46,
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 10),
                              Text(
                                'Edit Post',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          height: 46,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: clubRed,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Delete Post',
                                style: TextStyle(
                                  color: clubRed,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // PopupMenuItem(
                        //   value: 'copy',
                        //   child: Row(
                        //     children: [
                        //       Icon(Icons.link, size: 18),
                        //       SizedBox(width: 10),
                        //       Text('Copy post link'),
                        //     ],
                        //   ),
                        // ),
                      ];
                    } else {
                      return const [
                        PopupMenuItem(
                          value: 'report',
                          height: 46,
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, size: 18),
                              SizedBox(width: 10),
                              Text(
                                'Report Post',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          height: 46,
                          child: Row(
                            children: [
                              Icon(
                                Icons.block_outlined,
                                size: 18,
                                color: clubRed,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Block User',
                                style: TextStyle(
                                  color: clubRed,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // PopupMenuItem(
                        //   value: 'copy',
                        //   child: Row(
                        //     children: [
                        //       Icon(Icons.link, size: 18),
                        //       SizedBox(width: 10),
                        //       Text('Copy post link'),
                        //     ],
                        //   ),
                        // ),
                      ];
                    }
                  },
                ),
            ],
          ),
          if ((_post['content'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _PostText(
                text: _post['content'] as String,
                color: isDarkBg ? Colors.white : const Color(0xFF171717),
              ),
            ),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              key: const ValueKey('post-photo-media'),
              constraints: BoxConstraints(
                minWidth: double.infinity,
                maxHeight: maxImageHeight,
              ),
              child: images.length == 1
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PhotoViewerScreen(
                                images: images,
                                initialIndex: 0,
                                authorName: author,
                                content: _post['content'] as String?,
                              ),
                            ),
                          );
                        },
                        child: AspectRatio(
                          aspectRatio: 1.3,
                          child: _postImage(images.first, fit: BoxFit.cover),
                        ),
                      ),
                    )
                  : PostPhotoCarousel(
                      images: images,
                      imageBuilder: (src) => _postImage(src, fit: BoxFit.cover),
                      isDark: isDarkBg,
                      onPhotoTap: (index) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PhotoViewerScreen(
                              images: images,
                              initialIndex: index,
                              authorName: author,
                              content: _post['content'] as String?,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
          if (video.isNotEmpty) ...[
            const SizedBox(height: 12),
            PostVideo(
              key: ValueKey(video),
              source: video,
              onOpen: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReelsScreen(
                      initialPost: _post,
                      initialPosts: widget.videoPosts,
                    ),
                  ),
                );
                if (mounted) {
                  await _reload();
                  widget.onChanged?.call();
                }
              },
            ),
          ],
          if (_post['repost'] is Map) ...[
            const SizedBox(height: 12),
            FeedPostCard(
              post: Map<String, dynamic>.from(_post['repost'] as Map),
              showActions: false,
            ),
          ],
          if (_post['original_unavailable'] == true)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Original post unavailable',
                style: TextStyle(color: authMuted),
              ),
            ),
          if (widget.showActions) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  key: _likeButtonKey,
                  width: 62,
                  child: _PostAction(
                    tooltip: 'Like post',
                    onPressed: _busy ? null : _like,
                    onLongPress: _busy ? null : _pickReaction,
                    emoji:
                        _post['liked'] == true &&
                            _post['reactionType'] != 'like'
                        ? PostReaction.fromValue(_post['reactionType'])?.emoji
                        : null,
                    icon: _post['liked'] == true
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    color: _post['liked'] == true ? _postRed : actionColor,
                    label: (_post['likes'] ?? 0).toString(),
                    selected: _post['liked'] == true,
                  ),
                ),
                _PostActionDivider(isDark: isDarkBg),
                SizedBox(
                  width: 52,
                  child: _PostAction(
                    tooltip: 'Comment on post',
                    onPressed: widget.openComments ? _comments : null,
                    icon: Icons.chat_bubble_outline,
                    color: actionColor,
                    label: (_post['comments'] ?? 0).toString(),
                  ),
                ),
                if (!official) _PostActionDivider(isDark: isDarkBg),
                if (!official)
                  SizedBox(
                    width: 56,
                    child: _PostAction(
                      tooltip: 'Repost',
                      onPressed: _repost,
                      icon: Icons.repeat,
                      color: actionColor,
                      label: (_post['reposts'] ?? 0).toString(),
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: 40,
                  child: _PostAction(
                    tooltip: 'Share post',
                    onPressed: _share,
                    icon: Icons.share_outlined,
                    color: actionColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CachedPostImage extends StatefulWidget {
  const _CachedPostImage({required this.source, required this.fit});
  final String source;
  final BoxFit fit;

  @override
  State<_CachedPostImage> createState() => _CachedPostImageState();
}

class _CachedPostImageState extends State<_CachedPostImage> {
  Uint8List? _bytes;
  late String _url;
  late int _generation;

  @override
  void initState() {
    super.initState();
    _generation = MediaCache.instance.generation.value;
    _url = ClubRepository.mediaUrl(widget.source);
    _bytes = MediaCache.instance.bytesFor(_url);
    if (_bytes == null && _url.isNotEmpty) _load();
  }

  @override
  void didUpdateWidget(covariant _CachedPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final url = ClubRepository.mediaUrl(widget.source);
    final generation = MediaCache.instance.generation.value;
    if (url == _url && generation == _generation) return;
    _generation = generation;
    _url = url;
    _bytes = MediaCache.instance.bytesFor(url);
    if (_bytes == null && url.isNotEmpty) _load();
  }

  Future<void> _load() async {
    final url = _url;
    final bytes = await MediaCache.instance.ensure(url);
    if (!mounted || url != _url || bytes == null) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(480, 1440);
    final bytes = _bytes;
    if (bytes == null) {
      return const ColoredBox(color: Color(0xFFE8E8E8));
    }
    return Image.memory(
      bytes,
      width: double.infinity,
      fit: widget.fit,
      alignment: Alignment.center,
      gaplessPlayback: true,
      cacheWidth: width,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, error, stack) => const SizedBox(
        height: 180,
        child: Center(
          child: Icon(Icons.image_not_supported_outlined, color: authMuted),
        ),
      ),
    );
  }
}

class _PostText extends StatefulWidget {
  const _PostText({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  State<_PostText> createState() => _PostTextState();
}

class _PostTextState extends State<_PostText> {
  static const _collapsedLines = 2;
  static final _hashtag = RegExp(r'(?<![\w])#[\w]+', unicode: true);
  bool _expanded = false;

  TextStyle get _style => TextStyle(
    fontFamily: clubFontFamily,
    color: widget.color,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 23 / 15,
    letterSpacing: 0,
  );

  TextSpan _spanFor(String text) {
    final children = <InlineSpan>[];
    var start = 0;
    for (final match in _hashtag.allMatches(text)) {
      if (match.start > start) {
        children.add(TextSpan(text: text.substring(start, match.start)));
      }
      children.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(color: _postRed),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start)));
    }
    return TextSpan(children: children, style: _style);
  }

  bool _overflows(double maxWidth) {
    if (!maxWidth.isFinite) return false;
    final painter = TextPainter(
      text: _spanFor(widget.text),
      maxLines: _collapsedLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: maxWidth);
    final overflows = painter.didExceedMaxLines;
    painter.dispose();
    return overflows;
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  Widget _toggleButton(bool expanded) => Semantics(
    button: true,
    child: InkWell(
      key: ValueKey(expanded ? 'post-show-less' : 'post-show-more'),
      onTap: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            expanded ? 'Show less' : 'Show more',
            style: _style.copyWith(color: _postRed),
          ),
          const SizedBox(width: 6),
          Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: _postRed,
            size: 22,
          ),
        ],
      ),
    ),
  );

  @override
  void didUpdateWidget(_PostText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _overflows(constraints.maxWidth);
        final expanded = _expanded && overflows;
        if (!overflows) return Text.rich(_spanFor(widget.text));
        final scaler = MediaQuery.textScalerOf(context);
        final labelPainter = TextPainter(
          text: TextSpan(
            text: expanded ? 'Show less' : 'Show more',
            style: _style,
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final toggleSize = Size(labelPainter.width + 28, labelPainter.height);
        labelPainter.dispose();
        final toggle = WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _toggleButton(expanded),
        );
        var visibleText = widget.text;
        if (!expanded) {
          // Reserve the inline control while finding the two-line cutoff.
          // Characters keeps emoji and joined Unicode characters intact.
          final characters = widget.text.characters.toList();
          var low = 0;
          var high = characters.length;
          while (low < high) {
            final mid = (low + high + 1) ~/ 2;
            final candidate = '${characters.take(mid).join().trimRight()}...  ';
            final painter =
                TextPainter(
                    text: TextSpan(
                      style: _style,
                      children: [_spanFor(candidate), toggle],
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: scaler,
                    maxLines: _collapsedLines,
                  )
                  ..setPlaceholderDimensions([
                    PlaceholderDimensions(
                      size: toggleSize,
                      alignment: PlaceholderAlignment.middle,
                    ),
                  ])
                  ..layout(maxWidth: constraints.maxWidth);
            final fits = !painter.didExceedMaxLines;
            painter.dispose();
            if (fits) {
              low = mid;
            } else {
              high = mid - 1;
            }
          }
          visibleText = '${characters.take(low).join().trimRight()}...';
        }
        return Text.rich(
          TextSpan(
            style: _style,
            children: [_spanFor('$visibleText  '), toggle],
          ),
        );
      },
    );
  }
}

class _PostActionDivider extends StatelessWidget {
  const _PostActionDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    color: isDark ? const Color(0xFF45414A) : const Color(0xFFE5DDE7),
  );
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.label,
    this.selected = false,
    this.onLongPress,
    this.emoji,
  });
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String? label;
  final bool selected;
  final VoidCallback? onLongPress;
  final String? emoji;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: selected
              ? const Color(0xFFFCE5ED)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 18))
            else if (selected)
              Icon(icon, size: 18)
            else
              CustomPaint(
                size: const Size(18, 18),
                painter: _PostIconPainter(icon, color),
              ),
            if (label != null) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PostIconPainter extends CustomPainter {
  const _PostIconPainter(this.icon, this.color);
  final IconData icon;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (icon == Icons.thumb_up_outlined) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, 10, 4, 12),
          const Radius.circular(1),
        ),
        pen,
      );
      canvas.drawPath(
        Path()
          ..moveTo(6, 11)
          ..lineTo(11, 4)
          ..lineTo(11, 2)
          ..cubicTo(15, 1, 16, 5, 14, 10)
          ..lineTo(20, 10)
          ..quadraticBezierTo(23, 10, 22, 13)
          ..lineTo(20, 20)
          ..quadraticBezierTo(20, 22, 18, 22)
          ..lineTo(6, 22),
        pen,
      );
    } else if (icon == Icons.chat_bubble_outline) {
      canvas.drawPath(
        Path()
          ..moveTo(21, 16)
          ..quadraticBezierTo(21, 18, 19, 18)
          ..lineTo(8, 18)
          ..lineTo(3, 22)
          ..lineTo(3, 4)
          ..quadraticBezierTo(3, 2, 5, 2)
          ..lineTo(19, 2)
          ..quadraticBezierTo(21, 2, 21, 4)
          ..close(),
        pen,
      );
    } else if (icon == Icons.repeat) {
      canvas.drawPath(
        Path()
          ..moveTo(3, 10)
          ..lineTo(3, 8)
          ..quadraticBezierTo(3, 5, 6, 5)
          ..lineTo(20, 5)
          ..moveTo(16, 1)
          ..lineTo(20, 5)
          ..lineTo(16, 9)
          ..moveTo(21, 14)
          ..lineTo(21, 16)
          ..quadraticBezierTo(21, 19, 18, 19)
          ..lineTo(4, 19)
          ..moveTo(8, 15)
          ..lineTo(4, 19)
          ..lineTo(8, 23),
        pen,
      );
    } else {
      canvas.drawLine(const Offset(7, 11), const Offset(17, 5), pen);
      canvas.drawLine(const Offset(7, 13), const Offset(17, 19), pen);
      for (final point in [
        const Offset(5, 12),
        const Offset(19, 4),
        const Offset(19, 20),
      ]) {
        canvas.drawCircle(point, 3, pen);
      }
    }
  }

  @override
  bool shouldRepaint(_PostIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}
