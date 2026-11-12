import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../otp_api.dart';
import '../posts_api.dart';
import '../post_link_router.dart';
import '../realtime_client.dart';
import '../session.dart';
import '../widgets/video_poster.dart';
import 'post_detail_screen.dart';
import 'repost_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({
    super.key,
    required this.initialPost,
    this.initialPosts = const [],
  });
  final Map<String, dynamic> initialPost;
  final List<Map<String, dynamic>> initialPosts;

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  final _posts = <Map<String, dynamic>>[];
  final _busy = <String>{};
  late final PageController _pager;
  int _index = 0;
  String? _cursor, _error;
  bool _loading = false, _hasMore = true, _muted = false;
  bool _foreground = true, _covered = false;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  String _id(Map<String, dynamic> row) {
    final val = row['_id'] ?? row['id'];
    return val == null ? '' : val.toString();
  }

  Future<void> _refreshPost(String id) async {
    if (id.isEmpty) return;
    try {
      final updated = await PostsApi.instance.getPost(id);
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((row) => _id(row) == id);
          if (index >= 0) {
            _posts[index] = {
              ..._posts[index],
              if (updated['likes'] != null) 'likes': updated['likes'],
              if (updated['liked'] != null) 'liked': updated['liked'],
              if (updated['comments'] != null) 'comments': updated['comments'],
              if (updated['reposts'] != null) 'reposts': updated['reposts'],
              if (updated['shares'] != null) 'shares': updated['shares'],
            };
          }
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final rows = <String, Map<String, dynamic>>{};
    for (final post in [...widget.initialPosts, widget.initialPost]) {
      final pid = _id(post);
      if (pid.isNotEmpty && '${post['video'] ?? ''}'.trim().isNotEmpty) {
        rows[pid] = post;
      }
    }
    _posts.addAll(rows.values);
    final selected = _posts.indexWhere(
      (row) => _id(row) == _id(widget.initialPost),
    );
    _index = selected < 0 ? 0 : selected;
    _pager = PageController(initialPage: _index);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    // Immediately fetch latest likes & comments for the active reel
    final initialId = _id(widget.initialPost);
    if (initialId.isNotEmpty) {
      unawaited(_refreshPost(initialId));
    }

    _subscription = RealtimeClient.instance.settingsChanges.listen((event) {
      if (event['resource'] == 'posts') {
        final targetId = '${event['id'] ?? ''}';
        if (targetId.isNotEmpty) {
          unawaited(_refreshPost(targetId));
        }
      }
    });

    unawaited(_loadMore());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pager.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (!mounted || _loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, String>{
        'limit': '10',
        'media': 'video',
      };
      if (_cursor != null && _cursor!.trim().isNotEmpty) {
        params['cursor'] = _cursor!.trim();
      }
      final query = Uri(queryParameters: params).query;
      final data = await PostsApi.instance.request(
        '${PostsApi.instance.readPath}?$query',
      );
      if (!mounted) return;
      if (data['posts'] is! List) throw const FormatException();
      final more = data['hasMore'] == true;
      final cursor = data['nextCursor'];
      if (more && (cursor is! String || cursor.isEmpty || cursor == _cursor)) {
        throw const FormatException('Invalid video pagination');
      }
      final ids = _posts.map(_id).where((id) => id.isNotEmpty).toSet();
      final incoming = (data['posts'] as List).map(
        (row) => Map<String, dynamic>.from(row as Map),
      );
      setState(() {
        for (final post in incoming) {
          final pid = _id(post);
          if (pid.isNotEmpty &&
              '${post['video'] ?? ''}'.trim().isNotEmpty &&
              ids.add(pid)) {
            _posts.add(post);
          }
        }
        _cursor = more ? (cursor as String?) : null;
        _hasMore = more;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load more videos.');
    } finally {
      if (mounted) setState(() => _loading = false);
      if (mounted &&
          _error == null &&
          _hasMore &&
          _index >= _posts.length - 2) {
        scheduleMicrotask(_loadMore);
      }
    }
  }

  void _message(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _like(Map<String, dynamic> post) async {
    if (Session.token.isEmpty) {
      _message('Please log in to like videos.');
      return;
    }
    final id = _id(post);
    if (id.isEmpty || _busy.contains(id)) return;

    final index = _posts.indexWhere((row) => _id(row) == id);
    if (index < 0) return;

    final currentPost = _posts[index];
    final wasLiked = currentPost['liked'] == true;
    final currentLikes = (currentPost['likes'] as num?)?.toInt() ?? 0;
    final nextLiked = !wasLiked;
    final nextLikes = nextLiked
        ? currentLikes + 1
        : (currentLikes > 0 ? currentLikes - 1 : 0);

    // Immediate optimistic update
    setState(() {
      _busy.add(id);
      _posts[index] = {
        ...currentPost,
        'liked': nextLiked,
        'likes': nextLikes,
      };
    });

    try {
      final data = await PostsApi.instance.request(
        '/api/user/posts/$id/like',
        method: 'PUT',
        body: {'liked': nextLiked},
      );
      if (mounted) {
        setState(() {
          final idx = _posts.indexWhere((row) => _id(row) == id);
          if (idx >= 0 && data['post'] is Map) {
            _posts[idx] = Map<String, dynamic>.from(data['post'] as Map);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          final idx = _posts.indexWhere((row) => _id(row) == id);
          if (idx >= 0) {
            _posts[idx] = {
              ..._posts[idx],
              'liked': wasLiked,
              'likes': currentLikes,
            };
          }
        });
      }
      _message(error);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _comments(Map<String, dynamic> post) async {
    final id = _id(post);
    if (id.isEmpty) return;
    setState(() => _covered = true);
    try {
      await PostDetailScreen.showComments(context, id);
      try {
        final updated = await PostsApi.instance.getPost(id);
        if (mounted) {
          setState(() {
            final index = _posts.indexWhere((row) => _id(row) == id);
            if (index >= 0) _posts[index] = updated;
          });
        }
      } catch (_) {}
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _covered = false);
    }
  }

  Future<void> _repost(Map<String, dynamic> post) async {
    if (Session.token.isEmpty) {
      _message('Please log in to repost.');
      return;
    }
    final id = _id(post);
    if (id.isEmpty) return;
    setState(() => _covered = true);
    try {
      final repostResult = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(builder: (_) => RepostScreen(post: post)),
      );
      if (!mounted || repostResult == null || repostResult == false) return;
      setState(() {
        final index = _posts.indexWhere((row) => _id(row) == id);
        if (index >= 0) {
          final current = _posts[index];
          final count = (current['reposts'] as num?)?.toInt() ?? 0;
          _posts[index] = {...current, 'reposts': count + 1};
        }
      });
      try {
        final updated = await PostsApi.instance.getPost(id);
        if (mounted) {
          setState(() {
            final index = _posts.indexWhere((row) => _id(row) == id);
            if (index >= 0) _posts[index] = updated;
          });
        }
      } catch (_) {}
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _covered = false);
    }
  }

  Future<void> _share(Map<String, dynamic> post) async {
    final id = _id(post);
    if (id.isEmpty) return;
    setState(() => _covered = true);
    try {
      final link = sharedPostUrl(id);
      await const MethodChannel(
        'highlanders/app_links',
      ).invokeMethod('sharePost', {'text': '${post['content'] ?? ''}\n$link'});
      if (Session.token.isNotEmpty) {
        await PostsApi.instance.request(
          '/api/user/posts/$id/share',
          method: 'POST',
        );
      }
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _covered = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_posts.isEmpty)
              const Center(
                child: Text(
                  'No videos available.',
                  style: TextStyle(color: Colors.white),
                ),
              )
            else
              PageView.builder(
                key: const ValueKey('reels-pager'),
                controller: _pager,
                scrollDirection: Axis.vertical,
                itemCount: _posts.length,
                onPageChanged: (index) {
                  setState(() => _index = index);
                  if (index >= 0 && index < _posts.length) {
                    final pid = _id(_posts[index]);
                    if (pid.isNotEmpty) {
                      unawaited(_refreshPost(pid));
                    }
                  }
                  if (index >= _posts.length - 3 && _error == null) {
                    unawaited(_loadMore());
                  }
                },
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ReelVideo(
                        key: ValueKey('reel-${_id(post)}'),
                        source: '${post['video']}',
                        active: index == _index && _foreground && !_covered,
                        muted: _muted,
                      ),
                      const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xD9000000)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 80,
                        bottom: 40,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${post['authorName'] ?? 'Highlander'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ('${post['content'] ?? ''}'.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${post['content']}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            // const SizedBox(height: 8),
                            // Text(
                            //   '${index + 1}/${_posts.length}  ·  Swipe up for next video',
                            //   style: const TextStyle(
                            //     color: Colors.white70,
                            //     fontSize: 11,
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 55,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Like video',
                              onPressed: _busy.contains(_id(post))
                                  ? null
                                  : () => _like(post),
                              color: post['liked'] == true
                                  ? Colors.redAccent
                                  : Colors.white,
                              icon: Icon(
                                post['liked'] == true
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 30,
                              ),
                            ),
                            Text(
                              '${post['likes'] ?? 0}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            IconButton(
                              tooltip: 'Video comments',
                              onPressed: () => _comments(post),
                              color: Colors.white,
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 28,
                              ),
                            ),
                            Text(
                              '${post['comments'] ?? 0}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            if (post['official'] != true) ...[
                              const SizedBox(height: 16),
                              IconButton(
                                tooltip: 'Repost video',
                                onPressed: () => _repost(post),
                                color: Colors.white,
                                icon: const Icon(
                                  Icons.repeat,
                                  size: 28,
                                ),
                              ),
                              Text(
                                '${post['reposts'] ?? 0}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                            const SizedBox(height: 16),
                            IconButton(
                              tooltip: 'Share video',
                              onPressed: () => _share(post),
                              color: Colors.white,
                              icon: const Icon(Icons.share_outlined, size: 28),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            Positioned(
              top: 0,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  const Text(
                    'Reels',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _muted ? 'Unmute video' : 'Mute video',
                    onPressed: () => setState(() => _muted = !_muted),
                    color: Colors.white,
                    icon: Icon(
                      _muted
                          ? Icons.volume_off_outlined
                          : Icons.volume_up_outlined,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: TextButton(
                    onPressed: _loadMore,
                    child: Text(
                      '$_error Retry',
                      style: const TextStyle(color: Colors.white),
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

/// Offscreen pages hold no decoder; only the selected, visible reel can play.
class ReelVideo extends StatefulWidget {
  const ReelVideo({
    super.key,
    required this.source,
    required this.active,
    required this.muted,
  });
  final String source;
  final bool active, muted;

  @override
  State<ReelVideo> createState() => _ReelVideoState();
}

class _ReelVideoState extends State<ReelVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_initialize());
  }

  void _release() {
    _version++;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.pause().catchError((Object _) {}));
      unawaited(controller.dispose().catchError((Object _) {}));
    }
  }

  Future<void> _initialize() async {
    _release();
    final version = _version;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(OtpApi.apiBase).resolve(widget.source),
    );
    _controller = controller;
    _failed = false;
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || version != _version || !widget.active) return;
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      if (!mounted || version != _version || !widget.active) return;
      setState(() {});
      await controller.play();
    } catch (_) {
      if (mounted && version == _version) {
        _release();
        setState(() => _failed = true);
      }
    }
  }

  @override
  void didUpdateWidget(ReelVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      _release();
    } else if (!oldWidget.active || oldWidget.source != widget.source) {
      unawaited(_initialize());
    } else if (oldWidget.muted != widget.muted) {
      unawaited(
        _controller
                ?.setVolume(widget.muted ? 0 : 1)
                .catchError((Object _) {}) ??
            Future.value(),
      );
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPoster(source: widget.source),
        if (controller?.value.isInitialized == true)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller!,
            builder: (context, value, _) => value.hasError
                ? Center(
                    child: TextButton.icon(
                      onPressed: () => unawaited(_initialize()),
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        'Could not play video. Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: value.aspectRatio > 0
                                ? value.aspectRatio
                                : 9 / 16,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                      GestureDetector(
                        key: const ValueKey('reel-toggle'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          try {
                            value.isPlaying
                                ? await controller.pause()
                                : await controller.play();
                          } catch (_) {
                            if (mounted) setState(() => _failed = true);
                          }
                        },
                        child: Center(
                          child: value.isPlaying
                              ? const SizedBox.shrink()
                              : const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 64,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      if (value.isBuffering)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                        ),
                      ),
                    ],
                  ),
          )
        else if (widget.active)
          Center(
            child: _failed
                ? TextButton.icon(
                    onPressed: () {
                      setState(() => _failed = false);
                      unawaited(_initialize());
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Could not play video. Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
      ],
    );
  }
}
