import 'dart:io';

import 'package:flutter/services.dart';

import 'otp_api.dart';

/// Android extracts an actual video frame on a worker and caches the JPEG.
class VideoThumbnail {
  static const channel = MethodChannel('highlanders/video_thumbnail');
  static final _pending = <String, Future<String?>>{};

  static Future<String?> load(String source, {bool local = false}) {
    final url = local
        ? source
        : Uri.parse(OtpApi.apiBase).resolve(source).toString();
    if (_pending.containsKey(url)) return _pending[url]!;
    if (_pending.length >= 50) _pending.remove(_pending.keys.first);
    final future = _load(url, local);
    _pending[url] = future;
    return future;
  }

  static Future<String?> _load(String source, bool local) async {
    try {
      final path = await channel
          .invokeMethod<String>('extract', {'source': source, 'local': local})
          .timeout(const Duration(seconds: 35));
      if (path != null && await File(path).exists()) return path;
    } catch (_) {
      // A failed poster must never prevent opening and playing the video.
    }
    _pending.remove(source);
    return null;
  }
}
