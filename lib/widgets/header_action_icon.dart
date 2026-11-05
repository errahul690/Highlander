import 'package:flutter/material.dart';

import '../header_icons_repository.dart';

class HeaderActionVisibility extends StatelessWidget {
  const HeaderActionVisibility({
    super.key,
    required this.kind,
    required this.child,
  });
  final String kind;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: HeaderIconsRepository.instance,
    builder: (context, _) => HeaderIconsRepository.instance.isVisible(kind)
        ? child
        : const SizedBox.shrink(),
  );
}

class HeaderActionIcon extends StatelessWidget {
  const HeaderActionIcon({
    super.key,
    required this.kind,
    required this.fallback,
    this.size = 22,
  });

  final String kind;
  final IconData fallback;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: HeaderIconsRepository.instance,
    builder: (context, _) {
      final bytes = HeaderIconsRepository.instance.iconBytes(kind);
      final defaultIcon = Icon(fallback, size: size, color: Colors.white);
      return bytes == null
          ? defaultIcon
          : Image.memory(
              bytes,
              key: ValueKey('header-icon-$kind'),
              width: size,
              height: size,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, error, stack) => defaultIcon,
            );
    },
  );
}
