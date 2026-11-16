import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class SavedGalleryResource {
  const SavedGalleryResource(this.bytes, this.headers);
  final Uint8List bytes;
  final Map<String, String> headers;

  Map<String, String> get validators => {
    if (headers['etag'] != null) 'If-None-Match': headers['etag']!,
    if (headers['last-modified'] != null)
      'If-Modified-Since': headers['last-modified']!,
  };
}

/// Public gallery data and pictures survive process restarts.
class GalleryCache {
  GalleryCache({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  /// Disables device storage for isolated widget tests.
  GalleryCache.memory() : _directory = null;

  final Future<Directory> Function()? _directory;

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/gallery');

  String _name(String url) {
    var a = 0x811c9dc5;
    var b = 5381;
    for (final byte in utf8.encode(url)) {
      a = ((a ^ byte) * 16777619) & 0xffffffff;
      b = ((b * 33) ^ byte) & 0xffffffff;
    }
    return '${a.toRadixString(16)}-${b.toRadixString(16)}';
  }

  Future<SavedGalleryResource?> read(String url) async {
    if (_directory == null) return null;
    try {
      final directory = await _directory();
      final data = jsonDecode(
        await File('${directory.path}/${_name(url)}.json').readAsString(),
      ) as Map;
      if (data['url'] != url) return null;
      return SavedGalleryResource(
        base64Decode(data['bytes'] as String),
        Map<String, String>.from(data['headers'] as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String url, SavedGalleryResource resource) async {
    if (_directory == null) return;
    try {
      final directory = await _directory();
      await directory.create(recursive: true);
      final file = File('${directory.path}/${_name(url)}.json');
      final pending = File('${file.path}.pending');
      await pending.writeAsString(
        jsonEncode({
          'url': url,
          'bytes': base64Encode(resource.bytes),
          'headers': resource.headers,
        }),
        flush: true,
      );
      await pending.rename(file.path);
    } catch (_) {
      // Storage failure must not prevent online gallery use.
    }
  }
}
