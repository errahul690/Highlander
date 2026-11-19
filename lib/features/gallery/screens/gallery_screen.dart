import 'dart:async';

import 'package:Highlanders/core/theme/brand_colors.dart';

import 'package:Highlanders/shared/widgets/club_page_body.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:Highlanders/shared/widgets/club_header.dart';
import 'package:Highlanders/shared/widgets/app_bottom_navigation.dart';

import 'package:Highlanders/features/gallery/data/gallery_repository.dart';
import 'package:Highlanders/features/gallery/data/instagram_video_source.dart';
import 'package:Highlanders/features/gallery/widgets/instagram_reel_player.dart';
import 'package:Highlanders/core/theme/theme.dart';
import 'package:Highlanders/features/gallery/widgets/gallery_image.dart';
import 'package:Highlanders/features/gallery/widgets/gallery_featured_carousel.dart';
import 'package:Highlanders/features/gallery/widgets/gallery_video_stack.dart';
import 'package:Highlanders/features/matches/widgets/match_highlights_player.dart';

Future<void> showGalleryVideoPopup(BuildContext context, GalleryItem item) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _VideoPlayerModal(item: item),
      ),
    );

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.initialTab = 'images'});
  final String initialTab;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _selectedTab = 'images'; // 'images' or 'videos'
  bool _loading = true;
  List<GalleryItem> _items = [];
  final GalleryRepository _gallery = GalleryRepository.instance;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab == 'videos' ? 'videos' : 'images';
    _gallery.addListener(_onGallery);
    if (_gallery.hasLoaded(_selectedTab)) {
      _items = _gallery.current(_selectedTab);
      _loading = false;
      unawaited(_gallery.revalidate(_selectedTab));
    } else {
      _loadItems();
    }
  }

  void _onGallery() {
    if (!_gallery.hasLoaded(_selectedTab)) return;
    final next = _gallery.current(_selectedTab);
    if (!mounted || identical(_items, next)) return;
    setState(() {
      _items = next;
      _loading = false;
    });
  }

  Future<void> _loadItems({bool refresh = false}) async {
    final type = _selectedTab;
    if (!refresh && _gallery.hasLoaded(type)) {
      final current = _gallery.current(type);
      if (mounted && !identical(_items, current)) {
        setState(() {
          _items = current;
          _loading = false;
        });
      }
      return;
    }
    if (mounted && _items.isEmpty) setState(() => _loading = true);
    final results = refresh
        ? await _gallery.revalidate(type)
        : await _gallery.loadGallery(type: type);
    if (mounted && type == _selectedTab && !identical(_items, results)) {
      setState(() {
        _items = results;
        _loading = false;
      });
    } else if (mounted && _loading) {
      setState(() => _loading = false);
    }
  }

  void _onTabChanged(String tab) {
    if (_selectedTab == tab) return;
    final repo = _gallery;
    setState(() {
      _selectedTab = tab;
      if (repo.hasLoaded(tab)) {
        _items = repo.current(tab);
        _loading = false;
      } else {
        _items = [];
        _loading = true;
      }
    });
    if (!repo.hasLoaded(tab)) {
      _loadItems();
    } else {
      unawaited(repo.revalidate(tab));
    }
  }

  @override
  void dispose() {
    _gallery.removeListener(_onGallery);
    super.dispose();
  }

  void _openAlbum(GalleryItem item) {
    final photos = item.images.isNotEmpty
        ? item.images
        : [item.thumbnail].where((url) => url.isNotEmpty).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AlbumGridScreen(title: item.title, photos: photos),
      ),
    );
  }

  void _openVideo(GalleryItem item) {
    showGalleryVideoPopup(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final featured = _items.where((item) => item.isFeatured).toList();
    final videoFallback = _selectedTab == 'videos' && featured.isEmpty;
    final carouselItems = videoFallback ? _items : featured;
    final albums = videoFallback
        ? <GalleryItem>[]
        : _items.where((item) => !item.isFeatured).toList();
    return ClubScaffold(
      scrollBehindHeader: false,
      backgroundColor: const Color(0xFFFAF8FA),
      appBar: const ClubHeader(title: 'Gallery', showBack: true),
      bottomNavigationBar: const AppBottomNavigation(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildSegmentedTabPill(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadItems(refresh: true),
              color: clubRed,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Content List
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: CircularProgressIndicator(color: clubRed),
                        ),
                      )
                    else if (_items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedTab == 'videos'
                                    ? Icons.videocam_outlined
                                    : Icons.photo_library_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No ${_selectedTab == 'videos' ? 'videos' : 'photos'} available yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      if (carouselItems.isNotEmpty && _selectedTab == 'videos')
                        GalleryVideoStack(
                          key: ValueKey(
                            'videos-${carouselItems.map((item) => item.id).join(',')}',
                          ),
                          items: carouselItems,
                          onOpen: _openVideo,
                          imageBuilder: (item) =>
                              _buildThumbnailImage(item.thumbnail),
                          subtitle: _getAutoTagline,
                        ),
                      if (featured.isNotEmpty && _selectedTab != 'videos')
                        GalleryFeaturedCarousel(
                          key: ValueKey(
                            '$_selectedTab-${featured.map((item) => item.id).join(',')}',
                          ),
                          items: featured,
                          onOpen: _openItem,
                          imageBuilder: (item) =>
                              _buildThumbnailImage(item.thumbnail),
                          subtitle: _getAutoTagline,
                        ),
                      if (albums.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 19,
                                decoration: BoxDecoration(
                                  color: brandAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _selectedTab == 'videos'
                                    ? (featured.isEmpty
                                          ? 'Videos'
                                          : 'More videos')
                                    : (featured.isEmpty
                                          ? 'Albums'
                                          : 'More albums'),
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildGalleryCardsLayout(albums),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Segmented Pill Tab Switcher: [ Images | Videos ]
  // --------------------------------------------------------------------------
  Widget _buildSegmentedTabPill() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EDF1),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      children: [
        _buildTab('images', 'Photos', Icons.image_outlined),
        _buildTab('videos', 'Videos', Icons.play_circle_outline_rounded),
      ],
    ),
  );

  Widget _buildTab(String tab, String label, IconData icon) {
    final selected = _selectedTab == tab;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => _onTabChanged(tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? brandAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected ? Colors.white : const Color(0xFF788192),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF788192),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Auto-calculated Count Tagline Helper
  // --------------------------------------------------------------------------
  String _getAutoTagline(GalleryItem item) {
    if (item.type == 'images') {
      final count = item.images.length;
      return '$count ${count == 1 ? 'photo' : 'photos'}';
    }
    if (item.tagline.isNotEmpty) return item.tagline;
    if (item.videoUrl.isNotEmpty) {
      return '1 video';
    }
    return item.type == 'videos' ? '1 video' : 'Photos';
  }

  // --------------------------------------------------------------------------
  // Gallery Cards Layout (Uniform 2-Column Grid Rows)
  // --------------------------------------------------------------------------
  void _openItem(GalleryItem item) {
    if (_selectedTab == 'videos') {
      _openVideo(item);
    } else {
      _openAlbum(item);
    }
  }

  Widget _buildGalleryCardsLayout(List<GalleryItem> albums) {
    final rows = <Widget>[];
    for (int i = 0; i < albums.length;) {
      final itemA = albums[i];
      if (itemA.fullWidth) {
        rows.add(_buildColumnCard(itemA));
        rows.add(const SizedBox(height: 18));
        i++;
        continue;
      }
      final itemB = i + 1 < albums.length && !albums[i + 1].fullWidth
          ? albums[i + 1]
          : null;

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildColumnCard(itemA)),
            const SizedBox(width: 14),
            Expanded(
              child: itemB != null
                  ? _buildColumnCard(itemB)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      rows.add(const SizedBox(height: 18));
      i += itemB == null ? 1 : 2;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildColumnCard(GalleryItem item) {
    final hasVideo = item.videoUrl.isNotEmpty || item.type == 'videos';

    return GestureDetector(
      key: ValueKey('gallery-card-${item.id}'),
      onTap: () => hasVideo && _selectedTab == 'videos'
          ? _openVideo(item)
          : _openAlbum(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: item.fullWidth ? 16 / 9 : 1.0,
                  child: _buildThumbnailImage(item.thumbnail),
                ),

                // Video play overlay if videos tab or has video
                if (_selectedTab == 'videos' || hasVideo)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: Center(
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFF101014),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF101014),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 3),

          // Auto-generated Tagline (e.g. 18 photos / 1 video)
          Text(
            _getAutoTagline(item),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailImage(String url) {
    if (url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFE5E7EB),
        child: Center(
          child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
        ),
      );
    }
    return GalleryImage(key: ValueKey(url), url: url);
  }
}

class _AlbumGridScreen extends StatelessWidget {
  const _AlbumGridScreen({required this.title, required this.photos});
  final String title;
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final count = photos.length;
    return ClubScaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: ClubHeader(
        title: title,
        subtitle: '$count ${count == 1 ? 'photo' : 'photos'}',
        showBack: true,
        showSearch: false,
        showSupport: false,
        uppercaseTitle: false,
      ),
      body: photos.isEmpty
          ? const Center(child: Text('No photos in this album'))
          : CustomScrollView(
              key: const ValueKey('album-grid'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF101014),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$count ${count == 1 ? 'photo' : 'photos'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8E96A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cell = (constraints.maxWidth - 8) / 3;
                        return SizedBox(
                          height: cell * 2 + 4,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: cell * 2 + 4,
                                child: _photo(context, 0),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: cell,
                                      child: photos.length > 1
                                          ? _photo(context, 1)
                                          : const SizedBox.shrink(),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: cell,
                                      child: photos.length > 2
                                          ? _photo(context, 2)
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (photos.length > 3)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                      itemCount: photos.length - 3,
                      itemBuilder: (context, index) =>
                          _photo(context, index + 3),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }

  Widget _photo(BuildContext context, int index) => Semantics(
    label: 'Photo ${index + 1} of ${photos.length}',
    button: true,
    child: GestureDetector(
      key: ValueKey('album-photo-$index'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              _AlbumPhotoScreen(photos: photos, initialIndex: index),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GalleryImage(
          key: ValueKey(photos[index]),
          url: photos[index],
          placeholder: const Color(0xFFDDD1D9),
        ),
      ),
    ),
  );
}

class _AlbumPhotoScreen extends StatefulWidget {
  const _AlbumPhotoScreen({required this.photos, required this.initialIndex});
  final List<String> photos;
  final int initialIndex;
  @override
  State<_AlbumPhotoScreen> createState() => _AlbumPhotoScreenState();
}

class _AlbumPhotoScreenState extends State<_AlbumPhotoScreen> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      automaticallyImplyLeading: true,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text('${_index + 1} / ${widget.photos.length}'),
    ),
    body: PageView.builder(
      controller: _pages,
      itemCount: widget.photos.length,
      onPageChanged: (index) => setState(() => _index = index),
      itemBuilder: (_, index) => InteractiveViewer(
        child: Center(
          child: GalleryImage(
            key: ValueKey(widget.photos[index]),
            url: widget.photos[index],
            fit: BoxFit.contain,
            decodeWidth: 1920,
            expand: false,
            placeholder: const Color(0xFF101014),
          ),
        ),
      ),
    ),
  );
}

class _VideoPlayerModal extends StatefulWidget {
  const _VideoPlayerModal({required this.item});
  final GalleryItem item;
  @override
  State<_VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<_VideoPlayerModal> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final instagram = instagramVideoPermalink(item.videoUrl);
    return Scaffold(
      key: const ValueKey('gallery-video-fullscreen'),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: item.videoUrl.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.play_disabled_rounded,
                      color: Colors.white54,
                    ),
                  )
                : instagram != null
                ? InstagramReelPlayer(permalink: instagram)
                : MatchHighlightsPlayer(
                    source: item.videoUrl,
                    fullscreen: true,
                  ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ColoredBox(
                color: Colors.black54,
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('gallery-video-back'),
                      tooltip: 'Close video',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        item.title,
                        key: const ValueKey('gallery-video-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
