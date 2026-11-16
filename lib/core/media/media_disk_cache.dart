import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Private, bounded photo storage. Recently viewed files survive app restarts.
class MediaDiskCache {
  MediaDiskCache({
    Future<Directory> Function()? directory,
    this.maxBytes = 200 * 1024 * 1024,
    this.maxFiles = 300,
  }) : _directory = directory ?? _defaultDirectory;
  MediaDiskCache.disabled() : _directory = null, maxBytes = 0, maxFiles = 0;

  final Future<Directory> Function()? _directory;
  final int maxBytes, maxFiles;
  Future<void> _pending = Future.value();
  String? _indexedPath;
  final _entries = <String, ({int size, DateTime accessed})>{};
  Future<void> get idle => _pending;

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getTemporaryDirectory()).path}/feed-media-v1');

  String _name(String url) {
    var a = 0x811c9dc5, b = 5381;
    for (final byte in utf8.encode(url)) {
      a = ((a ^ byte) * 16777619) & 0xffffffff;
      b = ((b * 33) ^ byte) & 0xffffffff;
    }
    return '${a.toRadixString(16)}-${b.toRadixString(16)}.bin';
  }

  Future<T> _run<T>(Future<T> Function(Directory) operation, T fallback) {
    final next = _pending.then((_) async {
      if (_directory == null) return fallback;
      try {
        final directory = await _directory();
        await _index(directory);
        return await operation(directory);
      } catch (_) {
        return fallback; // Storage failure must not block online use.
      }
    });
    _pending = next.then<void>((_) {});
    return next;
  }

  Future<void> _index(Directory directory) async {
    if (_indexedPath == directory.path) return;
    _entries.clear();
    if (await directory.exists()) {
      await for (final item in directory.list(followLinks: false)) {
        if (item is File && item.path.endsWith('.bin')) {
          final stat = await item.stat();
          _entries[item.uri.pathSegments.last] = (
            size: stat.size,
            accessed: stat.modified,
          );
        } else if (item is File && item.path.endsWith('.bin.pending')) {
          await item.delete();
        }
      }
    }
    _indexedPath = directory.path;
  }

  Future<Uint8List?> read(String url) => _run((directory) async {
    final file = File('${directory.path}/${_name(url)}');
    final bytes = await file.readAsBytes();
    if (bytes.length < 4 || bytes.length > maxBytes) return null;
    final length = ByteData.sublistView(bytes).getUint32(0);
    if (length > bytes.length - 4 ||
        utf8.decode(bytes.sublist(4, 4 + length)) != url) {
      return null;
    }
    final accessed = DateTime.now();
    await file.setLastModified(accessed);
    _entries[_name(url)] = (size: bytes.length, accessed: accessed);
    return Uint8List.fromList(bytes.sublist(4 + length));
  }, null);

  Future<void> write(String url, Uint8List bytes) => _run((directory) async {
    final encodedUrl = utf8.encode(url);
    final length = 4 + encodedUrl.length + bytes.length;
    if (bytes.isEmpty || length > maxBytes || maxFiles < 1) return;
    await directory.create(recursive: true);
    final data = Uint8List(length);
    ByteData.sublistView(data).setUint32(0, encodedUrl.length);
    data.setAll(4, encodedUrl);
    data.setAll(4 + encodedUrl.length, bytes);
    final target = '${directory.path}/${_name(url)}';
    final pending = File('$target.pending');
    await pending.writeAsBytes(data, flush: true);
    await pending.rename(target);
    _entries[_name(url)] = (size: data.length, accessed: DateTime.now());
    final entries = _entries.entries.toList()
      ..sort((a, b) => a.value.accessed.compareTo(b.value.accessed));
    var total = entries.fold<int>(0, (sum, item) => sum + item.value.size);
    var count = entries.length;
    for (final item in entries) {
      if (total <= maxBytes && count <= maxFiles) break;
      final file = File('${directory.path}/${item.key}');
      if (await file.exists()) await file.delete();
      _entries.remove(item.key);
      total -= item.value.size;
      count--;
    }
  }, null);

  Future<void> remove(String url) => _run((directory) async {
    final file = File('${directory.path}/${_name(url)}');
    if (await file.exists()) await file.delete();
    _entries.remove(_name(url));
  }, null);

  Future<void> clear() => _run((directory) async {
    if (!await directory.exists()) return;
    await for (final item in directory.list(followLinks: false)) {
      if (item is File &&
          (item.path.endsWith('.bin') || item.path.endsWith('.bin.pending'))) {
        await item.delete();
      }
    }
    _entries.clear();
  }, null);
}
