import 'dart:io';

import 'package:flutter/material.dart';

import '../video_thumbnail.dart';

class VideoPoster extends StatelessWidget {
  const VideoPoster({super.key, required this.source, this.local = false});
  final String source;
  final bool local;

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: VideoThumbnail.load(source, local: local),
    builder: (context, snapshot) {
      if (snapshot.data != null) {
        return Image.file(
          File(snapshot.data!),
          key: const ValueKey('video-frame-thumbnail'),
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF202127)),
        );
      }
      return ColoredBox(
        color: const Color(0xFF202127),
        child: Center(
          child: snapshot.connectionState == ConnectionState.done
              ? const Icon(
                  Icons.videocam_outlined,
                  color: Colors.white38,
                  size: 44,
                )
              : const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
        ),
      );
    },
  );
}
