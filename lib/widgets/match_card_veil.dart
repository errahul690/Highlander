import 'dart:io';

import 'package:flutter/material.dart';

/// Darkness and photo of stadium cards, set from Admin → App Setting → Match Cards.
class MatchCardOverlay {
  static final amount = ValueNotifier<double>(0.08);
  static final localFile = ValueNotifier<String>('');

  static void apply(Object? raw, {String? localFile}) {
    final parsed = raw is num ? raw.toDouble() : double.tryParse('$raw');
    final percent = (parsed ?? 8).clamp(0, 40).toDouble();
    amount.value = percent / 100;
    if (localFile != null) MatchCardOverlay.localFile.value = localFile;
  }
}

class MatchCardVeil extends StatelessWidget {
  const MatchCardVeil({super.key, this.solid = false, this.opacityOverride});

  final double? opacityOverride;

  /// A flat tint. The default is a light-to-dark gradient.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: MatchCardOverlay.amount,
      builder: (_, defaultAmount, __) {
        final amount = (opacityOverride ?? defaultAmount)
            .clamp(0.0, 1.0)
            .toDouble();
        if (solid) {
          return ColoredBox(color: Color.fromRGBO(9, 35, 61, amount));
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(13, 37, 76, amount * 0.35),
                Color.fromRGBO(7, 20, 42, amount),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MatchCardPhoto extends StatelessWidget {
  const MatchCardPhoto({
    super.key,
    this.alignment = Alignment.center,
    this.fallback,
  });

  final Alignment alignment;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: MatchCardOverlay.localFile,
      builder: (_, path, __) {
        if (path.isEmpty) return _asset();
        return Image(
          image: FileImage(File(path)),
          fit: BoxFit.cover,
          alignment: alignment,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _asset(),
        );
      },
    );
  }

  Widget _asset() {
    return Image.asset(
      'assets/images/match_hero_stadium.png',
      fit: BoxFit.cover,
      alignment: alignment,
      errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
    );
  }
}
