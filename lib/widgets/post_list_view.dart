import 'package:flutter/material.dart';

import '../post_pager.dart';
import 'feed_post_card.dart';
import 'startup_loader.dart';

/// Lazy cards release their media players when they leave the scroll cache.
class PostListView extends StatefulWidget {
  const PostListView({
    super.key,
    required this.pager,
    required this.header,
    required this.padding,
    required this.onChanged,
    this.showPosts = true,
    this.alternative,
    this.spacing = 6,
    this.afterFirstPosts,
    this.afterPostCount = 2,
    this.inserts = const [],
    this.emptyLoading,
    this.holdEmpty = false,
    this.beforeHeader,
  });
  final PostPager pager;
  final List<Widget> header;
  final EdgeInsets padding;
  final Future<void> Function() onChanged;
  final bool showPosts;
  final Widget? alternative;
  final double spacing;
  final Widget? afterFirstPosts;
  final int afterPostCount;
  final List<PostListInsert> inserts;
  final Widget? emptyLoading;
  final bool holdEmpty;
  final Widget? beforeHeader;
  @override
  State<PostListView> createState() => _PostListViewState();
}

class _PostListViewState extends State<PostListView> {
  final _scroll = ScrollController();
  ScrollController? _primaryScroll;
  ScrollController get _effectiveScroll => _primaryScroll ?? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.maybeOf(context);
    if (identical(primary, _primaryScroll)) return;
    _primaryScroll?.removeListener(_onScroll);
    _primaryScroll = primary;
    _primaryScroll?.addListener(_onScroll);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (widget.showPosts &&
        _effectiveScroll.hasClients &&
        _effectiveScroll.position.extentAfter < 500 &&
        widget.pager.error == null) {
      widget.pager.next();
    }
  }

  @override
  void dispose() {
    _primaryScroll?.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  List<_FeedRow> _rows() {
    final posts = widget.pager.posts;
    final source = widget.inserts.isNotEmpty
        ? widget.inserts
        : widget.afterFirstPosts == null
        ? const <PostListInsert>[]
        : [
            PostListInsert(
              afterPosts: widget.afterPostCount,
              child: widget.afterFirstPosts!,
            ),
          ];
    final placed = <({int at, int order, Widget child})>[];
    for (var index = 0; index < source.length; index++) {
      final after = source[index].afterPosts < 0 ? 0 : source[index].afterPosts;
      final ready =
          posts.length >= after ||
          (!widget.pager.hasMore && !widget.pager.loading);
      if (!ready) continue;
      placed.add((
        at: after > posts.length ? posts.length : after,
        order: index,
        child: source[index].child,
      ));
    }
    placed.sort((a, b) {
      final byAt = a.at.compareTo(b.at);
      return byAt != 0 ? byAt : a.order.compareTo(b.order);
    });
    final rows = <_FeedRow>[];
    var postIndex = 0;
    var sectionIndex = 0;
    while (postIndex < posts.length || sectionIndex < placed.length) {
      if (sectionIndex < placed.length &&
          placed[sectionIndex].at == postIndex) {
        rows.add(_FeedRow.section(placed[sectionIndex].child));
        sectionIndex++;
        continue;
      }
      if (postIndex < posts.length) {
        rows.add(_FeedRow.post(posts[postIndex]));
        postIndex++;
        continue;
      }
      break;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    controller: _effectiveScroll,
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      if (widget.beforeHeader != null)
        SliverToBoxAdapter(child: widget.beforeHeader),
      SliverPadding(
        padding: widget.padding,
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.header,
              ),
            ),
            if (!widget.showPosts)
              SliverToBoxAdapter(
                child: widget.alternative ?? const SizedBox.shrink(),
              )
            else ...[
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final rows = _rows();
                    final row = rows[index];
                    if (row.section != null) return row.section;
                    final post = row.post!;
                    return Padding(
                      key: ValueKey(post['_id']),
                      padding: EdgeInsets.only(bottom: widget.spacing),
                      child: FeedPostCard(
                        post: post,
                        videoPosts: widget.pager.posts
                            .where(
                              (item) =>
                                  '${item['video'] ?? ''}'.trim().isNotEmpty,
                            )
                            .toList(),
                        onChanged: widget.onChanged,
                      ),
                    );
                  },
                  childCount: _rows().length,
                  addAutomaticKeepAlives: false,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child:
                        widget.pager.posts.isEmpty &&
                            (widget.pager.loading || widget.holdEmpty)
                        ? (widget.emptyLoading ?? const StartupLoader())
                        : widget.pager.loading
                        ? const StartupLoader()
                        : widget.pager.error != null
                        ? TextButton(
                            onPressed: widget.pager.retry,
                            child: Text(widget.pager.error!),
                          )
                        : widget.pager.posts.isEmpty
                        ? const Text('No posts yet')
                        : widget.pager.hasMore
                        ? TextButton(
                            onPressed: widget.pager.next,
                            child: const Text('Load more'),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class PostListInsert {
  const PostListInsert({required this.afterPosts, required this.child});
  final int afterPosts;
  final Widget child;
}

class _FeedRow {
  const _FeedRow.post(this.post) : section = null;
  const _FeedRow.section(this.section) : post = null;
  final Map<String, dynamic>? post;
  final Widget? section;
}
