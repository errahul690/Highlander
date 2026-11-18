import 'package:flutter/material.dart';

import 'package:Highlanders/features/gallery/data/gallery_repository.dart';
import 'package:Highlanders/features/gallery/screens/gallery_screen.dart';
import 'package:Highlanders/features/gallery/widgets/gallery_image.dart';
import 'package:Highlanders/features/gallery/widgets/gallery_video_stack.dart';

class FeedFocusShowcase extends StatefulWidget {
  const FeedFocusShowcase({
    super.key,
    required this.items,
    required this.title,
    required this.subtitle,
  });
  final List<GalleryItem> items;
  final String title, subtitle;

  @override
  State<FeedFocusShowcase> createState() => _FeedFocusShowcaseState();
}

class _FeedFocusShowcaseState extends State<FeedFocusShowcase> {
  final _cards = GalleryVideoStackController();
  int _index = 0;

  @override
  void dispose() {
    _cards.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 530),
      child: Container(
        key: const ValueKey('feed-focus-section'),
        margin: const EdgeInsets.symmetric(vertical: 12),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          border: Border.fromBorderSide(BorderSide(color: Color(0xFFEEE1E7))),
          gradient: LinearGradient(
            begin: Alignment(-.26, -1),
            end: Alignment(.26, 1),
            colors: [Color(0xFFFFFDFD), Color(0xFFFDF9FB), Color(0xFFF8EFF3)],
            stops: [0, .34, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              bottom: 51,
              left: 0,
              right: 0,
              height: 186,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: .75,
                      colors: [Color(0x1FD8B4C2), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xB3A51E4E),
                        Color(0xB3E7B6C9),
                        Colors.transparent,
                      ],
                      stops: [0, .36, .61, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 25, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA61147),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF9E8EE),
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Text(
                            'FROM THE HIGHLANDERS',
                            style: TextStyle(
                              color: Color(0xFF8B2D50),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Container(
                              height: 1,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFD6A8BA),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: widget.title.trim() == 'NEUFC in Focus'
                                  ? Text.rich(
                                      TextSpan(
                                        children: [
                                          const TextSpan(
                                            text: 'NEUFC ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: 'in Focus',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF890934),
                                            ),
                                          ),
                                          const TextSpan(
                                            text: '.',
                                            style: TextStyle(
                                              color: Color(0xFFD25F86),
                                            ),
                                          ),
                                        ],
                                      ),
                                      style: const TextStyle(
                                        fontSize: 30,
                                        height: 1.04,
                                        letterSpacing: -1.7,
                                        color: Color(0xFF211C24),
                                      ),
                                    )
                                  : Text(
                                      widget.title,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        height: 1.04,
                                        letterSpacing: -1.7,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF211C24),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const GalleryScreen(initialTab: 'videos'),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7D1438),
                              backgroundColor: Colors.white.withValues(
                                alpha: .76,
                              ),
                              side: const BorderSide(color: Color(0xFFE9D1DA)),
                              padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: const StadiumBorder(),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View All',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 7),
                                CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Color(0xFF85103B),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children:
                                widget.subtitle.endsWith('on & off the pitch.')
                                ? [
                                    TextSpan(
                                      text: widget.subtitle.substring(
                                        0,
                                        widget.subtitle.length -
                                            'on & off the pitch.'.length,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: 'on & off the pitch.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF6F2643),
                                      ),
                                    ),
                                  ]
                                : [TextSpan(text: widget.subtitle)],
                          ),
                          style: const TextStyle(
                            color: Color(0xFF847984),
                            fontSize: 12.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Stack(
                  children: [
                    Positioned(
                      top: 36,
                      left: 0,
                      right: 0,
                      child: ExcludeSemantics(
                        child: Center(
                          child: Text(
                            'NEUFC',
                            style: TextStyle(
                              fontSize: 118,
                              height: 1,
                              letterSpacing: -13,
                              fontWeight: FontWeight.w900,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 1
                                ..color = const Color(0x0E782245),
                            ),
                          ),
                        ),
                      ),
                    ),
                    GalleryVideoStack(
                      items: widget.items,
                      controller: _cards,
                      style: GalleryVideoStackStyle.focus,
                      onIndexChanged: (index) => setState(() => _index = index),
                      onOpen: (item) => showGalleryVideoPopup(context, item),
                      imageBuilder: (item) => GalleryImage(
                        url: item.thumbnail,
                        placeholder: const Color(0xFF29131D),
                      ),
                      subtitle: (item) =>
                          item.tagline.isEmpty ? 'Video' : item.tagline,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: List.generate(
                            widget.items.length,
                            (index) => Expanded(
                              child: Semantics(
                                selected: index == _index,
                                label:
                                    'Focus video ${index + 1} of ${widget.items.length}',
                                child: InkWell(
                                  onTap: () => _cards.goTo(index),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2.5,
                                      vertical: 14,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      height: 3,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(9),
                                        color: index == _index
                                            ? const Color(0xFF8F0E3D)
                                            : const Color(0xFFEAD4DD),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.fromLTRB(24, 16, 24, 27),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFFE7CBD5),
                        Colors.transparent,
                      ],
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
}
