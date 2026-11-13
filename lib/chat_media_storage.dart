import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'gallery_cache.dart';

/// Binary image files avoid parsing multi-megabyte base64 JSON on the UI isolate.
/// Old chat cache entries are still readable and migrate on the next write.
class ChatMediaStorage extends GalleryCache {
  ChatMediaStorage({required Future<Directory> Function() directory})
    : _directory = directory,
      super(directory: directory);
  final Future<Directory> Function() _directory;
  Future<Directory>? _directoryFuture;
  Future<Directory> get _readyDirectory => _directoryFuture ??= _directory();

  String _name(String key) {
    var a = 0x811c9dc5, b = 5381;
    for (final byte in utf8.encode(key)) {
      a = ((a ^ byte) * 16777619) & 0xffffffff;
      b = ((b * 33) ^ byte) & 0xffffffff;
    }
    return '${a.toRadixString(16)}-${b.toRadixString(16)}';
  }

  @override
  Future<SavedGalleryResource?> read(String url) async {
    final key = url;
    try {
      final directory = await _readyDirectory;
      final base = '${directory.path}/${_name(key)}';
      if (await File('$base.bin').exists()) {
        final metadata =
            jsonDecode(await File('$base.meta').readAsString()) as Map;
        if (metadata['url'] != key) return null;
        return SavedGalleryResource(
          await File('$base.bin').readAsBytes(),
          Map<String, String>.from(metadata['headers'] as Map),
        );
      }
      final legacy = File('$base.json');
      if (!await legacy.exists()) return null;
      final text = await legacy.readAsString();
      return await Isolate.run(() {
        final data = jsonDecode(text) as Map;
        if (data['url'] != key) return null;
        return SavedGalleryResource(
          base64Decode(data['bytes'] as String),
          Map<String, String>.from(data['headers'] as Map),
        );
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String url, SavedGalleryResource resource) async {
    final key = url;
    try {
      final directory = await _directory();
      await directory.create(recursive: true);
      final base = '${directory.path}/${_name(key)}';
      await File('$base.bin.pending').writeAsBytes(resource.bytes, flush: true);
      await File('$base.bin.pending').rename('$base.bin');
      await File('$base.meta.pending').writeAsString(
        jsonEncode({'url': key, 'headers': resource.headers}),
        flush: true,
      );
      await File('$base.meta.pending').rename('$base.meta');
    } catch (_) {
      /* A storage failure must not break the chat. */
    }
  }
}
