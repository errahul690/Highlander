import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class PostPhotoCarousel extends StatefulWidget {
  const PostPhotoCarousel({
    super.key,
    required this.images,
    required this.imageBuilder,
    this.isDark = false,
    this.onPhotoTap,
  });

  final List<String> images;
  final Widget Function(String source) imageBuilder;
  final bool isDark;
  final void Function(int index)? onPhotoTap;

  @override
  State<PostPhotoCarousel> createState() => _PostPhotoCarouselState();
}

class _PostPhotoCarouselState extends State<PostPhotoCarousel> {
  final _controller = PageController(viewportFraction: 1, keepPage: false);
  int _page = 0;
  int _revision = 0;

  @override
  void didUpdateWidget(PostPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.images, widget.images)) {
      _page = 0;
      final revision = ++_revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && revision == _revision && _controller.hasClients) {
          _controller.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (!_controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final page = _page.clamp(0, widget.images.length - 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: 1.68,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: widget.isDark
                    ? const Color(0xFF191B20)
                    : const Color(0xFFF3F4F8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.images.length > 1)
                      Offstage(
                        offstage: true,
                        child: Row(
                          children: [
                            for (final source in widget.images)
                              SizedBox(
                                width: 4,
                                height: 4,
                                child: widget.imageBuilder(source),
                              ),
                          ],
                        ),
                      ),
                    PageView.builder(
                      key: const ValueKey('post-photo-pager'),
                      controller: _controller,
                      allowImplicitScrolling: true,
                      itemCount: widget.images.length,
                      physics: const PageScrollPhysics(),
                      onPageChanged: (index) {
                        if (index < widget.images.length) {
                          setState(() => _page = index);
                        }
                      },
                      itemBuilder: (context, index) => AnimatedBuilder(
                        animation: _controller,
                        child: GestureDetector(
                          onTap: widget.onPhotoTap != null
                              ? () => widget.onPhotoTap!(index)
                              : null,
                          child: widget.imageBuilder(widget.images[index]),
                        ),
                        builder: (context, child) {
                          final current =
                              _controller.hasClients &&
                                  _controller.position.hasContentDimensions
                              ? _controller.page ?? page.toDouble()
                              : page.toDouble();
                          final offset = (index - current).clamp(-1.0, 1.0);
                          return Transform(
                            key: ValueKey('post-photo-transform-$index'),
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .0015)
                              ..rotateY(reducedMotion ? 0 : -offset * .65)
                              ..scaleByDouble(
                                reducedMotion ? 1.0 : 1 - offset.abs() * .12,
                                reducedMotion ? 1.0 : 1 - offset.abs() * .12,
                                1.0,
                                1.0,
                              ),
                            child: child,
                          );
                        },
                      ),
                    ),
                    if (widget.images.length > 1)
                      PositionedDirectional(
                        top: 10,
                        end: 10,
                        child: Semantics(
                          liveRegion: true,
                          label: 'Photo ${page + 1} of ${widget.images.length}',
                          excludeSemantics: true,
                          child: Container(
                            key: const ValueKey('post-photo-counter'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xB3000000),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${page + 1}/${widget.images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              key: const ValueKey('post-photo-dots'),
              alignment: WrapAlignment.center,
              children: [
                for (var index = 0; index < widget.images.length; index++)
                  Semantics(
                    button: true,
                    selected: index == page,
                    label: 'Show photo ${index + 1} of ${widget.images.length}',
                    child: InkWell(
                      key: ValueKey('post-photo-dot-$index'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _select(index),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: Center(
                          child: AnimatedContainer(
                            duration: reducedMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            width: index == page ? 14 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: index == page
                                  ? clubRed
                                  : widget.isDark
                                  ? const Color(0xFF767C88)
                                  : const Color(0xFFCBD0DA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
