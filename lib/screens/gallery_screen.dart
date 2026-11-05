import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import '../widgets/app_bottom_navigation.dart';

import '../gallery_repository.dart';
import '../theme.dart';
import '../widgets/match_highlights_player.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab == 'videos' ? 'videos' : 'images';
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final results = await GalleryRepository.instance.loadGallery(
      type: _selectedTab,
    );
    if (mounted) {
      setState(() {
        _items = results;
        _loading = false;
      });
    }
  }

  void _onTabChanged(String tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
    });
    _loadItems();
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
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => _VideoPlayerModal(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClubScaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const ClubHeader(title: 'Gallery', showBack: true),
      bottomNavigationBar: const AppBottomNavigation(),
      body: RefreshIndicator(
        onRefresh: _loadItems,
        color: clubRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Segmented Tab Selector: [ Images | Videos ]
              _buildSegmentedTabPill(),

              const SizedBox(height: 18),

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
              else
                _buildGalleryCardsLayout(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Segmented Pill Tab Switcher: [ Images | Videos ]
  // --------------------------------------------------------------------------
  Widget _buildSegmentedTabPill() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEEF2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _onTabChanged('images'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 'images'
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _selectedTab == 'images'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Images',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTab == 'images'
                        ? const Color(0xFF101014)
                        : const Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: _selectedTab == 'images'
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _onTabChanged('videos'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 'videos'
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _selectedTab == 'videos'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Videos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTab == 'videos'
                        ? const Color(0xFF101014)
                        : const Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: _selectedTab == 'videos'
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Auto-calculated Count Tagline Helper
  // --------------------------------------------------------------------------
  String _getAutoTagline(GalleryItem item) {
    if (item.tagline.isNotEmpty) {
      return item.tagline;
    }
    if (item.images.isNotEmpty) {
      final count = item.images.length;
      return '$count ${count == 1 ? 'photo' : 'photos'}';
    }
    if (item.videoUrl.isNotEmpty) {
      return '1 video';
    }
    return item.type == 'videos' ? '1 video' : 'Photos';
  }

  // --------------------------------------------------------------------------
  // Gallery Cards Layout (Uniform 2-Column Grid Rows)
  // --------------------------------------------------------------------------
  Widget _buildGalleryCardsLayout() {
    final rows = <Widget>[];
    for (int i = 0; i < _items.length;) {
      final itemA = _items[i];
      if (itemA.fullWidth) {
        rows.add(_buildColumnCard(itemA));
        rows.add(const SizedBox(height: 18));
        i++;
        continue;
      }
      final itemB = i + 1 < _items.length && !_items[i + 1].fullWidth
          ? _items[i + 1]
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
      return Container(
        color: const Color(0xFFE5E7EB),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFFE5E7EB),
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.grey,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _AlbumGridScreen extends StatelessWidget {
  const _AlbumGridScreen({required this.title, required this.photos});
  final String title;
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final count = photos.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF101014),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$count ${count == 1 ? 'photo' : 'photos'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
      body: photos.isEmpty
          ? const Center(child: Text('No photos in this album'))
          : GridView.builder(
              key: const ValueKey('album-grid'),
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) => GestureDetector(
                key: ValueKey('album-photo-$index'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AlbumPhotoScreen(
                      photos: photos,
                      initialIndex: index,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    photos[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
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
          child: Image.network(
            widget.photos[index],
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    ),
  );
}

// --------------------------------------------------------------------------
// Video Player Modal Placeholder
// --------------------------------------------------------------------------
class _VideoPlayerModal extends StatelessWidget {
  const _VideoPlayerModal({required this.item});

  final GalleryItem item;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 30),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101014),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: item.videoUrl.isEmpty
                    ? const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: Icon(
                            Icons.play_disabled_rounded,
                            color: Colors.white54,
                            size: 36,
                          ),
                        ),
                      )
                    : MatchHighlightsPlayer(source: item.videoUrl),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.tagline.isNotEmpty
                          ? item.tagline
                          : 'Highlights Stream',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      item.videoUrl.isNotEmpty ? 'HD 1080p' : 'Official Media',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
