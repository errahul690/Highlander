import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'club_repository.dart';
import 'session.dart';

/// Private local videos/documents. No network request is made by [cached].
class ChatFileCache {
  ChatFileCache({
    http.Client? client,
    Future<Directory> Function()? directory,
    String Function()? account,
  }) : _client = client ?? http.Client(),
       _directory =
           directory ??
           (() async => Directory(
             '${(await getApplicationSupportDirectory()).path}/chat-files/open',
           )),
       _account =
           account ??
           (() => Session.userId.isNotEmpty ? Session.userId : Session.email);
  static ChatFileCache instance = ChatFileCache();
  final http.Client _client;
  final Future<Directory> Function() _directory;
  final String Function() _account;
  Future<Directory>? _ready;
  final _pending = <String, Future<File?>>{};
  final _queue = Queue<void Function()>();
  int _active = 0;
  String _key(String url) => '${_account()}|${ClubRepository.mediaUrl(url)}';
  String _name(String key, String name) {
    var hash = 0x811c9dc5, second = 5381;
    for (final byte in utf8.encode(key)) {
      hash = ((hash ^ byte) * 16777619) & 0xffffffff;
      second = ((second * 33) ^ byte) & 0xffffffff;
    }
    var safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (safe.isEmpty) safe = 'Attachment';
    if (safe.length > 96) safe = safe.substring(safe.length - 96);
    return '${hash.toRadixString(16)}-${second.toRadixString(16)}-$safe';
  }

  Future<File> _file(String key, String name) async {
    final directory = await (_ready ??= _directory());
    return File('${directory.path}/${_name(key, name)}');
  }

  Future<File?> cached(String url, String name) async {
    try {
      final file = await _file(_key(url), name);
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  Future<File?> download(String url, String name) {
    final key = _key(url);
    if (_pending[key] != null) return _pending[key]!;
    final done = Completer<File?>();
    _pending[key] = done.future;
    _queue.add(() async {
      try {
        final file = await _file(key, name);
        if (await file.exists()) {
          done.complete(file);
          return;
        }
        final response = await _client
            .get(Uri.parse(ClubRepository.mediaUrl(url)))
            .timeout(const Duration(seconds: 60));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          done.complete(null);
          return;
        }
        await _write(file, response.bodyBytes);
        done.complete(file);
      } catch (_) {
        done.complete(null);
      } finally {
        _pending.remove(key);
        _active--;
        _pump();
      }
    });
    _pump();
    return done.future;
  }

  void _pump() {
    while (_active < 2 && _queue.isNotEmpty) {
      _active++;
      _queue.removeFirst()();
    }
  }

  Future<void> seed(String url, String name, Uint8List bytes) async {
    await _write(await _file(_key(url), name), bytes);
  }

  Future<void> _write(File file, Uint8List bytes) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.pending');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  }
}
