import 'package:flutter/material.dart';

import 'package:Highlanders/core/theme/brand_colors.dart';
import 'package:Highlanders/features/gallery/data/gallery_repository.dart';

/// Featured albums retain the order supplied by the admin gallery API.
class GalleryFeaturedCarousel extends StatefulWidget {
  const GalleryFeaturedCarousel({
    super.key,
    required this.items,
    required this.onOpen,
    required this.imageBuilder,
    required this.subtitle,
  });

  final List<GalleryItem> items;
  final ValueChanged<GalleryItem> onOpen;
  final Widget Function(GalleryItem) imageBuilder;
  final String Function(GalleryItem) subtitle;

  @override
  State<GalleryFeaturedCarousel> createState() =>
      _GalleryFeaturedCarouselState();
}

class _GalleryFeaturedCarouselState extends State<GalleryFeaturedCarousel> {
  late final PageController _pages;
  late final int _initialPage;
  int _index = 0;
  final _viewportKey = GlobalKey();

  void _selectPage(int page) {
    if ((_pages.page! - page).abs() < .5) {
      widget.onOpen(widget.items[page % widget.items.length]);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleTap(TapUpDetails details) {
    final viewport =
        _viewportKey.currentContext!.findRenderObject() as RenderBox;
    final x = viewport.globalToLocal(details.globalPosition).dx;
    final current = _pages.page!.round();
    final edge = viewport.size.width * .21;
    final step = widget.items.length == 1
        ? 0
        : (x < edge ? -1 : (x > viewport.size.width - edge ? 1 : 0));
    _selectPage(current + step);
  }

  @override
  void initState() {
    super.initState();
    _initialPage = widget.items.length > 1 ? widget.items.length * 1000 : 0;
    _pages = PageController(initialPage: _initialPage, viewportFraction: .62);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          key: _viewportKey,
          height: (constraints.maxWidth * .77).clamp(240.0, 470.0),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: _pages,
                      builder: (context, _) {
                        final current =
                            _pages.hasClients && _pages.position.haveDimensions
                            ? _pages.page ?? _initialPage.toDouble()
                            : _initialPage.toDouble();
                        final nearest = current.round();
                        final visible = widget.items.length == 1
                            ? [0]
                            : [
                                for (
                                  var page = nearest - 2;
                                  page <= nearest + 2;
                                  page++
                                )
                                  page,
                              ];
                        // Paint distant cards first so the front card covers both wings.
                        visible.sort(
                          (a, b) => (b - current).abs().compareTo(
                            (a - current).abs(),
                          ),
                        );
                        final width = constraints.maxWidth;
                        final cardWidth = width * .58;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final page in visible)
                              Positioned(
                                left:
                                    (width - cardWidth) / 2 +
                                    (page - current) * width * .34,
                                top: 8,
                                bottom: 14,
                                width: cardWidth,
                                child: Opacity(
                                  opacity: (2 - (page - current).abs()).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  child: Transform(
                                    key: ValueKey(
                                      'gallery-coverflow-card-$page',
                                    ),
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, .003)
                                      ..rotateY(
                                        (page - current).clamp(-1.0, 1.0) * .60,
                                      )
                                      ..scaleByDouble(
                                        1 -
                                            (page - current).abs().clamp(
                                                  0.0,
                                                  1.0,
                                                ) *
                                                .28,
                                        1 -
                                            (page - current).abs().clamp(
                                                  0.0,
                                                  1.0,
                                                ) *
                                                .28,
                                        1,
                                        1,
                                      ),
                                    child: _buildCard(
                                      widget.items[page % widget.items.length],
                                      showCaption: (page - current).abs() < .5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: PageView.builder(
                  key: const ValueKey('gallery-featured-carousel'),
                  controller: _pages,
                  itemCount: widget.items.length == 1 ? 1 : null,
                  onPageChanged: (page) =>
                      setState(() => _index = page % widget.items.length),
                  itemBuilder: (context, page) {
                    final item = widget.items[page % widget.items.length];
                    return Semantics(
                      button: true,
                      label: '${item.title}, ${widget.subtitle(item)}',
                      onTap: () => _selectPage(page),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTapUp: _handleTap,
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      if (widget.items.length > 1) _buildIndicators(),
    ],
  );

  Widget _buildCard(GalleryItem item, {required bool showCaption}) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFE5E7EB),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .22),
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.imageBuilder(item),
        if (showCaption)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [.45, 1],
                colors: [Colors.transparent, Color(0xD9000000)],
              ),
            ),
          ),
        if (item.type == 'videos' && showCaption)
          const Center(
            child: Icon(
              Icons.play_circle_outline_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        if (showCaption)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buildIndicators() => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 8),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: List.generate(
        widget.items.length,
        (index) => Semantics(
          selected: index == _index,
          label: 'Featured album ${index + 1} of ${widget.items.length}',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pages.animateToPage(
              (_pages.page!.round() ~/ widget.items.length) *
                      widget.items.length +
                  index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 23,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: index == _index
                      ? brandAccent
                      : const Color(0xFFD0CDD4),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
