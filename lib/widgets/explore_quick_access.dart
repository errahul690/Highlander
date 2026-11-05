import 'package:flutter/material.dart';

import '../club_repository.dart';
import '../explore_repository.dart';

class ExploreQuickAccess extends StatelessWidget {
  const ExploreQuickAccess({
    super.key,
    required this.title,
    required this.items,
    required this.onOpen,
    required this.colors,
  });
  final String title;
  final List<Map<String, dynamic>> items;
  final ValueChanged<String> onOpen;
  final Map<String, dynamic> colors;

  @override
  Widget build(BuildContext context) {
    final heading = exploreColor(colors['heading'], const Color(0xFF171717));
    final muted = exploreColor(colors['muted'], const Color(0xFF8A847C));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: heading,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            padding: EdgeInsets.zero,
            primary: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              for (final item in items)
                _QuickCard(
                  item: item,
                  titleColor: heading,
                  subtitleColor: muted,
                  onOpen: onOpen,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.item,
    required this.titleColor,
    required this.subtitleColor,
    required this.onOpen,
  });
  final Map<String, dynamic> item;
  final Color titleColor, subtitleColor;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (item['displayMode'] == 'image') {
      return Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('explore-quick-${item['id']}'),
          onTap: () => onOpen('${item['link']}'),
          child: Semantics(
            label: '${item['label']}',
            button: true,
            child: SizedBox.expand(
              child: Image.network(
                ClubRepository.mediaUrl(item['card_image_url']),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    semanticLabel: 'Card image unavailable',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final background = exploreColor(
      item['backgroundColor'],
      const Color(0xFFF6F3EF),
    );
    final accent = exploreColor(item['accentColor'], const Color(0xFFC92B20));
    final art = '${item['art_url'] ?? ''}';
    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('explore-quick-${item['id']}'),
        onTap: () => onOpen('${item['link']}'),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              width: 78,
              height: 72,
              child: art.isEmpty
                  ? CustomPaint(
                      painter: _QuickArtPainter('${item['icon']}', accent),
                    )
                  : Image.network(
                      ClubRepository.mediaUrl(art),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                      errorBuilder: (_, _, _) => CustomPaint(
                        painter: _QuickArtPainter('${item['icon']}', accent),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuickIcon(item: item, color: accent),
                  const Spacer(),
                  Text(
                    '${item['label']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  if ('${item['subtitle'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${item['subtitle']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickIcon extends StatelessWidget {
  const _QuickIcon({required this.item, required this.color});
  final Map<String, dynamic> item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final image = '${item['image_url'] ?? ''}';
    if (image.isNotEmpty) {
      return Image.network(
        ClubRepository.mediaUrl(image),
        width: 26,
        height: 26,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(_iconData('${item['icon']}'), color: color, size: 26),
      );
    }
    return Icon(_iconData('${item['icon']}'), color: color, size: 26);
  }
}

IconData _iconData(String kind) {
  const icons = {
    'gallery': Icons.photo_outlined,
    'circles': Icons.groups_outlined,
    'friends': Icons.person_outline,
    'swoofi': Icons.pets_outlined,
    'notifications': Icons.notifications_none_outlined,
    'help': Icons.help_outline,
    'squad': Icons.checkroom_outlined,
    'matches': Icons.sports_soccer_outlined,
    'grounds': Icons.stadium_outlined,
    'star': Icons.star_outline,
    'heart': Icons.favorite_border,
  };
  return icons[kind] ?? Icons.link;
}

class _QuickArtPainter extends CustomPainter {
  const _QuickArtPainter(this.kind, this.accent);
  final String kind;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accent.withValues(alpha: .28);
    final soft = Paint()..color = accent.withValues(alpha: .16);
    switch (kind) {
      case 'gallery':
        final back = RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .34, 8, 36, 46),
          const Radius.circular(6),
        );
        canvas.drawRRect(back, soft);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * .12, 18, 40, 48),
            const Radius.circular(6),
          ),
          paint,
        );
      case 'circles':
        canvas.drawCircle(Offset(size.width * .72, 24), 10, soft);
        canvas.drawCircle(Offset(size.width * .48, 30), 12, paint);
        canvas.drawCircle(Offset(size.width * .9, 32), 9, paint);
        final flag = Path()
          ..moveTo(size.width * .62, 8)
          ..lineTo(size.width * .62, 40)
          ..lineTo(size.width * .9, 28)
          ..close();
        canvas.drawPath(flag, soft);
      case 'friends':
        canvas.drawCircle(Offset(size.width * .42, 22), 8, paint);
        canvas.drawCircle(Offset(size.width * .68, 18), 8, soft);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.width * .42, 48),
              width: 22,
              height: 26,
            ),
            const Radius.circular(10),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.width * .7, 46),
              width: 20,
              height: 24,
            ),
            const Radius.circular(10),
          ),
          soft,
        );
      case 'swoofi':
        _paw(canvas, Offset(size.width * .55, 22), 11, paint);
        _paw(canvas, Offset(size.width * .82, 40), 16, soft);
      default:
        canvas.drawCircle(Offset(size.width * .7, size.height * .55), 18, soft);
    }
  }

  void _paw(Canvas canvas, Offset center, double scale, Paint paint) {
    canvas.drawCircle(center.translate(0, scale * .35), scale * .42, paint);
    for (final spot in [
      const Offset(-.55, -.45),
      const Offset(-.15, -.72),
      const Offset(.28, -.62),
      const Offset(.58, -.28),
    ]) {
      canvas.drawCircle(
        center.translate(spot.dx * scale, spot.dy * scale),
        scale * .18,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QuickArtPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.accent != accent;
}
