import 'package:flutter/material.dart';

import '../club_repository.dart';

class MatchPhotoGallery extends StatefulWidget {
  const MatchPhotoGallery({super.key, required this.images});
  final List<String> images;

  @override
  State<MatchPhotoGallery> createState() => _MatchPhotoGalleryState();
}

class _MatchPhotoGalleryState extends State<MatchPhotoGallery> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant MatchPhotoGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images) _index = 0;
  }

  void _open(List<String> images, int index) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF08121E),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Match photos',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close photos',
                    color: Colors.white,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: _FullScreenPhotos(images: images, initialIndex: index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images
        .toSet()
        .where((image) {
          final uri = Uri.tryParse(image);
          return uri != null &&
              ['http', 'https'].contains(uri.scheme) &&
              uri.host.isNotEmpty;
        })
        .take(6)
        .toList();
    if (images.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FROM THE MATCH',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172433),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  key: ValueKey(images.join('|')),
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => _open(images, index),
                    child: _MatchPhoto(url: images[index], fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_index + 1} / ${images.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? const Color(0xFFD91624)
                        : const Color(0xFFE1E5E9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FullScreenPhotos extends StatefulWidget {
  const _FullScreenPhotos({required this.images, required this.initialIndex});
  final List<String> images;
  final int initialIndex;
  @override
  State<_FullScreenPhotos> createState() => _FullScreenPhotosState();
}

class _FullScreenPhotosState extends State<_FullScreenPhotos> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: _controller,
    itemCount: widget.images.length,
    itemBuilder: (context, index) => InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: _MatchPhoto(url: widget.images[index], fit: BoxFit.contain),
    ),
  );
}

class _MatchPhoto extends StatelessWidget {
  const _MatchPhoto({required this.url, required this.fit});
  final String url;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => Image.network(
    ClubRepository.mediaUrl(url),
    fit: fit,
    semanticLabel: 'Match photo',
    errorBuilder: (_, error, stack) => const ColoredBox(
      color: Color(0xFFF0F2F5),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFF8190A3),
          size: 32,
        ),
      ),
    ),
  );
}
