import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media_cache.dart';

class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.authorName,
    this.content,
  });

  final List<String> images;
  final int initialIndex;
  final String? authorName;
  final String? content;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.images.isEmpty ? 0 : widget.images.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
      automaticallyImplyLeading: false,
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            'No image available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PageView with swipe and zoom
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final source = widget.images[index];
                return GestureDetector(
                  onTap: _toggleOverlay,
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      clipBehavior: Clip.none,
                      child: _ViewerPhoto(
                        key: ValueKey(source),
                        source: source,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              top: _showOverlay ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(8, topPadding + 6, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.authorName?.isNotEmpty == true
                            ? widget.authorName!
                            : 'Photo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(46),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom dots indicator
            if (widget.images.length > 1)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                bottom: _showOverlay ? bottomPadding + 20 : -50,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.images.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentIndex
                            ? Colors.white
                            : Colors.white.withAlpha(90),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerPhoto extends StatefulWidget {
  const _ViewerPhoto({super.key, required this.source});
  final String source;

  @override
  State<_ViewerPhoto> createState() => _ViewerPhotoState();
}

class _ViewerPhotoState extends State<_ViewerPhoto> {
  late final Future<Uint8List?> _loading;

  @override
  void initState() {
    super.initState();
    _loading = MediaCache.instance.ensure(widget.source);
  }

  static const _error = Center(
    child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 54),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _loading,
    initialData: MediaCache.instance.bytesFor(widget.source),
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          gaplessPlayback: true,
          errorBuilder: (_, error, stackTrace) => _error,
        );
      }
      if (snapshot.connectionState == ConnectionState.done) return _error;
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    },
  );
}
